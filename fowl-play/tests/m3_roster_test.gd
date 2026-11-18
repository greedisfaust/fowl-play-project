## Three-process late-join/reconnect test using the saved arena.
extends SceneTree

var role: String = "host"
var arena: Node3D
var network: Node
var initial_host_position: Vector3
var failed: bool = false

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--test-role="):
			role = argument.trim_prefix("--test-role=")
	_run.call_deferred()

func _run() -> void:
	network = root.get_node("Network")
	var scene: PackedScene = load("res://arena/test_arena.tscn")
	arena = scene.instantiate()
	root.add_child(arena)
	if role == "host":
		await wait_count(1)
		await physics_frame
		if not network.request_interaction(arena.get_node("TestUseDevice/Interactable").get_path(), &"use"):
			fail("Host could not toggle device before late joins")
		initial_host_position = (arena.get_node("Players/1") as Node3D).global_position
		Input.action_press("move_right")
		await create_timer(0.6).timeout
		Input.action_release("move_right")
		await create_timer(0.3).timeout
		print("ROSTER HOST READY")
		await wait_count(2)
		var old_client: int = int(network.roster[1])
		await wait_count(3)
		await wait_count(2)
		if network.roster.has(old_client) or network.movement_players.has(old_client):
			fail("Disconnected owner retained in roster/movement registry")
		await wait_count(3)
		if network.roster.has(old_client):
			fail("Reconnected client retained old identity")
		await create_timer(2.0).timeout
	elif role == "client":
		await wait_count(2)
		await check_late_position()
		print("ROSTER CLIENT READY")
		await wait_count(3)
		await create_timer(0.3).timeout
		network.shutdown()
		await process_frame
		if not network.roster.is_empty() or not network.movement_players.is_empty() or arena.get_node("Players").get_child_count() != 0:
			fail("Local disconnect did not clear state")
		await create_timer(0.8).timeout
		network.join_server("127.0.0.1")
		await wait_count(3)
		await check_late_position()
		await create_timer(0.5).timeout
	else:
		await wait_count(3)
		await check_late_position()
		await wait_count(2)
		await wait_count(3)
		await create_timer(1.0).timeout
	if not failed:
		print("M3 ROSTER PASS %s" % role)
	quit(1 if failed else 0)

func wait_count(count: int) -> void:
	var deadline: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		var ids: Array[int] = []
		for player: Node in arena.get_node("Players").get_children():
			ids.append(int(str(player.name)))
		ids.sort()
		if ids.size() == count and ids == network.roster and network.movement_players.size() == count:
			return
		await create_timer(0.02).timeout
	fail("Roster/spawn/registry did not converge to %d: %s" % [count, network.roster])

func check_late_position() -> void:
	await create_timer(0.2).timeout
	if not bool(arena.get_node("TestUseDevice").get("is_active")):
		fail("Late join/reconnect did not receive current device state")
	var host_player: Node3D = arena.get_node("Players/1") as Node3D
	var spawn: Node3D = arena.get_node("SpawnPoints").get_child(0) as Node3D
	if absf(host_player.global_position.x - spawn.global_position.x) < 1.0:
		fail("Late join received old spawn position instead of current movement")

func fail(message: String) -> void:
	failed = true
	push_error("%s: %s" % [role, message])
