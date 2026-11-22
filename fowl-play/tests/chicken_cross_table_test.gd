extends SceneTree

const ChickenCrossTable = preload("res://casino/tables/chicken_cross/chicken_cross_table.gd")
var _failed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var wallet: Node = root.get_node("CasinoWallet")
	_check_result(wallet.call("begin_run", 1000), true, "Initialize wallet for Chicken Cross table")
	var table: Node3D = ChickenCrossTable.new()
	table.set("table_id", "chicken_cross_test")
	table.set("game_id", "chicken_cross")
	root.add_child(table)
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
	if _failed:
		quit(1)
		return
	print("CHICKEN CROSS TABLE PASS")
	quit(0)

func _check_result(result: Dictionary, expected_ok: bool, label: String) -> void:
	_check(bool(result.get("ok", false)) == expected_ok, "%s (%s)" % [label, str(result.get("reason", ""))])

func _check(condition: bool, label: String) -> void:
	if not condition:
		_failed = true
		push_error("CHICKEN CROSS TABLE FAIL: " + label)
