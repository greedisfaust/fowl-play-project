## Host-simulated physical rig and client-rendered pose stream.
extends Node3D

const LAYERS = preload("res://core/layers.gd")
const TUNING = preload("res://core/tuning.gd")
const SELF_COLLISION = preload("res://ragdoll/self_collision_policy.gd")
const EXPECTED_PHYSICAL_BONES: int = 11
const POSE_VALUES_PER_BONE: int = 7
const POSITION_QUANTIZATION: float = 1000.0
const ROTATION_QUANTIZATION: float = 32767.0
const FACE_ORIENTATION_THRESHOLD: float = 0.35

@onready var simulator: PhysicalBoneSimulator3D = $Skeleton3D/PhysicalBoneSimulator3D
@onready var skeleton: Skeleton3D = $Skeleton3D
@onready var head_attachment: BoneAttachment3D = $Skeleton3D/HeadAttachment
@onready var recovery_animation_player: AnimationPlayer = get_node_or_null("RecoveryAnimationPlayer") as AnimationPlayer
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
var _chest_bone_index: int = -1
var _hips_physical_bone: PhysicalBone3D
var _pose_blend_active: bool = false
var _pose_blend_elapsed: float = 0.0
var _pose_blend_duration: float = 0.0
var _pose_blend_start: Array[Transform3D] = []
var _pose_blend_target: Array[Transform3D] = []
var _standing_pose: Array[Transform3D] = []
var _pending_recovery_animation: StringName = &""
var _recovery_animation_active: bool = false
var _carry_support_active: bool = false
var _carry_target_world: Vector3 = Vector3.ZERO
var _carry_facing_world: Vector3 = Vector3.ZERO
var _chest_physical_bone: PhysicalBone3D
var _carry_physics_active: bool = false
var _carry_saved_angular_damp: Dictionary = {}
var _carry_saved_chest_swing_span: float = 0.0
var _carry_saved_chest_twist_span: float = 0.0

# Strong, damped 6-DOF carry anchor. The Chest follows the carrier's
# CarryAnchor position and upright facing; spring damping gives slight lag
# without allowing the ragdoll limbs to spin the upper body away.
const CARRY_CHEST_SPRING_N_PER_M: float = 5000.0
const CARRY_CHEST_DAMPING_N_PER_MPS: float = 350.0
const CARRY_CHEST_MAX_FORCE_N: float = 18000.0
const CARRY_CHEST_ROTATION_STIFFNESS: float = 260.0
const CARRY_CHEST_ROTATION_DAMPING: float = 48.0
const CARRY_CHEST_MAX_TORQUE: float = 900.0

# Temporary rotational damping used only while this ragdoll is being carried.
const CARRY_TORSO_ANGULAR_DAMP: float = 4.0
const CARRY_ARM_ANGULAR_DAMP: float = 6.0
const CARRY_FOREARM_ANGULAR_DAMP: float = 7.0
const CARRY_HEAD_ANGULAR_DAMP: float = 3.0

func _enter_tree() -> void:
	# An editor animation preview can be saved in the skeleton's pose. Reset
	# BEFORE PhysicalBone3D children enter and construct their joint frames.
	# Resetting in _ready alone leaves those frames bound to the preview pose.
	var saved_skeleton: Skeleton3D = get_node("Skeleton3D") as Skeleton3D
	saved_skeleton.reset_bone_poses()

func _ready() -> void:
	_watch_name = StringName("rig/%s/physical_bones" % get_parent().name)
	simulator.physical_bones_stop_simulation()
	skeleton.reset_bone_poses()
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
			elif physical_bone.bone_name == "Chest":
				_chest_bone_index = _bone_indices[-1]
				_chest_physical_bone = physical_bone

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
	end_carry_physics()
	# Capture the standing pose before simulation overwrites it, so recovery
	# blends back to the actual standing pose instead of the rest/T-pose.
	if not _remote_active:
		_standing_pose = _capture_skeleton_pose()
	# The Player capsule can move independently; the simulated rig must not
	# inherit that transform or feed its own movement back through the parent.
	var world_transform: Transform3D = global_transform
	top_level = true
	global_transform = world_transform
	simulator.active = true
	_carry_support_active = false
	_latest_host_pose = PackedInt32Array()
	enable_host_collisions()
	for bone: PhysicalBone3D in physical_bones:
		bone.linear_velocity = Vector3.ZERO
		bone.angular_velocity = Vector3.ZERO
	simulator.physical_bones_start_simulation()
	return true

