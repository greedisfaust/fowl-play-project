## Host-simulated physical rig and client-rendered pose stream.
extends Node3D

const LAYERS = preload("res://core/layers.gd")
const TUNING = preload("res://core/tuning.gd")
const SELF_COLLISION = preload("res://ragdoll/self_collision_policy.gd")
const ARM_IK = preload("res://ragdoll/procedural_arm_ik.gd")
const LEG_CONTROLLER_SCRIPT = preload("res://ragdoll/procedural_leg_controller.gd")
const FOOT_PLANT_SCRIPT = preload("res://ragdoll/procedural_foot_plant.gd")
const FOOTSTEP_PLANNER_SCRIPT = preload("res://ragdoll/procedural_footstep_planner.gd")
const LEG_IK = preload("res://ragdoll/procedural_arm_ik.gd")
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
var _left_thigh_bone_index: int = -1
var _left_shin_bone_index: int = -1
var _left_foot_bone_index: int = -1
var _right_thigh_bone_index: int = -1
var _right_shin_bone_index: int = -1
var _right_foot_bone_index: int = -1
var _leg_controller: RefCounted = LEG_CONTROLLER_SCRIPT.new()
var _left_foot_plant: RefCounted = FOOT_PLANT_SCRIPT.new()
var _right_foot_plant: RefCounted = FOOT_PLANT_SCRIPT.new()
var _footstep_planner: RefCounted = FOOTSTEP_PLANNER_SCRIPT.new()
var _left_foot_grounded: bool = false
var _right_foot_grounded: bool = false
var _left_foot_ground_target_world: Vector3 = Vector3.ZERO
var _right_foot_ground_target_world: Vector3 = Vector3.ZERO
var _left_foot_ground_normal: Vector3 = Vector3.UP
var _right_foot_ground_normal: Vector3 = Vector3.UP
var _left_leg_ik_weight: float = 0.0
var _right_leg_ik_weight: float = 0.0
var _left_leg_ik_active: bool = false
var _right_leg_ik_active: bool = false
var _left_ground_probe: Dictionary = {}
var _right_ground_probe: Dictionary = {}
var _last_leg_world_velocity: Vector3 = Vector3.ZERO
var _leg_ground_status_command_name: StringName
var _leg_pose_active: bool = false
var _leg_status_watch_name: StringName
var _leg_status_command_name: StringName
var _chest_bone_index: int = -1
var _right_viewmodel_upper_arm_bone_index: int = -1
var _right_viewmodel_forearm_bone_index: int = -1
var _right_viewmodel_hand_bone_index: int = -1
var _left_viewmodel_upper_arm_bone_index: int = -1
var _left_viewmodel_forearm_bone_index: int = -1
var _left_viewmodel_hand_bone_index: int = -1
var _right_arm_ik_watch_name: StringName
var _left_arm_ik_watch_name: StringName
var _right_arm_ik_command_name: StringName
var _left_arm_ik_command_name: StringName
var _right_rig_hand_visible_watch_name: StringName
var _left_rig_hand_visible_watch_name: StringName
var _right_rig_hand_visuals: Array[VisualInstance3D] = []
var _left_rig_hand_visuals: Array[VisualInstance3D] = []
var _right_arm_ik_active: bool = false
var _left_arm_ik_active: bool = false
var _right_arm_ik_target_world: Vector3 = Vector3.ZERO
var _left_arm_ik_target_world: Vector3 = Vector3.ZERO
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
var _head_physical_bone: PhysicalBone3D
var _chest_rest_basis_offset: Basis = Basis.IDENTITY
var _carry_physics_active: bool = false
var _carry_saved_angular_damp: Dictionary = {}
var _carry_saved_chest_swing_span: float = 0.0
var _carry_saved_chest_twist_span: float = 0.0
var _carry_saved_head_swing_span: float = 0.0
var _carry_saved_head_twist_span: float = 0.0
var _player_tinted_geometry: Array[GeometryInstance3D] = []
var _player_original_materials: Array[Material] = []

## Apply the network-assigned identity color to the visible rig and its attached hands.
## FacePhoto is intentionally excluded; it is a temporary placeholder.
func set_player_color(new_color: Color) -> void:
	_restore_player_color()
	for candidate: Node in find_children("*", "GeometryInstance3D", true, false):
		var geometry: GeometryInstance3D = candidate as GeometryInstance3D
		if geometry == null or geometry.name == &"FacePhoto" or _is_attached_hand_visual(geometry):
			continue
		var original: Material = geometry.material_override
		if original == null and geometry is CSGShape3D:
			original = (geometry as CSGShape3D).material
		if original == null and geometry is MeshInstance3D:
			var mesh_instance: MeshInstance3D = geometry as MeshInstance3D
			if mesh_instance.mesh != null and mesh_instance.mesh.get_surface_count() > 0:
				original = mesh_instance.mesh.surface_get_material(0)
		var tinted: BaseMaterial3D
		if original is BaseMaterial3D:
			tinted = (original as BaseMaterial3D).duplicate() as BaseMaterial3D
		else:
			tinted = StandardMaterial3D.new()
		var shade: float = 1.0
		if original is BaseMaterial3D:
			shade = (original as BaseMaterial3D).albedo_color.v
		tinted.albedo_color = Color(new_color.r * shade, new_color.g * shade, new_color.b * shade, 1.0)
		_player_tinted_geometry.append(geometry)
		_player_original_materials.append(geometry.material_override)
		geometry.material_override = tinted

	var right_hand: Hand = get_node_or_null("Skeleton3D/HandAttachment_R/HandMount_R/Hand") as Hand
	var left_hand: Hand = get_node_or_null("Skeleton3D/HandAttachment_L/HandMount_L/Hand") as Hand
	if right_hand != null:
		right_hand.set_color(new_color)
	if left_hand != null:
		left_hand.set_color(new_color)

