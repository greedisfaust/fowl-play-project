## Reusable CMD-style text content for world-screen SubViewports.
## Keeps typography and the dark terminal backing independent from the physical screen housing.
class_name ScreenText
extends RichTextLabel

const DEBUG_CATEGORY: StringName = &"screen"
const DEFAULT_BACKGROUND: Color = Color(0.031, 0.051, 0.094, 1.0)
const DEFAULT_HEADER: Color = Color(0.85, 0.71, 0.36, 1.0)
const DEFAULT_BODY: Color = Color(0.96, 0.97, 1.0, 1.0)

const LAYOUT_STANDARD: StringName = &"standard"
const LAYOUT_WELCOME: StringName = &"welcome"
const LAYOUT_INFORMATION: StringName = &"information"
const LAYOUT_WARNING: StringName = &"warning"
const LAYOUT_SUCCESS: StringName = &"success"
const LAYOUT_CONFIRMATION: StringName = &"confirmation"

@export_group("Terminal Appearance")
@export var terminal_font: Font:
	set(value):
		terminal_font = value
		_apply_appearance()

@export_range(8, 512, 1) var terminal_font_size: int = 22:
	set(value):
		terminal_font_size = clampi(value, 8, 512)
		_apply_appearance()

@export_range(0.0, 1.5, 0.05) var content_padding_ratio: float = 0.45:
	set(value):
		content_padding_ratio = clampf(value, 0.0, 1.5)
		_apply_appearance()

@export var background_color: Color = DEFAULT_BACKGROUND:
	set(value):
		background_color = value
		_apply_appearance()

@export var header_color: Color = DEFAULT_HEADER
@export var body_color: Color = DEFAULT_BODY
@export var prompt_color: Color = DEFAULT_HEADER

var _debug_watch_name: StringName = &""
var _menu_option_lines: Array[int] = []
var _menu_option_end_line: int = -1

func _ready() -> void:
	bbcode_enabled = true
	scroll_active = true
	scroll_following = true
	fit_content = false
	selection_enabled = false
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vertical_alignment = VERTICAL_ALIGNMENT_TOP
	text_direction = Control.TEXT_DIRECTION_LTR
	_apply_appearance()

	var debug_hub: Node = get_node_or_null("/root/DebugHub")
	if is_instance_valid(debug_hub):
		_debug_watch_name = StringName("screen/%s/lines" % str(get_path()))
		debug_hub.call("watch", _debug_watch_name, func() -> int: return get_line_count())
		if debug_hub.call("is_on", DEBUG_CATEGORY):
			debug_hub.call("log", DEBUG_CATEGORY, "%s terminal text ready" % name)

func _exit_tree() -> void:
	var debug_hub: Node = get_node_or_null("/root/DebugHub")
	if is_instance_valid(debug_hub) and not _debug_watch_name.is_empty():
		debug_hub.call("unwatch", _debug_watch_name)

func append_header(value: String) -> void:
	_append_styled_line(value, header_color, true)

func append_paragraph(value: String) -> void:
	_append_styled_line(value, body_color, false)

func append_prompt(value: String) -> void:
	_append_styled_line(value, prompt_color, false)

func set_terminal_font(value: Font) -> void:
	terminal_font = value

func set_terminal_font_size(value: int) -> void:
	terminal_font_size = value

func clear_screen() -> void:
	clear()
	_menu_option_lines.clear()
	_menu_option_end_line = -1

## Replaces the display with selectable menu rows.
func show_menu(header: String, description: String, options: Array[Dictionary], selected_index: int, prompt: String = "") -> void:
	clear_screen()
	_menu_option_lines.clear()
	_menu_option_end_line = -1
	if not header.is_empty():
		_append_styled_line(header, header_color, true)
	if not description.is_empty():
		_append_styled_line(description, body_color, false)
	for index: int in options.size():
		var option: Dictionary = options[index]
		var enabled: bool = bool(option.get("enabled", true))
		var selected: bool = index == selected_index
		var marker: String = "> " if selected else "  "
		var option_color: Color = body_color
		if not enabled:
			option_color = Color(0.42, 0.46, 0.53, 1.0)
		elif selected:
			option_color = Color(0.30, 0.84, 0.92, 1.0)
		_menu_option_lines.append(maxi(0, get_line_count() - 1))
		_append_styled_line(marker + str(option.get("label", "")), option_color, selected)
	_menu_option_end_line = maxi(0, get_line_count() - 1)
	if not prompt.is_empty():
		_append_styled_line(prompt, prompt_color, false)

