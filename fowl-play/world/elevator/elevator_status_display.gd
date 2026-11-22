## Compact live status controller for the elevator's existing slim WorldScreen.
## Attach to a dedicated Node child of Elevator; do not replace WorldScreen's script.
class_name ElevatorStatusDisplay
extends Node

const COLOR_GREEN: String = "#55E68A"
const COLOR_RED: String = "#FF5555"
const COLOR_AMBER: String = "#F2C75C"
const COLOR_HEADER: String = "#F2D75C"
const COLOR_TEXT: String = "#F5F5F5"

@export_group("Scene References")
@export var world_screen_path: NodePath = ^"../InteriorDetails/SlimWorldScreen"
@export var occupancy_path: NodePath = ^"../ElevatorArea"

@export_group("Typography")
@export_range(1.0, 2.5, 0.05) var main_text_scale: float = 1.75
@export_range(0.6, 1.5, 0.05) var header_text_scale: float = 0.9
@export_range(0.6, 1.5, 0.05) var status_text_scale: float = 0.85

var _world_screen: Node
var _screen_text: ScreenText
var _occupancy: ElevatorOccupancy
var _network: Node

## Quota/run-state code will call set_early_departure_status once that system exists.
var _early_departure_status_known: bool = false
var _early_departure_eligible: bool = false


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

	_screen_text = _world_screen.call("get_screen_text") as ScreenText
	if _screen_text == null:
		push_error("ElevatorStatusDisplay could not find the WorldScreen's ScreenText.")
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


## Called by the future run/quota coordinator. The departure interaction must
## independently validate eligibility on the host.
func set_early_departure_status(eligible: bool, _reason: String = "") -> void:
	_early_departure_status_known = true
	_early_departure_eligible = eligible
	_refresh_display()


## Clears stale quota information when a new day/run begins.
func clear_early_departure_status() -> void:
	_early_departure_status_known = false
	_early_departure_eligible = false
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
	if not is_instance_valid(_screen_text) or not is_instance_valid(_occupancy):
		return

	var expected_peer_ids: Array[int] = _get_expected_peer_ids()
	var occupant_peer_ids: Array[int] = _occupancy.get_occupant_peer_ids()
	var total_players: int = expected_peer_ids.size()
	var players_inside: int = 0
	for peer_id: int in expected_peer_ids:
		if occupant_peer_ids.has(peer_id):
			players_inside += 1

	var all_players_inside: bool = total_players > 0 and players_inside == total_players
	var count_color: String = COLOR_GREEN if all_players_inside else COLOR_RED
	var departure_status: String = "WAITING FOR PLAYERS"
	var status_color: String = COLOR_AMBER

	if total_players == 0:
		departure_status = "NO SESSION"
	elif all_players_inside:
		if not _early_departure_status_known:
			departure_status = "WAITING FOR QUOTA"
		elif _early_departure_eligible:
			departure_status = "READY TO DEPART"
			status_color = COLOR_GREEN
		else:
			departure_status = "QUOTA NOT MET"
			status_color = COLOR_RED

	var base_size: int = maxi(_screen_text.get_effective_font_size(), 8)
	var header_size: int = maxi(roundi(float(base_size) * header_text_scale), 8)
	var main_size: int = maxi(roundi(float(base_size) * main_text_scale), 8)
	var status_size: int = maxi(roundi(float(base_size) * status_text_scale), 8)

	var header: String = "[table=2][cell][color=%s][font_size=%d][b]ELEVATOR STATUS[/b][/font_size][/color][/cell][cell align=right][color=%s][font_size=%d][b]TEAM SIZE %d[/b][/font_size][/color][/cell][/table]" % [
		COLOR_HEADER, header_size, COLOR_TEXT, header_size, total_players
	]
	var count_line: String = "[center][font_size=%d][b]INSIDE [color=%s]%d[/color] / %d[/b][/font_size][/center]" % [
		main_size, count_color, players_inside, total_players
	]
	var status_line: String = "[center][color=%s][font_size=%d][b]%s[/b][/font_size][/color][/center]" % [
		status_color, status_size, departure_status
	]

	_screen_text.clear_screen()
	_screen_text.append_text(header + "\n" + count_line + "\n\n" + status_line)
