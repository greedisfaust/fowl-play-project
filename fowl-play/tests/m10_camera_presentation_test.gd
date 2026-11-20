## Headless regression checks for local first-person camera presentation.
extends SceneTree

const CAMERA_PRESENTATION = preload("res://player/camera_presentation.gd")
var _failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_check_idle_and_locomotion_blend()
	_check_air_and_landing_response()
	_check_directional_impact_and_decay()
	if _failed:
		quit(1)
		return
	print("M10 camera presentation checks passed")
	quit(0)

func _check_idle_and_locomotion_blend() -> void:
	var controller: RefCounted = CAMERA_PRESENTATION.new()
	var idle: Dictionary = controller.call("advance", 0.016, Vector3.ZERO, 0.0, true, true)
	if Vector3(idle.offset).length() > 0.001:
		_fail("Idle camera should settle to neutral")
	var moving: Dictionary = {}
	for index: int in range(24):
		moving = controller.call("advance", 0.016, Vector3(0.0, 0.0, -5.5), 0.0, true, true)
	if float(moving.motion_weight) < 0.5 or Vector3(moving.offset).length() < 0.001:
		_fail("Walking/running should blend into subtle camera bob")
	var disabled: Dictionary = controller.call("advance", 0.2, Vector3.ZERO, 0.0, true, false)
	if Vector3(disabled.offset).length() > Vector3(moving.offset).length() + 0.1:
		_fail("Disabled presentation should remain bounded")

func _check_air_and_landing_response() -> void:
	var controller: RefCounted = CAMERA_PRESENTATION.new()
	controller.call("advance", 0.016, Vector3.ZERO, 0.0, true, true)
	var airborne: Dictionary = controller.call("advance", 0.016, Vector3.ZERO, 6.0, false, true)
	if absf(Vector3(airborne.rotation).x) < 0.001:
		_fail("Airborne vertical velocity should influence camera pitch")
	var landed: Dictionary = controller.call("advance", 0.016, Vector3.ZERO, -6.0, true, true)
	if float(landed.landing_weight) < 0.5:
		_fail("Landing should create a camera compression pulse")

func _check_directional_impact_and_decay() -> void:
	var controller: RefCounted = CAMERA_PRESENTATION.new()
	controller.call("add_impact", Vector3.RIGHT, 1.0, Basis.IDENTITY)
	var impact: Dictionary = controller.call("advance", 0.016, Vector3.ZERO, 0.0, true, true)
	if Vector3(impact.offset).length() < 0.001 or absf(Vector3(impact.rotation).z) < 0.001:
		_fail("Directional impact should add camera offset and roll")
	var settled: Dictionary = {}
	for index: int in range(90):
		settled = controller.call("advance", 0.016, Vector3.ZERO, 0.0, true, true)
	if Vector3(settled.offset).length() > Vector3(impact.offset).length():
		_fail("Impact camera response should decay smoothly")

func _fail(message: String) -> void:
	_failed = true
	push_error(message)
