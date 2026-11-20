## Reusable proximity-aware terminal lifecycle.
## Attach to an editor-authored terminal root and assign its screen, sensor, and screen Interactable.
class_name InteractiveTerminal
extends Node3D

signal woke
signal slept
signal session_started(actor: Node)
signal session_ended(actor: Node, reason: StringName)

const END_RANGE: StringName = &"out_of_range"
const END_LEFT_SENSOR: StringName = &"left_sensor"
const END_CLOSED: StringName = &"closed"

@export_group("Terminal References")
@export var screen: WorldScreen
@export var screen_interactable: Interactable
@export var proximity_area: Area3D

@export_group("Proximity")
@export_range(1.0, 20.0, 0.5) var wake_distance: float = 5.0
@export_range(0.5, 15.0, 0.5) var interaction_distance: float = 3.0
@export var horizontal_distance_only: bool = true

@export_group("Idle Presentation")
@export var idle_header: String = "TERMINAL ONLINE"
@export_multiline var idle_description: String = "SYSTEM READY.\nPRESS USE TO BEGIN."
@export var idle_prompt: String = "APPROACH AND INTERACT"

var _nearby_local_actors: Array[Node] = []
var _active_actor: Node = null
var _awake: bool = false

func _ready() -> void:
	if not is_instance_valid(screen):
		push_warning("%s requires a WorldScreen reference." % name)
		set_process(false)
		return
	if not is_instance_valid(proximity_area):
		push_warning("%s requires a proximity Area3D reference." % name)
		set_process(false)
		return
	proximity_area.body_entered.connect(_on_proximity_body_entered)
	proximity_area.body_exited.connect(_on_proximity_body_exited)
	if is_instance_valid(screen_interactable):
		screen_interactable.interaction_requested.connect(_on_screen_interaction_requested)
	_sleep_terminal()
	set_process(true)

func _exit_tree() -> void:
	if is_instance_valid(screen_interactable):
		if screen_interactable.interaction_requested.is_connected(_on_screen_interaction_requested):
			screen_interactable.interaction_requested.disconnect(_on_screen_interaction_requested)
	if is_instance_valid(proximity_area):
		if proximity_area.body_entered.is_connected(_on_proximity_body_entered):
			proximity_area.body_entered.disconnect(_on_proximity_body_entered)
		if proximity_area.body_exited.is_connected(_on_proximity_body_exited):
			proximity_area.body_exited.disconnect(_on_proximity_body_exited)

func _process(_delta: float) -> void:
	_prune_invalid_nearby_actors()
	if _nearby_local_actors.is_empty():
		if _active_actor != null:
			end_session(END_LEFT_SENSOR)
		if _awake:
			_sleep_terminal()
		return
	if not _awake:
		_wake_terminal()
	if _active_actor != null and not _is_actor_within(_active_actor, interaction_distance):
		end_session(END_RANGE)

func begin_session(actor: Node) -> bool:
	if not _awake or not _can_actor_activate(actor, &"use"):
		return false
	if _active_actor != null:
		return _active_actor == actor
	_active_actor = actor
	_on_terminal_session_started(actor)
	session_started.emit(actor)
	return true

func end_session(reason: StringName = END_CLOSED) -> void:
	if _active_actor == null:
		return
	var previous_actor: Node = _active_actor
	_active_actor = null
	_on_terminal_session_ended(previous_actor, reason)
	session_ended.emit(previous_actor, reason)

func is_awake() -> bool:
	return _awake

func has_active_session() -> bool:
	return is_instance_valid(_active_actor)

func get_active_actor() -> Node:
	return _active_actor

func _on_proximity_body_entered(body: Node3D) -> void:
	if not _is_local_player(body):
		return
	if not _nearby_local_actors.has(body):
		_nearby_local_actors.append(body)
	if not _awake:
		_wake_terminal()

func _on_proximity_body_exited(body: Node3D) -> void:
	_nearby_local_actors.erase(body)
	if body == _active_actor:
		end_session(END_LEFT_SENSOR)
	if _nearby_local_actors.is_empty():
		_sleep_terminal()

func _on_screen_interaction_requested(actor: Node, action: StringName) -> void:
	if action != &"use" or not _can_actor_activate(actor, action):
		return
	if _active_actor == actor:
		_on_terminal_use_again(actor)
	else:
		begin_session(actor)

func _can_actor_activate(actor: Node, action: StringName) -> bool:
	return action == &"use" and _awake and _nearby_local_actors.has(actor) and _is_actor_within(actor, interaction_distance)

func _is_local_player(actor: Node) -> bool:
	if not is_instance_valid(actor):
		return false
	var local_value: Variant = actor.get("is_local_player")
	return typeof(local_value) == TYPE_BOOL and bool(local_value)

func _is_actor_within(actor: Node, distance: float) -> bool:
	if not is_instance_valid(actor) or not actor is Node3D:
		return false
	var actor_position: Vector3 = (actor as Node3D).global_position
	var terminal_position: Vector3 = global_position
	if horizontal_distance_only:
		actor_position.y = 0.0
		terminal_position.y = 0.0
	return actor_position.distance_to(terminal_position) <= distance

func _prune_invalid_nearby_actors() -> void:
	for index: int in range(_nearby_local_actors.size() - 1, -1, -1):
		var actor: Node = _nearby_local_actors[index]
		if not is_instance_valid(actor):
			_nearby_local_actors.remove_at(index)

func _wake_terminal() -> void:
	if _awake:
		return
	_awake = true
	screen.show_layout("information", idle_header, idle_description, idle_prompt)
	woke.emit()
	_on_terminal_woke()

func _sleep_terminal() -> void:
	if not _awake:
		return
	if _active_actor != null:
		end_session(END_LEFT_SENSOR)
	_awake = false
	screen.clear_screen()
	slept.emit()
	_on_terminal_slept()

## Override these hooks in a specialized terminal controller.
func _on_terminal_woke() -> void:
	pass

func _on_terminal_slept() -> void:
	pass

func _on_terminal_session_started(_actor: Node) -> void:
	pass

func _on_terminal_session_ended(_actor: Node, _reason: StringName) -> void:
	pass

func _on_terminal_use_again(_actor: Node) -> void:
	pass
