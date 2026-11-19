## Reusable, size-adaptive 3D screen surface and SubViewport controller.
@tool
class_name WorldScreen
extends Node3D

const MIN_VIEWPORT_DIMENSION: int = 256
const MAX_FONT_SIZE: int = 512

@export_group("Display Size")
@export var display_size: Vector2 = Vector2(2.0, 1.125):
	set(value):
		display_size = Vector2(maxf(value.x, 0.1), maxf(value.y, 0.1))
		_apply_configuration()

@export_range(128, 2048, 64) var pixels_per_unit: int = 1024:
	set(value):
		pixels_per_unit = maxi(value, 128)
		_apply_configuration()

@export_range(256, 8192, 256) var max_viewport_dimension: int = 4096:
	set(value):
		max_viewport_dimension = maxi(value, MIN_VIEWPORT_DIMENSION)
		_apply_configuration()

@export_group("Text Scaling")
@export var auto_scale_font_size: bool = true:
	set(value):
		auto_scale_font_size = value
		_apply_configuration()

## Font size as a proportion of the viewport height. 0.0764 gives ~88 px at 1152 px tall.
@export_range(0.01, 0.2, 0.001) var font_size_ratio: float = 0.0764:
	set(value):
		font_size_ratio = clampf(value, 0.01, 0.2)
		_apply_configuration()

## Additional per-screen text sizing multiplier. Use this when a particular screen needs larger or smaller text.
@export_range(0.25, 4.0, 0.05) var text_scale: float = 1.0:
	set(value):
		text_scale = clampf(value, 0.25, 4.0)
		_apply_configuration()

func _ready() -> void:
	_apply_configuration()

## Recalculate the screen mesh, viewport resolution, and responsive text size.
## Resize screens through display_size rather than scaling the root node.
func _apply_configuration() -> void:
	if not is_inside_tree():
		return

	var display: MeshInstance3D = get_node_or_null("Display") as MeshInstance3D
	var viewport: SubViewport = get_node_or_null("SubViewport") as SubViewport
	var terminal: ScreenText = get_node_or_null("SubViewport/ScreenText") as ScreenText

	if display != null:
		var plane: PlaneMesh = display.mesh as PlaneMesh
		if plane == null:
			plane = PlaneMesh.new()
			display.mesh = plane
		plane.size = display_size

	if viewport != null:
		viewport.size = _calculate_viewport_size()

	if terminal != null and viewport != null and auto_scale_font_size:
		terminal.terminal_font_size = _calculate_font_size(viewport.size.y)

func _calculate_viewport_size() -> Vector2i:
	var raw_width: int = maxi(MIN_VIEWPORT_DIMENSION, roundi(display_size.x * float(pixels_per_unit)))
	var raw_height: int = maxi(MIN_VIEWPORT_DIMENSION, roundi(display_size.y * float(pixels_per_unit)))
	var largest_dimension: int = maxi(raw_width, raw_height)
	var resolution_scale: float = minf(1.0, float(max_viewport_dimension) / float(largest_dimension))
	var width: int = maxi(MIN_VIEWPORT_DIMENSION, roundi(float(raw_width) * resolution_scale))
	var height: int = maxi(MIN_VIEWPORT_DIMENSION, roundi(float(raw_height) * resolution_scale))
	width += width % 2
	height += height % 2
	return Vector2i(width, height)

func _calculate_font_size(viewport_height: int) -> int:
	var scaled_size: int = roundi(float(viewport_height) * font_size_ratio * text_scale)
	return clampi(scaled_size, 8, MAX_FONT_SIZE)

func get_screen_text() -> ScreenText:
	return get_node_or_null("SubViewport/ScreenText") as ScreenText

func set_display_size(value: Vector2) -> void:
	display_size = value

func set_text_scale(value: float) -> void:
	text_scale = value

func append_header(value: String) -> void:
	var terminal: ScreenText = get_screen_text()
	if terminal != null:
		terminal.append_header(value)

func append_paragraph(value: String) -> void:
	var terminal: ScreenText = get_screen_text()
	if terminal != null:
		terminal.append_paragraph(value)

func append_prompt(value: String) -> void:
	var terminal: ScreenText = get_screen_text()
	if terminal != null:
		terminal.append_prompt(value)

func clear_screen() -> void:
	var terminal: ScreenText = get_screen_text()
	if terminal != null:
		terminal.clear_screen()
