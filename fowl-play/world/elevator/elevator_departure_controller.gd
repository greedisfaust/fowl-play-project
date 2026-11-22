## Bridges the elevator's physical DEPART button to host-authoritative run progression.
## Attach to the existing plain Node child named DepartureController under the Elevator root.
## Occupancy and physical choreography live here; phase and destination rules live in RunManager.
class_name ElevatorDepartureController
extends Node

signal departure_requested(actor_peer_id: int)

@export_group("Scene References")
@export var button_path: NodePath = ^"../InteriorDetails/TerminalButton"
@export var occupancy_path: NodePath = ^"../ElevatorArea"
@export var door_controller_path: NodePath = ^"../DoorAnimation"
@export var door_proximity_path: NodePath = ^"../DoorProximityController"
@export var main_controller_path: NodePath = ^"/root/Main"

@export_group("Departure Sequence")
@export_range(1.0, 15.0, 0.5) var recovery_timeout_seconds: float = 8.0
@export_range(1.0, 8.0, 0.5) var door_timeout_seconds: float = 4.0

var _button: Node
var _interactable: Interactable
var _occupancy: ElevatorOccupancy
var _door_controller: ElevatorDoorController
var _door_proximity: Node
var _main_controller: MainController
var _run_manager: Node
var _network: Node
var _request_pending: bool = false
var _departure_in_progress: bool = false
var _debug_hub: Node


func _ready() -> void:
	_button = get_node_or_null(button_path)
	_occupancy = get_node_or_null(occupancy_path) as ElevatorOccupancy
	_door_controller = get_node_or_null(door_controller_path) as ElevatorDoorController
	_door_proximity = get_node_or_null(door_proximity_path)
	_network = get_node_or_null("/root/Network")
	_run_manager = get_node_or_null("/root/RunManager")
	_main_controller = get_node_or_null(main_controller_path) as MainController

	if not is_instance_valid(_run_manager):
		push_error("ElevatorDepartureController requires the RunManager autoload.")
		set_process(false)
		return
	if _main_controller == null:
		push_error("ElevatorDepartureController could not find MainController at %s." % main_controller_path)
		set_process(false)
		return
	if not is_instance_valid(_button):
		push_error("ElevatorDepartureController could not find the DEPART button at %s." % button_path)
		set_process(false)
		return
	if _occupancy == null:
		push_error("ElevatorDepartureController could not find ElevatorOccupancy at %s." % occupancy_path)
		set_process(false)
		return

	_interactable = _button.get("interactable") as Interactable
	if not is_instance_valid(_interactable):
		_interactable = _button.get_node_or_null("Interactable") as Interactable
	if not is_instance_valid(_interactable):
		push_error("ElevatorDepartureController could not resolve the button's Interactable.")
		set_process(false)
		return

	_interactable.availability_check = Callable(self, "_can_interact")
	if _button.has_signal("button_activated"):
		if not _button.is_connected("button_activated", _on_button_activated):
			_button.connect("button_activated", _on_button_activated)
	else:
		push_error("ElevatorDepartureController expects TerminalButton.button_activated.")
		set_process(false)
		return

	if not is_connected("departure_requested", _on_departure_requested):
		departure_requested.connect(_on_departure_requested)
	_debug_hub = get_node_or_null("/root/DebugHub")
	if is_instance_valid(_debug_hub):
		_debug_hub.call("watch", &"elevator/departure_ready", Callable(self, "are_all_players_inside"))
		_debug_hub.call("watch", &"elevator/departure_request_pending", func() -> bool: return _request_pending)
		_debug_hub.call("watch", &"elevator/departure_in_progress", func() -> bool: return _departure_in_progress)


func _exit_tree() -> void:
	if is_instance_valid(_interactable) and _interactable.availability_check == Callable(self, "_can_interact"):
		_interactable.availability_check = Callable()
	if is_instance_valid(_button) and _button.has_signal("button_activated"):
		if _button.is_connected("button_activated", _on_button_activated):
			_button.disconnect("button_activated", _on_button_activated)
	if is_instance_valid(_debug_hub):
		_debug_hub.call("unwatch", &"elevator/departure_ready")
		_debug_hub.call("unwatch", &"elevator/departure_request_pending")
		_debug_hub.call("unwatch", &"elevator/departure_in_progress")


## Returns true only when every connected player is inside the elevator.
## ElevatorOccupancy already accounts for players being carried by another player.
func are_all_players_inside() -> bool:
	if not is_instance_valid(_occupancy):
		return false
	var expected_peer_ids: Array[int] = _get_expected_peer_ids()
	return are_all_expected_players_inside(expected_peer_ids, _occupancy.get_occupant_peer_ids())


