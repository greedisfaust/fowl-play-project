## M9 offline lifecycle and state-baseline regression checks.
extends SceneTree

const PLAYER_SCENE: PackedScene = preload("res://player/player.tscn")

var failed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var network: Node = root.get_node("Network")
	var arena: Node3D = load("res://arena/test_arena.tscn").instantiate()
	root.add_child(arena)
	await physics_frame
	await physics_frame
	var players: Node3D = arena.get_node("Players") as Node3D
	var remote_player: CharacterBody3D = PLAYER_SCENE.instantiate() as CharacterBody3D
	remote_player.name = "2"
	remote_player.set("input_peer_id", 2)
	players.add_child(remote_player)
	await physics_frame
	await physics_frame
	check(not bool(remote_player.get("is_local_player")), "fixture is a remote player")

	var baseline: Vector3 = Vector3(4.0, 0.53, -3.0)
	check(bool(remote_player.call("apply_initial_player_state", 0, baseline, Vector3(1.0, 0.0, 0.0), 0.7, 0.2, true)), "initial standing snapshot is accepted")
	check(remote_player.global_position.distance_to(baseline) < 0.001, "initial snapshot moves the remote capsule to host position")
	check(is_equal_approx(remote_player.rotation.y, 0.7), "initial snapshot applies host yaw")
	check(is_equal_approx((remote_player.get_node("Head") as Node3D).rotation.x, 0.2), "initial snapshot applies host pitch")
	check(bool(remote_player.get("_remote_grounded")), "initial snapshot applies grounded state")
	check(not bool(remote_player.call("apply_initial_player_state", 1, Vector3(NAN, 0.0, 0.0), Vector3.ZERO, 0.0, 0.0, true)), "non-finite baseline is rejected")
	check(remote_player.global_position.distance_to(baseline) < 0.001, "rejected baseline leaves position unchanged")

	var pending_player: CharacterBody3D = PLAYER_SCENE.instantiate() as CharacterBody3D
	pending_player.name = "3"
	pending_player.set("input_peer_id", 3)
	players.add_child(pending_player)
	await physics_frame
	var pending_states: Dictionary = network.get("_pending_player_states")
	pending_states[3] = {
		"sequence": 0, "position": Vector3(-4.0, 0.53, 2.0), "velocity": Vector3.ZERO,
		"yaw": -0.4, "pitch": 0.1, "grounded": true
	}
	network.call("apply_pending_player_state", 3, pending_player)
	check(pending_player.global_position.distance_to(Vector3(-4.0, 0.53, 2.0)) < 0.001, "baseline received before Player registration is applied after ready")
	check(int(network.get("player_state_sync_received")) == 1, "deferred baseline increments receive diagnostic")

	var press_times: Dictionary = network.get("_combat_press_times")
	var charged_presses: Dictionary = network.get("_combat_charged_presses")
	var active_jabs: Dictionary = network.get("_active_jabs")
	var active_lunges: Dictionary = network.get("_active_lunges")
	var action_locks: Dictionary = network.get("_combat_action_lock_until")
	press_times[3] = 1.0
	charged_presses[3] = true
	active_jabs[3] = {"elapsed": 0.05, "hit": false}
	active_lunges[3] = {"elapsed": 0.1, "direction": Vector3.FORWARD}
	action_locks[3] = 10.0
	network.call("_on_peer_disconnected", 3)
	check(not press_times.has(3) and not charged_presses.has(3), "disconnect clears held combat input")
	check(not active_jabs.has(3) and not active_lunges.has(3), "disconnect clears active jab and lunge state")
	check(not action_locks.has(3), "disconnect clears combat action lock")
	check(not pending_states.has(3), "disconnect cleanup does not retain an already-applied state baseline")
	pending_states[4] = {"sequence": 0, "position": Vector3.ZERO, "velocity": Vector3.ZERO, "yaw": 0.0, "pitch": 0.0, "grounded": true}
	network.call("_on_peer_disconnected", 4)
	check(not pending_states.has(4), "disconnect clears a deferred player-state baseline")

	if not failed:
		print("M9 lifecycle checks passed")
	quit(1 if failed else 0)

func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
