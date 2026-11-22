@tool
extends Node3D
class_name CasinoPerimeterBuilder

## Generates clean solid perimeter walls with a simple interior skirting board.
## The panoramic façade edges are intentionally omitted.
## Coordinates are relative to the Casino root. Attach to Architecture/Perimeter.

@export_group("Wall")
@export_range(2.0, 8.0, 0.05) var wall_height: float = 4.2
@export_range(0.1, 1.0, 0.01) var wall_thickness: float = 0.38
@export var floor_level: float = 0.0
@export_range(0.0, 0.5, 0.01) var end_overlap: float = 0.08
@export var wall_color: Color = Color(0.055, 0.062, 0.072, 1.0)

@export_group("Baseboard / Skirting")
@export var generate_baseboard: bool = true
@export_range(0.05, 0.35, 0.01) var baseboard_height: float = 0.16
@export_range(0.02, 0.18, 0.01) var baseboard_depth: float = 0.07
@export var baseboard_color: Color = Color(0.16, 0.13, 0.105, 1.0)

@export_group("Collision")
@export var generate_collision: bool = true

@export_group("Generation")
@export var rebuild_geometry: bool = false:
	set(value):
		if value:
			call_deferred("_rebuild_geometry")

const GENERATED_ROOT_NAME: String = "_GeneratedPerimeter"

# Three solid edges of the footprint. The two panoramic-window edges stay open.
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
	if wall_height <= 0.1 or wall_thickness <= 0.05:
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

	var wall_material: StandardMaterial3D = _make_material(wall_color, 0.08, 0.38)
	var baseboard_material: StandardMaterial3D = _make_material(baseboard_color, 0.42, 0.32)

	for index: int in range(SOLID_WALL_PATH.size() - 1):
		_build_wall_segment(
			generated_root,
			SOLID_WALL_PATH[index],
			SOLID_WALL_PATH[index + 1],
			index,
			wall_material,
			baseboard_material,
			scene_root
		)

func _build_wall_segment(
	parent: Node3D,
	start_2d: Vector2,
	end_2d: Vector2,
	segment_index: int,
	wall_material: Material,
	baseboard_material: Material,
	scene_root: Node
) -> void:
	var start: Vector3 = Vector3(start_2d.x, 0.0, start_2d.y)
	var end: Vector3 = Vector3(end_2d.x, 0.0, end_2d.y)
	var edge: Vector3 = end - start
	var edge_length: float = edge.length()
	if edge_length <= 0.1:
		return

	var tangent: Vector3 = edge / edge_length
	var inward: Vector3 = tangent.cross(Vector3.UP).normalized()
	var segment_basis: Basis = Basis(tangent, Vector3.UP, inward)
	var midpoint: Vector3 = (start + end) * 0.5
	var prefix: String = "Wall_%02d_" % segment_index

	# A single uninterrupted wall surface for each perimeter edge.
	var wall_center: Vector3 = midpoint + Vector3.UP * (floor_level + wall_height * 0.5)
	_add_box(
		parent,
		prefix + "Stone",
		Vector3(edge_length + end_overlap, wall_height, wall_thickness),
		Transform3D(segment_basis, wall_center),
		wall_material,
		scene_root,
		true
	)

	# Skirting sits against the interior face of the wall, just above the floor.
	if generate_baseboard and baseboard_height > 0.0 and baseboard_depth > 0.0:
		var baseboard_center: Vector3 = midpoint
		baseboard_center += Vector3.UP * (floor_level + baseboard_height * 0.5)
		baseboard_center += inward * (wall_thickness * 0.5 + baseboard_depth * 0.5 + 0.004)
		_add_box(
			parent,
			prefix + "Baseboard",
			Vector3(edge_length + end_overlap, baseboard_height, baseboard_depth),
			Transform3D(segment_basis, baseboard_center),
			baseboard_material,
			scene_root,
			false
		)

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
