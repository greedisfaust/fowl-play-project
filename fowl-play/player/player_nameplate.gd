## SubViewport-rendered, billboarded player identity panel.
## Instance this scene beneath Player; the scene owns the authored UI hierarchy.
extends Node3D

const PlayerIdentity = preload("res://core/player_identity.gd")
const DISPLAY_SIZE: Vector2i = Vector2i(512, 128)
const PANEL_SIZE: Vector2 = Vector2(2.0, 0.5)
const NAME_FONT: Font = preload("res://assets/fonts/JetBrainsMonoNL-Regular.ttf")

@export var hide_for_local_player: bool = true
@export_range(0.0, 100.0, 0.5) var fade_start_distance: float = 18.0
@export_range(0.1, 150.0, 0.5) var fade_end_distance: float = 28.0
@export_range(0.1, 1.0, 0.01) var visual_scale: float = 0.78
@export_range(0.0, 1.0, 0.01) var idle_opacity: float = 0.12
@export_range(0.0, 1.0, 0.01) var hover_opacity: float = 1.0
@export_range(0.1, 30.0, 0.1) var opacity_response: float = 10.0

@onready var panel_mesh: MeshInstance3D = get_node_or_null("Panel") as MeshInstance3D
@onready var display: SubViewport = get_node_or_null("Display") as SubViewport
@onready var ui: Control = get_node_or_null("Display/UI") as Control
@onready var background: Panel = get_node_or_null("Display/UI/Background") as Panel
@onready var accent: ColorRect = get_node_or_null("Display/UI/Accent") as ColorRect
@onready var nickname_label: Label = get_node_or_null("Display/UI/Nickname") as Label
@onready var status_label: Label = get_node_or_null("Display/UI/Status") as Label
@onready var divider: ColorRect = get_node_or_null("Display/UI/Divider") as ColorRect

var _identity_color: Color = Color("#E6A64A")

func _ready() -> void:
	visible = false
	scale = Vector3.ONE * visual_scale
	_configure_display()
	_configure_ui()
	_configure_panel()
	_set_plate_opacity(idle_opacity)

func _process(delta: float) -> void:
	if not visible:
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return

	# QuadMesh faces +Z. Turn that face toward the camera instead of showing
	# its back side, which makes the SubViewport text appear mirrored.
	if global_position.distance_squared_to(camera.global_position) > 0.0001:
		look_at(camera.global_position, Vector3.UP)
		rotate_object_local(Vector3.UP, PI)

	var distance: float = global_position.distance_to(camera.global_position)
	var fade_span: float = maxf(fade_end_distance - fade_start_distance, 0.1)
	var distance_alpha: float = 1.0 - clampf((distance - fade_start_distance) / fade_span, 0.0, 1.0)
	var target_opacity: float = hover_opacity if _is_aimed_at_panel(camera) else idle_opacity
	target_opacity *= distance_alpha
	var current_opacity: float = _get_plate_opacity()
	_set_plate_opacity(move_toward(current_opacity, target_opacity, opacity_response * delta))
	# Identity text stays crisp and fully readable; only the decorative panel fades.
	if nickname_label != null:
		nickname_label.modulate.a = 1.0
	if status_label != null:
		status_label.modulate.a = 1.0

## The captured gameplay cursor is centered; when the OS cursor is visible,
## use its actual position. The test is against the rendered quad, not physics.
func _is_aimed_at_panel(camera: Camera3D) -> bool:
	if panel_mesh == null or not is_instance_valid(camera):
		return false
	var viewport: Viewport = get_viewport()
	var pointer_position: Vector2 = viewport.get_mouse_position()
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		pointer_position = viewport.get_visible_rect().size * 0.5

	var ray_origin: Vector3 = camera.project_ray_origin(pointer_position)
	var ray_direction: Vector3 = camera.project_ray_normal(pointer_position)
	var panel_normal: Vector3 = panel_mesh.global_basis.z.normalized()
	var denominator: float = panel_normal.dot(ray_direction)
	if absf(denominator) < 0.0001:
		return false
	var ray_distance: float = panel_normal.dot(panel_mesh.global_position - ray_origin) / denominator
	if ray_distance < 0.0:
		return false

	var hit_world: Vector3 = ray_origin + ray_direction * ray_distance
	var hit_local: Vector3 = panel_mesh.global_transform.affine_inverse() * hit_world
	var half_size: Vector2 = PANEL_SIZE * 0.5
	return absf(hit_local.x) <= half_size.x and absf(hit_local.y) <= half_size.y

