## Deterministic rule and payout checks for Egg Plinko.
extends SceneTree

const Rules = preload("res://casino/tables/egg_plinko/egg_plinko_rules.gd")
var _failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check(Rules.ROW_COUNT == 12, "Plinko board uses twelve peg rows")
	_check(Rules.SLOT_MULTIPLIERS.size() == 13, "Twelve rows produce thirteen payout slots")
	_check(Rules.SLOT_MULTIPLIERS[0] == 24.0, "Left edge slot carries the 24x jackpot")
	_check(Rules.SLOT_MULTIPLIERS[1] == 12.0, "Second slot carries the 12x jackpot")
	_check(Rules.SLOT_MULTIPLIERS[6] == 0.4, "Center slot carries the lowest multiplier")
	_check(Rules.SLOT_MULTIPLIERS[12] == 24.0, "Right edge slot mirrors the left edge")
	_check(Rules.SLOT_MULTIPLIERS[0] == Rules.SLOT_MULTIPLIERS[12] and Rules.SLOT_MULTIPLIERS[1] == Rules.SLOT_MULTIPLIERS[11], "Multiplier schedule is symmetric")

	var first_rng := RandomNumberGenerator.new()
	first_rng.seed = 928374
	var second_rng := RandomNumberGenerator.new()
	second_rng.seed = 928374
	var first_path: Dictionary = Rules.build_path(first_rng)
	var second_path: Dictionary = Rules.build_path(second_rng)
	var path_a: PackedVector3Array = first_path["path"]
	var path_b: PackedVector3Array = second_path["path"]
	_check(path_a.size() == Rules.ROW_COUNT * 3 + 2, "Every egg receives a complete path through all peg rows")
	_check(path_a == path_b, "The same host seed reproduces the same path")
	_check(int(first_path["slot_index"]) >= 0 and int(first_path["slot_index"]) < Rules.SLOT_MULTIPLIERS.size(), "Landing slot remains in range")
	_check(is_equal_approx(float(first_path["multiplier"]), Rules.SLOT_MULTIPLIERS[int(first_path["slot_index"])]), "Landing multiplier matches the resolved slot")

	_check(Rules.calculate_gross_return(100, 0.4) == 40, "A 0.4x landing returns 40 from a 100 stake")
	_check(Rules.calculate_gross_return(100, 1.5) == 150, "A 1.5x landing returns 150 from a 100 stake")
	_check(Rules.calculate_gross_return(100, 24.0) == 2400, "A 24x jackpot returns 2400 from a 100 stake")
	_check(Rules.calculate_gross_return(1, 0.8) == 0, "Fractional gross returns round down")
	_check(Rules.calculate_gross_return(0, 8.0) == 0, "Zero stake cannot produce a payout")

	if _failed:
		push_error("EGG PLINKO RULES FAIL")
		quit(1)
		return
	print("EGG PLINKO RULES PASS")
	quit(0)


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failed = true
		push_error("FAIL: " + label)
