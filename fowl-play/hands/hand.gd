## Scene-backed hand controller for first-person and world hand modes.
## Owns hand state, optional aim/pose hooks, tinting, and debug diagnostics.

class_name Hand
extends Node3D

## A single resolved pose drives every procedural hand channel.
## Higher-priority gameplay states always win over cosmetic hover/reach.
enum PoseState {
	IDLE,
	POINT,
	REACH,
	GUARD,
	CARRY,
	LIMP,
}

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
## Small world-space clearance added beyond the detected prop collision bounds.
@export_range(0.0, 0.2) var carry_side_offset_m: float = 0.04
@export_range(-0.5, 0.5) var carry_height_offset_m: float = 0.02
## Tight and open carry curls are blended using the prop's projected thickness.
@export var carry_tight_curl_degrees: Vector3 = Vector3(-55.0, -70.0, -45.0)
@export var carry_open_curl_degrees: Vector3 = Vector3(-20.0, -32.0, -16.0)
@export_range(0.05, 0.5) var carry_curl_small_extent_m: float = 0.15
@export_range(0.2, 1.5) var carry_curl_large_extent_m: float = 0.90

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
var carry_side: float = 0.0
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
	var pose_state: PoseState = _resolve_pose_state()
	var weight: float = 1.0 - exp(-pose_blend_speed * delta)
	var carry_curl: Vector3 = _get_carry_finger_curl_degrees() if pose_state == PoseState.CARRY else Vector3.ZERO
	_blend_thumb_and_hand_pose(weight, delta, pose_state)
	for index: int in _finger_joints.size():
		var joint: Node3D = _finger_joints[index]
		if not is_instance_valid(joint):
			continue
		var curl: Vector3 = relaxed_curl_degrees
		match pose_state:
			PoseState.LIMP:
				curl = Vector3(-8.0, -12.0, -8.0)
			PoseState.GUARD:
				curl = guard_curl_degrees
			PoseState.CARRY:
				curl = carry_curl
			PoseState.POINT, PoseState.REACH:
				curl = Vector3.ZERO if index < 3 else point_curl_degrees
		var target: Vector3 = _joint_rest_rotations[index]
		target.x += deg_to_rad(curl[index % 3])
		joint.rotation = joint.rotation.lerp(target, weight)
	if _aim_node != null:
		if pose_state == PoseState.POINT or pose_state == PoseState.REACH:
			_update_aim(_reach_target if pose_state == PoseState.REACH else hover_point, weight)
		else:
			_aim_node.quaternion = _aim_node.quaternion.slerp(_aim_rest_rotation, weight)

## Resolve one authoritative pose before touching any joint or transform.
## Priority: limp > carry > guard > reach > point > idle.
func _resolve_pose_state() -> PoseState:
	if is_limp:
		return PoseState.LIMP
	if is_carrying:
		return PoseState.CARRY
	if is_guarding:
		return PoseState.GUARD
	if _reach_elapsed >= 0.0:
		return PoseState.REACH
	if is_hovering:
		return PoseState.POINT
	return PoseState.IDLE

func _blend_thumb_and_hand_pose(weight: float, delta: float, pose_state: PoseState) -> void:
	var guard_active: bool = pose_state == PoseState.GUARD
	var point_active: bool = pose_state == PoseState.POINT or pose_state == PoseState.REACH
	var thumb_root_degrees: Vector3 = relaxed_thumb_root_degrees
	var thumb_curl_degrees: Vector2 = relaxed_thumb_curl_degrees
	if pose_state == PoseState.LIMP or pose_state == PoseState.CARRY:
		# Preserve the existing authored thumb for these unfinished poses.
		thumb_root_degrees = Vector3.ZERO
		thumb_curl_degrees = Vector2.ZERO
	elif guard_active:
		thumb_root_degrees = guard_thumb_root_degrees
		thumb_curl_degrees = guard_thumb_curl_degrees
	elif point_active:
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
	if pose_state == PoseState.CARRY and is_instance_valid(carry_item):
		position_target = _get_carry_pose_position()
	if guard_active:
		position_target += guard_position_offset
		rotation_offset = guard_rotation_degrees * PI / 180.0
	elif pose_state == PoseState.REACH:
		position_target += _reach_offset * _reach_amount
	_sway *= exp(-10.0 * delta)
	if not is_limp:
		rotation_offset += Vector3(_sway.y, _sway.x, 0.0)
	var rotation_target: Quaternion = _pose_rest_rotation * Quaternion.from_euler(rotation_offset)
	if pose_state == PoseState.CARRY and is_instance_valid(carry_item):
		rotation_target = _get_carry_pose_rotation(position_target)
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