func _is_attached_hand_visual(geometry: GeometryInstance3D) -> bool:
	var ancestor: Node = geometry.get_parent()
	while ancestor != null and ancestor != self:
		if ancestor is Hand:
			return true
		ancestor = ancestor.get_parent()
	return false

func _restore_player_color() -> void:
	for index: int in _player_tinted_geometry.size():
		var geometry: GeometryInstance3D = _player_tinted_geometry[index]
		if is_instance_valid(geometry):
			geometry.material_override = _player_original_materials[index]
	_player_tinted_geometry.clear()
	_player_original_materials.clear()

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
const CARRY_ARM_ANGULAR_DAMP: float = 9.0
const CARRY_FOREARM_ANGULAR_DAMP: float = 11.0
const ARM_IK_BLEND_SPEED: float = 18.0
const ARM_IK_POLE_FORWARD_WEIGHT: float = 0.22
const ARM_IK_MAX_STRETCH_RATIO: float = 1.12
const LEG_GROUND_PROBE_UP_M: float = 0.35
const LEG_GROUND_PROBE_DOWN_M: float = 0.85
const LEG_GROUND_FOOT_CLEARANCE_M: float = 0.04
const LEG_GROUND_MIN_NORMAL_Y: float = 0.45
const LEG_IK_BLEND_RESPONSE: float = 14.0
const LEG_IK_POLE_FORWARD_WEIGHT: float = 1.0
const CARRY_HEAD_ANGULAR_DAMP: float = 12.0

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
			elif physical_bone.bone_name == "Head":
				_head_physical_bone = physical_bone
	if _chest_physical_bone != null:
		# PhysicalBone's local axes follow the skeleton bone's bind orientation,
		# not the character's forward axis. Preserve that bind-space offset.
		_chest_rest_basis_offset = global_basis.inverse() * _chest_physical_bone.global_basis

	_left_thigh_bone_index = skeleton.find_bone("Thigh_L")
	_left_shin_bone_index = skeleton.find_bone("Shin_L")
	_left_foot_bone_index = skeleton.find_bone("Foot_L")
	_right_thigh_bone_index = skeleton.find_bone("Thigh_R")
	_right_shin_bone_index = skeleton.find_bone("Shin_R")
	_right_foot_bone_index = skeleton.find_bone("Foot_R")
	_right_viewmodel_upper_arm_bone_index = skeleton.find_bone("UpperArm_L")
	_right_viewmodel_forearm_bone_index = skeleton.find_bone("Forearm_L")
	_right_viewmodel_hand_bone_index = skeleton.find_bone("Hand_L")
	_left_viewmodel_upper_arm_bone_index = skeleton.find_bone("UpperArm_R")
	_left_viewmodel_forearm_bone_index = skeleton.find_bone("Forearm_R")
	_left_viewmodel_hand_bone_index = skeleton.find_bone("Hand_R")
	var right_rig_hand_root: Node = get_node_or_null("Skeleton3D/HandAttachment_L/HandMount_L/Hand")
	_right_rig_hand_visuals.clear()
	if right_rig_hand_root != null:
		for visual_node: Node in right_rig_hand_root.find_children("*", "VisualInstance3D", true, false):
			if visual_node.name == &"Forearm":
				continue
			var visual_instance: VisualInstance3D = visual_node as VisualInstance3D
			if visual_instance != null:
				_right_rig_hand_visuals.append(visual_instance)
	_right_rig_hand_visible_watch_name = StringName("rig/%s/right_rig_hand_visible" % get_parent().name)
	_set_right_rig_hand_visual_visible(false)
	var left_rig_hand_root: Node = get_node_or_null("Skeleton3D/HandAttachment_R/HandMount_R/Hand")
	_left_rig_hand_visuals.clear()
	if left_rig_hand_root != null:
		for left_visual_node: Node in left_rig_hand_root.find_children("*", "VisualInstance3D", true, false):
			if left_visual_node.name == &"Forearm":
				continue
			var left_visual_instance: VisualInstance3D = left_visual_node as VisualInstance3D
			if left_visual_instance != null:
				_left_rig_hand_visuals.append(left_visual_instance)
	_left_rig_hand_visible_watch_name = StringName("rig/%s/left_rig_hand_visible" % get_parent().name)
	_set_left_rig_hand_visual_visible(false)
	_leg_status_watch_name = StringName("rig/%s/legs_active" % get_parent().name)
	_leg_status_command_name = StringName("leg_status_%s" % get_parent().name)
	_leg_ground_status_command_name = StringName("leg_ground_%s" % get_parent().name)
	_right_arm_ik_watch_name = StringName("rig/%s/right_arm_ik" % get_parent().name)
	_right_arm_ik_command_name = StringName("arm_ik_status_%s" % get_parent().name)
	_left_arm_ik_watch_name = StringName("rig/%s/left_arm_ik" % get_parent().name)
	_left_arm_ik_command_name = StringName("arm_ik_status_left_%s" % get_parent().name)
	var self_contact_pairs: int = SELF_COLLISION.configure(physical_bones)

	if physical_bones.size() != EXPECTED_PHYSICAL_BONES:
		debug_hub.call("warn", &"ragdoll", "Rig %s has %d physical bones; expected %d." % [get_parent().name, physical_bones.size(), EXPECTED_PHYSICAL_BONES])
	else:
		debug_hub.call("log", &"ragdoll", "Rig %s prepared 11 dormant physical bones; %d selective self-contact pairs." % [get_parent().name, self_contact_pairs])
	debug_hub.call("watch", _watch_name, func() -> int: return physical_bones.size())
	debug_hub.call("watch", _leg_status_watch_name, func() -> bool: return _leg_pose_active)
	debug_hub.call("command", _leg_status_command_name, _debug_leg_status, "Report this player procedural leg gait state.", false, false)
	debug_hub.call("command", _leg_ground_status_command_name, _debug_leg_ground_status, "Report both procedural foot ground probes and world-space targets.", false, false)
	debug_hub.call("watch", _right_arm_ik_watch_name, func() -> bool: return _right_arm_ik_active)
	debug_hub.call("watch", _right_rig_hand_visible_watch_name, _is_right_rig_hand_visual_visible)
	debug_hub.call("watch", _left_arm_ik_watch_name, func() -> bool: return _left_arm_ik_active)
	debug_hub.call("watch", _left_rig_hand_visible_watch_name, _is_left_rig_hand_visual_visible)
	debug_hub.call("command", _right_arm_ik_command_name, _debug_right_arm_ik_status, "Report the procedural Viewmodel right-arm target and ownership state.", false, false)
	debug_hub.call("command", _left_arm_ik_command_name, _debug_left_arm_ik_status, "Report the procedural Viewmodel left-arm target and ownership state.", false, false)
	set_process(false)
	set_physics_process(true)

