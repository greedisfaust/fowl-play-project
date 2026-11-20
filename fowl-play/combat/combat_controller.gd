## Local input adapter for host-authoritative combat.
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
		_network.call("submit_combat_input", int(_player.get("input_peer_id")), false)
func _can_submit() -> bool:
	if not is_instance_valid(_player) or not is_instance_valid(_network):
		return false
	if bool(_player.get("is_limp")) or bool(_player.get("is_recovering")):
		return false
	if bool(_player.call("is_carrying")) or bool(_player.call("is_carried")):
		return false
	return true
static func is_jab_tap(held_seconds: float) -> bool:
	return is_finite(held_seconds) and held_seconds >= 0.0 and held_seconds <= TUNING.TAP_MAX_SECONDS
