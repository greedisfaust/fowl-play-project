## Headless regression checks for local first-person camera presentation.
extends SceneTree

const CAMERA_PRESENTATION = preload("res://player/camera_presentation.gd")
var _failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_check_idle_and_locomotion_blend()
	_check_authored_camera_transform_is_preserved()
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
	var peak_offset: float = 0.0
	var peak_rotation: float = 0.0
	for index: int in range(60):
		moving = controller.call("advance", 0.016, Vector3(0.0, 0.0, -3.8), 0.0, true, true)
		peak_offset = maxf(peak_offset, Vector3(moving.offset).length())
		peak_rotation = maxf(peak_rotation, Vector3(moving.rotation).length())
	if float(moving.motion_weight) < 0.5 or peak_offset < 0.02:
		_fail("Ordinary walking should produce clearly measurable camera bob")
	if peak_rotation < 0.01:
		_fail("Walking should include a visible first-person gait rotation")
	var strafe_controller: RefCounted = CAMERA_PRESENTATION.new()
	var peak_strafe_roll: float = 0.0
	for index: int in range(30):
		var strafing: Dictionary = strafe_controller.call("advance", 0.016, Vector3(3.8, 0.0, 0.0), 0.0, true, true)
		peak_strafe_roll = maxf(peak_strafe_roll, absf(Vector3(strafing.rotation).z))
	if peak_strafe_roll < 0.02:
		_fail("Strafing should visibly roll the first-person camera")
	var disabled: Dictionary = controller.call("advance", 0.2, Vector3.ZERO, 0.0, true, false)
	if Vector3(disabled.offset).length() > peak_offset + 0.1:
		_fail("Disabled presentation should remain bounded")

func _check_authored_camera_transform_is_preserved() -> void:
	var authored: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0.0, -0.2, -1.2))
	var idle_transform: Transform3D = CAMERA_PRESENTATION.compose_camera_transform(authored, Vector3.ZERO, Vector3.ZERO)
	if idle_transform.origin.distance_to(authored.origin) > 0.0001:
		_fail("Idle camera presentation must preserve the authored camera position")
	var moving_transform: Transform3D = CAMERA_PRESENTATION.compose_camera_transform(authored, Vector3(0.0, 0.03, 0.0), Vector3(0.02, 0.0, 0.0))
	if moving_transform.origin.distance_to(authored.origin) < 0.02:
		_fail("Camera bob must offset the authored camera position instead of replacing it")
	if moving_transform.basis.get_euler().distance_to(authored.basis.get_euler()) < 0.01:
		_fail("Camera motion must layer rotation on top of the authored camera rotation")

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