static func are_all_expected_players_inside(expected_peer_ids: Array[int], occupant_peer_ids: Array[int]) -> bool:
	if expected_peer_ids.is_empty():
		return false
	for peer_id: int in expected_peer_ids:
		if peer_id <= 0 or not occupant_peer_ids.has(peer_id):
			return false
	return true


static func can_peer_request_departure(actor_peer_id: int, expected_peer_ids: Array[int], occupant_peer_ids: Array[int]) -> bool:
	return actor_peer_id > 0 and occupant_peer_ids.has(actor_peer_id) and are_all_expected_players_inside(expected_peer_ids, occupant_peer_ids)


func _can_interact(actor: Node, action: StringName) -> bool:
	if action != &"use" or _request_pending or _departure_in_progress or not is_instance_valid(actor):
		return false
	var actor_peer_id: int = int(actor.get("input_peer_id"))
	return can_peer_request_departure(actor_peer_id, _get_expected_peer_ids(), _occupancy.get_occupant_peer_ids())


func _on_button_activated(_button_id: StringName, actor_peer_id: int) -> void:
	if not _is_network_authority() or _request_pending or _departure_in_progress:
		return
	if not can_peer_request_departure(actor_peer_id, _get_expected_peer_ids(), _occupancy.get_occupant_peer_ids()):
		_log_rejection("DEPART rejected: every connected player must be inside the elevator.")
		return

	_request_pending = true
	if is_instance_valid(_debug_hub):
		_debug_hub.call("log", &"net", "Elevator departure requested by peer %d." % actor_peer_id)
	departure_requested.emit(actor_peer_id)


## Resolves a valid button request through RunManager, then starts the existing elevator sequence.
## A fresh session starts its run on the first Apartment departure.
func _on_departure_requested(_actor_peer_id: int) -> void:
	if not _is_network_authority() or not is_instance_valid(_run_manager) or not is_instance_valid(_main_controller):
		return

	var current_world: int = _main_controller.active_world
	if not bool(_run_manager.get("run_active")):
		if current_world != MainController.World.APARTMENT or not _main_controller.can_transition_to(MainController.World.CASINO):
			reject_departure_request("a new run can only begin from the Apartment")
			return
		var start_result: Dictionary = _run_manager.call("begin_new_run")
		if not bool(start_result.get("ok", false)):
			reject_departure_request(str(start_result.get("reason", "could not start a new run")))
			return

	var destination_world: int = int(_run_manager.call("get_departure_destination", current_world))
	if destination_world < 0:
		reject_departure_request("departure is not allowed during the current run phase")
		return
	if not accept_departure_request(destination_world):
		reject_departure_request("the approved destination could not be started")


## Called by the outer-loop progression coordinator after it approves the request.
## Destination IDs match MainController.World. The elevator never decides quota/day rules.
func accept_departure_request(destination_world: int) -> bool:
	if not _is_network_authority() or not _request_pending or _departure_in_progress:
		return false
	if destination_world < MainController.World.APARTMENT or destination_world > MainController.World.REST_AREA:
		reject_departure_request("invalid destination world")
		return false
	_main_controller = get_node_or_null(main_controller_path) as MainController
	if _main_controller == null or not _main_controller.can_transition_to(destination_world):
		reject_departure_request("destination world is unavailable")
		return false
	if _door_controller == null or not is_instance_valid(_door_proximity) or not _door_proximity.has_method("begin_departure_closure"):
		reject_departure_request("elevator door/proximity controller is unavailable")
		return false
	_departure_in_progress = true
	_execute_departure_sequence.call_deferred(destination_world)
	return true


func _execute_departure_sequence(destination_world: int) -> void:
	var doors_closed: bool = await _close_doors_for_departure()
	if not doors_closed:
		_abort_departure("elevator doors did not finish closing")
		return
	var players_prepared: bool = await _prepare_players_for_transition()
	if not players_prepared:
		_abort_departure("could not safely prepare every player for transport")
		return
	var players_recovered: bool = await _wait_for_all_players_recovered()
	if not players_recovered:
		_abort_departure("a player did not finish recovering before the departure timeout")
		return
	if _main_controller.active_world == MainController.World.CASINO and destination_world == MainController.World.REST_AREA:
		var casino_day_manager: Node = get_node_or_null("/root/CasinoDayManager")
		if not is_instance_valid(casino_day_manager):
			_abort_departure("CasinoDayManager is unavailable")
			return
		if bool(casino_day_manager.get("day_active")):
			var day_end_result: Dictionary = casino_day_manager.call("finish_early_departure")
			if not bool(day_end_result.get("ok", false)):
				_abort_departure(str(day_end_result.get("reason", "casino day could not be completed")))
				return
		elif not bool(casino_day_manager.get("day_result_recorded")):
			_abort_departure("casino day has no recorded deadline or early-departure result")
			return
	_request_pending = false
	if is_instance_valid(_debug_hub):
		_debug_hub.call("log", &"net", "Elevator departure approved; transitioning to world %d." % destination_world)
	_main_controller.transition_to(destination_world)


