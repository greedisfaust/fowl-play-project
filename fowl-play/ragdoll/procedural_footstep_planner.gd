## Calculates movement-intent-based landing points relative to the hips.
## It does not own ground detection or foot anchoring; PlayerRig handles both.
extends RefCounted

const DEFAULT_FORWARD_PLACEMENT_M: float = 0.36
const DEFAULT_LATERAL_PLACEMENT_M: float = 0.18

## foot_side is +1 for the authored Thigh_L (+X) and -1 for Thigh_R (-X).
func get_landing_target(
	hip_world: Vector3,
	rig_basis: Basis,
	local_velocity: Vector3,
	foot_side: float,
	forward_placement_m: float = DEFAULT_FORWARD_PLACEMENT_M,
	lateral_placement_m: float = DEFAULT_LATERAL_PLACEMENT_M,
	predicted_swing_travel_m: float = 0.0
) -> Vector3:
	if not hip_world.is_finite() or not local_velocity.is_finite():
		return hip_world
	var horizontal_velocity: Vector3 = Vector3(local_velocity.x, 0.0, local_velocity.z)
	if horizontal_velocity.length_squared() <= 0.0001:
		horizontal_velocity = Vector3(0.0, 0.0, -1.0)
	var move_direction_world: Vector3 = rig_basis * horizontal_velocity.normalized()
	move_direction_world.y = 0.0
	if move_direction_world.length_squared() <= 0.0001:
		move_direction_world = Vector3(0.0, 0.0, -1.0)
	else:
		move_direction_world = move_direction_world.normalized()
	# Keep foot lanes perpendicular to travel. During a strafe, the lanes
	# become front/back so neither landing target gets forced across the hips.
	var lateral_axis_world: Vector3 = _get_lateral_axis_world(rig_basis, move_direction_world)
	var forward_offset: Vector3 = move_direction_world * (maxf(forward_placement_m, 0.0) + maxf(predicted_swing_travel_m, 0.0))
	var lateral_offset: Vector3 = lateral_axis_world * signf(foot_side) * maxf(lateral_placement_m, 0.0)
	return hip_world + forward_offset + lateral_offset

## Keep a candidate landing point on its assigned anatomical side of the hip midpoint.
## This is a target-space guard, not physical collision between leg meshes.
func constrain_anatomical_side(
	target_world: Vector3,
	hip_center_world: Vector3,
	rig_basis: Basis,
	foot_side: float,
	minimum_lateral_m: float,
	local_velocity: Vector3 = Vector3.ZERO
) -> Vector3:
	if not target_world.is_finite() or not hip_center_world.is_finite():
		return target_world
	var move_direction_world: Vector3 = Vector3.ZERO
	if local_velocity.is_finite():
		var horizontal_velocity: Vector3 = Vector3(local_velocity.x, 0.0, local_velocity.z)
		if horizontal_velocity.length_squared() > 0.0001:
			move_direction_world = rig_basis * horizontal_velocity.normalized()
			move_direction_world.y = 0.0
			move_direction_world = move_direction_world.normalized()
	var lateral_axis_world: Vector3 = _get_lateral_axis_world(rig_basis, move_direction_world)
	var side_sign: float = signf(foot_side)
	var signed_lateral: float = (target_world - hip_center_world).dot(lateral_axis_world) * side_sign
	var required_lateral: float = maxf(minimum_lateral_m, 0.0)
	if signed_lateral < required_lateral:
		target_world += lateral_axis_world * side_sign * (required_lateral - signed_lateral)
	return target_world


func _get_lateral_axis_world(rig_basis: Basis, move_direction_world: Vector3) -> Vector3:
	var lateral_axis_world: Vector3 = rig_basis * Vector3.RIGHT
	lateral_axis_world.y = 0.0
	if move_direction_world.length_squared() > 0.0001:
		lateral_axis_world -= move_direction_world * lateral_axis_world.dot(move_direction_world)
	# For a pure strafe, rig-right is parallel to travel. Use the character's
	# forward axis as a stable front/back lane direction instead.
	if lateral_axis_world.length_squared() < 0.04:
		lateral_axis_world = rig_basis * Vector3.FORWARD
		lateral_axis_world.y = 0.0
		if move_direction_world.length_squared() > 0.0001:
			lateral_axis_world -= move_direction_world * lateral_axis_world.dot(move_direction_world)
	if lateral_axis_world.length_squared() <= 0.0001:
		lateral_axis_world = Vector3.RIGHT
	return lateral_axis_world.normalized()
