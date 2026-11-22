extends Node

func _ready() -> void:
	var doors: ElevatorDoorController = $"../DoorAnimation"

	print("Testing elevator doors!")

	await get_tree().create_timer(2.0).timeout
	doors.open_doors()

	await get_tree().create_timer(3.0).timeout
	doors.close_doors()
