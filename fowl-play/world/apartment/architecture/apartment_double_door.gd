extends Node3D
class_name ApartmentDoubleDoor

## Host-authoritative, hinged double entrance doors.
## Interact to swing them; walking into them also pushes them open.

const LAYERS = preload("res://core/layers.gd")
const OPEN_ANGLE: float = 1.42
const AUTO_CLOSE_SECONDS: float = 3.2
const MIN_BUMP_SPEED: float = 1.25

var interactable: Interactable
var bump_area: Area3D
var left_hinge: Node3D
var right_hinge: Node3D

var _is_open: bool = false
var _open_direction: int = 1
var _animation: Tween
var _close_token: int = 0
var _door_plane_x: float

func _ready() -> void:
	_door_plane_x = global_position.x
	call_deferred("_setup_door")

func _setup_door() -> void:
	interactable = get_node_or_null("Interactable") as Interactable
	bump_area = get_node_or_null("Doorway_Bump_Area") as Area3D
	left_hinge = get_node_or_null("Left_Hinge") as Node3D
	right_hinge = get_node_or_null("Right_Hinge") as Node3D
	if interactable == null or bump_area == null or left_hinge == null or right_hinge == null:
		push_warning("ApartmentDoubleDoor: generated door components are incomplete.")
		return
	interactable.interacted.connect(_on_interacted)
	bump_area.body_entered.connect(_on_body_entered)
	bump_area.area_entered.connect(_on_area_entered)

func _on_interacted(actor: Node, action: StringName) -> void:
	if action != &"use" or not multiplayer.is_server():
		return
	var actor_3d: Node3D = actor as Node3D
	if actor_3d == null:
		return
	if _is_open:
		_publish_state(false, _open_direction)
	else:
		var direction: int = -1 if actor_3d.global_position.x > _door_plane_x else 1
		_publish_state(true, direction)

func _on_body_entered(body: Node3D) -> void:
	if not body is CharacterBody3D:
		return
	var character: CharacterBody3D = body as CharacterBody3D
	if character.velocity.length() < MIN_BUMP_SPEED:
		return
	var direction: int = -1 if body.global_position.x > _door_plane_x else 1
	_request_bump(direction)

func _on_area_entered(area: Area3D) -> void:
	if (area.collision_layer & (1 << (LAYERS.PUNCH_HITBOX - 1))) == 0:
		return
	var direction: int = -1 if area.global_position.x > _door_plane_x else 1
	_request_bump(direction)

func _request_bump(direction: int) -> void:
	if multiplayer.is_server():
		_publish_state(true, direction)
	else:
		rpc_id(1, "request_bump_open", direction)

func _publish_state(opened: bool, direction: int) -> void:
	if multiplayer.get_peers().is_empty():
		apply_door_state(opened, direction)
	else:
		rpc("apply_door_state", opened, direction)

@rpc("any_peer", "call_remote", "reliable")
func request_bump_open(direction: int) -> void:
	if not multiplayer.is_server():
		return
	_publish_state(true, clampi(direction, -1, 1))

@rpc("authority", "call_local", "reliable")
func apply_door_state(opened: bool, direction: int) -> void:
	_is_open = opened
	_open_direction = 1 if direction >= 0 else -1
	_close_token += 1
	if _animation != null and _animation.is_running():
		_animation.kill()
	_animation = create_tween()
	_animation.set_trans(Tween.TRANS_CUBIC)
	_animation.set_ease(Tween.EASE_OUT)
	var left_target: float = OPEN_ANGLE * float(_open_direction) if opened else 0.0
	var right_target: float = -OPEN_ANGLE * float(_open_direction) if opened else 0.0
	_animation.tween_property(left_hinge, "rotation:y", left_target, 0.58)
	_animation.parallel().tween_property(right_hinge, "rotation:y", right_target, 0.58)
	if opened:
		var token: int = _close_token
		_close_after_delay(token)

func _close_after_delay(token: int) -> void:
	await get_tree().create_timer(AUTO_CLOSE_SECONDS).timeout
	if token == _close_token and _is_open and multiplayer.is_server():
		if not bump_area.get_overlapping_bodies().is_empty():
			_close_after_delay(token)
		else:
			_publish_state(false, _open_direction)
