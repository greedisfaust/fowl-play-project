## Static Perya table geometry plus pooled, player-attributed chip stacks and animated dice.
## Geometry is built once; only wager stacks and three dice change during play.
extends Node3D
class_name PeryaVisualBuilder

const Rules = preload("res://casino/tables/perya/perya_rules.gd")
const Layers = preload("res://core/layers.gd")
const TERMINAL_FONT: Font = preload("res://assets/fonts/JetBrainsMonoNL-Regular.ttf")
const COLOR_VALUES: Array[Color] = [
	Color("#e53935"), Color("#2878d0"), Color("#f5c842"),
	Color("#35a765"), Color("#f2eee2"), Color("#ed65a5")
]
const COLOR_DARK: Array[Color] = [
	Color("#781d20"), Color("#173d70"), Color("#78601c"),
	Color("#1a5736"), Color("#77746a"), Color("#762d50")
]
const COLOR_NAMES: Array[String] = ["RED", "BLUE", "YELLOW", "GREEN", "WHITE", "PINK"]

var color_zones: Array[StaticBody3D] = []
var roll_interactable: Interactable
var _dice: Array[Node3D] = []
var _dice_tweens: Array[Tween] = []
var _roll_light: OmniLight3D
var _chip_stacks: Dictionary = {}
var _stack_tweens: Dictionary = {}
var _materials: Dictionary = {}
var _chip_mesh: CylinderMesh
var _chip_rim_mesh: TorusMesh
var _die_body_mesh: BoxMesh
var _die_face_mesh: BoxMesh


func _ready() -> void:
	build()

func build() -> void:
	cancel_dice_animation()
	for tween_value: Variant in _stack_tweens.values():
		var old_tween := tween_value as Tween
		if is_instance_valid(old_tween) and old_tween.is_running():
			old_tween.kill()
	_stack_tweens.clear()
	for child in get_children():
		child.queue_free()
	color_zones.clear()
	_dice.clear()
	_roll_light = null
	_chip_stacks.clear()
	_materials.clear()
	_chip_mesh = CylinderMesh.new()
	_chip_mesh.top_radius = 0.105
	_chip_mesh.bottom_radius = 0.105
	_chip_mesh.height = 0.045
	_chip_mesh.radial_segments = 24
	_chip_rim_mesh = TorusMesh.new()
	_chip_rim_mesh.inner_radius = 0.082
	_chip_rim_mesh.outer_radius = 0.105
	_chip_rim_mesh.rings = 8
	_chip_rim_mesh.ring_segments = 24
	_die_body_mesh = BoxMesh.new()
	_die_body_mesh.size = Vector3(0.34, 0.34, 0.34)
	_die_face_mesh = BoxMesh.new()
	_die_face_mesh.size = Vector3(0.23, 0.012, 0.23)
	_build_table()
	_build_color_board()
	_build_dice_station()
	_build_roll_control()

func _build_table() -> void:
	var root := Node3D.new()
	root.name = "PeryaAssembly"
	add_child(root)
	var dark := _mat(Color("#101923"), 0.72, 0.3)
	var bronze := _mat(Color("#9a6b32"), 0.84, 0.24)
	var felt := _mat(Color("#123c35"), 0.04, 0.88)
	var trim := _mat(Color("#e4b85d"), 0.35, 0.28, Color("#c88d38"), 0.9)
	_box(root, "TableApron", Vector3(4.8, 0.72, 2.35), Vector3(0, 0.58, 0.12), dark)
	_box(root, "TableTop", Vector3(4.92, 0.13, 2.48), Vector3(0, 0.99, 0.12), bronze)
	_box(root, "FeltSurface", Vector3(4.72, 0.035, 2.28), Vector3(0, 1.075, 0.12), felt)
	for x in [-2.05, 2.05]:
		for z in [-0.78, 0.96]:
			_box(root, "Leg_%s_%s" % [str(x), str(z)], Vector3(0.16, 0.92, 0.16), Vector3(x, 0.46, z), dark)
	_box(root, "FrontGoldRail", Vector3(4.76, 0.025, 0.025), Vector3(0, 1.1, 1.27), trim)
	_text(root, "PERya_TITLE", "PERYA  /  COLOR GAME", Vector3(-2.16, 1.13, -0.98), 0.0032, Color("#f4d28a"))
	_text(root, "DICE_TITLE", "THREE DICE  /  SIX COLORS", Vector3(0.52, 1.13, -0.98), 0.0027, Color("#f4d28a"))
	var body := StaticBody3D.new()
	body.name = "TableCollision"
	root.add_child(body)
	_collision(body, Vector3(4.8, 0.72, 2.35), Vector3(0, 0.58, 0.12))

