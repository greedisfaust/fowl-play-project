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
	remote_player.call("receive_movement", 5, baseline + Vector3(1.0, 0.0, 0.0), Vector3.ZERO, 0.8, 0.0, true)
	check(not bool(remote_player.call("apply_initial_player_state", 4, baseline, Vector3.ZERO, 0.7, 0.0, true)), "older reliable baseline cannot overwrite a newer movement sample")
	check(not bool(remote_player.call("apply_initial_player_state", 6, Vector3(NAN, 0.0, 0.0), Vector3.ZERO, 0.0, 0.0, true)), "non-finite baseline is rejected")

	var pending_states: Dictionary = network.get("_pending_player_states")
	pending_states[3] = {
		"sequence": 0, "position": Vector3(-4.0, 0.53, 2.0), "velocity": Vector3.ZERO,
		"yaw": -0.4, "pitch": 0.1, "grounded": true
	}
	var pending_player: CharacterBody3D = PLAYER_SCENE.instantiate() as CharacterBody3D
	pending_player.name = "3"
	pending_player.set("input_peer_id", 3)
	players.add_child(pending_player)
	await physics_frame
	check(pending_player.global_position.distance_to(Vector3(-4.0, 0.53, 2.0)) < 0.001, "baseline received before Player registration is applied after ready")
	check(int(network.get("player_state_sync_received")) == 1, "deferred baseline increments receive diagnostic")

	var press_times: Dictionary = network.get("_combat_press_times")
	var charged_presses: Dictionary = network.get("_combat_charged_presses")
	var active_jabs: Dictionary = network.get("_active_jabs")
	var active_lunges: Dictionary = network.get("_active_lunges")
	var action_locks: Dictionary = network.get("_combat_action_lock_until")
	var active_parries: Dictionary = network.get("_active_parries")
	var parry_ready_times: Dictionary = network.get("_parry_ready_times")
	press_times[3] = 1.0
	charged_presses[3] = true
	active_jabs[3] = {"elapsed": 0.05, "hit": false}
	active_lunges[3] = {"elapsed": 0.1, "direction": Vector3.FORWARD}
	action_locks[3] = 10.0
	active_parries[3] = {"expires_at": 10.0}
	parry_ready_times[3] = 10.0
	pending_player.call("begin_parry_presentation")
	network.call("_on_peer_disconnected", 3)
	check(not press_times.has(3) and not charged_presses.has(3), "disconnect clears held combat input")
	check(not active_jabs.has(3) and not active_lunges.has(3), "disconnect clears active jab and lunge state")
	check(not action_locks.has(3), "disconnect clears combat action lock")
	check(not active_parries.has(3) and not parry_ready_times.has(3), "disconnect clears active parry and cooldown state")
	check(not bool(pending_player.get("_parry_active")), "disconnect ends the departing player's parry presentation")
	check(not pending_states.has(3), "disconnect cleanup does not retain an already-applied state baseline")
	pending_states[4] = {"sequence": 0, "position": Vector3.ZERO, "velocity": Vector3.ZERO, "yaw": 0.0, "pitch": 0.0, "grounded": true}
	network.call("_on_peer_disconnected", 4)
	check(not pending_states.has(4), "disconnect clears a deferred player-state baseline")

	# Removing a Player node without a transport disconnect must also release
	# every peer-owned timer/epoch, not just the combat dictionaries.
	var tracked_player: CharacterBody3D = PLAYER_SCENE.instantiate() as CharacterBody3D
	tracked_player.name = "5"
	tracked_player.set("input_peer_id", 5)
	players.add_child(tracked_player)
	await physics_frame
	tracked_player.set("is_recovering", true)
	var interaction_times: Dictionary = network.get("_interaction_times")
	var carry_times: Dictionary = network.get("_carry_times")
	var ragdoll_epochs: Dictionary = network.get("_ragdoll_epochs")
	var jab_ready_times: Dictionary = network.get("_combat_jab_ready_times")
	var charged_ready_times: Dictionary = network.get("_charged_punch_ready_times")
	interaction_times[5] = 1.0
	carry_times[5] = 1.0
	ragdoll_epochs[5] = 7
	jab_ready_times[5] = 10.0
	charged_ready_times[5] = 10.0
	parry_ready_times[5] = 10.0
	active_jabs[5] = {"elapsed": 0.01, "hit": false}
	tracked_player.queue_free()
	await process_frame
	check(not network.get("movement_players").has(5), "removing a recovering Player unregisters its movement registration")
	check(not interaction_times.has(5) and not carry_times.has(5), "unregister clears interaction and carry timing state")
	check(not ragdoll_epochs.has(5), "unregister clears the departed Player ragdoll epoch")
	check(not jab_ready_times.has(5) and not charged_ready_times.has(5) and not parry_ready_times.has(5), "unregister clears combat cooldown state")
	check(not active_jabs.has(5), "unregister clears active combat actions")

	# Session shutdown must clear every peer-owned cache, even when no
	# transport disconnect event runs for the current local session.
	var shutdown_state_names: Array[String] = [
		"_interaction_times", "_carry_times", "_ragdoll_epochs",
		"_pending_ragdoll_starts", "_pending_player_states",
		"_combat_press_times", "_combat_charged_presses",
		"_combat_jab_ready_times", "_charged_punch_ready_times",
		"_combat_action_lock_until", "_active_jabs", "_active_lunges",
		"_active_parries", "_parry_ready_times",
	]
	for state_name: String in shutdown_state_names:
		var peer_state: Dictionary = network.get(state_name)
		peer_state[6] = {"fixture": true}
	network.get("movement_players")[6] = null
	network.get("connected_peers").append(6)
	network.get("roster").append(6)
	network.call("shutdown")
	await process_frame
	check(players.get_child_count() == 0, "session shutdown queues all arena Players for removal")
	for state_name: String in shutdown_state_names:
		check(network.get(state_name).is_empty(), "session shutdown clears %s" % state_name)
	check(network.get("movement_players").is_empty(), "session shutdown clears Player registrations")
	check(network.get("connected_peers").is_empty(), "session shutdown clears connected peers")
	check(network.get("roster").is_empty(), "session shutdown clears the published roster")
	check(str(network.get("status")) == "disconnected", "session shutdown sets the disconnected status")

	if not failed:
		print("M9/M11 lifecycle cleanup checks passed")
	quit(1 if failed else 0)

func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
