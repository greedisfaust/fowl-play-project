## Offline Main scene integration test.
## Uses temporary in-memory worlds so no editor-authored scene files are modified.
extends SceneTree

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main_scene: PackedScene = load("res://world/main.tscn")
	if main_scene == null:
		_finish(false, "Could not load Main scene.")
		return
	var main: Node3D = main_scene.instantiate() as Node3D
	if main == null:
		_finish(false, "Main scene root must be Node3D.")
		return

	main.set("apartment_scene", _make_world_scene(Vector3(2.0, 0.0, 3.0)))
	main.set("casino_scene", _make_world_scene(Vector3(-8.0, 0.0, 5.0)))
	main.set("initial_world", 0)
	main.set("fade_duration_seconds", 0.0)
	root.add_child(main)

	await process_frame
	await process_frame
	var players: Node3D = main.get_node("Players") as Node3D
	if players.get_child_count() != 1:
		main.queue_free()
		_finish(false, "Offline Main should spawn exactly one local player.")
		return

	var player: Node = players.get_node_or_null("1")
	if player == null or int(player.get("input_peer_id")) != 1:
		main.queue_free()
		_finish(false, "Offline host player was not created with peer ID 1.")
		return
	if not bool(main.call("can_transition_to", 1)):
		main.queue_free()
		_finish(false, "Main should accept an assigned, different destination.")
		return
	if bool(main.call("can_transition_to", 0)) or bool(main.call("can_transition_to", 3)):
		main.queue_free()
		_finish(false, "Main should reject the current world and invalid destination IDs.")
		return

	var network: Node = root.get_node("Network")
	var movement_players: Dictionary = network.get("movement_players")
	if movement_players.get(1) != player:
		main.queue_free()
		_finish(false, "Spawned player did not register with the existing Network autoload.")
		return

	main.call("transition_to", 1)
	await process_frame
	await process_frame
	if players.get_child_count() != 1 or players.get_node_or_null("1") != player:
		main.queue_free()
		_finish(false, "Player instance did not survive the world swap.")
		return
	if player.global_position.distance_to(Vector3(-8.0, 0.0, 5.0)) > 0.01:
		main.queue_free()
		_finish(false, "Standing player was not moved to the destination world's matching spawn slot.")
		return

	# Leaving a multiplayer session replaces the transport with OfflineMultiplayerPeer.
	# The persistent Main controller must still be able to create a fresh local player.
	var run_manager: Node = root.get_node_or_null("RunManager")
	var run_start: Dictionary = run_manager.call("begin_new_run")
	if not bool(run_start.get("ok", false)):
		main.queue_free()
		_finish(false, "Could not prepare a run before session-end reset verification.")
		return
	if not bool(run_manager.call("complete_world_transition", 0, 1)):
		main.queue_free()
		_finish(false, "Could not enter the Casino phase before session-end reset verification.")
		return
	var day_manager: Node = root.get_node_or_null("CasinoDayManager")
	if not is_instance_valid(day_manager) or not bool(day_manager.get("day_active")):
		main.queue_free()
		_finish(false, "Casino day state should be active before the network session ends.")
		return
	network.call("shutdown")
	await process_frame
	await process_frame
	if players.get_child_count() != 1 or players.get_node_or_null("1") == null:
		main.queue_free()
		_finish(false, "Intentional session shutdown should restore exactly one local Apartment player.")
		return
	var run_snapshot: Dictionary = run_manager.call("get_snapshot")
	if bool(run_snapshot.get("run_active", true)) or int(run_snapshot.get("current_day", -1)) != 0 or int(run_snapshot.get("phase", -1)) != 0:
		main.queue_free()
		_finish(false, "Network session end should reset run progression to IDLE.")
		return
	if bool(day_manager.get("day_active")) or int(day_manager.get("day_number")) != 0:
		main.queue_free()
		_finish(false, "Network session end should clear casino-day state.")
		return
	var wallet: Node = root.get_node_or_null("CasinoWallet")
	var wallet_snapshot: Dictionary = wallet.call("get_snapshot")
	if bool(wallet_snapshot.get("run_active", true)) or int(wallet_snapshot.get("available_balance", -1)) != 0:
		main.queue_free()
		_finish(false, "Network session end should clear the shared wallet ledger.")
		return
	# Exercise the same callback Godot emits when an ENet client cannot reach its host.
	# Failed connections use the same offline local-player recovery as intentional shutdown.
	network.call("_on_connection_failed")
	await process_frame
	await process_frame
	if players.get_child_count() != 1 or players.get_node_or_null("1") == null:
		main.queue_free()
		_finish(false, "A failed connection should automatically restore one local Apartment player.")
		return

	main.queue_free()
	await process_frame
	_finish(true, "offline spawn, Network registration, persistent player identity, world repositioning, intentional shutdown recovery, and failed-connection recovery")


func _make_world_scene(spawn_position: Vector3) -> PackedScene:
	var world: Node3D = Node3D.new()
	var spawn_points: Node3D = Node3D.new()
	spawn_points.name = "SpawnPoints"
	world.add_child(spawn_points)
	spawn_points.owner = world
	for index: int in range(4):
		var marker: Marker3D = Marker3D.new()
		marker.name = "Spawn%d" % (index + 1)
		marker.position = spawn_position + Vector3(float(index) * 2.0, 0.0, 0.0)
		spawn_points.add_child(marker)
		marker.owner = world
	var packed: PackedScene = PackedScene.new()
	var error: Error = packed.pack(world)
	world.free()
	if error != OK:
		push_error("Could not pack temporary test world: %s" % error_string(error))
	return packed


func _finish(passed: bool, message: String) -> void:
	if passed:
		print("MAIN CONTROLLER PASS: %s" % message)
		quit(0)
	else:
		push_error("MAIN CONTROLLER FAIL: %s" % message)
		quit(1)
