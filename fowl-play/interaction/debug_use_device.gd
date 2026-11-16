## Minimal M1 USE device for the test arena.
## Owns a toggled active state so the interaction path has an observable result.

extends Node3D

@onready var interactable: Interactable = $Interactable
@onready var debug_hub: Node = get_node("/root/DebugHub")

var is_active: bool = false
var _debug_watch_name: StringName

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	multiplayer.connected_to_server.connect(_request_current_state)
	get_node("/root/Network").session_ended.connect(_reset_state)
	_request_current_state.call_deferred()
	_debug_watch_name = StringName("interact/device/%s/active" % name)
	debug_hub.call("watch", _debug_watch_name, func() -> bool: return is_active)

func _exit_tree() -> void:
	if is_instance_valid(debug_hub):
		debug_hub.call("unwatch", _debug_watch_name)

func _on_interacted(_actor: Node, action: StringName) -> void:
	if action != &"use" or not multiplayer.is_server():
		return
	is_active = not is_active
	if get_node("/root/Network").get("is_host"):
		_receive_state.rpc(is_active)
	if debug_hub.call("is_on", &"interact"):
		debug_hub.call("log", &"interact", "%s active=%s" % [name, is_active])

func _reset_state() -> void:
	is_active = false

func _request_current_state() -> void:
	var network: Node = get_node("/root/Network")
	if network.get("is_client") and network.get("status") == "connected":
		_request_state.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable", 0)
func _request_state() -> void:
	var network: Node = get_node("/root/Network")
	if network.get("is_host") and network.call("validate_rpc"):
		_receive_state.rpc_id(multiplayer.get_remote_sender_id(), is_active)

@rpc("authority", "call_remote", "reliable", 0)
func _receive_state(active: bool) -> void:
	if not get_node("/root/Network").call("validate_rpc", 1):
		return
	is_active = active
	debug_hub.call("log", &"interact", "%s replicated active=%s" % [name, is_active])
