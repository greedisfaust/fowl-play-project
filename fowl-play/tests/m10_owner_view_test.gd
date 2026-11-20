## Headless regression checks for first-person owner body visibility.
extends SceneTree

const OWNER_VIEW = preload("res://player/owner_view_presentation.gd")
var _failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_expect_near(OWNER_VIEW.leg_visibility_weight(0.0), 0.0, "Legs should be hidden at the horizon.")
	var partial: float = OWNER_VIEW.leg_visibility_weight(deg_to_rad(-36.5))
	_expect(partial > 0.0 and partial < 1.0, "Legs should fade in during a partial downward look.")
	_expect_near(OWNER_VIEW.leg_visibility_weight(deg_to_rad(-65.0)), 1.0, "Legs should be fully visible when looking down.")
	_expect_near(OWNER_VIEW.leg_visibility_weight(deg_to_rad(30.0)), 0.0, "Looking up should not reveal the legs.")
	if _failed:
		quit(1)
		return
	print("M10 owner-view presentation checks passed.")
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
