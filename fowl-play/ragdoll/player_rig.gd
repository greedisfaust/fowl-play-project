## Host-simulated physical rig and client-rendered pose stream.
extends Node3D

const LAYERS = preload("res://core/layers.gd")
const TUNING = preload("res://core/tuning.gd")
const SELF_COLLISION = preload("res://ragdoll/self_collision_policy.gd")
const EXPECTED_PHYSICAL_BONES: int = 11
const POSE_VALUES_PER_BONE: int = 7
const POSITION_QUANTIZATION: float = 1000.0
const ROTATION_QUANTIZATION: float = 32767.0

@onready var simulator: PhysicalBoneSimulator3D = $Skeleton3D/PhysicalBoneSimulator3D
@onready var skeleton: Skeleton3D = $Skeleton3D
@onready var head_attachment: BoneAttachment3D = $Skeleton3D/HeadAttachment
@onready var debug_hub: Node = get_node("/root/DebugHub")

var physical_bones: Array[PhysicalBone3D] = []
var _bone_indices: PackedInt32Array = PackedInt32Array()
var _watch_name: StringName
var _remote_samples: Array[Dictionary] = []
var _remote_active: bool = false
var _last_remote_sequence: int = -1
var _last_remote_host_time_ms: int = -1
var _latest_host_pose: PackedInt32Array = PackedInt32Array()
var _hips_bone_index: int = -1
var _hips_physical_bone: PhysicalBone3D
var _pose_blend_active: bool = false
var _pose_blend_elapsed: float = 0.0
var _pose_blend_duration: float = 0.0
var _pose_blend_start: Array[Transform3D] = []
var _pose_blend_target: Array[Transform3D] = []

func _ready() -> void:
	_watch_name = StringName("rig/%s/physical_bones" % get_parent().name)
	simulator.physical_bones_stop_simulation()
	simulator.modification_processed.connect(_on_simulator_processed)
	for child: Node in simulator.get_children():
		if child is PhysicalBone3D:
			var physical_bone: PhysicalBone3D = child
			physical_bone.collision_layer = 0
			physical_bone.collision_mask = 0
			physical_bones.append(physical_bone)
			_bone_indices.append(skeleton.find_bone(String(physical_bone.bone_name)))
			if physical_bone.bone_name == "Hips":
				_hips_physical_bone = physical_bone
				_hips_bone_index = _bone_indices[-1]

	var self_contact_pairs: int = SELF_COLLISION.configure(physical_bones)

	if physical_bones.size() != EXPECTED_PHYSICAL_BONES:
		debug_hub.call("warn", &"ragdoll", "Rig %s has %d physical bones; expected %d." % [get_parent().name, physical_bones.size(), EXPECTED_PHYSICAL_BONES])
	else:
		debug_hub.call("log", &"ragdoll", "Rig %s prepared 11 dormant physical bones; %d selective self-contact pairs." % [get_parent().name, self_contact_pairs])
	debug_hub.call("watch", _watch_name, func() -> int: return physical_bones.size())
	set_process(false)

func _exit_tree() -> void:
	if is_instance_valid(debug_hub):
		debug_hub.call("unwatch", _watch_name)

func enable_host_collisions() -> void:
	for physical_bone: PhysicalBone3D in physical_bones:
		physical_bone.collision_layer = 1 << (LAYERS.LIMP_BODIES - 1)
		physical_bone.collision_mask = LAYERS.LAYER_MASK_LIMP_BODIES

func disable_collisions() -> void:
	for physical_bone: PhysicalBone3D in physical_bones:
		physical_bone.collision_layer = 0
		physical_bone.collision_mask = 0

func begin_host_simulation() -> bool:
	if simulator.is_simulating_physics() or _remote_active or not _has_valid_bones():
		return false
	# The Player capsule can move independently; the simulated rig must not
	# inherit that transform or feed its own movement back through the parent.
	var world_transform: Transform3D = global_transform
	top_level = true
	global_transform = world_transform
	simulator.active = true
	_latest_host_pose = PackedInt32Array()
	enable_host_collisions()
	simulator.physical_bones_start_simulation()
	return true

func stop_host_simulation() -> void:
	_pose_blend_active = false
	_pose_blend_start.clear()
	_pose_blend_target.clear()
	simulator.physical_bones_stop_simulation()
	disable_collisions()
	skeleton.reset_bone_poses()
	top_level = false
	transform = Transform3D.IDENTITY
	_latest_host_pose = PackedInt32Array()

func stop_host_simulation_with_blend(duration: float) -> void:
	var start_pose: Array[Transform3D] = _capture_skeleton_pose()
	stop_host_simulation()
	_begin_pose_blend(start_pose, duration)

func is_pose_blending() -> bool:
	return _pose_blend_active

func capture_quantized_pose() -> PackedInt32Array:
	if simulator.is_simulating_physics() and not _latest_host_pose.is_empty():
		return _latest_host_pose
	return _encode_current_pose()

