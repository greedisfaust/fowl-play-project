extends Node3D
class_name CasinoTableSpawner

## Places the six game scenes selected by CasinoManager into the six configured table slots.
## Every peer instantiates the same static world objects locally when the Casino scene loads.
## BaseTable remains responsible for host-authoritative gameplay.

@export_node_path("Node3D") var spawn_points_path: NodePath = ^"SpawnPoints"
@export_node_path("Node3D") var spawned_tables_path: NodePath = ^"SpawnedTables"
@export var spawn_on_ready: bool = true
@export var allow_single_chicken_cross_test_table: bool = true

var _spawned_slot_ids: Dictionary = {}
var _spawned_day_number: int = 0
var _casino_manager: Node = null
var _debug_hub: Node = null

func _ready() -> void:
	_casino_manager = get_node_or_null("/root/CasinoManager")
	_debug_hub = get_node_or_null("/root/DebugHub")
	if is_instance_valid(_debug_hub):
		_debug_hub.call("watch", &"casino/table_spawner/active_tables", func() -> int: return _spawned_slot_ids.size())
	if is_instance_valid(_casino_manager) and _casino_manager.has_signal("daily_selection_changed"):
		var callback: Callable = Callable(self, "_on_daily_selection_changed")
		if not _casino_manager.is_connected("daily_selection_changed", callback):
			_casino_manager.connect("daily_selection_changed", callback)
	if spawn_on_ready:
		call_deferred("spawn_tables")

func _exit_tree() -> void:
	if is_instance_valid(_casino_manager) and _casino_manager.has_signal("daily_selection_changed"):
		var callback: Callable = Callable(self, "_on_daily_selection_changed")
		if _casino_manager.is_connected("daily_selection_changed", callback):
			_casino_manager.disconnect("daily_selection_changed", callback)
	if is_instance_valid(_debug_hub):
		_debug_hub.call("unwatch", &"casino/table_spawner/active_tables")

func _on_daily_selection_changed(_day_number: int, _game_ids: Array) -> void:
	call_deferred("spawn_tables")

## Uses the current authoritative daily selection. If the catalog is not ready yet,
## the spawner waits for CasinoManager.daily_selection_changed.
func spawn_tables() -> Dictionary:
	if not is_instance_valid(_casino_manager):
		return _failure("CasinoManager is unavailable.")
	var day_number: int = int(_casino_manager.get("selected_day"))
	var definitions: Array[CasinoGameDefinition] = _casino_manager.call("get_selected_game_definitions")
	if day_number < 1:
		var run_manager: Node = get_node_or_null("/root/RunManager")
		if is_instance_valid(run_manager):
			var run_snapshot: Dictionary = run_manager.call("get_snapshot")
			if int(run_snapshot.get("phase", -1)) == 2:
				day_number = int(run_snapshot.get("current_day", 0))
	if definitions.is_empty() and allow_single_chicken_cross_test_table and day_number > 0:
		var test_definition: CasinoGameDefinition = _casino_manager.call("get_game_definition", &"chicken_cross") as CasinoGameDefinition
		if is_instance_valid(test_definition):
			return spawn_single_test_table(day_number, test_definition)
	if day_number < 1 or definitions.is_empty():
		return {
			"ok": true,
			"pending": true,
			"reason": "Waiting for the complete daily game catalog.",
			"spawned_count": 0,
			"skipped_count": 0,
			"total_spawned": _spawned_slot_ids.size(),
		}
	return spawn_tables_for_definitions(day_number, definitions)