func set_carrying(on: bool, item: Node3D = null, side: float = 0.0) -> void:
	is_carrying = on
	carry_item = item if on else null
	carry_side = clampf(side, -1.0, 1.0) if on else 0.0
	_debug_log("Carrying %s side=%.1f" % ["on" if on else "off", carry_side])

## Adapt the three finger-joint bends to the prop's actual thickness along
## the palm normal. Thin props get a tighter curl; thick props stay more open.
func _get_carry_finger_curl_degrees() -> Vector3:
	if not is_instance_valid(carry_item):
		return carry_tight_curl_degrees
	var grip_position: Vector3 = _get_carry_pose_position()
	var grip_rotation: Quaternion = _get_carry_pose_rotation(grip_position)
	var palm_normal_world: Vector3 = (global_basis.orthonormalized() * (grip_rotation * Vector3.DOWN)).normalized()
	var local_bounds: AABB = _get_carry_local_bounds()
	var minimum_projection: float = INF
	var maximum_projection: float = -INF
	for corner_index: int in 8:
		var corner_world: Vector3 = carry_item.to_global(_aabb_corner(local_bounds, corner_index))
		var projection: float = corner_world.dot(palm_normal_world)
		minimum_projection = minf(minimum_projection, projection)
		maximum_projection = maxf(maximum_projection, projection)
	var prop_thickness: float = maxf(maximum_projection - minimum_projection, 0.0)
	var open_weight: float = clampf(inverse_lerp(carry_curl_small_extent_m, carry_curl_large_extent_m, prop_thickness), 0.0, 1.0)
	return carry_tight_curl_degrees.lerp(carry_open_curl_degrees, open_weight)

## Convert the detected prop bounds into a world-space side grip target.
## Collision shape debug meshes provide a shape-agnostic bounds source, so boxes,
## spheres, capsules, cylinders, and compound collision props share this path.
## Mesh bounds are used only when no usable collision shape is present.
func _get_carry_pose_position() -> Vector3:
	if not is_instance_valid(carry_item):
		return _pose_rest_position
	var local_bounds: AABB = _get_carry_local_bounds()
	var item_basis: Basis = carry_item.global_basis.orthonormalized()
	var minimums: Vector3 = Vector3(INF, INF, INF)
	var maximums: Vector3 = Vector3(-INF, -INF, -INF)
	for corner_index: int in 8:
		var corner: Vector3 = _aabb_corner(local_bounds, corner_index)
		var world_corner: Vector3 = carry_item.to_global(corner)
		var projected: Vector3 = Vector3(
			world_corner.dot(item_basis.x),
			world_corner.dot(item_basis.y),
			world_corner.dot(item_basis.z)
		)
		minimums = minimums.min(projected)
		maximums = maximums.max(projected)
	var center: Vector3 = (minimums + maximums) * 0.5
	var half_extents: Vector3 = (maximums - minimums) * 0.5
	var grip_world: Vector3 = item_basis.x * (center.x + carry_side * (half_extents.x + carry_side_offset_m))
	grip_world += item_basis.y * (center.y + carry_height_offset_m)
	grip_world += item_basis.z * center.z
	return to_local(grip_world)

## Turn the palm toward the prop while preserving the authored forearm axis.
## The rig's fingers extend along local -Z, forearm along +Z, palm surface
## normal is local -Y (from the CSG palm extrusion), and thumb mounts on -X.
## Avoid an unconstrained shortest-path wrist roll.
func _get_carry_pose_rotation(grip_position: Vector3) -> Quaternion:
	if not is_instance_valid(carry_item):
		return _pose_rest_rotation
	var grip_world: Vector3 = to_global(grip_position)
	var toward_item_world: Vector3 = carry_item.global_position - grip_world
	if toward_item_world.length_squared() < 0.000001:
		return _pose_rest_rotation
	var hand_basis: Basis = global_basis.orthonormalized()
	var toward_item_local: Vector3 = (hand_basis.inverse() * toward_item_world).normalized()
	var rest_palm_normal: Vector3 = (_pose_rest_rotation * Vector3.DOWN).normalized()
	var facing_delta: Quaternion = Quaternion(rest_palm_normal, toward_item_local)
	var facing_rotation: Quaternion = facing_delta * _pose_rest_rotation
	var rest_forearm_axis: Vector3 = (_pose_rest_rotation * Vector3.BACK).normalized()
	var facing_forearm_axis: Vector3 = (facing_rotation * Vector3.BACK).normalized()
	var desired_forearm_flat: Vector3 = rest_forearm_axis - toward_item_local * rest_forearm_axis.dot(toward_item_local)
	var facing_forearm_flat: Vector3 = facing_forearm_axis - toward_item_local * facing_forearm_axis.dot(toward_item_local)
	if desired_forearm_flat.length_squared() < 0.0001 or facing_forearm_flat.length_squared() < 0.0001:
		return facing_rotation
	desired_forearm_flat = desired_forearm_flat.normalized()
	facing_forearm_flat = facing_forearm_flat.normalized()
	var wrist_roll: float = facing_forearm_flat.signed_angle_to(desired_forearm_flat, toward_item_local)
	return Quaternion(toward_item_local, wrist_roll) * facing_rotation

