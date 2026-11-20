## Tracks a foot's world-space stance anchor, normal swing, and emergency recovery step.
## Ground probing and Skeleton3D IK are owned by PlayerRig.
extends RefCounted

var anchor_world: Vector3 = Vector3.ZERO
var anchor_support: Node3D
var anchor_support_local: Vector3 = Vector3.ZERO
var step_start_world: Vector3 = Vector3.ZERO
var step_target_world: Vector3 = Vector3.ZERO
var step_target_support: Node3D
var step_target_support_local: Vector3 = Vector3.ZERO
var emergency_replant_target_support: Node3D
var emergency_replant_target_support_local: Vector3 = Vector3.ZERO
var has_anchor: bool = false
var was_in_swing: bool = false
var emergency_replant_active: bool = false
var emergency_replant_elapsed: float = 0.0
var emergency_replant_start_world: Vector3 = Vector3.ZERO
var emergency_replant_target_world: Vector3 = Vector3.ZERO
var emergency_replant_suppress_gait_swing: bool = false

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
	force_replant: bool = false,
	landing_support: Node3D = null,
	emergency_lift_height: float = -1.0
) -> Vector3:
	if not current_foot_world.is_finite() or not landing_target_world.is_finite():
		reset()
		return current_foot_world
	_refresh_anchor_from_support()
	if not grounded:
		was_in_swing = in_swing
		has_anchor = false
		emergency_replant_active = false
		emergency_replant_elapsed = 0.0
		emergency_replant_suppress_gait_swing = false
		return current_foot_world

	if not emergency_replant_active and emergency_replant_suppress_gait_swing and not in_swing:
		emergency_replant_suppress_gait_swing = false

	# A stretched stance leg can request a recovery step before the gait phase
	# naturally enters swing. The target is captured once, just like a normal step.
	if force_replant and not emergency_replant_active and not in_swing and has_anchor:
		emergency_replant_active = true
		emergency_replant_elapsed = 0.0
		emergency_replant_start_world = anchor_world
		emergency_replant_target_world = landing_target_world
		emergency_replant_target_support = landing_support
		_capture_support_local(landing_target_world, landing_support, true)
		emergency_replant_suppress_gait_swing = true
		was_in_swing = false

	if emergency_replant_active:
		var safe_duration: float = maxf(recovery_duration, 0.01)
		emergency_replant_elapsed = minf(emergency_replant_elapsed + maxf(delta, 0.0), safe_duration)
		var recovery_progress: float = clampf(emergency_replant_elapsed / safe_duration, 0.0, 1.0)
		var eased_recovery: float = recovery_progress * recovery_progress * recovery_progress * (recovery_progress * (recovery_progress * 6.0 - 15.0) + 10.0)
		if is_instance_valid(emergency_replant_target_support):
			emergency_replant_target_world = emergency_replant_target_support.global_transform * emergency_replant_target_support_local
		var recovery_target: Vector3 = emergency_replant_start_world.lerp(emergency_replant_target_world, eased_recovery)
		var recovery_lift: float = emergency_lift_height if emergency_lift_height >= 0.0 else lift_height
		recovery_target.y += sin(recovery_progress * PI) * maxf(recovery_lift, 0.0)
		if recovery_progress >= 1.0:
			anchor_world = emergency_replant_target_world
			anchor_support = emergency_replant_target_support
			anchor_support_local = emergency_replant_target_support_local
			has_anchor = true
			emergency_replant_active = false
			emergency_replant_elapsed = 0.0
			emergency_replant_target_support = null
			was_in_swing = false
			return anchor_world
		return recovery_target

	if emergency_replant_suppress_gait_swing:
		was_in_swing = false
		return anchor_world

	if in_swing:
		if not was_in_swing:
			step_start_world = anchor_world if has_anchor else current_foot_world
		if not was_in_swing:
			step_target_world = landing_target_world
			step_target_support = landing_support
			step_target_support_local = _get_support_local(step_target_world, step_target_support)
		if is_instance_valid(step_target_support):
			step_target_world = step_target_support.global_transform * step_target_support_local
		var progress: float = clampf(swing_progress, 0.0, 1.0)
		var eased_progress: float = progress * progress * progress * (progress * (progress * 6.0 - 15.0) + 10.0)
		var target: Vector3 = step_start_world.lerp(step_target_world, eased_progress)
		target.y += sin(progress * PI) * maxf(lift_height, 0.0)
		was_in_swing = true
		return target

	if was_in_swing or not has_anchor:
		anchor_world = step_target_world if was_in_swing else landing_target_world
		anchor_support = step_target_support if was_in_swing else landing_support
		anchor_support_local = step_target_support_local if was_in_swing else _get_support_local(anchor_world, anchor_support)
		has_anchor = true
	was_in_swing = false
	return anchor_world

func _refresh_anchor_from_support() -> void:
	if has_anchor and is_instance_valid(anchor_support):
		anchor_world = anchor_support.global_transform * anchor_support_local
	elif anchor_support != null and not is_instance_valid(anchor_support):
		anchor_support = null

func _get_support_local(world_position: Vector3, support: Node3D) -> Vector3:
	if is_instance_valid(support):
		return support.global_transform.affine_inverse() * world_position
	return Vector3.ZERO

func _capture_support_local(world_position: Vector3, support: Node3D, emergency: bool) -> void:
	if emergency:
		emergency_replant_target_support_local = _get_support_local(world_position, support)

func reset() -> void:
	anchor_world = Vector3.ZERO
	anchor_support = null
	anchor_support_local = Vector3.ZERO
	step_start_world = Vector3.ZERO
	step_target_world = Vector3.ZERO
	step_target_support = null
	step_target_support_local = Vector3.ZERO
	emergency_replant_target_support = null
	emergency_replant_target_support_local = Vector3.ZERO
	has_anchor = false
	was_in_swing = false
	emergency_replant_active = false
	emergency_replant_elapsed = 0.0
	emergency_replant_start_world = Vector3.ZERO
	emergency_replant_target_world = Vector3.ZERO
	emergency_replant_suppress_gait_swing = false
