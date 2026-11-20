## Network bootstrap and shared RPC validation for Fowl Play.
## This is the only project script that directly constructs ENet peers.

extends Node

const TUNING = preload("res://core/tuning.gd")
const LAYERS = preload("res://core/layers.gd")
const PlayerIdentity = preload("res://core/player_identity.gd")
const COMBAT_CONTROLLER_SCRIPT = preload("res://combat/combat_controller.gd")
const COMBAT_HIT_DETECTOR = preload("res://combat/combat_hit_detector.gd")

signal session_ended
signal session_started
signal roster_changed
signal identity_roster_changed

var peer: ENetMultiplayerPeer = null
var is_host: bool = false
var is_client: bool = false
var connected_peers: Array[int] = []
## Host-published session membership, separate from transport connection events.
var roster: Array[int] = []
## Host-authoritative identity records, keyed by the stable peer ID.
var player_identities: Dictionary = {}
var status: String = "offline"
var port: int = TUNING.ENET_PORT
var _switching_session: bool = false
var movement_players: Dictionary = {}
var movement_rejected: int = 0
var interaction_rejected: int = 0
var carry_rejected: int = 0
var combat_rejected: int = 0
var combat_jabs: int = 0
var combat_hits: int = 0
var combat_charged_punches: int = 0
var combat_lunge_hits: int = 0
var combat_parries: int = 0
var combat_parry_rejected: int = 0
var _carry_times: Dictionary = {}
var _combat_press_times: Dictionary = {}
var _combat_charged_presses: Dictionary = {}
var _combat_jab_ready_times: Dictionary = {}
var _charged_punch_ready_times: Dictionary = {}
var _combat_action_lock_until: Dictionary = {}
var _active_jabs: Dictionary = {}
var _active_lunges: Dictionary = {}
var _active_parries: Dictionary = {}
var _parry_ready_times: Dictionary = {}
var interaction_accepted: int = 0
var hand_poke_sent: int = 0
var hand_poke_received: int = 0
var hand_hover_sent: int = 0
var hand_hover_received: int = 0
var _interaction_times: Dictionary = {}
var _ragdoll_epochs: Dictionary = {}
var _pending_ragdoll_starts: Dictionary = {}
var _pending_player_states: Dictionary = {}
var player_state_sync_sent: int = 0
var player_state_sync_received: int = 0
var ragdoll_pose_sent: int = 0
var ragdoll_pose_received: int = 0
var ragdoll_pose_data_bytes_sent: int = 0
var ragdoll_send_hz: int = TUNING.RAGDOLL_SEND_HZ
var ragdoll_settled_sent: int = 0
var ragdoll_settled_received: int = 0

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_bootstrap.call_deferred()

func _bootstrap() -> void:
	var hub: Node = get_node("/root/DebugHub")
	hub.call("watch", &"net/status", func() -> String: return status)
	hub.call("watch", &"net/peers", func() -> Array[int]: return connected_peers.duplicate())
	hub.call("watch", &"net/roster", func() -> Array[int]: return roster.duplicate())
	hub.call("watch", &"net/identities", get_identity_summary)
	hub.call("watch", &"net/movement_rejected", func() -> int: return movement_rejected)
	hub.call("watch", &"net/interaction_rejected", func() -> int: return interaction_rejected)
	hub.call("watch", &"net/interaction_accepted", func() -> int: return interaction_accepted)
	hub.call("watch", &"net/hand_poke_sent", func() -> int: return hand_poke_sent)
	hub.call("watch", &"net/hand_poke_received", func() -> int: return hand_poke_received)
	hub.call("watch", &"net/hand_hover_sent", func() -> int: return hand_hover_sent)
	hub.call("watch", &"net/hand_hover_received", func() -> int: return hand_hover_received)
	hub.call("watch", &"net/ragdoll_pose_sent", func() -> int: return ragdoll_pose_sent)
	hub.call("watch", &"net/ragdoll_pose_received", func() -> int: return ragdoll_pose_received)
	hub.call("watch", &"net/ragdoll_pose_data_bytes_sent", func() -> int: return ragdoll_pose_data_bytes_sent)
	hub.call("watch", &"net/ragdoll_settled_sent", func() -> int: return ragdoll_settled_sent)
	hub.call("watch", &"net/ragdoll_settled_received", func() -> int: return ragdoll_settled_received)
	hub.call("watch", &"net/player_state_sync_sent", func() -> int: return player_state_sync_sent)
	hub.call("watch", &"net/player_state_sync_received", func() -> int: return player_state_sync_received)
	hub.call("command", &"net_status", _command_status, "Report local connection state.", false, false)
	hub.call("command", &"net_disconnect", _command_disconnect, "Leave this local network session.", false, false)
	hub.call("command", &"net_host", _command_host, "Host a game on this computer.", false, false)
	hub.call("command", &"net_join", _command_join, "Join an IP: net_join [IP]. Default: 127.0.0.1.", false, false)
	hub.call("command", &"identity_status", _command_identity_status, "List the current player identities.", false, false)
	hub.call("command", &"identity_set", _command_identity_set, "Request your nickname/color: identity_set <nickname> [color_index 0-9].", false, false)
	hub.call("command", &"ragdoll_spike_start", _command_ragdoll_start, "Host test: start a player's ragdoll by peer ID.", true, true)
	hub.call("command", &"ragdoll_spike_stop", _command_ragdoll_stop, "Host test: restore a player's standing state by peer ID.", true, true)
	hub.call("watch", &"net/carry_rejected", func() -> int: return carry_rejected)
	hub.call("watch", &"net/combat_rejected", func() -> int: return combat_rejected)
	hub.call("watch", &"net/combat_jabs", func() -> int: return combat_jabs)
	hub.call("watch", &"net/combat_hits", func() -> int: return combat_hits)
	hub.call("watch", &"net/combat_charged_punches", func() -> int: return combat_charged_punches)
	hub.call("watch", &"net/combat_lunge_hits", func() -> int: return combat_lunge_hits)
	hub.call("watch", &"net/combat_lunges_active", func() -> int: return _active_lunges.size())
	hub.call("watch", &"net/combat_parries", func() -> int: return combat_parries)
	hub.call("watch", &"net/combat_parry_rejected", func() -> int: return combat_parry_rejected)
	hub.call("watch", &"net/combat_parries_active", func() -> int: return _active_parries.size())
	parse_args(OS.get_cmdline_args() + OS.get_cmdline_user_args())

func parse_args(arguments: PackedStringArray) -> void:
	var host_requested: bool = arguments.has("--host")
	var address: String = ""
	for argument: String in arguments:
		if argument.begins_with("--join="):
			address = argument.trim_prefix("--join=").strip_edges()
			if address.is_empty():
				status = "failed"
				_debug_warn("Join address must not be empty")
				return
		elif argument.begins_with("--port="):
			var port_text: String = argument.trim_prefix("--port=")
			if not port_text.is_valid_int() or int(port_text) < 1 or int(port_text) > 65535:
				status = "failed"
				_debug_warn("Invalid network port")
				return
			port = int(port_text)
	if host_requested and not address.is_empty():
		status = "failed"
		_debug_warn("Choose --host or --join, not both")
	elif host_requested:
		start_host()
	elif not address.is_empty():
		join_server(address)

func start_host() -> Error:
	if peer != null:
		_debug_warn("Rejected host start: network already started")
		return ERR_ALREADY_IN_USE
	peer = ENetMultiplayerPeer.new()
	var error: Error = peer.create_server(port, TUNING.MAX_PLAYERS - 1)
	if error != OK:
		peer = null
		status = "failed"
		_debug_warn("Host start failed: %s" % error_string(error))
		return error
	multiplayer.multiplayer_peer = peer
	is_host = true
	status = "hosting"
	is_client = false
	connected_peers = [TUNING.PEER_ID_HOST]
	roster = connected_peers.duplicate()
	roster_changed.emit()
	_assign_player_identity(TUNING.PEER_ID_HOST, "Chicken", 0)
	_publish_identity_roster()
	_debug_log("Host started on port %d" % port)
	session_started.emit()
	return OK

func join_server(address: String) -> Error:
	if peer != null:
		_debug_warn("Rejected join: network already started")
		return ERR_ALREADY_IN_USE
	peer = ENetMultiplayerPeer.new()
	var error: Error = peer.create_client(address, port)
	if error != OK:
		peer = null
		status = "failed"
		_debug_warn("Join failed for %s: %s" % [address, error_string(error)])
		return error
	multiplayer.multiplayer_peer = peer
	is_host = false
	is_client = true
	status = "connecting"
	_debug_log("Joining %s:%d" % [address, port])
	return OK

func shutdown() -> void:
	for owner_key: Variant in _combat_press_times.keys():
		_play_combat_cancel(int(owner_key))
	for owner_key: Variant in _active_lunges.keys():
		_play_combat_lunge_stop(int(owner_key))
	for owner_key: Variant in _active_parries.keys():
		_play_parry_end(int(owner_key), false)
	if peer != null:
		peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	peer = null
	is_host = false
	is_client = false
	connected_peers.clear()
	roster.clear()
	player_identities.clear()
	identity_roster_changed.emit()
	roster_changed.emit()
	movement_players.clear()
	movement_rejected = 0
	interaction_rejected = 0
	interaction_accepted = 0
	hand_poke_sent = 0
	hand_poke_received = 0
	hand_hover_sent = 0
	hand_hover_received = 0
	_interaction_times.clear()
	_ragdoll_epochs.clear()
	_pending_ragdoll_starts.clear()
	_pending_player_states.clear()
	player_state_sync_sent = 0
	player_state_sync_received = 0
	ragdoll_pose_sent = 0
	ragdoll_pose_received = 0
	ragdoll_pose_data_bytes_sent = 0
	ragdoll_settled_sent = 0
	ragdoll_settled_received = 0
	ragdoll_send_hz = TUNING.RAGDOLL_SEND_HZ
	carry_rejected = 0
	_carry_times.clear()
	combat_rejected = 0
	combat_jabs = 0
	combat_hits = 0
	combat_charged_punches = 0
	combat_lunge_hits = 0
	combat_parries = 0
	combat_parry_rejected = 0
	_combat_press_times.clear()
	_combat_charged_presses.clear()
	_combat_jab_ready_times.clear()
	_charged_punch_ready_times.clear()
	_combat_action_lock_until.clear()
	_active_jabs.clear()
	_active_lunges.clear()
	_active_parries.clear()
	_parry_ready_times.clear()
	status = "disconnected"
	session_ended.emit()
	_debug_log("Network shut down")

