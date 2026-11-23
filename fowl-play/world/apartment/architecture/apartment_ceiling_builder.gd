@tool
extends Node3D
class_name ApartmentCeilingBuilder

## Warm-modern Apartment ceiling generator.
## Attach to Environment/Architecture/Ceiling at local origin.
## Coordinates are relative to the Apartment root. Decorative geometry only;
## dedicated lighting will be authored in the later lighting pass.

@export_group("Ceiling Dimensions")
@export_range(3.5, 5.0, 0.05) var ceiling_height: float = 4.0
@export_range(0.08, 0.3, 0.01) var slab_thickness: float = 0.18

@export_group("Main Room Tray")
@export var generate_main_room_tray: bool = true
@export_range(0.2, 1.2, 0.05) var tray_inset: float = 0.55
@export_range(0.03, 0.12, 0.005) var trim_width: float = 0.055

@export_group("Hallway Feature")
@export var generate_hallway_linear_detail: bool = true
@export_range(0.02, 0.10, 0.005) var hallway_rail_width: float = 0.045
@export_range(0.4, 1.2, 0.05) var hallway_rail_spacing_from_center: float = 0.72
@export var hallway_detail_end_z: float = 3.5

@export_group("Lobby Feature")
@export var generate_lobby_frame: bool = true

@export_group("Materials")
@export var ceiling_color: Color = Color(0.19, 0.17, 0.14, 1.0)
@export var walnut_color: Color = Color(0.12, 0.075, 0.045, 1.0)
@export var bronze_color: Color = Color(0.36, 0.22, 0.105, 1.0)
@export var warm_light_color: Color = Color(1.0, 0.55, 0.28, 1.0)

@export_group("Collision")
@export var generate_ceiling_collision: bool = true

@export_group("Generation")
@export var rebuild_geometry: bool = false:
	set(value):
		if value:
			call_deferred("_rebuild_geometry")

const GENERATED_ROOT_NAME: String = "_GeneratedApartmentCeiling"

func _ready() -> void:
	if Engine.is_editor_hint() and get_node_or_null(GENERATED_ROOT_NAME) == null:
		_rebuild_geometry()

func _rebuild_geometry() -> void:
	if not Engine.is_editor_hint():
		return
	if ceiling_height <= slab_thickness + 0.5:
		push_warning("ApartmentCeilingBuilder: invalid ceiling dimensions.")
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

	var ceiling_material: StandardMaterial3D = _make_material(ceiling_color, 0.04, 0.72)
	var walnut_material: StandardMaterial3D = _make_material(walnut_color, 0.08, 0.42)
	var bronze_material: StandardMaterial3D = _make_material(bronze_color, 0.72, 0.26)
	var light_material: StandardMaterial3D = _make_emissive_material(warm_light_color, 1.25)

	_add_box(generated_root, "MainRoom_CeilingSlab",
		Vector3(22.0, slab_thickness, 19.0),
		Vector3(0.0, ceiling_height - slab_thickness * 0.5, 0.0),
		ceiling_material, scene_root)
	_add_box(generated_root, "Hallway_CeilingSlab",
		Vector3(3.5, slab_thickness, 34.0),
		Vector3(-12.75, ceiling_height - slab_thickness * 0.5, 0.0),
		ceiling_material, scene_root)
	_add_box(generated_root, "ElevatorLobby_CeilingSlab",
		Vector3(4.5, slab_thickness, 4.5),
		Vector3(-12.75, ceiling_height - slab_thickness * 0.5, -19.25),
		ceiling_material, scene_root)

	if generate_main_room_tray:
		_build_main_room_tray(generated_root, walnut_material, bronze_material, light_material, scene_root)
	if generate_hallway_linear_detail:
		_build_hallway_detail(generated_root, walnut_material, bronze_material, light_material, scene_root)
	if generate_lobby_frame:
		_build_lobby_frame(generated_root, walnut_material, bronze_material, light_material, scene_root)

func _build_main_room_tray(
	parent: Node3D,
	walnut_material: Material,
	bronze_material: Material,
	light_material: Material,
	scene_root: Node
) -> void:
	var min_x: float = -11.0 + tray_inset
	var max_x: float = 11.0 - tray_inset
	var min_z: float = -9.5 + tray_inset
	var max_z: float = 9.5 - tray_inset
	var y: float = ceiling_height - slab_thickness - 0.035
	_add_rect_frame(parent, "MainRoom_Tray_Walnut", min_x, max_x, min_z, max_z,
		0.10, 0.075, y, walnut_material, scene_root)
	_add_rect_frame(parent, "MainRoom_Tray_BronzeReveal", min_x + 0.12, max_x - 0.12,
		min_z + 0.12, max_z - 0.12, 0.025, trim_width, y - 0.045,
		bronze_material, scene_root)
	_add_rect_frame(parent, "MainRoom_Tray_WarmReveal", min_x + 0.17, max_x - 0.17,
		min_z + 0.17, max_z - 0.17, 0.018, 0.025, y - 0.065,
		light_material, scene_root)

