## Physical presentation for a reusable world USE button.
## Attach to the button root; assign the moving cap and its Interactable component.
extends Node3D

@export var cap: Node3D
@export var interactable: Interactable
## Local-space direction the cap travels when pressed. Default is downward.
@export var press_axis: Vector3 = Vector3(0.0, -1.0, 0.0)
@export_range(0.001, 0.2, 0.001, "suffix:m") var press_depth: float = 0.035
@export_range(0.02, 0.3, 0.01, "suffix:s") var press_duration: float = 0.08
@export_range(0.05, 0.6, 0.01, "suffix:s") var return_duration: float = 0.24

var press_count: int = 0
var _rest_position: Vector3 = Vector3.ZERO
var _press_tween: Tween = null
var _debug_hub: Node = null
var _debug_watch_name: StringName = &""

func _ready() -> void:
	if not is_instance_valid(cap):
		push_warning("PhysicalUseButton requires its moving cap reference.")
		set_process(false)
		return
	if not is_instance_valid(interactable):
		push_warning("PhysicalUseButton requires its Interactable reference.")
		set_process(false)
		return
	if press_axis.is_zero_approx():
		push_warning("PhysicalUseButton press_axis cannot be zero; using local down.")
		press_axis = Vector3.DOWN
	press_axis = press_axis.normalized()
	_rest_position = cap.position
	interactable.interacted.connect(_on_interacted)
	_debug_hub = get_node_or_null("/root/DebugHub")
	if is_instance_valid(_debug_hub):
		_debug_watch_name = StringName("interact/button/%s/press_count" % str(get_path()))
		_debug_hub.call("watch", _debug_watch_name, func() -> int: return press_count)

func _exit_tree() -> void:
	if _press_tween != null and _press_tween.is_running():
		_press_tween.kill()
	if is_instance_valid(_debug_hub) and not _debug_watch_name.is_empty():
		_debug_hub.call("unwatch", _debug_watch_name)

func _on_interacted(_actor: Node, action: StringName) -> void:
	if action != &"use":
		return
	var network: Node = get_node_or_null("/root/Network")
	if not is_instance_valid(network):
		return
	var network_peer: MultiplayerPeer = network.get("peer") as MultiplayerPeer
	# Interactable emits on the authority. Offline mode has no ENet peer but
	# still owns the local interaction.
	if network_peer != null and not bool(network.get("is_host")):
		return
	_play_press_local()
	if network_peer != null:
		_receive_press_presentation.rpc()

@rpc("authority", "call_remote", "reliable", 0)
func _receive_press_presentation() -> void:
	var network: Node = get_node_or_null("/root/Network")
	if not is_instance_valid(network) or not bool(network.call("validate_rpc", 1)):
		return
	_play_press_local()

func _play_press_local() -> void:
	if not is_instance_valid(cap):
		return
	press_count += 1
	if _press_tween != null and _press_tween.is_running():
		_press_tween.kill()
	var pressed_position: Vector3 = _rest_position + press_axis * press_depth
	_press_tween = create_tween()
	_press_tween.set_trans(Tween.TRANS_CUBIC)
	_press_tween.set_ease(Tween.EASE_OUT)
	_press_tween.tween_property(cap, "position", pressed_position, press_duration)
	_press_tween.set_trans(Tween.TRANS_SPRING)
	_press_tween.set_ease(Tween.EASE_OUT)
	_press_tween.tween_property(cap, "position", _rest_position, return_duration)
	if is_instance_valid(_debug_hub) and _debug_hub.call("is_on", &"interact"):
		_debug_hub.call("log", &"interact", "%s physical button pressed (%d)" % [name, press_count])