func _on_connected_to_server() -> void:
	status = "connected"
	var local_id: int = multiplayer.get_unique_id()
	if not connected_peers.has(local_id):
		connected_peers.append(local_id)
	_debug_log("Connected as peer %d" % local_id)

func _on_connection_failed() -> void:
	shutdown()
	status = "failed"
	_debug_warn("Connection failed")

func _on_server_disconnected() -> void:
	shutdown()
	_debug_warn("Host disconnected")

func _command_status(_args: Array[Variant]) -> String:
	return "status=%s port=%d peers=%s" % [status, port, connected_peers]

func _command_disconnect(_args: Array[Variant]) -> String:
	if _switching_session:
		return "Session startup in progress; try again shortly."
	shutdown()
	return "Disconnected. Use net_host or net_join to start another session."

func _command_host(args: Array[Variant]) -> String:
	if not args.is_empty():
		return "Usage: net_host"
	return _request_session(true, "")

func _command_join(args: Array[Variant]) -> String:
	if args.size() > 1:
		return "Usage: net_join [IP]"
	var address: String = "127.0.0.1" if args.is_empty() else str(args[0]).strip_edges()
	if not address.is_valid_ip_address():
		return "Invalid IP address. Example: net_join 127.0.0.1"
	return _request_session(false, address)

func _request_session(host_requested: bool, address: String) -> String:
	if _switching_session:
		return "Session startup in progress; try again shortly."
	if peer != null:
		return "Already hosting or joining. Use net_disconnect first."
	_switching_session = true
	_switch_session.call_deferred(host_requested, address)
	return "Starting host; check net/status." if host_requested else "Joining %s; check net/status." % address

func _switch_session(host_requested: bool, address: String) -> void:
	# Remove offline/previous players before changing peer identity or spawning.
	shutdown()
	await get_tree().process_frame
	if host_requested:
		start_host()
	else:
		join_server(address)
	_switching_session = false

func _physics_process(delta: float) -> void:
	if peer != null and not is_host:
		return
	_advance_combat_holds()
	_advance_parries()
	for owner_key: Variant in _active_jabs.keys():
		var owner_id: int = int(owner_key)
		if not _active_jabs.has(owner_id):
			continue
		var jab: Dictionary = _active_jabs[owner_id]
		jab["elapsed"] = float(jab.get("elapsed", 0.0)) + delta
		if not bool(jab.get("hit", false)):
			var attacker: CharacterBody3D = movement_players.get(owner_id) as CharacterBody3D
			if is_instance_valid(attacker) and not attacker.is_queued_for_deletion():
				var jab_origin: Vector3 = jab.get("origin", Vector3.ZERO)
				var jab_direction: Vector3 = jab.get("direction", Vector3.ZERO)
				var result: Dictionary = COMBAT_HIT_DETECTOR.trace_jab(attacker, jab_origin, jab_direction, TUNING.QUICK_PUNCH_RANGE_M)
				if result.has("target"):
					var hit_target: Node3D = result.get("target") as Node3D
					var target_was_parrying: bool = is_instance_valid(hit_target) and _active_parries.has(int(hit_target.get("input_peer_id")))
					if _apply_jab_hit(result, owner_id, jab_direction, attacker.velocity):
						jab["hit"] = true
						if not target_was_parrying:
							combat_hits += 1
		if float(jab.get("elapsed", 0.0)) >= TUNING.QUICK_PUNCH_DURATION_S:
			_active_jabs.erase(owner_id)
		else:
			_active_jabs[owner_id] = jab
	_advance_combat_lunges(delta)

func validate_rpc(expected_sender: int = -1) -> bool:
	var sender: int = multiplayer.get_remote_sender_id()
	if sender <= 0 or sender == multiplayer.get_unique_id():
		_debug_warn("Rejected RPC from invalid sender %d" % sender)
		return false
	if expected_sender >= 0 and sender != expected_sender:
		_debug_warn("Rejected RPC from peer %d: expected peer %d" % [
			sender,
			expected_sender,
		])
		return false
	return true

func register_movement_player(owner_id: int, player: Node) -> void:
	movement_players[owner_id] = player

func apply_pending_ragdoll_start(owner_id: int, player: Node) -> void:
	if movement_players.get(owner_id) != player:
		return
	if _pending_ragdoll_starts.has(owner_id):
		var pending: Dictionary = _pending_ragdoll_starts[owner_id]
		_pending_ragdoll_starts.erase(owner_id)
		if bool(player.call("begin_remote_limp", pending.epoch, pending.world_transform, pending.pose)) and pending.has("settled_pose"):
			player.call("receive_remote_settled_pose", pending.epoch, pending.settled_sequence, pending.settled_time_ms, pending.settled_pose)

## Apply a late-join standing/recovery snapshot after the Player has finished _ready.
func apply_pending_player_state(owner_id: int, player: Node) -> void:
	if movement_players.get(owner_id) != player or not _pending_player_states.has(owner_id):
		return
	var pending: Dictionary = _pending_player_states[owner_id]
	_pending_player_states.erase(owner_id)
	if bool(player.call("apply_initial_player_state", pending.sequence, pending.position, pending.velocity, pending.yaw, pending.pitch, pending.grounded)):
		player_state_sync_received += 1

func unregister_movement_player(owner_id: int, player: Node) -> void:
	if movement_players.get(owner_id) == player:
		if _active_lunges.has(owner_id):
			_finish_combat_lunge(owner_id, "player unregistered")
		movement_players.erase(owner_id)
		_pending_ragdoll_starts.erase(owner_id)
		_pending_player_states.erase(owner_id)
		_combat_press_times.erase(owner_id)
		_combat_charged_presses.erase(owner_id)
		_combat_jab_ready_times.erase(owner_id)
		_charged_punch_ready_times.erase(owner_id)
		_combat_action_lock_until.erase(owner_id)
		_active_jabs.erase(owner_id)
		_active_lunges.erase(owner_id)
		_active_parries.erase(owner_id)
		_parry_ready_times.erase(owner_id)

func send_movement(owner_id: int, sequence: int, at: Vector3, speed: Vector3, yaw: float, pitch: float, grounded: bool = true) -> void:
	if peer == null or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	if is_host:
		_receive_movement(owner_id, sequence, at, speed, yaw, pitch, grounded)
	else:
		_submit_movement.rpc_id(TUNING.PEER_ID_HOST, sequence, at, speed, yaw, pitch, grounded)

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _submit_movement(sequence: int, at: Vector3, speed: Vector3, yaw: float, pitch: float, grounded: bool) -> void:
	if not is_host or not validate_rpc():
		return
	# Sender identity selects the player; clients cannot choose another player's ID.
	_receive_movement(multiplayer.get_remote_sender_id(), sequence, at, speed, yaw, pitch, grounded)

func _receive_movement(owner_id: int, sequence: int, at: Vector3, speed: Vector3, yaw: float, pitch: float, grounded: bool) -> void:
	var player: Node = movement_players.get(owner_id)
	if not is_instance_valid(player):
		return
	if bool(player.get("is_limp")):
		return
	if not bool(player.call("accept_movement", sequence, at, speed, yaw, pitch, grounded)):
		movement_rejected += 1
		if owner_id != TUNING.PEER_ID_HOST:
			_correct_movement.rpc_id(owner_id, player.get("accepted_position"))
		return
	_publish_movement.rpc(owner_id, sequence, at, speed, yaw, pitch, grounded)

@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _publish_movement(owner_id: int, sequence: int, at: Vector3, speed: Vector3, yaw: float, pitch: float, grounded: bool) -> void:
	if not validate_rpc(TUNING.PEER_ID_HOST):
		return
	var player: Node = movement_players.get(owner_id)
	if is_instance_valid(player):
		player.call("receive_movement", sequence, at, speed, yaw, pitch, grounded)

@rpc("authority", "call_remote", "reliable", 2)
func _correct_movement(at: Vector3) -> void:
	if not validate_rpc(TUNING.PEER_ID_HOST) or not at.is_finite():
		return
	var player: Node = movement_players.get(multiplayer.get_unique_id())
	if is_instance_valid(player):
		player.call("correct_movement", at)

## M4 spike entry point. Combat will call the same host-owned transition later.
func start_ragdoll_spike(owner_id: int) -> bool:
	if peer != null and not is_host:
		return false
	var player: Node = movement_players.get(owner_id)
	cancel_combat_state(owner_id)
	force_drop_carry(owner_id, "limp")
	if not is_instance_valid(player) or player.is_queued_for_deletion() or not bool(player.call("begin_host_limp")):
		return false
	var epoch: int = int(_ragdoll_epochs.get(owner_id, 0)) + 1
	_ragdoll_epochs[owner_id] = epoch
	player.set("limp_epoch", epoch)
	var rig: Node3D = player.get("rig") as Node3D
	var initial_pose: PackedInt32Array = rig.call("capture_quantized_pose")
	if peer != null:
		_ragdoll_begin.rpc(owner_id, epoch, rig.global_transform, initial_pose)
	_debug_log("Ragdoll spike started for peer %d epoch %d" % [owner_id, epoch])
	return true

func stop_ragdoll_spike(owner_id: int, reason: String = "manual") -> bool:
	if peer != null and not is_host:
		return false
	var player: Node = movement_players.get(owner_id)
	if not is_instance_valid(player) or not bool(player.get("is_limp")):
		return false
	var rig: Node3D = player.get("rig") as Node3D
	if rig == null:
		return false
	var final_pose: PackedInt32Array = rig.call("capture_quantized_pose")
	var recovery_variant: StringName = rig.call("get_recovery_variant")
	if not bool(player.call("stop_host_limp", recovery_variant)):
		return false
	if peer != null:
		_ragdoll_end.rpc(
			owner_id,
			int(_ragdoll_epochs.get(owner_id, 0)),
			player.get("global_position"),
			final_pose,
			recovery_variant
		)
	_debug_log("Ragdoll spike stopped for peer %d (%s)" % [owner_id, reason])
	return true

