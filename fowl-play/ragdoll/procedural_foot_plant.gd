## Tracks a foot's world-space stance anchor, normal swing, and emergency recovery step.
## Ground probing and Skeleton3D IK are owned by PlayerRig.
extends RefCounted

var anchor_world: Vector3 = Vector3.ZERO
var step_start_world: Vector3 = Vector3.ZERO
var step_target_world: Vector3 = Vector3.ZERO
var has_anchor: bool = false
var was_in_swing: bool = false
var emergency_replant_active: bool = false
var emergency_replant_elapsed: float = 0.0
var emergency_replant_start_world: Vector3 = Vector3.ZERO
var emergency_replant_target_world: Vector3 = Vector3.ZERO

func needs_replant(hip_world: Vector3, max_reach_m: float) -> bool:
	if not has_anchor or was_in_swing or emergency_replant_active:
		return false
	if not hip_world.is_finite() or max_reach_m <= 0.001:
		return false
	return hip_world.distance_to(anchor_world) >= max_reach_m

func get_stretch_ratio(hip_world: Vector3, max_reach_m: float) -> float:
	if not has_anchor or not hip_world.is_finite() or max_reach_m <= 0.001:
		return 0.0
	return hip_world.distance_to(anchor_world) / max_reach_m

func update_target(
	current_foot_world: Vector3,
	landing_target_world: Vector3,
	grounded: bool,
	in_swing: bool,
	swing_progress: float,
	lift_height: float,
	delta: float = 0.0,
	hip_world: Vector3 = Vector3.ZERO,
	max_reach_m: float = 1000000.0,
	recovery_duration: float = 0.18,
	force_replant: bool = false
) -> Vector3:
	if not current_foot_world.is_finite() or not landing_target_world.is_finite():
		reset()
		return current_foot_world
	if not grounded:
		was_in_swing = in_swing
		has_anchor = false
		emergency_replant_active = false
		emergency_replant_elapsed = 0.0
		return current_foot_world

	# A stretched stance leg can request a recovery step before the gait phase
	# naturally enters swing. The target is captured once, just like a normal step.
	if force_replant and not emergency_replant_active and not in_swing and has_anchor:
		emergency_replant_active = true
		emergency_replant_elapsed = 0.0
		emergency_replant_start_world = anchor_world
		emergency_replant_target_world = landing_target_world
		was_in_swing = false

	if emergency_replant_active:
		var safe_duration: float = maxf(recovery_duration, 0.01)
		emergency_replant_elapsed = minf(emergency_replant_elapsed + maxf(delta, 0.0), safe_duration)
		var recovery_progress: float = clampf(emergency_replant_elapsed / safe_duration, 0.0, 1.0)
		var eased_recovery: float = recovery_progress * recovery_progress * recovery_progress * (recovery_progress * (recovery_progress * 6.0 - 15.0) + 10.0)
		var recovery_target: Vector3 = emergency_replant_start_world.lerp(emergency_replant_target_world, eased_recovery)
		recovery_target.y += sin(recovery_progress * PI) * maxf(lift_height, 0.0)
		if recovery_progress >= 1.0:
			anchor_world = emergency_replant_target_world
			has_anchor = true
			emergency_replant_active = false
			emergency_replant_elapsed = 0.0
			was_in_swing = false
			return anchor_world
		return recovery_target

	if in_swing:
		if not was_in_swing:
			step_start_world = anchor_world if has_anchor else current_foot_world
		if not was_in_swing:
			step_target_world = landing_target_world
		var progress: float = clampf(swing_progress, 0.0, 1.0)
		var eased_progress: float = progress * progress * progress * (progress * (progress * 6.0 - 15.0) + 10.0)
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
	emergency_replant_active = false
	emergency_replant_elapsed = 0.0
	emergency_replant_start_world = Vector3.ZERO
	emergency_replant_target_world = Vector3.ZERO
