## Headless contract checks for reusable CMD-style world-screen text.
extends SceneTree

const ScreenTextScript = preload("res://ui/screen_text.gd")

var _failed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var terminal: ScreenText = ScreenTextScript.new()
	root.add_child(terminal)
	await process_frame
	_check(terminal.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT, "Terminal text must stay left-aligned")
	_check(terminal.text_direction == Control.TEXT_DIRECTION_LTR, "Terminal text must read left-to-right")
	_check(terminal.autowrap_mode == TextServer.AUTOWRAP_ARBITRARY, "Long unbroken text must wrap within the screen width")
	_check(terminal.clip_contents, "Screen text must be clipped to the viewport rectangle")
	_check(terminal.bbcode_enabled, "Terminal must support per-line header/body colors")
	_check(terminal.background_color == ScreenText.DEFAULT_BACKGROUND, "Terminal should use the dark blue-black backing by default")
	_check(terminal.header_color == ScreenText.DEFAULT_HEADER, "Terminal should use gold headers by default")
	_check(terminal.body_color == ScreenText.DEFAULT_BODY, "Terminal should use bright body text by default")
	terminal.append_header("REGISTRATION SYSTEM")
	terminal.append_paragraph("Welcome, player.")
	terminal.append_prompt("C:\\FOWLPLAY> _")
	var parsed: String = terminal.get_parsed_text()
	_check(parsed.contains("REGISTRATION SYSTEM"), "Header text should be appended")
	_check(parsed.contains("Welcome, player."), "Paragraph text should be appended")
	_check(parsed.contains("C:\\FOWLPLAY> _"), "Prompt text should be appended")
	terminal.set_content("NEW SESSION", "First body line.\nSecond body line.", "PRESS USE")
	var replaced: String = terminal.get_parsed_text()
	_check(replaced.contains("NEW SESSION"), "set_content should display the replacement header")
	_check(replaced.contains("First body line.") and replaced.contains("Second body line."), "set_content should preserve multi-line body text")
	_check(replaced.contains("PRESS USE"), "set_content should display the replacement prompt")
	_check(not replaced.contains("REGISTRATION SYSTEM") and not replaced.contains("Welcome, player."), "set_content should replace rather than append old content")
	terminal.show_layout(ScreenText.LAYOUT_WARNING, "SYSTEM WARNING", "Proceed with caution.", "CHECK STATUS")
	var warning_text: String = terminal.get_parsed_text()
	_check(warning_text.contains("SYSTEM WARNING") and warning_text.contains("Proceed with caution.") and warning_text.contains("CHECK STATUS"), "Warning layout should display all supplied sections")
	_check(not warning_text.contains("NEW SESSION"), "show_layout should replace the previous layout")
	terminal.size = Vector2(1024.0, 576.0)
	var menu_options: Array[Dictionary] = [
		{"id": &"first", "label": "FIRST OPTION"},
		{"id": &"second", "label": "SECOND OPTION"}
	]
	terminal.show_menu("CLICK TEST", "Choose one.", menu_options, 0, "CLICK TO SELECT")
	await process_frame
	var option_characters: Array = terminal.get("_menu_option_character_starts")
	_check(option_characters.size() == 2, "Menu should retain one rendered line index per option")
	if option_characters.size() == 2:
		var first_line: int = terminal.get_character_line(int(option_characters[0]))
		var second_line: int = terminal.get_character_line(int(option_characters[1]))
		var first_y: float = (float(terminal.get_line_offset(first_line)) + float(terminal.get_line_offset(second_line))) * 0.5
		_check(terminal.get_menu_option_at_position(Vector2(500.0, first_y)) == 0, "First option rendered line should resolve to its index")
		var end_line: int = terminal.get_character_line(int(terminal.get("_menu_option_end_character")))
		var second_y: float = (float(terminal.get_line_offset(second_line)) + float(terminal.get_line_offset(end_line))) * 0.5
		_check(terminal.get_menu_option_at_position(Vector2(500.0, second_y)) == 1, "Second option rendered line should resolve to its index")
	terminal.clear_screen()
	_check(terminal.get_parsed_text().is_empty(), "clear_screen should remove existing content")
	_check(terminal.get_menu_option_at_position(Vector2.ZERO) == -1, "Clearing the screen should clear menu hit targets")
	terminal.queue_free()
	await process_frame
	if _failed:
		quit(1)
		return
	print("SCREEN TEXT PASS")
	quit(0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("SCREEN TEXT FAIL: %s" % message)
