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
	var body_right_world: Vector3 = (rig_basis * Vector3.RIGHT).normalized()
	var lateral_axis_world: Vector3 = move_direction_world.cross(Vector3.UP).normalized()
	if lateral_axis_world.length_squared() <= 0.0001:
		lateral_axis_world = body_right_world
	elif lateral_axis_world.dot(body_right_world) < 0.0:
		lateral_axis_world = -lateral_axis_world
	var forward_offset: Vector3 = move_direction_world * (maxf(forward_placement_m, 0.0) + maxf(predicted_swing_travel_m, 0.0))
	var lateral_offset: Vector3 = lateral_axis_world * signf(foot_side) * maxf(lateral_placement_m, 0.0)
	return hip_world + forward_offset + lateral_offset
