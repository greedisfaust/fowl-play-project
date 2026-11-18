## Scene-backed hand controller for first-person and world hand modes.
## Owns hand state, optional aim/pose hooks, tinting, and debug diagnostics.

class_name Hand
extends Node3D

## Approved local guard rotations from hands/hand_pose_study.tscn.
## These are absolute authored rotations, not offsets from the neutral pose.
const AUTHORED_GUARD_THUMB_BASES: Array[Basis] = [
	Basis(Vector3(0.32573837, -0.88431454, 0.33448872), Vector3(0.42117006, 0.4524635, 0.7860616), Vector3(-0.8464694, -0.11517384, 0.51983136)),
	Basis.IDENTITY,
	Basis(Vector3(0.6706553, -0.3997253, -0.6248531), Vector3(0.62624645, -0.1463419, 0.76576734), Vector3(-0.39753878, -0.90487784, 0.15218154)),
]

@export var world_mode: bool = false
@export var aim_node_path: NodePath = NodePath("PoseRoot/IndexAim")
@export var pose_root_path: NodePath = NodePath("PoseRoot")
@export_range(1.0, 30.0) var pose_blend_speed: float = 14.0
@export_range(0.0, 60.0) var index_aim_limit_degrees: float = 35.0
@export var relaxed_curl_degrees: Vector3 = Vector3(-12.0, -18.0, -10.0)
@export var guard_curl_degrees: Vector3 = Vector3(-75.0, -85.0, -45.0)
@export var point_curl_degrees: Vector3 = Vector3(-75.0, -85.0, -45.0)
## Offsets in authoring units, relative to the editor-authored rest pose.
@export var guard_position_offset: Vector3 = Vector3(0.0, 0.14, -0.04)
@export var guard_rotation_degrees: Vector3 = Vector3(30.0, -10.0, 10.0)
@export var guard_thumb_root_degrees: Vector3 = Vector3(-20.0, -65.0, 0.0)
@export var guard_thumb_curl_degrees: Vector2 = Vector2(-20.0, -30.0)
## When enabled, uses the approved study pose instead of legacy guard thumb offsets.
@export var use_authored_guard_thumb: bool = true
## Pointing and reach use the same approved thumb pose as guard by default.
@export var use_authored_point_thumb: bool = true
@export var relaxed_thumb_root_degrees: Vector3 = Vector3(-8.0, -15.0, 0.0)
@export var relaxed_thumb_curl_degrees: Vector2 = Vector2(-10.0, -15.0)
@export var point_thumb_root_degrees: Vector3 = Vector3(-15.0, -40.0, 0.0)
@export var point_thumb_curl_degrees: Vector2 = Vector2(-18.0, -25.0)
@export_range(0.0, 0.5) var reach_distance: float = 0.20
## A short extension makes repeated clicks feel responsive.
@export_range(0.02, 1.0) var reach_extend_seconds: float = 0.07
## The longer recovery keeps the hand from snapping back after the final click.
@export_range(0.02, 1.0) var reach_return_seconds: float = 0.22

var _reach_elapsed: float = -1.0
var _reach_target: Vector3
var _reach_offset: Vector3 = Vector3.ZERO
var _reach_amount: float = 0.0
var _reach_start_amount: float = 0.0
var _reach_preview_delay: float = -1.0

var _finger_joints: Array[Node3D] = []
var _joint_rest_rotations: Array[Vector3] = []
var _aim_rest_rotation: Quaternion = Quaternion.IDENTITY
var _pose_command_name: StringName
var _pose_rest_position: Vector3
var _pose_rest_rotation: Quaternion = Quaternion.IDENTITY
var _thumb_nodes: Array[Node3D] = []
var _thumb_rest_rotations: Array[Quaternion] = []
var _sway: Vector2 = Vector2.ZERO

@onready var debug_hub: Node = get_node("/root/DebugHub")

var is_hovering: bool = false
var is_guarding: bool = false
var is_carrying: bool = false
var is_limp: bool = false
var speed_mps: float = 0.0
var color: Color = Color.WHITE
var hover_point: Vector3 = Vector3.ZERO
var carry_item: Node3D = null
var _aim_node: Node3D = null
var _pose_root: Node3D = null
var _debug_command_name: StringName
var _debug_watch_name: StringName
var _tinted_geometry: Array[GeometryInstance3D] = []
var _original_materials: Array[Material] = []

