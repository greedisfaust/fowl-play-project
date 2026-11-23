@tool
extends Node3D
class_name ApartmentWindowFacadeBuilder

## Editor-time Apartment hallway panoramic window façade generator.
## Coordinates in facade_points are local X/Z positions relative to the Apartment root. Attach this builder to Architecture/WindowSystems at zero transform.
## The hallway west wall runs along X = -14.5 from Z = -17 to Z = 17.

@export_group("Facade Path")
@export var facade_points: PackedVector2Array = PackedVector2Array([
	Vector2(-14.5, -17.0),
	Vector2(-14.5, 17.0)
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
@export_range(0.0, 1.0, 0.01) var pillar_clearance: float = 0.70

@export_group("Architectural Header")
@export var generate_architectural_header: bool = true
@export_range(3.8, 4.5, 0.01) var ceiling_underside_y: float = 4.02
@export_range(0.0, 0.08, 0.005) var header_shadow_gap: float = 0.025
@export_range(0.15, 0.55, 0.01) var header_depth: float = 0.34
@export var header_color: Color = Color(0.035, 0.041, 0.049, 1.0)
@export var header_recess_light_color: Color = Color(1.0, 0.48, 0.19, 1.0)

@export_group("Placement")
@export var base_y: float = 0.0
@export var generate_end_posts: bool = true

@export_group("Materials")
@export var glass_tint: Color = Color(0.98, 0.98, 0.96, 0.025)
@export var bronze_color: Color = Color(0.36, 0.22, 0.105, 1.0)
@export var sill_color: Color = Color(0.075, 0.082, 0.09, 1.0)

@export_group("Generation")
@export var rebuild_geometry: bool = false:
	set(value):
		if value:
			call_deferred("_rebuild_geometry")

const GENERATED_ROOT_NAME: String = "_GeneratedApartmentHallwayFacade"

func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	# Wait until the editor has assigned the opened scene as edited_scene_root.
	call_deferred("_ensure_saved_window_setup")

func _ensure_saved_window_setup() -> void:
	if not Engine.is_editor_hint():
		return
	var scene_root: Node = get_tree().edited_scene_root
	if scene_root == null:
		return
	var generated: Node3D = get_node_or_null(GENERATED_ROOT_NAME) as Node3D
	if generated == null:
		_rebuild_geometry()
		return
	_ensure_glass_collisions(generated, scene_root)
	if generated.get_node_or_null("NightCityEnvironment") == null:
		_add_night_city_environment(generated, scene_root)

func _rebuild_geometry() -> void:
	if not Engine.is_editor_hint():
		return
	if facade_points.size() < 2:
		push_warning("ApartmentWindowFacadeBuilder needs at least two facade points.")
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

	# The hallway panorama faces west, so reverse its facade path to orient
	# the shared city rig out from the glass rather than into the Apartment.
	var city_node := Node3D.new()
	city_node.name = "NightCityEnvironment"
	city_node.set_script(load("res://world/casino/night_city_environment.gd"))
	var outward_points := facade_points.duplicate()
	outward_points.reverse()
	city_node.set("facade_points", outward_points)
	city_node.set("buildings_per_segment", 34)
	city_node.set("rain_amount", 1800)
	generated_root.add_child(city_node)
	city_node.owner = scene_root

	var glass_material: StandardMaterial3D = StandardMaterial3D.new()
	glass_material.albedo_color = glass_tint
	glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_material.metallic = 0.0
	glass_material.roughness = 0.025
	glass_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var bronze_material: StandardMaterial3D = StandardMaterial3D.new()
	bronze_material.albedo_color = bronze_color
	bronze_material.metallic = 0.78
	bronze_material.roughness = 0.24

	var header_material: StandardMaterial3D = StandardMaterial3D.new()
	header_material.albedo_color = Color(0.035, 0.041, 0.049, 1.0)
	header_material.metallic = 0.10
	header_material.roughness = 0.38

	var header_light_material: StandardMaterial3D = StandardMaterial3D.new()
	header_light_material.albedo_color = Color(1.0, 0.48, 0.19, 1.0)
	header_light_material.emission_enabled = true
	header_light_material.emission = Color(1.0, 0.48, 0.19, 1.0)
	header_light_material.emission_energy_multiplier = 1.35

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
			header_material,
			header_light_material,
			scene_root,
			point_index
		)

func _ensure_glass_collisions(generated: Node3D, scene_root: Node) -> void:
	for child: Node in generated.get_children():
		var visual: MeshInstance3D = child as MeshInstance3D
		if visual == null or not visual.name.ends_with("Glass"):
			continue
		if generated.get_node_or_null(visual.name + "_Collision") != null:
			continue
		var box_mesh: BoxMesh = visual.mesh as BoxMesh
		if box_mesh == null:
			continue
		var body: StaticBody3D = StaticBody3D.new()
		body.name = visual.name + "_Collision"
		generated.add_child(body)
		body.owner = scene_root
		var collision: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = box_mesh.size
		collision.shape = shape
		collision.transform = visual.transform
		body.add_child(collision)
		collision.owner = scene_root

func _add_night_city_environment(parent: Node3D, scene_root: Node) -> void:
	var city_node: Node3D = Node3D.new()
	city_node.name = "NightCityEnvironment"
	city_node.set_script(load("res://world/casino/night_city_environment.gd"))
	var outward_points: PackedVector2Array = facade_points.duplicate()
	outward_points.reverse()
	city_node.set("facade_points", outward_points)
	city_node.set("rain_amount", 1800)
	parent.add_child(city_node)
	city_node.owner = scene_root

func _build_facade_segment(
	parent: Node3D,
	start_2d: Vector2,
	end_2d: Vector2,
	glass_material: Material,
	bronze_material: Material,
	sill_material: Material,
	header_material: Material,
	header_light_material: Material,
	scene_root: Node,
	segment_index: int
) -> void:
	var original_start: Vector3 = Vector3(start_2d.x, 0.0, start_2d.y)
	var original_end: Vector3 = Vector3(end_2d.x, 0.0, end_2d.y)
	var original_edge: Vector3 = original_end - original_start
	var original_length: float = original_edge.length()
	if original_length <= pillar_clearance * 2.0 + 0.05:
		return

	# Stop all façade components before the corner pillars instead of running glazing through them.
	var original_tangent: Vector3 = original_edge / original_length
	var start: Vector3 = original_start + original_tangent * pillar_clearance
	var end: Vector3 = original_end - original_tangent * pillar_clearance
	var edge: Vector3 = end - start
	var edge_length: float = edge.length()
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
		glass_material, scene_root, true
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

	# A solid charcoal fascia fills the gap above the glazing. A small recessed
	# warm reveal sits on its underside; a narrow shadow gap separates it from
	# the ceiling so the header reads as deliberate architecture, not a patch.
	var header_height: float = maxf(0.0, ceiling_underside_y - top_y - header_shadow_gap)
	if generate_architectural_header and header_height > 0.025:
		var header_center_y: float = top_y + header_height * 0.5
		_add_box(
			parent, prefix + "Charcoal_Architectural_Header",
			Vector3(edge_length, header_height, header_depth),
			Transform3D(segment_basis, midpoint + Vector3.UP * header_center_y),
			header_material, scene_root
		)
		_add_box(
			parent, prefix + "Header_Bronze_Underside_Reveal",
			Vector3(edge_length, 0.018, header_depth + 0.015),
			Transform3D(segment_basis, midpoint + Vector3.UP * (top_y + 0.012)),
			bronze_material, scene_root
		)
		_add_box(
			parent, prefix + "Header_Recessed_Warm_Light",
			Vector3(maxf(0.05, edge_length - 0.12), 0.012, 0.025),
			Transform3D(segment_basis, midpoint + Vector3.UP * (top_y + 0.032) + normal * (header_depth * 0.5 - 0.018)),
			header_light_material, scene_root
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

func _add_box(
	parent: Node3D,
	node_name: String,
	box_size: Vector3,
	box_transform: Transform3D,
	material: Material,
	scene_root: Node,
	with_collision: bool = false
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
	if with_collision:
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
