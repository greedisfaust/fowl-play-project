## Headless regression checks for comfortable local ragdoll camera follow and recovery easing.
extends SceneTree

const RAGDOLL_CAMERA = preload("res://player/ragdoll_camera_presentation.gd")

var _failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var controller: RefCounted = RAGDOLL_CAMERA.new()
	var initial: Transform3D = Transform3D(Basis.IDENTITY, Vector3(1.0, 2.0, 3.0))
	var target: Transform3D = Transform3D(Basis.from_euler(Vector3(0.0, PI * 0.5, 0.0)), Vector3(5.0, 2.0, 3.0))
	controller.call("begin", initial)

	var held: Transform3D = controller.call("advance", target, 0.0)
	_expect_near(held.origin.distance_to(initial.origin), 0.0, "A zero-delta update should preserve the starting camera pose.")

	var first_step: Transform3D = controller.call("advance", target, 0.016)
	_expect(first_step.origin.distance_to(initial.origin) > 0.0, "Ragdoll camera should begin following the simulated head.")
	_expect(first_step.origin.distance_to(target.origin) > 0.1, "Ragdoll camera position should ease rather than snap to the head.")
	_expect(first_step.basis.z.distance_to(target.basis.z) > 0.01, "Ragdoll camera rotation should ease toward natural head tilt.")

	var settled: Transform3D = first_step
	for frame: int in range(180):
		settled = controller.call("advance", target, 0.016)
	_expect(settled.origin.distance_to(target.origin) < 0.01, "Ragdoll camera should converge to the live head position.")
	_expect(settled.basis.z.distance_to(target.basis.z) < 0.01, "Ragdoll camera should converge to the live head orientation.")

	_expect_near(RAGDOLL_CAMERA.recovery_weight(0.0, 1.0), 0.0, "Recovery easing should begin at zero.")
	_expect_near(RAGDOLL_CAMERA.recovery_weight(0.5, 1.0), 0.5, "Recovery easing should remain centered at the midpoint.")
	_expect_near(RAGDOLL_CAMERA.recovery_weight(1.0, 1.0), 1.0, "Recovery easing should finish at one.")
	_expect(RAGDOLL_CAMERA.recovery_weight(0.25, 1.0) < RAGDOLL_CAMERA.recovery_weight(0.5, 1.0), "Recovery easing should progress monotonically.")

	controller.call("reset")
	var reset_pose: Transform3D = controller.call("advance", target, 0.016)
	_expect_near(reset_pose.origin.distance_to(target.origin), 0.0, "Reset should allow the next ragdoll session to initialize cleanly.")

	if _failed:
		quit(1)
		return
	print("M10 ragdoll camera comfort checks passed.")
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
