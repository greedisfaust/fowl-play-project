## Host-side movement budget and receive-time interpolation for standing capsules.
## Pure data component: creates no scene nodes or geometry.
extends RefCounted

const TUNING = preload("res://core/tuning.gd")
var position: Vector3
var velocity: Vector3 = Vector3.ZERO
var grounded: bool = true
var last_sequence: int = -1
var last_time: float
var horizontal_budget: float = 0.5
var vertical_budget: float = 0.5
var samples: Array[Dictionary] = []

func reset(at: Vector3, now: float) -> void:
	position = at
	last_time = now
	last_sequence = -1
	horizontal_budget = 0.5
	vertical_budget = 0.5
	velocity = Vector3.ZERO
	grounded = true
	samples.clear()

func accept(sequence: int, at: Vector3, speed: Vector3, yaw: float, pitch: float, now: float, on_floor: bool = true) -> bool:
	if sequence <= last_sequence or sequence < 0:
		return false
	if not at.is_finite() or not speed.is_finite() or not is_finite(yaw) or not is_finite(pitch):
		return false
	if absf(pitch) > deg_to_rad(85.1) or Vector2(speed.x, speed.z).length() > TUNING.MOVE_SANITY_MAX_SPEED_MPS:
		return false
	var elapsed: float = clampf(now - last_time, 0.0, 0.5)
	# Bounded credit tolerates jitter without granting a fresh teleport allowance per packet.
	horizontal_budget = minf(horizontal_budget + elapsed * TUNING.MOVE_SANITY_MAX_SPEED_MPS, 3.0)
	var vertical_limit: float = maxf(TUNING.MOVE_SANITY_MAX_SPEED_MPS, absf(velocity.y) + TUNING.GRAVITY_MPS2 * elapsed)
	vertical_budget = minf(vertical_budget + elapsed * vertical_limit, maxf(3.0, vertical_limit * 0.5))
	last_time = now
	var displacement: Vector3 = at - position
	if Vector2(displacement.x, displacement.z).length() > horizontal_budget or absf(displacement.y) > vertical_budget:
		return false
	if absf(speed.y) > vertical_limit + 1.0:
		return false
	horizontal_budget -= Vector2(displacement.x, displacement.z).length()
	vertical_budget -= absf(displacement.y)
	position = at
	velocity = speed
	grounded = on_floor
	last_sequence = sequence
	return true

func push(sequence: int, at: Vector3, speed: Vector3, yaw: float, pitch: float, now: float, on_floor: bool = true) -> void:
	if not samples.is_empty() and sequence <= int(samples.back().sequence):
		return
	samples.append({"sequence": sequence, "position": at, "velocity": speed, "yaw": yaw, "pitch": pitch, "grounded": on_floor, "time": now})
	while samples.size() > 32:
		samples.pop_front()

func sample(now: float) -> Dictionary:
	if samples.is_empty():
		return {}
	var render_time: float = now - TUNING.MOVE_INTERP_DELAY_S
	while samples.size() > 2 and float(samples[1].time) <= render_time:
		samples.pop_front()
	var first: Dictionary = samples[0]
	if samples.size() == 1 or render_time <= float(first.time):
		return first
	var second: Dictionary = samples[1]
	var weight: float = clampf((render_time - float(first.time)) / maxf(float(second.time) - float(first.time), 0.0001), 0.0, 1.0)
	var sampled_grounded: bool = first.grounded if render_time < float(second.time) else second.grounded
	return {"position": (first.position as Vector3).lerp(second.position, weight),
		"velocity": second.velocity, "yaw": lerp_angle(first.yaw, second.yaw, weight),
		"pitch": lerpf(first.pitch, second.pitch, weight), "grounded": sampled_grounded}
