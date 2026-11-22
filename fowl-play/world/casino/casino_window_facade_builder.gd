@tool
extends Node3D
class_name CasinoWindowFacadeBuilder

## Editor-time panoramic window façade generator.
## Coordinates in facade_points are local X/Z positions relative to the Casino root.
## The current Casino Environment is offset by Z = -9.665, so the defaults below
## already account for that offset and follow the angled edge plus adjoining long edge.

@export_group("Facade Path")
@export var facade_points: PackedVector2Array = PackedVector2Array([
	Vector2(-24.0, -18.665),
	Vector2(-14.0, -28.665),
	Vector2(11.0, -28.665)
])

@export_group("Dimensions")
@export_range(1.0, 8.0, 0.05) var window_height: float = 3.8
@export_range(0.0, 2.0, 0.01) var sill_height: float = 0.45
@export_range(0.05, 0.8, 0.01) var sill_depth: float = 0.32
@export_range(0.02, 0.3, 0.005) var glass_thickness: float = 0.035
@export_range(1.0, 6.0, 0.1) var mullion_spacing: float = 2.4
@export_range(0.025, 0.2, 0.005) var mullion_width: float = 0.075
@export_range(0.025, 0.2, 0.005) var frame_depth: float = 0.12
@export_range(0.025, 0.2, 0.005) var rail_height: float = 0.09
@export_group("Upper Transom")
@export var generate_upper_transom: bool = true
@export_range(3.8, 4.5, 0.01) var ceiling_underside_y: float = 4.02

@export_group("Placement")
@export var base_y: float = 0.0
@export var generate_end_posts: bool = true

@export_group("Materials")
@export var glass_tint: Color = Color(0.72, 0.86, 0.94, 0.20)
@export var bronze_color: Color = Color(0.36, 0.22, 0.105, 1.0)
@export var sill_color: Color = Color(0.075, 0.082, 0.09, 1.0)

@export_group("Generation")
@export var rebuild_geometry: bool = false:
	set(value):
		if value:
			call_deferred("_rebuild_geometry")

const GENERATED_ROOT_NAME: String = "_GeneratedPanoramicFacade"

func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild_geometry()

func _rebuild_geometry() -> void:
	if not Engine.is_editor_hint():
		return
	if facade_points.size() < 2:
		push_warning("CasinoWindowFacadeBuilder needs at least two facade points.")
		return
	if window_height <= sill_height + rail_height:
		push_warning("Window height must be greater than sill height plus top rail.")
		return

	var old_root: Node = get_node_or_null(GENERATED_ROOT_NAME)
	if old_root != null:
		old_root.free()

	var scene_root: Node = get_tree().edited_scene_root
	var generated_root: Node3D = Node3D.new()
	generated_root.name = GENERATED_ROOT_NAME
	add_child(generated_root)
	generated_root.owner = scene_root

	var glass_material: StandardMaterial3D = StandardMaterial3D.new()
	glass_material.albedo_color = glass_tint
	glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_material.metallic = 0.28
	glass_material.roughness = 0.10
	glass_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var bronze_material: StandardMaterial3D = StandardMaterial3D.new()
	bronze_material.albedo_color = bronze_color
	bronze_material.metallic = 0.78
	bronze_material.roughness = 0.24

	var sill_material: StandardMaterial3D = StandardMaterial3D.new()
	sill_material.albedo_color = sill_color
	sill_material.metallic = 0.12
	sill_material.roughness = 0.32

	for point_index: int in range(facade_points.size() - 1):
		_build_facade_segment(
			generated_root,
			facade_points[point_index],
			facade_points[point_index + 1],
			glass_material,
			bronze_material,
			sill_material,
			scene_root,
			point_index
		)

