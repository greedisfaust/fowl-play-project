## Local first-person camera motion. Cosmetic only; never replicated or authoritative.
extends RefCounted

const WALK_SPEED_MPS: float = 3.8
const RUN_SPEED_MPS: float = 8.0
const BLEND_RESPONSE: float = 8.0
const IMPACT_DECAY: float = 8.5
const LANDING_DECAY: float = 11.0
const LOCOMOTION_MOTION_SCALE: float = 0.75

var intensity: float = 1.0
var _phase: float = 0.0
var _weight: float = 0.0
var _was_grounded: bool = true
var _landing_impulse: float = 0.0
var _peak_air_vertical_speed: float = 0.0
var _impact_offset: Vector3 = Vector3.ZERO
var _impact_rotation: Vector3 = Vector3.ZERO

static func compose_camera_transform(base_transform: Transform3D, offset: Vector3, rotation: Vector3) -> Transform3D:
	var presentation_transform: Transform3D = Transform3D(Basis.from_euler(rotation), offset)
	return base_transform * presentation_transform

func reset(grounded: bool = true) -> void:
	_phase = 0.0
	_weight = 0.0
	_was_grounded = grounded
	_landing_impulse = 0.0
	_peak_air_vertical_speed = 0.0
	_impact_offset = Vector3.ZERO
	_impact_rotation = Vector3.ZERO

func add_impact(world_direction: Vector3, strength: float = 1.0, player_basis: Basis = Basis.IDENTITY) -> void:
	if not world_direction.is_finite() or world_direction.length_squared() < 0.0001:
		return
	var local_direction: Vector3 = (player_basis.inverse() * world_direction.normalized()).normalized()
	var amount: float = clampf(strength, 0.0, 1.5)
	_impact_offset += Vector3(-local_direction.x * 0.035, 0.025 + amount * 0.025, 0.045 + absf(local_direction.z) * 0.025) * amount
	_impact_rotation += Vector3(-0.045 * amount, local_direction.x * 0.065 * amount, -local_direction.x * 0.11 * amount)
	_impact_offset = _impact_offset.limit_length(0.14)
	_impact_rotation = _impact_rotation.limit_length(0.22)

func advance(delta: float, local_velocity: Vector3, vertical_velocity: float, grounded: bool, enabled: bool = true) -> Dictionary:
	var step: float = maxf(delta, 0.0)
	var horizontal_speed: float = Vector2(local_velocity.x, local_velocity.z).length()
	var target_weight: float = 1.0 if enabled and horizontal_speed > 0.18 else 0.0
	_weight = lerpf(_weight, target_weight, 1.0 - exp(-BLEND_RESPONSE * step))
	if enabled and grounded and horizontal_speed > 0.18:
		var speed_ratio: float = clampf(horizontal_speed / RUN_SPEED_MPS, 0.0, 1.0)
		var cadence: float = lerpf(8.0, 12.0, speed_ratio)
		_phase = fposmod(_phase + cadence * step, TAU)
	if enabled and not grounded:
		_peak_air_vertical_speed = maxf(_peak_air_vertical_speed, absf(vertical_velocity))
	if enabled and _was_grounded and not grounded:
		_peak_air_vertical_speed = absf(vertical_velocity)
	if enabled and not _was_grounded and grounded:
		_landing_impulse = clampf(_peak_air_vertical_speed / 8.0, 0.18, 1.0)
		_peak_air_vertical_speed = 0.0
	_was_grounded = grounded
	_landing_impulse = move_toward(_landing_impulse, 0.0, LANDING_DECAY * step)
	_impact_offset = _impact_offset.lerp(Vector3.ZERO, 1.0 - exp(-IMPACT_DECAY * step))
	_impact_rotation = _impact_rotation.lerp(Vector3.ZERO, 1.0 - exp(-IMPACT_DECAY * step))

	var run_blend: float = clampf((horizontal_speed - WALK_SPEED_MPS) / maxf(RUN_SPEED_MPS - WALK_SPEED_MPS, 0.01), 0.0, 1.0)
	# Make ordinary walking readable in first person while keeping sprint stronger.
	# The ViewmodelHands are children of Camera3D, so they naturally follow this motion.
	var bob_amplitude: float = lerpf(0.028, 0.055, run_blend) * _weight * LOCOMOTION_MOTION_SCALE
	var bob_y: float = sin(_phase) * bob_amplitude
	var bob_x: float = sin(_phase * 0.5) * bob_amplitude * 0.4
	var sway_roll: float = -clampf(local_velocity.x / RUN_SPEED_MPS, -1.0, 1.0) * 0.06 * _weight * LOCOMOTION_MOTION_SCALE
	var gait_pitch: float = sin(_phase * 2.0) * 0.012 * _weight * LOCOMOTION_MOTION_SCALE
	var gait_roll: float = sin(_phase * 0.5) * 0.028 * _weight * LOCOMOTION_MOTION_SCALE
	var air_pitch: float = clampf(-vertical_velocity * 0.0035, -0.035, 0.035) if enabled and not grounded else 0.0
	var landing_pitch: float = -_landing_impulse * 0.055
	var offset: Vector3 = (Vector3(bob_x, bob_y, 0.0) + _impact_offset) * intensity
	var rotation: Vector3 = (Vector3(air_pitch + landing_pitch + gait_pitch, 0.0, sway_roll + gait_roll) + _impact_rotation) * intensity
	return {"offset": offset, "rotation": rotation, "motion_weight": _weight, "landing_weight": _landing_impulse}
