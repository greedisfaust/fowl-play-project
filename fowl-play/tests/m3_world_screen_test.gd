## Headless contract checks for the reusable, size-adaptive WorldScreen scene.
extends SceneTree

const WorldScreenScene = preload("res://environment/kit/world_screen.tscn")

var _failed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var first: WorldScreen = WorldScreenScene.instantiate() as WorldScreen
	root.add_child(first)
	await process_frame

	var first_viewport: SubViewport = first.get_node("SubViewport") as SubViewport
	var first_display: MeshInstance3D = first.get_node("Display") as MeshInstance3D
	var first_text: ScreenText = first.get_screen_text()

	_check(first.display_size == Vector2(2.0, 1.125), "WorldScreen should start at its documented physical size")
	_check(first_viewport.size == Vector2i(2048, 1152), "Default viewport should use the 1024 px/unit density")
	_check((first_display.mesh as PlaneMesh).size == first.display_size, "Display mesh should match the exported display size")
	_check(first_text.terminal_font_size == 88, "Default 1152 px viewport should produce an 88 px terminal font")
	_check(first_text.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT, "Terminal text must stay left-aligned")
	_check(first_text.text_direction == Control.TEXT_DIRECTION_LTR, "Terminal text must read left-to-right")

	first.display_size = Vector2(3.0, 1.6875)
	_check(first_viewport.size == Vector2i(3072, 1728), "Larger display size should scale viewport resolution proportionally")
	_check((first_display.mesh as PlaneMesh).size == Vector2(3.0, 1.6875), "Display mesh should resize with the exported size")
	_check(first_text.terminal_font_size == 132, "Font size should scale with viewport height")

	first.text_scale = 1.5
	_check(first_text.terminal_font_size == 198, "Per-screen text scale should multiply the responsive font size")

	var second: WorldScreen = WorldScreenScene.instantiate() as WorldScreen
	root.add_child(second)
	await process_frame
	first.append_header("FIRST SCREEN")
	second.append_paragraph("SECOND SCREEN")
	_check(first.get_screen_text().get_parsed_text().contains("FIRST SCREEN"), "First instance should receive its own content")
	_check(not first.get_screen_text().get_parsed_text().contains("SECOND SCREEN"), "First instance must not receive second instance content")
	_check(second.get_screen_text().get_parsed_text().contains("SECOND SCREEN"), "Second instance should receive its own content")

	first.clear_screen()
	_check(first.get_screen_text().get_parsed_text().is_empty(), "WorldScreen clear_screen should clear its own content")

	first.queue_free()
	second.queue_free()
	await process_frame
	if _failed:
		quit(1)
		return
	print("WORLD SCREEN PASS")
	quit(0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("WORLD SCREEN FAIL: %s" % message)