## Development-only fallback: place the one registered Chicken Cross game in the
## first enabled physical slot while the twelve-game production roster is incomplete.
func spawn_single_test_table(day_number: int, definition: CasinoGameDefinition) -> Dictionary:
	if day_number < 1 or not is_instance_valid(definition):
		return _failure("A valid day and test game definition are required.")
	if String(definition.game_id) != "chicken_cross":
		return _failure("The incomplete-roster fallback is reserved for Chicken Cross.")
	if not is_instance_valid(definition.table_scene) or not definition.table_scene.can_instantiate():
		return _failure("Chicken Cross has no instantiable table scene.")
	if _spawned_day_number != 0 and _spawned_day_number != day_number:
		_clear_spawned_tables()
	if _spawned_day_number == day_number and not _spawned_slot_ids.is_empty():
		return {
			"ok": true,
			"pending": false,
			"test_fallback": true,
			"spawned_count": 0,
			"skipped_count": 0,
			"total_spawned": _spawned_slot_ids.size(),
		}
	var spawn_points: Node3D = get_node_or_null(spawn_points_path) as Node3D
	var spawned_tables: Node3D = get_node_or_null(spawned_tables_path) as Node3D
	if spawn_points == null or spawned_tables == null:
		return _failure("Table SpawnPoints or SpawnedTables node is missing.")
	var enabled_slots: Array[CasinoTableSpawnPoint] = []
	for child: Node in spawn_points.get_children():
		if child is CasinoTableSpawnPoint and (child as CasinoTableSpawnPoint).enabled:
			enabled_slots.append(child as CasinoTableSpawnPoint)
	enabled_slots.sort_custom(func(a: CasinoTableSpawnPoint, b: CasinoTableSpawnPoint) -> bool: return a.slot_id < b.slot_id)
	if enabled_slots.is_empty():
		return _failure("No enabled casino table slot is available for the Chicken Cross test table.")
	var slot: CasinoTableSpawnPoint = enabled_slots[0]
	if slot.slot_id.strip_edges().is_empty():
		return _failure("The first enabled Chicken Cross test slot needs a slot_id.")
	var table_id: String = "day_%02d_chicken_cross_test" % day_number
	var table_instance: Node = definition.table_scene.instantiate()
	if not table_instance is Node3D:
		if is_instance_valid(table_instance):
			table_instance.free()
		return _failure("Chicken Cross table scene must have a Node3D root.")
	var table_node: Node3D = table_instance as Node3D
	table_node.name = "%s_ChickenCrossTest" % slot.slot_id
	table_node.set_meta("casino_table_id", table_id)
	table_node.set_meta("casino_game_id", "chicken_cross")
	if table_node is BaseTable:
		var base_table: BaseTable = table_node as BaseTable
		base_table.table_id = table_id
		base_table.game_id = "chicken_cross"
	spawned_tables.add_child(table_node)
	table_node.global_transform = slot.global_transform
	_spawned_slot_ids[table_id] = table_node
	_spawned_day_number = day_number
	_log_test_fallback(day_number, slot.slot_id)
	return {
		"ok": true,
		"pending": false,
		"test_fallback": true,
		"spawned_count": 1,
		"skipped_count": enabled_slots.size() - 1,
		"total_spawned": _spawned_slot_ids.size(),
	}