func publish_ragdoll_pose(owner_id: int, epoch: int, sequence: int, pose: PackedInt32Array) -> void:
	if peer == null or not is_host or epoch != int(_ragdoll_epochs.get(owner_id, 0)):
		return
	var player: Node = movement_players.get(owner_id)
	if not is_instance_valid(player) or not bool(player.get("is_limp")):
		return
	var rig: Node3D = player.get("rig") as Node3D
	if rig == null or not bool(rig.call("valid_pose", pose)):
		return
	ragdoll_pose_sent += 1
	# 77 signed 32-bit bone values, plus four integer RPC arguments. This is
	# application data only; Godot/ENet framing and compression are excluded.
	ragdoll_pose_data_bytes_sent += pose.size() * 4 + 16
	_ragdoll_pose.rpc(owner_id, epoch, sequence, Time.get_ticks_msec(), pose)

func publish_settled_ragdoll_pose(owner_id: int, epoch: int, sequence: int, pose: PackedInt32Array) -> void:
	if peer == null or not is_host or epoch != int(_ragdoll_epochs.get(owner_id, 0)):
		return
	var player: Node = movement_players.get(owner_id)
	if not is_instance_valid(player) or not bool(player.get("is_limp")):
		return
	var rig: Node3D = player.get("rig") as Node3D
	if rig == null or not bool(rig.call("valid_pose", pose)):
		return
	ragdoll_settled_sent += 1
	_ragdoll_settled.rpc(owner_id, epoch, sequence, Time.get_ticks_msec(), pose)
	_debug_log("Ragdoll settled for peer %d epoch %d" % [owner_id, epoch])

@rpc("authority", "call_remote", "reliable", 0)
func _ragdoll_begin(owner_id: int, epoch: int, world_transform: Transform3D, initial_pose: PackedInt32Array) -> void:
	if not validate_rpc(TUNING.PEER_ID_HOST) or epoch <= int(_ragdoll_epochs.get(owner_id, 0)):
		return
	_ragdoll_epochs[owner_id] = epoch
	var player: Node = movement_players.get(owner_id)
	if not is_instance_valid(player):
		_pending_ragdoll_starts[owner_id] = {"epoch": epoch, "world_transform": world_transform, "pose": initial_pose}
		return
	if bool(player.call("begin_remote_limp", epoch, world_transform, initial_pose)):
		_debug_log("Ragdoll start received for peer %d epoch %d" % [owner_id, epoch])

@rpc("authority", "call_remote", "unreliable_ordered", 3)
func _ragdoll_pose(owner_id: int, epoch: int, sequence: int, host_time_ms: int, pose: PackedInt32Array) -> void:
	if not validate_rpc(TUNING.PEER_ID_HOST) or epoch != int(_ragdoll_epochs.get(owner_id, 0)):
		return
	var player: Node = movement_players.get(owner_id)
	if is_instance_valid(player):
		if bool(player.call("receive_remote_pose", epoch, sequence, host_time_ms, pose)):
			ragdoll_pose_received += 1

@rpc("authority", "call_remote", "reliable", 0)
func _ragdoll_settled(owner_id: int, epoch: int, sequence: int, host_time_ms: int, pose: PackedInt32Array) -> void:
	if not validate_rpc(TUNING.PEER_ID_HOST) or epoch != int(_ragdoll_epochs.get(owner_id, 0)):
		return
	var player: Node = movement_players.get(owner_id)
	if not is_instance_valid(player) and _pending_ragdoll_starts.has(owner_id):
		var pending: Dictionary = _pending_ragdoll_starts[owner_id]
		pending["settled_sequence"] = sequence
		pending["settled_time_ms"] = host_time_ms
		pending["settled_pose"] = pose
		_pending_ragdoll_starts[owner_id] = pending
		ragdoll_settled_received += 1
		return
	if is_instance_valid(player) and bool(player.call("receive_remote_settled_pose", epoch, sequence, host_time_ms, pose)):
		ragdoll_settled_received += 1

@rpc("authority", "call_remote", "reliable", 0)
func _ragdoll_end(
	owner_id: int,
	epoch: int,
	standing_at: Vector3,
	final_pose: PackedInt32Array,
	recovery_variant: StringName
) -> void:
	if not validate_rpc(TUNING.PEER_ID_HOST) or epoch != int(_ragdoll_epochs.get(owner_id, 0)):
		return
	_pending_ragdoll_starts.erase(owner_id)
	var player: Node = movement_players.get(owner_id)
	if is_instance_valid(player) and bool(player.call("end_remote_limp", epoch, standing_at, final_pose, recovery_variant)):
		_debug_log("Ragdoll end received for peer %d epoch %d" % [owner_id, epoch])

func _sync_active_ragdolls(peer_id: int) -> void:
	if not is_host or peer == null or not connected_peers.has(peer_id):
		return
	for owner: Variant in movement_players.keys():
		var owner_id: int = int(owner)
		var player: Node = movement_players[owner_id]
		if not is_instance_valid(player) or not bool(player.get("is_limp")):
			continue
		var rig: Node3D = player.get("rig") as Node3D
		var epoch: int = int(_ragdoll_epochs.get(owner_id, 0))
		var current_pose: PackedInt32Array = rig.call("capture_quantized_pose")
		_ragdoll_begin.rpc_id(peer_id, owner_id, epoch, rig.global_transform, current_pose)
		if bool(player.get("_ragdoll_settled_sent")):
			_ragdoll_settled.rpc_id(peer_id, owner_id, epoch, int(player.get("_ragdoll_sequence")), Time.get_ticks_msec(), current_pose)

## Send a reliable baseline for players who are not currently ragdolled.
## This includes players whose recovery blend is in progress and therefore are
## temporarily not publishing ordinary movement snapshots.
func _sync_active_player_states(peer_id: int) -> void:
	if not is_host or peer == null or not connected_peers.has(peer_id):
		return
	for owner_key: Variant in movement_players.keys():
		var owner_id: int = int(owner_key)
		var player: Node = movement_players[owner_id]
		if not is_instance_valid(player) or bool(player.get("is_limp")):
			continue
		var grounded: bool = true
		if not bool(player.get("is_recovering")):
			grounded = bool(player.call("is_on_floor")) if bool(player.get("is_local_player")) else bool(player.get("_remote_grounded"))
		var sequence: int = int(player.call("get_movement_sync_sequence"))
		var player_rotation: Vector3 = Vector3(player.get("rotation"))
		_player_state_sync.rpc_id(
			peer_id,
			owner_id,
			sequence,
			player.get("global_position"),
			player.get("velocity"),
			player_rotation.y,
			float(player.get("_pitch_radians")),
			grounded
		)
		player_state_sync_sent += 1

@rpc("authority", "call_remote", "reliable", 0)
func _player_state_sync(owner_id: int, sequence: int, at: Vector3, speed: Vector3, yaw: float, pitch: float, grounded: bool) -> void:
	if not validate_rpc(TUNING.PEER_ID_HOST) or owner_id <= 0 or sequence < 0:
		return
	if not at.is_finite() or not speed.is_finite() or not is_finite(yaw) or not is_finite(pitch) or absf(pitch) > deg_to_rad(85.1):
		return
	var player: Node = movement_players.get(owner_id)
	if not is_instance_valid(player):
		_pending_player_states[owner_id] = {
			"sequence": sequence, "position": at, "velocity": speed,
			"yaw": yaw, "pitch": pitch, "grounded": grounded
		}
		return
	if bool(player.call("apply_initial_player_state", sequence, at, speed, yaw, pitch, grounded)):
		player_state_sync_received += 1

func _command_ragdoll_start(args: Array[Variant]) -> String:
	if args.size() != 1 or not str(args[0]).is_valid_int():
		return "Usage: ragdoll_spike_start <peer_id>"
	return "Ragdoll started." if start_ragdoll_spike(int(args[0])) else "Ragdoll start rejected."

func _command_ragdoll_stop(args: Array[Variant]) -> String:
	if args.size() != 1 or not str(args[0]).is_valid_int():
		return "Usage: ragdoll_spike_stop <peer_id>"
	return "Standing restored." if stop_ragdoll_spike(int(args[0])) else "Ragdoll stop rejected."

func is_host_peer(peer_id: int) -> bool:
	return peer_id == TUNING.PEER_ID_HOST

