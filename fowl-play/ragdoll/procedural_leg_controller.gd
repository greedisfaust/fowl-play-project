## Local cosmetic gait model. It owns phase and target rotations, not Skeleton3D nodes.
extends RefCounted

const TUNING = preload("res://core/tuning.gd")
const STOP_SETTLE_PHASE_SPEED_RAD_S: float = 16.0

var phase: float = 0.0
var motion_weight: float = 0.0
var smoothed_velocity: Vector3 = Vector3.ZERO

var left_thigh_rotation: Quaternion = Quaternion.IDENTITY
var left_shin_rotation: Quaternion = Quaternion.IDENTITY
var left_foot_rotation: Quaternion = Quaternion.IDENTITY
var right_thigh_rotation: Quaternion = Quaternion.IDENTITY
var right_shin_rotation: Quaternion = Quaternion.IDENTITY
var right_foot_rotation: Quaternion = Quaternion.IDENTITY
var left_in_swing: bool = false
var right_in_swing: bool = false
var left_swing_progress: float = 0.0
var right_swing_progress: float = 0.0

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
			phase + (speed / TUNING.LEG_STEP_CYCLE_DISTANCE_M) * TAU * TUNING.LEG_GAIT_RATE_MULTIPLIER * safe_delta,
			TAU
		)
	elif motion_weight > 0.01:
		# A stopped character must finish the current swing instead of freezing
		# one foot in mid-air. PI is the overlap where both feet are in stance.
		var cycle_phase: float = fposmod(phase, TAU)
		var settle_distance: float = fposmod(PI - cycle_phase, TAU)
		var settle_step: float = minf(settle_distance, STOP_SETTLE_PHASE_SPEED_RAD_S * safe_delta)
		phase = fposmod(phase + settle_step, TAU)
		if settle_distance <= settle_step + 0.0001:
			phase = PI
	else:
		phase = PI
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
	var left_cycle: float = fposmod(phase / TAU, 1.0)
	var right_cycle: float = fposmod(left_cycle + 0.5, 1.0)
	left_in_swing = left_cycle >= TUNING.LEG_STANCE_FRACTION
	right_in_swing = right_cycle >= TUNING.LEG_STANCE_FRACTION
	left_swing_progress = _get_swing_progress(left_cycle)
	right_swing_progress = _get_swing_progress(right_cycle)

	# Stance keeps the knee comparatively quiet; swing flexes it to clear the
	# ground, then extends toward heel contact. This is angular foot clearance,
	# not world-space IK or a tracked planted-foot target.
	var left_knee_shape: float = _get_knee_shape(left_cycle, left_swing_progress, left_in_swing)
	var right_knee_shape: float = _get_knee_shape(right_cycle, right_swing_progress, right_in_swing)
	var left_knee: float = left_knee_shape * TUNING.LEG_MAX_KNEE_BEND_RAD * stride_weight * motion_weight
	var right_knee: float = right_knee_shape * TUNING.LEG_MAX_KNEE_BEND_RAD * stride_weight * motion_weight
	var left_foot_pitch: float = _get_foot_pitch(left_cycle, left_swing_progress, left_in_swing)
	var right_foot_pitch: float = _get_foot_pitch(right_cycle, right_swing_progress, right_in_swing)

	left_thigh_rotation = Quaternion(swing_axis, left_swing)
	var left_shin_axis: Vector3 = left_thigh_rotation.inverse() * swing_axis
	left_shin_rotation = Quaternion(left_shin_axis, left_knee)
	var left_foot_axis: Vector3 = (left_thigh_rotation * left_shin_rotation).inverse() * swing_axis
	left_foot_rotation = Quaternion(left_foot_axis, -(left_swing + left_knee) * TUNING.LEG_FOOT_COUNTER_ROTATION + left_foot_pitch * stride_weight * motion_weight)

	right_thigh_rotation = Quaternion(swing_axis, right_swing)
	var right_shin_axis: Vector3 = right_thigh_rotation.inverse() * swing_axis
	right_shin_rotation = Quaternion(right_shin_axis, right_knee)
	var right_foot_axis: Vector3 = (right_thigh_rotation * right_shin_rotation).inverse() * swing_axis
	right_foot_rotation = Quaternion(right_foot_axis, -(right_swing + right_knee) * TUNING.LEG_FOOT_COUNTER_ROTATION + right_foot_pitch * stride_weight * motion_weight)

func _get_swing_progress(cycle: float) -> float:
	if cycle < TUNING.LEG_STANCE_FRACTION:
		return 0.0
	return clampf(
		(cycle - TUNING.LEG_STANCE_FRACTION) / (1.0 - TUNING.LEG_STANCE_FRACTION),
		0.0,
		1.0
	)

func _get_knee_shape(cycle: float, swing_progress: float, in_swing: bool) -> float:
	if in_swing:
		# Bend early to lift the heel, hold flex through the forward swing,
		# then extend during the final approach to the floor.
		var bend_in: float = sin(clampf(swing_progress / 0.42, 0.0, 1.0) * PI * 0.5)
		var extend_out: float = smoothstep(0.72, 1.0, swing_progress)
		return bend_in * (1.0 - extend_out)
	var stance_progress: float = cycle / TUNING.LEG_STANCE_FRACTION
	return 0.08 * sin(stance_progress * PI)

func _get_foot_pitch(cycle: float, swing_progress: float, in_swing: bool) -> float:
	if in_swing:
		# Lift the toe through early swing, then point it down slightly for contact.
		var lift: float = sin(clampf(swing_progress / 0.72, 0.0, 1.0) * PI * 0.5)
		var contact: float = smoothstep(0.72, 1.0, swing_progress)
		return lerpf(0.0, TUNING.LEG_SWING_FOOT_LIFT_RAD, lift) - contact * TUNING.LEG_STANCE_TOE_ROLL_RAD
	var stance_progress: float = cycle / TUNING.LEG_STANCE_FRACTION
	return sin(stance_progress * PI) * TUNING.LEG_STANCE_TOE_ROLL_RAD

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
	left_in_swing = false
	right_in_swing = false
	left_swing_progress = 0.0
	right_swing_progress = 0.0
