## Reusable CMD-style text content for world-screen SubViewports.
## Keeps typography and the dark terminal backing independent from the physical screen housing.
class_name ScreenText
extends RichTextLabel

const DEBUG_CATEGORY: StringName = &"screen"
const DEFAULT_BACKGROUND: Color = Color(0.031, 0.051, 0.094, 1.0)
const DEFAULT_HEADER: Color = Color(0.85, 0.71, 0.36, 1.0)
const DEFAULT_BODY: Color = Color(0.96, 0.97, 1.0, 1.0)

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

	var backing: StyleBoxFlat = StyleBoxFlat.new()
	backing.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	var content_padding: float = float(terminal_font_size) * content_padding_ratio
	backing.content_margin_left = content_padding
	backing.content_margin_top = content_padding * 0.75
	backing.content_margin_right = content_padding
	backing.content_margin_bottom = content_padding * 0.75
	add_theme_stylebox_override("normal", backing)
