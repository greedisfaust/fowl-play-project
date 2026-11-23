@tool
extends Node3D
class_name ApartmentFloorBuilder

## Warm-modern mixed flooring for the Apartment.
## Attach to Environment/FloorFinish at local origin.
## Decorative surfaces sit just above the existing user-authored Foundation floors.
## This builder never edits or replaces MainRoomFloor, HallwayFloor, or ElevatorLobbyFloor.

@export_group("Floor Sections")
@export var generate_main_room_stone: bool = true
@export var generate_hallway_walnut: bool = true
@export var generate_elevator_lobby_stone: bool = true
@export var generate_transition_details: bool = true

@export_group("Main Room Stone")
@export var main_stone_base_color: Color = Color(0.24, 0.235, 0.22, 1.0)
@export var main_stone_variation: float = 0.035
@export_range(0.6, 1.8, 0.05) var main_tile_length: float = 1.2
@export_range(0.3, 1.0, 0.05) var main_tile_width: float = 0.6
@export_range(0.004, 0.03, 0.002) var grout_gap: float = 0.012

@export_group("Hallway Walnut")
@export var walnut_base_color: Color = Color(0.16, 0.085, 0.043, 1.0)
@export_range(1.2, 3.6, 0.1) var plank_length: float = 2.4
@export_range(0.14, 0.32, 0.01) var plank_width: float = 0.22
@export_range(0.004, 0.025, 0.002) var plank_gap: float = 0.008

@export_group("Elevator Lobby Stone")
@export var lobby_stone_color: Color = Color(0.105, 0.115, 0.12, 1.0)
@export_range(0.5, 1.5, 0.05) var lobby_tile_length: float = 0.9
@export_range(0.3, 0.9, 0.05) var lobby_tile_width: float = 0.45

@export_group("Metal Details")
@export_range(0.8, 3.6, 0.05) var doorway_threshold_width: float = 2.8
@export var doorway_threshold_center_z: float = -7.8
@export var bronze_color: Color = Color(0.40, 0.245, 0.115, 1.0)
@export_range(0.025, 0.12, 0.005) var transition_strip_width: float = 0.07
@export var generate_lobby_perimeter_inlay: bool = true

@export_group("Generation")
@export var rebuild_floor: bool = false:
	set(value):
		if value:
			call_deferred("_rebuild_floor")

const GENERATED_ROOT_NAME: String = "_GeneratedApartmentFloorFinish"
const FLOOR_TOP_Y: float = 0.012
const SURFACE_THICKNESS: float = 0.018
const BACKING_TOP_Y: float = 0.004
const BACKING_THICKNESS: float = 0.008

var _stone_materials: Array[StandardMaterial3D] = []
var _wood_materials: Array[StandardMaterial3D] = []
var _lobby_materials: Array[StandardMaterial3D] = []
var _grout_material: StandardMaterial3D
var _wood_joint_material: StandardMaterial3D
var _bronze_material: StandardMaterial3D

func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild_floor()

func _rebuild_floor() -> void:
	if not Engine.is_editor_hint():
		return
	var scene_root: Node = get_tree().edited_scene_root
	if scene_root == null:
		return
	var previous: Node = get_node_or_null(GENERATED_ROOT_NAME)
	if previous != null:
		previous.free()

	_create_materials()
	var generated: Node3D = Node3D.new()
	generated.name = GENERATED_ROOT_NAME
	add_child(generated)
	generated.owner = scene_root

	if generate_main_room_stone:
		_build_main_room_stone(generated, scene_root)
	if generate_hallway_walnut:
		_build_hallway_walnut(generated, scene_root)
	if generate_elevator_lobby_stone:
		_build_lobby_stone(generated, scene_root)
	if generate_transition_details:
		_build_transitions(generated, scene_root)

