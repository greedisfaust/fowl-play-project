## Headless checks for the reusable physical USE button presentation component.
extends SceneTree

const PhysicalUseButton = preload("res://interaction/physical_use_button.gd")

var _failed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var target: Node3D = Node3D.new()
	target.name = "ButtonFixture"
	root.add_child(target)
	var cap: Node3D = Node3D.new()
	cap.name = "Cap"
	cap.position = Vector3(0.0, 0.2, 0.0)
	target.add_child(cap)
	var interactable: Interactable = Interactable.new()
	interactable.kind = Interactable.InteractionKind.USE
	interactable.prompt_text = "Test button"
	target.add_child(interactable)
	var button: PhysicalUseButton = PhysicalUseButton.new()
	button.cap = cap
	button.interactable = interactable
	target.add_child(button)
	await process_frame
	var rest_position: Vector3 = cap.position
	button._on_interacted(target, &"grab")
	_check(button.press_count == 0, "GRAB must not activate a physical USE button")
	button._on_interacted(target, &"use")
	_check(button.press_count == 1, "USE should trigger one press")
	await process_frame
	var in_motion_position: Vector3 = cap.position
	_check(not in_motion_position.is_equal_approx(rest_position), "Cap should begin moving inward after USE")
	button._on_interacted(target, &"use")
	_check(button.press_count == 2, "A second USE should retrigger while the first animation is active")
	_check(cap.position.is_equal_approx(in_motion_position), "Retrigger must not snap the cap to a new starting position")
	for frame: int in range(40):
		await process_frame
	_check(cap.position.distance_to(rest_position) < 0.001, "Cap should spring back to its exact rest position")
	_check(button.press_count == 2, "Press count should reflect accepted USE events only")
	target.queue_free()
	await process_frame
	if _failed:
		quit(1)
		return
	print("PHYSICAL USE BUTTON PASS")
	quit(0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("PHYSICAL USE BUTTON FAIL: %s" % message)
