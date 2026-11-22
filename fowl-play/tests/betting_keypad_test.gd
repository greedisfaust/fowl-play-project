## Headless checks for shared keypad entry and host-owned wager confirmation.
extends SceneTree

const BaseTableScript = preload("res://casino/base_table.gd")
const KeypadControllerScript = preload("res://casino/terminals/components/betting_keypad_controller.gd")
const BettingProfileScript = preload("res://casino/terminals/resources/betting_terminal_profile.gd")
const BettingDisplayScript = preload("res://casino/terminals/display/betting_terminal_display.gd")
const PlayerIdentityScript = preload("res://core/player_identity.gd")

var _failed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var wallet: Node = root.get_node("CasinoWallet")
	_check_result(wallet.call("begin_run", 1000), true, "Initialize shared wallet")

	var table: Node3D = BaseTableScript.new()
	table.set("table_id", "keypad_test_table")
	table.set("game_id", "keypad_test_game")
	table.set("max_participants", 2)
	root.add_child(table)
	_check_result(table.call("enter_proximity", 1), true, "First player enters keypad proximity")
	_check_result(table.call("enter_proximity", 2), true, "Second player enters keypad proximity")

	var profile: Resource = BettingProfileScript.new()
	profile.set("minimum_wager", 50)
	profile.set("maximum_wager", 500)
	var controller: Node = KeypadControllerScript.new()
	controller.set("table", table)
	controller.set("profile", profile)
	controller.set("one_wager_per_player", true)
	root.add_child(controller)

	_check_result(controller.call("handle_button_input", &"MIN", 0), true, "Offline peer zero is normalized for local keypad input")
	_check_result(controller.call("handle_button_input", &"CLEAR", 0), true, "Offline local keypad input can clear its pending amount")
	_check_result(controller.call("handle_button_input", &"MIN", 1), true, "MIN preset selects the profile minimum")
	_check(int(controller.call("get_pending_wager_amount")) == 50, "MIN preset selects 50")
	_check_result(controller.call("handle_button_input", &"1/4", 1), true, "Quarter preset is accepted")
	_check(int(controller.call("get_pending_wager_amount")) == 250, "Quarter preset selects one quarter of available funds")
	_check_result(controller.call("handle_button_input", &"1/2", 1), true, "Half preset is accepted")
	_check(int(controller.call("get_pending_wager_amount")) == 500, "Half preset selects one half of available funds")
	_check_result(controller.call("handle_button_input", &"MAX", 1), true, "MAX preset is accepted")
	_check(int(controller.call("get_pending_wager_amount")) == 500, "MAX preset respects the configured table maximum")
	controller.call("handle_button_input", &"CLEAR", 1)

	var display: Node = BettingDisplayScript.new()
	display.set("table", table)
	display.set("profile", profile)

	_check_result(controller.call("handle_button_input", &"1", 1), true, "First digit is accepted")
	_check_result(controller.call("handle_button_input", &"0", 1), true, "Second digit is accepted")
	_check(int(controller.call("get_pending_wager_amount")) == 10, "Shared amount composes digits in order")
	_check_result(controller.call("handle_button_input", &"CONFIRM", 1), false, "Below-minimum amount cannot be confirmed")
	_check(int(wallet.call("get_snapshot")["available_balance"]) == 1000, "Rejected confirmation does not reserve funds")

	_check_result(controller.call("handle_button_input", &"CLEAR", 1), true, "Clear invalid amount before maximum test")
	for digit: String in ["6", "0", "0"]:
		controller.call("handle_button_input", StringName(digit), 1)
	_check_result(controller.call("handle_button_input", &"CONFIRM", 1), false, "Above-maximum amount cannot be confirmed")
	_check(int(wallet.call("get_snapshot")["available_balance"]) == 1000, "Above-maximum rejection does not reserve funds")

	profile.set("maximum_wager", 2000)
	controller.call("handle_button_input", &"CLEAR", 1)
	for digit: String in ["1", "0", "0", "1"]:
		controller.call("handle_button_input", StringName(digit), 1)
	_check_result(controller.call("handle_button_input", &"CONFIRM", 1), false, "Insufficient shared funds cannot be confirmed")
	_check(int(wallet.call("get_snapshot")["available_balance"]) == 1000, "Insufficient-funds rejection does not reserve funds")
	profile.set("maximum_wager", 500)

	_check_result(controller.call("handle_button_input", &"CLEAR", 1), true, "Clear pending amount before backspace test")
	controller.call("handle_button_input", &"1", 1)
	controller.call("handle_button_input", &"0", 1)
	_check_result(controller.call("handle_button_input", &"BACKSPACE", 1), true, "Backspace removes the last digit")
	_check(int(controller.call("get_pending_wager_amount")) == 1, "Backspace updates the pending amount")
	_check_result(controller.call("handle_button_input", &"CLEAR", 1), true, "Clear resets the shared amount")
	_check(int(controller.call("get_pending_wager_amount")) == 0, "Clear returns pending amount to zero")

	for digit: String in ["1", "0", "0"]:
		_check_result(controller.call("handle_button_input", StringName(digit), 1), true, "Player one enters wager digit %s" % digit)
	var first_result: Dictionary = controller.call("handle_button_input", &"CONFIRM", 1)
	_check_result(first_result, true, "Confirm submits the first player's wager")
	_check(not str(first_result.get("wager_id", "")).is_empty(), "Successful confirmation returns a wager ID")
	_check(int(controller.call("get_pending_wager_amount")) == 0, "Successful confirmation resets the pending amount")
	_check(int(wallet.call("get_snapshot")["available_balance"]) == 900, "First confirmation reserves shared funds")
	var first_wagers: Array[Dictionary] = table.call("get_round_wagers")
	_check(first_wagers.size() == 1 and int(first_wagers[0].get("peer_id", 0)) == 1, "First confirmer is recorded as the bettor")

	for digit: String in ["5", "0"]:
		controller.call("handle_button_input", StringName(digit), 2)
	var second_result: Dictionary = controller.call("handle_button_input", &"CONFIRM", 2)
	_check_result(second_result, true, "Second player can edit the shared amount and confirm their own wager")
	_check(int(wallet.call("get_snapshot")["available_balance"]) == 850, "Second confirmation reserves from the same shared wallet")
	var all_wagers: Array[Dictionary] = table.call("get_round_wagers")
	_check(all_wagers.size() == 2, "Both players' confirmed wagers are recorded")
	_check(int(all_wagers[1].get("peer_id", 0)) == 2, "Second confirmer is recorded as the second bettor")

	for digit: String in ["7", "5"]:
		controller.call("handle_button_input", StringName(digit), 1)
	var duplicate_result: Dictionary = controller.call("handle_button_input", &"CONFIRM", 1)
	_check_result(duplicate_result, false, "Chicken Cross rejects a second active wager from the same player")
	_check(int(wallet.call("get_snapshot")["available_balance"]) == 850, "Rejected duplicate confirmation does not reserve funds")
	_check(int(controller.call("get_pending_wager_amount")) == 75, "Rejected confirmation preserves the pending amount for correction")

	controller.call("handle_button_input", &"CLEAR", 1)
	for digit: String in ["1", "0", "0", "0", "0", "0", "0", "0", "0", "1"]:
		_check_result(controller.call("handle_button_input", StringName(digit), 1), true, "Large wager digit %s is accepted" % digit)
	_check(int(controller.call("get_pending_wager_amount")) == 1000000001, "Keypad accepts wager amounts greater than one billion")
	_check_result(controller.call("handle_button_input", &"CONFIRM", 1), false, "Large wager still respects configured table maximum")

	controller.call("handle_button_input", &"CLEAR", 1)
	for digit: String in ["9", "2", "2", "3", "3", "7", "2", "0", "3", "6", "8", "5", "4", "7", "7", "5", "8", "0", "7"]:
		_check_result(controller.call("handle_button_input", StringName(digit), 1), true, "64-bit maximum digit %s is accepted" % digit)
	_check(int(controller.call("get_pending_wager_amount")) == 9223372036854775807, "Keypad supports the signed 64-bit maximum")
	_check_result(controller.call("handle_button_input", &"BACKSPACE", 1), true, "Backspace returns to the largest 18-digit prefix")
	_check_result(controller.call("handle_button_input", &"8", 1), false, "Keypad rejects an amount above the signed 64-bit maximum")

	var formatted_billion: String = str(display.call("_format_compact_money", 1000000000))
	var formatted_trillion: String = str(display.call("_format_compact_money", 1000000000000))
	var formatted_quintillion: String = str(display.call("_format_compact_money", 1230000000000000000))
	_check(formatted_billion == "1B$", "Billion denomination remains readable")
	_check(formatted_trillion == "1T$", "Trillion denomination is supported")
	_check(formatted_quintillion == "1.23Qi$", "Quintillion denomination is supported")
	_check(bool(display.call("_is_pending_wager_valid", 50, 500, 850)) == false, "Zero wager is never marked valid")
	display.set("_pending_wager_amount", 100)
	_check(bool(display.call("_is_pending_wager_valid", 50, 500, 850)), "In-range affordable wager is marked valid")
	_check(not bool(display.call("_is_pending_wager_valid", 50, 500, 99)), "Unaffordable wager is marked invalid")

	var network: Node = root.get_node("Network")
	var identities: Dictionary = network.get("player_identities")
	identities[1] = PlayerIdentityScript.new(1, "RED", 0)
	network.set("player_identities", identities)
	display.set("_network", network)
	var occupancy_rows: Array[String] = display.call("_build_player_rows")
	_check(not occupancy_rows.is_empty() and occupancy_rows[0] == "2 / 2 PLAYERS", "Terminal occupancy counts players currently inside its proximity")
	_check(display.call("_get_player_color", 1) == Color("#ef5350"), "Confirmed player row uses the assigned identity color")
	var player_row_colors: Dictionary = display.get("_player_row_colors")
	_check(player_row_colors.has(1) and player_row_colors.has(2), "Every confirmed player row receives its own identity color")
	display.free()
	controller.queue_free()
	table.queue_free()
	if _failed:
		quit(1)
		return
	print("BETTING KEYPAD PASS")
	quit(0)

func _check_result(result: Dictionary, expected_ok: bool, label: String) -> void:
	if bool(result.get("ok", false)) != expected_ok:
		_fail("%s: expected ok=%s, got %s (%s)" % [label, str(expected_ok), str(result.get("ok", false)), str(result.get("reason", ""))])

func _check(condition: bool, label: String) -> void:
	if not condition:
		_fail(label)

func _fail(message: String) -> void:
	_failed = true
	push_error("BETTING KEYPAD FAIL: %s" % message)
