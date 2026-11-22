@tool
extends Node3D
class_name CasinoPerimeterBuilder

## Generates the three solid outer walls of the Casino.
## The panoramic façade edges are intentionally omitted:
## (-24, -18.665) -> (-14, -28.665) -> (11, -28.665).
## Coordinates are relative to the Casino root. Attach this to Architecture/Perimeter.

@export_group("Wall Shape")
@export_range(2.0, 8.0, 0.05) var wall_height: float = 4.2
@export_range(0.1, 1.0, 0.01) var wall_thickness: float = 0.38
@export var floor_level: float = 0.0
@export_range(0.0, 0.5, 0.01) var end_overlap: float = 0.08

@export_group("Architectural Details")
@export var generate_panel_bands: bool = true
@export_range(0.02, 0.2, 0.005) var bronze_trim_width: float = 0.055
@export_range(0.05, 0.5, 0.01) var panel_spacing: float = 2.8
@export_range(0.1, 1.0, 0.01) var panel_inset_height: float = 2.5
@export_range(0.0, 0.5, 0.01) var base_band_height: float = 0.28
@export_range(0.0, 0.5, 0.01) var crown_band_height: float = 0.22

@export_group("Materials")
@export var wall_color: Color = Color(0.055, 0.062, 0.072, 1.0)
@export var bronze_color: Color = Color(0.36, 0.22, 0.105, 1.0)
@export var inset_color: Color = Color(0.085, 0.092, 0.10, 1.0)

@export_group("Collision")
@export var generate_collision: bool = true

@export_group("Generation")
@export var rebuild_geometry: bool = false:
	set(value):
		if value:
			call_deferred("_rebuild_geometry")

const GENERATED_ROOT_NAME: String = "_GeneratedPerimeter"

# The casino floor footprint after applying Environment's Z = -9.665 offset.
# The two omitted edges are reserved for the panoramic glass façade.
const SOLID_WALL_PATH: Array[Vector2] = [
	Vector2(11.0, -28.665),
	Vector2(11.0, -1.665),
	Vector2(-24.0, -1.665),
	Vector2(-24.0, -18.665)
]

func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild_geometry()

func _rebuild_geometry() -> void:
	if not Engine.is_editor_hint():
		return
	if SOLID_WALL_PATH.size() < 2 or wall_height <= 0.1 or wall_thickness <= 0.05:
		push_warning("CasinoPerimeterBuilder has invalid wall dimensions.")
		return

	var old_root: Node = get_node_or_null(GENERATED_ROOT_NAME)
	if old_root != null:
		old_root.free()

	var scene_root: Node = get_tree().edited_scene_root
	var generated_root: Node3D = Node3D.new()
	generated_root.name = GENERATED_ROOT_NAME
	add_child(generated_root)
	generated_root.owner = scene_root

	var wall_material: StandardMaterial3D = _make_material(wall_color, 0.18, 0.42)
	var bronze_material: StandardMaterial3D = _make_material(bronze_color, 0.78, 0.24)
	var inset_material: StandardMaterial3D = _make_material(inset_color, 0.12, 0.34)

	for index: int in range(SOLID_WALL_PATH.size() - 1):
		_build_wall_segment(
			generated_root,
			SOLID_WALL_PATH[index],
			SOLID_WALL_PATH[index + 1],
			index,
			wall_material,
			bronze_material,
			inset_material,
			scene_root
		)