func _exit_tree() -> void:
	if is_instance_valid(debug_hub):
		debug_hub.call("unwatch", _watch_name)
		debug_hub.call("unwatch", _leg_status_watch_name)
		debug_hub.call("unregister_command", _leg_status_command_name)
		debug_hub.call("unregister_command", _leg_ground_status_command_name)
		debug_hub.call("unwatch", _right_arm_ik_watch_name)
		debug_hub.call("unwatch", _left_arm_ik_watch_name)
		debug_hub.call("unwatch", _right_rig_hand_visible_watch_name)
		debug_hub.call("unwatch", _left_rig_hand_visible_watch_name)
		debug_hub.call("unregister_command", _right_arm_ik_command_name)
		debug_hub.call("unregister_command", _left_arm_ik_command_name)

## The positive-X Rig hand is a duplicate of the camera-attached Viewmodel hand while standing.
## Keep its node and skeleton attachment intact; only its rendered hand instance changes visibility.
func _is_right_rig_hand_visual_visible() -> bool:
	for visual_instance: VisualInstance3D in _right_rig_hand_visuals:
		if is_instance_valid(visual_instance) and visual_instance.visible:
			return true
	return false

func _set_right_rig_hand_visual_visible(visible: bool) -> void:
	for visual_instance: VisualInstance3D in _right_rig_hand_visuals:
		if is_instance_valid(visual_instance):
			visual_instance.visible = visible

func _is_left_rig_hand_visual_visible() -> bool:
	for visual_instance: VisualInstance3D in _left_rig_hand_visuals:
		if is_instance_valid(visual_instance) and visual_instance.visible:
			return true
	return false

func _set_left_rig_hand_visual_visible(visible: bool) -> void:
	for visual_instance: VisualInstance3D in _left_rig_hand_visuals:
		if is_instance_valid(visual_instance):
			visual_instance.visible = visible

## Viewmodel right is positive X / Rig suffix L; Viewmodel left is negative X / Rig suffix R.
func _set_right_arm_ik_active(active: bool) -> void:
	if not active:
		_reset_arm_pose_scale(_right_viewmodel_upper_arm_bone_index, _right_viewmodel_forearm_bone_index)
	if _right_arm_ik_active == active:
		return
	_right_arm_ik_active = active
	debug_hub.call("log", &"hands", "Rig %s Viewmodel-right arm IK %s." % [
		get_parent().name, "active" if active else "yielded"
	])

