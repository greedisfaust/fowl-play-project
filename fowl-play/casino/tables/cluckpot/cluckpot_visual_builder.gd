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
var reel_drums: Array[Node3D] = []
const REEL_SYMBOL_COUNT: int = 10
const SYMBOL_TEXTURES: Dictionary = {
	"SEVEN": preload("res://assets/images/cluckpot/seven.png"),
	"WILD": preload("res://assets/images/cluckpot/gold_chicken.png"),
	"ROOSTER": preload("res://assets/images/cluckpot/normal_chicken.png"),
	"CHICK": preload("res://assets/images/cluckpot/baby_chicken.png"),
	"EGG": preload("res://assets/images/cluckpot/egg.png"),
	"CORN": preload("res://assets/images/cluckpot/corn.png"),
	"WINGS": preload("res://assets/images/cluckpot/chickenwings.png"),
}
var reel_symbol_cells: Array[Array] = []
var _jackpot_trim_material: StandardMaterial3D
var _symbol_rng := RandomNumberGenerator.new()


func _ready() -> void:
	# The runtime parent configures machine_number and builds this child once.
	# Keep editor previews self-building without duplicating the cabinet at runtime.
	if Engine.is_editor_hint():
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

	for x: float in [-0.76, 0.76]:
		for y: float in [0.31, 2.28]:
			_sphere(cabinet, "Rivet", 0.035, Vector3(x, y, 0.57), bright_brass)

	# Three real horizontal-axis reel drums. Each carries a full ring of symbol tiles.
	var reels := Node3D.new()
	reels.name = "Reels"
	cabinet.add_child(reels)
	reel_cells.clear()
	reel_drums.clear()
	reel_symbol_cells.clear()
	_symbol_rng.randomize()
	for reel_index: int in range(3):
		var drum := Node3D.new()
		drum.name = "Reel_%d" % reel_index
		drum.position = Vector3((float(reel_index) - 1.0) * 0.425, 1.57, 0.27)
		reels.add_child(drum)
		reel_drums.append(drum)
		var barrel := MeshInstance3D.new()
		barrel.name = "CylindricalDrum"
		var barrel_mesh := CylinderMesh.new()
		# Keep the drum core inside the symbol tiles. A full-radius opaque barrel
		# would occlude the artwork wrapped around its outside surface.
		barrel_mesh.top_radius = 0.405
		barrel_mesh.bottom_radius = 0.405
		barrel_mesh.height = 0.39
		barrel_mesh.radial_segments = 48
		barrel.mesh = barrel_mesh
		barrel.rotation.z = PI * 0.5
		barrel.material_override = _mat(Color("#d9cbb0"), 0.16, 0.28)
		drum.add_child(barrel)
		for side: int in [-1, 1]:
			var end_cap := MeshInstance3D.new()
			end_cap.name = "ReelEndCap_%d" % side
			var cap_mesh := CylinderMesh.new()
			cap_mesh.top_radius = 0.485
			cap_mesh.bottom_radius = 0.485
			cap_mesh.height = 0.016
			cap_mesh.radial_segments = 48
			end_cap.mesh = cap_mesh
			end_cap.rotation.z = PI * 0.5
			end_cap.position.x = float(side) * 0.202
			end_cap.material_override = bright_brass
			drum.add_child(end_cap)
		var axle := _cylinder(drum, "Axle", 0.075, 0.54, Vector3.ZERO, dark_brass)
		axle.rotation.z = PI * 0.5
		var cells: Array[Node3D] = []
		for symbol_index: int in range(REEL_SYMBOL_COUNT):
			var angle: float = -TAU * float(symbol_index) / float(REEL_SYMBOL_COUNT)
			var cell := Node3D.new()
			cell.name = "Cell_%d" % symbol_index
			cell.position = Vector3(0, sin(angle) * 0.475, cos(angle) * 0.475)
			cell.rotation.x = -angle
			drum.add_child(cell)
			_box(cell, "IvoryTile", Vector3(0.33, 0.265, 0.018), Vector3(0, 0, 0.012), ivory)
			set_symbol_icon(cell, Rules.SYMBOLS[_symbol_rng.randi_range(0, Rules.SYMBOLS.size() - 1)])
			cells.append(cell)
		# Public row order is top, center, bottom; these exact cells face the payline at rest.
		reel_cells.append([cells[9], cells[0], cells[1]])
		reel_symbol_cells.append(cells)

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
		screen.display_size = Vector2(1.55, 0.58)
		# 1280 px/unit keeps the wide wager readout crisp while cutting its
		# render target from ~3.77 MP to ~1.47 MP per machine.
		screen.pixels_per_unit = 1280
		screen.max_viewport_dimension = 4096
		screen.render_on_demand = true
		screen.text_scale = 1.0
		screen.font_size_ratio = 0.14
		screen.content_padding_ratio = 0.04
		# The enlarged display replaces the old jackpot medallion and sits just
		# above the reel bezel, keeping the entire symbol window unobstructed.
		screen.position = Vector3(0, 2.49, 0.72)
		screen.rotation.x = deg_to_rad(-3.0)
		cabinet.add_child(screen)
		var screen_viewport: SubViewport = screen.get_node_or_null("SubViewport") as SubViewport
		if is_instance_valid(screen_viewport):
			# Font antialiasing remains enabled; 2D MSAA is unnecessary for glyphs.
			screen_viewport.msaa_2d = Viewport.MSAA_DISABLED
		var display := screen.get_screen_text()
		if display != null:
			display.terminal_font_size = 112
			display.content_padding_ratio = 0.04
			display.show_layout(ScreenText.LAYOUT_WARNING, "CLUCKPOT", "MIN  $100     MAX  $5,000\nWAGER  --", "INVALID / SET WAGER")
			screen.request_update()

	# Cabinet light accents.
	var body := StaticBody3D.new()
	body.name = "CabinetCollision"
	cabinet.add_child(body)
	_collision(body, Vector3(1.76, 2.42, 1.02), Vector3(0, 1.28, 0))
	_collision(body, Vector3(0.16, 0.2, 0.2), Vector3(1.0, 1.63, 0.2))
	_set_owner_recursive(cabinet)


