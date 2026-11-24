@tool
## Procedural premium Art Deco slot cabinet. Meshes and collision stay editable in the scene tree.
class_name CluckpotVisualBuilder
extends Node3D

@export var machine_number: int = 1
@export var rebuild_visuals: bool = false:
	set(value):
		rebuild_visuals = false
		if value and is_inside_tree():
			_rebuild()

var reel_labels: Array[Array] = []
var status_label: MeshInstance3D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	for child: Node in get_children():
		if child.name == "Cabinet":
			child.free()
	build(self, machine_number)


func build(parent: Node3D, machine_number: int = 1) -> void:
	var cabinet := Node3D.new()
	cabinet.name = "Cabinet"
	parent.add_child(cabinet)
	var dark := _mat(Color(0.018, 0.035, 0.031), 0.48, 0.3)
	var green := _mat(Color(0.025, 0.18, 0.115), 0.28, 0.38)
	var gold := _mat(Color(0.72, 0.43, 0.12), 0.9, 0.2)
	var bright_gold := _mat(Color(1.0, 0.72, 0.22), 0.78, 0.2, Color(1.0, 0.47, 0.08), 1.8)
	var black := _mat(Color(0.006, 0.009, 0.012), 0.25, 0.18)
	var ivory := _mat(Color(0.92, 0.84, 0.63), 0.05, 0.3)
	_box(cabinet, "CabinetBody", Vector3(1.82, 2.35, 0.88), Vector3(0, 1.22, 0), dark)
	_box(cabinet, "FrontInset", Vector3(1.68, 2.18, 0.055), Vector3(0, 1.24, 0.47), green)
	_box(cabinet, "BasePlinth", Vector3(1.96, 0.18, 1.0), Vector3(0, 0.12, 0), gold)
	_box(cabinet, "Crown", Vector3(1.96, 0.18, 1.0), Vector3(0, 2.36, 0), gold)
	_box(cabinet, "LeftGoldRail", Vector3(0.075, 2.1, 0.09), Vector3(-0.83, 1.25, 0.51), bright_gold)
	_box(cabinet, "RightGoldRail", Vector3(0.075, 2.1, 0.09), Vector3(0.83, 1.25, 0.51), bright_gold)
	_box(cabinet, "WinFrame", Vector3(1.48, 1.12, 0.11), Vector3(0, 1.47, 0.54), bright_gold)
	_box(cabinet, "ReelGlassBacking", Vector3(1.38, 1.02, 0.08), Vector3(0, 1.47, 0.61), black)
	_box(cabinet, "ReelGlass", Vector3(1.29, 0.92, 0.025), Vector3(0, 1.47, 0.665), _mat(Color(0.025, 0.045, 0.04, 0.92), 0.05, 0.12))
	_text(cabinet, "MachineTitle", "CLUCKPOT", 0.22, Vector3(0, 2.12, 0.56), bright_gold)
	_text(cabinet, "MachineNumber", "NO. %02d" % machine_number, 0.075, Vector3(0, 1.98, 0.56), ivory)
	_box(cabinet, "StatusPanel", Vector3(1.24, 0.19, 0.07), Vector3(0, 0.79, 0.55), black)
	status_label = _text(cabinet, "StatusText", "INSERT WAGER", 0.085, Vector3(0, 0.79, 0.595), bright_gold)
	_box(cabinet, "PaylineTrim", Vector3(1.24, 0.055, 0.07), Vector3(0, 0.69, 0.55), gold)
	_box(cabinet, "LowerPanel", Vector3(1.46, 0.39, 0.08), Vector3(0, 0.43, 0.53), dark)
	_text(cabinet, "WildBadge", "GOLDEN CHICKEN  /  WILD", 0.075, Vector3(0, 0.45, 0.59), bright_gold)
	_text(cabinet, "MachineBrand", "THE GOLDEN COOP", 0.07, Vector3(0, 0.28, 0.59), ivory)

	var reels := Node3D.new()
	reels.name = "Reels"
	cabinet.add_child(reels)
	reel_labels.clear()
	var idle_symbols: Array[Array] = [
		["ROOSTER", "CHICK", "EGG"],
		["CORN", "SEVEN", "FEATHER"],
		["EGG", "WILD", "ROOSTER"],
	]
	for reel_index: int in range(3):
		var reel := Node3D.new()
		reel.name = "Reel_%d" % reel_index
		reels.add_child(reel)
		var reel_cells: Array[MeshInstance3D] = []
		var x: float = (float(reel_index) - 1.0) * 0.42
		for row_index: int in range(3):
			var y: float = 1.78 - float(row_index) * 0.31
			var cell := Node3D.new()
			cell.name = "Cell_%d" % row_index
			reel.add_child(cell)
			var cell_panel := _box(cell, "CellPanel", Vector3(0.39, 0.285, 0.025), Vector3(0, 0, 0), ivory)
			cell_panel.position = Vector3(0, 0, 0)
			var symbol_name: String = str(idle_symbols[reel_index][row_index])
			var symbol_text: String = "7" if symbol_name == "SEVEN" else symbol_name
			var label := _text(cell, "Symbol", symbol_text, 0.18, Vector3(0, 0, 0.025), _mat(Color(1.0, 0.72, 0.12), 0.1, 0.25, Color(1.0, 0.42, 0.05), 0.6))
			label.position = Vector3(0, 0, 0.03)
			cell.position = Vector3(x, y - 1.47, 0.72)
			reel_cells.append(label)
		reel_labels.append(reel_cells)

	# Mechanical lever assembly on the cabinet's right shoulder.
	var lever_mount := _cylinder(cabinet, "LeverMount", 0.14, 0.10, Vector3(0.98, 1.47, 0.58), gold)
	lever_mount.rotation.z = PI * 0.5
	var lever_arm := _cylinder(cabinet, "LeverArm", 0.035, 0.48, Vector3(1.02, 1.67, 0.58), bright_gold)
	lever_arm.rotation.z = deg_to_rad(-22.0)
	_sphere(cabinet, "LeverGrip", 0.12, Vector3(1.12, 1.86, 0.58), _mat(Color(0.7, 0.035, 0.025), 0.3, 0.22))
	_box(cabinet, "ButtonHousing", Vector3(0.46, 0.13, 0.32), Vector3(0, 0.91, 0.88), gold)
	_cylinder(cabinet, "SpinButton", 0.13, 0.08, Vector3(0, 1.02, 0.9), bright_gold)
	_text(cabinet, "SpinLabel", "SPIN", 0.07, Vector3(0, 1.09, 0.95), ivory)

	var body := StaticBody3D.new()
	body.name = "CabinetCollision"
	cabinet.add_child(body)
	_collision(body, Vector3(1.82, 2.35, 0.88), Vector3(0, 1.22, 0))
	_collision(body, Vector3(0.4, 0.5, 0.4), Vector3(1.08, 1.65, 0.1))
	var light := OmniLight3D.new()
	light.name = "CrownGlow"
	light.position = Vector3(0, 2.5, 0.7)
	light.light_color = Color(1.0, 0.63, 0.22)
	light.light_energy = 0.75
	light.omni_range = 2.4
	cabinet.add_child(light)
	_set_owner_recursive(cabinet)


