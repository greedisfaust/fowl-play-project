extends SceneTree

const STREAM = preload("res://core/movement_stream.gd")
const MOVEMENT_CONTROLLER = preload("res://core/movement_controller.gd")
const JUMP_CONTROLLER = preload("res://core/jump_controller.gd")
var failed: bool = false

func _initialize() -> void:
	var movement: RefCounted = MOVEMENT_CONTROLLER.new()
	var accelerating: Vector3 = movement.call(
		"advance_horizontal_velocity", Vector3.ZERO, Vector3(0.0, 0.0, -1.0),
		3.8, 14.0, 18.0, 0.1
	)
	check(is_equal_approx(accelerating.length(), 1.4), "movement accelerates instead of instantly reaching walking speed")
	var decelerating: Vector3 = movement.call(
		"advance_horizontal_velocity", Vector3(0.0, 0.0, -3.8), Vector3.ZERO,
		3.8, 14.0, 18.0, 0.1
	)
	check(is_equal_approx(decelerating.length(), 2.0), "movement decelerates smoothly when input is released")
	var turning: Vector3 = movement.call(
		"advance_horizontal_velocity", Vector3(3.8, 0.0, 0.0), Vector3(-1.0, 0.0, 0.0),
		3.8, 14.0, 18.0, 0.1
	)
	check(turning.x > 0.0, "direction reversals should blend through velocity rather than snap")
	for step: int in 20:
		turning = movement.call(
			"advance_horizontal_velocity", turning, Vector3(-1.0, 0.0, 0.0),
			3.8, 14.0, 18.0, 0.1
		)
	check(turning.x < -3.7, "acceleration should reach the requested movement speed over time")
	var air_controlled: Vector3 = movement.call(
		"advance_horizontal_velocity", Vector3.ZERO, Vector3(0.0, 0.0, -1.0),
		3.8, 14.0 * 0.55, 18.0 * 0.55, 0.1
	)
	check(air_controlled.length() < accelerating.length(), "air steering acceleration is weaker than grounded acceleration")

	var jump: RefCounted = JUMP_CONTROLLER.new()
	jump.call("advance", 0.016, true, false, false, 0.0, 6.5, 0.10, 0.12, 0.45)
	var coyote_jump: Dictionary = jump.call("advance", 0.05, false, true, false, 0.0, 6.5, 0.10, 0.12, 0.45)
	check(bool(coyote_jump.get("jumped", false)), "jump input is accepted briefly after leaving a ledge")
	check(is_equal_approx(float(coyote_jump.get("vertical_velocity", 0.0)), 6.5), "coyote jump receives full jump speed")

	jump.call("reset")
	jump.call("advance", 0.016, true, false, false, 0.0, 6.5, 0.10, 0.12, 0.45)
	jump.call("advance", 0.11, false, false, false, 0.0, 6.5, 0.10, 0.12, 0.45)
	var expired_coyote: Dictionary = jump.call("advance", 0.016, false, true, false, 0.0, 6.5, 0.10, 0.12, 0.45)
	check(not bool(expired_coyote.get("jumped", false)), "coyote grace expires after its configured window")

	jump.call("reset")
	var buffered_press: Dictionary = jump.call("advance", 0.016, false, true, false, -1.0, 6.5, 0.10, 0.12, 0.45)
	check(not bool(buffered_press.get("jumped", false)), "jump pressed in midair waits for landing")
	var buffered_landing: Dictionary = jump.call("advance", 0.04, true, false, false, 0.0, 6.5, 0.10, 0.12, 0.45)
	check(bool(buffered_landing.get("jumped", false)), "buffered jump fires on landing")

	jump.call("reset")
	jump.call("advance", 0.016, true, true, false, 0.0, 6.5, 0.10, 0.12, 0.45)
	var short_hop: Dictionary = jump.call("advance", 0.016, false, false, true, 6.5, 6.5, 0.10, 0.12, 0.45)
	check(bool(short_hop.get("jump_cut", false)), "releasing jump during ascent cuts the jump")
	check(is_equal_approx(float(short_hop.get("vertical_velocity", 0.0)), 2.925), "short hop reduces upward velocity")

	jump.call("reset")
	jump.call("advance", 0.016, true, true, false, 0.0, 6.5, 0.10, 0.12, 0.45)
	var full_jump: Dictionary = jump.call("advance", 0.016, false, false, false, 6.5, 6.5, 0.10, 0.12, 0.45)
	check(is_equal_approx(float(full_jump.get("vertical_velocity", 0.0)), 6.5), "holding jump preserves full upward velocity")

	var stream: STREAM = STREAM.new()
	stream.reset(Vector3.ZERO, 0.0)
	check(stream.accept(1, Vector3(0.25, 0, 0), Vector3(5, 0, 0), 0, 0, 0.05), "normal movement")
	check(not stream.accept(1, Vector3.ZERO, Vector3.ZERO, 0, 0, 0.1), "stale sequence rejected")
	check(not stream.accept(2, Vector3(100, 0, 0), Vector3.ZERO, 0, 0, 0.1), "teleport rejected")
	check(not stream.accept(2, Vector3(NAN, 0, 0), Vector3.ZERO, 0, 0, 0.1), "NaN rejected")
	check(not stream.accept(2, Vector3.ZERO, Vector3(100, 0, 0), 0, 0, 0.1), "speed rejected")
	check(stream.accept(2, Vector3(0.5, 0, 0), Vector3(5, 0, 0), 0, 0, 0.1), "recovery after rejected sample")
	# Repeated packets cannot replenish displacement credit without elapsed time.
	for index: int in 20:
		stream.accept(index + 3, stream.position + Vector3(0.25, 0, 0), Vector3.ZERO, 0, 0, 0.1)
	check(stream.position.x < 3.0, "packet flood cannot multiply jitter tolerance")
	stream.reset(Vector3.ZERO, 0.0)
	stream.push(1, Vector3.ZERO, Vector3.ZERO, deg_to_rad(179), 0, 1.0)
	stream.push(2, Vector3(2, 0, 0), Vector3.ZERO, deg_to_rad(-179), 0, 1.2)
	stream.push(1, Vector3(99, 0, 0), Vector3.ZERO, 0, 0, 1.3)
	var sample: Dictionary = stream.sample(1.2)
	check(absf(sample.position.x - 1.0) < 0.001, "delayed interpolation midpoint")
	check(absf(absf(sample.yaw) - PI) < 0.01, "yaw takes shortest arc")
	check(stream.sample(5.0).position == Vector3(2, 0, 0), "holds last snapshot on loss")
	stream.reset(Vector3.ZERO, 0.0)
	stream.push(1, Vector3.ZERO, Vector3.ZERO, 0.0, 0.0, 1.0, false)
	stream.push(2, Vector3(1.0, 0.0, 0.0), Vector3.ZERO, 0.0, 0.0, 1.2, true)
	check(not bool(stream.sample(1.2).grounded), "grounded state remains false before the landing snapshot time")
	check(bool(stream.sample(1.3).grounded), "grounded state changes at the landing snapshot time")
	if not failed:
		print("M3 movement checks passed")
	quit(1 if failed else 0)

func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