func _build_color_board() -> void:
	var root := get_node("PeryaAssembly") as Node3D
	var board := Node3D.new()
	board.name = "ColorBoard"
	board.position = Vector3(-1.18, 1.11, 0.05)
	root.add_child(board)
	var frame := _mat(Color("#26323c"), 0.82, 0.26)
	_box(board, "BoardBase", Vector3(2.05, 0.045, 1.78), Vector3.ZERO, frame)
	var felt := _mat(Color("#071a1b"), 0.08, 0.78)
	_box(board, "BoardInset", Vector3(1.96, 0.018, 1.69), Vector3(0, 0.031, 0), felt)
	for index in range(Rules.COLOR_COUNT):
		var col := index % 2
		var row := index / 2
		var x := -0.48 + float(col) * 0.98
		var z := -0.52 + float(row) * 0.52
		var color := COLOR_VALUES[index]
		var tile := Node3D.new()
		tile.name = "Color_%s" % COLOR_NAMES[index]
		tile.position = Vector3(x, 0.055, z)
		board.add_child(tile)
		var tile_mat := _mat(COLOR_DARK[index], 0.28, 0.38)
		var inset_mat := _mat(color, 0.18, 0.3, color, 0.45)
		_box(tile, "TileBase", Vector3(0.88, 0.065, 0.43), Vector3.ZERO, tile_mat)
		_box(tile, "ColorInlay", Vector3(0.79, 0.012, 0.34), Vector3(0, 0.04, 0), inset_mat)
		_box(tile, "TopAccent", Vector3(0.73, 0.009, 0.018), Vector3(0, 0.049, -0.15), _mat(Color("#fff0c8"), 0.2, 0.28, Color("#fff0c8"), 0.4))
		_text(tile, "ColorLabel", COLOR_NAMES[index], Vector3(-0.34, 0.052, 0.07), 0.0023, Color("#fff8e8"))
		var zone := StaticBody3D.new()
		zone.name = "ColorZone_%s" % COLOR_NAMES[index]
		zone.position = Vector3(0, 0.07, 0)
		zone.collision_layer = 1 << (Layers.DEVICES - 1)
		zone.collision_mask = 0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.88, 0.16, 0.43)
		shape.shape = box
		zone.add_child(shape)
		var interactable := Interactable.new()
		interactable.name = "Interactable"
		interactable.prompt_text = "BET ON %s" % COLOR_NAMES[index]
		interactable.set_meta("perya_color_index", index)
		tile.add_child(interactable)
		tile.add_child(zone)
		color_zones.append(zone)
		# Dedicated shallow recess for each color's player chip stacks.
		var stack_anchor := Node3D.new()
		stack_anchor.name = "ChipStacks"
		stack_anchor.position = Vector3(0, 0.065, 0.12)
		tile.add_child(stack_anchor)

