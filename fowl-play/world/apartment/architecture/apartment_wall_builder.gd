@tool
extends Node3D
class_name ApartmentWallBuilder

## Procedural structural wall builder for the Apartment.
## Attach one instance to Architecture/PerimeterWalls and another to
## Architecture/InteriorWalls. Set wall_set accordingly.
## All coordinates are relative to the Apartment root.

enum WallSet {
	PERIMETER,
	INTERIOR
}

@export_group("Wall Set")
@export var wall_set: WallSet = WallSet.PERIMETER

@export_group("Dimensions")
@export_range(2.0, 6.0, 0.05) var wall_height: float = 4.0
@export_range(0.1, 0.6, 0.01) var wall_thickness: float = 0.30
@export_range(0.1, 0.4, 0.01) var interior_wall_thickness: float = 0.20
@export var floor_level: float = 0.0

@export_group("Main Room Window")
@export var generate_main_room_window: bool = true
@export_range(2.0, 18.0, 0.25) var main_window_width: float = 12.0
@export_range(0.5, 2.0, 0.05) var main_window_sill_height: float = 0.85
@export_range(2.0, 3.8, 0.05) var main_window_top: float = 3.15

@export_group("Hallway Window")
@export var generate_hallway_window: bool = true
@export_range(1.0, 8.0, 0.25) var hallway_window_width: float = 4.5
@export_range(0.5, 2.0, 0.05) var hallway_window_sill_height: float = 0.9
@export_range(2.0, 3.8, 0.05) var hallway_window_top: float = 2.7

@export_group("Main Room Doorway")
@export var generate_main_room_doorway: bool = true
@export_range(0.8, 3.0, 0.05) var doorway_width: float = 1.8
@export_range(1.8, 3.0, 0.05) var doorway_height: float = 2.3
@export_range(-9.0, 9.0, 0.05) var doorway_center_z: float = -7.8

@export_group("Appearance")
@export var wall_color: Color = Color(0.16, 0.17, 0.18, 1.0)
@export_range(0.0, 1.0, 0.01) var wall_roughness: float = 0.82

@export_group("Collision")
@export var generate_collision: bool = true

@export_group("Generation")
@export var rebuild_geometry: bool = false:
	set(value):
		if value:
			call_deferred("_rebuild_geometry")

const GENERATED_ROOT_NAME: String = "_GeneratedApartmentWalls"

func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild_geometry()

func _rebuild_geometry() -> void:
	if not Engine.is_editor_hint():
		return
	if wall_height <= 0.1:
		push_warning("ApartmentWallBuilder: wall height must be greater than zero.")
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
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = wall_color
	material.roughness = wall_roughness
	var thickness: float = wall_thickness if wall_set == WallSet.PERIMETER else interior_wall_thickness
	if wall_set == WallSet.PERIMETER:
		_build_perimeter(generated_root, material, thickness, scene_root)
	else:
		_build_interior(generated_root, material, thickness, scene_root)

func _build_perimeter(parent: Node3D, material: Material, thickness: float, scene_root: Node) -> void:
	# Main room: 22 x 19 m, centered at the origin.
	# East wall has the panoramic city window.
	_build_segment(parent, "MainRoom_East", Vector2(11.0, -9.5), Vector2(11.0, 9.5),
		material, thickness, scene_root,
		generate_main_room_window, 0.0, main_window_width, main_window_sill_height, main_window_top)
	_build_segment(parent, "MainRoom_North", Vector2(-11.0, -9.5), Vector2(11.0, -9.5),
		material, thickness, scene_root)
	_build_segment(parent, "MainRoom_South", Vector2(-11.0, 9.5), Vector2(11.0, 9.5),
		material, thickness, scene_root)

	# Hallway west wall, with a separate street-facing window.
	_build_segment(parent, "Hallway_West", Vector2(-14.5, -17.0), Vector2(-14.5, 17.0),
		material, thickness, scene_root,
		generate_hallway_window, 0.0, hallway_window_width, hallway_window_sill_height, hallway_window_top)
	_build_segment(parent, "Hallway_South", Vector2(-14.5, 17.0), Vector2(-11.0, 17.0),
		material, thickness, scene_root)

	# Elevator lobby enclosure. Its south side remains open to the hallway.
	_build_segment(parent, "ElevatorLobby_North", Vector2(-15.0, -21.5), Vector2(-10.5, -21.5),
		material, thickness, scene_root)
	_build_segment(parent, "ElevatorLobby_West", Vector2(-15.0, -21.5), Vector2(-15.0, -17.0),
		material, thickness, scene_root)
	_build_segment(parent, "ElevatorLobby_East", Vector2(-10.5, -21.5), Vector2(-10.5, -17.0),
		material, thickness, scene_root)
	# Short returns account for the lobby being 0.5 m wider than the hallway.
	_build_segment(parent, "ElevatorLobby_West_Return", Vector2(-15.0, -17.0), Vector2(-14.5, -17.0),
		material, thickness, scene_root)
	_build_segment(parent, "ElevatorLobby_East_Return", Vector2(-11.0, -17.0), Vector2(-10.5, -17.0),
		material, thickness, scene_root)