func _set_left_arm_ik_active(active: bool) -> void:
	if not active:
		_reset_arm_pose_scale(_left_viewmodel_upper_arm_bone_index, _left_viewmodel_forearm_bone_index)
	if _left_arm_ik_active == active:
		return
	_left_arm_ik_active = active
	debug_hub.call("log", &"hands", "Rig %s Viewmodel-left arm IK %s." % [
		get_parent().name, "active" if active else "yielded"
	])

func _debug_right_arm_ik_status(_args: Array[Variant]) -> String:
	return "active=%s target=%s upper_scale=%s forearm_scale=%s bones=UpperArm_L/Forearm_L/Hand_L" % [
		_right_arm_ik_active, _right_arm_ik_target_world,
		skeleton.get_bone_pose_scale(_right_viewmodel_upper_arm_bone_index),
		skeleton.get_bone_pose_scale(_right_viewmodel_forearm_bone_index)
	]

func _debug_left_arm_ik_status(_args: Array[Variant]) -> String:
	return "active=%s target=%s upper_scale=%s forearm_scale=%s bones=UpperArm_R/Forearm_R/Hand_R" % [
		_left_arm_ik_active, _left_arm_ik_target_world,
		skeleton.get_bone_pose_scale(_left_viewmodel_upper_arm_bone_index),
		skeleton.get_bone_pose_scale(_left_viewmodel_forearm_bone_index)
	]

func _bone_axis_scale(rest_offset: Vector3, amount: float) -> Vector3:
	var result: Vector3 = Vector3.ONE
	var axis_x: float = absf(rest_offset.x)
	var axis_y: float = absf(rest_offset.y)
	var axis_z: float = absf(rest_offset.z)
	if axis_x >= axis_y and axis_x >= axis_z:
		result.x = amount
	elif axis_y >= axis_z:
		result.y = amount
	else:
		result.z = amount
	return result

func _bone_axis_scale_value(rest_offset: Vector3, pose_scale: Vector3) -> float:
	var axis_x: float = absf(rest_offset.x)
	var axis_y: float = absf(rest_offset.y)
	var axis_z: float = absf(rest_offset.z)
	if axis_x >= axis_y and axis_x >= axis_z:
		return pose_scale.x
	if axis_y >= axis_z:
		return pose_scale.y
	return pose_scale.z

func _reset_arm_pose_scale(upper_index: int, forearm_index: int) -> void:
	if upper_index >= 0:
		skeleton.set_bone_pose_scale(upper_index, Vector3.ONE)
	if forearm_index >= 0:
		skeleton.set_bone_pose_scale(forearm_index, Vector3.ONE)

func _update_procedural_arm_chain(
	upper_index: int,
	forearm_index: int,
	hand_index: int,
	wrist_target_world: Vector3,
	delta: float
) -> bool:
	if upper_index < 0 or forearm_index < 0 or hand_index < 0:
		return false
	if simulator.is_simulating_physics() or _remote_active or _pose_blend_active or _recovery_animation_active:
		return false
	if not wrist_target_world.is_finite():
		return false
	skeleton.force_update_all_bone_transforms()
	var shoulder_local: Vector3 = skeleton.get_bone_global_pose(upper_index).origin
	var shoulder_world: Vector3 = skeleton.to_global(shoulder_local)
	var upper_rest_offset: Vector3 = skeleton.get_bone_rest(forearm_index).origin
	var forearm_rest_offset: Vector3 = skeleton.get_bone_rest(hand_index).origin
	var base_upper_length: float = upper_rest_offset.length()
	var base_forearm_length: float = forearm_rest_offset.length()
	var base_reach: float = base_upper_length + base_forearm_length
	var target_distance: float = shoulder_world.distance_to(wrist_target_world)
	var target_stretch_ratio: float = clampf(target_distance / maxf(base_reach, 0.001), 1.0, ARM_IK_MAX_STRETCH_RATIO)
	var blend_weight: float = 1.0 - exp(-ARM_IK_BLEND_SPEED * maxf(delta, 0.0))
	var current_stretch_ratio: float = _bone_axis_scale_value(upper_rest_offset, skeleton.get_bone_pose_scale(upper_index))
	var stretch_ratio: float = lerpf(current_stretch_ratio, target_stretch_ratio, blend_weight)
	var upper_length: float = base_upper_length * stretch_ratio
	var forearm_length: float = base_forearm_length * stretch_ratio
	# Scale only along each bone chain axis. This is a small cosmetic extension
	# while standing; ragdoll ownership resets these scales before physics starts.
	skeleton.set_bone_pose_scale(upper_index, _bone_axis_scale(upper_rest_offset, stretch_ratio))
	skeleton.set_bone_pose_scale(forearm_index, _bone_axis_scale(forearm_rest_offset, stretch_ratio))
	skeleton.force_update_all_bone_transforms()
	var pole_world: Vector3 = (global_basis * (Vector3.DOWN + Vector3.BACK * ARM_IK_POLE_FORWARD_WEIGHT)).normalized()
	var solution: Dictionary = ARM_IK.solve_two_bone(shoulder_world, wrist_target_world, pole_world, upper_length, forearm_length)
	if solution.is_empty():
		return false
	var elbow_world: Vector3 = solution["elbow"]
	var parent_index: int = skeleton.get_bone_parent(upper_index)
	var chest_world_basis: Basis = skeleton.global_basis * skeleton.get_bone_global_pose(parent_index).basis
	var upper_direction_parent: Vector3 = chest_world_basis.inverse() * (elbow_world - shoulder_world).normalized()
	var upper_rest_axis: Vector3 = skeleton.get_bone_rest(forearm_index).origin.normalized()
	var upper_target_rotation: Quaternion = Quaternion(upper_rest_axis, upper_direction_parent.normalized())
	var upper_current: Quaternion = skeleton.get_bone_pose_rotation(upper_index)
	skeleton.set_bone_pose_rotation(upper_index, upper_current.slerp(upper_target_rotation, blend_weight))
	skeleton.force_update_all_bone_transforms()
	var elbow_local: Vector3 = skeleton.get_bone_global_pose(forearm_index).origin
	var elbow_actual_world: Vector3 = skeleton.to_global(elbow_local)
	var upper_world_basis: Basis = skeleton.global_basis * skeleton.get_bone_global_pose(upper_index).basis
	var forearm_direction_local: Vector3 = upper_world_basis.inverse() * (wrist_target_world - elbow_actual_world).normalized()
	var forearm_rest_axis: Vector3 = skeleton.get_bone_rest(hand_index).origin.normalized()
	var forearm_target_rotation: Quaternion = Quaternion(forearm_rest_axis, forearm_direction_local.normalized())
	var forearm_current: Quaternion = skeleton.get_bone_pose_rotation(forearm_index)
	skeleton.set_bone_pose_rotation(forearm_index, forearm_current.slerp(forearm_target_rotation, blend_weight))
	skeleton.force_update_all_bone_transforms()
	return true

