extends SceneTree

const ELEVATOR_SCENE: PackedScene = preload("res://world/elevator/elevator.tscn")
const ELEVATOR_LAYER_BIT: int = 1 << 6

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var elevator: Node3D = ELEVATOR_SCENE.instantiate() as Node3D
	if elevator == null:
		_finish(false, "Elevator scene could not be instantiated.")
		return
	root.add_child(elevator)
	await process_frame

	var panel_names: Array[String] = [
		"LeftOuterPanel",
		"LeftInnerPanel",
		"RightInnerPanel",
		"RightOuterPanel",
	]
	var collision_bodies: Array[AnimatableBody3D] = []
	for panel_name: String in panel_names:
		var body: AnimatableBody3D = elevator.get_node_or_null("DoorAssembly/%s/DoorCollision" % panel_name) as AnimatableBody3D
		if body == null:
			_finish(false, "%s is missing its moving door collision body." % panel_name)
			return
		if (body.collision_layer & ELEVATOR_LAYER_BIT) == 0:
			_finish(false, "%s collision must use the ELEVATOR layer." % panel_name)
			return
		if not body.sync_to_physics:
			_finish(false, "%s must synchronize its animated transform with physics." % panel_name)
			return
		var collision_shape: CollisionShape3D = body.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if collision_shape == null or not collision_shape.shape is BoxShape3D:
			_finish(false, "%s needs a BoxShape3D matching its door leaf." % panel_name)
			return
		collision_bodies.append(body)

	var doors: ElevatorDoorController = elevator.get_node("DoorAnimation") as ElevatorDoorController
	if doors == null:
		_finish(false, "ElevatorDoorController is missing.")
		return
	doors.travel_seconds = 0.05
	var initial_x: float = collision_bodies[0].global_position.x
	doors.open_doors()
	while doors.are_doors_moving():
		await process_frame
	if is_equal_approx(collision_bodies[0].global_position.x, initial_x):
		_finish(false, "Door collision must travel with the animated visual panel when opening.")
		return
	doors.close_doors()
	while doors.are_doors_moving():
		await process_frame
	if doors.are_doors_open():
		_finish(false, "Door controller should report closed after the closing animation.")
		return

	_finish(true, "all four moving door collision bodies use the ELEVATOR layer and follow their visual panels")


func _finish(passed: bool, message: String) -> void:
	print(("PASS: " if passed else "FAIL: ") + message)
	quit(0 if passed else 1)