func _build_dice_station() -> void:
	var root := get_node("PeryaAssembly") as Node3D
	var station := Node3D.new()
	station.name = "DiceCage"
	station.position = Vector3(0.92, 1.14, 0.02)
	root.add_child(station)
	var cage_dark := _mat(Color("#111923"), 0.82, 0.24)
	var gold := _mat(Color("#b58a4a"), 0.82, 0.2, Color("#a56d27"), 0.55)
	_box(station, "CageBase", Vector3(1.72, 0.09, 1.12), Vector3(0, 0, 0), cage_dark)
	_box(station, "CageBack", Vector3(1.72, 0.72, 0.055), Vector3(0, 0.38, -0.54), gold)
	_box(station, "CageLeft", Vector3(0.055, 0.72, 1.12), Vector3(-0.83, 0.38, 0), gold)
	_box(station, "CageRight", Vector3(0.055, 0.72, 1.12), Vector3(0.83, 0.38, 0), gold)
	_box(station, "CageTop", Vector3(1.72, 0.055, 1.12), Vector3(0, 0.74, 0), gold)
	# Open-front cage: three dice remain clearly visible from the player side.
	for index in range(Rules.DICE_COUNT):
		var die := Node3D.new()
		die.name = "Die_%d" % (index + 1)
		die.position = Vector3((float(index) - 1.0) * 0.48, 0.22, 0.0)
		station.add_child(die)
		var body := MeshInstance3D.new()
		body.name = "DieBody"
		body.mesh = _die_body_mesh
		body.material_override = _mat(Color("#eee9dc"), 0.08, 0.3)
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		die.add_child(body)
		_add_die_face(die, 0, Vector3(0, 0.177, 0), Vector3.ZERO)
		_add_die_face(die, 1, Vector3(0, -0.177, 0), Vector3(PI, 0, 0))
		_add_die_face(die, 2, Vector3(0, 0, 0.177), Vector3(-PI * 0.5, 0, 0))
		_add_die_face(die, 3, Vector3(0, 0, -0.177), Vector3(PI * 0.5, 0, 0))
		_add_die_face(die, 4, Vector3(0.177, 0, 0), Vector3(0, 0, -PI * 0.5))
		_add_die_face(die, 5, Vector3(-0.177, 0, 0), Vector3(0, 0, PI * 0.5))
		_dice.append(die)
	_roll_light = OmniLight3D.new()
	_roll_light.name = "RollGlow"
	_roll_light.position = Vector3(0, 0.42, 0.34)
	_roll_light.light_color = Color("#ffc66d")
	_roll_light.light_energy = 1.1
	_roll_light.omni_range = 2.8
	_roll_light.shadow_enabled = false
	station.add_child(_roll_light)
	_text(station, "CageLabel", "ROLL", Vector3(-0.19, 0.8, -0.56), 0.0024, Color("#f4d28a"))

func _build_roll_control() -> void:
	var root := get_node("PeryaAssembly") as Node3D
	var control := Node3D.new()
	control.name = "RollControl"
	control.position = Vector3(1.0, 1.13, 1.02)
	root.add_child(control)
	_cylinder(control, "StartButtonBase", 0.25, 0.12, Vector3.ZERO, _mat(Color("#6f4a22"), 0.82, 0.22))
	_cylinder(control, "StartButtonCap", 0.19, 0.10, Vector3(0, 0.105, 0), _mat(Color("#d9a33d"), 0.3, 0.22, Color("#ffbd45"), 1.1))
	_text(control, "StartText", "START / ROLL", Vector3(-0.34, 0.18, -0.19), 0.0021, Color("#ffe4aa"))
	var body := StaticBody3D.new()
	body.name = "RollButtonBody"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var sphere := CylinderShape3D.new()
	sphere.radius = 0.26
	sphere.height = 0.28
	shape.shape = sphere
	shape.position.y = 0.09
	body.add_child(shape)
	control.add_child(body)
	roll_interactable = Interactable.new()
	roll_interactable.name = "Interactable"
	roll_interactable.prompt_text = "START / ROLL THE DICE"
	control.add_child(roll_interactable)