func _on_peer_connected(peer_id: int) -> void:
	if not connected_peers.has(peer_id):
		connected_peers.append(peer_id)
	_debug_log("Peer %d connected" % peer_id)
	if is_host:
		_assign_player_identity(peer_id, "Chicken", 0)
		_publish_roster()
		_sync_active_ragdolls.call_deferred(peer_id)
		_sync_active_carries.call_deferred(peer_id)
		_sync_active_parries.call_deferred(peer_id)
		_sync_active_player_states.call_deferred(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	_interaction_times.erase(peer_id)
	_clear_combat_peer_state(peer_id)
	force_drop_carry(peer_id, "disconnect")
	_carry_times.erase(peer_id)
	# G8 forced-exit cleanup: if a limp player disconnects, broadcast the
	# reliable end event to the remaining clients so their limp bodies
	# complete a get-up blend instead of vanishing silently. The host
	# restores the departing player's rig locally before the arena despawns
	# the player node. This runs before the epoch is erased so the end RPC
	# carries the correct epoch.
	if is_host and _ragdoll_epochs.has(peer_id):
		var player: Node = movement_players.get(peer_id)
		if is_instance_valid(player) and bool(player.get("is_limp")):
			stop_ragdoll_spike(peer_id, "disconnect")
	_pending_ragdoll_starts.erase(peer_id)
	_pending_player_states.erase(peer_id)
	_ragdoll_epochs.erase(peer_id)
	player_identities.erase(peer_id)
	connected_peers.erase(peer_id)
	_debug_log("Peer %d disconnected" % peer_id)
	if is_host:
		_publish_roster()

## Remove every combat timer/action owned by a departing peer.
func _clear_combat_peer_state(owner_id: int) -> void:
	if peer == null or is_host:
		cancel_combat_state(owner_id)
	_active_jabs.erase(owner_id)
	_active_lunges.erase(owner_id)
	_active_parries.erase(owner_id)
	_combat_press_times.erase(owner_id)
	_combat_charged_presses.erase(owner_id)
	_combat_jab_ready_times.erase(owner_id)
	_charged_punch_ready_times.erase(owner_id)
	_combat_action_lock_until.erase(owner_id)
	_parry_ready_times.erase(owner_id)
	_carry_times.erase(owner_id)

func _publish_roster() -> void:
	roster = connected_peers.duplicate()
	roster.sort()
	roster_changed.emit()
	_receive_roster.rpc(roster)
	_publish_identity_roster()
	_debug_log("Roster updated: %s" % [roster])

@rpc("authority", "call_remote", "reliable", 0)
func _receive_roster(members: Array[int]) -> void:
	if not validate_rpc(TUNING.PEER_ID_HOST):
		return
	roster = members.duplicate()
	roster_changed.emit()
	_debug_log("Roster received: %s" % [roster])


## Submit identity intent for this local peer. The host derives remote peer IDs
## from the RPC sender and never accepts a client-supplied owner ID.
func request_identity(nickname: String, requested_color_index: int) -> bool:
	if requested_color_index < 0 or requested_color_index >= PlayerIdentity.palette_size():
		_debug_warn("Identity request rejected: invalid color index %d" % requested_color_index)
		return false
	if is_host:
		return _assign_player_identity(multiplayer.get_unique_id(), nickname, requested_color_index)
	if peer == null or not is_client or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		_debug_warn("Identity request rejected: not connected to a host")
		return false
	_submit_identity_request.rpc_id(TUNING.PEER_ID_HOST, nickname, requested_color_index)
	return true

@rpc("any_peer", "call_remote", "reliable", 0)
func _submit_identity_request(nickname: String, requested_color_index: int) -> void:
	if not is_host or not validate_rpc():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if not connected_peers.has(sender_id):
		_debug_warn("Identity request rejected from unregistered peer %d" % sender_id)
		return
	if requested_color_index < 0 or requested_color_index >= PlayerIdentity.palette_size():
		_debug_warn("Identity request rejected from peer %d: invalid color index" % sender_id)
		return
	_assign_player_identity(sender_id, nickname, requested_color_index)

func _assign_player_identity(peer_id: int, requested_nickname: String, requested_color_index: int) -> bool:
	if not is_host or peer_id <= 0 or not connected_peers.has(peer_id):
		_debug_warn("Identity assignment rejected for peer %d: not an active host-owned peer" % peer_id)
		return false
	if requested_color_index < 0 or requested_color_index >= PlayerIdentity.palette_size():
		_debug_warn("Identity assignment rejected for peer %d: invalid color index" % peer_id)
		return false
	var color_index: int = _next_available_identity_color(requested_color_index, peer_id)
	if color_index < 0:
		_debug_warn("Identity assignment rejected for peer %d: lobby color palette is full" % peer_id)
		return false
	var nickname: String = _unique_identity_nickname(_clean_identity_nickname(requested_nickname), peer_id)
	var identity: PlayerIdentity = PlayerIdentity.new(peer_id, nickname, color_index)
	player_identities[peer_id] = identity
	identity_roster_changed.emit()
	_debug_log("Identity assigned peer=%d nickname=%s color=%s" % [
		peer_id,
		nickname,
		identity.get_color_name(),
	])
	_publish_identity_roster()
	return true

func _clean_identity_nickname(requested: String) -> String:
	var cleaned: String = ""
	for index: int in range(requested.length()):
		var codepoint: int = requested.unicode_at(index)
		if codepoint >= 32 and codepoint != 127:
			cleaned += String.chr(codepoint)
	cleaned = cleaned.strip_edges()
	if cleaned.is_empty():
		return "Chicken"
	return cleaned.substr(0, PlayerIdentity.MAX_NICKNAME_LENGTH).strip_edges()

func _unique_identity_nickname(base_name: String, peer_id: int) -> String:
	var candidate: String = base_name
	var suffix: int = 2
	while _identity_nickname_taken(candidate, peer_id):
		var suffix_text: String = " %d" % suffix
		var allowed_base_length: int = PlayerIdentity.MAX_NICKNAME_LENGTH - suffix_text.length()
		candidate = base_name.substr(0, maxi(1, allowed_base_length)).strip_edges() + suffix_text
		suffix += 1
	return candidate

func _identity_nickname_taken(candidate: String, excluded_peer_id: int) -> bool:
	for key: Variant in player_identities.keys():
		var peer_id: int = int(key)
		if peer_id == excluded_peer_id:
			continue
		var identity: PlayerIdentity = player_identities[peer_id] as PlayerIdentity
		if identity != null and identity.nickname.to_lower() == candidate.to_lower():
			return true
	return false

func _next_available_identity_color(requested_index: int, excluded_peer_id: int) -> int:
	for offset: int in range(PlayerIdentity.palette_size()):
		var candidate: int = (requested_index + offset) % PlayerIdentity.palette_size()
		var taken: bool = false
		for key: Variant in player_identities.keys():
			var peer_id: int = int(key)
			if peer_id == excluded_peer_id:
				continue
			var identity: PlayerIdentity = player_identities[peer_id] as PlayerIdentity
			if identity != null and identity.color_index == candidate:
				taken = true
				break
		if not taken:
			return candidate
	return -1

func get_player_identity(peer_id: int) -> PlayerIdentity:
	return player_identities.get(peer_id) as PlayerIdentity

func get_local_player_identity() -> PlayerIdentity:
	return get_player_identity(multiplayer.get_unique_id())

func get_identity_summary() -> Array[Dictionary]:
	var summary: Array[Dictionary] = []
	var peer_ids: Array[int] = []
	for key: Variant in player_identities.keys():
		peer_ids.append(int(key))
	peer_ids.sort()
	for peer_id: int in peer_ids:
		var identity: PlayerIdentity = player_identities[peer_id] as PlayerIdentity
		if identity != null:
			summary.append(identity.to_network_data())
	return summary

func _publish_identity_roster() -> void:
	identity_roster_changed.emit()
	if peer != null and is_host:
		_receive_identity_roster.rpc(get_identity_summary())

@rpc("authority", "call_remote", "reliable", 0)
func _receive_identity_roster(identities: Array[Dictionary]) -> void:
	if not validate_rpc(TUNING.PEER_ID_HOST):
		return
	var received: Dictionary = {}
	var used_colors: Dictionary = {}
	for data: Dictionary in identities:
		var peer_id: int = int(data.get("peer_id", 0))
		var nickname: String = str(data.get("nickname", "")).strip_edges()
		var color_index: int = int(data.get("color_index", -1))
		if peer_id <= 0 or nickname.is_empty() or color_index < 0 or color_index >= PlayerIdentity.palette_size():
			_debug_warn("Rejected malformed identity roster entry")
			return
		if received.has(peer_id) or used_colors.has(color_index):
			_debug_warn("Rejected duplicate peer/color in identity roster")
			return
		received[peer_id] = PlayerIdentity.new(peer_id, nickname, color_index)
		used_colors[color_index] = true
	player_identities = received
	identity_roster_changed.emit()
	_debug_log("Identity roster received: %d players" % player_identities.size())

func _command_identity_status(_args: Array[Variant]) -> String:
	return "identities=%s" % [get_identity_summary()]

func _command_identity_set(args: Array[Variant]) -> String:
	if args.is_empty() or args.size() > 2:
		return "Usage: identity_set <nickname> [color_index 0-9]"
	var color_index: int = 0 if args.size() == 1 else int(str(args[1]))
	if args.size() == 2 and not str(args[1]).is_valid_int():
		return "Color index must be an integer from 0 to 9."
	return "Identity request submitted." if request_identity(str(args[0]), color_index) else "Identity request rejected."


func submit_combat_input(owner_id: int, pressed: bool) -> bool:
	if peer == null or is_host:
		return _receive_combat_input(owner_id, pressed)
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return false
	# Mirror only the local held-input state for immediate local action gating.
	# The host still owns the authoritative timestamp and attack decision.
	if pressed:
		_combat_press_times[owner_id] = Time.get_ticks_msec() / 1000.0
	else:
		_combat_press_times.erase(owner_id)
	_submit_combat_input.rpc_id(TUNING.PEER_ID_HOST, pressed)
	return true

@rpc("any_peer", "call_remote", "reliable", 0)
func _submit_combat_input(pressed: bool) -> void:
	if not is_host or not validate_rpc():
		return
	_receive_combat_input(multiplayer.get_remote_sender_id(), pressed)

func submit_parry_input(owner_id: int) -> bool:
	if peer == null or is_host:
		return _receive_parry_input(owner_id)
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return false
	_submit_parry_input.rpc_id(TUNING.PEER_ID_HOST)
	return true

@rpc("any_peer", "call_remote", "reliable", 0)
func _submit_parry_input() -> void:
	if not is_host or not validate_rpc():
		return
	_receive_parry_input(multiplayer.get_remote_sender_id())

func _receive_parry_input(owner_id: int) -> bool:
	if peer != null and not is_host:
		return false
	if not can_start_parry(owner_id):
		combat_parry_rejected += 1
		_combat_log("Parry rejected peer=%d" % owner_id)
		return false
	var now: float = Time.get_ticks_msec() / 1000.0
	_active_parries[owner_id] = {"expires_at": now + TUNING.PARRY_GRACE_SECONDS}
	if peer != null:
		_parry_start.rpc(owner_id, TUNING.PARRY_GRACE_SECONDS)
	_play_parry_start(owner_id)
	_combat_log("Parry started peer=%d window=%.2f s" % [owner_id, TUNING.PARRY_GRACE_SECONDS])
	return true

func cancel_combat_input(owner_id: int) -> bool:
	if peer == null or is_host:
		return _receive_combat_cancel(owner_id)
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return false
	_combat_press_times.erase(owner_id)
	_submit_combat_cancel.rpc_id(TUNING.PEER_ID_HOST)
	return true

@rpc("any_peer", "call_remote", "reliable", 0)
func _submit_combat_cancel() -> void:
	if not is_host or not validate_rpc():
		return
	_receive_combat_cancel(multiplayer.get_remote_sender_id())

func _receive_combat_cancel(owner_id: int) -> bool:
	if peer != null and not is_host:
		return false
	if not _combat_press_times.has(owner_id):
		return false
	_combat_press_times.erase(owner_id)
	# A charged punch has already fired. Cancelling the held input only re-arms Q.
	if _combat_charged_presses.has(owner_id):
		_combat_charged_presses.erase(owner_id)
		_combat_log("Charged punch input re-armed peer=%d" % owner_id)
		return true
	_cancel_combat_windup(owner_id)
	_combat_log("Wind-up cancelled peer=%d" % owner_id)
	return true

func _receive_combat_input(owner_id: int, pressed: bool) -> bool:
	if peer != null and not is_host:
		return _combat_reject(owner_id, "not host")
	var actor: Node3D = movement_players.get(owner_id) as Node3D
	if not is_instance_valid(actor) or actor.is_queued_for_deletion():
		return _combat_reject(owner_id, "no active player for sender")
	var now: float = Time.get_ticks_msec() / 1000.0
	if pressed:
		if not _combat_actor_can_attack(actor, owner_id):
			return _combat_reject(owner_id, "actor state blocks combat")
		if _combat_press_times.has(owner_id):
			return false
		_combat_press_times[owner_id] = now
		if peer != null:
			_combat_windup.rpc(owner_id)
		_play_combat_windup(owner_id)
		_combat_log("Punch hold started peer=%d" % owner_id)
		return true
	if not _combat_press_times.has(owner_id):
		return _combat_reject(owner_id, "release without press")
	var held_seconds: float = now - float(_combat_press_times[owner_id])
	if _combat_charged_presses.has(owner_id):
		_combat_press_times.erase(owner_id)
		_combat_charged_presses.erase(owner_id)
		_combat_log("Charged punch input released/re-armed peer=%d" % owner_id)
		return true
	if held_seconds >= TUNING.CHARGED_PUNCH_HOLD_SECONDS:
		var charged_started: bool = _begin_charged_punch(owner_id, now)
		_combat_press_times.erase(owner_id)
		_combat_charged_presses.erase(owner_id)
		return charged_started
	_combat_press_times.erase(owner_id)
	if not _combat_actor_can_attack(actor, owner_id):
		_cancel_combat_windup(owner_id)
		return _combat_reject(owner_id, "actor state changed before jab")
	if now < float(_combat_jab_ready_times.get(owner_id, 0.0)):
		_cancel_combat_windup(owner_id)
		return _combat_reject(owner_id, "jab cooldown")
	var camera: Camera3D = actor.get_node_or_null("Head/Camera3D") as Camera3D
	if camera == null:
		_cancel_combat_windup(owner_id)
		return _combat_reject(owner_id, "attacker camera missing")
	var direction: Vector3 = -camera.global_basis.z
	if direction.length_squared() < 0.0001 or not direction.is_finite():
		_cancel_combat_windup(owner_id)
		return _combat_reject(owner_id, "invalid attack direction")
	direction = direction.normalized()
	_combat_jab_ready_times[owner_id] = now + TUNING.JAB_COOLDOWN_SECONDS
	_active_jabs[owner_id] = {"elapsed": 0.0, "origin": camera.global_position, "direction": direction, "hit": false}
	combat_jabs += 1
	if peer != null:
		_combat_jab.rpc(owner_id, direction)
	_play_combat_jab(owner_id, direction)
	_combat_log("Jab accepted peer=%d held=%.3f s" % [owner_id, held_seconds])
	return true

func _advance_parries() -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	for owner_key: Variant in _active_parries.keys():
		var owner_id: int = int(owner_key)
		var parry: Dictionary = _active_parries.get(owner_id, {})
		if now >= float(parry.get("expires_at", 0.0)):
			_finish_parry(owner_id, false, "window expired")

func _advance_combat_holds() -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	for owner_key: Variant in _combat_press_times.keys():
		var owner_id: int = int(owner_key)
		if _combat_charged_presses.has(owner_id):
			continue
		if now - float(_combat_press_times.get(owner_id, now)) < TUNING.CHARGED_PUNCH_HOLD_SECONDS:
			continue
		_begin_charged_punch(owner_id, now)

func _begin_charged_punch(owner_id: int, now: float) -> bool:
	if _combat_charged_presses.has(owner_id):
		return true
	# Consume this press before validation so it cannot fall back into a jab.
	_combat_charged_presses[owner_id] = true
	var actor: Node3D = movement_players.get(owner_id) as Node3D
	if not _combat_actor_can_attack(actor, owner_id):
		_cancel_combat_windup(owner_id)
		return _combat_reject(owner_id, "actor state blocks charged punch")
	if now < float(_charged_punch_ready_times.get(owner_id, 0.0)):
		_cancel_combat_windup(owner_id)
		return _combat_reject(owner_id, "charged punch cooldown")
	var camera: Camera3D = actor.get_node_or_null("Head/Camera3D") as Camera3D
	if camera == null:
		_cancel_combat_windup(owner_id)
		return _combat_reject(owner_id, "attacker camera missing")
	var direction: Vector3 = -camera.global_basis.z
	if not direction.is_finite() or direction.length_squared() < 0.0001:
		_cancel_combat_windup(owner_id)
		return _combat_reject(owner_id, "invalid charged-punch direction")
	direction = direction.normalized()
	_charged_punch_ready_times[owner_id] = now + TUNING.CHARGED_PUNCH_COOLDOWN_SECONDS
	_combat_action_lock_until[owner_id] = now + TUNING.CHARGED_PUNCH_COOLDOWN_SECONDS
	_active_lunges[owner_id] = {"elapsed": 0.0, "direction": direction}
	combat_charged_punches += 1
	if peer != null:
		_combat_lunge_start.rpc(owner_id, direction)
	_play_combat_lunge_start(owner_id, direction)
	_combat_log("Charged punch fired peer=%d direction=%s" % [owner_id, str(direction)])
	return true

func _advance_combat_lunges(delta: float) -> void:
	for owner_key: Variant in _active_lunges.keys():
		var owner_id: int = int(owner_key)
		if not _active_lunges.has(owner_id):
			continue
		var lunge: Dictionary = _active_lunges[owner_id]
		var actor: CharacterBody3D = movement_players.get(owner_id) as CharacterBody3D
		if not is_instance_valid(actor) or actor.is_queued_for_deletion() or bool(actor.get("is_limp")):
			_finish_combat_lunge(owner_id, "attacker unavailable")
			continue
		lunge["elapsed"] = float(lunge.get("elapsed", 0.0)) + delta
		var camera: Camera3D = actor.get_node_or_null("Head/Camera3D") as Camera3D
		if camera != null:
			var desired: Vector3 = -camera.global_basis.z
			var current: Vector3 = lunge.get("direction", desired)
			var direction: Vector3 = COMBAT_CONTROLLER_SCRIPT.steer_lunge_direction(current, desired, delta)
			lunge["direction"] = direction
			var hit_results: Array[Dictionary] = COMBAT_HIT_DETECTOR.trace_lunge_targets(
				actor,
				camera.global_position,
				direction,
				TUNING.CHARGED_PUNCH_RANGE_M
			)
			var hit_any_player: bool = false
			for hit_result: Dictionary in hit_results:
				if _apply_charged_lunge_hit(hit_result, owner_id, direction):
					hit_any_player = true
			if hit_any_player:
				_finish_combat_lunge(owner_id, "hit")
				continue
		if float(lunge.get("elapsed", 0.0)) >= TUNING.LUNGE_DURATION_S:
			_finish_combat_lunge(owner_id, "miss")
		else:
			_active_lunges[owner_id] = lunge

func _apply_charged_lunge_hit(result: Dictionary, attacker_id: int, attack_direction: Vector3) -> bool:
	var target: Node3D = result.get("target") as Node3D
	var attacker: Node3D = movement_players.get(attacker_id) as Node3D
	if not is_instance_valid(target) or target.is_queued_for_deletion() or bool(target.get("is_limp")) or bool(target.get("is_recovering")):
		return false
	if not is_instance_valid(attacker) or attacker.is_queued_for_deletion() or bool(attacker.get("is_limp")):
		return false
	var target_id: int = int(target.get("input_peer_id"))
	if target_id == attacker_id:
		return false
	var impact_position: Vector3 = result.get("position", target.global_position + Vector3.UP * 0.9)
	if _active_parries.has(target_id):
		return _resolve_parry(attacker_id, target_id, impact_position, attack_direction)
	var target_rig: Node3D = target.get("rig") as Node3D
	if not is_instance_valid(target_rig) or not start_ragdoll_spike(target_id):
		return false
	var launch_direction: Vector3 = get_charged_launch_direction(attacker.global_position, impact_position, attack_direction)
	var impulse_applied: bool = bool(target_rig.call("apply_combat_impulse", launch_direction, impact_position, TUNING.CHARGED_PUNCH_LAUNCH_SPEED_MPS))
	combat_lunge_hits += 1
	_combat_log("Charged lunge hit attacker=%d target=%d launch=%s impulse=%s" % [attacker_id, target_id, str(launch_direction), impulse_applied])
	return true

## Builds a bounded launch vector away from the actual attacker/impact position.
## Horizontal direction follows the hit angle; elevation responds to the strike
## pitch and relative impact height without turning the hit into a huge launch.
static func get_charged_launch_direction(attacker_position: Vector3, impact_position: Vector3, attack_direction: Vector3) -> Vector3:
	if not attacker_position.is_finite() or not impact_position.is_finite():
		return attack_direction.normalized() if attack_direction.is_finite() and attack_direction.length_squared() > 0.0001 else Vector3.FORWARD
	var away: Vector3 = impact_position - attacker_position
	var horizontal: Vector3 = Vector3(away.x, 0.0, away.z)
	var horizontal_distance: float = horizontal.length()
	if horizontal_distance < 0.0001:
		horizontal = Vector3(attack_direction.x, 0.0, attack_direction.z)
		horizontal_distance = horizontal.length()
	if horizontal_distance < 0.0001:
		horizontal = Vector3.FORWARD
		horizontal_distance = 1.0
	horizontal = horizontal.normalized()
	var relative_slope: float = clampf(away.y / maxf(horizontal_distance, 0.5), -0.35, 0.35)
	var aim_elevation: float = 0.0
	if attack_direction.is_finite() and attack_direction.length_squared() > 0.0001:
		aim_elevation = clampf(attack_direction.normalized().y, -0.75, 0.75)
	var lift: float = clampf(TUNING.CHARGED_PUNCH_LAUNCH_BASE_LIFT + aim_elevation * 0.14 + relative_slope * 0.18, 0.22, TUNING.CHARGED_PUNCH_LAUNCH_MAX_LIFT)
	return (horizontal + Vector3.UP * lift).normalized()

func _finish_combat_lunge(owner_id: int, reason: String) -> void:
	if not _active_lunges.has(owner_id):
		return
	_active_lunges.erase(owner_id)
	_play_combat_lunge_stop(owner_id)
	if peer != null:
		_combat_lunge_stop.rpc(owner_id)
	_combat_log("Charged lunge ended peer=%d reason=%s" % [owner_id, reason])

func cancel_combat_state(owner_id: int) -> void:
	if peer != null and not is_host:
		return
	if _active_parries.has(owner_id):
		_finish_parry(owner_id, false, "forced state change")
	_combat_press_times.erase(owner_id)
	_combat_charged_presses.erase(owner_id)
	_combat_action_lock_until.erase(owner_id)
	_cancel_combat_windup(owner_id)
	if _active_lunges.has(owner_id):
		_finish_combat_lunge(owner_id, "forced state change")

## Includes a held Q charge as well as the post-launch recovery lock.
func is_combat_action_locked(owner_id: int) -> bool:
	if _active_parries.has(owner_id) or _combat_press_times.has(owner_id):
		return true
	return Time.get_ticks_msec() / 1000.0 < float(_combat_action_lock_until.get(owner_id, 0.0))

## Host validates the actor state and cooldown; clients submit intent only.
func can_start_parry(owner_id: int) -> bool:
	var now: float = Time.get_ticks_msec() / 1000.0
	if is_combat_action_locked(owner_id) or _active_parries.has(owner_id) or _active_jabs.has(owner_id) or now < float(_parry_ready_times.get(owner_id, 0.0)):
		return false
	var actor: Node3D = movement_players.get(owner_id) as Node3D
	if not is_instance_valid(actor) or actor.is_queued_for_deletion() or int(actor.get("input_peer_id")) != owner_id:
		return false
	if bool(actor.get("is_limp")) or bool(actor.get("is_recovering")) or bool(actor.get("terminal_movement_locked")):
		return false
	if bool(actor.call("is_carrying")) or bool(actor.call("is_carried")):
		return false
	return true

func _combat_actor_can_attack(actor: Node3D, owner_id: int) -> bool:
	if not is_instance_valid(actor) or actor.is_queued_for_deletion() or int(actor.get("input_peer_id")) != owner_id:
		return false
	if Time.get_ticks_msec() / 1000.0 < float(_combat_action_lock_until.get(owner_id, 0.0)):
		return false
	if _active_parries.has(owner_id):
		return false
	if bool(actor.get("is_limp")) or bool(actor.get("is_recovering")) or bool(actor.get("terminal_movement_locked")):
		return false
	if bool(actor.call("is_carrying")) or bool(actor.call("is_carried")):
		return false
	return true

func _combat_reject(owner_id: int, reason: String) -> bool:
	combat_rejected += 1
	_debug_warn("Combat input rejected peer=%d: %s" % [owner_id, reason])
	return false

func _play_combat_windup(owner_id: int) -> void:
	var player: Node = movement_players.get(owner_id)
	if is_instance_valid(player):
		player.call("play_combat_windup")

func _cancel_combat_windup(owner_id: int) -> void:
	if peer != null:
		_combat_cancel.rpc(owner_id)
	_play_combat_cancel(owner_id)

func _play_combat_cancel(owner_id: int) -> void:
	var player: Node = movement_players.get(owner_id)
	if is_instance_valid(player):
		player.call("cancel_combat_presentation")

func _play_combat_jab(owner_id: int, direction: Vector3) -> void:
	var player: Node = movement_players.get(owner_id)
	if is_instance_valid(player):
		player.call("play_combat_jab", direction)

func _play_combat_lunge_start(owner_id: int, direction: Vector3) -> void:
	var player: Node = movement_players.get(owner_id)
	if is_instance_valid(player):
		player.call("begin_combat_lunge", direction)

func _play_combat_lunge_stop(owner_id: int) -> void:
	var player: Node = movement_players.get(owner_id)
	if is_instance_valid(player):
		player.call("stop_combat_lunge")

func _advance_parry_state(owner_id: int) -> void:
	var player: Node = movement_players.get(owner_id)
	if is_instance_valid(player):
		player.call("begin_parry_presentation")

func _play_parry_start(owner_id: int) -> void:
	_advance_parry_state(owner_id)

func _play_parry_hit(owner_id: int, world_position: Vector3) -> void:
	var player: Node = movement_players.get(owner_id)
	if is_instance_valid(player):
		player.call("play_parry_hit", world_position)

func _play_parry_end(owner_id: int, successful: bool) -> void:
	var player: Node = movement_players.get(owner_id)
	if is_instance_valid(player):
		player.call("end_parry_presentation", successful)

func _finish_parry(owner_id: int, successful: bool, reason: String) -> void:
	if not _active_parries.has(owner_id):
		return
	_active_parries.erase(owner_id)
	_parry_ready_times[owner_id] = Time.get_ticks_msec() / 1000.0 + TUNING.PARRY_COOLDOWN_SECONDS
	_play_parry_end(owner_id, successful)
	if peer != null and is_host:
		_parry_end.rpc(owner_id, successful)
	_combat_log("Parry ended peer=%d success=%s reason=%s cooldown=%.2f s" % [owner_id, successful, reason, TUNING.PARRY_COOLDOWN_SECONDS])

func _resolve_parry(attacker_id: int, defender_id: int, impact_position: Vector3, attack_direction: Vector3) -> bool:
	if not _active_parries.has(defender_id):
		return false
	var attacker: Node3D = movement_players.get(attacker_id) as Node3D
	var defender: Node3D = movement_players.get(defender_id) as Node3D
	if not is_instance_valid(attacker) or not is_instance_valid(defender) or bool(attacker.get("is_limp")) or bool(attacker.get("is_recovering")):
		return false
	var attacker_rig: Node3D = attacker.get("rig") as Node3D
	if not is_instance_valid(attacker_rig) or not start_ragdoll_spike(attacker_id):
		return false
	var attacker_impact: Vector3 = attacker.global_position + Vector3.UP * 0.9
	var defender_center: Vector3 = defender.global_position + Vector3.UP * 0.9
	var reflected_direction: Vector3 = get_charged_launch_direction(defender_center, attacker_impact, -attack_direction)
	var impulse_applied: bool = bool(attacker_rig.call("apply_combat_impulse", reflected_direction, attacker_impact, TUNING.PARRY_REFLECT_LAUNCH_SPEED_MPS))
	_play_parry_hit(defender_id, impact_position)
	if peer != null and is_host:
		_parry_hit.rpc(defender_id, impact_position)
	combat_parries += 1
	_finish_parry(defender_id, true, "punch reflected")
	_combat_log("Parry reflected attacker=%d defender=%d launch=%s impulse=%s" % [attacker_id, defender_id, str(reflected_direction), impulse_applied])
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _parry_start(owner_id: int, remaining_seconds: float) -> void:
	if not validate_rpc(TUNING.PEER_ID_HOST) or not is_finite(remaining_seconds):
		return
	var remaining: float = clampf(remaining_seconds, 0.0, TUNING.PARRY_GRACE_SECONDS)
	if remaining <= 0.0:
		return
	_active_parries[owner_id] = {"expires_at": Time.get_ticks_msec() / 1000.0 + remaining}
	_play_parry_start(owner_id)

@rpc("authority", "call_remote", "reliable", 0)
func _parry_hit(owner_id: int, world_position: Vector3) -> void:
	if not validate_rpc(TUNING.PEER_ID_HOST) or not world_position.is_finite():
		return
	_play_parry_hit(owner_id, world_position)

@rpc("authority", "call_remote", "reliable", 0)
func _parry_end(owner_id: int, successful: bool) -> void:
	if not validate_rpc(TUNING.PEER_ID_HOST):
		return
	_active_parries.erase(owner_id)
	_parry_ready_times[owner_id] = Time.get_ticks_msec() / 1000.0 + TUNING.PARRY_COOLDOWN_SECONDS
	_play_parry_end(owner_id, successful)

func _apply_jab_hit(result: Dictionary, attacker_id: int, direction: Vector3, attacker_velocity: Vector3) -> bool:
	var target: Node3D = result.get("target") as Node3D
	if not is_instance_valid(target) or target.is_queued_for_deletion() or bool(target.get("is_recovering")):
		return false
	var target_id: int = int(target.get("input_peer_id"))
	var impact_position: Vector3 = result.get("position", target.global_position + Vector3.UP * 0.9)
	if _active_parries.has(target_id):
		return _resolve_parry(attacker_id, target_id, impact_position, direction)
	var impact_strength: float = get_jab_impact_strength(attacker_velocity, direction)
	if bool(target.get("is_limp")):
		var target_rig: Node3D = target.get("rig") as Node3D
		if target_rig == null:
			return false
		var applied: bool = bool(target_rig.call("apply_combat_impulse", direction, result.get("position", target.global_position), TUNING.JAB_LIMP_IMPULSE_MPS))
		if not applied:
			return false
	else:
		if peer != null:
			_combat_recoil.rpc(target_id, direction, impact_strength)
		_receive_combat_recoil(target_id, direction, impact_strength)
	_combat_log("Jab hit peer=%d limp=%s impact=%.2f" % [int(target.get("input_peer_id")), bool(target.get("is_limp")), impact_strength])
	return true

static func get_jab_impact_strength(attacker_velocity: Vector3, jab_direction: Vector3) -> float:
	if not attacker_velocity.is_finite() or not jab_direction.is_finite() or jab_direction.length_squared() < 0.0001:
		return 1.0
	var forward_speed: float = maxf(attacker_velocity.dot(jab_direction.normalized()), 0.0)
	return clampf(1.0 + (forward_speed / 8.0) * 0.35, 1.0, 1.35)

func _receive_combat_recoil(target_id: int, direction: Vector3, strength: float = 1.0) -> void:
	var target: Node = movement_players.get(target_id)
	if is_instance_valid(target):
		target.call("apply_combat_recoil", direction, clampf(strength, 1.0, 1.35))

@rpc("authority", "call_remote", "reliable", 0)
func _combat_windup(owner_id: int) -> void:
	if not validate_rpc(TUNING.PEER_ID_HOST):
		return
	_play_combat_windup(owner_id)

@rpc("authority", "call_remote", "reliable", 0)
func _combat_cancel(owner_id: int) -> void:
	if not validate_rpc(TUNING.PEER_ID_HOST):
		return
	_combat_press_times.erase(owner_id)
	_combat_charged_presses.erase(owner_id)
	_combat_action_lock_until.erase(owner_id)
	_play_combat_cancel(owner_id)

@rpc("authority", "call_remote", "reliable", 0)
func _combat_jab(owner_id: int, direction: Vector3) -> void:
	if not validate_rpc(TUNING.PEER_ID_HOST) or not direction.is_finite() or direction.length_squared() < 0.0001:
		return
	_play_combat_jab(owner_id, direction.normalized())

@rpc("authority", "call_remote", "reliable", 0)
func _combat_lunge_start(owner_id: int, direction: Vector3) -> void:
	if not validate_rpc(TUNING.PEER_ID_HOST) or not direction.is_finite() or direction.length_squared() < 0.0001:
		return
	_combat_action_lock_until[owner_id] = Time.get_ticks_msec() / 1000.0 + TUNING.CHARGED_PUNCH_COOLDOWN_SECONDS
	_play_combat_lunge_start(owner_id, direction.normalized())

@rpc("authority", "call_remote", "reliable", 0)
func _combat_lunge_stop(owner_id: int) -> void:
	if not validate_rpc(TUNING.PEER_ID_HOST):
		return
	_play_combat_lunge_stop(owner_id)

@rpc("authority", "call_remote", "reliable", 0)
func _combat_recoil(target_id: int, direction: Vector3, strength: float = 1.0) -> void:
	if not validate_rpc(TUNING.PEER_ID_HOST) or not direction.is_finite() or direction.length_squared() < 0.0001:
		return
	_receive_combat_recoil(target_id, direction.normalized(), clampf(strength, 1.0, 1.35))

func _combat_log(message: String) -> void:
	var debug_hub: Node = get_node_or_null("/root/DebugHub")
	if debug_hub != null:
		debug_hub.call("log", &"combat", message)

func _debug_log(message: String) -> void:
	var debug_hub: Node = get_node_or_null("/root/DebugHub")
	if debug_hub != null:
		debug_hub.call("log", &"net", message)

## Host and client inputs (including console commands) share this intent path.
func request_interaction(target_path: NodePath, action: StringName) -> bool:
	if peer == null or is_host:
		var owner_id: int = multiplayer.get_unique_id()
		if peer == null and movement_players.has(0):
			owner_id = 0
		return _receive_interaction(owner_id, target_path, action)
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return false
	_submit_interaction.rpc_id(TUNING.PEER_ID_HOST, target_path, action)
	return true # Submitted; the reliable result is reported separately.

@rpc("any_peer", "call_remote", "reliable", 0)
func _submit_interaction(target_path: NodePath, action: StringName) -> void:
	if is_host and validate_rpc():
		_receive_interaction(multiplayer.get_remote_sender_id(), target_path, action)

func _receive_interaction(owner_id: int, target_path: NodePath, action: StringName) -> bool:
	var now: float = Time.get_ticks_msec() / 1000.0
	var reason: String = ""
	var target: Interactable = null
	if now - float(_interaction_times.get(owner_id, -INF)) < TUNING.INTERACT_REQUEST_INTERVAL_S:
		reason = "request cooldown"
	else:
		_interaction_times[owner_id] = now
		var actor: Node3D = movement_players.get(owner_id) as Node3D
		target = get_node_or_null(target_path) as Interactable
		reason = _interaction_rejection(actor, target, action)
		if reason.is_empty() and not target.interact(actor, action):
			reason = "target state changed"
	var accepted: bool = reason.is_empty()
	if accepted:
		interaction_accepted += 1
		_publish_hand_poke(owner_id, target)
	else:
		interaction_rejected += 1
	var message: String = "Interaction %s peer=%d action=%s%s" % ["accepted" if accepted else "rejected", owner_id, action, "" if accepted else ": " + reason]
	_interaction_log(message)
	if owner_id == TUNING.PEER_ID_HOST or peer == null:
		_finish_local_interaction_hand(owner_id, accepted)
	elif is_host:
		_interaction_result.rpc_id(owner_id, owner_id, accepted, message)
	return accepted

## Replicate the local owner's current hover target to other players' camera-attached Viewmodel hands.
## Clients submit only the hover state; the host derives the owner from the RPC sender.
func update_hand_hover(active: bool, world_point: Vector3) -> void:
	var owner_id: int = multiplayer.get_unique_id()
	if peer == null and movement_players.has(0):
		owner_id = 0
	if active and not world_point.is_finite():
		return
	if peer == null or is_host:
		_receive_hand_hover(owner_id, active, world_point)
	elif peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		_submit_hand_hover.rpc_id(TUNING.PEER_ID_HOST, active, world_point)

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _submit_hand_hover(active: bool, world_point: Vector3) -> void:
	if not is_host or not validate_rpc():
		return
	if active and not world_point.is_finite():
		return
	_receive_hand_hover(multiplayer.get_remote_sender_id(), active, world_point)

func _receive_hand_hover(owner_id: int, active: bool, world_point: Vector3) -> void:
	if active and not world_point.is_finite():
		return
	var player: Node = movement_players.get(owner_id)
	if not is_instance_valid(player) or player.is_queued_for_deletion():
		return
	# Count a hover only when this instance actually applies it to a remote
	# Viewmodel hand. The owning peer intentionally rejects its own copy.
	if bool(player.call("set_world_hand_hover", active, world_point)):
		hand_hover_received += 1
	if peer != null and is_host:
		hand_hover_sent += 1
		_hand_hover.rpc(owner_id, active, world_point)

@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _hand_hover(owner_id: int, active: bool, world_point: Vector3) -> void:
	if not validate_rpc(TUNING.PEER_ID_HOST):
		return
	if active and not world_point.is_finite():
		return
	var player: Node = movement_players.get(owner_id)
	if is_instance_valid(player) and not player.is_queued_for_deletion():
		if bool(player.call("set_world_hand_hover", active, world_point)):
			hand_hover_received += 1

func _interaction_rejection(actor: Node3D, target: Interactable, action: StringName) -> String:
	if not is_instance_valid(actor) or actor.is_queued_for_deletion():
		return "no active actor for sender"
	var owner_id: int = int(actor.get("input_peer_id"))
	if _active_parries.has(owner_id):
		return "parry blocks interaction"
	if is_combat_action_locked(owner_id):
		return "charged punch blocks interaction"
	if bool(actor.get("is_limp")):
		return "actor is limp"
	var carrier: Node = actor.get_node_or_null("Carrier")
	if carrier != null and bool(carrier.call("is_holding")):
		return "actor is carrying"
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		return "unknown target"
	var body: Node3D = target.get_parent() as Node3D
	if body == null or body.is_queued_for_deletion() or not target.can_interact(actor, action):
		return "target unavailable or unsupported action"
	var camera: Camera3D = actor.get_node_or_null("Head/Camera3D") as Camera3D
	if camera == null:
		return "actor has no interaction origin"
	var origin: Vector3 = camera.global_position
	# Remote visuals lag; use the most recent host-accepted actor position.
	if peer != null and not bool(actor.get("is_local_player")):
		origin += Vector3(actor.get("accepted_position")) - actor.global_position
	var target_position: Vector3 = body.global_position
	if body.has_method("get_interaction_world_position"):
		target_position = Vector3(body.call("get_interaction_world_position"))
	if not origin.is_finite() or not target_position.is_finite():
		return "invalid interaction position"
	var mask: int = (1 << (LAYERS.WORLD_STATIC - 1)) | (1 << (LAYERS.DEVICES - 1)) | (1 << (LAYERS.PROPS - 1)) | (1 << (LAYERS.ELEVATOR - 1)) | (1 << (LAYERS.LIMP_BODIES - 1))
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, target_position, mask)
	if actor is CollisionObject3D:
		query.exclude = [actor.get_rid()]
	var hit: Dictionary = actor.get_world_3d().direct_space_state.intersect_ray(query)
	var contact: Vector3 = target_position
	if not hit.is_empty():
		var collider: Node = hit.collider as Node
		if collider != body and not body.is_ancestor_of(collider):
			return "target obstructed"
		contact = hit.position
	if origin.distance_to(contact) > TUNING.REACH_M:
		return "out of reach"
	return ""

