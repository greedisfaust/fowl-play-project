@tool
## Cluckpot's mechanical cabinet, sculpted reel symbols, and editable collision.
class_name CluckpotVisualBuilder
extends Node3D

const Rules = preload("res://casino/tables/cluckpot/cluckpot_rules.gd")

@export var machine_number: int = 1
@export var rebuild_visuals: bool = false:
	set(value):
		rebuild_visuals = false
		if value and is_inside_tree():
			_rebuild()

var reel_cells: Array[Array] = []


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	for child: Node in get_children():
		if child.name == "Cabinet":
			child.free()
	build(self, machine_number)


func build(parent: Node3D, number: int = 1) -> void:
	var cabinet := Node3D.new()
	cabinet.name = "Cabinet"
	parent.add_child(cabinet)

	var enamel := _mat(Color("#858783"), 0.72, 0.36)
	var burgundy := _mat(Color("#4b1721"), 0.34, 0.32)
	var brass := _mat(Color("#928a79"), 0.76, 0.3)
	var bright_brass := _mat(Color("#d0c6b1"), 0.78, 0.26)
	var dark_brass := _mat(Color("#514a3e"), 0.68, 0.36)
	var ivory := _mat(Color("#eee2c9"), 0.04, 0.42)
	var black := _mat(Color("#111619"), 0.22, 0.2)
	var walnut := _mat(Color("#38251b"), 0.08, 0.38)

	# Solid, rounded-looking cast-metal silhouette with stepped shoulders.
	_box(cabinet, "MainCasting", Vector3(1.72, 2.34, 0.98), Vector3(0, 1.28, 0), enamel)
	_box(cabinet, "WoodenFoot", Vector3(1.86, 0.19, 1.08), Vector3(0, 0.13, 0), walnut)
	_box(cabinet, "FootBrassLine", Vector3(1.88, 0.035, 1.09), Vector3(0, 0.235, 0), bright_brass)
	_box(cabinet, "UpperShoulder", Vector3(1.68, 0.43, 0.96), Vector3(0, 2.36, 0), enamel)
	_box(cabinet, "CrownBand", Vector3(1.7, 0.07, 1.0), Vector3(0, 2.16, 0), brass)
	# Rounded cast shoulders soften the silhouette beyond a stack of flat boxes.
	var left_cheek := _sphere(cabinet, "LeftCastCheek", 0.5, Vector3(-0.79, 1.48, 0.02), enamel)
	left_cheek.scale = Vector3(0.36, 1.18, 1.0)
	var right_cheek := _sphere(cabinet, "RightCastCheek", 0.5, Vector3(0.79, 1.48, 0.02), enamel)
	right_cheek.scale = Vector3(0.36, 1.18, 1.0)
	_box(cabinet, "CrownPinstripe", Vector3(1.54, 0.025, 0.025), Vector3(0, 2.18, 0.505), bright_brass)
	_box(cabinet, "FrontBurgundyEnamel", Vector3(1.57, 2.03, 0.075), Vector3(0, 1.28, 0.51), burgundy)
	_box(cabinet, "InnerFace", Vector3(1.48, 1.18, 0.055), Vector3(0, 1.57, 0.565), enamel)

	# Thick stepped brass reel bezel and dark glass recess.
	_box(cabinet, "BezelTop", Vector3(1.52, 0.075, 0.14), Vector3(0, 2.13, 0.62), bright_brass)
	_box(cabinet, "BezelBottom", Vector3(1.52, 0.075, 0.14), Vector3(0, 1.01, 0.62), bright_brass)
	_box(cabinet, "BezelLeft", Vector3(0.075, 1.18, 0.14), Vector3(-0.72, 1.57, 0.62), bright_brass)
	_box(cabinet, "BezelRight", Vector3(0.075, 1.18, 0.14), Vector3(0.72, 1.57, 0.62), bright_brass)
	_box(cabinet, "ReelCavity", Vector3(1.34, 1.02, 0.09), Vector3(0, 1.57, 0.61), black)
	_box(cabinet, "Glass", Vector3(1.28, 0.96, 0.025), Vector3(0, 1.57, 0.665), _mat(Color(0.063, 0.082, 0.102, 0.88), 0.2, 0.1))
	_box(cabinet, "PaylineGold", Vector3(1.29, 0.025, 0.035), Vector3(0, 1.57, 0.704), bright_brass)

	# A single iconic jackpot medallion replaces the old text-heavy marquee.
	var medallion := _sphere(cabinet, "SevenMedallion", 0.19, Vector3(0, 2.43, 0.57), burgundy)
	medallion.scale = Vector3(1.35, 0.88, 0.34)
	var medallion_rim := _cylinder(cabinet, "SevenMedallionRim", 0.19, 0.035, Vector3(0, 2.43, 0.69), bright_brass)
	medallion_rim.rotation.x = deg_to_rad(90.0)
	_text(cabinet, "JackpotSeven", "7", 0.22, Vector3(0, 2.43, 0.715), _mat(Color("#e6c47d"), 0.7, 0.24))
	for x: float in [-0.76, 0.76]:
		for y: float in [0.31, 2.28]:
			_sphere(cabinet, "Rivet", 0.035, Vector3(x, y, 0.57), bright_brass)

	# Three separate vertical reel carriers; symbol objects are real meshes, not text.
	var reels := Node3D.new()
	reels.name = "Reels"
	cabinet.add_child(reels)
	reel_cells.clear()
	var idle: Array[Array] = [
		["CHERRY", "SEVEN", "EGG"],
		["ROOSTER", "SEVEN", "CORN"],
		["LEMON", "SEVEN", "CHICK"],
	]
	for reel_index: int in range(3):
		var drum := Node3D.new()
		drum.name = "Reel_%d" % reel_index
		reels.add_child(drum)
		var cells: Array[Node3D] = []
		var x := (float(reel_index) - 1.0) * 0.425
		for row: int in range(3):
			var cell := Node3D.new()
			cell.name = "Cell_%d" % row
			cell.position = Vector3(x, 1.88 - float(row) * 0.31, 0.745)
			drum.add_child(cell)
			_box(cell, "IvoryTile", Vector3(0.39, 0.285, 0.018), Vector3.ZERO, ivory)
			set_symbol_icon(cell, str(idle[reel_index][row]))
			cells.append(cell)
		reel_cells.append(cells)

	# Subtle vertical cooling ribs and a recessed coin-return assembly.
	for rib_index: int in range(5):
		_box(cabinet, "LowerRib_%d" % rib_index, Vector3(0.018, 0.27, 0.018), Vector3(-0.56 + float(rib_index) * 0.28, 0.59, 0.63), brass)
	_box(cabinet, "LowerPanel", Vector3(1.42, 0.48, 0.10), Vector3(0, 0.59, 0.55), enamel)
	_box(cabinet, "LowerPanelInset", Vector3(1.28, 0.35, 0.025), Vector3(0, 0.59, 0.615), burgundy)
	_box(cabinet, "CoinReturnRim", Vector3(0.58, 0.19, 0.08), Vector3(0, 0.59, 0.67), bright_brass)
	_box(cabinet, "CoinReturnDark", Vector3(0.49, 0.12, 0.025), Vector3(0, 0.59, 0.72), black)
	# Keep the coin return purely mechanical; no decorative label.

	# Physical side lever: decorative and animated on confirmed keypad wager.
	var mount := _cylinder(cabinet, "LeverMount", 0.16, 0.11, Vector3(0.91, 1.63, 0.18), brass)
	mount.rotation.z = PI * 0.5
	var arm := _cylinder(cabinet, "LeverArm", 0.035, 0.52, Vector3(1.01, 1.88, 0.2), bright_brass)
	arm.name = "LeverArm"
	arm.rotation.z = deg_to_rad(-22)
	var grip := _sphere(cabinet, "LeverGrip", 0.13, Vector3(1.12, 2.1, 0.2), _mat(Color("#a30e19"), 0.45, 0.16))
	grip.name = "LeverGrip"

	# Head-mounted WorldScreen for wager range and current selection.
	var screen_scene: PackedScene = load("res://environment/kit/world_screen.tscn") as PackedScene
	if screen_scene != null:
		var screen: WorldScreen = screen_scene.instantiate() as WorldScreen
		screen.name = "WagerWorldScreen"
		screen.display_size = Vector2(1.08, 0.48)
		screen.pixels_per_unit = 2048
		screen.text_scale = 1.0
		screen.font_size_ratio = 0.105
		screen.content_padding_ratio = 0.12
		screen.position = Vector3(0, 2.68, 0.51)
		screen.rotation.x = deg_to_rad(-5.0)
		cabinet.add_child(screen)
		var display := screen.get_screen_text()
		if display != null:
			display.terminal_font_size = 54
			display.content_padding_ratio = 0.10
			display.show_layout(ScreenText.LAYOUT_WARNING, "READY", "MIN  $100\nMAX  $5,000\nWAGER  --", "SET WAGER")

	# Cabinet light accents.
	var crown_light := OmniLight3D.new()
	crown_light.name = "CrownGlow"
	crown_light.position = Vector3(0, 2.72, 0.58)
	crown_light.light_color = Color("#d6c5a3")
	crown_light.light_energy = 0.28
	crown_light.omni_range = 1.2
	cabinet.add_child(crown_light)
	var body := StaticBody3D.new()
	body.name = "CabinetCollision"
	cabinet.add_child(body)
	_collision(body, Vector3(1.76, 2.42, 1.02), Vector3(0, 1.28, 0))
	_collision(body, Vector3(0.16, 0.2, 0.2), Vector3(1.0, 1.63, 0.2))
	_set_owner_recursive(cabinet)


