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

	main.set("apartment_scene", _make_world_scene(Vector3(2.0, 0.0, 3.0), "LobbySpawnPoints", true))
	main.set("casino_scene", _make_world_scene(Vector3(-8.0, 0.0, 5.0), "PlayerSpawnPoints"))
	main.set("initial_world", 0)
	main.set("fade_duration_seconds", 0.0)
	main.set("transition_hold_seconds", 0.1)
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

	var player_spawner: MultiplayerSpawner = main.get_node("MultiplayerSpawner") as MultiplayerSpawner
	if player_spawner == null or player_spawner.get_multiplayer_authority() != 1 or not player_spawner.is_multiplayer_authority():
		main.queue_free()
		_finish(false, "MultiplayerSpawner must explicitly be authoritative on the host peer.")
		return
	var spawn_points: Node3D = main.call("_get_player_spawn_points") as Node3D
	main.call("_spawn_player", 1, spawn_points)
	if players.get_child_count() != 1:
		main.queue_free()
		_finish(false, "Repeated spawn requests must not create a duplicate player.")
		return

	# Simulate the cursor being released during the elevator interaction.
	# A terminal text-entry movement lock must not prevent mouse-look restoration.
	player.call("set_terminal_movement_locked", true)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	main.call("transition_to", 1)
	await process_frame
	if int(main.get("active_world")) != 1:
		main.queue_free()
		_finish(false, "Destination world should be installed as soon as the screen reaches black.")
		return
	var transition_fade: ColorRect = main.get("_fade_rect") as ColorRect
	if transition_fade == null or transition_fade.color.a < 0.99:
		main.queue_free()
		_finish(false, "Destination world must remain hidden behind a fully black screen during the arrival pause.")
		return
	await create_timer(0.12).timeout
	await process_frame
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		main.queue_free()
		_finish(false, "Gameplay mouse should be captured again after the world transition fade completes, even with terminal movement locked.")
		return
	var casino_hud: CanvasLayer = main.get_node_or_null("CasinoHUD") as CanvasLayer
	var hud_controls: Array[Node] = casino_hud.find_children("*", "Control", true, false) if casino_hud != null else []
	for hud_node: Node in hud_controls:
		var hud_control: Control = hud_node as Control
		if hud_control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			main.queue_free()
			_finish(false, "Casino HUD controls must ignore mouse input so FPS look events reach Player._unhandled_input.")
			return
	var yaw_before_mouse_look: float = float(player.rotation.y)
	player.call("_rotate_view", Vector2(10.0, 0.0))
	if is_equal_approx(float(player.rotation.y), yaw_before_mouse_look):
		main.queue_free()
		_finish(false, "Mouse look should remain responsive while terminal movement is locked.")
		return
	if players.get_child_count() != 1 or players.get_node_or_null("1") != player:
		main.queue_free()
		_finish(false, "Player instance did not survive the world swap.")
		return
	if player.global_position.distance_to(Vector3(-8.0, 0.0, 5.0)) > 0.01:
		main.queue_free()
		_finish(false, "Standing player was not moved to the destination world's matching spawn slot.")
		return

	# Starting a new host/client session also calls Network.shutdown(), but
	# must NOT restore the temporary offline player while MultiplayerSpawner
	# is about to replicate the real peer-owned player nodes.
	network.set("_switching_session", true)
	network.call("shutdown")
	if players.get_child_count() != 0:
		main.queue_free()
		_finish(false, "Session shutdown must detach the offline player immediately before a replicated spawn can arrive.")
		return
	await process_frame
	await process_frame
	if players.get_child_count() != 0:
		main.queue_free()
		_finish(false, "Session startup must not recreate Players/1 as an offline player.")
		return
	network.set("_switching_session", false)
	main.call("_restore_local_player_after_session_end")
	await process_frame
	await process_frame
	if players.get_child_count() != 1 or players.get_node_or_null("1") == null:
		main.queue_free()
		_finish(false, "Offline player recovery should still work after session startup is cancelled.")
		return
	player = players.get_node("1")

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


func _make_world_scene(spawn_position: Vector3, spawn_container_name: String, include_empty_spawn_points: bool = false) -> PackedScene:
	var world: Node3D = Node3D.new()
	if include_empty_spawn_points:
		var empty_spawn_points: Node3D = Node3D.new()
		empty_spawn_points.name = "SpawnPoints"
		world.add_child(empty_spawn_points)
		empty_spawn_points.owner = world
	var spawn_points: Node3D = Node3D.new()
	spawn_points.name = spawn_container_name
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
