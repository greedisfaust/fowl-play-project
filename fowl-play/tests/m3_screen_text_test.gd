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
	terminal.clear_screen()
	_check(terminal.get_parsed_text().is_empty(), "clear_screen should remove existing content")
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