func are_physical_bones_slow() -> bool:
	if not simulator.is_simulating_physics() or physical_bones.size() != EXPECTED_PHYSICAL_BONES:
		return false
	for physical_bone: PhysicalBone3D in physical_bones:
		if physical_bone.linear_velocity.length() > TUNING.LIMP_SETTLED_SPEED_MPS or physical_bone.angular_velocity.length() > 1.0:
			return false
	return true

func get_hips_world_position() -> Vector3:
	if simulator.is_simulating_physics() and _hips_physical_bone != null:
		return _hips_physical_bone.global_position
	if _hips_bone_index >= 0:
		return skeleton.to_global(skeleton.get_bone_global_pose(_hips_bone_index).origin)
	return global_position

func get_head_eye_transform() -> Transform3D:
	# The attachment follows the simulated host head or the interpolated client pose.
	var eye_offset: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.17, -0.06))
	return head_attachment.global_transform * eye_offset

func set_owner_head_visible(show_head: bool) -> void:
	head_attachment.visible = show_head

func _on_simulator_processed() -> void:
	if simulator.is_simulating_physics() and not _remote_active:
		_latest_host_pose = _encode_current_pose()

func _encode_current_pose() -> PackedInt32Array:
	var data: PackedInt32Array = PackedInt32Array()
	if not _has_valid_bones():
		return data
	data.resize(EXPECTED_PHYSICAL_BONES * POSE_VALUES_PER_BONE)
	for bone_number: int in range(EXPECTED_PHYSICAL_BONES):
		var pose: Transform3D = skeleton.get_bone_global_pose(_bone_indices[bone_number])
		var rotation: Quaternion = pose.basis.get_rotation_quaternion().normalized()
		var offset: int = bone_number * POSE_VALUES_PER_BONE
		data[offset] = roundi(pose.origin.x * POSITION_QUANTIZATION)
		data[offset + 1] = roundi(pose.origin.y * POSITION_QUANTIZATION)
		data[offset + 2] = roundi(pose.origin.z * POSITION_QUANTIZATION)
		data[offset + 3] = roundi(rotation.x * ROTATION_QUANTIZATION)
		data[offset + 4] = roundi(rotation.y * ROTATION_QUANTIZATION)
		data[offset + 5] = roundi(rotation.z * ROTATION_QUANTIZATION)
		data[offset + 6] = roundi(rotation.w * ROTATION_QUANTIZATION)
	return data

func begin_remote_pose(world_transform: Transform3D, initial_pose: PackedInt32Array) -> bool:
	if _remote_active or not _has_valid_bones() or not valid_pose(initial_pose):
		return false
	var previous_transform: Transform3D = global_transform
	top_level = true
	global_transform = world_transform if world_transform.is_finite() else previous_transform
	simulator.active = false
	_remote_active = true
	_last_remote_sequence = 0
	_last_remote_host_time_ms = -1
	_remote_samples.clear()
	_remote_samples.append({"time": Time.get_ticks_msec() / 1000.0, "host_time_ms": 0, "data": initial_pose})
	_apply_pose(initial_pose, initial_pose, 0.0)
	set_process(true)
	return true

func push_remote_pose(sequence: int, host_time_ms: int, data: PackedInt32Array) -> bool:
	if not _remote_active or sequence <= _last_remote_sequence or host_time_ms <= _last_remote_host_time_ms or not valid_pose(data):
		return false
	_last_remote_sequence = sequence
	_last_remote_host_time_ms = host_time_ms
	_remote_samples.append({
		"time": Time.get_ticks_msec() / 1000.0,
		"host_time_ms": host_time_ms,
		"data": data,
	})
	while _remote_samples.size() > 4:
		_remote_samples.pop_front()
	return true

func push_settled_pose(sequence: int, host_time_ms: int, data: PackedInt32Array) -> bool:
	if not _remote_active or sequence <= _last_remote_sequence or not valid_pose(data):
		return false
	_last_remote_sequence = sequence
	_last_remote_host_time_ms = host_time_ms
	_remote_samples.clear()
	_remote_samples.append({"time": Time.get_ticks_msec() / 1000.0, "host_time_ms": host_time_ms, "data": data})
	_apply_pose(data, data, 0.0)
	return true

func end_remote_pose() -> void:
	_pose_blend_active = false
	_pose_blend_start.clear()
	_pose_blend_target.clear()
	_remote_active = false
	_remote_samples.clear()
	set_process(false)
	disable_collisions()
	skeleton.reset_bone_poses()
	simulator.active = true
	top_level = false
	transform = Transform3D.IDENTITY

func end_remote_pose_with_blend(duration: float, final_pose: PackedInt32Array) -> void:
	if valid_pose(final_pose):
		_apply_pose(final_pose, final_pose, 0.0)
	var start_pose: Array[Transform3D] = _capture_skeleton_pose()
	end_remote_pose()
	_begin_pose_blend(start_pose, duration)

func valid_pose(data: PackedInt32Array) -> bool:
	if data.size() != EXPECTED_PHYSICAL_BONES * POSE_VALUES_PER_BONE:
		return false
	for value: int in data:
		if absi(value) > 1000000:
			return false
	return true

