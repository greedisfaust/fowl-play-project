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

@export_group("Lower Wainscoting")
@export var generate_wainscoting: bool = true
@export_range(0.8, 1.8, 0.05) var wainscoting_height: float = 1.3
@export_range(1.2, 3.2, 0.1) var panel_spacing: float = 2.2
@export_range(0.04, 0.14, 0.01) var molding_width: float = 0.075
@export_range(0.02, 0.10, 0.01) var molding_depth: float = 0.055
@export_range(0.02, 0.08, 0.01) var panel_face_depth: float = 0.03
@export var wainscoting_color: Color = Color(0.12, 0.075, 0.045, 1.0)
@export var panel_color: Color = Color(0.16, 0.105, 0.065, 1.0)
@export var molding_color: Color = Color(0.24, 0.16, 0.09, 1.0)

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
	if generate_wainscoting and bottom <= 0.01 and top >= wall_height - 0.01:
		_build_wainscoting(parent, node_name, box_size, box_center, along_x, scene_root)
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

func _build_wainscoting(
	parent: Node3D,
	prefix: String,
	wall_size: Vector3,
	wall_center: Vector3,
	along_x: bool,
	scene_root: Node
) -> void:
	var panel_top: float = minf(wainscoting_height, wall_size.y - 0.25)
	var base_height: float = 0.18
	var panel_bottom: float = 0.31
	var top_rail_height: float = 0.11
	var panel_height: float = panel_top - panel_bottom - top_rail_height - 0.10
	var wall_length: float = wall_size.x if along_x else wall_size.z
	if wall_length <= 0.4 or panel_height <= 0.3:
		return

	var backing_material: StandardMaterial3D = _make_material(wainscoting_color, 0.05, 0.48)
	var panel_material: StandardMaterial3D = _make_material(panel_color, 0.0, 0.58)
	var molding_material: StandardMaterial3D = _make_material(molding_color, 0.18, 0.34)
	var panel_count: int = maxi(1, int(floor(wall_length / maxf(1.2, panel_spacing))))
	var bay_width: float = wall_length / float(panel_count)
	var frame_width: float = molding_width
	var face_width: float = bay_width - frame_width * 2.0 - 0.20
	var face_height: float = panel_height - frame_width * 2.0
	if face_width <= 0.25 or face_height <= 0.25:
		return

	for face_sign: int in [-1, 1]:
		var face_depth: float = wall_size.z if along_x else wall_size.x
		var face_z: float = wall_center.z + float(face_sign) * (face_depth * 0.5 + 0.018) if along_x else wall_center.z
		var face_x: float = wall_center.x if along_x else wall_center.x + float(face_sign) * (face_depth * 0.5 + 0.018)
		var backing_size: Vector3 = Vector3(wall_length, panel_top - base_height, 0.035) if along_x else Vector3(0.035, panel_top - base_height, wall_length)
		var backing_pos: Vector3 = Vector3(face_x, floor_level + base_height + (panel_top - base_height) * 0.5, face_z)
		_make_wainscot_box(parent, prefix + "_Wainscot_Backboard_" + str(face_sign), backing_size, backing_pos, backing_material, scene_root)

		var trim_depth_offset: float = float(face_sign) * (face_depth * 0.5 + 0.055)
		var base_pos: Vector3 = Vector3(wall_center.x, floor_level + 0.09, wall_center.z)
		var rail_pos: Vector3 = Vector3(wall_center.x, floor_level + panel_top - top_rail_height * 0.5, wall_center.z)
		if along_x:
			base_pos.z += trim_depth_offset
			rail_pos.z += trim_depth_offset
		else:
			base_pos.x += trim_depth_offset
			rail_pos.x += trim_depth_offset
		var horizontal_trim_size: Vector3 = Vector3(wall_length, 0.18, 0.075) if along_x else Vector3(0.075, 0.18, wall_length)
		var rail_size: Vector3 = Vector3(wall_length, top_rail_height, 0.11) if along_x else Vector3(0.11, top_rail_height, wall_length)
		_make_wainscot_box(parent, prefix + "_Wainscot_Baseboard_" + str(face_sign), horizontal_trim_size, base_pos, molding_material, scene_root)
		_make_wainscot_box(parent, prefix + "_Wainscot_ChairRail_" + str(face_sign), rail_size, rail_pos, molding_material, scene_root)

		for panel_index: int in range(panel_count):
			var offset_along: float = -wall_length * 0.5 + (float(panel_index) + 0.5) * bay_width
			var panel_pos: Vector3 = wall_center
			panel_pos.y = floor_level + panel_bottom + panel_height * 0.5
			if along_x:
				panel_pos.x += offset_along
				panel_pos.z += float(face_sign) * (face_depth * 0.5 + 0.045)
			else:
				panel_pos.z += offset_along
				panel_pos.x += float(face_sign) * (face_depth * 0.5 + 0.045)
			var face_size: Vector3 = Vector3(face_width, face_height, panel_face_depth) if along_x else Vector3(panel_face_depth, face_height, face_width)
			_make_wainscot_box(parent, prefix + "_Panel_" + str(panel_index) + "_Face_" + str(face_sign), face_size, panel_pos, panel_material, scene_root)

			var frame_pos: Vector3 = panel_pos
			if along_x:
				frame_pos.z += float(face_sign) * 0.03
			else:
				frame_pos.x += float(face_sign) * 0.03
			for side_index: int in range(2):
				var side_offset: float = -(face_width * 0.5 + frame_width * 0.5) if side_index == 0 else (face_width * 0.5 + frame_width * 0.5)
				var stile_pos: Vector3 = frame_pos
				if along_x:
					stile_pos.x += side_offset
				else:
					stile_pos.z += side_offset
				var stile_size: Vector3 = Vector3(frame_width, panel_height, molding_depth) if along_x else Vector3(molding_depth, panel_height, frame_width)
				_make_wainscot_box(parent, prefix + "_Panel_" + str(panel_index) + "_Stile_" + str(side_index) + "_" + str(face_sign), stile_size, stile_pos, molding_material, scene_root)
			for rail_index: int in range(2):
				var rail_y_offset: float = -panel_height * 0.5 + frame_width * 0.5 if rail_index == 0 else panel_height * 0.5 - frame_width * 0.5
				var panel_rail_size: Vector3 = Vector3(face_width + frame_width * 2.0, frame_width, molding_depth) if along_x else Vector3(molding_depth, frame_width, face_width + frame_width * 2.0)
				_make_wainscot_box(parent, prefix + "_Panel_" + str(panel_index) + "_Rail_" + str(rail_index) + "_" + str(face_sign), panel_rail_size, frame_pos + Vector3.UP * rail_y_offset, molding_material, scene_root)

func _make_wainscot_box(
	parent: Node3D,
	node_name: String,
	box_size: Vector3,
	box_position: Vector3,
	material: Material,
	scene_root: Node
) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = box_size
	instance.mesh = mesh
	instance.material_override = material
	instance.position = box_position
	parent.add_child(instance)
	instance.owner = scene_root

func _make_material(color: Color, metallic_value: float, roughness_value: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic_value
	material.roughness = roughness_value
	return material
