## Live information controller for the elevator's existing slim WorldScreen.
## Attach to a dedicated Node child of Elevator; do not replace WorldScreen's script.
class_name ElevatorStatusDisplay
extends Node

@export_group("Scene References")
@export var world_screen_path: NodePath = ^"../InteriorDetails/SlimWorldScreen"
@export var occupancy_path: NodePath = ^"../ElevatorArea"

var _world_screen: Node
var _occupancy: ElevatorOccupancy
var _network: Node

## Quota/run-state code will call set_early_departure_status once that system exists.
## Until then the display explicitly reports that quota status is not connected.
var _early_departure_status_known: bool = false
var _early_departure_eligible: bool = false
var _early_departure_reason: String = "DAILY QUOTA NOT CONNECTED"


func _ready() -> void:
	_world_screen = get_node_or_null(world_screen_path)
	_occupancy = get_node_or_null(occupancy_path) as ElevatorOccupancy
	_network = get_node_or_null("/root/Network")

	if _world_screen == null:
		push_error("ElevatorStatusDisplay could not find its WorldScreen.")
		set_process(false)
		return
	if _occupancy == null:
		push_error("ElevatorStatusDisplay could not find ElevatorOccupancy.")
		set_process(false)
		return

	if not _occupancy.occupants_changed.is_connected(_on_occupants_changed):
		_occupancy.occupants_changed.connect(_on_occupants_changed)
	if is_instance_valid(_network) and _network.has_signal("roster_changed"):
		if not _network.is_connected("roster_changed", _on_roster_changed):
			_network.connect("roster_changed", _on_roster_changed)

	_refresh_display()


func _exit_tree() -> void:
	if is_instance_valid(_occupancy) and _occupancy.occupants_changed.is_connected(_on_occupants_changed):
		_occupancy.occupants_changed.disconnect(_on_occupants_changed)
	if is_instance_valid(_network) and _network.has_signal("roster_changed"):
		if _network.is_connected("roster_changed", _on_roster_changed):
			_network.disconnect("roster_changed", _on_roster_changed)


## Called by the future run/quota coordinator. This is presentation state only;
## the departure interaction must independently validate eligibility on the host.
func set_early_departure_status(eligible: bool, reason: String = "") -> void:
	_early_departure_status_known = true
	_early_departure_eligible = eligible
	_early_departure_reason = reason.strip_edges()
	if _early_departure_reason.is_empty():
		_early_departure_reason = "QUOTA MET" if eligible else "DAILY QUOTA NOT MET"
	_refresh_display()


## Clears stale quota information when a new day/run begins.
func clear_early_departure_status() -> void:
	_early_departure_status_known = false
	_early_departure_eligible = false
	_early_departure_reason = "DAILY QUOTA NOT CONNECTED"
	_refresh_display()


func _on_occupants_changed(_peer_ids: Array[int]) -> void:
	_refresh_display()


func _on_roster_changed() -> void:
	_refresh_display()


func _get_expected_peer_ids() -> Array[int]:
	var peer_ids: Array[int] = []
	if is_instance_valid(_network):
		var roster_value: Variant = _network.get("roster")
		if roster_value is Array:
			for peer_value: Variant in roster_value:
				var peer_id: int = int(peer_value)
				if peer_id > 0 and not peer_ids.has(peer_id):
					peer_ids.append(peer_id)

	if peer_ids.is_empty():
		var local_peer_id: int = multiplayer.get_unique_id()
		if local_peer_id > 0:
			peer_ids.append(local_peer_id)
		for remote_peer_id: int in multiplayer.get_peers():
			if remote_peer_id > 0 and not peer_ids.has(remote_peer_id):
				peer_ids.append(remote_peer_id)

	peer_ids.sort()
	return peer_ids


func _refresh_display() -> void:
	if not is_instance_valid(_world_screen) or not is_instance_valid(_occupancy):
		return

	var expected_peer_ids: Array[int] = _get_expected_peer_ids()
	var occupant_peer_ids: Array[int] = _occupancy.get_occupant_peer_ids()
	var total_players: int = expected_peer_ids.size()
	var players_inside: int = 0
	for peer_id: int in expected_peer_ids:
		if occupant_peer_ids.has(peer_id):
			players_inside += 1

	var all_players_inside: bool = total_players > 0 and players_inside == total_players
	var early_status: String = "CHECKING"
	if _early_departure_status_known:
		early_status = "ELIGIBLE" if _early_departure_eligible else "NOT ELIGIBLE"

	var departure_status: String = "WAITING FOR PLAYERS"
	if all_players_inside:
		if not _early_departure_status_known:
			departure_status = "WAITING FOR QUOTA"
		elif _early_departure_eligible:
			departure_status = "READY TO DEPART"
		else:
			departure_status = "QUOTA NOT MET"
	elif total_players == 0:
		departure_status = "NO SESSION"

	var body: String = "PLAYERS   %d / %d\nINSIDE    %d / %d\n\nEARLY DEPARTURE\n%s\n%s" % [
		players_inside,
		total_players,
		players_inside,
		total_players,
		early_status,
		_early_departure_reason if _early_departure_status_known else "QUOTA STATUS PENDING"
	]
	_world_screen.call("set_content", "ELEVATOR STATUS", body, departure_status)