func set_symbol_icon(cell: Node3D, symbol: String) -> void:
	for child in cell.get_children():
		if child.name == "SymbolIcon":
			child.free()
	var icon := Node3D.new()
	icon.name = "SymbolIcon"
	cell.add_child(icon)
	match symbol:
		"SEVEN":
			var seven := _text(icon, "GoldenSeven", "7", 0.29, Vector3(0, 0, 0.055), _mat(Color("#e4bd70"), 0.68, 0.23))
			seven.rotation.x = 0
		"ROOSTER", "WILD":
			var gold := symbol == "WILD"
			var body_mat := _mat(Color("#f0b83d") if gold else Color("#b72d24"), 0.35, 0.25, Color("#e99b2f") if gold else Color("#7d1718"), 0.45)
			_sphere(icon, "Body", 0.105, Vector3(0, -0.015, 0.07), body_mat).scale = Vector3(1.25, 0.82, 0.72)
			_sphere(icon, "Breast", 0.075, Vector3(-0.055, -0.045, 0.12), body_mat)
			_sphere(icon, "Head", 0.067, Vector3(0.07, 0.09, 0.08), body_mat)
			_cone(icon, "Beak", 0.035, 0.075, Vector3(0.13, 0.075, 0.09), _mat(Color("#f4a52f"), 0.25, 0.3))
			_sphere(icon, "Comb", 0.035, Vector3(0.055, 0.16, 0.08), _mat(Color("#c51e25"), 0.2, 0.25))
			_sphere(icon, "Eye", 0.012, Vector3(0.102, 0.105, 0.14), black_material())
			for feather_index: int in range(3):
				var tail := _sphere(icon, "TailFeather", 0.045, Vector3(-0.13, 0.055 + feather_index * 0.035, 0.045), body_mat)
				tail.scale = Vector3(0.65, 1.8, 0.55)
			_box(icon, "Feet", Vector3(0.13, 0.018, 0.025), Vector3(0, -0.13, 0.08), _mat(Color("#e89a29"), 0.25, 0.3))
		"CHICK":
			var chick_mat := _mat(Color("#ffd45c"), 0.12, 0.3, Color("#d99c27"), 0.3)
			_sphere(icon, "ChickBody", 0.115, Vector3(0, -0.025, 0.07), chick_mat).scale = Vector3(1.0, 0.9, 0.72)
			_sphere(icon, "ChickHead", 0.082, Vector3(0.035, 0.09, 0.08), chick_mat)
			_cone(icon, "ChickBeak", 0.03, 0.06, Vector3(0.105, 0.075, 0.13), _mat(Color("#e58b21"), 0.2, 0.3))
			_sphere(icon, "ChickEye", 0.012, Vector3(0.075, 0.105, 0.145), black_material())
			_sphere(icon, "ChickWing", 0.052, Vector3(-0.06, -0.015, 0.13), _mat(Color("#f2bb42"), 0.1, 0.35))
		"EGG":
			var egg := _sphere(icon, "SpeckledEgg", 0.12, Vector3(0, 0, 0.07), _mat(Color("#f4e7c8"), 0.05, 0.24))
			egg.scale = Vector3(0.78, 1.18, 0.62)
			for spot: int in range(5):
				_sphere(icon, "EggSpeckle", 0.009, Vector3(-0.05 + float(spot % 3) * 0.045, -0.035 + float(spot / 3) * 0.07, 0.145), _mat(Color("#bd9871"), 0.0, 0.5))
		"CORN":
			_cylinder(icon, "CornCob", 0.072, 0.25, Vector3(0, 0, 0.07), _mat(Color("#f5c83d"), 0.1, 0.28))
			for row: int in range(4):
				for col: int in range(3):
					_sphere(icon, "Kernel", 0.027, Vector3(-0.045 + col * 0.045, -0.085 + row * 0.055, 0.135), _mat(Color("#ffdf54"), 0.08, 0.23))
			_cone(icon, "Husk", 0.07, 0.18, Vector3(-0.09, -0.07, 0.05), _mat(Color("#3d8b42"), 0.05, 0.35))
		"CHERRY":
			var cherry_mat := _mat(Color("#c91528"), 0.18, 0.18, Color("#5c0714"), 0.35)
			_sphere(icon, "CherryLeft", 0.075, Vector3(-0.065, -0.045, 0.08), cherry_mat)
			_sphere(icon, "CherryRight", 0.075, Vector3(0.065, -0.045, 0.08), cherry_mat)
			_cylinder(icon, "CherryStemLeft", 0.009, 0.19, Vector3(-0.035, 0.07, 0.08), _mat(Color("#39834b"), 0.0, 0.4))
			_cylinder(icon, "CherryStemRight", 0.009, 0.19, Vector3(0.035, 0.07, 0.08), _mat(Color("#39834b"), 0.0, 0.4))
			_sphere(icon, "Leaf", 0.045, Vector3(0.035, 0.15, 0.08), _mat(Color("#3c9b4e"), 0.0, 0.3)).scale = Vector3(1.5, 0.5, 0.4)
		"LEMON":
			var lemon := _sphere(icon, "Lemon", 0.105, Vector3(0, 0, 0.07), _mat(Color("#ffdc36"), 0.08, 0.22))
			lemon.scale = Vector3(1.35, 0.78, 0.72)
			_sphere(icon, "LemonTipLeft", 0.026, Vector3(-0.14, 0, 0.07), _mat(Color("#f1bf28"), 0.05, 0.25))
			_sphere(icon, "LemonTipRight", 0.026, Vector3(0.14, 0, 0.07), _mat(Color("#f1bf28"), 0.05, 0.25))
		"FEATHER":
			var feather_mat := _mat(Color("#e8e5d9"), 0.12, 0.26)
			var shaft := _cylinder(icon, "Quill", 0.009, 0.28, Vector3(0, 0, 0.08), _mat(Color("#bcae8e"), 0.15, 0.3))
			shaft.rotation.z = deg_to_rad(-28)
			for barb: int in range(5):
				var vane := _sphere(icon, "Vane", 0.025, Vector3(-0.035 + barb * 0.018, -0.07 + barb * 0.035, 0.08), feather_mat)
				vane.scale = Vector3(1.6, 0.55, 0.35)
		_:
			_text(icon, "FallbackSeven", "7", 0.25, Vector3(0, 0, 0.05), bright_material())