func _build_facade_segment(
	parent: Node3D,
	start_2d: Vector2,
	end_2d: Vector2,
	glass_material: Material,
	bronze_material: Material,
	sill_material: Material,
	scene_root: Node,
	segment_index: int
) -> void:
	var start: Vector3 = Vector3(start_2d.x, 0.0, start_2d.y)
	var end: Vector3 = Vector3(end_2d.x, 0.0, end_2d.y)
	var edge: Vector3 = end - start
	var edge_length: float = edge.length()
	if edge_length <= 0.05:
		return

	var tangent: Vector3 = edge / edge_length
	var normal: Vector3 = tangent.cross(Vector3.UP).normalized()
	var segment_basis: Basis = Basis(tangent, Vector3.UP, normal)
	var midpoint: Vector3 = (start + end) * 0.5
	var bottom_y: float = base_y
	var top_y: float = base_y + window_height
	var glass_bottom: float = bottom_y + sill_height
	var glass_top: float = top_y - rail_height
	var glass_height: float = glass_top - glass_bottom
	var prefix: String = "Segment_%02d_" % segment_index

	# Dark stone sill anchors the glazing to the floor.
	_add_box(
		parent, prefix + "StoneSill",
		Vector3(edge_length, sill_height, sill_depth),
		Transform3D(segment_basis, midpoint + Vector3.UP * (bottom_y + sill_height * 0.5)),
		sill_material, scene_root
	)

	# Continuous, lightly tinted glazing keeps the skyline visually open.
	_add_box(
		parent, prefix + "Glass",
		Vector3(maxf(0.05, edge_length - mullion_width), glass_height, glass_thickness),
		Transform3D(segment_basis, midpoint + Vector3.UP * (glass_bottom + glass_height * 0.5)),
		glass_material, scene_root
	)

	# Slim bronze sill accent and top rail.
	_add_box(
		parent, prefix + "SillBronzeAccent",
		Vector3(edge_length, 0.035, sill_depth + 0.015),
		Transform3D(segment_basis, midpoint + Vector3.UP * (glass_bottom + 0.025)),
		bronze_material, scene_root
	)
	_add_box(
		parent, prefix + "TopRail",
		Vector3(edge_length, rail_height, frame_depth),
		Transform3D(segment_basis, midpoint + Vector3.UP * (top_y - rail_height * 0.5)),
		bronze_material, scene_root
	)

	# Narrow glass transom closes the 22cm gap between the top rail and ceiling.
	var transom_height: float = maxf(0.0, ceiling_underside_y - top_y)
	if generate_upper_transom and transom_height > 0.025:
		_add_box(
			parent, prefix + "Upper_Transom_Glass",
			Vector3(maxf(0.05, edge_length - mullion_width), transom_height, glass_thickness),
			Transform3D(segment_basis, midpoint + Vector3.UP * (top_y + transom_height * 0.5)),
			glass_material, scene_root
		)

	# Repeated vertical mullions create a refined curtain-wall rhythm.
	var post_count: int = maxi(1, int(floor(edge_length / maxf(0.5, mullion_spacing))))
	for post_index: int in range(post_count + 1):
		var distance_along: float = minf(float(post_index) * mullion_spacing, edge_length)
		if post_index == post_count:
			distance_along = edge_length
		if not generate_end_posts and (post_index == 0 or post_index == post_count):
			continue
		var post_position: Vector3 = start + tangent * distance_along
		_add_box(
			parent, prefix + "Mullion_%02d" % post_index,
			Vector3(mullion_width, glass_height, frame_depth),
			Transform3D(segment_basis, post_position + Vector3.UP * (glass_bottom + glass_height * 0.5)),
			bronze_material, scene_root
		)
		if generate_upper_transom and transom_height > 0.025:
			_add_box(
				parent, prefix + "Transom_Mullion_%02d" % post_index,
				Vector3(mullion_width, transom_height, frame_depth),
				Transform3D(segment_basis, post_position + Vector3.UP * (top_y + transom_height * 0.5)),
				bronze_material, scene_root
			)

func _add_box(
	parent: Node3D,
	node_name: String,
	box_size: Vector3,
	box_transform: Transform3D,
	material: Material,
	scene_root: Node
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
