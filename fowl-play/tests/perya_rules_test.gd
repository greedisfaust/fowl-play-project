extends SceneTree

const Rules = preload("res://casino/tables/perya/perya_rules.gd")

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
	_check(Rules.calculate_bet_return(250, [2, 2, 5], 2) == 750, "each color bet settles independently")
	_check(is_equal_approx(Rules.theoretical_return_rate(), 199.0 / 216.0), "RTP is 92.1296%")
	_check(is_equal_approx(Rules.theoretical_house_edge(), 17.0 / 216.0), "house edge is 7.8704%")
	print("PERYA RULES PASS")
	quit(0)

func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error("Perya rules check failed: %s" % description)
		quit(1)
