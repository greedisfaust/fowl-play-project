## Controls the elevator's four synchronized sliding door leaves.
## Attach this script to the existing DoorAnimation (AnimationPlayer) node.
class_name ElevatorDoorController
extends AnimationPlayer

signal door_state_changed(is_open: bool)
signal door_motion_finished(is_open: bool)

@export_group("Door Motion")
@export_range(0.1, 3.0, 0.05) var travel_seconds: float = 0.9
@export_range(0.0, 0.5, 0.01) var stagger_seconds: float = 0.04
@export_range(0.5, 2.0, 0.05) var travel_multiplier: float = 1.0

const PANEL_NAMES: Array[String] = [
	"LeftOuterPanel",
	"LeftInnerPanel",
	"RightInnerPanel",
	"RightOuterPanel"
]
const OPEN_OFFSETS: Dictionary = {
	"LeftOuterPanel": -0.6,
	"LeftInnerPanel": -1.2,
	"RightInnerPanel": 1.2,
	"RightOuterPanel": 0.6
}

var _is_open: bool = false
var _is_moving: bool = false
var _active_tween: Tween


func are_doors_open() -> bool:
	return _is_open


func are_doors_moving() -> bool:
	return _is_moving


func open_doors() -> void:
	_set_doors_open(true)


func close_doors() -> void:
	_set_doors_open(false)


func toggle_doors() -> void:
	_set_doors_open(not _is_open)


func _set_doors_open(open: bool) -> void:
	if _is_moving or _is_open == open:
		return

	var door_assembly: Node3D = get_parent().get_node_or_null("DoorAssembly") as Node3D
	if door_assembly == null:
		push_error("ElevatorDoorController expects DoorAssembly beside DoorAnimation.")
		return

	var panels: Array[Node3D] = []
	for panel_name: String in PANEL_NAMES:
		var panel: Node3D = door_assembly.get_node_or_null(panel_name) as Node3D
		if panel == null:
			push_error("ElevatorDoorController cannot find door pivot: %s" % panel_name)
			return
		panels.append(panel)

	_is_moving = true
	var tween: Tween = create_tween()
	_active_tween = tween
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUINT)
	tween.set_ease(Tween.EASE_IN_OUT)

	for index: int in range(panels.size()):
		var panel: Node3D = panels[index]
		var closed_x: float = _closed_x_for_panel(panel.name)
		var target_x: float = closed_x
		if open:
			target_x += float(OPEN_OFFSETS[panel.name])
		var delay: float = 0.0
		if panel.name == "LeftInnerPanel" or panel.name == "RightInnerPanel":
			delay = stagger_seconds
		var duration: float = travel_seconds * travel_multiplier
		tween.tween_property(panel, "position:x", target_x, duration).set_delay(delay)

	tween.set_parallel(false)
	tween.tween_callback(_finish_motion.bind(open))


func _closed_x_for_panel(panel_name: String) -> float:
	match panel_name:
		"LeftOuterPanel":
			return -0.9
		"LeftInnerPanel":
			return -0.3
		"RightInnerPanel":
			return 0.3
		"RightOuterPanel":
			return 0.9
	return 0.0


func _finish_motion(open: bool) -> void:
	_is_open = open
	_is_moving = false
	door_state_changed.emit(_is_open)
	door_motion_finished.emit(_is_open)
	
