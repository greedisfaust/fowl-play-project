@tool
extends Node3D
class_name CasinoPerimeterBuilder

## Generates the three solid outer walls of the Casino.
## The panoramic façade edges are intentionally omitted.
## Coordinates are relative to the Casino root. Attach to Architecture/Perimeter.

@export_group("Wall Shape")
@export_range(2.0, 8.0, 0.05) var wall_height: float = 4.2
@export_range(0.1, 1.0, 0.01) var wall_thickness: float = 0.38
@export var floor_level: float = 0.0
@export_range(0.0, 0.5, 0.01) var end_overlap: float = 0.08

@export_group("Minimal Architectural Accents")
@export var generate_accents: bool = true
@export_range(0.01, 0.08, 0.005) var accent_height: float = 0.025
@export_range(0.01, 0.08, 0.005) var accent_depth: float = 0.025
@export_range(0.0, 0.5, 0.01) var accent_bottom_height: float = 0.42
@export_range(0.0, 0.5, 0.01) var accent_top_inset: float = 0.38

@export_group("Architectural Wall Wash")
@export var generate_wall_wash_lights: bool = true
@export_range(2.0, 8.0, 0.5) var light_spacing: float = 6.0
@export_range(0.1, 2.0, 0.05) var light_energy: float = 0.65
@export_range(2.0, 10.0, 0.5) var light_range: float = 5.0
@export var light_color: Color = Color(1.0, 0.72, 0.48, 1.0)

@export_group("Materials")
@export var wall_color: Color = Color(0.055, 0.062, 0.072, 1.0)
@export var bronze_color: Color = Color(0.36, 0.22, 0.105, 1.0)

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

	var wall_material: StandardMaterial3D = _make_material(wall_color, 0.12, 0.34)
	var bronze_material: StandardMaterial3D = _make_material(bronze_color, 0.72, 0.28)

	for index: int in range(SOLID_WALL_PATH.size() - 1):
		_build_wall_segment(
			generated_root,
			SOLID_WALL_PATH[index],
			SOLID_WALL_PATH[index + 1],
			index,
			wall_material,
			bronze_material,
			scene_root
		)

func _build_wall_segment(
	parent: Node3D,
	start_2d: Vector2,
	end_2d: Vector2,
	segment_index: int,
	wall_material: Material,
	bronze_material: Material,
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
	var wall_center: Vector3 = midpoint + Vector3.UP * (floor_level + wall_height * 0.5)

	# One clean, continuous stone surface per perimeter edge.
	_add_box(
		parent,
		prefix + "Stone",
		Vector3(edge_length + end_overlap, wall_height, wall_thickness),
		Transform3D(segment_basis, wall_center),
		wall_material,
		scene_root,
		true
	)

	if generate_accents:
		_add_wall_line(
			parent, prefix + "LowerBronzeReveal", start, tangent, inward,
			edge_length, floor_level + accent_bottom_height,
			accent_height, accent_depth, segment_basis, bronze_material, scene_root
		)
		_add_wall_line(
			parent, prefix + "UpperBronzeReveal", start, tangent, inward,
			edge_length, floor_level + wall_height - accent_top_inset,
			accent_height, accent_depth, segment_basis, bronze_material, scene_root
		)

	if generate_wall_wash_lights:
		var light_count: int = maxi(1, int(ceil(edge_length / maxf(2.0, light_spacing))))
		for light_index: int in range(light_count):
			var distance_along: float = (float(light_index) + 0.5) * edge_length / float(light_count)
			var wall_light: OmniLight3D = OmniLight3D.new()
			wall_light.name = prefix + "WallWash_%02d" % light_index
			wall_light.position = start + tangent * distance_along + inward * 0.9 + Vector3.UP * (floor_level + wall_height - 0.55)
			wall_light.light_color = light_color
			wall_light.light_energy = light_energy
			wall_light.omni_range = light_range
			wall_light.shadow_enabled = false
			parent.add_child(wall_light)
			wall_light.owner = scene_root

func _add_wall_line(
	parent: Node3D,
	node_name: String,
	start: Vector3,
	tangent: Vector3,
	inward: Vector3,
	edge_length: float,
	height: float,
	line_height: float,
	line_depth: float,
	segment_basis: Basis,
	material: Material,
	scene_root: Node
) -> void:
	var line_center: Vector3 = start + tangent * (edge_length * 0.5)
	line_center += Vector3.UP * height
	line_center += inward * (wall_thickness * 0.5 + line_depth * 0.5 + 0.006)
	_add_box(
		parent,
		node_name,
		Vector3(edge_length, line_height, line_depth),
		Transform3D(segment_basis, line_center),
		material,
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