func _physics_process(_delta: float) -> void:
	if simulator.is_simulating_physics() or _remote_active or _pose_blend_active or _recovery_animation_active:
		_left_ground_probe.clear()
		_right_ground_probe.clear()
		return
	if _left_foot_bone_index < 0 or _right_foot_bone_index < 0:
		return
	# Landing probes are calculated after the gait update, from hip-relative
	# planner targets, inside update_procedural_legs().
	_left_ground_probe.clear()
	_right_ground_probe.clear()

func _probe_ground_at_target(foot_world: Vector3) -> Dictionary:
	if not foot_world.is_finite():
		return {}
	# The planner supplies a hip-relative landing point. Probe vertically at
	# that point instead of projecting a long distance from the trailing foot.
	var probe_origin: Vector3 = foot_world + Vector3.UP * LEG_GROUND_PROBE_UP_M
	var probe_end: Vector3 = foot_world - Vector3.UP * LEG_GROUND_PROBE_DOWN_M
	var ground_mask: int = (1 << (LAYERS.WORLD_STATIC - 1)) | (1 << (LAYERS.PROPS - 1)) | (1 << (LAYERS.ELEVATOR - 1))
	var excluded: Array[RID] = []
	var player_body: CollisionObject3D = get_parent() as CollisionObject3D
	if player_body != null:
		excluded.append(player_body.get_rid())
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(probe_origin, probe_end, ground_mask, excluded)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var world: World3D = get_world_3d()
	if world == null:
		return {}
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var hit_normal: Vector3 = hit.get("normal", Vector3.UP)
	if hit_normal.y < LEG_GROUND_MIN_NORMAL_Y:
		return {}
	return {
		"position": hit.get("position", foot_world) + Vector3.UP * LEG_GROUND_FOOT_CLEARANCE_M,
		"normal": hit_normal,
		"collider": hit.get("collider")
	}