func add_or_update_chip_stack(color_index: int, peer_id: int, nickname: String, player_color: Color, bet_count: int, total_stake: int) -> void:
	if color_index < 0 or color_index >= color_zones.size() or peer_id <= 0:
		return
	var key := "%d:%d" % [color_index, peer_id]
	var tile := color_zones[color_index].get_parent() as Node3D
	var anchor := tile.get_node("ChipStacks") as Node3D
	var stack := _chip_stacks.get(key) as Node3D
	if not is_instance_valid(stack):
		stack = Node3D.new()
		stack.name = "PlayerStack_%d" % peer_id
		anchor.add_child(stack)
		_chip_stacks[key] = stack
		var chip_material := _mat(Color("#202833"), 0.8, 0.22)
		var rim_material := _mat(player_color, 0.24, 0.25, player_color, 1.15)
		var chip_multimesh := MultiMesh.new()
		chip_multimesh.transform_format = MultiMesh.TRANSFORM_3D
		chip_multimesh.mesh = _chip_mesh
		chip_multimesh.instance_count = 4
		var rim_multimesh := MultiMesh.new()
		rim_multimesh.transform_format = MultiMesh.TRANSFORM_3D
		rim_multimesh.mesh = _chip_rim_mesh
		rim_multimesh.instance_count = 4
		var rim_basis := Basis.IDENTITY
		for chip_index in range(4):
			chip_multimesh.set_instance_transform(
				chip_index,
				Transform3D(Basis.IDENTITY, Vector3(0, 0.0225 + float(chip_index) * 0.032, 0))
			)
			rim_multimesh.set_instance_transform(
				chip_index,
				Transform3D(rim_basis, Vector3(0, 0.045 + float(chip_index) * 0.032, 0))
			)
		var chips := MultiMeshInstance3D.new()
		chips.name = "ChipStack"
		chips.multimesh = chip_multimesh
		chips.material_override = chip_material
		chips.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		stack.add_child(chips)
		var rims := MultiMeshInstance3D.new()
		rims.name = "PlayerColorRims"
		rims.multimesh = rim_multimesh
		rims.material_override = rim_material
		rims.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		stack.add_child(rims)
		var label := _make_text_mesh("%s  x%d" % [nickname.substr(0, 5).to_upper(), bet_count], 0.00135, Color("#fff1d0"))
		label.name = "StackLabel"
		label.position = Vector3(-0.16, 0.19, -0.12)
		stack.add_child(label)
	else:
		var label := stack.get_node_or_null("StackLabel") as MeshInstance3D
		if is_instance_valid(label) and label.mesh is TextMesh:
			(label.mesh as TextMesh).text = "%s  x%d" % [nickname.substr(0, 8).to_upper(), bet_count]
	var chips := stack.get_node_or_null("ChipStack") as MultiMeshInstance3D
	var rims := stack.get_node_or_null("PlayerColorRims") as MultiMeshInstance3D
	if is_instance_valid(chips) and is_instance_valid(chips.multimesh):
		chips.multimesh.visible_instance_count = mini(bet_count, 4)
	if is_instance_valid(rims) and is_instance_valid(rims.multimesh):
		rims.multimesh.visible_instance_count = mini(bet_count, 4)
	var amount := stack.get_node_or_null("AmountLabel") as MeshInstance3D
	if not is_instance_valid(amount):
		amount = _make_text_mesh("$%s" % _format_money(total_stake), 0.0013, Color("#e6c77c"))
		amount.name = "AmountLabel"
		amount.position = Vector3(-0.16, 0.16, 0.02)
		stack.add_child(amount)
	else:
		(amount.mesh as TextMesh).text = "$%s" % _format_money(total_stake)
	_reposition_color_stacks(color_index)
	stack.scale = Vector3.ONE * 0.72
	var previous_tween := _stack_tweens.get(key) as Tween
	if is_instance_valid(previous_tween) and previous_tween.is_running():
		previous_tween.kill()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(stack, "scale", Vector3.ONE, 0.22)
	_stack_tweens[key] = tween
	tween.finished.connect(_on_stack_tween_finished.bind(key), CONNECT_ONE_SHOT)

func _reposition_color_stacks(color_index: int) -> void:
	# Reposition every stack when membership changes; network peer IDs are not
	# guaranteed to arrive in ascending order or be consecutive.
	var peer_ids: Array[int] = []
	var color_prefix := "%d:" % color_index
	for stack_key_value: Variant in _chip_stacks.keys():
		var stack_key := str(stack_key_value)
		if stack_key.begins_with(color_prefix):
			peer_ids.append(int(stack_key.get_slice(":", 1)))
	peer_ids.sort()
	var slot_x := [-0.30, -0.10, 0.10, 0.30]
	for slot_index in range(mini(peer_ids.size(), slot_x.size())):
		var key := "%d:%d" % [color_index, peer_ids[slot_index]]
		var player_stack := _chip_stacks.get(key) as Node3D
		if is_instance_valid(player_stack):
			player_stack.position.x = slot_x[slot_index]

