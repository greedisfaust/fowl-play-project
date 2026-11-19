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
	var first_text_display: MeshInstance3D = first.get_node_or_null("TextDisplay") as MeshInstance3D
	var first_text: ScreenText = first.get_screen_text()

	_check(first.display_size == Vector2(2.0, 1.125), "WorldScreen should start at its documented physical size")
	_check(first_viewport.size == Vector2i(2048, 1152), "Default viewport should use the 1024 px/unit density")
	_check(first_viewport.use_hdr_2d, "WorldScreen SubViewport should preserve HDR 2D values")
	_check(first_viewport.transparent_bg, "Text viewport must have a transparent background")
	_check((first_display.mesh as PlaneMesh).size == first.display_size, "Physical display mesh should match the exported size")
	_check(first_text.terminal_font_size == 88, "Default 1152 px viewport should produce an 88 px terminal font")
	_check(first_text.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT, "Terminal text must stay left-aligned")
	_check(first_text.text_direction == Control.TEXT_DIRECTION_LTR, "Terminal text must read left-to-right")

	var first_style: StyleBoxFlat = first_text.get_theme_stylebox("normal") as StyleBoxFlat
	_check(is_equal_approx(first_style.bg_color.a, 0.0), "ScreenText stylebox must remain transparent")
	var first_shader: ShaderMaterial = first_text.material as ShaderMaterial
	_check(first_shader != null, "WorldScreen should assign its reusable HDR/LED shader to ScreenText")
	_check(is_equal_approx(float(first_shader.get_shader_parameter("hdr_boost")), 2.2), "Default text glow boost should be applied")
	_check(bool(first_shader.get_shader_parameter("led_matrix_enabled")), "LED matrix should be enabled by default")

	if first_text_display != null:
		_check((first_text_display.mesh as PlaneMesh).size == first.display_size, "Text overlay mesh should match the physical display size")
		var overlay: StandardMaterial3D = first_text_display.material_override as StandardMaterial3D
		_check(overlay != null, "TextDisplay should receive its own overlay material")
		if overlay != null:
			_check(overlay.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "Text overlay must use alpha transparency")
			_check(overlay.emission_enabled, "Text overlay must route the transparent viewport through emission")
			_check(overlay.emission_texture == first_viewport.get_texture(), "Only the transparent text viewport should feed overlay emission")
	else:
		print("WORLD SCREEN NOTE: TextDisplay editor task is not present in this scene revision; overlay assertions skipped.")

	first.display_size = Vector2(3.0, 1.6875)
	_check(first_viewport.size == Vector2i(3072, 1728), "Larger display size should scale viewport resolution proportionally")
	_check((first_display.mesh as PlaneMesh).size == Vector2(3.0, 1.6875), "Physical display mesh should resize with the exported size")
	if first_text_display != null:
		_check((first_text_display.mesh as PlaneMesh).size == Vector2(3.0, 1.6875), "Text overlay mesh should resize with the physical display")
	_check(first_text.terminal_font_size == 132, "Font size should scale with viewport height")

	first.text_scale = 1.5
	_check(first_text.terminal_font_size == 198, "Per-screen text scale should multiply the responsive font size")

	var second: WorldScreen = WorldScreenScene.instantiate() as WorldScreen
	root.add_child(second)
	await process_frame
	first.text_glow_boost = 3.5
	var second_shader: ShaderMaterial = second.get_screen_text().material as ShaderMaterial
	_check(is_equal_approx(float(first_shader.get_shader_parameter("hdr_boost")), 3.5), "Changing one screen's glow should update its material")
	_check(is_equal_approx(float(second_shader.get_shader_parameter("hdr_boost")), 2.2), "WorldScreen instances should keep independent shader settings")
	_check(first_display.mesh != (second.get_node("Display") as MeshInstance3D).mesh, "WorldScreen instances must not share mutable display meshes")
	_check(first_text_display == null or first_text_display.mesh != (second.get_node("TextDisplay") as MeshInstance3D).mesh, "WorldScreen instances must not share mutable overlay meshes")
	first.display_size = Vector2(4.0, 2.25)
	_check((second.get_node("Display") as MeshInstance3D).mesh is PlaneMesh and ((second.get_node("Display") as MeshInstance3D).mesh as PlaneMesh).size == Vector2(2.0, 1.125), "Resizing one WorldScreen must not resize another instance")
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