## Public data-driven entry point, also used by automated checks.
func spawn_tables_for_definitions(day_number: int, definitions: Array[CasinoGameDefinition]) -> Dictionary:
	if day_number < 1:
		return _failure("A valid casino day number is required.")
	if definitions.is_empty():
		return _failure("The daily game selection is empty.")
	if _spawned_day_number == day_number and _spawned_slot_ids.size() == definitions.size() and not _spawned_slot_ids.has("day_%02d_chicken_cross_test" % day_number):
		return {
			"ok": true,
			"pending": false,
			"spawned_count": 0,
			"skipped_count": 0,
			"total_spawned": _spawned_slot_ids.size(),
		}

	var spawn_points: Node3D = get_node_or_null(spawn_points_path) as Node3D
	var spawned_tables: Node3D = get_node_or_null(spawned_tables_path) as Node3D
	if spawn_points == null:
		return _failure("SpawnPoints node is missing.")
	if spawned_tables == null:
		return _failure("SpawnedTables node is missing.")

	var enabled_slots: Array[CasinoTableSpawnPoint] = []
	var slot_ids: Dictionary = {}
	for child: Node in spawn_points.get_children():
		if not child is CasinoTableSpawnPoint:
			continue
		var slot: CasinoTableSpawnPoint = child as CasinoTableSpawnPoint
		if not slot.enabled:
			continue
		if slot.slot_id.strip_edges().is_empty():
			return _failure("Spawn point '%s' needs a unique slot_id." % slot.name)
		if slot_ids.has(slot.slot_id):
			return _failure("Duplicate table slot ID '%s'." % slot.slot_id)
		slot_ids[slot.slot_id] = true
		enabled_slots.append(slot)

	enabled_slots.sort_custom(func(a: CasinoTableSpawnPoint, b: CasinoTableSpawnPoint) -> bool: return a.slot_id < b.slot_id)
	if enabled_slots.size() != definitions.size():
		return _failure("The daily selection contains %d games but there are %d enabled table slots. Configure one enabled slot per selected game." % [definitions.size(), enabled_slots.size()])

	var game_ids: Dictionary = {}
	for definition: CasinoGameDefinition in definitions:
		if not is_instance_valid(definition):
			return _failure("The daily selection contains an invalid game definition.")
		var game_id: String = String(definition.game_id).strip_edges()
		if game_id.is_empty() or game_ids.has(game_id):
			return _failure("The daily selection contains an empty or duplicate game ID.")
		if not is_instance_valid(definition.table_scene) or not definition.table_scene.can_instantiate():
			return _failure("Game '%s' has no instantiable table scene." % game_id)
		game_ids[game_id] = true

	if _spawned_day_number != 0 and (_spawned_day_number != day_number or _spawned_slot_ids.has("day_%02d_chicken_cross_test" % day_number)):
		_clear_spawned_tables()

	var spawned_count: int = 0
	for index: int in range(definitions.size()):
		var definition: CasinoGameDefinition = definitions[index]
		var slot: CasinoTableSpawnPoint = enabled_slots[index]
		var game_id: String = String(definition.game_id)
		var table_id: String = "day_%02d_%s_%02d" % [day_number, game_id, index + 1]
		if _spawned_slot_ids.has(table_id):
			continue

		var table_instance: Node = definition.table_scene.instantiate()
		if table_instance == null or not table_instance is Node3D:
			push_warning("Table scene for game '%s' must have a Node3D root." % game_id)
			if is_instance_valid(table_instance):
				table_instance.free()
			continue
		var table_node: Node3D = table_instance as Node3D
		table_node.name = "%s_Table" % slot.slot_id
		table_node.set_meta("casino_table_id", table_id)
		table_node.set_meta("casino_game_id", game_id)
		if table_node is BaseTable:
			var base_table: BaseTable = table_node as BaseTable
			base_table.table_id = table_id
			base_table.game_id = game_id
		spawned_tables.add_child(table_node)
		table_node.global_transform = slot.global_transform
		_spawned_slot_ids[table_id] = table_node
		spawned_count += 1

	_spawned_day_number = day_number
	return {
		"ok": true,
		"pending": false,
		"spawned_count": spawned_count,
		"skipped_count": definitions.size() - spawned_count,
		"total_spawned": _spawned_slot_ids.size(),
	}

func _log_test_fallback(day_number: int, slot_id: String) -> void:
	if is_instance_valid(_debug_hub):
		_debug_hub.call("warn", &"casino_games", "Development fallback spawned Chicken Cross in slot '%s' for Day %d; remaining table slots are intentionally empty until the game roster is complete." % [slot_id, day_number])


func get_spawned_table_count() -> int:
	return _spawned_slot_ids.size()

func get_spawned_table(table_id: String) -> Node:
	var table: Node = _spawned_slot_ids.get(table_id) as Node
	if is_instance_valid(table):
		return table
	return null

func _clear_spawned_tables() -> void:
	for table_value: Variant in _spawned_slot_ids.values():
		var table: Node = table_value as Node
		if is_instance_valid(table):
			table.queue_free()
	_spawned_slot_ids.clear()
	_spawned_day_number = 0

func _failure(reason: String) -> Dictionary:
	return {
		"ok": false,
		"reason": reason,
		"spawned_count": 0,
		"skipped_count": 0,
		"total_spawned": _spawned_slot_ids.size(),
	}
