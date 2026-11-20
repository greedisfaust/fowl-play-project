## Procedural jab, anticipation and weak-recoil presentation.
## Gameplay outcomes are host-authoritative; this script only animates the approved intent.
extends RefCounted

const JAB_POSE_DURATION_S: float = 0.38
const RECOIL_POSE_DURATION_S: float = 0.28
const WINDUP_LEAN_RAD: float = -0.12
const JAB_FOLLOW_THROUGH_RAD: float = 0.20
const RECOIL_LEAN_RAD: float = -0.13

enum Phase { IDLE, WINDUP, JAB }

var _player: Node
var _phase: Phase = Phase.IDLE
var _phase_elapsed: float = 0.0
var _recoil_elapsed: float = -1.0
var _jab_direction: Vector3 = Vector3.FORWARD
var _recoil_direction: Vector3 = Vector3.FORWARD
var _base_punch_position_offset: Vector3 = Vector3.ZERO

func configure(player: Node) -> void:
	_player = player
	var hand: Hand = _get_right_hand()
	if hand != null:
		_base_punch_position_offset = hand.punch_position_offset

func begin_windup() -> void:
	if not _can_present():
		return
	_phase = Phase.WINDUP
	_phase_elapsed = 0.0
	var hand: Hand = _get_right_hand()
	if hand != null:
		hand.set_punching(true)
		hand.punch_position_offset = _base_punch_position_offset

func play_jab(direction: Vector3) -> void:
	var hand: Hand = _get_right_hand()
	if hand == null or not direction.is_finite() or direction.length_squared() < 0.0001 or not _can_present():
		cancel()
		return
	var camera: Camera3D = _player.get("camera") as Camera3D
	if camera == null:
		cancel()
		return
	_phase = Phase.JAB
	_phase_elapsed = 0.0
	_jab_direction = direction.normalized()
	hand.set_punching(true)
	var target: Vector3 = camera.global_position + _jab_direction
	if not hand.begin_action(target):
		hand.set_punching(false)
		_phase = Phase.IDLE

## A weak hit reaction is visual only; movement recoil remains owned by Player.
func play_recoil(direction: Vector3) -> void:
	if not _can_present() or not direction.is_finite() or direction.length_squared() < 0.0001:
		return
	_recoil_direction = direction.normalized()
	_recoil_elapsed = 0.0

func advance(delta: float) -> void:
	if not _can_present():
		cancel()
		return
	_phase_elapsed += maxf(delta, 0.0)
	var body_pose: Vector3 = Vector3.ZERO
	match _phase:
		Phase.WINDUP:
			var windup_weight: float = 1.0 - exp(-14.0 * _phase_elapsed)
			body_pose.x = WINDUP_LEAN_RAD * windup_weight
			var windup_hand: Hand = _get_right_hand()
			if windup_hand != null:
				windup_hand.punch_position_offset = get_windup_hand_offset(_base_punch_position_offset, _phase_elapsed)
		Phase.JAB:
			body_pose += get_jab_body_pose(_phase_elapsed, _local_direction(_jab_direction))
			var jab_hand: Hand = _get_right_hand()
			if jab_hand != null:
				jab_hand.punch_position_offset = get_jab_hand_offset(_base_punch_position_offset, _phase_elapsed)
			if _phase_elapsed >= JAB_POSE_DURATION_S:
				_phase = Phase.IDLE
				if jab_hand != null:
					jab_hand.set_punching(false)
					jab_hand.punch_position_offset = _base_punch_position_offset
	if _recoil_elapsed >= 0.0:
		body_pose += get_recoil_body_pose(_recoil_elapsed, _local_direction(_recoil_direction))
		_recoil_elapsed += maxf(delta, 0.0)
		if _recoil_elapsed >= RECOIL_POSE_DURATION_S:
			_recoil_elapsed = -1.0
	var rig: Node3D = _player.get("rig") as Node3D
	if is_instance_valid(rig):
		rig.call("set_combat_body_pose", body_pose)

func cancel() -> void:
	_phase = Phase.IDLE
	_phase_elapsed = 0.0
	_recoil_elapsed = -1.0
	var hand: Hand = _get_right_hand()
	if hand != null:
		hand.set_punching(false)
		hand.punch_position_offset = _base_punch_position_offset
	var rig: Node3D = null
	if is_instance_valid(_player):
		rig = _player.get("rig") as Node3D
	if is_instance_valid(rig):
		rig.call("set_combat_body_pose", Vector3.ZERO)

static func get_windup_hand_offset(base_offset: Vector3, elapsed: float) -> Vector3:
	var weight: float = 1.0 - exp(-14.0 * maxf(elapsed, 0.0))
	return base_offset + Vector3(0.0, 0.025 * weight, 0.14 * weight)

static func get_jab_hand_offset(base_offset: Vector3, elapsed: float) -> Vector3:
	var t: float = clampf(elapsed / JAB_POSE_DURATION_S, 0.0, 1.0)
	var pullback_to_extension: float = smoothstep(0.0, 0.18, t)
	var depth: float = lerpf(0.14, -0.045, pullback_to_extension) if t < 0.18 else -0.045 * sin(PI * t)
	var height: float = lerpf(0.025, 0.02, pullback_to_extension) if t < 0.18 else 0.02
	return base_offset + Vector3(0.0, height, depth)

static func get_jab_body_pose(elapsed: float, local_direction: Vector3) -> Vector3:
	var t: float = clampf(elapsed / JAB_POSE_DURATION_S, 0.0, 1.0)
	var pitch: float = 0.0
	if t < 0.18:
		pitch = lerpf(WINDUP_LEAN_RAD, JAB_FOLLOW_THROUGH_RAD, smoothstep(0.0, 0.18, t))
	elif t < 0.42:
		pitch = JAB_FOLLOW_THROUGH_RAD
	else:
		pitch = lerpf(JAB_FOLLOW_THROUGH_RAD, 0.0, smoothstep(0.42, 1.0, t))
	var direction_yaw: float = clampf(atan2(-local_direction.x, -local_direction.z), -0.6, 0.6)
	var yaw: float = direction_yaw * 0.28 * sin(PI * t)
	return Vector3(pitch, yaw, -yaw * 0.18)

static func get_recoil_body_pose(elapsed: float, local_direction: Vector3) -> Vector3:
	var t: float = clampf(elapsed / RECOIL_POSE_DURATION_S, 0.0, 1.0)
	var weight: float = sin(PI * t)
	var side: float = clampf(local_direction.x, -1.0, 1.0)
	return Vector3(RECOIL_LEAN_RAD * weight, -side * 0.10 * weight, side * 0.12 * weight)

func _local_direction(world_direction: Vector3) -> Vector3:
	var player_3d: Node3D = _player as Node3D
	if not is_instance_valid(player_3d):
		return Vector3.FORWARD
	return (player_3d.global_basis.inverse() * world_direction).normalized()

func _can_present() -> bool:
	return is_instance_valid(_player) and not bool(_player.get("is_limp")) and not bool(_player.get("is_recovering")) and not bool(_player.call("is_carrying"))

func _get_right_hand() -> Hand:
	if not is_instance_valid(_player):
		return null
	return _player.get("viewmodel_right_hand") as Hand
