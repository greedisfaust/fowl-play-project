## Deterministic rule, multi-bet settlement, and payout checks for Perya.
extends SceneTree

const Rules = preload("res://casino/tables/perya/perya_rules.gd")
var _failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_check(Rules.is_valid_dice([0, 1, 2]), "three valid colors accepted")
	_check(not Rules.is_valid_dice([0, 1]), "wrong dice count rejected")
	_check(not Rules.is_valid_dice([0, 1, 6]), "out-of-range color rejected")
	_check(Rules.count_matches([0, 0, 0], 0) == 3, "three matching dice")
	_check(Rules.count_matches([0, 1, 0], 0) == 2, "two matching dice")
	_check(Rules.count_matches([0, 1, 2], 0) == 1, "one matching die")
	_check(Rules.count_matches([1, 2, 3], 0) == 0, "no matching dice")
	_check(Rules.calculate_gross_return(100, 0) == 0, "no-match loses stake")
	_check(Rules.calculate_gross_return(100, 1) == 200, "one match returns 2x gross")
	_check(Rules.calculate_gross_return(100, 2) == 300, "two matches returns 3x gross")
	_check(Rules.calculate_gross_return(100, 3) == 400, "three matches returns 4x gross")
	_check(Rules.calculate_bet_return(250, [2, 2, 5], 2) == 750, "two matching dice return 3x")

	var wagers: Array[Dictionary] = [
		{"wager_id": "W1", "stake": 100, "status": "locked", "payload": {"color_index": 0}},
		{"wager_id": "W2", "stake": 250, "status": "locked", "payload": {"color_index": 0}},
		{"wager_id": "W3", "stake": 75, "status": "locked", "payload": {"color_index": 1}},
		{"wager_id": "W4", "stake": 50, "status": "locked", "payload": {"color_index": 5}},
		{"wager_id": "W5", "stake": 999, "status": "reserved", "payload": {"color_index": 0}},
	]
	var payouts: Dictionary = Rules.calculate_round_payouts(wagers, [0, 0, 2])
	_check(payouts.size() == 4, "only locked bets are settled")
	_check(int(payouts.get("W1", -1)) == 300, "first separate red bet receives its own 3x gross return")
	_check(int(payouts.get("W2", -1)) == 750, "second separate red bet receives its own 3x gross return")
	_check(int(payouts.get("W3", -1)) == 0, "non-winning color loses its stake")
	_check(int(payouts.get("W4", -1)) == 0, "another non-winning color is not refunded")
	_check(Rules.calculate_round_payouts(wagers, [0, 1]).is_empty(), "invalid dice cannot produce payouts")
	_check(is_equal_approx(Rules.theoretical_return_rate(), 199.0 / 216.0), "RTP is 92.1296%")
	_check(is_equal_approx(Rules.theoretical_house_edge(), 17.0 / 216.0), "house edge is 7.8704%")

	if _failed:
		push_error("PERYA RULES FAIL")
		quit(1)
		return
	print("PERYA RULES PASS")
	quit(0)

func _check(condition: bool, description: String) -> void:
	if not condition:
		_failed = true
		push_error("Perya rules check failed: %s" % description)
