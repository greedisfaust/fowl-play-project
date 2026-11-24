@tool
## Procedural freestanding arcade Plinko cabinet with an oversized illuminated peg field.
class_name EggPlinkoVisualBuilder
extends Node3D

const Rules = preload("res://casino/tables/egg_plinko/egg_plinko_rules.gd")
const GENERATED_NAME: StringName = &"_GeneratedEggPlinko"
const ROW_COUNT: int = 12
const SLOT_COUNT: int = 13
const SLOT_WIDTH: float = 0.19

@export var rebuild_visuals: bool = false:
	set(value):
		rebuild_visuals = false
		if value and is_inside_tree():
			_rebuild()

@export var dark_stone_color: Color = Color(0.025, 0.032, 0.045, 1.0)
@export var bronze_color: Color = Color(0.42, 0.27, 0.12, 1.0)
@export var felt_color: Color = Color(0.012, 0.19, 0.125, 1.0)
@export var warm_light_color: Color = Color(1.0, 0.58, 0.16, 1.0)
@export var cabinet_scale: float = 1.0

func _ready() -> void:
	_rebuild()

func _rebuild() -> void:
	var previous: Node = get_node_or_null(NodePath(GENERATED_NAME))
	if is_instance_valid(previous):
		previous.free()
	var generated := Node3D.new()
	generated.name = GENERATED_NAME
	generated.scale = Vector3.ONE * maxf(cabinet_scale, 0.5)
	add_child(generated)
	_set_owner_recursive(generated)
	var stone := _material(dark_stone_color, 0.48, 0.28)
	var bronze := _material(bronze_color, 0.86, 0.22)
	var dark_metal := _material(Color(0.012, 0.017, 0.026, 1.0), 0.78, 0.26)
	var felt := _material(felt_color, 0.05, 0.82)
	var warm := _material(warm_light_color, 0.24, 0.28, warm_light_color, 1.8)
	_build_cabinet(generated, stone, bronze, dark_metal, felt, warm)
	_build_board(generated, stone, bronze, dark_metal, warm)
	_build_collision(generated)

## One continuous arcade cabinet replaces the old four-legged casino table.
func _build_cabinet(parent: Node3D, stone: Material, bronze: Material, dark_metal: Material, felt: Material, warm: Material) -> void:
	_add_box(parent, "Cabinet_Body", Vector3(3.72, 0.82, 1.35), Vector3(0.0, 0.48, 0.62), stone)
	_add_box(parent, "Cabinet_Front_Inset", Vector3(3.52, 0.56, 0.035), Vector3(0.0, 0.5, 1.31), dark_metal)
	_add_box(parent, "Cabinet_Base_Trim", Vector3(3.78, 0.075, 1.39), Vector3(0.0, 0.105, 0.62), bronze)
	_add_box(parent, "Cabinet_Crown", Vector3(3.82, 0.12, 1.43), Vector3(0.0, 0.91, 0.58), bronze)
	_add_box(parent, "Control_Deck", Vector3(3.55, 0.10, 0.78), Vector3(0.0, 1.02, 1.0), dark_metal)
	_add_box(parent, "Control_Deck_Glow", Vector3(3.38, 0.012, 0.64), Vector3(0.0, 1.078, 1.0), felt)
	_add_box(parent, "Control_Deck_Front_Trim", Vector3(3.52, 0.025, 0.025), Vector3(0.0, 1.085, 1.38), warm)
	_add_box(parent, "Cabinet_Left_Column", Vector3(0.12, 0.95, 1.42), Vector3(-1.82, 0.53, 0.58), bronze)
	_add_box(parent, "Cabinet_Right_Column", Vector3(0.12, 0.95, 1.42), Vector3(1.82, 0.53, 0.58), bronze)
	# The lower control face is deliberately left open for the authored keypad,
	# display and large launch button to sit flush against the cabinet front.
	_add_box(parent, "Front_Panel_Left", Vector3(1.02, 0.62, 0.035), Vector3(-1.22, 0.52, 1.335), stone)
	_add_box(parent, "Front_Panel_Right", Vector3(1.02, 0.62, 0.035), Vector3(1.22, 0.52, 1.335), stone)

