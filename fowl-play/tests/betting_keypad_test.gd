## Headless checks for shared keypad entry and host-owned wager confirmation.
extends SceneTree

const BaseTableScript = preload("res://casino/base_table.gd")
const KeypadControllerScript = preload("res://casino/terminals/components/betting_keypad_controller.gd")
const BettingProfileScript = preload("res://casino/terminals/resources/betting_terminal_profile.gd")

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

	_check_result(controller.call("handle_button_input", &"1", 1), true, "First digit is accepted")
	_check_result(controller.call("handle_button_input", &"0", 1), true, "Second digit is accepted")
	_check(int(controller.call("get_pending_wager_amount")) == 10, "Shared amount composes digits in order")
	_check_result(controller.call("handle_button_input", &"CONFIRM", 1), false, "Below-minimum amount cannot be confirmed")
	_check(int(wallet.call("get_snapshot")["available_balance"]) == 1000, "Rejected confirmation does not reserve funds")

	_check_result(controller.call("handle_button_input", &"BACKSPACE", 1), true, "Backspace removes the last digit")
	_check(int(controller.call("get_pending_wager_amount")) == 1, "Backspace updates the pending amount")
	_check_result(controller.call("handle_button_input", &"CLEAR", 1), true, "Clear resets the shared amount")
	_check(int(controller.call("get_pending_wager_amount")) == 0, "Clear returns pending amount to zero")

	for digit: String in ["1", "0", "0"]:
		_check_result(controller.call("handle_button_input", StringName(digit), 1), true, "Player one enters wager digit %s" % digit)
	var first_result: Dictionary = controller.call("handle_button_input", &"CONFIRM", 1)
	_check_result(first_result, true, "Confirm submits the first player's wager")
	_check(int(first_result.get("wager_id", "").length()) > 0, "Successful confirmation returns a wager ID")
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
