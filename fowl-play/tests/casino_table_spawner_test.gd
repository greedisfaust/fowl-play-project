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

	var definition: CasinoGameDefinition = CasinoGameDefinition.new()
	definition.game_id = &"test_game"
	definition.display_name = "Spawner Test Game"
	definition.table_scene = packed_table
	var definitions: Array[CasinoGameDefinition] = [definition]

	var active_slot: Marker3D = _make_slot("Slot_A", "slot_a", true)
	active_slot.position = Vector3(-6.0, 0.15, -12.0)
	spawn_points.add_child(active_slot)

	var disabled_slot: Marker3D = _make_slot("Slot_B", "slot_b", false)
	spawn_points.add_child(disabled_slot)

	var result: Dictionary = spawner.call("spawn_tables_for_definitions", 1, definitions)
	if not bool(result.get("ok", false)):
		_fail("Spawner returned an error: %s" % str(result.get("reason", "")))
		return
	if int(result.get("spawned_count", 0)) != 1:
		_fail("Expected exactly one enabled configured table to spawn.")
		return
	if int(result.get("skipped_count", 0)) != 0:
		_fail("Disabled slots should not count as selected-game omissions.")
		return
	if spawned_tables.get_child_count() != 1:
		_fail("SpawnedTables should contain exactly one instance.")
		return

	var spawned_table: Node3D = spawned_tables.get_child(0) as Node3D
	if spawned_table == null or spawned_table.name != "slot_a_Table":
		_fail("Spawned table has an unexpected instance name.")
		return
	if spawned_table.get_meta("casino_game_id", "") != "test_game":
		_fail("Spawned table is missing its game ID metadata.")
		return
	if spawned_table.get_meta("casino_table_id", "") != "day_01_test_game_01":
		_fail("Spawned table is missing its generated table ID.")
		return
	if not spawned_table.global_position.is_equal_approx(active_slot.global_position):
		_fail("Spawned table did not inherit the spawn marker's world position.")
		return

	var second_result: Dictionary = spawner.call("spawn_tables_for_definitions", 1, definitions)
	if int(second_result.get("spawned_count", -1)) != 0 or spawned_tables.get_child_count() != 1:
		_fail("Calling the daily spawner twice created a duplicate table.")
		return

	var mismatch: Dictionary = spawner.call("spawn_tables_for_definitions", 2, [definition, definition])
	if bool(mismatch.get("ok", true)):
		_fail("Spawner should reject a slot count that does not match the daily selection.")
		return

	print("CASINO TABLE SPAWNER PASS: daily game definitions, enabled slots, disabled slots, scene instantiation, transform placement, metadata, slot-count validation, and duplicate prevention")
	quit(0)

func _make_slot(slot_name: String, slot_id: String, is_enabled: bool) -> Marker3D:
	var slot: Marker3D = Marker3D.new()
	slot.name = slot_name
	slot.set_script(SPAWN_POINT_SCRIPT)
	slot.set("slot_id", slot_id)
	slot.set("enabled", is_enabled)
	return slot

func _fail(message: String) -> void:
	push_error("CASINO TABLE SPAWNER FAIL: " + message)
	quit(1)