func _build_hallway_detail(
	parent: Node3D,
	walnut_material: Material,
	bronze_material: Material,
	light_material: Material,
	scene_root: Node
) -> void:
	# Two slim longitudinal ceiling rails stop before the void fade becomes dense.
	var start_z: float = -16.5
	var end_z: float = clampf(hallway_detail_end_z, start_z + 1.0, 16.5)
	var y: float = ceiling_height - slab_thickness - 0.035
	for side_index: int in range(2):
		var rail_x: float = -12.75 + (hallway_rail_spacing_from_center if side_index == 0 else -hallway_rail_spacing_from_center)
		_add_box(parent, "Hallway_Walnut_Rail_%d" % side_index,
			Vector3(0.12, 0.055, end_z - start_z),
			Vector3(rail_x, y, (start_z + end_z) * 0.5), walnut_material, scene_root)
		_add_box(parent, "Hallway_Bronze_Rail_%d" % side_index,
			Vector3(0.045, 0.025, end_z - start_z - 0.18),
			Vector3(rail_x, y - 0.04, (start_z + end_z) * 0.5), bronze_material, scene_root)
		_add_box(parent, "Hallway_Warm_Light_%d" % side_index,
			Vector3(0.018, 0.012, end_z - start_z - 0.32),
			Vector3(rail_x, y - 0.058, (start_z + end_z) * 0.5), light_material, scene_root)

func _build_lobby_frame(
	parent: Node3D,
	walnut_material: Material,
	bronze_material: Material,
	light_material: Material,
	scene_root: Node
) -> void:
	var min_x: float = -15.0 + 0.28
	var max_x: float = -10.5 - 0.28
	var min_z: float = -21.5 + 0.28
	var max_z: float = -17.0 - 0.28
	var y: float = ceiling_height - slab_thickness - 0.035
	_add_rect_frame(parent, "ElevatorLobby_Walnut_Frame", min_x, max_x, min_z, max_z,
		0.085, 0.065, y, walnut_material, scene_root)
	_add_rect_frame(parent, "ElevatorLobby_Bronze_Reveal", min_x + 0.10, max_x - 0.10,
		min_z + 0.10, max_z - 0.10, 0.025, 0.025, y - 0.04,
		bronze_material, scene_root)
	_add_rect_frame(parent, "ElevatorLobby_Warm_Reveal", min_x + 0.15, max_x - 0.15,
		min_z + 0.15, max_z - 0.15, 0.015, 0.018, y - 0.06,
		light_material, scene_root)

func _add_rect_frame(
	parent: Node3D,
	prefix: String,
	min_x: float,
	max_x: float,
	min_z: float,
	max_z: float,
	height: float,
	width: float,
	y: float,
	material: Material,
	scene_root: Node
) -> void:
	_add_box(parent, prefix + "_North", Vector3(max_x - min_x, height, width),
		Vector3((min_x + max_x) * 0.5, y, min_z), material, scene_root)
	_add_box(parent, prefix + "_South", Vector3(max_x - min_x, height, width),
		Vector3((min_x + max_x) * 0.5, y, max_z), material, scene_root)
	_add_box(parent, prefix + "_West", Vector3(width, height, max_z - min_z),
		Vector3(min_x, y, (min_z + max_z) * 0.5), material, scene_root)
	_add_box(parent, prefix + "_East", Vector3(width, height, max_z - min_z),
		Vector3(max_x, y, (min_z + max_z) * 0.5), material, scene_root)

func _add_box(
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
	if generate_ceiling_collision and node_name.ends_with("CeilingSlab"):
		var body: StaticBody3D = StaticBody3D.new()
		body.name = node_name + "_Collision"
		body.collision_layer = 1
		body.collision_mask = 1 << 4
		parent.add_child(body)
		body.owner = scene_root
		var collision: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = box_size
		collision.shape = shape
		collision.position = box_position
		body.add_child(collision)
		collision.owner = scene_root

func _make_material(color: Color, metallic_value: float, roughness_value: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic_value
	material.roughness = roughness_value
	return material

func _make_emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	material.roughness = 0.32
	return material
