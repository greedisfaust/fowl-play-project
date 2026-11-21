## Headless regression checks for first-person camera obstruction handling.
extends SceneTree

const CAMERA_COLLISION = preload("res://player/camera_collision_presentation.gd")
var _failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var controller: RefCounted = CAMERA_COLLISION.new()
	var origin: Vector3 = Vector3.ZERO
	var desired: Vector3 = Vector3(0.0, 0.0, -1.2)
	var clear: Vector3 = controller.call("advance", origin, desired, false, Vector3.ZERO, 0.016)
	_expect_near(clear.length(), 1.2, "Clear path should preserve authored camera distance.")
	controller.call("advance", origin, desired, true, Vector3(0.0, 0.0, -0.5), 0.016)
	var blocked: Vector3 = controller.call("advance", origin, desired, true, Vector3(0.0, 0.0, -0.5), 0.016)
	_expect_near(blocked.length(), 0.36, "Obstruction should move camera inward with clearance.")
	var released: Vector3 = controller.call("advance", origin, desired, false, Vector3.ZERO, 0.016)
	_expect(released.length() > blocked.length() and released.length() < desired.length(), "Clear path should release camera smoothly.")
	controller.call("reset")
	var reset_position: Vector3 = controller.call("advance", origin, desired, false, Vector3.ZERO, 0.016)
	_expect_near(reset_position.length(), 1.2, "Reset should discard the previous obstruction distance.")
	if _failed:
		quit(1)
		return
	print("M10 camera collision presentation checks passed.")
	quit(0)

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)

func _expect_near(actual: float, expected: float, message: String) -> void:
	if absf(actual - expected) > 0.001:
		_failed = true
		push_error("%s Actual: %.4f, expected: %.4f" % [message, actual, expected])
