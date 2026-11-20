## Calculates movement-intent-based landing points relative to the hips.
## It does not own ground detection or foot anchoring; PlayerRig handles both.
extends RefCounted

const DEFAULT_FORWARD_PLACEMENT_M: float = 0.36
const DEFAULT_LATERAL_PLACEMENT_M: float = 0.18

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
	# Keep each foot on its anatomical side of the body. Using the movement
	# perpendicular as the side axis makes the feet swap sides while strafing.
	var lateral_axis_world: Vector3 = rig_basis * Vector3.RIGHT
	lateral_axis_world.y = 0.0
	if lateral_axis_world.length_squared() <= 0.0001:
		lateral_axis_world = Vector3.RIGHT
	else:
		lateral_axis_world = lateral_axis_world.normalized()
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
	minimum_lateral_m: float
) -> Vector3:
	if not target_world.is_finite() or not hip_center_world.is_finite():
		return target_world
	var lateral_axis_world: Vector3 = rig_basis * Vector3.RIGHT
	lateral_axis_world.y = 0.0
	if lateral_axis_world.length_squared() <= 0.0001:
		lateral_axis_world = Vector3.RIGHT
	else:
		lateral_axis_world = lateral_axis_world.normalized()
	var side_sign: float = -1.0 if foot_side < 0.0 else 1.0
	var signed_lateral: float = (target_world - hip_center_world).dot(lateral_axis_world) * side_sign
	var required_lateral: float = maxf(minimum_lateral_m, 0.0)
	if signed_lateral < required_lateral:
		target_world += lateral_axis_world * side_sign * (required_lateral - signed_lateral)
	return target_world
