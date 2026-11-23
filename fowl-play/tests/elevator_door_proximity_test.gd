## Unit checks for elevator door proximity distance and entrance-relative behavior.
extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var script: Script = load("res://world/elevator/elevator_door_proximity.gd") as Script
	if script == null:
		_finish(false, "Could not load elevator_door_proximity.gd.")
		return
	var elevator: Node3D = Node3D.new()
	root.add_child(elevator)
	var proximity: Node3D = Node3D.new()
	proximity.set_script(script)
	elevator.add_child(proximity)
	await process_frame
	var distance_front: float = float(proximity.call("_distance_to_entrance", Vector3(0.0, 0.0, -4.0)))
	if not is_equal_approx(distance_front, 2.42):
		_finish(false, "Front entrance distance was incorrect: %.3f." % distance_front)
		return
	var distance_side: float = float(proximity.call("_distance_to_entrance", Vector3(3.0, 20.0, -1.58)))
	if not is_equal_approx(distance_side, 3.0):
		_finish(false, "Horizontal side distance or vertical filtering was incorrect: %.3f." % distance_side)
		return
	var distance_center: float = float(proximity.call("_distance_to_entrance", Vector3(0.0, -10.0, -1.58)))
	if not is_zero_approx(distance_center):
		_finish(false, "Entrance center should have zero distance.")
		return
	elevator.queue_free()
	await process_frame
	_finish(true, "entrance-relative distance, side approach, and vertical-distance filtering")

func _finish(passed: bool, message: String) -> void:
	if passed:
		print("ELEVATOR DOOR PROXIMITY PASS: %s" % message)
		quit(0)
	else:
		push_error("ELEVATOR DOOR PROXIMITY FAIL: %s" % message)
		quit(1)
