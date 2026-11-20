## Reusable, size-adaptive 3D screen surface and transparent text-overlay controller.
@tool
class_name WorldScreen
extends Node3D

const MIN_VIEWPORT_DIMENSION: int = 256
const MAX_FONT_SIZE: int = 512
const TEXT_SHADER: Shader = preload("res://environment/kit/world_screen_text.gdshader")

var _text_shader_material: ShaderMaterial
var _overlay_material: StandardMaterial3D
var _missing_overlay_warning_sent: bool = false

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

@export_group("Text Glow")
@export var text_glow_enabled: bool = true:
	set(value):
		text_glow_enabled = value
		_apply_configuration()

@export_range(1.0, 8.0, 0.1) var text_glow_boost: float = 2.2:
	set(value):
		text_glow_boost = clampf(value, 1.0, 8.0)
		_apply_configuration()

@export_group("LED Matrix")
@export var led_matrix_enabled: bool = true:
	set(value):
		led_matrix_enabled = value
		_apply_configuration()

@export_range(1.0, 16.0, 0.5) var led_dot_size: float = 3.0:
	set(value):
		led_dot_size = clampf(value, 1.0, 16.0)
		_apply_configuration()

@export_range(0.0, 0.8, 0.01) var led_gap: float = 0.28:
	set(value):
		led_gap = clampf(value, 0.0, 0.8)
		_apply_configuration()

@export_range(0.01, 0.25, 0.01) var led_softness: float = 0.08:
	set(value):
		led_softness = clampf(value, 0.01, 0.25)
		_apply_configuration()

@export_group("Text Scaling")
@export_range(0.0, 1.5, 0.05) var content_padding_ratio: float = 0.70:
	set(value):
		content_padding_ratio = clampf(value, 0.0, 1.5)
		_apply_configuration()

@export var auto_scale_font_size: bool = true:
	set(value):
		auto_scale_font_size = value
		_apply_configuration()

## Font size as a proportion of viewport height. 0.0764 gives ~88 px at 1152 px tall.
@export_range(0.01, 0.2, 0.001) var font_size_ratio: float = 0.0764:
	set(value):
		font_size_ratio = clampf(value, 0.01, 0.2)
		_apply_configuration()

## Additional per-screen text sizing multiplier.
@export_range(0.25, 4.0, 0.05) var text_scale: float = 1.0:
	set(value):
		text_scale = clampf(value, 0.25, 4.0)
		_apply_configuration()

func _ready() -> void:
	# PackedScene instances can share SubResources. Localize every mutable resource
	# before the @tool controller changes mesh sizes or material parameters.
	_make_instance_resources_local(self)
	_apply_configuration()

func _make_instance_resources_local(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh != null:
			mesh_instance.mesh = mesh_instance.mesh.duplicate(true) as Mesh
		if mesh_instance.material_override != null:
			mesh_instance.material_override = mesh_instance.material_override.duplicate(true) as Material
		if mesh_instance.material_overlay != null:
			mesh_instance.material_overlay = mesh_instance.material_overlay.duplicate(true) as Material
	elif node is CanvasItem:
		var canvas_item: CanvasItem = node as CanvasItem
		if canvas_item.material != null:
			canvas_item.material = canvas_item.material.duplicate(true) as Material
	for child: Node in node.get_children():
		_make_instance_resources_local(child)

## Resize through display_size rather than scaling the root Node3D.
## Display is the opaque physical panel; TextDisplay is a transparent, emissive overlay.
func _apply_configuration() -> void:
	if not is_inside_tree():
		return

	var display: MeshInstance3D = get_node_or_null("Display") as MeshInstance3D
	var text_display: MeshInstance3D = get_node_or_null("TextDisplay") as MeshInstance3D
	var viewport: SubViewport = get_node_or_null("SubViewport") as SubViewport
	var terminal: ScreenText = get_screen_text()

	if display != null:
		_set_plane_size(display)
	if text_display != null:
		_set_plane_size(text_display)

	if viewport != null:
		viewport.size = _calculate_viewport_size()
		viewport.use_hdr_2d = true
		viewport.transparent_bg = true

	if terminal != null:
		terminal.content_padding_ratio = content_padding_ratio
		_ensure_text_shader(terminal)
		_update_text_shader_parameters()

	if text_display != null and viewport != null:
		_ensure_overlay_material(text_display, viewport)
	elif not _missing_overlay_warning_sent:
		push_warning("WorldScreen requires a sibling MeshInstance3D named TextDisplay for the isolated text overlay.")
		_missing_overlay_warning_sent = true

	if terminal != null and viewport != null and auto_scale_font_size:
		terminal.terminal_font_size = _calculate_font_size(viewport.size.y)

func _set_plane_size(mesh_instance: MeshInstance3D) -> void:
	var plane: PlaneMesh = mesh_instance.mesh as PlaneMesh
	if plane == null:
		plane = PlaneMesh.new()
		mesh_instance.mesh = plane
	plane.size = display_size

func _ensure_text_shader(terminal: ScreenText) -> void:
	if _text_shader_material == null:
		_text_shader_material = terminal.material as ShaderMaterial
	if _text_shader_material == null:
		_text_shader_material = ShaderMaterial.new()
		_text_shader_material.shader = TEXT_SHADER
		terminal.material = _text_shader_material
	elif _text_shader_material.shader != TEXT_SHADER:
		_text_shader_material.shader = TEXT_SHADER
		terminal.material = _text_shader_material

func _update_text_shader_parameters() -> void:
	if _text_shader_material == null:
		return
	_text_shader_material.set_shader_parameter("hdr_boost", text_glow_boost if text_glow_enabled else 1.0)
	_text_shader_material.set_shader_parameter("led_matrix_enabled", led_matrix_enabled)
	_text_shader_material.set_shader_parameter("led_dot_size", led_dot_size)
	_text_shader_material.set_shader_parameter("led_gap", led_gap)
	_text_shader_material.set_shader_parameter("led_softness", led_softness)

func _ensure_overlay_material(text_display: MeshInstance3D, viewport: SubViewport) -> void:
	if _overlay_material == null:
		_overlay_material = text_display.material_override as StandardMaterial3D
	if _overlay_material == null:
		_overlay_material = StandardMaterial3D.new()
		text_display.material_override = _overlay_material

	_overlay_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_overlay_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_overlay_material.albedo_color = Color.WHITE
	_overlay_material.albedo_texture = viewport.get_texture()
	_overlay_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	_overlay_material.emission_enabled = true
	_overlay_material.emission = Color.WHITE
	_overlay_material.emission_texture = viewport.get_texture()
	_overlay_material.emission_energy_multiplier = 1.0

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

## Renders menu rows through ScreenText; selection logic belongs to ScreenMenu.
func show_menu(header: String, description: String, options: Array[Dictionary], selected_index: int, prompt: String = "") -> void:
	var terminal: ScreenText = get_screen_text()
	if terminal != null:
		terminal.show_menu(header, description, options, selected_index, prompt)

## Replaces this screen's content using the configured standard colors.
func set_content(header: String, body: String, prompt: String = "") -> void:
	var terminal: ScreenText = get_screen_text()
	if terminal != null:
		terminal.set_content(header, body, prompt)

## Replaces this screen's content using a named presentation preset.
func show_layout(layout: StringName, header: String, body: String, prompt: String = "") -> void:
	var terminal: ScreenText = get_screen_text()
	if terminal != null:
		terminal.show_layout(layout, header, body, prompt)
