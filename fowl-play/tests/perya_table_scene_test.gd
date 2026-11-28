## Scene smoke test for Perya's physical table, interaction pads, dice, and shared terminal.
extends SceneTree

const PeryaScene = preload("res://casino/tables/perya/perya_table.tscn")
var _failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var table := PeryaScene.instantiate() as Node3D
	_check(is_instance_valid(table), "Perya table scene instantiates")
	if not is_instance_valid(table):
		quit(1)
		return
	root.add_child(table)
	await process_frame

	var visuals := table.get_node_or_null("Visuals") as PeryaVisualBuilder
	_check(is_instance_valid(visuals), "visual builder is present")
	if is_instance_valid(visuals):
		_check(visuals.color_zones.size() == 6, "exactly six physical color betting pads are built")
		_check(is_instance_valid(visuals.roll_interactable), "physical START / ROLL interaction is built")
		_check(is_instance_valid(table.get_node_or_null("Visuals/PeryaAssembly/DiceCage/Die_1")), "first physical die exists")
		_check(is_instance_valid(table.get_node_or_null("Visuals/PeryaAssembly/DiceCage/Die_2")), "second physical die exists")
		_check(is_instance_valid(table.get_node_or_null("Visuals/PeryaAssembly/DiceCage/Die_3")), "third physical die exists")
	_check(is_instance_valid(table.get("roll_interactable")), "table controller binds the roll interaction")
	var display := table.get_node_or_null("BettingTerminalDisplay")
	_check(is_instance_valid(display), "shared betting terminal controller exists")
	if is_instance_valid(display):
		_check(is_instance_valid(display.get("screen_text")), "terminal is connected to the physical screen")
		_check(is_instance_valid(display.get("profile")), "Perya terminal profile is assigned")
	var keypad_controller := table.get_node_or_null("BettingKeypad/BettingKeypadController")
	_check(is_instance_valid(keypad_controller), "shared betting keypad controller is attached")
	if is_instance_valid(keypad_controller):
		_check(bool(keypad_controller.get("selection_only")), "keypad confirmation selects a chip value without placing a bet")
		_check(not bool(keypad_controller.get("one_wager_per_player")), "multiple independent wagers per player are enabled")

	table.queue_free()
	await process_frame
	if _failed:
		push_error("PERYA TABLE SCENE FAIL")
		quit(1)
		return
	print("PERYA TABLE SCENE PASS")
	quit(0)

func _check(condition: bool, description: String) -> void:
	if not condition:
		_failed = true
		push_error("Perya table scene check failed: %s" % description)