func get_menu_option_at_position(local_position: Vector2) -> int:
	if _menu_option_lines.is_empty() or _menu_option_end_line < 0:
		return -1
	var vertical_scroll_bar: VScrollBar = get_v_scroll_bar()
	var vertical_scroll: float = vertical_scroll_bar.value if vertical_scroll_bar != null else 0.0
	for option_index: int in _menu_option_lines.size():
		var line_index: int = _menu_option_lines[option_index]
		var end_line: int = _menu_option_end_line
		if option_index + 1 < _menu_option_lines.size():
			end_line = _menu_option_lines[option_index + 1]
		if line_index < 0 or end_line >= get_line_count() or end_line <= line_index:
			continue
		var line_top: float = float(get_line_offset(line_index)) - vertical_scroll
		var line_bottom: float = float(get_line_offset(end_line)) - vertical_scroll
		if local_position.y >= line_top and local_position.y < line_bottom:
			return option_index
	return -1

## Replaces the current display using the configured standard terminal colors.
func set_content(header: String, body: String, prompt: String = "") -> void:
	show_layout(LAYOUT_STANDARD, header, body, prompt)

## Replaces the display using a named presentation preset.
## Supported presets: standard, welcome, information, warning, success, confirmation.
func show_layout(layout: StringName, header: String, body: String, prompt: String = "") -> void:
	var selected_header_color: Color = header_color
	var selected_body_color: Color = body_color
	var selected_prompt_color: Color = prompt_color

	match layout:
		LAYOUT_STANDARD:
			pass
		LAYOUT_WELCOME:
			selected_header_color = Color(0.30, 0.84, 0.92, 1.0)
			selected_prompt_color = Color(0.30, 0.84, 0.92, 1.0)
		LAYOUT_INFORMATION:
			selected_header_color = Color(0.42, 0.76, 0.96, 1.0)
			selected_prompt_color = header_color
		LAYOUT_WARNING:
			selected_header_color = Color(1.0, 0.62, 0.24, 1.0)
			selected_body_color = Color(1.0, 0.90, 0.78, 1.0)
			selected_prompt_color = Color(1.0, 0.62, 0.24, 1.0)
		LAYOUT_SUCCESS:
			selected_header_color = Color(0.34, 0.86, 0.58, 1.0)
			selected_prompt_color = Color(0.34, 0.86, 0.58, 1.0)
		LAYOUT_CONFIRMATION:
			selected_header_color = header_color
			selected_prompt_color = Color(0.30, 0.84, 0.92, 1.0)
		_:
			push_warning("ScreenText received unknown layout '%s'; using standard colors." % String(layout))

	clear_screen()
	if not header.is_empty():
		_append_styled_line(header, selected_header_color, true)
	if not body.is_empty():
		_append_styled_line(body, selected_body_color, false)
	if not prompt.is_empty():
		_append_styled_line(prompt, selected_prompt_color, false)

func _append_styled_line(value: String, color: Color, bold: bool) -> void:
	var escaped: String = _escape_bbcode(value)
	var color_hex: String = color.to_html(false)
	var style_open: String = "[b]" if bold else ""
	var style_close: String = "[/b]" if bold else ""
	append_text("[color=#%s]%s%s%s[/color]\n" % [color_hex, style_open, escaped, style_close])

func _escape_bbcode(value: String) -> String:
	return value.replace("[", "[lb]").replace("]", "[rb]")

func _apply_appearance() -> void:
	if not is_inside_tree():
		return

	add_theme_color_override("default_color", body_color)
	add_theme_font_size_override("normal_font_size", terminal_font_size)
	add_theme_font_size_override("bold_font_size", terminal_font_size)
	add_theme_font_size_override("italics_font_size", terminal_font_size)
	add_theme_font_size_override("bold_italics_font_size", terminal_font_size)
	add_theme_font_size_override("mono_font_size", terminal_font_size)

	if terminal_font != null:
		add_theme_font_override("normal_font", terminal_font)
		add_theme_font_override("bold_font", terminal_font)
		add_theme_font_override("italics_font", terminal_font)
		add_theme_font_override("bold_italics_font", terminal_font)
		add_theme_font_override("mono_font", terminal_font)

	var parent_node: Node = get_parent()
	if parent_node != null:
		var background_node: ColorRect = parent_node.get_node_or_null("Background") as ColorRect
		if background_node != null:
			background_node.color = background_color

	var backing: StyleBoxFlat = StyleBoxFlat.new()
	backing.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	var content_padding: float = float(terminal_font_size) * content_padding_ratio
	backing.content_margin_left = content_padding
	backing.content_margin_top = content_padding * 0.75
	backing.content_margin_right = content_padding
	backing.content_margin_bottom = content_padding * 0.75
	add_theme_stylebox_override("normal", backing)
