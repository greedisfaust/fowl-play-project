## Headless checks for shared-wallet reservation, editing, withdrawal, locking and settlement.
extends SceneTree

const SharedWalletScript = preload("res://casino/shared_wallet.gd")

var _failed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var wallet: Node = SharedWalletScript.new()
	root.add_child(wallet)
	_check_result(wallet.call("begin_run", 1000), true, "Initialize shared wallet")
	_check(int(wallet.call("get_snapshot")["available_balance"]) == 1000, "Initial available balance")
	_check_result(wallet.call("open_round", "blackjack_table", "round_001"), true, "Open first round")
	var locked_reserve: Dictionary = wallet.call("reserve_wager", 2, "blackjack_table", "round_001", 300, {"hand": 1})
	var locked_id: String = str(locked_reserve.get("wager_id", ""))
	_check_result(locked_reserve, true, "Reserve first player's wager")
	var editable_reserve: Dictionary = wallet.call("reserve_wager", 3, "blackjack_table", "round_001", 1, {"hand": 2})
	var editable_id: String = str(editable_reserve.get("wager_id", ""))
	_check_result(editable_reserve, true, "Reserve second player's wager")
	_check(int(wallet.call("get_snapshot")["available_balance"]) == 699, "Confirmed stakes immediately leave available funds")
	_check(int(wallet.call("get_snapshot")["reserved_total"]) == 301, "Reserved funds are tracked separately")
	_check_result(wallet.call("reserve_wager", 4, "blackjack_table", "round_001", 800, {}), false, "Concurrent overspend is rejected")
	_check(int(wallet.call("get_snapshot")["available_balance"]) == 699, "Rejected wager does not change funds")
	_check_result(wallet.call("update_wager", editable_id, 500, {"hand": 3}), true, "Increase an open wager")
	_check(int(wallet.call("get_snapshot")["available_balance"]) == 200, "Increasing stake reserves only the difference")
	_check_result(wallet.call("update_wager", editable_id, 200, {"hand": 4}), true, "Decrease an open wager")
	_check(int(wallet.call("get_snapshot")["available_balance"]) == 500, "Decreasing stake returns only the difference")
	_check_result(wallet.call("withdraw_wager", editable_id), true, "Withdraw an open wager")
	_check(int(wallet.call("get_snapshot")["available_balance"]) == 700, "Withdrawal returns the full current stake")
	_check(str(wallet.call("get_wager", editable_id)["status"]) == "refunded", "Withdrawn wager is marked refunded")
	_check_result(wallet.call("lock_round", "blackjack_table", "round_001"), true, "Lock remaining round wagers")
	_check_result(wallet.call("update_wager", editable_id, 250, {}), false, "A withdrawn wager cannot be edited")
	_check_result(wallet.call("withdraw_wager", locked_id), false, "Locked wager cannot be withdrawn")
	_check_result(wallet.call("settle_round", "blackjack_table", "round_001", {}), false, "Incomplete settlement is rejected")
	_check_result(wallet.call("settle_round", "blackjack_table", "round_001", {locked_id: 100}), true, "Settle a locked wager")
	_check(int(wallet.call("get_snapshot")["available_balance"]) == 800, "Gross return is credited to shared funds")
	_check(int(wallet.call("get_wager", locked_id)["net_result"]) == -200, "Net result is tracked per bettor")
	_check_result(wallet.call("settle_round", "blackjack_table", "round_001", {locked_id: 100}), false, "A round cannot be settled twice")

	_check_result(wallet.call("open_round", "roulette_table", "round_002"), true, "Open second round")
	var refundable: Dictionary = wallet.call("reserve_wager", 4, "roulette_table", "round_002", 150, {"bet": "red"})
	var refundable_id: String = str(refundable.get("wager_id", ""))
	_check_result(refundable, true, "Reserve a wager for an open round")
	_check_result(wallet.call("cancel_open_round", "roulette_table", "round_002"), true, "Cancel and refund an unstarted round")
	_check(int(wallet.call("get_snapshot")["available_balance"]) == 800, "Open-round cancellation restores reserved funds")
	_check(str(wallet.call("get_wager", refundable_id)["status"]) == "refunded", "Cancelled wager is marked refunded")
	_check_result(wallet.call("cancel_open_round", "roulette_table", "round_002"), false, "Cancelled round cannot be refunded twice")

	_check_result(wallet.call("open_round", "chicken_cross_table", "round_003"), true, "Open third round")
	var locked: Dictionary = wallet.call("reserve_wager", 1, "chicken_cross_table", "round_003", 200, {"lane": 2})
	var locked_id_two: String = str(locked.get("wager_id", ""))
	_check_result(locked, true, "Reserve Chicken Cross wager")
	_check_result(wallet.call("lock_round", "chicken_cross_table", "round_003"), true, "Lock Chicken Cross wager")
	_check(int(wallet.call("get_snapshot")["available_balance"]) == 600, "Locked stake remains unavailable")
	_check(int(wallet.call("get_snapshot")["reserved_total"]) == 200, "Locked stake remains tracked as reserved")
	_check_result(wallet.call("begin_run", 500), false, "Run cannot reset while a wager remains locked")
	_check_result(wallet.call("cancel_open_round", "chicken_cross_table", "round_003"), false, "Locked round cannot be force-refunded by open-round cancellation")
	_check_result(wallet.call("settle_round", "chicken_cross_table", "round_003", {locked_id_two: 0}), true, "Loss settles with zero gross return")
	_check(int(wallet.call("get_snapshot")["available_balance"]) == 600, "Loss does not return the stake")
	_check(int(wallet.call("get_snapshot")["reserved_total"]) == 0, "Settled wager is no longer reserved")
	_check_result(wallet.call("begin_run", 500), true, "Fresh run can initialize after all wagers settle")
	_check(int(wallet.call("get_snapshot")["available_balance"]) == 500, "New run starts at the requested balance")
	_check(wallet.call("get_wager", locked_id_two).is_empty(), "New run clears the previous wager ledger")
	_check_result(wallet.call("open_round", "", "bad"), false, "Empty table ID is rejected")
	_check_result(wallet.call("reserve_wager", 0, "table", "round", 1, {}), false, "Invalid bettor peer ID is rejected")
	_check_result(wallet.call("reserve_wager", 1, "table", "round", 0, {}), false, "Zero wager is rejected")
	_check_result(wallet.call("open_round", "table", "round::invalid"), false, "Round key delimiter is rejected")

	wallet.queue_free()
	if _failed:
		quit(1)
		return
	print("CASINO WALLET PASS")
	quit(0)

func _check_result(result: Dictionary, expected_ok: bool, label: String) -> void:
	if bool(result.get("ok", false)) != expected_ok:
		_fail("%s: expected ok=%s, got %s (%s)" % [label, str(expected_ok), str(result.get("ok", false)), str(result.get("reason", ""))])

func _check(condition: bool, label: String) -> void:
	if not condition:
		_fail(label)

func _fail(message: String) -> void:
	_failed = true
	push_error("CASINO WALLET FAIL: %s" % message)
