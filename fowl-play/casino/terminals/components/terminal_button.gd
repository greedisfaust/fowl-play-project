## Casino keypad button presentation.
## Attach to the TerminalButton root and assign ButtonKey + Interactable.
extends Node3D

@export var button_key: Node3D
@export var interactable: Interactable
@export_range(0.001, 0.03, 0.001, "suffix:m") var press_depth: float = 0.008
@export_range(0.02, 0.2, 0.01, "suffix:s") var press_duration: float = 0.07
@export_range(0.05, 0.4, 0.01, "suffix:s") var return_duration: float = 0.18

var press_count: int = 0
var _rest_position: Vector3 = Vector3.ZERO
var _press_tween: Tween = null

func _ready() -> void:
	if not is_instance_valid(button_key):
		push_warning("TerminalButton requires its ButtonKey reference.")
		set_process(false)
		return
	if not is_instance_valid(interactable):
		push_warning("TerminalButton requires its Interactable reference.")
		set_process(false)
		return
	_rest_position = button_key.position
	interactable.interacted.connect(_on_interacted)

func _exit_tree() -> void:
	if _press_tween != null and _press_tween.is_running():
		_press_tween.kill()

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
	if not is_instance_valid(button_key):
		return
	press_count += 1
	if _press_tween != null and _press_tween.is_running():
		_press_tween.kill()
	var pressed_position: Vector3 = _rest_position + Vector3.DOWN * press_depth
	_press_tween = create_tween()
	_press_tween.set_trans(Tween.TRANS_CUBIC)
	_press_tween.set_ease(Tween.EASE_OUT)
	_press_tween.tween_property(button_key, "position", pressed_position, press_duration)
	_press_tween.set_trans(Tween.TRANS_SPRING)
	_press_tween.set_ease(Tween.EASE_OUT)
	_press_tween.tween_property(button_key, "position", _rest_position, return_duration)
