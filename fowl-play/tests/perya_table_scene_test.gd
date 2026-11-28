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
		for zone in visuals.color_zones:
			_check(zone.collision_layer == 2, "color pad uses the shared device collision layer")
			_check(is_instance_valid(zone.get_parent().get_node_or_null("Interactable")), "each color pad has a focusable Interactable")
		for die_index in range(3):
			var die := table.get_node_or_null("Visuals/PeryaAssembly/DiceCage/Die_%d" % (die_index + 1)) as Node3D
			_check(is_instance_valid(die), "physical die %d exists" % (die_index + 1))
			if is_instance_valid(die):
				var face_count := 0
				for face in die.get_children():
					if str(face.name).begins_with("Face_"):
						face_count += 1
				_check(face_count == 6, "die %d has all six color faces" % (die_index + 1))
	_check(is_instance_valid(table.get("roll_interactable")), "table controller binds the roll interaction")
	if is_instance_valid(visuals):
		var stack_anchor := visuals.color_zones[0].get_parent().get_node("ChipStacks") as Node3D
		var occupied_slots: Dictionary = {}
		for peer_id in [1, 5, 7, 9]:
			visuals.add_or_update_chip_stack(0, peer_id, "PLAYER %d" % peer_id, Color("#42a5f5"), 1, 100)
			var stack := stack_anchor.get_node("PlayerStack_%d" % peer_id) as Node3D
			var slot_key := str(snappedf(stack.position.x, 0.001))
			occupied_slots[slot_key] = true
			_check(stack.get_node_or_null("ChipStack") is MultiMeshInstance3D, "chip stack uses a MultiMesh")
			_check(stack.get_node_or_null("PlayerColorRims") is MultiMeshInstance3D, "player-color rim uses a MultiMesh")
		_check(occupied_slots.size() == 4, "non-consecutive peer IDs receive distinct chip stack positions")
	_check(table.has_method("_rpc_request_selected_wager"), "client keypad selections are validated and routed through the host")
	_check(table.has_method("_rpc_request_color_bet"), "client color wagers are validated and routed through the host")
	_check(table.has_method("_rpc_request_start_roll"), "client roll requests are validated and routed through the host")
	if is_instance_valid(visuals):
		table.set("_rolling", true)
		table.call("_update_terminal_status")
		for zone in visuals.color_zones:
			var interactable := zone.get_parent().get_node_or_null("Interactable") as Interactable
			_check(is_instance_valid(interactable) and not interactable.enabled, "color pad locks during a dice roll")
		table.set("_rolling", false)
		table.call("_update_terminal_status")
		for zone in visuals.color_zones:
			var interactable := zone.get_parent().get_node_or_null("Interactable") as Interactable
			_check(is_instance_valid(interactable) and interactable.enabled, "color pad reopens after the dice roll")
	var proximity := table.get_node_or_null("ProximityArea") as Area3D
	_check(is_instance_valid(proximity) and proximity.collision_mask == 16, "proximity sensor detects the healthy-player collision layer")
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
