## Tracks player occupants inside the elevator's authored Area3D.
## Attach this script to Elevator/ElevatorArea. Each peer tracks the replicated
## player bodies it can see; the host's local list will drive future transitions.
class_name ElevatorOccupancy
extends Area3D

const LAYERS = preload("res://core/layers.gd")

signal occupant_entered(peer_id: int, player: Node)
signal occupant_exited(peer_id: int, player: Node)
signal occupants_changed(peer_ids: Array[int])

## One record per peer. body_ids prevents a limp proxy and player body from
## counting as two occupants or removing each other when one leaves the area.
var _occupants: Dictionary = {}

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
		_debug_hub.call("watch", DEBUG_COUNT_WATCH, get_occupant_count)
		_debug_hub.call("watch", DEBUG_PEERS_WATCH, get_occupant_peer_ids)


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

	var body_id: int = body.get_instance_id()
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


func _on_body_exited(body: Node3D) -> void:
	if not is_instance_valid(body):
		return

	var player: Node = _find_player_root(body)
	if player == null:
		return

	var peer_id: int = int(player.get("input_peer_id"))
	if not _occupants.has(peer_id):
		return

	var record: Dictionary = _occupants.get(peer_id, {})
	var body_ids: Dictionary = record.get("body_ids", {})
	body_ids.erase(body.get_instance_id())
	record["body_ids"] = body_ids

	if body_ids.is_empty():
		_remove_occupant(peer_id, player)
	else:
		_occupants[peer_id] = record


func _on_player_tree_exiting(peer_id: int) -> void:
	if not _occupants.has(peer_id):
		return
	var record: Dictionary = _occupants.get(peer_id, {})
	var player: Node = record.get("player") as Node
	_remove_occupant(peer_id, player)


func _remove_occupant(peer_id: int, player: Node) -> void:
	if not _occupants.has(peer_id):
		return
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