func _finish_local_interaction_hand(owner_id: int, accepted: bool) -> void:
	var player: Node = movement_players.get(owner_id)
	if is_instance_valid(player) and not player.is_queued_for_deletion():
		player.call("finish_local_hand_action", accepted)

@rpc("authority", "call_remote", "reliable", 0)
func _interaction_result(owner_id: int, accepted: bool, message: String) -> void:
	if not validate_rpc(TUNING.PEER_ID_HOST):
		return
	_finish_local_interaction_hand(owner_id, accepted)
	_interaction_log(message)

## Host broadcasts a cosmetic poke only after the gameplay interaction is accepted.
func _publish_hand_poke(owner_id: int, target: Interactable) -> void:
	if peer == null or not is_host or not is_instance_valid(target):
		return
	var body: Node3D = target.get_parent() as Node3D
	if not is_instance_valid(body):
		return
	var point: Vector3 = body.global_position
	if body.has_method("get_interaction_world_position"):
		point = Vector3(body.call("get_interaction_world_position"))
	if not point.is_finite():
		return
	_receive_hand_poke(owner_id, point)
	hand_poke_sent += 1
	_hand_poke.rpc(owner_id, point)

@rpc("authority", "call_remote", "reliable", 0)
func _hand_poke(owner_id: int, world_point: Vector3) -> void:
	if not validate_rpc(TUNING.PEER_ID_HOST) or not world_point.is_finite():
		return
	_receive_hand_poke(owner_id, world_point)

