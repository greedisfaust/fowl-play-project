@tool
extends Node3D
class_name CasinoPillarBuilder

## Generates restrained architectural stone piers at the casino's structural transitions.
## Attach to Architecture/Pillars. Coordinates are relative to the Casino root.

@export_group("Placement")
@export var pillar_positions: PackedVector2Array = PackedVector2Array([
	Vector2(-24.0, -18.665),
	Vector2(-14.0, -28.665),
	Vector2(11.0, -28.665),
	Vector2(11.0, -1.665),
	Vector2(-24.0, -1.665)
])

@export_group("Dimensions")
@export_range(3.5, 4.5, 0.05) var pillar_height: float = 4.02
@export_range(0.45, 1.2, 0.05) var shaft_width: float = 0.68
@export_range(0.05, 0.3, 0.01) var base_height: float = 0.18
@export_range(0.08, 0.35, 0.01) var capital_height: float = 0.22
@export_range(0.03, 0.15, 0.005) var trim_width: float = 0.055

@export_group("Finish")
@export var stone_color: Color = Color(0.045, 0.052, 0.062, 1.0)
@export var edge_color: Color = Color(0.085, 0.095, 0.108, 1.0)
@export var bronze_color: Color = Color(0.36, 0.22, 0.105, 1.0)
@export var warm_accent_color: Color = Color(1.0, 0.48, 0.19, 1.0)

@export_group("Collision")
@export var generate_collision: bool = true

@export_group("Generation")
@export var rebuild_geometry: bool = false:
	set(value):
		if value:
			call_deferred("_rebuild_geometry")

const GENERATED_ROOT_NAME: String = "_GeneratedPillars"

func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild_geometry()

func _rebuild_geometry() -> void:
	if not Engine.is_editor_hint():
		return
	if pillar_positions.is_empty() or pillar_height <= base_height + capital_height + 0.5:
		push_warning("CasinoPillarBuilder has invalid positions or dimensions.")
		return

	var old_root: Node = get_node_or_null(GENERATED_ROOT_NAME)
	if old_root != null:
		old_root.free()

	var scene_root: Node = get_tree().edited_scene_root
	var generated_root: Node3D = Node3D.new()
	generated_root.name = GENERATED_ROOT_NAME
	add_child(generated_root)
	generated_root.owner = scene_root

	var stone_material: StandardMaterial3D = _make_material(stone_color, 0.10, 0.34)
	var edge_material: StandardMaterial3D = _make_material(edge_color, 0.12, 0.30)
	var bronze_material: StandardMaterial3D = _make_material(bronze_color, 0.72, 0.25)
	var light_material: StandardMaterial3D = _make_emissive_material(warm_accent_color, 1.2)

	for index: int in range(pillar_positions.size()):
		_build_pillar(
			generated_root,
			index,
			pillar_positions[index],
			stone_material,
			edge_material,
			bronze_material,
			light_material,
			scene_root
		)

func _build_pillar(
	parent: Node3D,
	index: int,
	ground_position: Vector2,
	stone_material: Material,
	edge_material: Material,
	bronze_material: Material,
	light_material: Material,
	scene_root: Node
) -> void:
	var center: Vector3 = Vector3(ground_position.x, 0.0, ground_position.y)
	var shaft_height: float = pillar_height - base_height - capital_height
	var shaft_center_y: float = base_height + shaft_height * 0.5
	var prefix: String = "StonePier_%02d_" % index

	# A single broad collision volume keeps the whole pier solid to the player.
	_add_box(
		parent, prefix + "Shaft",
		Vector3(shaft_width, shaft_height, shaft_width),
		Transform3D(Basis.IDENTITY, center + Vector3.UP * shaft_center_y),
		stone_material, scene_root
	)
	if generate_collision:
		_add_collision(
			parent, prefix + "Collision",
			Vector3(shaft_width, pillar_height, shaft_width),
			center + Vector3.UP * (pillar_height * 0.5),
			scene_root
		)

	# Layered stone plinth gives the column a deliberate connection to the floor.
	_add_box(
		parent, prefix + "Base_Plinth",
		Vector3(shaft_width + 0.22, base_height, shaft_width + 0.22),
		Transform3D(Basis.IDENTITY, center + Vector3.UP * (base_height * 0.5)),
		edge_material, scene_root
	)
	_add_box(
		parent, prefix + "Base_Bronze_Reveal",
		Vector3(shaft_width + 0.16, 0.025, shaft_width + 0.16),
		Transform3D(Basis.IDENTITY, center + Vector3.UP * (base_height - 0.018)),
		bronze_material, scene_root
	)

	# A restrained cap visually ties the pier into the ceiling line.
	var capital_center_y: float = pillar_height - capital_height * 0.5
	_add_box(
		parent, prefix + "Capital",
		Vector3(shaft_width + 0.18, capital_height, shaft_width + 0.18),
		Transform3D(Basis.IDENTITY, center + Vector3.UP * capital_center_y),
		edge_material, scene_root
	)
	_add_box(
		parent, prefix + "Capital_Bronze_Reveal",
		Vector3(shaft_width + 0.22, 0.025, shaft_width + 0.22),
		Transform3D(Basis.IDENTITY, center + Vector3.UP * (pillar_height - capital_height + 0.018)),
		bronze_material, scene_root
	)

	# Four narrow bronze inlays add vertical definition without busy paneling.
	var face_offset: float = shaft_width * 0.5 + 0.012
	var inlay_height: float = maxf(0.2, shaft_height - 0.34)
	var inlay_center_y: float = base_height + shaft_height * 0.5
	var inlay_positions: Array[Vector3] = [
		Vector3(center.x, inlay_center_y, center.z - face_offset),
		Vector3(center.x, inlay_center_y, center.z + face_offset),
		Vector3(center.x - face_offset, inlay_center_y, center.z),
		Vector3(center.x + face_offset, inlay_center_y, center.z)
	]
	for face_index: int in range(inlay_positions.size()):
		var inlay_size: Vector3 = Vector3(trim_width, inlay_height, 0.018)
		if face_index >= 2:
			inlay_size = Vector3(0.018, inlay_height, trim_width)
		_add_box(
			parent, prefix + "Bronze_Inlay_%d" % face_index,
			inlay_size,
			Transform3D(Basis.IDENTITY, inlay_positions[face_index]),
			bronze_material, scene_root
		)

	# Soft warm reveal directly beneath the capital.
	var reveal_y: float = pillar_height - capital_height - 0.035
	for face_index: int in range(4):
		var reveal_position: Vector3 = center
		var reveal_size: Vector3 = Vector3(shaft_width * 0.72, 0.018, 0.012)
		match face_index:
			0:
				reveal_position.z -= face_offset
			1:
				reveal_position.z += face_offset
			2:
				reveal_position.x -= face_offset
				reveal_size = Vector3(0.012, 0.018, shaft_width * 0.72)
			3:
				reveal_position.x += face_offset
				reveal_size = Vector3(0.012, 0.018, shaft_width * 0.72)
		reveal_position.y = reveal_y
		_add_box(
			parent, prefix + "Warm_Cap_Reveal_%d" % face_index,
			reveal_size,
			Transform3D(Basis.IDENTITY, reveal_position),
			light_material, scene_root
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

func _add_collision(
	parent: Node3D,
	node_name: String,
	shape_size: Vector3,
	center: Vector3,
	scene_root: Node
) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	parent.add_child(body)
	body.owner = scene_root
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = shape_size
	collision.shape = shape
	collision.position = center
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
