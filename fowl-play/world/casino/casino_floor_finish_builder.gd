@tool
extends Node3D
class_name CasinoFloorFinishBuilder

## Adds the Apartment's warm limestone and walnut finishes to the Casino.
## Attach to a NEW sibling of Architecture/FloorDetails (for example Architecture/FloorFinish).
## This builder never edits FloorDetails, the existing casino floor builder, or foundation collision.
## All geometry is decorative and has no collision.

@export_group("Floor Sections")
@export var generate_gaming_stone: bool = true
@export var generate_bar_walnut: bool = true

@export_group("Gaming Area Limestone")
@export var gaming_floor_top_height: float = 0.15
@export var stone_base_color: Color = Color(0.24, 0.235, 0.22, 1.0)
@export var stone_variation: float = 0.035
@export_range(0.6, 1.8, 0.05) var tile_length: float = 1.2
@export_range(0.3, 1.0, 0.05) var tile_width: float = 0.6
@export_range(0.004, 0.03, 0.002) var grout_gap: float = 0.012

@export_group("Bar Walnut Planks")
@export var bar_floor_top_height: float = 0.0
@export var walnut_base_color: Color = Color(0.16, 0.085, 0.043, 1.0)
@export_range(1.2, 3.6, 0.1) var plank_length: float = 2.4
@export_range(0.14, 0.32, 0.01) var plank_width: float = 0.22
@export_range(0.004, 0.025, 0.002) var plank_gap: float = 0.008

@export_group("Casino Floor Boundaries")
@export var bar_min_x: float = 1.5
@export var floor_min_z: float = -28.665
@export var floor_max_z: float = -1.665
@export var preserve_medallion_clearance: bool = true
@export var medallion_center: Vector2 = Vector2(-9.0, -15.5)
@export_range(1.5, 3.5, 0.1) var medallion_clearance_radius: float = 1.9

@export_group("Generation")
@export var rebuild_floor: bool = false:
	set(value):
		if value:
			call_deferred("_rebuild_floor")

const GENERATED_ROOT_NAME: String = "_GeneratedCasinoFloorFinish"
const FLOOR_FOOTPRINT: Array[Vector2] = [
	Vector2(-24.0, -18.665),
	Vector2(-14.0, -28.665),
	Vector2(11.0, -28.665),
	Vector2(11.0, -1.665),
	Vector2(-24.0, -1.665)
]
const STONE_THICKNESS: float = 0.014
const WOOD_THICKNESS: float = 0.014

var _stone_materials: Array[StandardMaterial3D] = []
var _wood_materials: Array[StandardMaterial3D] = []
var _grout_material: StandardMaterial3D
var _wood_joint_material: StandardMaterial3D

func _ready() -> void:
	# Generated children are serialized into the scene. Preserve editor-authored
	# tweaks on reopen; the inspector rebuild toggle remains the explicit reset.
	if Engine.is_editor_hint() and get_node_or_null(GENERATED_ROOT_NAME) == null:
		_rebuild_floor()

func _rebuild_floor() -> void:
	if not Engine.is_editor_hint():
		return
	if tile_length <= 0.1 or tile_width <= 0.1 or plank_length <= 0.1 or plank_width <= 0.05:
		push_warning("CasinoFloorFinishBuilder has invalid tile or plank dimensions.")
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

	if generate_gaming_stone:
		_build_gaming_stone(generated, scene_root)
	if generate_bar_walnut:
		_build_bar_walnut(generated, scene_root)

func _create_materials() -> void:
	_stone_materials.clear()
	_wood_materials.clear()
	for index: int in range(5):
		var offset: float = (float(index) - 2.0) * stone_variation * 0.5
		var color: Color = Color(
			clampf(stone_base_color.r + offset, 0.0, 1.0),
			clampf(stone_base_color.g + offset, 0.0, 1.0),
			clampf(stone_base_color.b + offset, 0.0, 1.0),
			1.0
		)
		_stone_materials.append(_make_material(color, 0.04, 0.72))
	for index: int in range(5):
		var factor: float = 1.0 + (float(index) - 2.0) * 0.045
		var color: Color = Color(
			clampf(walnut_base_color.r * factor, 0.0, 1.0),
			clampf(walnut_base_color.g * factor, 0.0, 1.0),
			clampf(walnut_base_color.b * factor, 0.0, 1.0),
			1.0
		)
		_wood_materials.append(_make_material(color, 0.0, 0.48))
	_grout_material = _make_material(Color(0.075, 0.078, 0.078, 1.0), 0.02, 0.82)
	_wood_joint_material = _make_material(Color(0.045, 0.025, 0.014, 1.0), 0.0, 0.82)