func _ready() -> void:
	_aim_node = get_node_or_null(aim_node_path) as Node3D
	_pose_root = get_node_or_null(pose_root_path) as Node3D
	# Never animate the stable attachment root, even with a legacy path override.
	if _pose_root == self:
		_pose_root = null
	if _pose_root != null:
		_pose_rest_position = _pose_root.position
		_pose_rest_rotation = _pose_root.quaternion
		for thumb_path: String in ["ThumbRoot", "ThumbRoot/ThumbJoint1", "ThumbRoot/ThumbJoint1/ThumbJoint2"]:
			var thumb: Node3D = _pose_root.get_node_or_null(NodePath(thumb_path)) as Node3D
			_thumb_nodes.append(thumb)
			_thumb_rest_rotations.append(thumb.quaternion if thumb != null else Quaternion.IDENTITY)
	if _aim_node != null:
		_aim_rest_rotation = _aim_node.quaternion
	_cache_finger_joints()
	var debug_id: String = str(name)
	var command_names: Array = debug_hub.call("get_command_names")
	while command_names.has(StringName("hand_status_%s" % debug_id)) or command_names.has(StringName("hand_pose_%s" % debug_id)):
		debug_id += "_%s" % get_instance_id()
	_debug_command_name = StringName("hand_status_%s" % debug_id)
	_debug_watch_name = StringName("hands/%s/state" % debug_id)
	debug_hub.call("command", _debug_command_name, _debug_status,
		"Report this hand's cosmetic state.", false, false)
	debug_hub.call("watch", _debug_watch_name, _debug_state)
	_pose_command_name = StringName("hand_pose_%s" % debug_id)
	debug_hub.call("command", _pose_command_name, _debug_pose,
		"Preview idle, point, guard, limp, or reach (after a 1-second delay).", false, false)

func _cache_finger_joints() -> void:
	for finger_path: String in ["IndexAim/Index", "Middle", "Ring", "Pinky"]:
		var joint_path: String = finger_path
		for joint_name: String in ["Joint1", "Joint2", "Joint3"]:
			joint_path += "/" + joint_name
			var joint: Node3D = null
			if _pose_root != null:
				joint = _pose_root.get_node_or_null(NodePath(joint_path)) as Node3D
			_finger_joints.append(joint)
			_joint_rest_rotations.append(joint.rotation if joint != null else Vector3.ZERO)

func _process(delta: float) -> void:
	if _reach_preview_delay >= 0.0:
		_reach_preview_delay -= delta
		if _reach_preview_delay < 0.0:
			reach(global_position - global_basis.z * 2.0)
	if is_guarding or is_limp or is_carrying:
		_reach_elapsed = -1.0
		_reach_amount = 0.0
	elif _reach_elapsed >= 0.0:
		_reach_elapsed += delta
		if _reach_elapsed < reach_extend_seconds:
			var extend_weight: float = smoothstep(0.0, reach_extend_seconds, _reach_elapsed)
			_reach_amount = lerpf(_reach_start_amount, 1.0, extend_weight)
		else:
			var return_elapsed: float = _reach_elapsed - reach_extend_seconds
			_reach_amount = 1.0 - smoothstep(0.0, reach_return_seconds, return_elapsed)
		if _reach_elapsed >= reach_extend_seconds + reach_return_seconds:
			_reach_elapsed = -1.0
			_reach_amount = 0.0
	var weight: float = 1.0 - exp(-pose_blend_speed * delta)
	_blend_thumb_and_hand_pose(weight, delta)
	for index: int in _finger_joints.size():
		var joint: Node3D = _finger_joints[index]
		if not is_instance_valid(joint):
			continue
		var curl: Vector3 = relaxed_curl_degrees
		if is_limp:
			curl = Vector3(-8.0, -12.0, -8.0)
		elif is_guarding:
			curl = guard_curl_degrees
		elif is_carrying:
			curl = Vector3(-35.0, -50.0, -25.0)
		elif is_hovering or _reach_elapsed >= 0.0:
			curl = Vector3.ZERO if index < 3 else point_curl_degrees
		var target: Vector3 = _joint_rest_rotations[index]
		target.x += deg_to_rad(curl[index % 3])
		joint.rotation = joint.rotation.lerp(target, weight)
	if _aim_node != null:
		if (is_hovering or _reach_elapsed >= 0.0) and not (is_guarding or is_carrying or is_limp):
			_update_aim(_reach_target if _reach_elapsed >= 0.0 else hover_point, weight)
		else:
			_aim_node.quaternion = _aim_node.quaternion.slerp(_aim_rest_rotation, weight)

