## Camera focus and interaction input for the local player.
## Owns the focus ray, highlighting, intent submission, and debug hooks.

extends Node3D

const LAYERS = preload("res://core/layers.gd")
const TUNING = preload("res://core/tuning.gd")

@export var actor_path: NodePath = NodePath("../../..")

@onready var focus_ray: RayCast3D = $FocusRay
@onready var debug_hub: Node = get_node("/root/DebugHub")
@onready var left_hand: Hand = get_node_or_null("../ViewmodelHands/LeftHand") as Hand
@onready var right_hand: Hand = get_node_or_null("../ViewmodelHands/RightHand") as Hand

var _actor: Node3D = null
var _focused: Interactable = null
var _active: bool = false
var _debug_command_name: StringName
var _debug_focus_watch_name: StringName

func _ready() -> void:
	_actor = get_node_or_null(actor_path) as Node3D
	focus_ray.collision_mask = _focus_mask()
	focus_ray.target_position = Vector3(0.0, 0.0, -TUNING.REACH_M)
	_debug_command_name = StringName("interact_use_%s" % get_parent().get_parent().get_parent().name)
	_debug_focus_watch_name = StringName("interact/focused/%s" % get_parent().get_parent().get_parent().name)
	debug_hub.call(
		"watch",
		_debug_focus_watch_name,
		func() -> String:
			return _focused.prompt_text if _focused != null else ""
	)
	debug_hub.call(
		"command",
		_debug_command_name,
		_debug_use_focused,
		"Use the currently focused interaction target.",
		false,
		false
	)
	set_process_unhandled_input(false)

func _exit_tree() -> void:
	_clear_focus()
	if not is_instance_valid(debug_hub):
		return
	debug_hub.call("unregister_command", _debug_command_name)
	debug_hub.call("unwatch", _debug_focus_watch_name)

func set_active(active: bool) -> void:
	_active = active
	set_process_unhandled_input(active)
	if not active:
		_clear_focus()

func _process(_delta: float) -> void:
	if not _active:
		return
	_update_focus()

func _unhandled_input(event: InputEvent) -> void:
	if not _active or bool(debug_hub.call("is_console_open")):
		return
	if event.is_action_pressed("primary"):
		_try_interact(&"primary")
	elif event.is_action_pressed("interact"):
		_try_interact(&"interact")

func _update_focus() -> void:
	focus_ray.force_raycast_update()
	var candidate: Interactable = _find_interactable(focus_ray.get_collider() as Node)
	if candidate != _focused:
		if is_instance_valid(_focused):
			_focused.set_focused(false)
		_focused = candidate
		if is_instance_valid(_focused):
			_focused.set_focused(true)
			_debug_log("Focused %s" % _focused.prompt_text)
	var collision_point: Vector3 = Vector3.ZERO
	if is_instance_valid(candidate) and focus_ray.is_colliding():
		collision_point = focus_ray.get_collision_point()
	_set_hands_hover(is_instance_valid(candidate), collision_point)

func _set_hands_hover(active: bool, world_point: Vector3) -> void:
	if is_instance_valid(right_hand):
		right_hand.set_hover(active, world_point)


func _clear_focus() -> void:
	if is_instance_valid(_focused):
		_focused.set_focused(false)
	_focused = null
	_set_hands_hover(false, Vector3.ZERO)

func _try_interact(input_action: StringName) -> bool:
	if not _active:
		return false
	if _actor != null and _actor.call("is_carrying"):
		_debug_log("Interaction rejected: actor is carrying")
		return false
	_update_focus()
	if not is_instance_valid(_focused):
		_debug_log("Interaction rejected: no focused target")
		return false
	var action: StringName = _focused.action_for_input(input_action)
	if action == &"":
		_debug_log("Interaction rejected: target does not accept %s" % input_action)
		return false
	return bool(get_node("/root/Network").call("request_interaction", _focused.get_path(), action))

func _debug_use_focused(_args: Array[Variant]) -> String:
	return "Interaction requested; check interact logs for host result." if _try_interact(&"interact") else "Interaction rejected."

func _find_interactable(node: Node) -> Interactable:
	var current: Node = node
	while current != null:
		if current is Interactable:
			return current as Interactable
		var component: Interactable = current.get_node_or_null("Interactable") as Interactable
		if component != null:
			return component
		current = current.get_parent()
	return null

func _focus_mask() -> int:
	return (1 << (LAYERS.WORLD_STATIC - 1)) | (1 << (LAYERS.ELEVATOR - 1)) | (1 << (LAYERS.DEVICES - 1)) | (1 << (LAYERS.PROPS - 1)) | (1 << (LAYERS.LIMP_BODIES - 1))

func _debug_log(message: String) -> void:
	if debug_hub.call("is_on", &"interact"):
		debug_hub.call("log", &"interact", message)

func _debug_warn(message: String) -> void:
	debug_hub.call("warn", &"interact", message)