func _build_gaming_stone(parent: Node3D, scene_root: Node) -> void:
	var section: Node3D = _make_group(parent, "Gaming_Area_Limestone_Tiles", scene_root)
	var row_index: int = 0
	var z_cursor: float = floor_min_z
	while z_cursor < floor_max_z:
		var row_depth: float = minf(tile_width, floor_max_z - z_cursor)
		var stagger: float = tile_length * 0.5 if row_index % 2 == 1 else 0.0
		var x_cursor: float = FLOOR_FOOTPRINT[0].x - stagger
		var column_index: int = 0
		while x_cursor < bar_min_x:
			var tile_start_x: float = maxf(FLOOR_FOOTPRINT[0].x, x_cursor)
			var tile_end_x: float = minf(bar_min_x, x_cursor + tile_length)
			var tile_center: Vector2 = Vector2((tile_start_x + tile_end_x) * 0.5, z_cursor + row_depth * 0.5)
			var tile_size_x: float = tile_end_x - tile_start_x
			if tile_size_x > 0.05 and row_depth > 0.05:
				var corners: Array[Vector2] = [
					Vector2(tile_start_x, z_cursor),
					Vector2(tile_end_x, z_cursor),
					Vector2(tile_end_x, z_cursor + row_depth),
					Vector2(tile_start_x, z_cursor + row_depth)
				]
				var fits: bool = true
				for corner: Vector2 in corners:
					if not Geometry2D.is_point_in_polygon(corner, PackedVector2Array(FLOOR_FOOTPRINT)):
						fits = false
						break
				if fits and _is_outside_medallion(tile_center):
					var material_index: int = posmod(row_index * 3 + column_index * 2 + row_index % 2, _stone_materials.size())
					_add_box(
						section,
						"Limestone_Tile_R%02d_C%02d" % [row_index, column_index],
						Vector3(maxf(0.05, tile_size_x - grout_gap), STONE_THICKNESS, maxf(0.05, row_depth - grout_gap)),
						Vector3(tile_center.x, gaming_floor_top_height + STONE_THICKNESS * 0.5 + 0.004, tile_center.y),
						_stone_materials[material_index],
						scene_root
					)
			x_cursor += tile_length
			column_index += 1
		z_cursor += tile_width
		row_index += 1

func _build_bar_walnut(parent: Node3D, scene_root: Node) -> void:
	var section: Node3D = _make_group(parent, "Bar_Area_Walnut_Planks", scene_root)
	var bar_width: float = 11.0 - bar_min_x
	_add_box(
		section,
		"Bar_Dark_Wood_Joint_Bed",
		Vector3(bar_width, 0.008, floor_max_z - floor_min_z),
		Vector3((bar_min_x + 11.0) * 0.5, bar_floor_top_height + 0.002, (floor_min_z + floor_max_z) * 0.5),
		_wood_joint_material,
		scene_root
	)

	var row_index: int = 0
	var z_cursor: float = floor_min_z
	while z_cursor < floor_max_z:
		var row_depth: float = minf(plank_width, floor_max_z - z_cursor)
		var stagger: float = plank_length * 0.5 if row_index % 2 == 1 else 0.0
		var x_cursor: float = bar_min_x - stagger
		var segment_index: int = 0
		while x_cursor < 11.0:
			var segment_start: float = maxf(bar_min_x, x_cursor)
			var segment_end: float = minf(11.0, x_cursor + plank_length)
			var segment_width: float = segment_end - segment_start
			if segment_width > 0.08 and row_depth > 0.05:
				var center: Vector2 = Vector2((segment_start + segment_end) * 0.5, z_cursor + row_depth * 0.5)
				var corners: Array[Vector2] = [
					Vector2(segment_start, z_cursor),
					Vector2(segment_end, z_cursor),
					Vector2(segment_end, z_cursor + row_depth),
					Vector2(segment_start, z_cursor + row_depth)
				]
				var fits: bool = true
				for corner: Vector2 in corners:
					if not Geometry2D.is_point_in_polygon(corner, PackedVector2Array(FLOOR_FOOTPRINT)):
						fits = false
						break
				if fits:
					var material_index: int = posmod(row_index * 2 + segment_index * 3, _wood_materials.size())
					_add_box(
						section,
						"Walnut_Plank_R%02d_S%02d" % [row_index, segment_index],
						Vector3(maxf(0.05, segment_width - plank_gap), WOOD_THICKNESS, maxf(0.05, row_depth - plank_gap)),
						Vector3(center.x, bar_floor_top_height + WOOD_THICKNESS * 0.5 + 0.004, center.y),
						_wood_materials[material_index],
						scene_root
					)
			x_cursor += plank_length
			segment_index += 1
		z_cursor += plank_width
		row_index += 1

func _is_outside_medallion(point: Vector2) -> bool:
	if not preserve_medallion_clearance:
		return true
	return point.distance_to(medallion_center) >= medallion_clearance_radius

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