func _blend_thumb_and_hand_pose(weight: float, delta: float) -> void:
	var guard_active: bool = is_guarding and not is_limp
	var point_active: bool = (is_hovering or _reach_elapsed >= 0.0) and not (is_limp or is_guarding or is_carrying)
	var thumb_root_degrees: Vector3 = relaxed_thumb_root_degrees
	var thumb_curl_degrees: Vector2 = relaxed_thumb_curl_degrees
	if is_limp or is_carrying and not guard_active:
		# Preserve the existing authored thumb for these unfinished poses.
		thumb_root_degrees = Vector3.ZERO
		thumb_curl_degrees = Vector2.ZERO
	elif guard_active:
		thumb_root_degrees = guard_thumb_root_degrees
		thumb_curl_degrees = guard_thumb_curl_degrees
	elif is_hovering or _reach_elapsed >= 0.0:
		thumb_root_degrees = point_thumb_root_degrees
		thumb_curl_degrees = point_thumb_curl_degrees
	for index: int in _thumb_nodes.size():
		var thumb: Node3D = _thumb_nodes[index]
		if not is_instance_valid(thumb):
			continue
		var offset_degrees: Vector3 = Vector3.ZERO
		if index == 0:
			offset_degrees = thumb_root_degrees
		else:
			offset_degrees.x = thumb_curl_degrees[index - 1]
		var target: Quaternion = _thumb_rest_rotations[index] * Quaternion.from_euler(offset_degrees * PI / 180.0)
		if (guard_active and use_authored_guard_thumb) or (point_active and use_authored_point_thumb):
			# Text scene matrices list rows; Basis(Vector3, Vector3, Vector3) takes columns.
			target = AUTHORED_GUARD_THUMB_BASES[index].transposed().orthonormalized().get_rotation_quaternion()
		thumb.quaternion = thumb.quaternion.slerp(target, weight)
	if _pose_root == null:
		return
	var position_target: Vector3 = _pose_rest_position
	var rotation_offset: Vector3 = Vector3.ZERO
	if guard_active:
		position_target += guard_position_offset
		rotation_offset = guard_rotation_degrees * PI / 180.0
	elif _reach_elapsed >= 0.0:
		position_target += _reach_offset * _reach_amount
	_sway *= exp(-10.0 * delta)
	if not is_limp:
		rotation_offset += Vector3(_sway.y, _sway.x, 0.0)
	var rotation_target: Quaternion = _pose_rest_rotation * Quaternion.from_euler(rotation_offset)
	_pose_root.position = _pose_root.position.lerp(position_target, weight)
	_pose_root.quaternion = _pose_root.quaternion.slerp(rotation_target, weight)

func _exit_tree() -> void:
	_restore_tint()
	if not is_instance_valid(debug_hub):
		return
	debug_hub.call("unregister_command", _debug_command_name)
	debug_hub.call("unwatch", _debug_watch_name)
	debug_hub.call("unregister_command", _pose_command_name)

func set_color(new_color: Color) -> void:
	color = new_color
	_apply_tint()
	_debug_log("Color updated")

func set_hover(on: bool, world_point: Vector3) -> void:
	var changed: bool = is_hovering != on
	is_hovering = on
	hover_point = world_point
	if changed:
		_debug_log("Hover %s" % ("on" if on else "off"))

func update_hover_point(world_point: Vector3) -> void:
	hover_point = world_point

func reach(world_point: Vector3) -> bool:
	if is_guarding or is_limp or is_carrying:
		return false
	if not world_point.is_finite():
		return false
	var local_direction: Vector3 = to_local(world_point) - _pose_rest_position
	if local_direction.length_squared() < 0.000001:
		return false
	_reach_target = world_point
	_reach_offset = local_direction.normalized() * minf(reach_distance, local_direction.length())
	# Restart the extension from the current blend amount, never from a snapped rest pose.
	_reach_start_amount = _reach_amount
	_reach_elapsed = 0.0
	_debug_log("Reach")
	return true