func stop_host_simulation() -> void:
	end_carry_physics()
	_carry_support_active = false
	_pose_blend_active = false
	_recovery_animation_active = false
	_pending_recovery_animation = &""
	_pose_blend_start.clear()
	_pose_blend_target.clear()
	if recovery_animation_player != null:
		recovery_animation_player.stop()
	simulator.physical_bones_stop_simulation()
	disable_collisions()
	skeleton.reset_bone_poses()
	top_level = false
	transform = Transform3D.IDENTITY
	_latest_host_pose = PackedInt32Array()

func stop_host_simulation_with_blend(duration: float, recovery_variant: StringName = &"") -> void:
	# Outside modification_processed the host skeleton can contain the
	# pre-physics (rest) pose. Reconstruct the same final sample sent to clients.
	var final_pose: PackedInt32Array = capture_quantized_pose()
	var old_skeleton_world: Transform3D = skeleton.global_transform
	stop_host_simulation()
	if valid_pose(final_pose):
		_apply_pose(final_pose, final_pose, 0.0)
	var start_pose: Array[Transform3D] = _capture_skeleton_pose()
	_rebase_pose(start_pose, skeleton.global_transform.affine_inverse() * old_skeleton_world)
	_begin_recovery(start_pose, duration, recovery_variant)

func is_pose_blending() -> bool:
	return _pose_blend_active or _recovery_animation_active

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

## Host-only spring support: chest follows the carrier anchor while hips,
## head and limbs remain free to sway under gravity and joint constraints.
func set_carry_target(target_world: Vector3, facing_world: Vector3 = Vector3.ZERO) -> void:
	if not simulator.is_simulating_physics() or _hips_physical_bone == null or not target_world.is_finite():
		return
	_carry_target_world = target_world
	if facing_world.is_finite() and Vector2(facing_world.x, facing_world.z).length_squared() > 0.0001:
		_carry_facing_world = Vector3(facing_world.x, 0.0, facing_world.z).normalized()
	_carry_support_active = true

func stop_carry_support() -> void:
	_carry_support_active = false
	_carry_facing_world = Vector3.ZERO

## Stabilize only the Hips-to-Chest joint while carried. The head joint and
## every limb joint remain simulated, so the head can look around and the legs
## can continue to dangle and limp. Original settings are restored on release.
func begin_carry_physics() -> void:
	if _carry_physics_active or not simulator.is_simulating_physics() or _chest_physical_bone == null:
		return
	_carry_saved_angular_damp.clear()
	for physical_bone: PhysicalBone3D in physical_bones:
		_carry_saved_angular_damp[physical_bone] = physical_bone.angular_damp
		match String(physical_bone.bone_name):
			"Hips", "Chest":
				physical_bone.angular_damp = CARRY_TORSO_ANGULAR_DAMP
			"Head":
				physical_bone.angular_damp = CARRY_HEAD_ANGULAR_DAMP
			"UpperArm_L", "UpperArm_R":
				physical_bone.angular_damp = CARRY_ARM_ANGULAR_DAMP
			"Forearm_L", "Forearm_R":
				physical_bone.angular_damp = CARRY_FOREARM_ANGULAR_DAMP
	_carry_saved_chest_swing_span = float(_chest_physical_bone.get("joint_constraints/swing_span"))
	_carry_saved_chest_twist_span = float(_chest_physical_bone.get("joint_constraints/twist_span"))
	# Near-zero spans make the ConeJoint behave like a fixed torso connection.
	# The Head remains a separate, freely constrained joint above the Chest.
	_chest_physical_bone.set("joint_constraints/swing_span", 0.05)
	_chest_physical_bone.set("joint_constraints/twist_span", 0.05)
	_carry_physics_active = true

## Restore the torso joint and every body's exact pre-carry damping values.
func end_carry_physics() -> void:
	if not _carry_physics_active:
		return
	if _chest_physical_bone != null:
		_chest_physical_bone.set("joint_constraints/swing_span", _carry_saved_chest_swing_span)
		_chest_physical_bone.set("joint_constraints/twist_span", _carry_saved_chest_twist_span)
	for physical_bone: PhysicalBone3D in physical_bones:
		if _carry_saved_angular_damp.has(physical_bone):
			physical_bone.angular_damp = float(_carry_saved_angular_damp[physical_bone])
	_carry_saved_angular_damp.clear()
	_carry_physics_active = false

