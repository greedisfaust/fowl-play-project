@tool
extends Node3D
class_name CasinoLightingBuilder

## Cinematic casino lighting: focused ceiling spots, restrained warm practical
## pools, a cool window edge, and very low-energy neon bounce.
## Attach to Architecture/Lighting. Coordinates follow the Casino root footprint.

const LightingRig = preload("res://world/shared/lighting/fowl_play_lighting_rig.gd")

@export_group("Gaming Floor")
@export var generate_gaming_lights: bool = true
@export var gaming_light_color: Color = Color(1.0, 0.78, 0.58, 1.0)
@export_range(0.1, 5.0, 0.1) var gaming_light_energy: float = 0.58
@export_range(3.0, 16.0, 0.5) var gaming_light_range: float = 9.0

@export_group("Bar")
@export var generate_bar_lights: bool = true
@export var bar_light_color: Color = Color(1.0, 0.68, 0.46, 1.0)
@export_range(0.1, 5.0, 0.1) var bar_light_energy: float = 0.82
@export_range(3.0, 16.0, 0.5) var bar_light_range: float = 7.0

@export_group("Window Fill")
@export var generate_window_fill: bool = true
@export var window_fill_color: Color = Color(0.42, 0.60, 0.82, 1.0)
@export_range(0.0, 2.0, 0.05) var window_fill_energy: float = 0.18
@export_range(2.0, 12.0, 0.5) var window_fill_range: float = 6.5

@export_group("Neon Accents")
@export var generate_neon_accents: bool = true
@export var cyan_neon_color: Color = Color(0.20, 0.72, 1.0, 1.0)
@export var magenta_neon_color: Color = Color(0.92, 0.24, 0.68, 1.0)
@export_range(0.05, 1.5, 0.05) var neon_light_energy: float = 0.14
@export_range(2.0, 9.0, 0.5) var neon_light_range: float = 4.5

@export_group("Light Quality")
@export_range(0.0, 1.0, 0.05) var light_specular: float = 0.28

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
	var scene_root: Node = get_tree().edited_scene_root
	if scene_root == null:
		return
	var old_root: Node = get_node_or_null(GENERATED_ROOT_NAME)
	if old_root != null:
		old_root.free()

	var generated_root: Node3D = Node3D.new()
	generated_root.name = GENERATED_ROOT_NAME
	add_child(generated_root)
	generated_root.owner = scene_root

	# The eight authored ceiling spots remain the primary pools over tables.
	# These low-power fills support the darker spaces between those pools.
	if generate_gaming_lights:
		_add_omni(generated_root, "Gaming_Ambient_Fill_West", Vector3(-17.0, 3.1, -17.0), gaming_light_color, gaming_light_energy, gaming_light_range, scene_root)
		_add_omni(generated_root, "Gaming_Ambient_Fill_Center", Vector3(-5.0, 3.1, -18.0), gaming_light_color, gaming_light_energy * 0.78, gaming_light_range, scene_root)
		_add_omni(generated_root, "Gaming_Ambient_Fill_South", Vector3(-16.0, 2.9, -7.0), gaming_light_color, gaming_light_energy * 0.62, gaming_light_range * 0.85, scene_root)

	if generate_bar_lights:
		_add_omni(generated_root, "Bar_Practical_Fill_01", Vector3(4.0, 3.0, -21.0), bar_light_color, bar_light_energy, bar_light_range, scene_root)
		_add_omni(generated_root, "Bar_Practical_Fill_02", Vector3(8.0, 3.0, -14.5), bar_light_color, bar_light_energy * 0.78, bar_light_range, scene_root)

	if generate_window_fill:
		_add_omni(generated_root, "Window_Cool_Edge_01", Vector3(-20.0, 2.35, -18.0), window_fill_color, window_fill_energy, window_fill_range, scene_root)
		_add_omni(generated_root, "Window_Cool_Edge_02", Vector3(-5.0, 2.35, -27.0), window_fill_color, window_fill_energy * 0.8, window_fill_range, scene_root)

	if generate_neon_accents:
		# Neon should tint nearby surfaces, not become another competing key light.
		_add_omni(generated_root, "Neon_Cyan_Gaming_Bounce", Vector3(-18.0, 2.5, -17.0), cyan_neon_color, neon_light_energy, neon_light_range, scene_root)
		_add_omni(generated_root, "Neon_Magenta_Bar_Bounce", Vector3(7.0, 2.5, -18.0), magenta_neon_color, neon_light_energy * 0.82, neon_light_range, scene_root)

func _add_omni(
	parent: Node3D,
	node_name: String,
	light_position: Vector3,
	color: Color,
	energy: float,
	light_range: float,
	scene_root: Node
) -> void:
	LightingRig.add_omni(parent, node_name, light_position, color, energy, light_range, scene_root, light_specular)
