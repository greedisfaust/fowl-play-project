## Network bootstrap and shared RPC validation for Fowl Play.
## This is the only project script that directly constructs ENet peers.

extends Node

const TUNING = preload("res://core/tuning.gd")

var peer: ENetMultiplayerPeer = null
var is_host: bool = false
var is_client: bool = false
var connected_peers: Array[int] = []

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	parse_args(OS.get_cmdline_args())

func parse_args(arguments: PackedStringArray) -> void:
	for argument: String in arguments:
		if argument == "--host":
			start_host()
		elif argument.begins_with("--join="):
			join_server(argument.trim_prefix("--join="))

func start_host() -> Error:
	if peer != null:
		_debug_warn("Rejected host start: network already started")
		return ERR_ALREADY_IN_USE
	peer = ENetMultiplayerPeer.new()
	var error: Error = peer.create_server(TUNING.ENET_PORT, TUNING.MAX_PLAYERS - 1)
	if error != OK:
		peer = null
		_debug_warn("Host start failed: %s" % error_string(error))
		return error
	multiplayer.multiplayer_peer = peer
	is_host = true
	is_client = false
	connected_peers = [TUNING.PEER_ID_HOST]
	_debug_log("Host started on port %d" % TUNING.ENET_PORT)
	return OK

func join_server(address: String) -> Error:
	if peer != null:
		_debug_warn("Rejected join: network already started")
		return ERR_ALREADY_IN_USE
	peer = ENetMultiplayerPeer.new()
	var error: Error = peer.create_client(address, TUNING.ENET_PORT)
	if error != OK:
		peer = null
		_debug_warn("Join failed for %s: %s" % [address, error_string(error)])
		return error
	multiplayer.multiplayer_peer = peer
	is_host = false
	is_client = true
	_debug_log("Joining %s:%d" % [address, TUNING.ENET_PORT])
	return OK

func shutdown() -> void:
	if peer == null:
		return
	peer.close()
	multiplayer.multiplayer_peer = null
	peer = null
	is_host = false
	is_client = false
	connected_peers.clear()
	_debug_log("Network shut down")

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
