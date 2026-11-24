## Integration checks for independent Egg Plinko wagers and host settlement.
extends SceneTree

const TableScene: PackedScene = preload("res://casino/tables/egg_plinko/egg_plinko_table.tscn")
var _failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var wallet: Node = root.get_node("CasinoWallet")
	var day_manager: Node = root.get_node("CasinoDayManager")
	_check_result(wallet.call("begin_run", 10000), true, "Initialize shared wallet")
	_check_result(day_manager.call("begin_casino_day", 1, 10000), true, "Start quota for the Plinko test")

	var table: Node3D = TableScene.instantiate() as Node3D
	table.set("egg_flight_duration", 0.15)
	table.set("quota_safety_bias", 0.15)
	root.add_child(table)
	await process_frame
	var display: Node = table.get_node("BettingTerminalDisplay")
	var profile: Resource = display.get("profile")
	profile.set("maximum_wager", 20000)

	_check_result(table.call("enter_proximity", 1), true, "Player enters Plinko proximity")
	var limits: Dictionary = table.call("get_wager_limits")
	_check(int(limits.get("safety_reserve", 0)) == 1125, "Safety reserve follows the live quota gap and 15% bias")
	_check(int(limits.get("maximum", 0)) == 8875, "Dynamic maximum preserves the quota safety reserve")
	var keypad: Node = table.get_node("BettingKeypad/BettingKeypadController")
	for digit: String in ["1", "0", "0", "0"]:
		_check_result(keypad.call("handle_button_input", StringName(digit), 1), true, "Player enters selected wager digit %s" % digit)
	_check_result(keypad.call("handle_button_input", &"CONFIRM", 1), true, "Confirm stores the selected amount without spending it")
	_check(table.call("get_selected_wager", 1) == 1000, "Confirmed amount becomes the player's selected wager")
	_check(int(wallet.call("get_snapshot")["available_balance"]) == 10000, "Selecting a wager does not reserve or spend money")

	var first_drop: Dictionary = table.call("_handle_plinko_drop", 1)
	_check_result(first_drop, true, "First Plinko press launches an egg")
	_check(int(wallet.call("get_snapshot")["available_balance"]) == 9000, "First press spends the full selected wager")
	keypad.call("handle_button_input", &"CLEAR", 1)
	for digit: String in ["5", "0", "0"]:
		keypad.call("handle_button_input", StringName(digit), 1)
	_check_result(keypad.call("handle_button_input", &"CONFIRM", 1), true, "Player changes selected wager while an egg is airborne")
	_check(table.call("get_selected_wager", 1) == 500, "The player's new selected wager is stored independently")
	var second_drop: Dictionary = table.call("_handle_plinko_drop", 1)
	_check_result(second_drop, true, "Second Plinko press launches another independent egg")
	_check(int(wallet.call("get_snapshot")["available_balance"]) == 8500, "Second press spends the new full wager without splitting")
	var active_records: Array[Dictionary] = table.call("get_active_egg_records")
	_check(active_records.size() == 2, "Both eggs remain active simultaneously")
	if active_records.size() == 2:
		_check(int(active_records[0].get("stake", 0)) == 1000, "Changing the selected wager does not alter the first egg")
		_check(int(active_records[1].get("stake", 0)) == 500, "The second egg uses the newly selected wager")
		_check(int(active_records[0].get("peer_id", 0)) == 1 and int(active_records[1].get("peer_id", 0)) == 1, "Each egg retains its originating player attribution")
		_check(str(active_records[0].get("wager_id", "")) != str(active_records[1].get("wager_id", "")), "Every egg receives a unique wallet wager ID")

	await create_timer(0.45).timeout
	_check(table.call("get_active_egg_records").is_empty(), "Both egg flights complete and are removed from the active list")
	_check(int(wallet.call("get_snapshot")["reserved_total"]) == 0, "Every airborne wager settles exactly once")
	var first_wager: Dictionary = wallet.call("get_wager", str(first_drop.get("wager_id", "")))
	var second_wager: Dictionary = wallet.call("get_wager", str(second_drop.get("wager_id", "")))
	_check(str(first_wager.get("status", "")) == "settled", "First egg's independent wallet round settles")
	_check(str(second_wager.get("status", "")) == "settled", "Second egg's independent wallet round settles")

	_check_result(keypad.call("handle_button_input", &"MIN", 1), true, "Select the minimum wager for day-end cleanup test")
	_check_result(keypad.call("handle_button_input", &"CONFIRM", 1), true, "Confirm the cleanup-test wager")
	var cleanup_drop: Dictionary = table.call("_handle_plinko_drop", 1)
	_check_result(cleanup_drop, true, "Launch an egg before casino cleanup")
	var cleanup_result: Dictionary = table.call("request_day_end_cleanup", "test_day_end")
	_check_result(cleanup_result, true, "Casino cleanup settles airborne Plinko eggs")
	_check(int(cleanup_result.get("settled_count", 0)) == 1, "Cleanup settles the in-flight egg immediately")
	_check(table.call("get_active_egg_records").is_empty(), "Day-end cleanup clears active egg visuals")
	var cleanup_wager: Dictionary = wallet.call("get_wager", str(cleanup_drop.get("wager_id", "")))
	_check(str(cleanup_wager.get("status", "")) == "settled", "Day-end cleanup preserves the individual wallet settlement")
	_check(int(wallet.call("get_snapshot")["reserved_total"]) == 0, "Day-end cleanup leaves no locked Plinko stakes")

	table.queue_free()
	if _failed:
		quit(1)
		return
	print("EGG PLINKO TABLE PASS")
	quit(0)


func _check_result(result: Dictionary, expected_ok: bool, label: String) -> void:
	if bool(result.get("ok", false)) != expected_ok:
		_fail("%s: expected ok=%s, got %s (%s)" % [label, str(expected_ok), str(result.get("ok", false)), str(result.get("reason", ""))])


func _check(condition: bool, label: String) -> void:
	if not condition:
		_fail(label)


func _fail(message: String) -> void:
	_failed = true
	push_error("EGG PLINKO TABLE FAIL: " + message)