func _on_stack_tween_finished(key: String) -> void:
	var completed_tween := _stack_tweens.get(key) as Tween
	if is_instance_valid(completed_tween) and not completed_tween.is_running():
		_stack_tweens.erase(key)

func animate_color_selection(color_index: int) -> void:
	if color_index < 0 or color_index >= color_zones.size():
		return
	var tile := color_zones[color_index].get_parent() as Node3D
	var inlay := tile.get_node_or_null("ColorInlay") as MeshInstance3D
	if not is_instance_valid(inlay):
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(inlay, "scale", Vector3(1.035, 1.0, 1.035), 0.10)
	tween.tween_property(inlay, "scale", Vector3.ONE, 0.16)

func set_roll_ready(ready: bool, rolling: bool = false) -> void:
	var cap := get_node_or_null("PeryaAssembly/RollControl/StartButtonCap") as MeshInstance3D
	if is_instance_valid(cap):
		var material := cap.material_override as StandardMaterial3D
		if is_instance_valid(material):
			material.emission_enabled = true
			material.emission = Color("#ffbd45")
			material.emission_energy_multiplier = 0.25 if not ready else 2.0
	if is_instance_valid(roll_interactable):
		roll_interactable.prompt_text = "DICE ARE ROLLING" if rolling else ("START / ROLL THE DICE" if ready else "PLACE A COLOR BET FIRST")

func animate_roll_button() -> void:
	var cap := get_node_or_null("PeryaAssembly/RollControl/StartButtonCap") as MeshInstance3D
	if not is_instance_valid(cap):
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(cap, "position:y", 0.045, 0.07)
	tween.tween_property(cap, "position:y", 0.105, 0.18).set_trans(Tween.TRANS_BACK)

func clear_chip_stacks() -> void:
	for tween_value: Variant in _stack_tweens.values():
		var stack_tween := tween_value as Tween
		if is_instance_valid(stack_tween) and stack_tween.is_running():
			stack_tween.kill()
	_stack_tweens.clear()
	for value: Variant in _chip_stacks.values():
		var stack := value as Node
		if is_instance_valid(stack):
			stack.queue_free()
	_chip_stacks.clear()

func _add_die_face(die: Node3D, color_index: int, position: Vector3, rotation: Vector3) -> void:
	var face := MeshInstance3D.new()
	face.name = "Face_%s" % COLOR_NAMES[color_index]
	face.mesh = _die_face_mesh
	face.position = position
	face.rotation = rotation
	face.material_override = _mat(COLOR_VALUES[color_index], 0.12, 0.28, COLOR_VALUES[color_index], 0.8)
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	die.add_child(face)

func _face_up_rotation(color_index: int) -> Vector3:
	match color_index:
		0: return Vector3.ZERO
		1: return Vector3(PI, 0, 0)
		2: return Vector3(-PI * 0.5, 0, 0)
		3: return Vector3(PI * 0.5, 0, 0)
		4: return Vector3(0, 0, PI * 0.5)
		5: return Vector3(0, 0, -PI * 0.5)
	return Vector3.ZERO

