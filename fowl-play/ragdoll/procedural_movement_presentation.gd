## Local procedural body language for acceleration, turning, airtime and landing.
## Reads replicated movement intent and produces cosmetic poses only.
extends RefCounted

const BODY_RESPONSE: float = 11.0
const ACCELERATION_RESPONSE: float = 8.0
const MAX_FORWARD_LEAN: float = 0.14
const MAX_SIDE_LEAN: float = 0.12
const LANDING_PULSE_SECONDS: float = 0.24

var movement_body_pose: Vector3 = Vector3.ZERO
var smoothed_acceleration: Vector3 = Vector3.ZERO
var previous_local_velocity: Vector3 = Vector3.ZERO
var previous_grounded: bool = true
var airborne_elapsed: float = 0.0
var landing_elapsed: float = LANDING_PULSE_SECONDS
var air_pose_weight: float = 0.0
var landing_weight: float = 0.0
var initialized: bool = false

func advance(
	delta: float,
	local_velocity: Vector3,
	vertical_velocity: float,
	grounded: bool,
	yaw_delta: float,
	enabled: bool,
	combat_active: bool
) -> Vector3:
	var safe_delta: float = maxf(delta, 0.0)
	if not local_velocity.is_finite() or not is_finite(vertical_velocity) or not is_finite(yaw_delta):
		reset(grounded, local_velocity)
		return Vector3.ZERO
	var horizontal_velocity: Vector3 = Vector3(local_velocity.x, 0.0, local_velocity.z)
	if not initialized:
		previous_local_velocity = horizontal_velocity
		previous_grounded = grounded
		initialized = true
	var raw_acceleration: Vector3 = (horizontal_velocity - previous_local_velocity) / maxf(safe_delta, 0.0001)
	var acceleration_blend: float = 1.0 - exp(-ACCELERATION_RESPONSE * safe_delta)
	smoothed_acceleration = smoothed_acceleration.lerp(raw_acceleration, acceleration_blend)
	previous_local_velocity = horizontal_velocity

	if not grounded:
		airborne_elapsed += safe_delta
		landing_elapsed = LANDING_PULSE_SECONDS
	elif not previous_grounded:
		airborne_elapsed = 0.0
		landing_elapsed = 0.0
	else:
		landing_elapsed = minf(LANDING_PULSE_SECONDS, landing_elapsed + safe_delta)
	previous_grounded = grounded

	var air_target: float = 0.0 if grounded else 1.0
	air_pose_weight = lerpf(air_pose_weight, air_target, 1.0 - exp(-12.0 * safe_delta))
	landing_weight = 0.0
	if grounded and landing_elapsed < LANDING_PULSE_SECONDS:
		var landing_progress: float = clampf(landing_elapsed / LANDING_PULSE_SECONDS, 0.0, 1.0)
		landing_weight = sin(PI * landing_progress)

	var target_pose: Vector3 = Vector3.ZERO
	if enabled:
		var movement_weight: float = 0.45 if combat_active else 1.0
		var forward_lean: float = clampf(-smoothed_acceleration.z * 0.008, -MAX_FORWARD_LEAN, MAX_FORWARD_LEAN)
		var side_lean: float = clampf(-smoothed_acceleration.x * 0.007, -MAX_SIDE_LEAN, MAX_SIDE_LEAN)
		var turn_rate: float = clampf(yaw_delta / maxf(safe_delta, 0.0001), -3.0, 3.0)
		var turn_counter: float = clampf(-turn_rate * 0.035, -0.10, 0.10)
		target_pose = Vector3(forward_lean, turn_counter, side_lean + turn_rate * 0.012)
		target_pose.x += -0.11 * air_pose_weight
		target_pose.x += -0.13 * landing_weight
		target_pose *= movement_weight
	var pose_blend: float = 1.0 - exp(-BODY_RESPONSE * safe_delta)
	movement_body_pose = movement_body_pose.lerp(target_pose, pose_blend)
	return movement_body_pose

func reset(grounded: bool = true, local_velocity: Vector3 = Vector3.ZERO) -> void:
	movement_body_pose = Vector3.ZERO
	smoothed_acceleration = Vector3.ZERO
	previous_local_velocity = Vector3(local_velocity.x, 0.0, local_velocity.z)
	previous_grounded = grounded
	airborne_elapsed = 0.0
	landing_elapsed = LANDING_PULSE_SECONDS
	air_pose_weight = 0.0
	landing_weight = 0.0
	initialized = true