func _has_valid_bones() -> bool:
	if _bone_indices.size() != EXPECTED_PHYSICAL_BONES:
		return false
	for index: int in _bone_indices:
		if index < 0:
			return false
	return true

func _process(_delta: float) -> void:
	if _pose_blend_active:
		_process_pose_blend(_delta)
		return
	if not _remote_active or _remote_samples.is_empty():
		return
	var render_time: float = Time.get_ticks_msec() / 1000.0 - TUNING.RAGDOLL_INTERP_DELAY_S
	while _remote_samples.size() > 2 and float(_remote_samples[1].time) <= render_time:
		_remote_samples.pop_front()
	var first: Dictionary = _remote_samples[0]
	if _remote_samples.size() == 1 or render_time <= float(first.time):
		_apply_pose(first.data, first.data, 0.0)
		_enforce_hips_sync_tolerance()
		return
	var second: Dictionary = _remote_samples[1]
	var weight: float = clampf((render_time - float(first.time)) / maxf(float(second.time) - float(first.time), 0.0001), 0.0, 1.0)
	_apply_pose(first.data, second.data, weight)
	_enforce_hips_sync_tolerance()

func _enforce_hips_sync_tolerance() -> void:
	if _hips_bone_index < 0 or _remote_samples.is_empty():
		return
	var latest: Dictionary = _remote_samples.back()
	var latest_pose: PackedInt32Array = latest.data
	var latest_hips: Vector3 = Vector3(latest_pose[0], latest_pose[1], latest_pose[2]) / POSITION_QUANTIZATION
	var rendered_hips: Vector3 = skeleton.get_bone_global_pose(_hips_bone_index).origin
	if rendered_hips.distance_to(latest_hips) <= TUNING.HIPS_SYNC_TOLERANCE_M:
		return
	# Keep all bones together when an old interpolation sample falls behind.
	_apply_pose(latest_pose, latest_pose, 0.0)
	_remote_samples.clear()
	_remote_samples.append(latest)

func _capture_skeleton_pose() -> Array[Transform3D]:
	var poses: Array[Transform3D] = []
	poses.resize(skeleton.get_bone_count())
	for bone_index: int in range(skeleton.get_bone_count()):
		poses[bone_index] = skeleton.get_bone_global_pose(bone_index)
	return poses

func _begin_pose_blend(start_pose: Array[Transform3D], duration: float) -> void:
	if start_pose.size() != skeleton.get_bone_count() or duration <= 0.0:
		skeleton.reset_bone_poses()
		set_process(_remote_active)
		return
	_pose_blend_start = start_pose
	_pose_blend_target = _capture_skeleton_pose()
	_pose_blend_duration = duration
	_pose_blend_elapsed = 0.0
	_pose_blend_active = true
	set_process(true)
	debug_hub.call("log", &"limp", "Rig %s started get-up blend." % get_parent().name)

func _process_pose_blend(delta: float) -> void:
	_pose_blend_elapsed += delta
	var weight: float = clampf(_pose_blend_elapsed / _pose_blend_duration, 0.0, 1.0)
	var eased_weight: float = weight * weight * (3.0 - 2.0 * weight)
	for bone_index: int in range(_pose_blend_start.size()):
		var start: Transform3D = _pose_blend_start[bone_index]
		var target: Transform3D = _pose_blend_target[bone_index]
		var rotation: Quaternion = start.basis.get_rotation_quaternion().slerp(
			target.basis.get_rotation_quaternion(),
			eased_weight
		)
		skeleton.set_bone_global_pose(
			bone_index,
			Transform3D(Basis(rotation), start.origin.lerp(target.origin, eased_weight))
		)
	if weight < 1.0:
		return
	skeleton.reset_bone_poses()
	_pose_blend_active = false
	_pose_blend_start.clear()
	_pose_blend_target.clear()
	set_process(_remote_active)
	debug_hub.call("log", &"limp", "Rig %s completed get-up blend." % get_parent().name)

func _apply_pose(first: PackedInt32Array, second: PackedInt32Array, weight: float) -> void:
	for bone_number: int in range(EXPECTED_PHYSICAL_BONES):
		var offset: int = bone_number * POSE_VALUES_PER_BONE
		var first_position: Vector3 = Vector3(first[offset], first[offset + 1], first[offset + 2]) / POSITION_QUANTIZATION
		var second_position: Vector3 = Vector3(second[offset], second[offset + 1], second[offset + 2]) / POSITION_QUANTIZATION
		var first_rotation: Quaternion = Quaternion(first[offset + 3], first[offset + 4], first[offset + 5], first[offset + 6]).normalized()
		var second_rotation: Quaternion = Quaternion(second[offset + 3], second[offset + 4], second[offset + 5], second[offset + 6]).normalized()
		var pose: Transform3D = Transform3D(Basis(first_rotation.slerp(second_rotation, weight)), first_position.lerp(second_position, weight))
		skeleton.set_bone_global_pose(_bone_indices[bone_number], pose)