func _apply_procedural_leg_ik(
	thigh_index: int,
	shin_index: int,
	foot_index: int,
	foot_target_world: Vector3,
	foot_ground_normal: Vector3,
	base_thigh_rotation: Quaternion,
	base_shin_rotation: Quaternion,
	base_foot_rotation: Quaternion,
	ik_weight: float
) -> bool:
	if thigh_index < 0 or shin_index < 0 or foot_index < 0 or not foot_target_world.is_finite():
		return false
	skeleton.force_update_all_bone_transforms()
	var hip_local: Vector3 = skeleton.get_bone_global_pose(thigh_index).origin
	var hip_world: Vector3 = skeleton.to_global(hip_local)
	var upper_rest_offset: Vector3 = skeleton.get_bone_rest(shin_index).origin
	var lower_rest_offset: Vector3 = skeleton.get_bone_rest(foot_index).origin
	var upper_length: float = upper_rest_offset.length()
	var lower_length: float = lower_rest_offset.length()
	var parent_index: int = skeleton.get_bone_parent(thigh_index)
	if parent_index < 0 or upper_length <= 0.001 or lower_length <= 0.001:
		return false
	var parent_world_basis: Basis = skeleton.global_basis * skeleton.get_bone_global_pose(parent_index).basis
	var pole_world: Vector3 = hip_world + global_basis * Vector3.FORWARD * LEG_IK_POLE_FORWARD_WEIGHT
	var solution: Dictionary = LEG_IK.solve_two_bone(
		hip_world, foot_target_world, pole_world, upper_length, lower_length
	)
	if solution.is_empty():
		return false
	var knee_world: Vector3 = solution["elbow"]
	var upper_direction_parent: Vector3 = parent_world_basis.inverse() * (knee_world - hip_world).normalized()
	var upper_rest_axis: Vector3 = upper_rest_offset.normalized()
	var upper_target_rotation: Quaternion = Quaternion(upper_rest_axis, upper_direction_parent.normalized())
	var blend_weight: float = clampf(ik_weight, 0.0, 1.0)
	var blended_thigh: Quaternion = base_thigh_rotation.slerp(upper_target_rotation, blend_weight)
	skeleton.set_bone_pose_rotation(thigh_index, blended_thigh)
	skeleton.force_update_all_bone_transforms()
	var actual_knee_local: Vector3 = skeleton.get_bone_global_pose(shin_index).origin
	var actual_knee_world: Vector3 = skeleton.to_global(actual_knee_local)
	var thigh_world_basis: Basis = skeleton.global_basis * skeleton.get_bone_global_pose(thigh_index).basis
	var lower_direction_local: Vector3 = thigh_world_basis.inverse() * (foot_target_world - actual_knee_world).normalized()
	var lower_rest_axis: Vector3 = lower_rest_offset.normalized()
	var lower_target_rotation: Quaternion = Quaternion(lower_rest_axis, lower_direction_local.normalized())
	var blended_shin: Quaternion = base_shin_rotation.slerp(lower_target_rotation, blend_weight)
	skeleton.set_bone_pose_rotation(shin_index, blended_shin)
	skeleton.force_update_all_bone_transforms()
	var foot_parent_index: int = skeleton.get_bone_parent(foot_index)
	if foot_parent_index >= 0 and foot_ground_normal.is_finite() and foot_ground_normal.length_squared() > 0.5:
		var foot_parent_world_basis: Basis = skeleton.global_basis * skeleton.get_bone_global_pose(foot_parent_index).basis
		var normal_parent_local: Vector3 = (foot_parent_world_basis.inverse() * foot_ground_normal.normalized()).normalized()
		var foot_surface_rotation: Quaternion = Quaternion(Vector3.UP, normal_parent_local)
		var blended_foot: Quaternion = base_foot_rotation.slerp(foot_surface_rotation, blend_weight)
		skeleton.set_bone_pose_rotation(foot_index, blended_foot)
	return true