func _close_doors_for_departure() -> bool:
	if not bool(_door_proximity.call("begin_departure_closure")):
		return false
	var deadline: int = Time.get_ticks_msec() + int(door_timeout_seconds * 1000.0)
	while _door_controller.are_doors_moving() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if _door_controller.are_doors_moving():
		return false
	if _door_controller.are_doors_open():
		_door_controller.close_doors()
	deadline = Time.get_ticks_msec() + int(door_timeout_seconds * 1000.0)
	while (_door_controller.are_doors_open() or _door_controller.are_doors_moving()) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return not _door_controller.are_doors_open() and not _door_controller.are_doors_moving()


func _prepare_players_for_transition() -> bool:
	if not is_instance_valid(_network):
		return false
	var players: Dictionary = _network.get("movement_players")
	var peer_ids: Array[int] = []
	for peer_value: Variant in players.keys():
		peer_ids.append(int(peer_value))
	peer_ids.sort()
	for peer_id: int in peer_ids:
		var player: Node = players.get(peer_id) as Node
		if not is_instance_valid(player):
			return false
		if bool(player.call("is_carrying")):
			_network.call("force_drop_carry", peer_id, "elevator departure")
	await get_tree().process_frame
	for peer_id: int in peer_ids:
		var player: Node = players.get(peer_id) as Node
		if not is_instance_valid(player) or bool(player.call("is_carried")):
			return false
		if bool(player.get("is_limp")):
			if not bool(_network.call("stop_ragdoll_spike", peer_id, "elevator departure")):
				return false
	return true


func _wait_for_all_players_recovered() -> bool:
	var deadline: int = Time.get_ticks_msec() + int(recovery_timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var players: Dictionary = _network.get("movement_players")
		var all_ready: bool = true
		for player_value: Variant in players.values():
			var player: Node = player_value as Node
			if not is_instance_valid(player) or bool(player.get("is_limp")) or bool(player.get("is_recovering")) or bool(player.call("is_carried")) or bool(player.call("is_carrying")):
				all_ready = false
				break
		if all_ready:
			return true
		await get_tree().process_frame
	return false


func _abort_departure(reason: String) -> void:
	_request_pending = false
	_departure_in_progress = false
	if is_instance_valid(_door_proximity) and _door_proximity.has_method("cancel_departure_closure"):
		_door_proximity.call("cancel_departure_closure")
	elif is_instance_valid(_door_controller) and not _door_controller.are_doors_open() and not _door_controller.are_doors_moving():
		_door_controller.open_doors()
	_log_rejection("DEPART sequence aborted: %s" % reason)


## Called by the future progression coordinator when its quota/day-state checks reject the request.
func reject_departure_request(reason: String = "") -> void:
	if not _request_pending or _departure_in_progress:
		return
	_request_pending = false
	if not reason.is_empty():
		_log_rejection("DEPART rejected by progression: %s" % reason)


## Called by the future transition sequence after the group has arrived at its destination.
func finish_departure_request() -> void:
	_request_pending = false
	_departure_in_progress = false


func is_departure_request_pending() -> bool:
	return _request_pending


func is_departure_in_progress() -> bool:
	return _departure_in_progress


func _get_expected_peer_ids() -> Array[int]:
	var peer_ids: Array[int] = []
	if not is_instance_valid(_network):
		return peer_ids

	var roster_value: Variant = _network.get("roster")
	if roster_value is Array:
		for peer_value: Variant in roster_value:
			var peer_id: int = int(peer_value)
			if peer_id > 0 and not peer_ids.has(peer_id):
				peer_ids.append(peer_id)

	# Offline/dev sessions may not have a published roster. Use the live player
	# registry so the local host is still counted.
	if peer_ids.is_empty():
		var players_value: Variant = _network.get("movement_players")
		if players_value is Dictionary:
			for peer_value: Variant in players_value.keys():
				var peer_id: int = int(peer_value)
				if peer_id > 0 and not peer_ids.has(peer_id):
					peer_ids.append(peer_id)

	peer_ids.sort()
	return peer_ids


func _is_network_authority() -> bool:
	if not is_instance_valid(_network):
		return multiplayer.is_server()
	var network_peer: MultiplayerPeer = _network.get("peer") as MultiplayerPeer
	return network_peer == null or bool(_network.get("is_host"))


func _log_rejection(message: String) -> void:
	if is_instance_valid(_debug_hub):
		_debug_hub.call("warn", &"net", message)
	else:
		push_warning(message)
