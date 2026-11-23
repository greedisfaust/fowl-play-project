extends SceneTree

const ChickenCrossTable = preload("res://casino/tables/chicken_cross/chicken_cross_table.gd")
var _failed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var wallet: Node = root.get_node("CasinoWallet")
	_check_result(wallet.call("begin_run", 1000), true, "Initialize wallet for Chicken Cross table")
	_test_single_player_round(wallet)
	_test_multi_player_round(wallet)
	_test_duplicate_bettor_rejection(wallet)
	if _failed:
		quit(1)
		return
	print("CHICKEN CROSS TABLE PASS")
	quit(0)

func _test_single_player_round(wallet: Node) -> void:
	_check_result(wallet.call("begin_run", 1000), true, "Reset wallet for single-player table test")
	var table: Node3D = _create_table("chicken_cross_single_test")
	_check_result(table.call("enter_proximity", 1), true, "Host enters table proximity")
	_check_result(table.call("open_round", 1), true, "Host opens Chicken Cross round")
	_check_result(table.call("join_table", 1), true, "Host joins Chicken Cross round")
	var wager: Dictionary = table.call("place_wager", 1, 100, {})
	var wager_id: String = str(wager.get("wager_id", ""))
	_check_result(wager, true, "Host places Chicken Cross wager")
	_check(int(table.get("state")) == 1, "Confirmed wager leaves Chicken Cross OPEN until the player crosses")
	var cross_result: Dictionary = table.call("request_cross")
	_check_result(cross_result, true, "First Cross locks the wager, starts the round, and advances the chicken")
	_check(int(table.get("state")) == 2 or int(table.get("state")) == 0, "First Cross starts gameplay; an immediate loss may settle the round")
	if bool(cross_result.get("failed", false)):
		_check(str(wallet.call("get_wager", wager_id)["status"]) == "settled", "A failed chicken settles its wager immediately")
	else:
		_check(int(table.call("get_player_state", 1)["tile"]) == 1, "Cross advances the requesting chicken")
		var cleanup: Dictionary = table.call("request_day_end_cleanup", "casino_timer_expired")
		_check_result(cleanup, true, "Day-end requests automatic Chicken Cross resolution")
		var settled_wager: Dictionary = wallet.call("get_wager", wager_id)
		_check(str(settled_wager["status"]) == "settled", "Day-end automatically settles locked wager")
		_check(int(settled_wager["return_amount"]) == 150, "Day-end cashes out tile-1 chicken at 1.5x")
	var available: int = int(wallet.call("get_snapshot")["available_balance"])
	_check(available == 900 or available == 1050, "Wallet reflects the random tile-1 outcome")
	_check(str(table.get("current_round_id")) == "", "Completed round clears its round ID")
	table.queue_free()

func _test_multi_player_round(wallet: Node) -> void:
	_check_result(wallet.call("begin_run", 1000), true, "Reset wallet for multi-player table test")
	var table: Node3D = _create_table("chicken_cross_multi_test")
	for peer_id: int in [1, 2]:
		_check_result(table.call("enter_proximity", peer_id), true, "Peer %d enters table proximity" % peer_id)
	_check_result(table.call("open_round", 1), true, "Host opens multi-player Chicken Cross round")
	for peer_id: int in [1, 2]:
		_check_result(table.call("join_table", peer_id), true, "Peer %d joins Chicken Cross" % peer_id)
	_check_result(table.call("place_wager", 1, 100, {}), true, "Peer 1 reserves their own wager")
	_check_result(table.call("place_wager", 2, 200, {}), true, "Peer 2 reserves their own wager")
	var ready_states: Dictionary = table.get("_round_player_states")
	_check(ready_states.has(1) and ready_states.has(2), "Each successful wager publishes an individual ready chicken state")
	var ready_lines: Array[String] = table.call("get_round_player_display_lines")
	_check(ready_lines.size() == 2, "The multiplayer scoreboard lists both wagered players before the round starts")
	_check(ready_lines[0].contains("RED") and ready_lines[1].contains("ORANGE"), "The scoreboard identifies each chicken by its assigned player color")
	_check_result(table.call("start_round", 1), true, "Host locks both player wagers")
	var model: RefCounted = table.get("_round_model") as RefCounted
	_check(model != null, "Starting a round creates the Chicken Cross model")
	if model != null:
		_check_result(model.call("advance", 1, 0.50), true, "Peer 1 safely advances using an independent roll")
		_check_result(model.call("advance", 2, 0.01), true, "Peer 2 independently fails their tile")
		_check(int(model.call("get_player", 1)["tile"]) == 1, "Peer 1 progress is retained independently")
		_check(str(model.call("get_player", 2)["status"]) == "failed", "Peer 2 failure does not alter peer 1")
		_check_result(model.call("cash_out", 1), true, "Peer 1 cashes out without affecting peer 2")
		table.call("_try_settle_completed_round")
	var wager_one: Dictionary = wallet.call("get_wager", "W00000001")
	var wager_two: Dictionary = wallet.call("get_wager", "W00000002")
	_check(str(wager_one.get("status", "")) == "settled", "Peer 1 wager settles")
	_check(str(wager_two.get("status", "")) == "settled", "Peer 2 wager settles")
	_check(int(wager_one.get("return_amount", 0)) == 150, "Peer 1 receives their own 1.5x gross return")
	_check(int(wager_two.get("return_amount", -1)) == 0, "Peer 2 receives zero after failure")
	_check(int(wallet.call("get_snapshot")["available_balance"]) == 850, "Shared wallet receives only the resolved gross return")
	_check(int(table.get("state")) == 0 and str(table.get("current_round_id")) == "", "Settled multiplayer round returns the table to IDLE")
	table.queue_free()

func _test_duplicate_bettor_rejection(wallet: Node) -> void:
	_check_result(wallet.call("begin_run", 1000), true, "Reset wallet for duplicate-bettor test")
	var table: Node3D = _create_table("chicken_cross_duplicate_test")
	_check_result(table.call("enter_proximity", 1), true, "Peer enters duplicate-bettor test table")
	_check_result(table.call("open_round", 1), true, "Open duplicate-bettor test round")
	_check_result(table.call("join_table", 1), true, "Peer joins duplicate-bettor test round")
	_check_result(table.call("place_wager", 1, 100, {}), true, "First wager is reserved")
	_check_result(table.call("place_wager", 1, 50, {}), true, "Wallet ledger can record a second distinct wager")
	var start_result: Dictionary = table.call("start_round", 1)
	_check_result(start_result, false, "Chicken Cross rejects multiple active wagers from one player")
	_check(int(table.get("state")) == 1, "Rejected start leaves the table OPEN")
	_check(int(wallet.call("get_snapshot")["available_balance"]) == 850, "Rejected start does not lock or alter reserved stakes")
	_check_result(table.call("cancel_open_round"), true, "Invalid open round can be safely cancelled")
	_check(int(wallet.call("get_snapshot")["available_balance"]) == 1000, "Cancelling rejected round refunds both reserved wagers")
	table.queue_free()

func _create_table(test_table_id: String) -> Node3D:
	var table: Node3D = ChickenCrossTable.new()
	table.set("table_id", test_table_id)
	table.set("game_id", "chicken_cross")
	root.add_child(table)
	return table

func _check_result(result: Dictionary, expected_ok: bool, label: String) -> void:
	_check(bool(result.get("ok", false)) == expected_ok, "%s (%s)" % [label, str(result.get("reason", ""))])

func _check(condition: bool, label: String) -> void:
	if not condition:
		_failed = true
		push_error("CHICKEN CROSS TABLE FAIL: " + label)
