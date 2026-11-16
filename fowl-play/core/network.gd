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
var interaction_accepted: int = 0
var _interaction_times: Dictionary = {}

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
	hub.call("command", &"net_status", _command_status, "Report local connection state.", false, false)
	hub.call("command", &"net_disconnect", _command_disconnect, "Leave this local network session.", false, false)
	hub.call("command", &"net_host", _command_host, "Host a game on this computer.", false, false)
	hub.call("command", &"net_join", _command_join, "Join an IP: net_join [IP]. Default: 127.0.0.1.", false, false)
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
	_interaction_times.clear()
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

func unregister_movement_player(owner_id: int, player: Node) -> void:
	if movement_players.get(owner_id) == player:
		movement_players.erase(owner_id)

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

func is_host_peer(peer_id: int) -> bool:
	return peer_id == TUNING.PEER_ID_HOST

func _on_peer_connected(peer_id: int) -> void:
	if not connected_peers.has(peer_id):
		connected_peers.append(peer_id)
	_debug_log("Peer %d connected" % peer_id)
	if is_host:
		_publish_roster()

func _on_peer_disconnected(peer_id: int) -> void:
	_interaction_times.erase(peer_id)
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
	if now - float(_interaction_times.get(owner_id, -INF)) < TUNING.INTERACT_REQUEST_INTERVAL_S:
		reason = "request cooldown"
	else:
		_interaction_times[owner_id] = now
		var actor: Node3D = movement_players.get(owner_id) as Node3D
		var target: Interactable = get_node_or_null(target_path) as Interactable
		reason = _interaction_rejection(actor, target, action)
		if reason.is_empty() and not target.interact(actor, action):
			reason = "target state changed"
	var accepted: bool = reason.is_empty()
	if accepted:
		interaction_accepted += 1
	else:
		interaction_rejected += 1
	var message: String = "Interaction %s peer=%d action=%s%s" % ["accepted" if accepted else "rejected", owner_id, action, "" if accepted else ": " + reason]
	_interaction_log(message)
	if is_host and owner_id != TUNING.PEER_ID_HOST:
		_interaction_result.rpc_id(owner_id, message)
	return accepted

func _interaction_rejection(actor: Node3D, target: Interactable, action: StringName) -> String:
	if not is_instance_valid(actor) or actor.is_queued_for_deletion():
		return "no active actor for sender"
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
	if not origin.is_finite() or not body.global_position.is_finite():
		return "invalid interaction position"
	var mask: int = (1 << (LAYERS.WORLD_STATIC - 1)) | (1 << (LAYERS.DEVICES - 1)) | (1 << (LAYERS.PROPS - 1)) | (1 << (LAYERS.ELEVATOR - 1)) | (1 << (LAYERS.LIMP_BODIES - 1))
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, body.global_position, mask)
	if actor is CollisionObject3D:
		query.exclude = [actor.get_rid()]
	var hit: Dictionary = actor.get_world_3d().direct_space_state.intersect_ray(query)
	var contact: Vector3 = body.global_position
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

func _interaction_log(message: String) -> void:
	get_node("/root/DebugHub").call("log", &"interact", message)

func _debug_warn(message: String) -> void:
	var debug_hub: Node = get_node_or_null("/root/DebugHub")
	if debug_hub != null:
		debug_hub.call("warn", &"net", message)
