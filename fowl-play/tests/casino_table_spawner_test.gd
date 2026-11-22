extends SceneTree

const SPAWN_POINT_SCRIPT: Script = preload("res://world/casino/casino_table_spawn_point.gd")
const SPAWNER_SCRIPT: Script = preload("res://world/casino/casino_table_spawner.gd")

func _initialize() -> void:
	call_deferred("_run_checks")

func _run_checks() -> void:
	var spawner: Node3D = Node3D.new()
	spawner.name = "CasinoTableSpawners"
	spawner.set_script(SPAWNER_SCRIPT)
	spawner.set("spawn_on_ready", false)

	var spawn_points: Node3D = Node3D.new()
	spawn_points.name = "SpawnPoints"
	var spawned_tables: Node3D = Node3D.new()
	spawned_tables.name = "SpawnedTables"
	spawner.add_child(spawn_points)
	spawner.add_child(spawned_tables)
	root.add_child(spawner)

	var table_root: Node3D = Node3D.new()
	table_root.name = "TestTable"
	var packed_table: PackedScene = PackedScene.new()
	var pack_result: int = packed_table.pack(table_root)
	table_root.free()
	if pack_result != OK:
		_fail("Could not pack the test table scene.")
		return

	var active_slot: Marker3D = _make_slot("Slot_A", "test_table_a", "chicken_cross", packed_table, true)
	active_slot.position = Vector3(-6.0, 0.15, -12.0)
	spawn_points.add_child(active_slot)

	var disabled_slot: Marker3D = _make_slot("Slot_B", "test_table_b", "chicken_cross", packed_table, false)
	spawn_points.add_child(disabled_slot)

	var result: Dictionary = spawner.call("spawn_tables")
	if not bool(result.get("ok", false)):
		_fail("Spawner returned an error: %s" % str(result.get("reason", "")))
		return
	if int(result.get("spawned_count", 0)) != 1:
		_fail("Expected exactly one enabled configured table to spawn.")
		return
	if int(result.get("skipped_count", 0)) != 1:
		_fail("Expected the disabled table slot to be skipped.")
		return
	if spawned_tables.get_child_count() != 1:
		_fail("SpawnedTables should contain exactly one instance.")
		return

	var spawned_table: Node3D = spawned_tables.get_child(0) as Node3D
	if spawned_table == null or spawned_table.name != "Slot_A_Table":
		_fail("Spawned table has an unexpected instance name.")
		return
	if spawned_table.get_meta("casino_table_id", "") != "test_table_a":
		_fail("Spawned table is missing its table ID metadata.")
		return
	if not spawned_table.global_position.is_equal_approx(active_slot.global_position):
		_fail("Spawned table did not inherit the spawn marker's world position.")
		return

	var second_result: Dictionary = spawner.call("spawn_tables")
	if int(second_result.get("spawned_count", -1)) != 0 or spawned_tables.get_child_count() != 1:
		_fail("Calling spawn_tables twice created a duplicate table.")
		return

	print("CASINO TABLE SPAWNER PASS: enabled slots, disabled slots, scene instantiation, transform placement, metadata, and duplicate prevention")
	quit(0)

func _make_slot(slot_name: String, table_id: String, game_id: String, scene: PackedScene, is_enabled: bool) -> Marker3D:
	var slot: Marker3D = Marker3D.new()
	slot.name = slot_name
	slot.set_script(SPAWN_POINT_SCRIPT)
	slot.set("table_id", table_id)
	slot.set("game_id", game_id)
	slot.set("table_scene", scene)
	slot.set("enabled", is_enabled)
	return slot

func _fail(message: String) -> void:
	push_error("CASINO TABLE SPAWNER FAIL: " + message)
	quit(1)