func _build_wall_segment(
	parent: Node3D,
	start_2d: Vector2,
	end_2d: Vector2,
	segment_index: int,
	wall_material: Material,
	bronze_material: Material,
	inset_material: Material,
	scene_root: Node
) -> void:
	var start: Vector3 = Vector3(start_2d.x, 0.0, start_2d.y)
	var end: Vector3 = Vector3(end_2d.x, 0.0, end_2d.y)
	var edge: Vector3 = end - start
	var edge_length: float = edge.length()
	if edge_length <= 0.1:
		return

	var tangent: Vector3 = edge / edge_length
	var normal: Vector3 = tangent.cross(Vector3.UP).normalized()
	var segment_basis: Basis = Basis(tangent, Vector3.UP, normal)
	var midpoint: Vector3 = (start + end) * 0.5
	var prefix: String = "Wall_%02d_" % segment_index
	var wall_center: Vector3 = midpoint + Vector3.UP * (floor_level + wall_height * 0.5)

	_add_box(parent, prefix + "Main", Vector3(edge_length + end_overlap, wall_height, wall_thickness), Transform3D(segment_basis, wall_center), wall_material, scene_root, true)

	# Bronze base and crown lines give the dark wall a restrained Art Deco rhythm.
	if base_band_height > 0.0:
		_add_box(parent, prefix + "BaseBand", Vector3(edge_length + end_overlap, base_band_height, wall_thickness + 0.025), Transform3D(segment_basis, midpoint + Vector3.UP * (floor_level + base_band_height * 0.5)), bronze_material, scene_root, false)
	if crown_band_height > 0.0:
		_add_box(parent, prefix + "CrownBand", Vector3(edge_length + end_overlap, crown_band_height, wall_thickness + 0.025), Transform3D(segment_basis, midpoint + Vector3.UP * (floor_level + wall_height - crown_band_height * 0.5)), bronze_material, scene_root, false)

	if not generate_panel_bands:
		return

	var usable_height: float = maxf(0.5, minf(panel_inset_height, wall_height - base_band_height - crown_band_height - 0.25))
	var panel_bottom: float = floor_level + base_band_height + 0.18
	var panel_top: float = panel_bottom + usable_height
	var panel_count: int = maxi(1, int(floor(edge_length / maxf(0.8, panel_spacing))))
	var actual_spacing: float = edge_length / float(panel_count)

	for panel_index: int in range(panel_count):
		var panel_center_distance: float = (float(panel_index) + 0.5) * actual_spacing
		var panel_center: Vector3 = start + tangent * panel_center_distance
		var panel_width: float = maxf(0.25, actual_spacing - 0.42)
		# A shallow inset face and two slim bronze vertical reveals.
		_add_box(parent, prefix + "Inset_%02d" % panel_index, Vector3(panel_width, usable_height, 0.035), Transform3D(segment_basis, panel_center + Vector3.UP * (panel_bottom + usable_height * 0.5) + normal * (wall_thickness * 0.5 + 0.012)), inset_material, scene_root, false)
		var reveal_x: float = panel_width * 0.5
		for side_index: int in range(2):
			var side_offset: float = -reveal_x if side_index == 0 else reveal_x
			_add_box(parent, prefix + "PanelTrim_%02d_%d" % [panel_index, side_index], Vector3(bronze_trim_width, usable_height + 0.08, 0.045), Transform3D(segment_basis, panel_center + tangent * side_offset + Vector3.UP * (panel_bottom + usable_height * 0.5) + normal * (wall_thickness * 0.5 + 0.035)), bronze_material, scene_root, false)

func _add_box(
	parent: Node3D,
	node_name: String,
	box_size: Vector3,
	box_transform: Transform3D,
	material: Material,
	scene_root: Node,
	with_collision: bool
) -> void:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = node_name
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = box_size
	mesh_instance.mesh = box_mesh
	mesh_instance.material_override = material
	mesh_instance.transform = box_transform
	parent.add_child(mesh_instance)
	mesh_instance.owner = scene_root

	if with_collision and generate_collision:
		var body: StaticBody3D = StaticBody3D.new()
		body.name = node_name + "_Collision"
		parent.add_child(body)
		body.owner = scene_root
		var collision: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = box_size
		collision.shape = shape
		collision.transform = box_transform
		body.add_child(collision)
		collision.owner = scene_root

func _make_material(color: Color, metallic_value: float, roughness_value: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic_value
	material.roughness = roughness_value
	return material
