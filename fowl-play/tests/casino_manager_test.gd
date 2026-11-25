## Headless checks for casino game registration and equal-probability unique daily draws.
extends SceneTree

const CasinoGameDefinitionScript = preload("res://casino/casino_game_definition.gd")
const CasinoManagerScript = preload("res://casino/casino_manager.gd")
var _failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var manager: Node = root.get_node_or_null("CasinoManager")
	if not is_instance_valid(manager):
		_finish(false, "CasinoManager autoload was not registered.")
		return

	var initial_ids: Array[StringName] = manager.call("get_registered_game_ids")
	_check(initial_ids.size() == 3 and initial_ids.has(&"chicken_cross") and initial_ids.has(&"egg_plinko") and initial_ids.has(&"cluckpot"), "Chicken Cross, Egg Plinko, and Cluckpot are the currently registered production games")
	_check(not bool(manager.call("is_catalog_complete")), "A partial roster must not pretend it can select six from twelve")
	var premature: Dictionary = manager.call("select_games_for_day", 1, 42)
	_check(not bool(premature.get("ok", false)), "Selection is blocked until all twelve game types are registered")

	for index: int in range(9):
		var definition: Resource = CasinoGameDefinitionScript.new()
		definition.set("game_id", StringName("test_game_%02d" % index))
		definition.set("display_name", "Test Game %02d" % index)
		var scene_root: Node = Node.new()
		var test_scene: PackedScene = PackedScene.new()
		test_scene.pack(scene_root)
		scene_root.free()
		definition.set("table_scene", test_scene)
		var registration: Dictionary = manager.call("register_game", definition)
		_check(bool(registration.get("ok", false)), "A valid additional game definition registers")

	_check(bool(manager.call("is_catalog_complete")), "Exactly twelve registered game types complete the roster")
	_check(manager.call("get_registered_game_ids").size() == 12, "Catalog contains twelve unique game IDs")
	var overflow: Resource = CasinoGameDefinitionScript.new()
	overflow.set("game_id", &"thirteenth_game")
	overflow.set("display_name", "Thirteenth Game")
	var overflow_root: Node = Node.new()
	var overflow_scene: PackedScene = PackedScene.new()
	overflow_scene.pack(overflow_root)
	overflow_root.free()
	overflow.set("table_scene", overflow_scene)
	_check(not bool(manager.call("register_game", overflow).get("ok", false)), "Catalog rejects a thirteenth game type")

	var duplicate: Resource = CasinoGameDefinitionScript.new()
	duplicate.set("game_id", &"chicken_cross")
	duplicate.set("display_name", "Duplicate Chicken Cross")
	var duplicate_root: Node = Node.new()
	var duplicate_scene: PackedScene = PackedScene.new()
	duplicate_scene.pack(duplicate_root)
	duplicate_root.free()
	duplicate.set("table_scene", duplicate_scene)
	var duplicate_result: Dictionary = manager.call("register_game", duplicate)
	_check(not bool(duplicate_result.get("ok", false)), "Duplicate game IDs are rejected")

	var selected: Dictionary = manager.call("select_games_for_day", 1, 123456)
	_check(bool(selected.get("ok", false)), "A complete roster can select the daily games")
	var selected_ids: Array[StringName] = manager.call("get_selected_game_ids")
	_check(selected_ids.size() == 6, "Exactly six game types are selected")
	var unique: Dictionary = {}
	for game_id: StringName in selected_ids:
		unique[game_id] = true
		_check(is_instance_valid(manager.call("get_game_definition", game_id)), "Every selected ID resolves to a registered definition")
	_check(unique.size() == 6, "No game type is selected twice in one day")

	var unchanged: Dictionary = manager.call("select_games_for_day", 1, 999)
	_check(bool(unchanged.get("ok", false)), "Repeated request for the active day succeeds")
	_check(manager.call("get_selected_game_ids") == selected_ids, "The active day's selection cannot be rerolled")

	var next_day: Dictionary = manager.call("select_games_for_day", 2, 123456)
	_check(bool(next_day.get("ok", false)), "The next day receives a fresh selection")
	_check(int(manager.get("selected_day")) == 2, "Selection records the requested day")
	# Consecutive-day repeats are deliberately allowed; the algorithm does not exclude yesterday's games.
	manager.call("_on_run_state_changed", {"run_active": true, "phase_name": "APARTMENT"})
	_check(int(manager.get("selected_day")) == 0, "Starting a fresh run clears the previous run's daily selection")
	_check(manager.call("get_selected_game_ids").is_empty(), "Fresh-run reset clears selected game IDs")
	manager.call("_on_run_state_changed", {"run_active": true, "phase_name": "CASINO", "current_day": 3})
	_check(int(manager.get("selected_day")) == 3, "A complete catalog is selected automatically on Casino arrival")
	_check(manager.call("get_selected_game_ids").size() == 6, "Automatic arrival selection still chooses six games")

	var roster: Array[String] = []
	for game_id: StringName in manager.call("get_registered_game_ids"):
		roster.append(String(game_id))
	var seen: Dictionary = {}
	for seed_value: int in range(128):
		var draw: Array[String] = CasinoManagerScript.draw_unique_game_ids(roster, 6, seed_value)
		_check(draw.size() == 6, "Every seeded draw returns six games")
		var draw_unique: Dictionary = {}
		for game_id: String in draw:
			draw_unique[game_id] = true
			seen[game_id] = true
		_check(draw_unique.size() == 6, "Every seeded draw contains six unique games")
	_check(seen.size() == 12, "Repeated seeded draws demonstrate every roster entry is eligible")

	_check(CasinoManagerScript.draw_unique_game_ids(roster, 13, 1).is_empty(), "Selection larger than roster is rejected")
	_check(CasinoManagerScript.draw_unique_game_ids(["same", "same"], 1, 1).is_empty(), "Duplicate roster IDs are rejected")

	if _failed:
		quit(1)
		return
	print("CASINO MANAGER PASS: 12-game registration, incomplete-roster gate, six unique selections, stable daily draw, and fair-roster eligibility")
	quit(0)


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failed = true
		push_error("CASINO MANAGER FAIL: %s" % label)


func _finish(passed: bool, message: String) -> void:
	if passed:
		print("CASINO MANAGER PASS: %s" % message)
		quit(0)
	else:
		push_error("CASINO MANAGER FAIL: %s" % message)
		quit(1)
