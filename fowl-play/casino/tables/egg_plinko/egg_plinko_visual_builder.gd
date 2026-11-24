@tool
## Procedural luxury Egg Plinko board, table body, pegs and multiplier pockets.
class_name EggPlinkoVisualBuilder
extends Node3D

const GENERATED_NAME: StringName = &"_GeneratedEggPlinko"
const ROW_COUNT: int = 12
const SLOT_COUNT: int = 13
const SLOT_WIDTH: float = 0.19

@export var rebuild_visuals: bool = false:
	set(value):
		rebuild_visuals = false
		if value and is_inside_tree():
			_rebuild()

@export var dark_stone_color: Color = Color(0.035, 0.043, 0.052, 1.0)
@export var bronze_color: Color = Color(0.36, 0.22, 0.105, 1.0)
@export var felt_color: Color = Color(0.012, 0.19, 0.125, 1.0)
@export var warm_light_color: Color = Color(1.0, 0.48, 0.19, 1.0)


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	var previous: Node = get_node_or_null(NodePath(GENERATED_NAME))
	if is_instance_valid(previous):
		previous.free()
	var generated := Node3D.new()
	generated.name = GENERATED_NAME
	add_child(generated)
	_set_owner_recursive(generated)
	var stone := _material(dark_stone_color, 0.48, 0.28)
	var bronze := _material(bronze_color, 0.82, 0.24)
	var dark_metal := _material(Color(0.025, 0.032, 0.04, 1.0), 0.72, 0.3)
	var felt := _material(felt_color, 0.05, 0.82)
	var warm := _material(warm_light_color, 0.24, 0.28, warm_light_color, 1.4)
	_build_table(generated, stone, bronze, dark_metal, felt)
	_build_board(generated, stone, bronze, dark_metal, warm)
	_build_collision(generated)


func _build_table(parent: Node3D, stone: Material, bronze: Material, dark_metal: Material, felt: Material) -> void:
	_add_box(parent, "TableTop", Vector3(3.55, 0.18, 2.15), Vector3(0.0, 0.86, 0.62), stone)
	_add_box(parent, "PlayingSurface", Vector3(3.34, 0.035, 1.96), Vector3(0.0, 0.968, 0.62), felt)
	_add_box(parent, "Rim_Front", Vector3(3.5, 0.018, 0.026), Vector3(0.0, 0.975, 1.68), bronze)
	_add_box(parent, "Rim_Back", Vector3(3.5, 0.018, 0.026), Vector3(0.0, 0.975, -0.44), bronze)
	_add_box(parent, "Rim_Left", Vector3(0.026, 0.018, 2.1), Vector3(-1.76, 0.975, 0.62), bronze)
	_add_box(parent, "Rim_Right", Vector3(0.026, 0.018, 2.1), Vector3(1.76, 0.975, 0.62), bronze)
	for x_index: int in range(2):
		for z_index: int in range(2):
			var x: float = -1.48 + float(x_index) * 2.96
			var z: float = -0.16 + float(z_index) * 1.56
			_add_box(parent, "Leg_%d_%d" % [x_index, z_index], Vector3(0.22, 0.82, 0.22), Vector3(x, 0.41, z), dark_metal)
			_add_box(parent, "LegCollar_%d_%d" % [x_index, z_index], Vector3(0.27, 0.045, 0.27), Vector3(x, 0.15, z), bronze)


