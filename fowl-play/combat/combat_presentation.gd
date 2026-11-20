## Coordinates the curled-fist wind-up and short extension on the existing hand.
extends RefCounted
var _player: Node
func configure(player: Node) -> void:
	_player = player
func begin_windup() -> void:
	var hand: Hand = _get_right_hand()
	if hand != null:
		hand.set_punching(true)
func play_jab(direction: Vector3) -> void:
	var hand: Hand = _get_right_hand()
	if hand == null or not direction.is_finite() or direction.length_squared() < 0.0001:
		cancel()
		return
	var camera: Camera3D = _player.get("camera") as Camera3D
	if camera == null:
		cancel()
		return
	hand.set_punching(true)
	var target: Vector3 = camera.global_position + direction.normalized() * 1.0
	if not hand.begin_action(target):
		hand.set_punching(false)
func cancel() -> void:
	var hand: Hand = _get_right_hand()
	if hand != null:
		hand.set_punching(false)
func _get_right_hand() -> Hand:
	if not is_instance_valid(_player):
		return null
	return _player.get("viewmodel_right_hand") as Hand
