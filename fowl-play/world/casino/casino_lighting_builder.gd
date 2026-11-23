@tool
extends Node3D
class_name CasinoLightingBuilder

## Creates practical warm lighting for the casino. Attach to Architecture/Lighting.
## Coordinates follow the Casino root footprint.

@export_group("Gaming Floor")
@export var generate_gaming_lights: bool = true
@export var gaming_light_color: Color = Color(1.0, 0.72, 0.48, 1.0)
@export_range(0.1, 5.0, 0.1) var gaming_light_energy: float = 1.35
@export_range(3.0, 16.0, 0.5) var gaming_light_range: float = 8.5

@export_group("Bar")
@export var generate_bar_lights: bool = true
@export var bar_light_color: Color = Color(1.0, 0.62, 0.36, 1.0)
@export_range(0.1, 5.0, 0.1) var bar_light_energy: float = 1.1
@export_range(3.0, 16.0, 0.5) var bar_light_range: float = 7.0

@export_group("Window Fill")
@export var generate_window_fill: bool = true
@export var window_fill_color: Color = Color(0.42, 0.62, 0.88, 1.0)
@export_range(0.0, 2.0, 0.05) var window_fill_energy: float = 0.35
@export_range(2.0, 12.0, 0.5) var window_fill_range: float = 6.0

@export_group("Neon Accents")
@export var generate_neon_accents: bool = true
@export var cyan_neon_color: Color = Color(0.20, 0.72, 1.0, 1.0)
@export var magenta_neon_color: Color = Color(0.92, 0.24, 0.68, 1.0)
@export_range(0.05, 1.5, 0.05) var neon_light_energy: float = 0.42
@export_range(2.0, 9.0, 0.5) var neon_light_range: float = 5.5

@export_group("Generation")
@export var rebuild_lighting: bool = false:
	set(value):
		if value:
			call_deferred("_rebuild_lighting")

const GENERATED_ROOT_NAME: String = "_GeneratedCasinoLighting"

func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild_lighting()

func _rebuild_lighting() -> void:
	if not Engine.is_editor_hint():
		return
	var old_root: Node = get_node_or_null(GENERATED_ROOT_NAME)
	if old_root != null:
		old_root.free()

	var scene_root: Node = get_tree().edited_scene_root
	var generated_root: Node3D = Node3D.new()
	generated_root.name = GENERATED_ROOT_NAME
	add_child(generated_root)
	generated_root.owner = scene_root

	if generate_gaming_lights:
		_add_omni(generated_root, "Gaming_Warm_Key_01", Vector3(-17.0, 3.35, -22.0), gaming_light_color, gaming_light_energy, gaming_light_range, scene_root)
		_add_omni(generated_root, "Gaming_Warm_Key_02", Vector3(-8.0, 3.35, -22.0), gaming_light_color, gaming_light_energy, gaming_light_range, scene_root)
		_add_omni(generated_root, "Gaming_Warm_Key_03", Vector3(-17.0, 3.35, -12.0), gaming_light_color, gaming_light_energy, gaming_light_range, scene_root)
		_add_omni(generated_root, "Gaming_Warm_Key_04", Vector3(-8.0, 3.35, -12.0), gaming_light_color, gaming_light_energy, gaming_light_range, scene_root)
		_add_omni(generated_root, "Gaming_Warm_Key_05", Vector3(-1.0, 3.35, -17.0), gaming_light_color, gaming_light_energy * 0.8, gaming_light_range, scene_root)

	if generate_bar_lights:
		_add_omni(generated_root, "Bar_Warm_Key_01", Vector3(4.0, 3.25, -21.0), bar_light_color, bar_light_energy, bar_light_range, scene_root)
		_add_omni(generated_root, "Bar_Warm_Key_02", Vector3(8.0, 3.25, -15.0), bar_light_color, bar_light_energy, bar_light_range, scene_root)
		_add_omni(generated_root, "Bar_Warm_Key_03", Vector3(4.0, 3.25, -9.0), bar_light_color, bar_light_energy * 0.8, bar_light_range, scene_root)

	if generate_window_fill:
		_add_omni(generated_root, "Window_Cool_Fill_01", Vector3(-19.0, 2.4, -18.0), window_fill_color, window_fill_energy, window_fill_range, scene_root)
		_add_omni(generated_root, "Window_Cool_Fill_02", Vector3(-4.0, 2.4, -27.0), window_fill_color, window_fill_energy, window_fill_range, scene_root)

	if generate_neon_accents:
		# Low-energy colored pools support neon signage without overpowering the practical casino lights.
		_add_omni(generated_root, "Neon_Cyan_Gaming_01", Vector3(-18.0, 2.65, -17.0), cyan_neon_color, neon_light_energy, neon_light_range, scene_root)
		_add_omni(generated_root, "Neon_Magenta_Gaming_01", Vector3(-5.0, 2.65, -13.0), magenta_neon_color, neon_light_energy * 0.82, neon_light_range, scene_root)
		_add_omni(generated_root, "Neon_Cyan_Window_01", Vector3(-18.0, 2.5, -25.0), cyan_neon_color, neon_light_energy * 0.72, neon_light_range, scene_root)
		_add_omni(generated_root, "Neon_Magenta_Bar_01", Vector3(7.0, 2.65, -18.0), magenta_neon_color, neon_light_energy * 0.88, neon_light_range, scene_root)

func _add_omni(
	parent: Node3D,
	node_name: String,
	light_position: Vector3,
	color: Color,
	energy: float,
	light_range: float,
	scene_root: Node
) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.name = node_name
	light.position = light_position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.omni_attenuation = 1.2
	light.shadow_enabled = false
	parent.add_child(light)
	light.owner = scene_root
