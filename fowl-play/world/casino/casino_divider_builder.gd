@tool
extends Node3D
class_name CasinoDividerBuilder

## Builds a waist-to-chest-height architectural divider between the gaming floor and bar.

@export_group("Placement")
@export var start_point: Vector2 = Vector2(1.525, -4.0)
@export var end_point: Vector2 = Vector2(1.525, -25.5)
@export_range(0.8, 1.7, 0.05) var divider_height: float = 1.42
@export_range(0.12, 0.45, 0.01) var divider_thickness: float = 0.30

@export_group("Finish")
@export_range(0.03, 0.12, 0.005) var cap_height: float = 0.065
@export_range(0.02, 0.10, 0.005) var cap_overhang: float = 0.055
@export_range(0.02, 0.08, 0.005) var accent_width: float = 0.045
@export_range(1.5, 5.0, 0.1) var accent_spacing: float = 3.5
@export_range(0.18, 0.5, 0.02) var flute_spacing: float = 0.32
@export var stone_color: Color = Color(0.055, 0.062, 0.072, 1.0)
@export var bronze_color: Color = Color(0.36, 0.22, 0.105, 1.0)

@export_group("Collision")
@export var generate_collision: bool = true

@export_group("Generation")
@export var rebuild_geometry: bool = false:
	set(value):
		if value:
			call_deferred("_rebuild_geometry")

const GENERATED_ROOT_NAME: String = "_GeneratedDivider"

func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild_geometry()

func _rebuild_geometry() -> void:
	if not Engine.is_editor_hint():
		return
	var edge_2d: Vector2 = end_point - start_point
	var edge_length: float = edge_2d.length()
	if edge_length <= 0.5 or divider_height <= cap_height + 0.1:
		push_warning("CasinoDividerBuilder has invalid placement or dimensions.")
		return

	var old_root: Node = get_node_or_null(GENERATED_ROOT_NAME)
	if old_root != null:
		old_root.free()

	var scene_root: Node = get_tree().edited_scene_root
	var generated_root: Node3D = Node3D.new()
	generated_root.name = GENERATED_ROOT_NAME
	add_child(generated_root)
	generated_root.owner = scene_root

	var tangent_2d: Vector2 = edge_2d / edge_length
	var tangent: Vector3 = Vector3(tangent_2d.x, 0.0, tangent_2d.y)
	var inward: Vector3 = tangent.cross(Vector3.UP).normalized()
	var basis: Basis = Basis(tangent, Vector3.UP, inward)
	var midpoint_2d: Vector2 = (start_point + end_point) * 0.5
	var midpoint: Vector3 = Vector3(midpoint_2d.x, 0.0, midpoint_2d.y)
	var body_height: float = divider_height - cap_height
	var stone_material: StandardMaterial3D = _make_material(stone_color, 0.08, 0.38)
	var flute_material: StandardMaterial3D = _make_material(Color(0.085, 0.095, 0.108, 1.0), 0.12, 0.32)
	var bronze_material: StandardMaterial3D = _make_material(bronze_color, 0.72, 0.26)
	var light_material: StandardMaterial3D = _make_emissive_material(Color(1.0, 0.48, 0.19, 1.0), 1.35)

	_add_box(
		generated_root, "Divider_Stone",
		Vector3(edge_length, body_height, divider_thickness),
		Transform3D(basis, midpoint + Vector3.UP * (body_height * 0.5)),
		stone_material, scene_root, true
	)

	# Wider end piers give the divider a deliberate architectural beginning and end.
	for end_index: int in range(2):
		var end_distance: float = 0.32 if end_index == 0 else edge_length - 0.32
		var pier_center: Vector3 = Vector3(start_point.x, 0.0, start_point.y) + tangent * end_distance
		_add_box(
			generated_root, "Divider_End_Pier_%d" % end_index,
			Vector3(0.62, body_height, divider_thickness + 0.08),
			Transform3D(basis, pier_center + Vector3.UP * (body_height * 0.5)),
			flute_material, scene_root, false
		)

	# Shallow vertical flutes add rhythm and shadow without making the divider busy.
	var flute_count: int = int(floor(edge_length / flute_spacing))
	for index: int in range(1, flute_count):
		var distance: float = edge_length * float(index) / float(flute_count)
		var flute_center: Vector3 = Vector3(start_point.x, 0.0, start_point.y) + tangent * distance
		flute_center += Vector3.UP * (body_height * 0.5)
		for side_index: int in range(2):
			var side_sign: float = -1.0 if side_index == 0 else 1.0
			var face_center: Vector3 = flute_center + inward * side_sign * (divider_thickness * 0.5 + 0.012)
			_add_box(
				generated_root, "Divider_Flute_%02d_%d" % [index, side_index],
				Vector3(0.035, body_height * 0.78, 0.035),
				Transform3D(basis, face_center),
				flute_material, scene_root, false
			)

	# Sparse bronze ribs provide a restrained metallic accent on both faces.
	var accent_count: int = int(floor(edge_length / accent_spacing))
	for index: int in range(1, accent_count + 1):
		var distance: float = edge_length * float(index) / float(accent_count + 1)
		var accent_center: Vector3 = Vector3(start_point.x, 0.0, start_point.y) + tangent * distance
		accent_center += Vector3.UP * (body_height * 0.5)
		for side_index: int in range(2):
			var side_sign: float = -1.0 if side_index == 0 else 1.0
			var face_center: Vector3 = accent_center + inward * side_sign * (divider_thickness * 0.5 + 0.035)
			_add_box(
				generated_root, "Divider_Bronze_Accent_%02d_%d" % [index, side_index],
				Vector3(accent_width, body_height * 0.82, 0.018),
				Transform3D(basis, face_center),
				bronze_material, scene_root, false
			)

	# Thin warm light reveals sit just below the cap on both sides.
	for side_index: int in range(2):
		var side_sign: float = -1.0 if side_index == 0 else 1.0
		var light_center: Vector3 = midpoint + Vector3.UP * (body_height - 0.035)
		light_center += inward * side_sign * (divider_thickness * 0.5 + 0.016)
		_add_box(
			generated_root, "Divider_Warm_Light_%d" % side_index,
			Vector3(edge_length - 0.5, 0.018, 0.012),
			Transform3D(basis, light_center),
			light_material, scene_root, false
		)

	_add_box(
		generated_root, "Divider_Bronze_Cap",
		Vector3(edge_length + cap_overhang * 2.0, cap_height, divider_thickness + cap_overhang * 2.0),
		Transform3D(basis, midpoint + Vector3.UP * (body_height + cap_height * 0.5)),
		bronze_material, scene_root, false
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

func _make_emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	material.roughness = 0.3
	return material