func update_procedural_legs(world_velocity: Vector3, grounded: bool, delta: float) -> bool:
	if _left_thigh_bone_index < 0 or _left_shin_bone_index < 0 or _left_foot_bone_index < 0:
		return false
	if _right_thigh_bone_index < 0 or _right_shin_bone_index < 0 or _right_foot_bone_index < 0:
		return false
	if simulator.is_simulating_physics() or _remote_active or _pose_blend_active or _recovery_animation_active:
		_leg_pose_active = false
		_left_foot_grounded = false
		_right_foot_grounded = false
		_left_foot_plant.call("reset")
		_right_foot_plant.call("reset")
		_left_leg_ik_weight = 0.0
		_right_leg_ik_weight = 0.0
		_left_leg_ik_active = false
		_right_leg_ik_active = false
		return false
	if not world_velocity.is_finite():
		return false
	_last_leg_world_velocity = world_velocity
	var local_velocity: Vector3 = global_basis.inverse() * world_velocity
	_leg_controller.call("update", delta, local_velocity, grounded)
	skeleton.force_update_all_bone_transforms()
	var left_foot_world: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(_left_foot_bone_index).origin)
	var right_foot_world: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(_right_foot_bone_index).origin)
	var left_hip_world: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(_left_thigh_bone_index).origin)
	var right_hip_world: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(_right_thigh_bone_index).origin)
	var hip_center_world: Vector3 = (left_hip_world + right_hip_world) * 0.5
	var planner_velocity: Vector3 = _leg_controller.get("smoothed_velocity")
	var left_landing_world: Vector3 = left_foot_world
	var right_landing_world: Vector3 = right_foot_world
	# Only swing feet request a new hip-relative landing point. During stance,
	# probe the current sole so initialization and stopping cannot pull feet
	# toward an artificial forward target.
	if bool(_leg_controller.get("left_in_swing")) and planner_velocity.length() > TUNING.LEG_MIN_WALK_SPEED_MPS:
		left_landing_world = _footstep_planner.call(
			"get_landing_target", hip_center_world, global_basis, planner_velocity, -1.0,
			0.0, 0.18, TUNING.LEG_STEP_CYCLE_DISTANCE_M * (1.0 - TUNING.LEG_STANCE_FRACTION)
		)
	if bool(_leg_controller.get("right_in_swing")) and planner_velocity.length() > TUNING.LEG_MIN_WALK_SPEED_MPS:
		right_landing_world = _footstep_planner.call(
			"get_landing_target", hip_center_world, global_basis, planner_velocity, 1.0,
			0.0, 0.18, TUNING.LEG_STEP_CYCLE_DISTANCE_M * (1.0 - TUNING.LEG_STANCE_FRACTION)
		)
	# Keep each probe at its current sole height; only X/Z come from the hip zone.
	left_landing_world.y = left_foot_world.y
	right_landing_world.y = right_foot_world.y
	_left_ground_probe = _probe_ground_at_target(left_landing_world)
	_right_ground_probe = _probe_ground_at_target(right_landing_world)
	var left_ground_hit: Dictionary = _left_ground_probe
	var right_ground_hit: Dictionary = _right_ground_probe
	_left_foot_grounded = grounded and not left_ground_hit.is_empty()
	_right_foot_grounded = grounded and not right_ground_hit.is_empty()
	_left_foot_ground_target_world = left_ground_hit.get("position", left_foot_world)
	_right_foot_ground_target_world = right_ground_hit.get("position", right_foot_world)
	_left_foot_ground_normal = left_ground_hit.get("normal", Vector3.UP)
	_right_foot_ground_normal = right_ground_hit.get("normal", Vector3.UP)
	var left_target: Vector3 = _left_foot_plant.call(
		"update_target", left_foot_world, _left_foot_ground_target_world,
		_left_foot_grounded, bool(_leg_controller.get("left_in_swing")),
		float(_leg_controller.get("left_swing_progress")), 0.12
	)
	var right_target: Vector3 = _right_foot_plant.call(
		"update_target", right_foot_world, _right_foot_ground_target_world,
		_right_foot_grounded, bool(_leg_controller.get("right_in_swing")),
		float(_leg_controller.get("right_swing_progress")), 0.12
	)
	_left_foot_ground_target_world = left_target
	_right_foot_ground_target_world = right_target
	var left_thigh_rotation: Quaternion = _leg_controller.get("left_thigh_rotation")
	var left_shin_rotation: Quaternion = _leg_controller.get("left_shin_rotation")
	var left_foot_rotation: Quaternion = _leg_controller.get("left_foot_rotation")
	var right_thigh_rotation: Quaternion = _leg_controller.get("right_thigh_rotation")
	var right_shin_rotation: Quaternion = _leg_controller.get("right_shin_rotation")
	var right_foot_rotation: Quaternion = _leg_controller.get("right_foot_rotation")
	skeleton.set_bone_pose_rotation(_left_thigh_bone_index, left_thigh_rotation)
	skeleton.set_bone_pose_rotation(_left_shin_bone_index, left_shin_rotation)
	skeleton.set_bone_pose_rotation(_left_foot_bone_index, left_foot_rotation)
	skeleton.set_bone_pose_rotation(_right_thigh_bone_index, right_thigh_rotation)
	skeleton.set_bone_pose_rotation(_right_shin_bone_index, right_shin_rotation)
	skeleton.set_bone_pose_rotation(_right_foot_bone_index, right_foot_rotation)
	var left_ik_target_weight: float = 1.0 if _left_foot_plant.get("has_anchor") else 0.0
	var right_ik_target_weight: float = 1.0 if _right_foot_plant.get("has_anchor") else 0.0
	var ik_blend: float = 1.0 - exp(-LEG_IK_BLEND_RESPONSE * maxf(delta, 0.0))
	_left_leg_ik_weight = lerpf(_left_leg_ik_weight, left_ik_target_weight, ik_blend)
	_right_leg_ik_weight = lerpf(_right_leg_ik_weight, right_ik_target_weight, ik_blend)
	if _left_leg_ik_weight > 0.01:
		var left_ik_applied: bool = _apply_procedural_leg_ik(
			_left_thigh_bone_index, _left_shin_bone_index, _left_foot_bone_index,
			_left_foot_ground_target_world,
			_left_foot_ground_normal if not bool(_leg_controller.get("left_in_swing")) else Vector3.ZERO,
			left_thigh_rotation, left_shin_rotation, left_foot_rotation, _left_leg_ik_weight
		)
		_left_leg_ik_active = left_ik_applied
	else:
		_left_leg_ik_active = false
	if _right_leg_ik_weight > 0.01:
		var right_ik_applied: bool = _apply_procedural_leg_ik(
			_right_thigh_bone_index, _right_shin_bone_index, _right_foot_bone_index,
			_right_foot_ground_target_world,
			_right_foot_ground_normal if not bool(_leg_controller.get("right_in_swing")) else Vector3.ZERO,
			right_thigh_rotation, right_shin_rotation, right_foot_rotation, _right_leg_ik_weight
		)
		_right_leg_ik_active = right_ik_applied
	else:
		_right_leg_ik_active = false
	skeleton.force_update_all_bone_transforms()
	_leg_pose_active = bool(_leg_controller.call("is_active"))
	return true

func _debug_leg_status(_args: Array[Variant]) -> String:
	var phase_value: float = float(_leg_controller.get("phase"))
	var left_state: String = "swing" if bool(_leg_controller.get("left_in_swing")) else "stance"
	var right_state: String = "swing" if bool(_leg_controller.get("right_in_swing")) else "stance"
	var left_progress: float = float(_leg_controller.get("left_swing_progress"))
	var right_progress: float = float(_leg_controller.get("right_swing_progress"))
	return "active=%s phase=%.2f left=%s(%.2f) right=%s(%.2f)" % [
		_leg_pose_active, phase_value, left_state, left_progress, right_state, right_progress
	]

