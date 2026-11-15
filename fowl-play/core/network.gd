## Network bootstrap and shared RPC validation for Fowl Play.
## This is the only project script that directly constructs ENet peers.

extends Node

const TUNING = preload("res://core/tuning.gd")

signal session_ended
signal session_started

var peer: ENetMultiplayerPeer = null
var is_host: bool = false
var is_client: bool = false
var connected_peers: Array[int] = []
var status: String = "offline"
var port: int = TUNING.ENET_PORT
var _switching_session: bool = false

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

func is_host_peer(peer_id: int) -> bool:
	return peer_id == TUNING.PEER_ID_HOST

func _on_peer_connected(peer_id: int) -> void:
	if not connected_peers.has(peer_id):
		connected_peers.append(peer_id)
	_debug_log("Peer %d connected" % peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	connected_peers.erase(peer_id)
	_debug_log("Peer %d disconnected" % peer_id)

func _debug_log(message: String) -> void:
	var debug_hub: Node = get_node_or_null("/root/DebugHub")
	if debug_hub != null:
		debug_hub.call("log", &"net", message)

func _debug_warn(message: String) -> void:
	var debug_hub: Node = get_node_or_null("/root/DebugHub")
	if debug_hub != null:
		debug_hub.call("warn", &"net", message)
