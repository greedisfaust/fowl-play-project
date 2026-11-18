## Headless checks for the gameplay cursor UI and Focus signal contract.
extends SceneTree

var _failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var cursor_scene: PackedScene = load("res://ui/gameplay_cursor.tscn") as PackedScene
	if cursor_scene == null:
		_fail("Gameplay cursor scene failed to load")
		quit(1)
		return
	var cursor_layer: CanvasLayer = cursor_scene.instantiate() as CanvasLayer
	root.add_child(cursor_layer)
	await process_frame
	var display: Control = cursor_layer.get_node("CursorDisplay") as Control
	if display == null:
		_fail("CursorDisplay control is missing")
		quit(1)
		return
	if display.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		_fail("Cursor must not intercept mouse input")
	var accent: Color = Color(0.8, 0.3, 0.6, 1.0)
	display.call("set_identity_color", accent)
	if not Color(display.get("identity_color")).is_equal_approx(accent):
		_fail("Cursor identity color setter did not update the accent")
	var target: Interactable = Interactable.new()
	display.call("_on_focus_target_changed", target)
	if not bool(display.get("is_hovering")):
		_fail("Cursor did not enter hover state for an Interactable")
	display.call("_on_focus_target_changed", null)
	if bool(display.get("is_hovering")):
		_fail("Cursor did not leave hover state when focus cleared")
	if not display.has_method("set_identity_color"):
		_fail("Cursor does not expose the future identity-color integration point")
	var focus_script: Script = load("res://player/focus.gd") as Script
	var focus_node: Node = focus_script.new() as Node
	if not focus_node.has_signal("focus_target_changed"):
		_fail("Focus node does not expose focus_target_changed")
	focus_node.free()
	target.free()
	cursor_layer.free()
	if _failed:
		quit(1)
		return
	print("M1 cursor checks passed")
	quit(0)

func _fail(message: String) -> void:
	_failed = true
	push_error(message)
