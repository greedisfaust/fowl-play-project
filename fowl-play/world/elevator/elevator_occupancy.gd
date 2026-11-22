## Tracks player occupants inside the elevator's authored Area3D.
## Attach this script to Elevator/ElevatorArea. Each peer tracks the replicated
## player bodies it can see; the host's local list will drive future transitions.
class_name ElevatorOccupancy
extends Area3D

const LAYERS = preload("res://core/layers.gd")

signal occupant_entered(peer_id: int, player: Node)
signal occupant_exited(peer_id: int, player: Node)
signal occupants_changed(peer_ids: Array[int])

## One record per peer. body_ids includes physical bodies and synthetic tokens
## for players being carried by another occupant.
var _occupants: Dictionary = {}
var _carried_peer_by_carrier: Dictionary = {}

var _debug_hub: Node
const DEBUG_COUNT_WATCH: StringName = &"elevator/occupant_count"
const DEBUG_PEERS_WATCH: StringName = &"elevator/occupant_peer_ids"


func _ready() -> void:
	collision_mask = LAYERS.LAYER_MASK_ELEVATOR
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	_debug_hub = get_node_or_null("/root/DebugHub")
	if _debug_hub != null:
		_debug_hub.call("watch", DEBUG_COUNT_WATCH, func() -> int: return get_occupant_count())
		_debug_hub.call("watch", DEBUG_PEERS_WATCH, func() -> Array[int]: return get_occupant_peer_ids())


func _exit_tree() -> void:
	if is_instance_valid(_debug_hub):
		_debug_hub.call("unwatch", DEBUG_COUNT_WATCH)
		_debug_hub.call("unwatch", DEBUG_PEERS_WATCH)


func get_occupant_count() -> int:
	return _occupants.size()


func get_occupant_peer_ids() -> Array[int]:
	var peer_ids: Array[int] = []
	for peer_value: Variant in _occupants.keys():
		peer_ids.append(int(peer_value))
	peer_ids.sort()
	return peer_ids


func is_player_inside(peer_id: int) -> bool:
	return _occupants.has(peer_id)


func get_occupant(peer_id: int) -> Node:
	var record: Dictionary = _occupants.get(peer_id, {})
	return record.get("player") as Node


func _on_body_entered(body: Node3D) -> void:
	if not is_instance_valid(body):
		return

	var player: Node = _find_player_root(body)
	if player == null:
		return

	var peer_id: int = int(player.get("input_peer_id"))
	if peer_id <= 0:
		return

	_add_occupant_body(peer_id, player, body.get_instance_id())
	_connect_carrier_signals(player, peer_id)
	_register_already_carried_player(peer_id, player)


func _on_body_exited(body: Node3D) -> void:
	if not is_instance_valid(body):
		return

	var player: Node = _find_player_root(body)
	if player == null:
		return

	var peer_id: int = int(player.get("input_peer_id"))
	_remove_occupant_body(peer_id, player, body.get_instance_id())


func _add_occupant_body(peer_id: int, player: Node, body_id: int) -> void:
	var is_new_occupant: bool = not _occupants.has(peer_id)
	var record: Dictionary = _occupants.get(peer_id, {})
	var body_ids: Dictionary = record.get("body_ids", {})
	if body_ids.has(body_id):
		return

	body_ids[body_id] = true
	record["player"] = player
	record["body_ids"] = body_ids
	_occupants[peer_id] = record

	if is_new_occupant:
		var exiting_callback: Callable = _on_player_tree_exiting.bind(peer_id)
		if not player.tree_exiting.is_connected(exiting_callback):
			player.tree_exiting.connect(exiting_callback, CONNECT_ONE_SHOT)
		occupant_entered.emit(peer_id, player)
		_emit_occupants_changed()


func _remove_occupant_body(peer_id: int, player: Node, body_id: int) -> void:
	if not _occupants.has(peer_id):
		return

	var record: Dictionary = _occupants.get(peer_id, {})
	var body_ids: Dictionary = record.get("body_ids", {})
	body_ids.erase(body_id)
	record["body_ids"] = body_ids

	if body_ids.is_empty():
		_remove_occupant(peer_id, player)
	else:
		_occupants[peer_id] = record