func set_guard(active: bool) -> void:
	if is_guarding == active:
		return
	is_guarding = active
	_debug_log("Guard %s" % ("on" if active else "off"))

func shake(intensity: float) -> void:
	var clamped_intensity: float = clampf(intensity, 0.0, 1.0)
	if clamped_intensity <= 0.0:
		return
	_debug_log("Shake intensity=%.2f" % clamped_intensity)

func add_sway(relative_motion: Vector2) -> void:
	if _pose_root == null:
		return
	_sway = (_sway + relative_motion * 0.001).limit_length(0.06)

func set_speed(new_speed_mps: float) -> void:
	speed_mps = maxf(new_speed_mps, 0.0)

func set_carrying(on: bool, item: Node3D = null) -> void:
	is_carrying = on
	carry_item = item if on else null
	_debug_log("Carrying %s" % ("on" if on else "off"))

func set_limp(on: bool) -> void:
	is_limp = on
	_debug_log("Limp %s" % ("on" if on else "off"))

func _update_aim(world_point: Vector3, weight: float) -> void:
	if _aim_node == null:
		return
	var target: Quaternion = _aim_rest_rotation
	if world_point.is_finite():
		var parent: Node3D = _aim_node.get_parent() as Node3D
		var direction: Vector3 = _aim_rest_rotation.inverse() * (parent.to_local(world_point) - _aim_node.position)
		if direction.length_squared() > 0.000001:
			direction = direction.normalized()
			# A cone around the authored forward axis prevents backwards finger bends.
			var angle: float = acos(clampf(Vector3.FORWARD.dot(direction), -1.0, 1.0))
			var axis: Vector3 = Vector3.FORWARD.cross(direction)
			if axis.length_squared() > 0.000001:
				target *= Quaternion(axis.normalized(), minf(angle, deg_to_rad(index_aim_limit_degrees)))
	_aim_node.quaternion = _aim_node.quaternion.slerp(target, weight)

func _debug_pose(args: Array[Variant]) -> String:
	if args.size() != 1 or str(args[0]) not in ["idle", "point", "guard", "limp", "reach"]:
		return "Usage: %s idle|point|guard|limp|reach" % _pose_command_name
	var pose: String = str(args[0])
	_reach_elapsed = -1.0
	_reach_amount = 0.0
	_reach_preview_delay = -1.0
	set_limp(pose == "limp")
	set_guard(pose == "guard")
	set_carrying(false)
	set_hover(pose == "point", global_position - global_basis.z * 2.0)
	if pose == "reach":
		_reach_preview_delay = 1.0
		return "Reach preview in 1 second; close the console."
	return "Hand pose: %s" % pose

func _apply_tint() -> void:
	_restore_tint()
	for child: Node in find_children("*", "GeometryInstance3D", true, false):
		var geometry: GeometryInstance3D = child as GeometryInstance3D
		if geometry == null:
			continue
		# The authored hand uses material overrides on both meshes and its CSG palm.
		var original: BaseMaterial3D = geometry.material_override as BaseMaterial3D
		if original == null:
			continue
		var tint: BaseMaterial3D = original.duplicate() as BaseMaterial3D
		# Keep the cuff's darker value while applying the chosen hue opaquely.
		var shade: float = original.albedo_color.v
		tint.albedo_color = Color(color.r * shade, color.g * shade, color.b * shade, 1.0)
		tint.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		_tinted_geometry.append(geometry)
		_original_materials.append(geometry.material_override)
		geometry.material_override = tint

func _restore_tint() -> void:
	for index: int in _tinted_geometry.size():
		var geometry: GeometryInstance3D = _tinted_geometry[index]
		if is_instance_valid(geometry):
			geometry.material_override = _original_materials[index]
	_tinted_geometry.clear()
	_original_materials.clear()

func _debug_status(_args: Array[Variant]) -> String:
	return _debug_state()

func _debug_state() -> String:
	return "world=%s hover=%s guard=%s carrying=%s limp=%s reach=%.2f speed_mps=%.2f" % [
		world_mode,
		is_hovering,
		is_guarding,
		is_carrying,
		is_limp,
		_reach_amount,
		speed_mps,
	]

func _debug_log(message: String) -> void:
	if debug_hub.call("is_on", &"hands"):
		debug_hub.call("log", &"hands", "%s: %s" % [name, message])
