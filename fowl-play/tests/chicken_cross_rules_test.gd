## Deterministic rules and per-player round-state checks for Chicken Cross.
extends SceneTree

const Rules = preload("res://casino/tables/chicken_cross/chicken_cross_rules.gd")
const RoundModel = preload("res://casino/tables/chicken_cross/chicken_cross_round.gd")

var _failed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check(Rules.TILE_COUNT == 12, "Chicken Cross has twelve tiles")
	_check(is_equal_approx(Rules.failure_chance_for_tile(1), 0.03), "Tile 1 failure chance is 3%")
	_check(is_equal_approx(Rules.failure_chance_for_tile(12), 0.85), "Tile 12 failure chance is 85%")
	_check(is_equal_approx(Rules.multiplier_for_tile(1), 1.5), "Tile 1 multiplier is 1.5x")
	_check(is_equal_approx(Rules.multiplier_for_tile(12), 90.0), "Tile 12 multiplier is 90x")
	_check(Rules.failure_chance_for_tile(0) < 0.0, "Invalid tile has no failure chance")
	_check(Rules.multiplier_for_tile(13) == 0.0, "Invalid tile has no multiplier")
	_check(Rules.roll_failed(1, 0.02), "Roll below the failure chance fails")
	_check(not Rules.roll_failed(1, 0.03), "Roll at the failure threshold survives")
	_check(Rules.gross_return_for_stake(100, 1) == 150, "Tile 1 returns 150 for a 100 stake")
	_check(Rules.gross_return_for_stake(100, 12) == 9000, "Tile 12 returns 9000 for a 100 stake")
	_check(Rules.gross_return_for_stake(1, 1) == 1, "Fractional gross return rounds down")
	for tile_number: int in range(2, Rules.TILE_COUNT + 1):
		_check(
			Rules.failure_chance_for_tile(tile_number) > Rules.failure_chance_for_tile(tile_number - 1),
			"Failure chance increases at tile %d" % tile_number
		)
		_check(
			Rules.multiplier_for_tile(tile_number) > Rules.multiplier_for_tile(tile_number - 1),
			"Multiplier increases at tile %d" % tile_number
		)

	var round_model: RefCounted = RoundModel.new()
	var wagers: Array[Dictionary] = [
		{"peer_id": 1, "wager_id": "W1", "stake": 100, "status": "locked"},
		{"peer_id": 2, "wager_id": "W2", "stake": 200, "status": "locked"},
		{"peer_id": 3, "wager_id": "W3", "stake": 50, "status": "locked"},
	]
	_check_result(round_model.call("begin", wagers), true, "Round accepts one locked wager per player")

	var p1_step: Dictionary = round_model.call("advance", 1, 0.50)
	var p2_step: Dictionary = round_model.call("advance", 2, 0.01)
	var p3_step: Dictionary = round_model.call("advance", 3, 0.80)
	_check(bool(p1_step.get("ok", false)) and not bool(p1_step.get("failed", true)), "Player 1 independently survives tile 1")
	_check(bool(p2_step.get("failed", false)), "Player 2 independently fails tile 1")
	_check(bool(p3_step.get("ok", false)) and not bool(p3_step.get("failed", true)), "Player 3 independently survives tile 1")
	_check(int(round_model.call("get_player", 1)["tile"]) == 1, "Player 1 progress is independent")
	_check(int(round_model.call("get_player", 2)["tile"]) == 1, "Failed player records attempted tile")
	_check(int(round_model.call("get_player", 3)["tile"]) == 1, "Player 3 progress is independent")
	_check(not bool(round_model.call("is_complete")), "Round remains active while players remain")

	var cashout: Dictionary = round_model.call("cash_out", 1)
	_check_result(cashout, true, "Player 1 can cash out independently")
	_check(int(cashout.get("gross_return", 0)) == 150, "Cash-out uses the player's own stake and tile multiplier")
	_check(bool(round_model.call("is_complete")) == false, "Round waits for the remaining active player")
	_check_result(round_model.call("cash_out", 2), false, "Failed player cannot cash out")
	_check_result(round_model.call("advance", 1, 0.50), false, "Cashed-out player cannot advance")

	var second_tile: Dictionary = round_model.call("advance", 3, 0.50)
	_check(bool(second_tile.get("ok", false)) and int(second_tile.get("tile", 0)) == 2, "Remaining player advances independently")
	_check_result(round_model.call("cash_out", 3), true, "Remaining player can cash out")
	_check(bool(round_model.call("is_complete")), "Round ends when every player has cashed out or failed")
	var payouts: Dictionary = round_model.call("build_payouts")
	_check(payouts.size() == 3, "Completed round produces one payout per wager")
	_check(int(payouts["W1"]) == 150, "Cashed-out player receives their gross return")
	_check(int(payouts["W2"]) == 0, "Failed player receives zero")
	_check(int(payouts["W3"]) == 110, "Each player's own wager determines their payout")
	_check_result(round_model.call("advance", 99, 0.50), false, "Non-participant cannot act")

	var unlocked_model: RefCounted = RoundModel.new()
	var unlocked_wagers: Array[Dictionary] = [
		{"peer_id": 9, "wager_id": "WU", "stake": 1, "status": "reserved"}
	]
	_check_result(
		unlocked_model.call("begin", unlocked_wagers),
		false,
		"Round rejects wagers that have not been locked"
	)

	var final_tile_model: RefCounted = RoundModel.new()
	var final_tile_wagers: Array[Dictionary] = [
		{"peer_id": 4, "wager_id": "W4", "stake": 10, "status": "locked"}
	]
	_check_result(final_tile_model.call("begin", final_tile_wagers), true, "Single-player final-tile test starts")
	for tile_number: int in range(1, Rules.TILE_COUNT):
		var chance: float = Rules.failure_chance_for_tile(tile_number)
		var safe_roll: float = chance
		var step: Dictionary = final_tile_model.call("advance", 4, safe_roll)
		_check(bool(step.get("ok", false)), "Safe deterministic roll accepted on tile %d" % tile_number)
	var final_step: Dictionary = final_tile_model.call("advance", 4, 0.99)
	_check(bool(final_step.get("ok", false)), "Final tile step resolves")
	_check(str(final_step.get("status", "")) == "cashed_out", "Surviving tile 12 automatically cashes out")
	_check(int(final_step.get("gross_return", 0)) == 900, "Final tile pays the 90x gross return")
	_check(bool(final_tile_model.call("is_complete")), "Final-tile success completes a solo round")

	if _failed:
		push_error("CHICKEN CROSS RULES FAIL")
		quit(1)
		return
	print("CHICKEN CROSS RULES PASS")
	quit(0)

func _check(condition: bool, label: String) -> void:
	if condition:
		return
	_failed = true
	push_error("FAIL: " + label)

func _check_result(result: Dictionary, expected_ok: bool, label: String) -> void:
	_check(bool(result.get("ok", false)) == expected_ok, "%s (%s)" % [label, str(result.get("reason", ""))])