func _create_materials() -> void:
	_stone_materials.clear()
	_wood_materials.clear()
	_lobby_materials.clear()
	for index: int in range(5):
		var offset: float = (float(index) - 2.0) * main_stone_variation * 0.5
		var stone_color: Color = Color(
			clampf(main_stone_base_color.r + offset, 0.0, 1.0),
			clampf(main_stone_base_color.g + offset, 0.0, 1.0),
			clampf(main_stone_base_color.b + offset, 0.0, 1.0),
			1.0
		)
		_stone_materials.append(_make_material(stone_color, 0.04, 0.72))
	for index: int in range(5):
		var factor: float = 1.0 + (float(index) - 2.0) * 0.045
		var wood_color: Color = Color(
			clampf(walnut_base_color.r * factor, 0.0, 1.0),
			clampf(walnut_base_color.g * factor, 0.0, 1.0),
			clampf(walnut_base_color.b * factor, 0.0, 1.0),
			1.0
		)
		_wood_materials.append(_make_material(wood_color, 0.0, 0.48))
	for index: int in range(4):
		var factor: float = 1.0 + float(index - 1) * 0.055
		var lobby_color: Color = Color(
			clampf(lobby_stone_color.r * factor, 0.0, 1.0),
			clampf(lobby_stone_color.g * factor, 0.0, 1.0),
			clampf(lobby_stone_color.b * factor, 0.0, 1.0),
			1.0
		)
		_lobby_materials.append(_make_material(lobby_color, 0.08, 0.38))
	_grout_material = _make_material(Color(0.075, 0.078, 0.078, 1.0), 0.02, 0.82)
	_wood_joint_material = _make_material(Color(0.045, 0.025, 0.014, 1.0), 0.0, 0.82)
	_bronze_material = _make_material(bronze_color, 0.78, 0.28)

func _build_main_room_stone(parent: Node3D, scene_root: Node) -> void:
	var section: Node3D = _make_group(parent, "MainRoom_Limestone_Tile_Floor", scene_root)
	_add_box(section, "Dark_Stone_Grout_Bed", Vector3(22.0, BACKING_THICKNESS, 19.0),
		Vector3(0.0, BACKING_TOP_Y - BACKING_THICKNESS * 0.5, 0.0), _grout_material, scene_root)

	var x_start: float = -11.0
	var z_start: float = -9.5
	var row_index: int = 0
	var z_cursor: float = z_start
	while z_cursor < 9.499:
		var tile_depth: float = minf(main_tile_width, 9.5 - z_cursor)
		var column_index: int = 0
		var row_stagger: float = main_tile_length * 0.5 if row_index % 2 == 1 else 0.0
		var x_cursor: float = x_start - row_stagger
		while x_cursor < 10.999:
			var tile_start: float = maxf(-11.0, x_cursor)
			var tile_end: float = minf(11.0, x_cursor + main_tile_length)
			var tile_length_value: float = tile_end - tile_start
			if tile_length_value > 0.05:
				var tile_size: Vector3 = Vector3(
					maxf(0.05, tile_length_value - grout_gap),
					SURFACE_THICKNESS,
					maxf(0.05, tile_depth - grout_gap)
				)
				var material_index: int = posmod(row_index * 3 + column_index * 2 + (row_index % 2), _stone_materials.size())
				var tile_name: String = "Limestone_Tile_R%02d_C%02d" % [row_index, column_index]
				_add_box(section, tile_name, tile_size,
					Vector3((tile_start + tile_end) * 0.5, FLOOR_TOP_Y - SURFACE_THICKNESS * 0.5,
						z_cursor + tile_depth * 0.5), _stone_materials[material_index], scene_root)
			x_cursor += main_tile_length
			column_index += 1
		z_cursor += main_tile_width
		row_index += 1

func _build_hallway_walnut(parent: Node3D, scene_root: Node) -> void:
	var section: Node3D = _make_group(parent, "Hallway_Walnut_Plank_Floor", scene_root)
	_add_box(section, "Dark_Wood_Joint_Bed", Vector3(3.5, BACKING_THICKNESS, 34.0),
		Vector3(-12.75, BACKING_TOP_Y - BACKING_THICKNESS * 0.5, 0.0), _wood_joint_material, scene_root)

	var plank_rows: int = int(ceil(3.5 / plank_width))
	var row_pitch: float = 3.5 / float(plank_rows)
	var x_start: float = -14.5
	for row_index: int in range(plank_rows):
		var plank_x: float = x_start + float(row_index) * row_pitch + row_pitch * 0.5
		var stagger: float = plank_length * 0.5 if row_index % 2 == 1 else 0.0
		var segment_index: int = 0
		var z_cursor: float = -17.0 - stagger
		while z_cursor < 17.0:
			var segment_start: float = maxf(-17.0, z_cursor)
			var segment_end: float = minf(17.0, z_cursor + plank_length)
			var segment_depth: float = segment_end - segment_start
			if segment_depth > 0.08:
				var material_index: int = posmod(row_index * 2 + segment_index * 3, _wood_materials.size())
				var plank_name: String = "Walnut_Plank_R%02d_S%02d" % [row_index, segment_index]
				_add_box(section, plank_name,
					Vector3(maxf(0.05, row_pitch - plank_gap), SURFACE_THICKNESS, segment_depth - plank_gap),
					Vector3(plank_x, FLOOR_TOP_Y - SURFACE_THICKNESS * 0.5,
						(segment_start + segment_end) * 0.5), _wood_materials[material_index], scene_root)
			z_cursor += plank_length
			segment_index += 1

