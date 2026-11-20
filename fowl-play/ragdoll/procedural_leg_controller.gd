## Local cosmetic gait model. It owns phase and target rotations, not Skeleton3D nodes.
extends RefCounted

const TUNING = preload("res://core/tuning.gd")

var phase: float = 0.0
var motion_weight: float = 0.0
var smoothed_velocity: Vector3 = Vector3.ZERO

var left_thigh_rotation: Quaternion = Quaternion.IDENTITY
var left_shin_rotation: Quaternion = Quaternion.IDENTITY
var left_foot_rotation: Quaternion = Quaternion.IDENTITY
var right_thigh_rotation: Quaternion = Quaternion.IDENTITY
var right_shin_rotation: Quaternion = Quaternion.IDENTITY
var right_foot_rotation: Quaternion = Quaternion.IDENTITY

func update(delta: float, local_velocity: Vector3, grounded: bool) -> void:
	if not local_velocity.is_finite():
		reset()
		return
	var safe_delta: float = maxf(delta, 0.0)
	var target_velocity: Vector3 = Vector3(local_velocity.x, 0.0, local_velocity.z)
	var velocity_blend: float = 1.0 - exp(-TUNING.LEG_VELOCITY_RESPONSE * safe_delta)
	smoothed_velocity = smoothed_velocity.lerp(target_velocity, velocity_blend)
	var speed: float = smoothed_velocity.length()
	var moving: bool = grounded and speed > TUNING.LEG_MIN_WALK_SPEED_MPS
	var target_weight: float = 1.0 if moving else 0.0
	var blend_weight: float = 1.0 - exp(-TUNING.LEG_BLEND_RESPONSE * safe_delta)
	motion_weight = lerpf(motion_weight, target_weight, blend_weight)
	if moving:
		phase = fposmod(
			phase + (speed / TUNING.LEG_STEP_CYCLE_DISTANCE_M) * TAU * safe_delta,
			TAU
		)
	var stride_weight: float = clampf(speed / TUNING.PLAYER_SPEED_MPS, 0.0, 1.0)
	var direction: Vector3 = smoothed_velocity.normalized() if speed > 0.001 else Vector3(0.0, 0.0, -1.0)
	var swing_axis: Vector3 = direction.cross(Vector3.UP)
	if swing_axis.length_squared() < 0.0001:
		swing_axis = Vector3.RIGHT
	else:
		swing_axis = swing_axis.normalized()

	var left_swing: float = sin(phase) * TUNING.LEG_MAX_THIGH_SWING_RAD * stride_weight * motion_weight
	var right_phase: float = phase + PI
	var right_swing: float = sin(right_phase) * TUNING.LEG_MAX_THIGH_SWING_RAD * stride_weight * motion_weight
	var left_knee: float = maxf(0.0, sin(phase)) * TUNING.LEG_MAX_KNEE_BEND_RAD * stride_weight * motion_weight
	var right_knee: float = maxf(0.0, sin(right_phase)) * TUNING.LEG_MAX_KNEE_BEND_RAD * stride_weight * motion_weight

	left_thigh_rotation = Quaternion(swing_axis, left_swing)
	var left_shin_axis: Vector3 = left_thigh_rotation.inverse() * swing_axis
	left_shin_rotation = Quaternion(left_shin_axis, left_knee)
	var left_foot_axis: Vector3 = (left_thigh_rotation * left_shin_rotation).inverse() * swing_axis
	left_foot_rotation = Quaternion(left_foot_axis, -(left_swing + left_knee) * TUNING.LEG_FOOT_COUNTER_ROTATION)

	right_thigh_rotation = Quaternion(swing_axis, right_swing)
	var right_shin_axis: Vector3 = right_thigh_rotation.inverse() * swing_axis
	right_shin_rotation = Quaternion(right_shin_axis, right_knee)
	var right_foot_axis: Vector3 = (right_thigh_rotation * right_shin_rotation).inverse() * swing_axis
	right_foot_rotation = Quaternion(right_foot_axis, -(right_swing + right_knee) * TUNING.LEG_FOOT_COUNTER_ROTATION)

func is_active() -> bool:
	return motion_weight > 0.01

func reset() -> void:
	phase = 0.0
	motion_weight = 0.0
	smoothed_velocity = Vector3.ZERO
	left_thigh_rotation = Quaternion.IDENTITY
	left_shin_rotation = Quaternion.IDENTITY
	left_foot_rotation = Quaternion.IDENTITY
	right_thigh_rotation = Quaternion.IDENTITY
	right_shin_rotation = Quaternion.IDENTITY
	right_foot_rotation = Quaternion.IDENTITY