func _build_interior(parent: Node3D, material: Material, thickness: float, scene_root: Node) -> void:
	# Shared wall between hallway and main room. Door is near the elevator end.
	_build_segment(parent, "Hallway_MainRoom_Divider",
		Vector2(-11.0, -9.5), Vector2(-11.0, 9.5),
		material, thickness, scene_root,
		generate_main_room_doorway, doorway_center_z, doorway_width, 0.0, doorway_height)

func _build_segment(
	parent: Node3D,
	node_prefix: String,
	start: Vector2,
	end: Vector2,
	material: Material,
	thickness: float,
	scene_root: Node,
	has_opening: bool = false,
	opening_center: float = 0.0,
	opening_width: float = 0.0,
	opening_bottom: float = 0.0,
	opening_top: float = 0.0
) -> void:
	var delta: Vector2 = end - start
	var length: float = delta.length()
	if length <= 0.05:
		return
	var along_x: bool = absf(delta.x) >= absf(delta.y)
	var opening_start: float = clampf(opening_center - opening_width * 0.5, 0.0, length)
	var opening_end: float = clampf(opening_center + opening_width * 0.5, 0.0, length)
	var valid_opening: bool = has_opening and opening_width > 0.05 and opening_top > opening_bottom and opening_end > opening_start
	if not valid_opening:
		_add_wall_box(parent, node_prefix, start, end, 0.0, wall_height, thickness, along_x, material, scene_root)
		return

	if opening_start > 0.01:
		_add_wall_box(parent, node_prefix + "_BeforeOpening", start, end,
			0.0, wall_height, thickness, along_x, material, scene_root, 0.0, opening_start)
	if length - opening_end > 0.01:
		_add_wall_box(parent, node_prefix + "_AfterOpening", start, end,
			0.0, wall_height, thickness, along_x, material, scene_root, opening_end, length)

	var safe_bottom: float = clampf(opening_bottom, 0.0, wall_height)
	var safe_top: float = clampf(opening_top, safe_bottom, wall_height)
	if safe_bottom > 0.01:
		_add_wall_box(parent, node_prefix + "_OpeningSill", start, end,
			0.0, safe_bottom, thickness, along_x, material, scene_root, opening_start, opening_end)
	if wall_height - safe_top > 0.01:
		_add_wall_box(parent, node_prefix + "_OpeningHeader", start, end,
			safe_top, wall_height, thickness, along_x, material, scene_root, opening_start, opening_end)

func _add_wall_box(
	parent: Node3D,
	node_name: String,
	start: Vector2,
	end: Vector2,
	bottom: float,
	top: float,
	thickness: float,
	along_x: bool,
	material: Material,
	scene_root: Node,
	distance_start: float = 0.0,
	distance_end: float = -1.0
) -> void:
	var full_delta: Vector2 = end - start
	var full_length: float = full_delta.length()
	var actual_end: float = full_length if distance_end < 0.0 else distance_end
	var segment_length: float = actual_end - distance_start
	var direction: Vector2 = full_delta.normalized()
	var center_2d: Vector2 = start + direction * ((distance_start + actual_end) * 0.5)
	var height: float = top - bottom
	if segment_length <= 0.01 or height <= 0.01:
		return
	var box_size: Vector3 = Vector3(segment_length, height, thickness) if along_x else Vector3(thickness, height, segment_length)
	var box_center: Vector3 = Vector3(center_2d.x, floor_level + bottom + height * 0.5, center_2d.y)
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = node_name
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = box_size
	mesh_instance.mesh = box_mesh
	mesh_instance.material_override = material
	mesh_instance.position = box_center
	parent.add_child(mesh_instance)
	mesh_instance.owner = scene_root
	if generate_collision:
		var body: StaticBody3D = StaticBody3D.new()
		body.name = node_name + "_Collision"
		parent.add_child(body)
		body.owner = scene_root
		var collision: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = box_size
		collision.shape = shape
		collision.position = box_center
		body.add_child(collision)
		collision.owner = scene_root
