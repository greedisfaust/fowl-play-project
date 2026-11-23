@tool
extends Node3D
class_name ApartmentMainWindowBuilder

## Editor-time panoramic city-window generator for the Apartment Main Room.
## Attach to a dedicated Node3D child of Architecture/WindowSystems.
## The east wall is at X = 11.0; the structural wall opening spans Z = -7.0 to 7.0.

@export_group("Placement")
@export var wall_x: float = 11.0
@export var window_center_z: float = 0.0
@export var base_y: float = 0.0

@export_group("Dimensions")
@export_range(4.0, 18.0, 0.25) var window_width: float = 14.0
@export_range(1.0, 4.0, 0.05) var window_height: float = 2.30
@export_range(0.0, 2.0, 0.05) var sill_height: float = 0.85
@export_range(0.2, 0.8, 0.01) var sill_depth: float = 0.42
@export_range(0.02, 0.12, 0.005) var glass_thickness: float = 0.035
@export_range(1.5, 4.0, 0.1) var mullion_spacing: float = 2.8
@export_range(0.04, 0.14, 0.005) var mullion_width: float = 0.075
@export_range(0.08, 0.22, 0.01) var frame_depth: float = 0.14
@export_range(0.04, 0.14, 0.005) var rail_height: float = 0.085
@export_range(0.025, 0.10, 0.005) var horizontal_mullion_height: float = 0.055

@export_group("Materials")
@export var glass_tint: Color = Color(0.98, 0.98, 0.96, 0.025)
@export var bronze_color: Color = Color(0.36, 0.22, 0.105, 1.0)
@export var sill_color: Color = Color(0.075, 0.082, 0.09, 1.0)

@export_group("Collision")
@export var generate_glass_collision: bool = true

@export_group("Generation")
@export var rebuild_geometry: bool = false:
	set(value):
		if value:
			call_deferred("_rebuild_geometry")

const GENERATED_ROOT_NAME: String = "_GeneratedApartmentMainPanoramicWindow"

func _ready() -> void:
	if Engine.is_editor_hint() and get_node_or_null(GENERATED_ROOT_NAME) == null:
		_rebuild_geometry()

func _rebuild_geometry() -> void:
	if not Engine.is_editor_hint():
		return
	if window_width <= 0.1 or window_height <= rail_height or sill_height < 0.0:
		push_warning("ApartmentMainWindowBuilder: check the window dimensions.")
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

	# Reuse the same Night City and weather rig as the Casino, oriented out
	# from this Apartment panorama's east-facing window.
	var city_node := Node3D.new()
	city_node.name = "NightCityEnvironment"
	city_node.set_script(load("res://world/casino/night_city_environment.gd"))
	city_node.set("facade_points", PackedVector2Array([
		Vector2(wall_x, window_center_z - window_width * 0.5),
		Vector2(wall_x, window_center_z + window_width * 0.5)
	]))
	city_node.set("buildings_per_segment", 30)
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

	var sill_material: StandardMaterial3D = StandardMaterial3D.new()
	sill_material.albedo_color = sill_color
	sill_material.metallic = 0.12
	sill_material.roughness = 0.32

	# The facade runs along the east wall, parallel to the Z axis.
	var start: Vector3 = Vector3(wall_x, 0.0, window_center_z - window_width * 0.5)
	var end: Vector3 = Vector3(wall_x, 0.0, window_center_z + window_width * 0.5)
	var tangent: Vector3 = (end - start).normalized()
	var normal: Vector3 = tangent.cross(Vector3.UP).normalized()
	var segment_basis: Basis = Basis(tangent, Vector3.UP, normal)
	var midpoint: Vector3 = (start + end) * 0.5
	var bottom_y: float = base_y
	var top_y: float = base_y + sill_height + window_height
	var glass_bottom: float = bottom_y + sill_height
	var glass_top: float = top_y - rail_height
	var glass_height: float = glass_top - glass_bottom
	var prefix: String = "MainRoom_Panoramic_"

	_add_box(
		generated_root, prefix + "StoneSill",
		Vector3(window_width, sill_height, sill_depth),
		Transform3D(segment_basis, midpoint + Vector3.UP * (bottom_y + sill_height * 0.5)),
		sill_material, scene_root
	)

	var glass_size: Vector3 = Vector3(window_width - mullion_width, glass_height, glass_thickness)
	var glass_transform: Transform3D = Transform3D(
		segment_basis,
		midpoint + Vector3.UP * (glass_bottom + glass_height * 0.5)
	)
	_add_box(
		generated_root, prefix + "TintedGlass",
		glass_size, glass_transform, glass_material, scene_root,
		generate_glass_collision
	)

	_add_box(
		generated_root, prefix + "BronzeSillAccent",
		Vector3(window_width, 0.035, sill_depth + 0.015),
		Transform3D(segment_basis, midpoint + Vector3.UP * (glass_bottom + 0.025)),
		bronze_material, scene_root
	)
	_add_box(
		generated_root, prefix + "TopRail",
		Vector3(window_width, rail_height, frame_depth),
		Transform3D(segment_basis, midpoint + Vector3.UP * (top_y - rail_height * 0.5)),
		bronze_material, scene_root
	)

	# Vertical bronze mullions establish the same rhythm as the hallway glazing.
	var mullion_count: int = maxi(1, int(round(window_width / maxf(0.5, mullion_spacing))))
	for mullion_index: int in range(mullion_count + 1):
		var distance_along: float = window_width * float(mullion_index) / float(mullion_count)
		var mullion_position: Vector3 = start + tangent * distance_along
		_add_box(
			generated_root, prefix + "VerticalMullion_%02d" % mullion_index,
			Vector3(mullion_width, glass_height, frame_depth),
			Transform3D(segment_basis, mullion_position + Vector3.UP * (glass_bottom + glass_height * 0.5)),
			bronze_material, scene_root
		)

	# A slim cross-rail adds a subtle horizontal division without breaking the panorama into small panes.
	_add_box(
		generated_root, prefix + "HorizontalMullion",
		Vector3(window_width, horizontal_mullion_height, frame_depth),
		Transform3D(segment_basis, midpoint + Vector3.UP * (glass_bottom + glass_height * 0.52)),
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