func set_reel_outcome(reel_index: int, column: Array, visual_seed: int = 0) -> void:
	if reel_index < 0 or reel_index >= 3 or column.size() != 3:
		return
	if reel_symbol_cells.size() != 3:
		return
	var cells: Array = reel_symbol_cells[reel_index]
	if cells.size() != REEL_SYMBOL_COUNT:
		return
	if visual_seed > 0:
		_symbol_rng.seed = visual_seed
	else:
		_symbol_rng.randomize()
	# Only randomize the seven hidden faces. The visible top/center/bottom cells
	# are assigned their authoritative result once, avoiding three redundant updates.
	for index: int in range(2, 9):
		set_symbol_icon(cells[index], Rules.SYMBOLS[_symbol_rng.randi_range(0, Rules.SYMBOLS.size() - 1)])
	set_symbol_icon(cells[9], str(column[0]))
	set_symbol_icon(cells[0], str(column[1]))
	set_symbol_icon(cells[1], str(column[2]))


func set_symbol_icon(cell: Node3D, symbol: String) -> void:
	var texture: Texture2D = SYMBOL_TEXTURES.get(symbol) as Texture2D
	if texture == null:
		push_warning("Unknown or unavailable Cluckpot symbol texture: %s" % symbol)
		return

	# Keep one Sprite3D per reel cell and swap its cached texture in place.
	var icon: Sprite3D = cell.get_node_or_null("SymbolIcon") as Sprite3D
	if not is_instance_valid(icon):
		icon = Sprite3D.new()
		icon.name = "SymbolIcon"
		icon.position = Vector3(0, 0, 0.055)
		icon.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		icon.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		icon.alpha_scissor_threshold = 0.08
		icon.shaded = false
		icon.double_sided = true
		cell.add_child(icon)

	icon.texture = texture
	var texture_size := Vector2(texture.get_width(), texture.get_height())
	icon.pixel_size = minf(0.30 / texture_size.x, 0.22 / texture_size.y)
	icon.modulate = Color("#fff3d1") if symbol == "SEVEN" else Color.WHITE

	# Jackpot trim is created at most once per cell, then simply toggled.
	var is_jackpot: bool = symbol == "SEVEN"
	var trim_top := icon.get_node_or_null("JackpotTrimTop") as MeshInstance3D
	if is_jackpot and not is_instance_valid(trim_top):
		if not is_instance_valid(_jackpot_trim_material):
			_jackpot_trim_material = _mat(Color("#d4ad63"), 0.62, 0.26)
		_box(icon, "JackpotTrimTop", Vector3(0.32, 0.009, 0.008), Vector3(0, 0.112, 0.035), _jackpot_trim_material)
		_box(icon, "JackpotTrimBottom", Vector3(0.32, 0.009, 0.008), Vector3(0, -0.112, 0.035), _jackpot_trim_material)
		_box(icon, "JackpotTrimLeft", Vector3(0.009, 0.22, 0.008), Vector3(-0.16, 0, 0.035), _jackpot_trim_material)
		_box(icon, "JackpotTrimRight", Vector3(0.009, 0.22, 0.008), Vector3(0.16, 0, 0.035), _jackpot_trim_material)

	# Existing trim remains attached and is only shown for Golden 7 symbols.
	if is_instance_valid(icon.get_node_or_null("JackpotTrimTop")):
		for trim_name: String in ["JackpotTrimTop", "JackpotTrimBottom", "JackpotTrimLeft", "JackpotTrimRight"]:
			var trim := icon.get_node_or_null(trim_name) as MeshInstance3D
			if is_instance_valid(trim):
				trim.visible = is_jackpot


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
