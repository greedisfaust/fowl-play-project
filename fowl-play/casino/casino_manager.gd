## Registers the casino game catalog and selects six unique game types each day.
## Host-authoritative selection; every peer loads the same registered definitions.
extends Node

const REQUIRED_GAME_COUNT: int = 12
const DAILY_SELECTION_COUNT: int = 6
const MAX_DAYS: int = 10
const CHICKEN_CROSS_SCENE: PackedScene = preload("res://casino/tables/chicken_cross/chicken_cross_table.tscn")

signal game_catalog_changed(registered_count: int, required_count: int)
signal daily_selection_changed(day_number: int, game_ids: Array)

var _registered_games: Dictionary = {}
var selected_day: int = 0
var selected_game_ids: Array[StringName] = []
var _pending_day_number: int = 0
var _run_manager: Node
var _debug_hub: Node


func _ready() -> void:
	_run_manager = get_node_or_null("/root/RunManager")
	_debug_hub = get_node_or_null("/root/DebugHub")
	_register_builtin_games()
	if is_instance_valid(_run_manager) and _run_manager.has_signal("run_state_changed"):
		var callback: Callable = Callable(self, "_on_run_state_changed")
		if not _run_manager.is_connected("run_state_changed", callback):
			_run_manager.connect("run_state_changed", callback)
	if is_instance_valid(_debug_hub):
		_debug_hub.call("watch", &"casino/games/registered_count", func() -> int: return _registered_games.size())
		_debug_hub.call("watch", &"casino/games/roster_complete", func() -> bool: return is_catalog_complete())
		_debug_hub.call("watch", &"casino/games/selected_day", func() -> int: return selected_day)
		_debug_hub.call("watch", &"casino/games/selected_count", func() -> int: return selected_game_ids.size())
		_debug_hub.call("watch", &"casino/games/selected_ids", func() -> Array: return get_selected_game_ids())


func _exit_tree() -> void:
	if is_instance_valid(_run_manager) and _run_manager.has_signal("run_state_changed"):
		var callback: Callable = Callable(self, "_on_run_state_changed")
		if _run_manager.is_connected("run_state_changed", callback):
			_run_manager.disconnect("run_state_changed", callback)
	if is_instance_valid(_debug_hub):
		for watch_name: StringName in [
			&"casino/games/registered_count",
			&"casino/games/roster_complete",
			&"casino/games/selected_day",
			&"casino/games/selected_count",
			&"casino/games/selected_ids",
		]:
			_debug_hub.call("unwatch", watch_name)


func _register_builtin_games() -> void:
	var chicken_cross: CasinoGameDefinition = CasinoGameDefinition.new()
	chicken_cross.game_id = &"chicken_cross"
	chicken_cross.display_name = "Chicken Cross"
	chicken_cross.table_scene = CHICKEN_CROSS_SCENE
	var result: Dictionary = register_game(chicken_cross)
	if not bool(result.get("ok", false)):
		_log("Could not register Chicken Cross: %s" % str(result.get("reason", "")))


## Registration is local static catalog setup, so every peer registers the same definitions.
func register_game(definition: CasinoGameDefinition) -> Dictionary:
	if not is_instance_valid(definition):
		return _failure("Game definition is missing.")
	var game_id: String = String(definition.game_id).strip_edges()
	if game_id.is_empty():
		return _failure("Game ID cannot be empty.")
	if definition.display_name.strip_edges().is_empty():
		return _failure("Game display name cannot be empty.")
	if not is_instance_valid(definition.table_scene) or not definition.table_scene.can_instantiate():
		return _failure("Game '%s' must provide an instantiable table scene." % game_id)
	if _registered_games.has(game_id):
		return _failure("Game ID '%s' is already registered." % game_id)
	_registered_games[game_id] = definition
	game_catalog_changed.emit(_registered_games.size(), REQUIRED_GAME_COUNT)
	_log("Registered casino game '%s' (%s)." % [game_id, definition.display_name])
	if _pending_day_number > 0 and selected_game_ids.is_empty() and is_catalog_complete():
		select_games_for_day(_pending_day_number)
	return _success({"game_id": game_id, "registered_count": _registered_games.size()})


func is_catalog_complete() -> bool:
	return _registered_games.size() == REQUIRED_GAME_COUNT


func get_registered_game_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for game_id_value: Variant in _registered_games.keys():
		result.append(StringName(str(game_id_value)))
	result.sort()
	return result


func get_game_definition(game_id: StringName) -> CasinoGameDefinition:
	if not _registered_games.has(String(game_id)):
		return null
	return _registered_games[String(game_id)] as CasinoGameDefinition