func _connect_carrier_signals(player: Node, peer_id: int) -> void:
	var carrier: Node = player.get_node_or_null("Carrier")
	if carrier == null:
		return

	var started_callback: Callable = _on_carrier_carry_started.bind(peer_id)
	if carrier.has_signal("carry_started") and not carrier.is_connected("carry_started", started_callback):
		carrier.connect("carry_started", started_callback)

	var ended_callback: Callable = _on_carrier_carry_ended.bind(peer_id)
	if carrier.has_signal("carry_ended") and not carrier.is_connected("carry_ended", ended_callback):
		carrier.connect("carry_ended", ended_callback)


func _register_already_carried_player(carrier_peer_id: int, carrier_player: Node) -> void:
	var carrier: Node = carrier_player.get_node_or_null("Carrier")
	if carrier == null or not carrier.has_method("is_holding"):
		return
	if not bool(carrier.call("is_holding")):
		return
	var held_item: Node3D = carrier.get("held_item") as Node3D
	_register_carried_player(carrier_peer_id, carrier_player, held_item)


func _on_carrier_carry_started(item: Node3D, carrier_peer_id: int) -> void:
	var carrier_record: Dictionary = _occupants.get(carrier_peer_id, {})
	var carrier_player: Node = carrier_record.get("player") as Node
	if carrier_player == null:
		return
	_register_carried_player(carrier_peer_id, carrier_player, item)


func _on_carrier_carry_ended(carrier_peer_id: int) -> void:
	_remove_carried_link(carrier_peer_id)


func _register_carried_player(carrier_peer_id: int, carrier_player: Node, item: Node3D) -> void:
	if item == null or not is_instance_valid(item) or not _has_property(item, &"input_peer_id"):
		return

	var carried_peer_id: int = int(item.get("input_peer_id"))
	if carried_peer_id <= 0 or carried_peer_id == carrier_peer_id:
		return

	_remove_carried_link(carrier_peer_id)
	var token: int = -carrier_player.get_instance_id()
	_add_occupant_body(carried_peer_id, item, token)
	_carried_peer_by_carrier[carrier_peer_id] = {
		"peer_id": carried_peer_id,
		"token": token
	}


func _remove_carried_link(carrier_peer_id: int) -> void:
	if not _carried_peer_by_carrier.has(carrier_peer_id):
		return

	var link: Dictionary = _carried_peer_by_carrier[carrier_peer_id]
	_carried_peer_by_carrier.erase(carrier_peer_id)
	var carried_peer_id: int = int(link.get("peer_id", 0))
	var token: int = int(link.get("token", 0))
	if not _occupants.has(carried_peer_id):
		return

	var record: Dictionary = _occupants.get(carried_peer_id, {})
	var body_ids: Dictionary = record.get("body_ids", {})
	body_ids.erase(token)
	record["body_ids"] = body_ids
	if body_ids.is_empty():
		var carried_player: Node = record.get("player") as Node
		_remove_occupant(carried_peer_id, carried_player)
	else:
		_occupants[carried_peer_id] = record


func _clear_carrier_links_for_target(carried_peer_id: int) -> void:
	for carrier_peer_value: Variant in _carried_peer_by_carrier.keys():
		var carrier_peer_id: int = int(carrier_peer_value)
		var link: Dictionary = _carried_peer_by_carrier[carrier_peer_id]
		if int(link.get("peer_id", 0)) == carried_peer_id:
			_carried_peer_by_carrier.erase(carrier_peer_id)


func _on_player_tree_exiting(peer_id: int) -> void:
	if not _occupants.has(peer_id):
		return
	var record: Dictionary = _occupants.get(peer_id, {})
	var player: Node = record.get("player") as Node
	_remove_occupant(peer_id, player)


func _remove_occupant(peer_id: int, player: Node) -> void:
	if not _occupants.has(peer_id):
		return
	_remove_carried_link(peer_id)
	_clear_carrier_links_for_target(peer_id)
	_occupants.erase(peer_id)
	occupant_exited.emit(peer_id, player)
	_emit_occupants_changed()


func _emit_occupants_changed() -> void:
	occupants_changed.emit(get_occupant_peer_ids())


func _find_player_root(body: Node) -> Node:
	var candidate: Node = body
	while candidate != null:
		if _has_property(candidate, &"input_peer_id"):
			return candidate
		candidate = candidate.get_parent()
	return null


func _has_property(node: Object, property_name: StringName) -> bool:
	for property_info: Dictionary in node.get_property_list():
		if StringName(property_info.get("name", "")) == property_name:
			return true
	return false