func _build_board(parent: Node3D, stone: Material, bronze: Material, dark_metal: Material, warm: Material) -> void:
	# Triangular board silhouette; its bottom edge stays aligned with the
	# existing 13-slot payout row and the host-authored egg path.
	var left := Vector3(-1.55, 0.91, -0.32)
	var peak := Vector3(0.0, 3.62, -0.32)
	var right := Vector3(1.55, 0.91, -0.32)
	_add_triangle(parent, "BoardBackplate", left, right, peak, stone)
	var inner_left := Vector3(-1.42, 1.02, -0.255)
	var inner_peak := Vector3(0.0, 3.43, -0.255)
	var inner_right := Vector3(1.42, 1.02, -0.255)
	_add_triangle(parent, "BoardFelt", inner_left, inner_right, inner_peak, _material(Color(0.012, 0.07, 0.052, 1.0), 0.04, 0.72))
	_add_beam(parent, "OuterRail_Left", left + Vector3(0, 0, 0.11), peak + Vector3(0, 0, 0.11), 0.15, 0.13, bronze)
	_add_beam(parent, "OuterRail_Right", peak + Vector3(0, 0, 0.11), right + Vector3(0, 0, 0.11), 0.15, 0.13, bronze)
	_add_beam(parent, "InnerGlow_Left", inner_left + Vector3(0, 0, 0.16), inner_peak + Vector3(0, 0, 0.16), 0.035, 0.045, warm)
	_add_beam(parent, "InnerGlow_Right", inner_peak + Vector3(0, 0, 0.16), inner_right + Vector3(0, 0, 0.16), 0.035, 0.045, warm)
	_add_beam(parent, "Top_Crown_Rail", peak + Vector3(-0.12, -0.03, 0.10), peak + Vector3(0.12, -0.03, 0.10), 0.16, 0.13, bronze)
	_add_box(parent, "Board_Bottom_Rail", Vector3(3.22, 0.12, 0.16), Vector3(0.0, 0.91, -0.17), bronze)
	_add_box(parent, "Launch_Header", Vector3(0.68, 0.12, 0.12), Vector3(0.0, 3.36, -0.02), warm)

	var peg_material := _material(Color(0.86, 0.78, 0.60, 1.0), 0.82, 0.18)
	var peg_glow := _material(Color(0.94, 0.92, 0.55, 1.0), 0.2, 0.2, Color(0.48, 1.0, 0.22, 1.0), 1.35)
	for row_index: int in range(ROW_COUNT):
		var peg_count: int = row_index + 1
		var y: float = 3.02 - float(row_index) * 0.145
		for peg_index: int in range(peg_count):
			var x: float = (float(peg_index) - float(peg_count - 1) * 0.5) * 0.155
			_add_sphere(parent, "Peg_%02d_%02d" % [row_index + 1, peg_index + 1], 0.026, Vector3(x, y, -0.035), peg_material)
			_add_sphere(parent, "PegCap_%02d_%02d" % [row_index + 1, peg_index + 1], 0.009, Vector3(x, y, 0.004), peg_glow)

	var multipliers: Array[float] = Rules.get_slot_multipliers()
	for slot_index: int in range(SLOT_COUNT):
		var x: float = (float(slot_index) - float(SLOT_COUNT - 1) * 0.5) * SLOT_WIDTH
		var multiplier: float = multipliers[slot_index]
		var slot_color: Color = Color(0.16, 0.62, 0.30, 1.0)
		if multiplier >= 3.0:
			slot_color = Color(0.92, 0.18, 0.12, 1.0)
		elif multiplier >= 1.5:
			slot_color = Color(0.95, 0.48, 0.08, 1.0)
		elif multiplier <= 0.6:
			slot_color = Color(0.10, 0.17, 0.24, 1.0)
		var slot_material := _material(slot_color, 0.24, 0.3, slot_color, 0.85)
		_add_box(parent, "Pocket_%02d" % slot_index, Vector3(SLOT_WIDTH - 0.009, 0.12, 0.08), Vector3(x, 1.07, -0.08), dark_metal)
		_add_box(parent, "PocketLight_%02d" % slot_index, Vector3(SLOT_WIDTH - 0.02, 0.018, 0.025), Vector3(x, 1.13, 0.0), slot_material)
		_add_box(parent, "PocketDivider_%02d" % slot_index, Vector3(0.012, 0.17, 0.12), Vector3(x + SLOT_WIDTH * 0.5, 1.13, -0.04), bronze)
		var label := MeshInstance3D.new()
		label.name = "Multiplier_%02d" % slot_index
		var text_mesh := TextMesh.new()
		text_mesh.text = "%.1fX" % multiplier
		text_mesh.font_size = 24
		text_mesh.pixel_size = 0.003
		text_mesh.depth = 0.001
		label.mesh = text_mesh
		label.position = Vector3(x - 0.055, 0.99, 0.06)
		label.rotation.x = -PI * 0.5
		label.material_override = _material(Color(1.0, 0.9, 0.68, 1.0), 0.12, 0.36, Color(1.0, 0.72, 0.26, 1.0), 0.75)
		parent.add_child(label)
		_set_owner_recursive(label)

func _build_collision(parent: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "PlinkoPhysicalBody"
	body.collision_layer = 1
	body.collision_mask = 1
	parent.add_child(body)
	_add_collision(body, Vector3(3.72, 0.82, 1.35), Vector3(0.0, 0.48, 0.62))
	_add_collision(body, Vector3(0.15, 2.8, 0.16), Vector3(-1.5, 2.2, -0.2))
	_add_collision(body, Vector3(0.15, 2.8, 0.16), Vector3(1.5, 2.2, -0.2))
	_add_collision(body, Vector3(0.25, 2.75, 0.16), Vector3(-0.78, 2.2, -0.2))
	_add_collision(body, Vector3(0.25, 2.75, 0.16), Vector3(0.78, 2.2, -0.2))
	_set_owner_recursive(body)

func _add_triangle(parent: Node3D, node_name: String, a: Vector3, b: Vector3, c: Vector3, material: Material) -> void:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([a, b, c])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(instance)
	_set_owner_recursive(instance)

func _add_beam(parent: Node3D, node_name: String, start: Vector3, finish: Vector3, thickness: float, depth: float, material: Material) -> void:
	var delta: Vector3 = finish - start
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = Vector3(delta.length(), thickness, depth)
	instance.mesh = mesh
	instance.position = (start + finish) * 0.5
	instance.rotation.z = atan2(delta.y, delta.x)
	instance.material_override = material
	parent.add_child(instance)
	_set_owner_recursive(instance)

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