func _debug_leg_ground_status(_args: Array[Variant]) -> String:
	return "left_hit=%s left_ik=%s left_weight=%.2f left_anchor=%s left_target=%s left_normal=%s right_hit=%s right_ik=%s right_weight=%.2f right_anchor=%s right_target=%s right_normal=%s" % [
		_left_foot_grounded, _left_leg_ik_active, _left_leg_ik_weight, _left_foot_plant.get("anchor_world"), _left_foot_ground_target_world, _left_foot_ground_normal,
		_right_foot_grounded, _right_leg_ik_active, _right_leg_ik_weight, _right_foot_plant.get("anchor_world"), _right_foot_ground_target_world, _right_foot_ground_normal
	]

func update_procedural_right_arm(wrist_target_world: Vector3, delta: float) -> bool:
	var applied: bool = _update_procedural_arm_chain(
		_right_viewmodel_upper_arm_bone_index,
		_right_viewmodel_forearm_bone_index,
		_right_viewmodel_hand_bone_index,
		wrist_target_world,
		delta
	)
	if not applied:
		_set_right_arm_ik_active(false)
		return false
	_right_arm_ik_target_world = wrist_target_world
	_set_right_arm_ik_active(true)
	return true

func update_procedural_left_arm(wrist_target_world: Vector3, delta: float) -> bool:
	var applied: bool = _update_procedural_arm_chain(
		_left_viewmodel_upper_arm_bone_index,
		_left_viewmodel_forearm_bone_index,
		_left_viewmodel_hand_bone_index,
		wrist_target_world,
		delta
	)
	if not applied:
		_set_left_arm_ik_active(false)
		return false
	_left_arm_ik_target_world = wrist_target_world
	_set_left_arm_ik_active(true)
	return true

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
	_leg_controller.call("reset")
	_leg_pose_active = false
	_set_right_arm_ik_active(false)
	_set_left_arm_ik_active(false)
	_set_right_rig_hand_visual_visible(true)
	_set_left_rig_hand_visual_visible(true)
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
	_set_right_arm_ik_active(false)
	_set_left_arm_ik_active(false)
	_set_right_rig_hand_visual_visible(false)
	_set_left_rig_hand_visual_visible(false)
	disable_collisions()
	skeleton.reset_bone_poses()
	top_level = false
	transform = Transform3D.IDENTITY
	_latest_host_pose = PackedInt32Array()
	_leg_controller.call("reset")
	_leg_pose_active = false

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

## Return the live Chest PhysicalBone transform while simulating. The animated
## skeleton pose is the fallback before/after physics ownership.
func get_chest_world_position() -> Vector3:
	if simulator.is_simulating_physics() and _chest_physical_bone != null:
		return _chest_physical_bone.global_position
	if _chest_bone_index >= 0:
		return skeleton.to_global(skeleton.get_bone_global_pose(_chest_bone_index).origin)
	return get_hips_world_position()

func get_chest_world_basis() -> Basis:
	if simulator.is_simulating_physics() and _chest_physical_bone != null:
		return _chest_physical_bone.global_basis.orthonormalized()
	if _chest_bone_index >= 0:
		return (skeleton.global_basis * skeleton.get_bone_global_pose(_chest_bone_index).basis).orthonormalized()
	return global_basis.orthonormalized()

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
	if _head_physical_bone != null:
		_carry_saved_head_swing_span = float(_head_physical_bone.get("joint_constraints/swing_span"))
		_carry_saved_head_twist_span = float(_head_physical_bone.get("joint_constraints/twist_span"))
		# Keep the head mobile, but reduce large, sudden neck swings while carried.
		_head_physical_bone.set("joint_constraints/swing_span", 18.0)
		_head_physical_bone.set("joint_constraints/twist_span", 14.0)
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
	if _head_physical_bone != null:
		_head_physical_bone.set("joint_constraints/swing_span", _carry_saved_head_swing_span)
		_head_physical_bone.set("joint_constraints/twist_span", _carry_saved_head_twist_span)
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
	var character_facing_basis: Basis = Basis.looking_at(_carry_facing_world.normalized(), Vector3.UP)
	# Apply the character-facing rotation plus the Chest bone's original bind
	# orientation, so the visual torso faces forward instead of tilting sideways.
	var target_basis: Basis = character_facing_basis * _chest_rest_basis_offset
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
	_leg_controller.call("reset")
	_leg_pose_active = false
	_set_right_arm_ik_active(false)
	_set_left_arm_ik_active(false)
	_set_right_rig_hand_visual_visible(true)
	_set_left_rig_hand_visual_visible(true)
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
	_set_right_arm_ik_active(false)
	_set_left_arm_ik_active(false)
	_set_right_rig_hand_visual_visible(false)
	_set_left_rig_hand_visual_visible(false)
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
