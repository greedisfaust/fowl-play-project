## Local input adapter and pure timing helpers for host-authoritative combat.
extends RefCounted
const TUNING = preload("res://core/tuning.gd")
var _player: Node
var _network: Node
var _punch_held: bool = false
func configure(player: Node, network: Node) -> void:
	_player = player
	_network = network
func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("punch"):
		if event is InputEventKey and (event as InputEventKey).echo:
			return true
		if _punch_held:
			return true
		if not _can_submit():
			return true
		_punch_held = true
		_network.call("submit_combat_input", int(_player.get("input_peer_id")), true)
		return true
	if event.is_action_released("punch"):
		if not _punch_held:
			return false
		_punch_held = false
		if is_instance_valid(_network) and is_instance_valid(_player):
			_network.call("submit_combat_input", int(_player.get("input_peer_id")), false)
		return true
	return false
func cancel() -> void:
	if not _punch_held:
		return
	_punch_held = false
	if is_instance_valid(_network) and is_instance_valid(_player):
		_network.call("cancel_combat_input", int(_player.get("input_peer_id")))
func abandon() -> void:
	_punch_held = false
func _can_submit() -> bool:
	if not is_instance_valid(_player) or not is_instance_valid(_network):
		return false
	if bool(_player.get("is_limp")) or bool(_player.get("is_recovering")):
		return false
	if bool(_player.call("is_carrying")) or bool(_player.call("is_carried")):
		return false
	return true
## A release strictly before the one-second threshold is a jab.
static func is_jab_tap(held_seconds: float) -> bool:
	return is_finite(held_seconds) and held_seconds >= 0.0 and held_seconds < TUNING.CHARGED_PUNCH_HOLD_SECONDS
## Shared steering curve used by owner movement and the host hit query.
static func steer_lunge_direction(current: Vector3, desired: Vector3, delta: float) -> Vector3:
	if not current.is_finite() or current.length_squared() < 0.0001:
		return desired.normalized() if desired.is_finite() and desired.length_squared() >= 0.0001 else Vector3.FORWARD
	if not desired.is_finite() or desired.length_squared() < 0.0001:
		return current.normalized()
	var from_direction: Vector3 = current.normalized()
	var to_direction: Vector3 = desired.normalized()
	var angle: float = from_direction.angle_to(to_direction)
	var max_step: float = TUNING.LUNGE_STEER_MAX_RAD_S * maxf(delta, 0.0)
	if angle <= max_step or angle < 0.0001:
		return to_direction
	var rotation_axis: Vector3 = from_direction.cross(to_direction)
	if rotation_axis.length_squared() < 0.0001:
		# Opposite directions have no unique cross-product axis; choose a stable
		# perpendicular axis so the turn still respects the angular-speed cap.
		rotation_axis = from_direction.cross(Vector3.UP)
		if rotation_axis.length_squared() < 0.0001:
			rotation_axis = from_direction.cross(Vector3.RIGHT)
	return from_direction.rotated(rotation_axis.normalized(), minf(angle, max_step)).normalized()