func apply_carry_support() -> void:
	if not _carry_support_active or not simulator.is_simulating_physics() or _chest_physical_bone == null:
		return
	# The Chest itself is actively held at the carrier's CarryAnchor. This is
	# deliberately much firmer than the old spring so arm/leg forces cannot
	# drag the entire body away. All other bones remain physical.
	var displacement: Vector3 = _carry_target_world - _chest_physical_bone.global_position
	var force: Vector3 = displacement * CARRY_CHEST_SPRING_N_PER_M
	force -= _chest_physical_bone.linear_velocity * CARRY_CHEST_DAMPING_N_PER_MPS
	PhysicsServer3D.body_apply_central_force(_chest_physical_bone.get_rid(), force.limit_length(CARRY_CHEST_MAX_FORCE_N))
	_apply_carry_chest_orientation()

func _apply_carry_chest_orientation() -> void:
	if _chest_physical_bone == null or _carry_facing_world.length_squared() < 0.0001:
		return
	# Keep the Chest upright and facing the carrier's requested direction.
	# A full 3-axis spring resists pitch/roll as well as yaw, with damping
	# preserving a small delayed response when the carrier turns.
	var target_basis: Basis = Basis.looking_at(_carry_facing_world.normalized(), Vector3.UP)
	var target_rotation: Quaternion = target_basis.get_rotation_quaternion().normalized()
	var current_rotation: Quaternion = _chest_physical_bone.global_basis.get_rotation_quaternion().normalized()
	var rotation_error: Quaternion = (target_rotation * current_rotation.inverse()).normalized()
	if rotation_error.w < 0.0:
		rotation_error = Quaternion(-rotation_error.x, -rotation_error.y, -rotation_error.z, -rotation_error.w)
	var angular_error: Vector3 = rotation_error.get_axis() * rotation_error.get_angle()
	var torque: Vector3 = angular_error * CARRY_CHEST_ROTATION_STIFFNESS
	torque -= _chest_physical_bone.angular_velocity * CARRY_CHEST_ROTATION_DAMPING
	PhysicsServer3D.body_apply_torque(_chest_physical_bone.get_rid(), torque.limit_length(CARRY_CHEST_MAX_TORQUE))

func release_carry(linear: Vector3, angular: Vector3) -> void:
	_carry_support_active = false
	if not simulator.is_simulating_physics() or _hips_physical_bone == null:
		return
	_hips_physical_bone.linear_velocity = linear
	_hips_physical_bone.angular_velocity = angular

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
	# Capture the standing pose before limp overwrites it, so recovery
	# blends back to the actual standing pose instead of the rest/T-pose.
	_standing_pose = _capture_skeleton_pose()
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
	_recovery_animation_active = false
	_pending_recovery_animation = &""
	_pose_blend_start.clear()
	_pose_blend_target.clear()
	if recovery_animation_player != null:
		recovery_animation_player.stop()
	_remote_active = false
	_remote_samples.clear()
	set_process(false)
	disable_collisions()
	skeleton.reset_bone_poses()
	simulator.active = true
	top_level = false
	transform = Transform3D.IDENTITY

func end_remote_pose_with_blend(
	duration: float,
	final_pose: PackedInt32Array,
	recovery_variant: StringName = &""
) -> void:
	if valid_pose(final_pose):
		_apply_pose(final_pose, final_pose, 0.0)
	var start_pose: Array[Transform3D] = _capture_skeleton_pose()
	var old_skeleton_world: Transform3D = skeleton.global_transform
	end_remote_pose()
	_rebase_pose(start_pose, skeleton.global_transform.affine_inverse() * old_skeleton_world)
	_begin_recovery(start_pose, duration, recovery_variant)