func _build_lobby_stone(parent: Node3D, scene_root: Node) -> void:
	var section: Node3D = _make_group(parent, "ElevatorLobby_Dark_Stone_Floor", scene_root)
	_add_box(section, "Lobby_Dark_Grout_Bed", Vector3(4.5, BACKING_THICKNESS, 4.5),
		Vector3(-12.75, BACKING_TOP_Y - BACKING_THICKNESS * 0.5, -19.25), _grout_material, scene_root)

	var row_index: int = 0
	var z_cursor: float = -21.5
	while z_cursor < -16.999:
		var tile_depth: float = minf(lobby_tile_width, -17.0 - z_cursor)
		var column_index: int = 0
		var x_cursor: float = -15.0
		while x_cursor < -10.499:
			var tile_length_value: float = minf(lobby_tile_length, -10.5 - x_cursor)
			var material_index: int = posmod(row_index + column_index * 2, _lobby_materials.size())
			_add_box(section, "Lobby_Stone_Tile_R%02d_C%02d" % [row_index, column_index],
				Vector3(maxf(0.05, tile_length_value - grout_gap), SURFACE_THICKNESS,
					maxf(0.05, tile_depth - grout_gap)),
				Vector3(x_cursor + tile_length_value * 0.5, FLOOR_TOP_Y - SURFACE_THICKNESS * 0.5,
					z_cursor + tile_depth * 0.5), _lobby_materials[material_index], scene_root)
			x_cursor += lobby_tile_length
			column_index += 1
		z_cursor += lobby_tile_width
		row_index += 1

	if generate_lobby_perimeter_inlay:
		_add_lobby_bronze_inlay(section, scene_root)

func _add_lobby_bronze_inlay(parent: Node3D, scene_root: Node) -> void:
	var inset: float = 0.12
	var line_width: float = 0.025
	var y_position: float = FLOOR_TOP_Y + 0.001
	_add_box(parent, "Lobby_Bronze_Inlay_North", Vector3(4.5 - inset * 2.0, 0.012, line_width),
		Vector3(-12.75, y_position, -21.5 + inset), _bronze_material, scene_root)
	_add_box(parent, "Lobby_Bronze_Inlay_South", Vector3(4.5 - inset * 2.0, 0.012, line_width),
		Vector3(-12.75, y_position, -17.0 - inset), _bronze_material, scene_root)
	_add_box(parent, "Lobby_Bronze_Inlay_West", Vector3(line_width, 0.012, 4.5 - inset * 2.0),
		Vector3(-15.0 + inset, y_position, -19.25), _bronze_material, scene_root)
	_add_box(parent, "Lobby_Bronze_Inlay_East", Vector3(line_width, 0.012, 4.5 - inset * 2.0),
		Vector3(-10.5 - inset, y_position, -19.25), _bronze_material, scene_root)

func _build_transitions(parent: Node3D, scene_root: Node) -> void:
	var details: Node3D = _make_group(parent, "Bronze_Floor_Transitions", scene_root)
	var strip_y: float = FLOOR_TOP_Y + 0.001
	# Threshold centered in the 1.8 m doorway through the hallway/main-room divider.
	_add_box(details, "MainRoom_Doorway_Bronze_Threshold",
		Vector3(transition_strip_width, 0.012, 1.8),
		Vector3(-11.0, strip_y, -7.8), _bronze_material, scene_root)
	# Open connection between the 3.5 m hallway and the 4.5 m elevator lobby.
	_add_box(details, "ElevatorLobby_Bronze_Threshold",
		Vector3(3.5, 0.012, transition_strip_width),
		Vector3(-12.75, strip_y, -17.0), _bronze_material, scene_root)

func _make_group(parent: Node, node_name: String, scene_root: Node) -> Node3D:
	var group: Node3D = Node3D.new()
	group.name = node_name
	parent.add_child(group)
	group.owner = scene_root
	return group

func _add_box(parent: Node, node_name: String, size: Vector3, position: Vector3, material: Material, scene_root: Node) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	parent.add_child(instance)
	instance.owner = scene_root
	return instance

func _make_material(color: Color, metallic_value: float, roughness_value: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic_value
	material.roughness = roughness_value
	return material
