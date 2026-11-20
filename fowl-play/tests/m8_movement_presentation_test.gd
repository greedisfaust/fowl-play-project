## Headless checks for procedural acceleration, turning, jump and landing presentation.
extends SceneTree

const PRESENTATION = preload("res://ragdoll/procedural_movement_presentation.gd")
const LEG_CONTROLLER = preload("res://ragdoll/procedural_leg_controller.gd")

var _failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_check_acceleration_and_braking()
	_check_turn_counterbalance()
	_check_air_and_landing_transitions()
	_check_airborne_leg_pose()
	if _failed:
		quit(1)
		return
	print("M8 movement presentation checks passed")
	quit(0)

func _check_acceleration_and_braking() -> void:
	var controller: RefCounted = PRESENTATION.new()
	controller.call("advance", 0.1, Vector3(0.0, 0.0, -3.0), 0.0, true, 0.0, true, false)
	var accelerating: Vector3 = controller.call("advance", 0.1, Vector3(0.0, 0.0, -5.0), 0.0, true, 0.0, true, false)
	if accelerating.x <= 0.0:
		_fail("Forward acceleration should create a forward body lean")
	var braking: Vector3 = controller.call("advance", 0.1, Vector3.ZERO, 0.0, true, 0.0, true, false)
	if braking.x >= accelerating.x:
		_fail("Braking should transition away from the forward acceleration lean")
	var suppressed: Vector3 = controller.call("advance", 0.1, Vector3(0.0, 0.0, -6.0), 0.0, true, 0.0, false, false)
	if suppressed.length() >= accelerating.length():
		_fail("Carry/disabled presentation should blend toward neutral")

func _check_turn_counterbalance() -> void:
	var controller: RefCounted = PRESENTATION.new()
	controller.call("advance", 0.1, Vector3.ZERO, 0.0, true, 0.0, true, false)
	var turning: Vector3 = controller.call("advance", 0.1, Vector3.ZERO, 0.0, true, 0.15, true, false)
	if absf(turning.y) < 0.001 or absf(turning.z) < 0.001:
		_fail("Turning should create subtle torso yaw and counter-roll")

func _check_air_and_landing_transitions() -> void:
	var controller: RefCounted = PRESENTATION.new()
	controller.call("advance", 0.016, Vector3.ZERO, 0.0, true, 0.0, true, false)
	controller.call("advance", 0.1, Vector3.ZERO, 4.0, false, 0.0, true, false)
	if float(controller.get("air_pose_weight")) <= 0.0:
		_fail("Takeoff should blend into an airborne pose")
	controller.call("advance", 0.1, Vector3.ZERO, -3.0, false, 0.0, true, false)
	controller.call("advance", 0.016, Vector3.ZERO, -1.0, true, 0.0, true, false)
	if float(controller.get("landing_weight")) <= 0.0:
		_fail("Touchdown should trigger a short landing compression pulse")
	for index: int in range(30):
		controller.call("advance", 0.016, Vector3.ZERO, 0.0, true, 0.0, true, false)
	if float(controller.get("landing_weight")) > 0.01:
		_fail("Landing compression should smoothly return to neutral")

func _check_airborne_leg_pose() -> void:
	var controller: RefCounted = LEG_CONTROLLER.new()
	controller.call("update", 0.1, Vector3(0.0, 0.0, -3.8), true, 0.0, 0.0)
	var grounded_thigh: Quaternion = controller.get("left_thigh_rotation")
	controller.call("update", 0.1, Vector3(0.0, 0.0, -3.8), false, 4.0, 0.0)
	var airborne_thigh: Quaternion = controller.get("left_thigh_rotation")
	if airborne_thigh.angle_to(grounded_thigh) < 0.03:
		_fail("Airborne leg pose should visibly differ from grounded gait")
	controller.call("update", 0.1, Vector3.ZERO, true, -1.0, 1.0)
	if float(controller.get("landing_weight")) < 0.99:
		_fail("Landing weight should be accepted by the leg controller")

func _fail(message: String) -> void:
	_failed = true
	push_error(message)