func get_recovery_variant() -> StringName:
	if _chest_bone_index < 0:
		return &"get_up_face_up"
	var chest_pose: Transform3D = skeleton.get_bone_global_pose(_chest_bone_index)
	if simulator.is_simulating_physics() and valid_pose(_latest_host_pose):
		var offset: int = _bone_indices.find(_chest_bone_index) * POSE_VALUES_PER_BONE
		var rotation: Quaternion = Quaternion(_latest_host_pose[offset + 3], _latest_host_pose[offset + 4], _latest_host_pose[offset + 5], _latest_host_pose[offset + 6]).normalized()
		chest_pose.basis = Basis(rotation)
	var chest_forward: Vector3 = -(skeleton.global_basis * chest_pose.basis.z).normalized()
	var face_direction: float = chest_forward.dot(Vector3.UP)
	if absf(face_direction) >= FACE_ORIENTATION_THRESHOLD:
		return &"get_up_face_up" if face_direction > 0.0 else &"get_up_face_down"
	return &"get_up_face_up"

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
	if _recovery_animation_active:
		if recovery_animation_player != null and recovery_animation_player.is_playing():
			return
		_recovery_animation_active = false
		skeleton.reset_bone_poses()
		set_process(_remote_active)
		debug_hub.call("log", &"limp", "Rig %s completed authored recovery." % get_parent().name)
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

func _rebase_pose(poses: Array[Transform3D], old_to_new: Transform3D) -> void:
	for bone_index: int in range(poses.size()):
		poses[bone_index] = old_to_new * poses[bone_index]

func _to_local_pose(poses: Array[Transform3D]) -> Array[Transform3D]:
	var local_poses: Array[Transform3D] = []
	for bone_index: int in range(poses.size()):
		var parent_index: int = skeleton.get_bone_parent(bone_index)
		local_poses.append(poses[parent_index].affine_inverse() * poses[bone_index] if parent_index >= 0 else poses[bone_index])
	return local_poses

func _begin_recovery(start_pose: Array[Transform3D], duration: float, recovery_variant: StringName) -> void:
	if start_pose.size() != skeleton.get_bone_count() or duration <= 0.0:
		skeleton.reset_bone_poses()
		set_process(_remote_active)
		return
	_pending_recovery_animation = &""
	if _prepare_recovery_animation(recovery_variant):
		_pending_recovery_animation = recovery_variant
		# Blend straight into the authored opening, never via standing/T-pose.
		_pose_blend_target = _to_local_pose(_capture_skeleton_pose())
	elif _standing_pose.size() == skeleton.get_bone_count():
		_pose_blend_target = _to_local_pose(_standing_pose)
	else:
		_pose_blend_target = _to_local_pose(_capture_skeleton_pose())
	_pose_blend_start = _to_local_pose(start_pose)
	for bone_index: int in range(start_pose.size()):
		skeleton.set_bone_global_pose(bone_index, start_pose[bone_index])
	_pose_blend_duration = duration
	_pose_blend_elapsed = 0.0
	_pose_blend_active = true
	set_process(true)
	debug_hub.call("log", &"limp", "Rig %s started get-up blend." % get_parent().name)

func _prepare_recovery_animation(recovery_variant: StringName) -> bool:
	if recovery_animation_player == null or recovery_variant == &"":
		return false
	var library: AnimationLibrary = recovery_animation_player.get_animation_library(&"")
	if library == null or not library.has_animation(recovery_variant):
		debug_hub.call("warn", &"limp", "Rig %s missing recovery clip %s; using procedural fallback." % [get_parent().name, recovery_variant])
		return false
	recovery_animation_player.play(recovery_variant, 0.0)
	recovery_animation_player.seek(0.0, true)
	recovery_animation_player.pause()
	return true

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
		skeleton.set_bone_pose(
			bone_index,
			Transform3D(Basis(rotation), start.origin.lerp(target.origin, eased_weight))
		)
	if weight < 1.0:
		return
	_pose_blend_active = false
	_pose_blend_start.clear()
	_pose_blend_target.clear()
	if _pending_recovery_animation != &"" and recovery_animation_player != null:
		recovery_animation_player.play(_pending_recovery_animation, 0.0)
		recovery_animation_player.seek(0.0, true)
		_recovery_animation_active = true
		debug_hub.call("log", &"limp", "Rig %s playing authored recovery %s." % [get_parent().name, _pending_recovery_animation])
	else:
		skeleton.reset_bone_poses()
	_pending_recovery_animation = &""
	set_process(_remote_active or _recovery_animation_active)
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