func _receive_hand_poke(owner_id: int, world_point: Vector3) -> void:
	if not world_point.is_finite():
		return
	var player: Node = movement_players.get(owner_id)
	if not is_instance_valid(player) or player.is_queued_for_deletion():
		return
	if bool(player.get("is_limp")) or bool(player.get("is_recovering")) or bool(player.call("is_carrying")):
		return
	if bool(player.call("play_world_hand_poke", world_point)):
		hand_poke_received += 1
		_debug_log("Hand poke mirrored for peer %d" % owner_id)

func _interaction_log(message: String) -> void:
	get_node("/root/DebugHub").call("log", &"interact", message)

func _debug_warn(message: String) -> void:
	var debug_hub: Node = get_node_or_null("/root/DebugHub")
	if debug_hub != null:
		debug_hub.call("warn", &"net", message)



# ---------------------------------------------------------------------
# Carry / drop / throw (host-authoritative)
# Clients send intent only. The host validates, mutates its own Carrier +
# Prop, then broadcasts a reliable event so every peer mirrors the state.
# ---------------------------------------------------------------------
 
## Local entry point for drop/throw intent (input and console commands).
func request_carry_action(action: StringName, direction: Vector3) -> bool:
	if peer == null or is_host:
		var owner_id: int = multiplayer.get_unique_id()
		if peer == null and movement_players.has(0):
			owner_id = 0
		return _receive_carry_action(owner_id, action, direction)
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return false
	_submit_carry_action.rpc_id(TUNING.PEER_ID_HOST, action, direction)
	return true
 
