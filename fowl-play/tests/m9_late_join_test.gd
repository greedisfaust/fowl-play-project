## Host/client regression: a client joining during recovery receives the current capsule baseline.
extends SceneTree

var _role: String = "host"
var _expected_position: Vector3 = Vector3.ZERO
var _finished: bool = false

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--test-role="):
			_role = argument.trim_prefix("--test-role=")
		elif argument.begins_with("--expected-x="):
			_expected_position.x = float(argument.trim_prefix("--expected-x="))
		elif argument.begins_with("--expected-y="):
			_expected_position.y = float(argument.trim_prefix("--expected-y="))
		elif argument.begins_with("--expected-z="):
			_expected_position.z = float(argument.trim_prefix("--expected-z="))
	_run.call_deferred()

func _run() -> void:
	var network: Node = root.get_node("Network")
	var arena: Node3D = load("res://arena/test_arena.tscn").instantiate()
	root.add_child(arena)
	if _role == "host":
		await _run_host(network, arena)
	else:
		await _run_client(network, arena)

func _run_host(network: Node, arena: Node3D) -> void:
	for frame: int in range(4):
		await physics_frame
	var players: Node3D = arena.get_node("Players") as Node3D
	var deadline: int = Time.get_ticks_msec() + 5000
	while players.get_node_or_null("1") == null and Time.get_ticks_msec() < deadline:
		await process_frame
	var player: CharacterBody3D = players.get_node_or_null("1") as CharacterBody3D
	if player == null:
		_finish(false, "host Player did not spawn")
		return
	player.global_position = Vector3(4.0, 0.53, 4.0)
	player.set("auto_recovery_enabled", false)
	await physics_frame
	var rig: Node3D = player.get_node("Rig") as Node3D
	rig.position.y += 1.0
	if not bool(network.call("start_ragdoll_spike", 1)):
		_finish(false, "host could not begin ragdoll")
		return
	await create_timer(1.2).timeout
	if not bool(network.call("stop_ragdoll_spike", 1, "M9 late-join recovery")):
		_finish(false, "host could not enter recovery")
		return
	if not bool(player.get("is_recovering")):
		_finish(false, "host did not enter recovery state")
		return
	var expected: Vector3 = player.global_position
	print("M9_RECOVERY_STARTED x=%.4f y=%.4f z=%.4f" % [expected.x, expected.y, expected.z])
	await create_timer(8.0).timeout
	_finish(true, "host recovery window completed")

func _run_client(network: Node, arena: Node3D) -> void:
	var players: Node3D = arena.get_node("Players") as Node3D
	var deadline: int = Time.get_ticks_msec() + 9000
	while Time.get_ticks_msec() < deadline:
		var remote_host: CharacterBody3D = players.get_node_or_null("1") as CharacterBody3D
		if remote_host != null and int(network.get("player_state_sync_received")) > 0:
			var error_m: float = remote_host.global_position.distance_to(_expected_position)
			if error_m <= 0.25 and not bool(remote_host.get("is_limp")):
				_finish(true, "late join received recovery position baseline (%.3f m error)" % error_m)
				return
		await process_frame
	var remote_node: Node3D = players.get_node_or_null("1") as Node3D
	var actual: Vector3 = remote_node.global_position if remote_node != null else Vector3.INF
	_finish(false, "late join did not receive host recovery baseline; received=%d actual=%s expected=%s" % [int(network.get("player_state_sync_received")), str(actual), str(_expected_position)])

func _finish(passed: bool, detail: String) -> void:
	if _finished:
		return
	_finished = true
	if passed:
		print("M9 PASS %s: %s" % [_role, detail])
	else:
		push_error("M9 FAIL %s: %s" % [_role, detail])
	quit(0 if passed else 1)