func apply_player_identity(identity: PlayerIdentity, is_local_player: bool) -> void:
	if identity == null:
		visible = false
		if nickname_label != null:
			nickname_label.text = ""
		return
	_identity_color = identity.get_color()
	if nickname_label != null:
		nickname_label.text = identity.nickname
	if accent != null:
		accent.color = _identity_color
	if status_label != null:
		status_label.text = "PLAYER  /  REGISTERED"
	visible = not (hide_for_local_player and is_local_player)
	_set_plate_opacity(idle_opacity)
	if nickname_label != null:
		nickname_label.modulate.a = 1.0
	if status_label != null:
		status_label.modulate.a = 1.0

func _get_plate_opacity() -> float:
	if background != null:
		return background.modulate.a
	if accent != null:
		return accent.modulate.a
	if divider != null:
		return divider.modulate.a
	return idle_opacity

func _set_plate_opacity(value: float) -> void:
	var alpha: float = clampf(value, 0.0, 1.0)
	if background != null:
		background.modulate.a = alpha
	if accent != null:
		accent.modulate.a = alpha
	if divider != null:
		divider.modulate.a = alpha

func _configure_display() -> void:
	if display == null:
		push_warning("Player NamePlate requires a SubViewport named Display.")
		return
	display.size = DISPLAY_SIZE
	display.transparent_bg = true
	display.render_target_update_mode = SubViewport.UPDATE_ALWAYS

func _configure_ui() -> void:
	if ui == null:
		push_warning("Player NamePlate requires Display/UI.")
		return
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if background != null:
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var panel_style: StyleBoxFlat = StyleBoxFlat.new()
		panel_style.bg_color = Color("#101820")
		panel_style.border_color = Color("#34404A")
		panel_style.set_border_width_all(2)
		panel_style.set_corner_radius_all(8)
		panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
		panel_style.shadow_size = 8
		background.add_theme_stylebox_override("panel", panel_style)
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if accent != null:
		accent.position = Vector2(0.0, 0.0)
		accent.size = Vector2(8.0, float(DISPLAY_SIZE.y))
		accent.color = _identity_color
		accent.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if nickname_label != null:
		nickname_label.position = Vector2(8.0, 15.0)
		nickname_label.size = Vector2(float(DISPLAY_SIZE.x - 16), 58.0)
		nickname_label.add_theme_font_override("font", NAME_FONT)
		nickname_label.add_theme_font_size_override("font_size", 38)
		nickname_label.add_theme_color_override("font_color", Color("#F4F6F7"))
		nickname_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.65))
		nickname_label.add_theme_constant_override("shadow_offset_x", 1)
		nickname_label.add_theme_constant_override("shadow_offset_y", 2)
		nickname_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nickname_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		nickname_label.clip_text = true
		nickname_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if divider != null:
		divider.position = Vector2(28.0, 82.0)
		divider.size = Vector2(450.0, 1.0)
		divider.color = Color(0.55, 0.62, 0.68, 0.28)
		divider.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if status_label != null:
		status_label.position = Vector2(28.0, 91.0)
		status_label.size = Vector2(450.0, 23.0)
		status_label.add_theme_font_override("font", NAME_FONT)
		status_label.add_theme_font_size_override("font_size", 13)
		status_label.add_theme_color_override("font_color", Color("#AAB7C1"))
		status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _configure_panel() -> void:
	if panel_mesh == null:
		push_warning("Player NamePlate requires a MeshInstance3D named Panel.")
		return
	var quad: QuadMesh = QuadMesh.new()
	quad.size = PANEL_SIZE
	panel_mesh.mesh = quad
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	if display != null:
		material.albedo_texture = display.get_texture()
	material.albedo_color = Color.WHITE
	panel_mesh.material_override = material
