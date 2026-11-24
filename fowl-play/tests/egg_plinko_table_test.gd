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

	_check_result(table.call("enter_proximity", 1), true, "Player one enters Plinko proximity")
	_check_result(table.call("enter_proximity", 2), true, "Player two enters Plinko proximity")
	var limits: Dictionary = table.call("get_wager_limits")
	_check(int(limits.get("safety_reserve", 0)) == 2625, "Safety reserve protects 15% of the live quota target")
	_check(int(limits.get("maximum", 0)) == 7375, "Dynamic maximum respects the quota gap and protected reserve")
	var keypad: Node = table.get_node("BettingKeypad/BettingKeypadController")
	for digit: String in ["1", "0", "0", "0"]:
		_check_result(keypad.call("handle_button_input", StringName(digit), 1), true, "Player one enters a wager digit")
	for digit: String in ["2", "0", "0", "0"]:
		_check_result(keypad.call("handle_button_input", StringName(digit), 2), true, "Player two enters a separate wager digit")
	_check_result(keypad.call("handle_button_input", &"CONFIRM", 2), true, "Player two confirms their independent amount")
	_check(table.call("get_selected_wager", 2) == 2000, "The shared team wager updates when player two confirms")
	_check_result(keypad.call("handle_button_input", &"CONFIRM", 1), true, "Player one confirms their preserved draft")
	_check(table.call("get_selected_wager", 1) == 1000, "Player one can replace the shared team wager with their confirmed draft")
	_check(int(wallet.call("get_snapshot")["available_balance"]) == 10000, "Selecting wagers does not reserve or spend money")

	var first_drop: Dictionary = table.call("_handle_plinko_drop", 1)
	_check_result(first_drop, true, "First Plinko press launches an egg")
	_check(int(wallet.call("get_snapshot")["available_balance"]) == 9000, "First press spends the full selected wager")
	keypad.call("handle_button_input", &"CLEAR", 1)
	for digit: String in ["5", "0", "0"]:
		keypad.call("handle_button_input", StringName(digit), 1)
	_check_result(keypad.call("handle_button_input", &"CONFIRM", 1), true, "Player changes selected wager while an egg is airborne")
	_check(table.call("get_selected_wager", 1) == 500, "The new wager becomes the shared team setting for every player")
	var second_drop: Dictionary = table.call("_handle_plinko_drop", 1)
	_check_result(second_drop, true, "Second Plinko press launches another independent egg")
	_check(int(wallet.call("get_snapshot")["available_balance"]) == 8500, "Second press spends the new full wager without splitting")
	var third_drop: Dictionary = table.call("_handle_plinko_drop", 2)
	_check_result(third_drop, true, "A second player launches using the same shared team wager")
	_check(int(wallet.call("get_snapshot")["available_balance"]) == 8000, "Every player launch spends the current shared wager")
	var active_records: Array[Dictionary] = table.call("get_active_egg_records")
	_check(active_records.size() == 3, "All three eggs remain active simultaneously")
	if active_records.size() == 3:
		_check(int(active_records[0].get("stake", 0)) == 1000, "Changing the shared wager does not alter the first egg")
		_check(int(active_records[1].get("stake", 0)) == 500 and int(active_records[2].get("stake", 0)) == 500, "Upcoming eggs from either player use the same current wager")
		_check(int(active_records[0].get("peer_id", 0)) == 1 and int(active_records[1].get("peer_id", 0)) == 1 and int(active_records[2].get("peer_id", 0)) == 2, "Each egg retains its originating player attribution")
		_check(str(active_records[0].get("wager_id", "")) != str(active_records[1].get("wager_id", "")) and str(active_records[1].get("wager_id", "")) != str(active_records[2].get("wager_id", "")), "Every egg receives a unique wallet wager ID")

	await create_timer(0.55).timeout
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