func _box(parent: Node3D, node_name: String, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = position
	node.material_override = material
	parent.add_child(node)
	return node


func _text(parent: Node3D, node_name: String, value: String, size: float, position: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := TextMesh.new()
	mesh.text = value
	mesh.font_size = 48
	mesh.pixel_size = size / 48.0
	mesh.depth = 0.002
	mesh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mesh.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.mesh = mesh
	node.position = position
	node.material_override = material
	parent.add_child(node)
	return node


func _cylinder(parent: Node3D, node_name: String, radius: float, height: float, position: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	node.mesh = mesh
	node.position = position
	node.material_override = material
	parent.add_child(node)
	return node


func _sphere(parent: Node3D, node_name: String, radius: float, position: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	node.mesh = mesh
	node.position = position
	node.material_override = material
	parent.add_child(node)
	return node


func _collision(parent: StaticBody3D, size: Vector3, position: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = position
	parent.add_child(collision)


func _mat(color: Color, metallic: float, roughness: float, emission: Color = Color.BLACK, energy: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	if energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = energy
	return material


func _set_owner_recursive(node: Node) -> void:
	if Engine.is_editor_hint():
		var scene_root: Node = get_tree().edited_scene_root
		if is_instance_valid(scene_root) and node != scene_root:
			node.owner = scene_root
	for child: Node in node.get_children():
		_set_owner_recursive(child)
