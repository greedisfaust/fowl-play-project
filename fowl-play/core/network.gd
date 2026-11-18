## Network bootstrap and shared RPC validation for Fowl Play.
## This is the only project script that directly constructs ENet peers.

extends Node

const TUNING = preload("res://core/tuning.gd")
const LAYERS = preload("res://core/layers.gd")

signal session_ended
signal session_started
signal roster_changed

var peer: ENetMultiplayerPeer = null
var is_host: bool = false
var is_client: bool = false
var connected_peers: Array[int] = []
## Host-published session membership, separate from transport connection events.
var roster: Array[int] = []
var status: String = "offline"
var port: int = TUNING.ENET_PORT
var _switching_session: bool = false
var movement_players: Dictionary = {}
var movement_rejected: int = 0
var interaction_rejected: int = 0
var carry_rejected: int = 0
var _carry_times: Dictionary = {}
var interaction_accepted: int = 0
var hand_poke_sent: int = 0
var hand_poke_received: int = 0
var hand_hover_sent: int = 0
var hand_hover_received: int = 0
var _interaction_times: Dictionary = {}
var _ragdoll_epochs: Dictionary = {}
var _pending_ragdoll_starts: Dictionary = {}
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
	hub.call("command", &"net_status", _command_status, "Report local connection state.", false, false)
	hub.call("command", &"net_disconnect", _command_disconnect, "Leave this local network session.", false, false)
	hub.call("command", &"net_host", _command_host, "Host a game on this computer.", false, false)
	hub.call("command", &"net_join", _command_join, "Join an IP: net_join [IP]. Default: 127.0.0.1.", false, false)
	hub.call("command", &"ragdoll_spike_start", _command_ragdoll_start, "Host test: start a player's ragdoll by peer ID.", true, true)
	hub.call("command", &"ragdoll_spike_stop", _command_ragdoll_stop, "Host test: restore a player's standing state by peer ID.", true, true)
	hub.call("watch", &"net/carry_rejected", func() -> int: return carry_rejected)
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
	if peer != null:
		peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	peer = null
	is_host = false
	is_client = false
	connected_peers.clear()
	roster.clear()
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
	ragdoll_pose_sent = 0
	ragdoll_pose_received = 0
	ragdoll_pose_data_bytes_sent = 0
	ragdoll_settled_sent = 0
	ragdoll_settled_received = 0
	ragdoll_send_hz = TUNING.RAGDOLL_SEND_HZ
	carry_rejected = 0
	_carry_times.clear()
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

func unregister_movement_player(owner_id: int, player: Node) -> void:
	if movement_players.get(owner_id) == player:
		movement_players.erase(owner_id)
		_pending_ragdoll_starts.erase(owner_id)

func send_movement(owner_id: int, sequence: int, at: Vector3, speed: Vector3, yaw: float, pitch: float) -> void:
	if peer == null or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	if is_host:
		_receive_movement(owner_id, sequence, at, speed, yaw, pitch)
	else:
		_submit_movement.rpc_id(TUNING.PEER_ID_HOST, sequence, at, speed, yaw, pitch)

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _submit_movement(sequence: int, at: Vector3, speed: Vector3, yaw: float, pitch: float) -> void:
	if not is_host or not validate_rpc():
		return
	# Sender identity selects the player; clients cannot choose another player's ID.
	_receive_movement(multiplayer.get_remote_sender_id(), sequence, at, speed, yaw, pitch)

func _receive_movement(owner_id: int, sequence: int, at: Vector3, speed: Vector3, yaw: float, pitch: float) -> void:
	var player: Node = movement_players.get(owner_id)
	if not is_instance_valid(player):
		return
	if bool(player.get("is_limp")):
		return
	if not bool(player.call("accept_movement", sequence, at, speed, yaw, pitch)):
		movement_rejected += 1
		if owner_id != TUNING.PEER_ID_HOST:
			_correct_movement.rpc_id(owner_id, player.get("accepted_position"))
		return
	_publish_movement.rpc(owner_id, sequence, at, speed, yaw, pitch)

@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _publish_movement(owner_id: int, sequence: int, at: Vector3, speed: Vector3, yaw: float, pitch: float) -> void:
	if not validate_rpc(TUNING.PEER_ID_HOST):
		return
	var player: Node = movement_players.get(owner_id)
	if is_instance_valid(player):
		player.call("receive_movement", sequence, at, speed, yaw, pitch)

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
		_publish_roster()
		_sync_active_ragdolls.call_deferred(peer_id)
		_sync_active_carries.call_deferred(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	_interaction_times.erase(peer_id)
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
	_ragdoll_epochs.erase(peer_id)
	connected_peers.erase(peer_id)
	_debug_log("Peer %d disconnected" % peer_id)
	if is_host:
		_publish_roster()

func _publish_roster() -> void:
	roster = connected_peers.duplicate()
	roster.sort()
	roster_changed.emit()
	_receive_roster.rpc(roster)
	_debug_log("Roster updated: %s" % [roster])

@rpc("authority", "call_remote", "reliable", 0)
func _receive_roster(members: Array[int]) -> void:
	if not validate_rpc(TUNING.PEER_ID_HOST):
		return
	roster = members.duplicate()
	roster_changed.emit()
	_debug_log("Roster received: %s" % [roster])

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
	if is_host and owner_id != TUNING.PEER_ID_HOST:
		_interaction_result.rpc_id(owner_id, message)
	return accepted

## Replicate the local owner's current hover target to other players' world hands.
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
	player.call("set_world_hand_hover", active, world_point)
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

@rpc("authority", "call_remote", "reliable", 0)
func _interaction_result(message: String) -> void:
	if validate_rpc(TUNING.PEER_ID_HOST):
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
 
 
