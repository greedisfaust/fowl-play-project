## Tracks a foot's world-space stance anchor and interpolated swing path.
## Ground probing and Skeleton3D IK are owned by PlayerRig.
extends RefCounted

var anchor_world: Vector3 = Vector3.ZERO
var step_start_world: Vector3 = Vector3.ZERO
var step_target_world: Vector3 = Vector3.ZERO
var has_anchor: bool = false
var was_in_swing: bool = false

func update_target(
	current_foot_world: Vector3,
	landing_target_world: Vector3,
	grounded: bool,
	in_swing: bool,
	swing_progress: float,
	lift_height: float
) -> Vector3:
	if not current_foot_world.is_finite() or not landing_target_world.is_finite():
		reset()
		return current_foot_world
	if not grounded:
		was_in_swing = in_swing
		has_anchor = false
		return current_foot_world

	if in_swing:
		if not was_in_swing:
			step_start_world = anchor_world if has_anchor else current_foot_world
		if not was_in_swing:
			step_target_world = landing_target_world
		var progress: float = clampf(swing_progress, 0.0, 1.0)
		var eased_progress: float = progress * progress * (3.0 - 2.0 * progress)
		var target: Vector3 = step_start_world.lerp(step_target_world, eased_progress)
		target.y += sin(progress * PI) * maxf(lift_height, 0.0)
		was_in_swing = true
		return target

	if was_in_swing or not has_anchor:
		anchor_world = step_target_world if was_in_swing else landing_target_world
		has_anchor = true
	was_in_swing = false
	return anchor_world

func reset() -> void:
	anchor_world = Vector3.ZERO
	step_start_world = Vector3.ZERO
	step_target_world = Vector3.ZERO
	has_anchor = false
	was_in_swing = false