@rpc("any_peer", "call_remote", "reliable", 0)
func _submit_carry_action(action: StringName, direction: Vector3) -> void:
	if is_host and validate_rpc():
		_receive_carry_action(multiplayer.get_remote_sender_id(), action, direction)
 
func _receive_carry_action(owner_id: int, action: StringName, direction: Vector3) -> bool:
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - float(_carry_times.get(owner_id, -INF)) < TUNING.CARRY_ACTION_INTERVAL_S:
		return _carry_reject(owner_id, action, "request cooldown")
	_carry_times[owner_id] = now
	if action != &"drop" and action != &"throw":
		return _carry_reject(owner_id, action, "unknown action")
	var actor: Node3D = movement_players.get(owner_id) as Node3D
	if not is_instance_valid(actor) or actor.is_queued_for_deletion():
		return _carry_reject(owner_id, action, "no active actor for sender")
	if bool(actor.get("is_limp")):
		return _carry_reject(owner_id, action, "actor is limp")
	var carrier: Node = actor.get_node_or_null("Carrier")
	if carrier == null or not bool(carrier.call("is_holding")):
		return _carry_reject(owner_id, action, "nothing held")
 
	var inherited: Vector3 = Vector3(actor.get("velocity")).limit_length(TUNING.PLAYER_SPEED_MPS)
	if action == &"throw":
		var spin: Vector3 = Vector3(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))
		_release_carried(owner_id, carrier, _throw_velocity(carrier, direction) + inherited, spin)
	else:
		_release_carried(owner_id, carrier, inherited, Vector3.ZERO)
	_debug_log("Carry %s accepted peer=%d" % [action, owner_id])
	return true
 