func animate_dice(results: Array[int], duration: float = 2.25) -> void:
	if results.size() != Rules.DICE_COUNT or _dice.size() != Rules.DICE_COUNT:
		return
	cancel_dice_animation()
	var total_duration := maxf(duration, 0.5)
	if is_instance_valid(_roll_light):
		var light_tween := create_tween()
		light_tween.tween_property(_roll_light, "light_energy", 3.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		light_tween.tween_property(_roll_light, "light_energy", 1.1, total_duration * 0.72)
	for index in range(Rules.DICE_COUNT):
		var die := _dice[index]
		var home_x := (float(index) - 1.0) * 0.48
		var target_rotation := _face_up_rotation(results[index])
		var spin := Vector3(TAU * (2 + index), TAU * (3 + index), TAU * (2 + index))
		var side_shift := 0.075 if index != 1 else -0.075
		var tween := create_tween()
		_dice_tweens.append(tween)
		# A slight stagger makes the dice feel hand-tumbled instead of mechanically synchronized.
		tween.tween_interval(float(index) * 0.055)
		tween.chain()
		tween.set_parallel(true)
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(die, "rotation", target_rotation + spin, total_duration * 0.56)
		tween.tween_property(die, "position:y", 0.48, total_duration * 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(die, "position:x", home_x + side_shift, total_duration * 0.56)
		# Two quick impacts and a squash give each die a more tactile landing.
		tween.chain()
		tween.tween_property(die, "position:y", 0.31, 0.09).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tween.tween_property(die, "position:y", 0.22, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(die, "rotation", target_rotation, 0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(die, "position:x", home_x, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(die, "scale", Vector3(1.07, 0.91, 1.07), 0.06)
		tween.tween_property(die, "scale", Vector3.ONE, 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(total_duration).timeout
	_dice_tweens.clear()

func cancel_dice_animation(final_dice: Array[int] = []) -> void:
	for tween_value: Tween in _dice_tweens:
		if is_instance_valid(tween_value) and tween_value.is_running():
			tween_value.kill()
	_dice_tweens.clear()
	for index in range(_dice.size()):
		var die := _dice[index]
		if not is_instance_valid(die):
			continue
		var color_index := final_dice[index] if Rules.is_valid_dice(final_dice) else 0
		die.rotation = _face_up_rotation(color_index)
		die.position = Vector3((float(index) - 1.0) * 0.48, 0.22, 0.0)
		die.scale = Vector3.ONE
	if is_instance_valid(_roll_light):
		_roll_light.light_energy = 1.1

func highlight_winning_color(color_index: int) -> void:
	if color_index < 0 or color_index >= color_zones.size():
		return
	var tile := color_zones[color_index].get_parent() as Node3D
	var inlay := tile.get_node_or_null("ColorInlay") as MeshInstance3D
	if not is_instance_valid(inlay):
		return
	var material := inlay.material_override as StandardMaterial3D
	if is_instance_valid(material):
		material.emission_enabled = true
		material.emission = COLOR_VALUES[color_index]
		material.emission_energy_multiplier = 2.2
	var tween := create_tween()
	for _pulse_index in range(3):
		tween.tween_property(inlay, "scale", Vector3(1.04, 1, 1.04), 0.18)
		tween.tween_property(inlay, "scale", Vector3.ONE, 0.18)
	tween.tween_callback(func() -> void: material.emission_energy_multiplier = 0.45)

func _mat(color: Color, metallic: float, roughness: float, emission: Color = Color.BLACK, energy: float = 0.0) -> StandardMaterial3D:
	var key := "%s:%s:%s:%s" % [color.to_html(), str(metallic), str(roughness), str(energy)]
	if _materials.has(key):
		return _materials[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	if energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = energy
	_materials[key] = material
	return material

func _box(parent: Node3D, node_name: String, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
	return instance

func _cylinder(parent: Node3D, node_name: String, radius: float, height: float, position: Vector3, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 32
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
	return instance

func _collision(parent: StaticBody3D, size: Vector3, position: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = position
	parent.add_child(collision)

func _text(parent: Node3D, node_name: String, value: String, position: Vector3, pixel_size: float, color: Color) -> void:
	var label := _make_text_mesh(value, pixel_size, color)
	label.name = node_name
	label.position = position
	label.rotation.x = -PI * 0.5
	parent.add_child(label)

func _make_text_mesh(value: String, pixel_size: float, color: Color) -> MeshInstance3D:
	var mesh := TextMesh.new()
	mesh.text = value
	mesh.font = TERMINAL_FONT
	mesh.font_size = 28
	mesh.pixel_size = pixel_size
	mesh.depth = 0.0008
	var material := _mat(color, 0.1, 0.32, color, 0.25)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance

func _format_money(amount: int) -> String:
	var digits := str(maxi(amount, 0))
	var formatted := ""
	for index in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			formatted += ","
		formatted += digits.substr(index, 1)
	return formatted