## Returns the same selection if this day has already been drawn; never rerolls an active day.
func select_games_for_day(day_number: int, seed_override: int = -1) -> Dictionary:
	if not _is_authority():
		return _failure("Only the host can select the daily games.")
	if day_number < 1 or day_number > MAX_DAYS:
		return _failure("Casino day must be between 1 and 10.")
	if selected_day == day_number and selected_game_ids.size() == DAILY_SELECTION_COUNT:
		return _success({"day_number": selected_day, "game_ids": get_selected_game_ids()})
	if not is_catalog_complete():
		return _failure("The casino catalog has %d of %d required game types; daily selection is unavailable until all twelve are registered." % [_registered_games.size(), REQUIRED_GAME_COUNT])
	var roster: Array[String] = []
	for game_id: StringName in get_registered_game_ids():
		roster.append(String(game_id))
	var drawn_ids: Array[String] = draw_unique_game_ids(roster, DAILY_SELECTION_COUNT, seed_override)
	if drawn_ids.size() != DAILY_SELECTION_COUNT:
		return _failure("Could not draw the required number of unique games.")
	var selected: Array[StringName] = []
	for game_id: String in drawn_ids:
		selected.append(StringName(game_id))
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		_apply_daily_selection(day_number, selected)
	else:
		rpc("_rpc_apply_daily_selection", day_number, selected)
	return _success({"day_number": day_number, "game_ids": get_selected_game_ids()})


## Partial Fisher-Yates shuffle: every six-game subset has equal probability.
static func draw_unique_game_ids(roster: Array[String], selection_count: int, seed_override: int = -1) -> Array[String]:
	if selection_count < 0 or selection_count > roster.size():
		return []
	var unique_check: Dictionary = {}
	for game_id: String in roster:
		if game_id.strip_edges().is_empty() or unique_check.has(game_id):
			return []
		unique_check[game_id] = true
	var candidates: Array[String] = roster.duplicate()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	if seed_override >= 0:
		rng.seed = seed_override
	else:
		rng.randomize()
	for index: int in range(selection_count):
		var swap_index: int = rng.randi_range(index, candidates.size() - 1)
		var temporary: String = candidates[index]
		candidates[index] = candidates[swap_index]
		candidates[swap_index] = temporary
	var result: Array[String] = []
	for index: int in range(selection_count):
		result.append(candidates[index])
	return result


func get_selected_game_ids() -> Array[StringName]:
	return selected_game_ids.duplicate()


func get_selected_game_definitions() -> Array[CasinoGameDefinition]:
	var result: Array[CasinoGameDefinition] = []
	for game_id: StringName in selected_game_ids:
		var definition: CasinoGameDefinition = get_game_definition(game_id)
		if is_instance_valid(definition):
			result.append(definition)
	return result


func _on_run_state_changed(snapshot: Dictionary) -> void:
	if not bool(snapshot.get("run_active", false)):
		_pending_day_number = 0
		return
	var phase_name: String = str(snapshot.get("phase_name", ""))
	if phase_name == "APARTMENT":
		_pending_day_number = 0
		selected_day = 0
		selected_game_ids.clear()
		daily_selection_changed.emit(selected_day, get_selected_game_ids())
		return
	if phase_name != "CASINO":
		_pending_day_number = 0
		return
	if not _is_authority():
		return
	var day_number: int = int(snapshot.get("current_day", 0))
	if day_number < 1 or day_number > MAX_DAYS:
		return
	_pending_day_number = day_number
	if selected_day == day_number and selected_game_ids.size() == DAILY_SELECTION_COUNT:
		return
	var result: Dictionary = select_games_for_day(day_number)
	if not bool(result.get("ok", false)):
		_log("Daily game selection pending: %s" % str(result.get("reason", "")))


@rpc("authority", "call_local", "reliable")
func _rpc_apply_daily_selection(day_number: int, game_ids: Array) -> void:
	if day_number < 1 or day_number > MAX_DAYS or game_ids.size() != DAILY_SELECTION_COUNT:
		return
	var unique_ids: Dictionary = {}
	var validated: Array[StringName] = []
	for value: Variant in game_ids:
		var game_id: String = str(value)
		if not _registered_games.has(game_id) or unique_ids.has(game_id):
			return
		unique_ids[game_id] = true
		validated.append(StringName(game_id))
	if day_number < selected_day:
		return
	if day_number == selected_day and selected_game_ids.size() == DAILY_SELECTION_COUNT:
		if validated != selected_game_ids:
			return
		return
	_apply_daily_selection(day_number, validated)


func _apply_daily_selection(day_number: int, game_ids: Array[StringName]) -> void:
	selected_day = day_number
	selected_game_ids = game_ids.duplicate()
	daily_selection_changed.emit(selected_day, get_selected_game_ids())
	var display_ids: PackedStringArray = PackedStringArray()
	for game_id: StringName in selected_game_ids:
		display_ids.append(String(game_id))
	_log("Day %d selected games: %s" % [selected_day, ", ".join(display_ids)])


func _is_authority() -> bool:
	return multiplayer.is_server()


func _success(data: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"ok": true, "reason": ""}
	result.merge(data, true)
	return result


func _failure(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}


func _log(message: String) -> void:
	if is_instance_valid(_debug_hub):
		_debug_hub.call("log", &"casino_games", message)