func _carry_reject(owner_id: int, action: StringName, reason: String) -> bool:
	carry_rejected += 1
	_debug_log("Carry %s rejected peer=%d: %s" % [action, owner_id, reason])
	return false
 
## Trust the client's aim only if it agrees with the host's view of where the
## player is looking; otherwise fall back to the host's own camera forward.
## Limp bodies are thrown slower than props (TUNING.THROW_SPEED_LIMP_MPS).
func _throw_velocity(carrier: Node, requested: Vector3) -> Vector3:
	const MAX_AIM_ERROR_DEG: float = 25.0
	var item: Node3D = carrier.get("held_item") as Node3D
	var item_is_limp: bool = false
	if item != null:
		item_is_limp = item.get("is_limp") == true
	var actor: Node3D = carrier.get_node_or_null("..") as Node3D
	var camera: Camera3D = actor.get_node_or_null("Head/Camera3D") as Camera3D
	var forward: Vector3 = (-camera.global_basis.z if camera != null else -actor.global_basis.z).normalized()
	var dir: Vector3 = forward
	if requested.is_finite() and requested.length() > 0.001:
		var wanted: Vector3 = requested.normalized()
		if wanted.angle_to(forward) <= deg_to_rad(MAX_AIM_ERROR_DEG):
			dir = wanted
	var speed: float = TUNING.THROW_SPEED_LIMP_MPS if item_is_limp else TUNING.THROW_SPEED_MPS
	return dir * speed
 
## Host-only: detach, apply physics, and broadcast.
func _release_carried(owner_id: int, carrier: Node, linear: Vector3, angular: Vector3) -> void:
	var item: Node3D = carrier.get("held_item") as Node3D
	if not is_instance_valid(item):
		return
	var at: Vector3 = item.global_position
	if item.has_method("get_carry_world_position"):
		at = Vector3(item.call("get_carry_world_position"))
	carrier.call("detach_item")
	item.call("apply_release", at, linear, angular)
	if peer != null:
		_carry_release.rpc(owner_id, item.get_path(), at, linear, angular)
 
## Host-only: called by Prop when an accepted "grab" interaction fires.
func host_begin_carry(actor: Node, item: Node3D) -> bool:
	if peer != null and not is_host:
		return false
	var actor_3d: Node3D = actor as Node3D
	if not is_instance_valid(actor_3d) or not is_instance_valid(item) or actor_3d.is_queued_for_deletion():
		return false
	if bool(actor_3d.get("is_limp")) or bool(actor_3d.get("is_recovering")):
		return false
	var carrier: Node = actor_3d.get_node_or_null("Carrier")
	if carrier == null or bool(carrier.call("is_holding")):
		return false
	if not item.has_method("is_carried") or bool(item.call("is_carried")):
		return false
	if item.has_method("set_carry_target") and (not bool(item.get("is_limp")) or bool(item.get("is_recovering"))):
		return false
	var owner_id: int = int(actor_3d.get("input_peer_id"))
	carrier.call("attach_item", item)
	if peer != null:
		_carry_begin.rpc(owner_id, item.get_path())
	_debug_log("Carry begin peer=%d item=%s" % [owner_id, item.get_path()])
	return true
 
## Host-only: drop whatever this player holds (limp, disconnect, etc.).
func force_drop_carry(owner_id: int, reason: String) -> void:
	if peer != null and not is_host:
		return
	var player: Node = movement_players.get(owner_id)
	if not is_instance_valid(player):
		return
	var carrier: Node = player.get_node_or_null("Carrier")
	if carrier == null or not bool(carrier.call("is_holding")):
		return
	var inherited: Vector3 = Vector3(player.get("velocity")).limit_length(TUNING.PLAYER_SPEED_MPS)
	_release_carried(owner_id, carrier, inherited, Vector3.ZERO)
	_debug_log("Carry forced drop peer=%d (%s)" % [owner_id, reason])
 
@rpc("authority", "call_remote", "reliable", 0)
func _carry_begin(owner_id: int, item_path: NodePath) -> void:
	if not validate_rpc(TUNING.PEER_ID_HOST):
		return
	var player: Node = movement_players.get(owner_id)
	var item: Node3D = get_node_or_null(item_path) as Node3D
	if not is_instance_valid(player) or not is_instance_valid(item):
		return
	var carrier: Node = player.get_node_or_null("Carrier")
	if carrier != null:
		carrier.call("attach_item", item)
	_debug_log("Carry begin mirrored peer=%d item=%s" % [owner_id, item_path])
 
@rpc("authority", "call_remote", "reliable", 0)
func _carry_release(owner_id: int, item_path: NodePath, at: Vector3, linear: Vector3, angular: Vector3) -> void:
	if not validate_rpc(TUNING.PEER_ID_HOST):
		return
	if not at.is_finite() or not linear.is_finite() or not angular.is_finite():
		return
	var item: Node3D = get_node_or_null(item_path) as Node3D
	var player: Node = movement_players.get(owner_id)
	if is_instance_valid(player):
		var carrier: Node = player.get_node_or_null("Carrier")
		if carrier != null and carrier.get("held_item") == item:
			carrier.call("detach_item")
	if is_instance_valid(item) and item.has_method("apply_release"):
		item.call("apply_release", at, linear, angular)
	_debug_log("Carry release mirrored peer=%d item=%s at=%s" % [owner_id, item_path, str(at)])
 
## Late joiners learn who is already carrying what.
func _sync_active_parries(peer_id: int) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	for owner_key: Variant in _active_parries.keys():
		var owner_id: int = int(owner_key)
		var parry: Dictionary = _active_parries.get(owner_id, {})
		var remaining: float = maxf(0.0, float(parry.get("expires_at", now)) - now)
		if remaining > 0.0:
			_parry_start.rpc_id(peer_id, owner_id, remaining)

func _sync_active_carries(peer_id: int) -> void:
	if not is_host or peer == null or not connected_peers.has(peer_id):
		return
	for key: Variant in movement_players.keys():
		var owner_id: int = int(key)
		var player: Node = movement_players[owner_id]
		if not is_instance_valid(player):
			continue
		var carrier: Node = player.get_node_or_null("Carrier")
		if carrier != null and bool(carrier.call("is_holding")):
			var item: Node3D = carrier.get("held_item") as Node3D
			_carry_begin.rpc_id(peer_id, owner_id, item.get_path())
 
 