func black_material() -> StandardMaterial3D:
	return _mat(Color("#08090b"), 0.05, 0.15)


func bright_material() -> StandardMaterial3D:
	return _mat(Color("#e4bd70"), 0.68, 0.23)


func _box(parent: Node3D, node_name: String, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.material_override = material
	parent.add_child(node)
	return node


func _text(parent: Node3D, node_name: String, value: String, size: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := TextMesh.new()
	mesh.text = value
	mesh.font_size = 64
	mesh.pixel_size = size / 64.0
	mesh.depth = 0.006
	mesh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mesh.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.mesh = mesh
	node.position = pos
	node.material_override = material
	parent.add_child(node)
	return node


func _cylinder(parent: Node3D, node_name: String, radius: float, height: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	node.mesh = mesh
	node.position = pos
	node.material_override = material
	parent.add_child(node)
	return node


func _sphere(parent: Node3D, node_name: String, radius: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 20
	mesh.rings = 12
	node.mesh = mesh
	node.position = pos
	node.material_override = material
	parent.add_child(node)
	return node


func _cone(parent: Node3D, node_name: String, radius: float, height: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	node.mesh = mesh
	node.position = pos
	node.material_override = material
	parent.add_child(node)
	return node


func _collision(parent: StaticBody3D, size: Vector3, pos: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = pos
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
	for child in node.get_children():
		_set_owner_recursive(child)
