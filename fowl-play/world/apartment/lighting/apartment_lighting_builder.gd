@tool
extends Node3D
class_name ApartmentLightingBuilder

## Editor-time warm lighting setup for the Apartment.
## Attach to Environment/Lighting at local origin.
## Creates real OmniLight3D nodes only; it does not modify architectural geometry.

@export_group("Main Room")
@export var generate_main_room_lights: bool = true
@export var main_room_light_color: Color = Color(1.0, 0.78, 0.58, 1.0)
@export_range(0.1, 4.0, 0.05) var main_room_light_energy: float = 1.35
@export_range(3.0, 16.0, 0.5) var main_room_light_range: float = 9.0
@export_range(0.0, 2.0, 0.05) var window_side_fill_energy: float = 0.55

@export_group("Hallway")
@export var generate_hallway_lights: bool = true
@export var hallway_light_color: Color = Color(1.0, 0.68, 0.43, 1.0)
@export_range(0.1, 3.0, 0.05) var hallway_light_energy: float = 0.95
@export_range(2.0, 10.0, 0.5) var hallway_light_range: float = 5.2
@export var hallway_light_start_z: float = -14.0
@export var hallway_light_end_z: float = 1.5
@export_range(2, 8, 1) var hallway_light_count: int = 4

@export_group("Elevator Lobby")
@export var generate_lobby_lights: bool = true
@export var lobby_light_color: Color = Color(1.0, 0.78, 0.58, 1.0)
@export_range(0.1, 4.0, 0.05) var lobby_light_energy: float = 1.55
@export_range(2.0, 10.0, 0.5) var lobby_light_range: float = 5.0

@export_group("Light Quality")
@export var enable_shadows: bool = false
@export_range(0.0, 1.0, 0.05) var light_specular: float = 0.35

@export_group("Generation")
@export var rebuild_lighting: bool = false:
	set(value):
		if value:
			call_deferred("_rebuild_lighting")

const GENERATED_ROOT_NAME: String = "_GeneratedApartmentLighting"

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

	if generate_main_room_lights:
		_build_main_room_lights(generated_root, scene_root)
	if generate_hallway_lights:
		_build_hallway_lights(generated_root, scene_root)
	if generate_lobby_lights:
		_build_lobby_lights(generated_root, scene_root)

func _build_main_room_lights(parent: Node3D, scene_root: Node) -> void:
	# Six broad pools of light, arranged to cover the 22 x 19 m communal room.
	var x_positions: Array[float] = [-6.5, 0.0, 6.5]
	var z_positions: Array[float] = [-4.8, 4.8]
	for row_index: int in range(z_positions.size()):
		for column_index: int in range(x_positions.size()):
			var light_name: String = "MainRoom_Ceiling_%d_%d" % [row_index + 1, column_index + 1]
			_add_omni_light(
				parent, light_name,
				Vector3(x_positions[column_index], 3.48, z_positions[row_index]),
				main_room_light_color, main_room_light_energy,
				main_room_light_range, scene_root
			)

	# A softer fill near the panoramic glazing keeps the window-side seating area from feeling flat.
	if window_side_fill_energy > 0.01:
		_add_omni_light(
			parent, "MainRoom_CityWindow_SoftFill",
			Vector3(7.6, 3.35, 0.0),
			main_room_light_color, window_side_fill_energy,
			6.5, scene_root
		)

func _build_hallway_lights(parent: Node3D, scene_root: Node) -> void:
	if hallway_light_count < 1:
		return
	for light_index: int in range(hallway_light_count):
		var progress: float = 0.5
		if hallway_light_count > 1:
			progress = float(light_index) / float(hallway_light_count - 1)
		var light_z: float = lerpf(hallway_light_start_z, hallway_light_end_z, progress)
		# Keep the last light before the void fade begins at Z = 4.
		_add_omni_light(
			parent, "Hallway_Ceiling_%02d" % (light_index + 1),
			Vector3(-12.75, 3.42, light_z),
			hallway_light_color, hallway_light_energy,
			hallway_light_range, scene_root
		)

func _build_lobby_lights(parent: Node3D, scene_root: Node) -> void:
	_add_omni_light(
		parent, "ElevatorLobby_Ceiling_Main",
		Vector3(-12.75, 3.42, -19.25),
		lobby_light_color, lobby_light_energy,
		lobby_light_range, scene_root
	)
	_add_omni_light(
		parent, "ElevatorLobby_Elevator_WelcomeFill",
		Vector3(-12.75, 2.9, -20.7),
		lobby_light_color, lobby_light_energy * 0.55,
		3.5, scene_root
	)

func _add_omni_light(
	parent: Node3D,
	node_name: String,
	light_position: Vector3,
	color: Color,
	energy: float,
	range_value: float,
	scene_root: Node
) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.name = node_name
	light.position = light_position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_value
	light.shadow_enabled = enable_shadows
	light.light_specular = light_specular
	parent.add_child(light)
	light.owner = scene_root
