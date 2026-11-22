## Unit checks for elevator departure occupancy validation.
extends SceneTree

func _initialize() -> void:
	_run()

func _run() -> void:
	var script: Script = load("res://world/elevator/elevator_departure_controller.gd") as Script
	if script == null:
		_finish(false, "Could not load elevator_departure_controller.gd.")
		return
	var controller: Node = script.new() as Node
	if controller == null:
		_finish(false, "Could not instantiate ElevatorDepartureController.")
		return

	var peers: Array[int] = [1, 2, 3]
	var all_inside: Array[int] = [1, 2, 3]
	var missing_one: Array[int] = [1, 3]
	var extra_occupant: Array[int] = [1, 2, 3, 4]
	var empty: Array[int] = []

	if not bool(controller.call("are_all_expected_players_inside", peers, all_inside)):
		_finish(false, "All expected players inside should be eligible.")
		return
	if bool(controller.call("are_all_expected_players_inside", peers, missing_one)):
		_finish(false, "A missing player must block departure.")
		return
	if bool(controller.call("are_all_expected_players_inside", empty, empty)):
		_finish(false, "An empty session must not be eligible.")
		return
	if not bool(controller.call("are_all_expected_players_inside", peers, extra_occupant)):
		_finish(false, "An extra occupant must not block the expected team.")
		return
	if not bool(controller.call("can_peer_request_departure", 2, peers, all_inside)):
		_finish(false, "An occupant should be able to request departure.")
		return
	if bool(controller.call("can_peer_request_departure", 4, peers, all_inside)):
		_finish(false, "A non-occupant must not be able to request departure.")
		return
	if bool(controller.call("can_peer_request_departure", 2, peers, missing_one)):
		_finish(false, "A player must not request departure while a teammate is outside.")
		return
	var offline_peers: Array[int] = [0]
	if not bool(controller.call("are_all_expected_players_inside", offline_peers, offline_peers)):
		_finish(false, "The offline local player (peer ID zero) should count as an elevator occupant.")
		return
	if not bool(controller.call("can_peer_request_departure", 0, offline_peers, offline_peers)):
		_finish(false, "The offline local player should be allowed to request departure when inside.")
		return

	controller.free()
	_finish(true, "full-team occupancy, empty-session rejection, occupant authorization, and missing-player rejection")

func _finish(passed: bool, message: String) -> void:
	if passed:
		print("ELEVATOR DEPARTURE PASS: %s" % message)
		quit(0)
	else:
		push_error("ELEVATOR DEPARTURE FAIL: %s" % message)
		quit(1)
