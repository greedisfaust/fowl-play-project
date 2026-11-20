## Headless lifecycle checks for the generic BaseTable controller.
extends SceneTree

const BaseTableScript = preload("res://casino/base_table.gd")

var _failed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var wallet: Node = root.get_node("CasinoWallet")
	_check_result(wallet.call("begin_run", 1000), true, "Initialize shared wallet")
	var table: Node3D = BaseTableScript.new()
	table.set("table_id", "test_table")
	table.set("game_id", "test_game")
	table.set("max_participants", 2)
	root.add_child(table)

	_check_result(table.call("enter_proximity", 1), true, "First player enters proximity")
	_check_result(table.call("enter_proximity", 2), true, "Second player enters proximity")
	_check_result(table.call("open_round", 1), true, "Nearby player opens a round")
	var round_id: String = str(table.get("current_round_id"))
	_check(not round_id.is_empty(), "Table creates a unique round ID")
	_check_result(table.call("join_table", 1), true, "First player joins")
	_check_result(table.call("join_table", 2), true, "Second player joins")
	_check_result(table.call("join_table", 2), true, "Joining twice is idempotent")
	_check_result(table.call("enter_proximity", 3), true, "Third player enters proximity")
	_check_result(table.call("join_table", 3), false, "Participant capacity is enforced")

	var first_wager: Dictionary = table.call("place_wager", 1, 100, {"selection": "A"})
	var first_wager_id: String = str(first_wager.get("wager_id", ""))
	_check_result(first_wager, true, "First participant confirms a wager")
	var second_wager: Dictionary = table.call("place_wager", 2, 200, {"selection": "B"})
	var second_wager_id: String = str(second_wager.get("wager_id", ""))
	_check_result(second_wager, true, "Second participant confirms a wager")
	_check_result(table.call("update_wager", 2, first_wager_id, 150, {}), false, "A player cannot edit another player's wager")
	_check(int(wallet.call("get_snapshot")["available_balance"]) == 700, "Both wagers reserve from shared funds")

	var exit_result: Dictionary = table.call("exit_proximity", 2)
	_check_result(exit_result, true, "Leaving before start removes the participant")
	_check(int(exit_result.get("refunded_total", 0)) == 200, "Leaving before start refunds that player's stake")
	_check(str(wallet.call("get_wager", second_wager_id)["status"]) == "refunded", "Proximity refund updates the wager ledger")
	_check(int(wallet.call("get_snapshot")["available_balance"]) == 900, "Proximity refund restores shared available funds")

	_check_result(table.call("enter_proximity", 2), true, "Starter returns to proximity")
	_check_result(table.call("start_round", 2), true, "Nearby non-participant can start the round")
	_check(int(wallet.call("get_wager", first_wager_id)["status"]) == "locked", "Starting locks remaining wagers")
	_check_result(table.call("withdraw_wager", 1, first_wager_id), false, "Locked wager cannot be withdrawn")

	var post_start_exit: Dictionary = table.call("exit_proximity", 1)
	_check_result(post_start_exit, true, "Participant can leave after round start")
	_check(bool(post_start_exit.get("auto_resolve_required", false)), "Leaving after start requests game auto-resolution")
	var participants: Array[Dictionary] = table.call("get_participants")
	_check(str(participants[0].get("status", "")) == "left_after_start", "Post-start departure remains visible in participant state")

	_check_result(table.call("begin_resolution"), true, "Running round enters resolution")
	_check_result(table.call("settle_round", {first_wager_id: 150}), true, "Game settlement returns to shared wallet")
	_check(str(table.get("state")) == "0" or int(table.get("state")) == 0, "Settled table returns to idle")
	_check(int(wallet.call("get_snapshot")["available_balance"]) == 1050, "Gross payout is credited to shared wallet")
	_check(table.get("current_round_id") == "", "Settled table clears its active round ID")

	_check_result(table.call("open_round", 2), true, "Table can open another round")
	_check_result(table.call("join_table", 2), true, "Player joins the next round")
	_check_result(table.call("place_wager", 2, 50, {}), true, "Player reserves another wager")
	_check_result(table.call("cancel_open_round", 2), true, "Open round can be cancelled")
	_check(int(wallet.call("get_snapshot")["available_balance"]) == 1050, "Cancelling an open round refunds its wager")
	_check(int(table.get("state")) == 0, "Cancelled table returns to idle")

	_check_result(table.call("open_round", 2), true, "Table opens a round for the no-wager start check")
	_check_result(table.call("start_round", 2), false, "Round without active wagers cannot start")
	_check(int(table.get("state")) == 1, "Rejected start leaves the round open")
	_check_result(table.call("cancel_open_round", 2), true, "Empty open round can be cancelled")

	table.queue_free()
	if _failed:
		quit(1)
		return
	print("BASE TABLE PASS")
	quit(0)

func _check_result(result: Dictionary, expected_ok: bool, label: String) -> void:
	if bool(result.get("ok", false)) != expected_ok:
		_fail("%s: expected ok=%s, got %s (%s)" % [label, str(expected_ok), str(result.get("ok", false)), str(result.get("reason", ""))])

func _check(condition: bool, label: String) -> void:
	if not condition:
		_fail(label)

func _fail(message: String) -> void:
	_failed = true
	push_error("BASE TABLE FAIL: %s" % message)