## Build one prop-local AABB from every usable collision shape. Transforming each
## debug-mesh corner handles shape-node offsets, rotation, and scale, including
## a scaled CollisionShape3D beneath an unscaled RigidBody3D.
func _get_carry_local_bounds() -> AABB:
	if not is_instance_valid(carry_item):
		return AABB(Vector3.ZERO, Vector3.ZERO)
	var bounds_min: Vector3 = Vector3(INF, INF, INF)
	var bounds_max: Vector3 = Vector3(-INF, -INF, -INF)
	var found_collision_bounds: bool = false
	for candidate: Node in carry_item.find_children("*", "CollisionShape3D", true, false):
		var collision_shape: CollisionShape3D = candidate as CollisionShape3D
		if collision_shape == null or collision_shape.disabled or collision_shape.shape == null:
			continue
		var debug_mesh: Mesh = collision_shape.shape.get_debug_mesh()
		if debug_mesh == null:
			continue
		var shape_bounds: AABB = debug_mesh.get_aabb()
		for corner_index: int in 8:
			var shape_corner: Vector3 = _aabb_corner(shape_bounds, corner_index)
			var prop_local_corner: Vector3 = carry_item.to_local(collision_shape.to_global(shape_corner))
			bounds_min = bounds_min.min(prop_local_corner)
			bounds_max = bounds_max.max(prop_local_corner)
			found_collision_bounds = true
	if found_collision_bounds:
		return AABB(bounds_min, bounds_max - bounds_min)
	# Some custom shapes may not expose a debug mesh. Fall back to visible mesh
	# bounds rather than silently assuming every prop is a box.
	var found_mesh_bounds: bool = false
	for candidate: Node in carry_item.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = candidate as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var mesh_bounds: AABB = mesh_instance.mesh.get_aabb()
		for corner_index: int in 8:
			var mesh_corner: Vector3 = _aabb_corner(mesh_bounds, corner_index)
			var prop_local_mesh_corner: Vector3 = carry_item.to_local(mesh_instance.to_global(mesh_corner))
			bounds_min = bounds_min.min(prop_local_mesh_corner)
			bounds_max = bounds_max.max(prop_local_mesh_corner)
			found_mesh_bounds = true
	if found_mesh_bounds:
		return AABB(bounds_min, bounds_max - bounds_min)
	# Last-resort fallback preserves a small, usable grip target for invisible props.
	return AABB(Vector3(-0.18, -0.10, -0.18), Vector3(0.36, 0.20, 0.36))

func _aabb_corner(bounds: AABB, corner_index: int) -> Vector3:
	return Vector3(
		bounds.position.x + (bounds.size.x if (corner_index & 1) != 0 else 0.0),
		bounds.position.y + (bounds.size.y if (corner_index & 2) != 0 else 0.0),
		bounds.position.z + (bounds.size.z if (corner_index & 4) != 0 else 0.0)
	)

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
	return "world=%s pose=%s hover=%s guard=%s carrying=%s limp=%s reach=%.2f speed_mps=%.2f" % [
		world_mode,
		_pose_state_name(_resolve_pose_state()),
		is_hovering,
		is_guarding,
		is_carrying,
		is_limp,
		_reach_amount,
		speed_mps,
	]

func _pose_state_name(state: PoseState) -> String:
	match state:
		PoseState.IDLE:
			return "idle"
		PoseState.POINT:
			return "point"
		PoseState.REACH:
			return "reach"
		PoseState.GUARD:
			return "guard"
		PoseState.CARRY:
			return "carry"
		PoseState.LIMP:
			return "limp"
	return "unknown"

func _debug_log(message: String) -> void:
	if debug_hub.call("is_on", &"hands"):
		debug_hub.call("log", &"hands", "%s: %s" % [name, message])
