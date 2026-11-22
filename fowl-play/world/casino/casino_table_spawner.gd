extends Node3D
class_name CasinoTableSpawner

## Instantiates configured table scenes at child CasinoTableSpawnPoint markers.
## Every peer creates the same static world objects locally when the Casino scene loads.
## BaseTable remains responsible for host-authoritative gameplay.

@export_node_path("Node3D") var spawn_points_path: NodePath = ^"SpawnPoints"
@export_node_path("Node3D") var spawned_tables_path: NodePath = ^"SpawnedTables"
@export var spawn_on_ready: bool = true

var _spawned_slot_ids: Dictionary = {}
var _debug_hub: Node = null

func _ready() -> void:
	_debug_hub = get_node_or_null("/root/DebugHub")
	if is_instance_valid(_debug_hub):
		_debug_hub.call("watch", &"casino/table_spawner/active_tables", func() -> int: return _spawned_slot_ids.size())
	if spawn_on_ready:
		call_deferred("spawn_tables")

func _exit_tree() -> void:
	if is_instance_valid(_debug_hub):
		_debug_hub.call("unwatch", &"casino/table_spawner/active_tables")

func get_spawned_table_count() -> int:
	return _spawned_slot_ids.size()

func spawn_tables() -> Dictionary:
	var spawn_points: Node3D = get_node_or_null(spawn_points_path) as Node3D
	var spawned_tables: Node3D = get_node_or_null(spawned_tables_path) as Node3D
	if spawn_points == null:
		return _failure("SpawnPoints node is missing.")
	if spawned_tables == null:
		return _failure("SpawnedTables node is missing.")

	var spawned_count: int = 0
	var skipped_count: int = 0
	for child: Node in spawn_points.get_children():
		if not child is CasinoTableSpawnPoint:
			continue
		var slot: CasinoTableSpawnPoint = child as CasinoTableSpawnPoint
		if not slot.enabled or slot.table_scene == null:
			skipped_count += 1
			continue
		if slot.table_id.strip_edges().is_empty() or slot.game_id.strip_edges().is_empty():
			push_warning("Casino table spawn point '%s' has a scene but no table_id or game_id." % slot.name)
			skipped_count += 1
			continue
		if _spawned_slot_ids.has(slot.table_id):
			skipped_count += 1
			continue

		var table_instance: Node = slot.table_scene.instantiate()
		if table_instance == null or not table_instance is Node3D:
			push_warning("Table scene for spawn point '%s' must have a Node3D root." % slot.name)
			if is_instance_valid(table_instance):
				table_instance.free()
			skipped_count += 1
			continue
		var table_node: Node3D = table_instance as Node3D
		table_node.name = "%s_Table" % slot.name
		table_node.set_meta("casino_table_id", slot.table_id)
		table_node.set_meta("casino_game_id", slot.game_id)
		if table_node is BaseTable:
			var base_table: BaseTable = table_node as BaseTable
			base_table.table_id = slot.table_id
			base_table.game_id = slot.game_id
		spawned_tables.add_child(table_node)
		table_node.global_transform = slot.global_transform
		_spawned_slot_ids[slot.table_id] = table_node
		spawned_count += 1

	return {
		"ok": true,
		"spawned_count": spawned_count,
		"skipped_count": skipped_count,
		"total_spawned": _spawned_slot_ids.size(),
	}

func get_spawned_table(table_id: String) -> Node:
	var table: Node = _spawned_slot_ids.get(table_id) as Node
	if is_instance_valid(table):
		return table
	return null

func _failure(reason: String) -> Dictionary:
	return {
		"ok": false,
		"reason": reason,
		"spawned_count": 0,
		"skipped_count": 0,
		"total_spawned": _spawned_slot_ids.size(),
	}
