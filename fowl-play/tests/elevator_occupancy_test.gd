## Unit checks for elevator occupancy bookkeeping.
extends SceneTree

class FakePlayer:
	extends CharacterBody3D
	var input_peer_id: int = 42

class FakeCarrier:
	extends Node3D
	signal carry_started(item: Node3D)
	signal carry_ended
	var held_item: Node3D = null

	func is_holding() -> bool:
		return is_instance_valid(held_item)

	func begin_carry(item: Node3D) -> void:
		held_item = item
		carry_started.emit(item)

	func end_carry() -> void:
		held_item = null
		carry_ended.emit()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var occupancy_script: Script = load("res://world/elevator/elevator_occupancy.gd") as Script
	if occupancy_script == null:
		_finish(false, "Could not load elevator_occupancy.gd.")
		return

	var area: Area3D = Area3D.new()
	area.set_script(occupancy_script)
	root.add_child(area)
	await process_frame

	var player: FakePlayer = FakePlayer.new()
	player.name = "42"
	root.add_child(player)
	var limp_proxy: StaticBody3D = StaticBody3D.new()
	limp_proxy.name = "LimpInteractionProxy"
	player.add_child(limp_proxy)

	area.call("_on_body_entered", player)
	if int(area.call("get_occupant_count")) != 1:
		_finish(false, "A player body entering the area was not counted.")
		return

	area.call("_on_body_entered", limp_proxy)
	if int(area.call("get_occupant_count")) != 1:
		_finish(false, "A player's secondary body was counted as a second occupant.")
		return

	var peer_ids: Array[int] = area.call("get_occupant_peer_ids")
	if peer_ids != [42] or not bool(area.call("is_player_inside", 42)):
		_finish(false, "Occupant peer ID lookup returned the wrong result.")
		return

	area.call("_on_body_exited", player)
	if int(area.call("get_occupant_count")) != 1:
		_finish(false, "Leaving with one body removed a player whose second body remained inside.")
		return

	area.call("_on_body_exited", limp_proxy)
	if int(area.call("get_occupant_count")) != 0:
		_finish(false, "A player was not removed after all of their bodies exited.")
		return

	var offline_player: FakePlayer = FakePlayer.new()
	offline_player.input_peer_id = 0
	offline_player.name = "OfflineLocalPlayer"
	root.add_child(offline_player)
	area.call("_on_body_entered", offline_player)
	if not bool(area.call("is_player_inside", 0)):
		_finish(false, "The offline local player (peer ID zero) should be tracked in the elevator.")
		return
	area.call("_on_body_exited", offline_player)
	if bool(area.call("is_player_inside", 0)):
		_finish(false, "The offline local player should be removed after exiting the elevator.")
		return
	offline_player.queue_free()

	var carried_player: FakePlayer = FakePlayer.new()
	carried_player.input_peer_id = 43
	carried_player.name = "43"
	root.add_child(carried_player)
	var fake_carrier: FakeCarrier = FakeCarrier.new()
	fake_carrier.name = "Carrier"
	player.add_child(fake_carrier)

	area.call("_on_body_entered", player)
	fake_carrier.begin_carry(carried_player)
	if int(area.call("get_occupant_count")) != 2 or not bool(area.call("is_player_inside", 43)):
		_finish(false, "A player being carried by an occupant was not counted.")
		return

	fake_carrier.end_carry()
	if int(area.call("get_occupant_count")) != 1 or bool(area.call("is_player_inside", 43)):
		_finish(false, "A dropped carried player remained counted without a body in the area.")
		return

	fake_carrier.begin_carry(carried_player)
	area.call("_on_body_exited", player)
	if int(area.call("get_occupant_count")) != 0:
		_finish(false, "A carried player remained counted after their carrier left the area.")
		return
	fake_carrier.end_carry()

	area.call("_on_body_entered", player)
	player.queue_free()
	await process_frame
	if int(area.call("get_occupant_count")) != 0:
		_finish(false, "A freed player remained in the occupant list.")
		return

	carried_player.queue_free()
	area.queue_free()
	await process_frame
	_finish(true, "player detection, duplicate-body protection, carried-player tracking, exits, and despawn cleanup")


func _finish(passed: bool, message: String) -> void:
	if passed:
		print("ELEVATOR OCCUPANCY PASS: %s" % message)
		quit(0)
	else:
		push_error("ELEVATOR OCCUPANCY FAIL: %s" % message)
		quit(1)