func _build_board(parent: Node3D, stone: Material, bronze: Material, dark_metal: Material, warm: Material) -> void:
	# Upright board sits behind the table's play surface and faces the players (+Z).
	_add_box(parent, "BoardBackplate", Vector3(2.72, 2.52, 0.16), Vector3(0.0, 2.16, -0.32), stone)
	_add_box(parent, "BoardFelt", Vector3(2.54, 2.36, 0.025), Vector3(0.0, 2.16, -0.225), _material(Color(0.012, 0.075, 0.058, 1.0), 0.05, 0.72))
	_add_box(parent, "Frame_Left", Vector3(0.09, 2.58, 0.12), Vector3(-1.37, 2.16, -0.18), bronze)
	_add_box(parent, "Frame_Right", Vector3(0.09, 2.58, 0.12), Vector3(1.37, 2.16, -0.18), bronze)
	_add_box(parent, "Frame_Top", Vector3(2.78, 0.09, 0.12), Vector3(0.0, 3.45, -0.18), bronze)
	_add_box(parent, "Frame_Bottom", Vector3(2.78, 0.09, 0.12), Vector3(0.0, 0.88, -0.18), bronze)
	_add_box(parent, "LauncherRail", Vector3(0.34, 0.075, 0.12), Vector3(0.0, 3.22, -0.06), warm)
	_add_cylinder(parent, "EggLauncher", 0.105, 0.32, Vector3(0.0, 3.14, -0.01), bronze)

	var peg_material := _material(Color(0.76, 0.69, 0.53, 1.0), 0.76, 0.22)
	var peg_glow := _material(Color(0.98, 0.66, 0.28, 1.0), 0.25, 0.24, Color(0.98, 0.66, 0.28, 1.0), 0.45)
	for row_index: int in range(ROW_COUNT):
		var peg_count: int = row_index + 1
		var y: float = 3.02 - float(row_index) * 0.1615
		for peg_index: int in range(peg_count):
			var x: float = (float(peg_index) - float(peg_count - 1) * 0.5) * 0.155
			_add_sphere(parent, "Peg_%02d_%02d" % [row_index + 1, peg_index + 1], 0.036, Vector3(x, y, -0.035), peg_material)
			_add_sphere(parent, "PegCap_%02d_%02d" % [row_index + 1, peg_index + 1], 0.012, Vector3(x, y, 0.003), peg_glow)

	var multipliers: Array[float] = EggPlinkoRules.get_slot_multipliers()
	for slot_index: int in range(SLOT_COUNT):
		var x: float = (float(slot_index) - float(SLOT_COUNT - 1) * 0.5) * SLOT_WIDTH
		var multiplier: float = multipliers[slot_index]
		var slot_color: Color = Color(0.18, 0.55, 0.34, 1.0)
		if multiplier >= 3.0:
			slot_color = Color(0.82, 0.23, 0.13, 1.0)
		elif multiplier >= 1.5:
			slot_color = Color(0.76, 0.48, 0.18, 1.0)
		elif multiplier <= 0.6:
			slot_color = Color(0.12, 0.23, 0.26, 1.0)
		var slot_material := _material(slot_color, 0.3, 0.34, slot_color, 0.35)
		_add_box(parent, "Pocket_%02d" % slot_index, Vector3(SLOT_WIDTH - 0.009, 0.12, 0.08), Vector3(x, 0.91, -0.08), dark_metal)
		_add_box(parent, "PocketLight_%02d" % slot_index, Vector3(SLOT_WIDTH - 0.02, 0.012, 0.025), Vector3(x, 0.98, 0.0), slot_material)
		_add_box(parent, "PocketDivider_%02d" % slot_index, Vector3(0.012, 0.17, 0.12), Vector3(x + SLOT_WIDTH * 0.5, 0.99, -0.04), bronze)
		var label := MeshInstance3D.new()
		label.name = "Multiplier_%02d" % slot_index
		var text_mesh := TextMesh.new()
		text_mesh.text = "%.1fX" % multiplier
		text_mesh.font_size = 24
		text_mesh.pixel_size = 0.003
		text_mesh.depth = 0.001
		label.mesh = text_mesh
		label.position = Vector3(x - 0.055, 0.78, 0.06)
		label.rotation.x = -PI * 0.5
		label.material_override = _material(Color(0.96, 0.82, 0.55, 1.0), 0.15, 0.42, Color(0.96, 0.72, 0.32, 1.0), 0.55)
		parent.add_child(label)
		_set_owner_recursive(label)


func _build_collision(parent: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "PlinkoPhysicalBody"
	body.collision_layer = 1
	body.collision_mask = 1
	parent.add_child(body)
	_add_collision(body, Vector3(3.55, 0.18, 2.15), Vector3(0.0, 0.86, 0.62))
	_add_collision(body, Vector3(0.22, 0.82, 0.22), Vector3(-1.48, 0.41, -0.16))
	_add_collision(body, Vector3(0.22, 0.82, 0.22), Vector3(1.48, 0.41, -0.16))
	_add_collision(body, Vector3(0.22, 0.82, 0.22), Vector3(-1.48, 0.41, 1.4))
	_add_collision(body, Vector3(0.22, 0.82, 0.22), Vector3(1.48, 0.41, 1.4))
	_add_collision(body, Vector3(2.72, 2.52, 0.16), Vector3(0.0, 2.16, -0.32))
	_set_owner_recursive(body)


func _add_collision(parent: StaticBody3D, size: Vector3, position: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = position
	parent.add_child(collision)
	_set_owner_recursive(collision)


func _add_box(parent: Node3D, node_name: String, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	parent.add_child(instance)
	_set_owner_recursive(instance)
	return instance


func _add_sphere(parent: Node3D, node_name: String, radius: float, position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	parent.add_child(instance)
	_set_owner_recursive(instance)
	return instance


func _add_cylinder(parent: Node3D, node_name: String, radius: float, height: float, position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 0.86
	mesh.height = height
	mesh.radial_segments = 24
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	instance.rotation.x = PI * 0.5
	parent.add_child(instance)
	_set_owner_recursive(instance)
	return instance


func _material(color: Color, metallic: float, roughness: float, emission_color: Color = Color.BLACK, emission_energy: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = emission_color
		material.emission_energy_multiplier = emission_energy
	return material


func _set_owner_recursive(node: Node) -> void:
	if Engine.is_editor_hint():
		var scene_root: Node = get_tree().edited_scene_root
		if is_instance_valid(scene_root) and node != scene_root:
			node.owner = scene_root
	for child: Node in node.get_children():
		_set_owner_recursive(child)
