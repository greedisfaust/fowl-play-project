## Opens the elevator doors when a player approaches the entrance.
## Attach to the existing DoorTest node (rename it DoorProximityController).
extends Node3D

@export_group("Proximity")
@export_range(1.0, 8.0, 0.1) var open_distance: float = 3.25
@export_range(1.0, 10.0, 0.1) var keep_open_distance: float = 4.0
@export_range(0.0, 5.0, 0.1) var close_delay_seconds: float = 1.25
@export var entrance_local_position: Vector3 = Vector3(0.0, 0.0, -1.58)

@export_group("References")
@export var door_controller_path: NodePath = ^"../DoorAnimation"

var _door_controller: ElevatorDoorController
var _network: Node
var _commanded_open: bool = false
var _time_without_nearby_players: float = 0.0
var _debug_hub: Node


func _ready() -> void:
	_door_controller = get_node_or_null(door_controller_path) as ElevatorDoorController
	if _door_controller == null:
		push_error("ElevatorDoorProximity could not find ElevatorDoorController at %s." % door_controller_path)
		set_process(false)
		return

	_network = get_node_or_null("/root/Network")
	_commanded_open = _door_controller.are_doors_open()
	if not _door_controller.door_motion_finished.is_connected(_on_door_motion_finished):
		_door_controller.door_motion_finished.connect(_on_door_motion_finished)

	_debug_hub = get_node_or_null("/root/DebugHub")
	if _debug_hub != null:
		_debug_hub.call("watch", &"elevator/door_nearby_players", func() -> int: return _count_players_within_distance(open_distance))
		_debug_hub.call("watch", &"elevator/door_commanded_open", func() -> bool: return _commanded_open)


func _exit_tree() -> void:
	if is_instance_valid(_debug_hub):
		_debug_hub.call("unwatch", &"elevator/door_nearby_players")
		_debug_hub.call("unwatch", &"elevator/door_commanded_open")


func _process(delta: float) -> void:
	if not _is_network_authority():
		return

	if _count_players_within_distance(open_distance) > 0:
		_time_without_nearby_players = 0.0
		_request_door_state(true)
		return

	if not _commanded_open:
		return

	if _count_players_within_distance(keep_open_distance) > 0:
		_time_without_nearby_players = 0.0
		return

	_time_without_nearby_players += delta
	if _time_without_nearby_players >= close_delay_seconds:
		_time_without_nearby_players = 0.0
		_request_door_state(false)


func _is_network_authority() -> bool:
	if _network == null:
		return multiplayer.is_server()
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return true
	return bool(_network.get("is_host"))


func _request_door_state(open: bool) -> void:
	if _commanded_open == open:
		return

	_commanded_open = open
	if _network == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		_apply_door_state(open)
		return

	rpc("_rpc_set_door_state", open)


@rpc("authority", "call_local", "reliable")
func _rpc_set_door_state(open: bool) -> void:
	_commanded_open = open
	_apply_door_state(open)


func _apply_door_state(open: bool) -> void:
	if not is_instance_valid(_door_controller):
		return
	if open:
		_door_controller.open_doors()
	else:
		_door_controller.close_doors()


func _on_door_motion_finished(is_open: bool) -> void:
	if is_open != _commanded_open:
		_apply_door_state(_commanded_open)


func _count_players_within_distance(max_distance: float) -> int:
	if _network == null:
		return 0

	var players: Dictionary = _network.get("movement_players")
	var nearby_count: int = 0
	for player_value: Variant in players.values():
		var player: Node3D = player_value as Node3D
		if not is_instance_valid(player) or player.is_queued_for_deletion():
			continue
		if _distance_to_entrance(player.global_position) <= max_distance:
			nearby_count += 1
	return nearby_count


## Horizontal distance from a world position to the center of the elevator entrance.
func _distance_to_entrance(world_position: Vector3) -> float:
	var elevator_root: Node3D = get_parent() as Node3D
	if elevator_root == null:
		return INF
	var local_position: Vector3 = elevator_root.to_local(world_position)
	var horizontal_offset: Vector2 = Vector2(
		local_position.x - entrance_local_position.x,
		local_position.z - entrance_local_position.z
	)
	return horizontal_offset.length()
