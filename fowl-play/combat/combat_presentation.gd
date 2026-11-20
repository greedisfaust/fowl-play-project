## Procedural jab, charged-lunge and weak-recoil presentation.
## Gameplay outcomes are host-authoritative; this script only animates approved intent.
extends RefCounted
const JAB_POSE_DURATION_S: float = 0.21
const JAB_EXTENSION_END_S: float = 0.058
const JAB_CONTACT_HOLD_S: float = 0.018
const RECOIL_POSE_DURATION_S: float = 0.48
const WINDUP_LEAN_RAD: float = -0.07
const JAB_FOLLOW_THROUGH_RAD: float = 0.16
const RECOIL_LEAN_RAD: float = -0.36
const RECOIL_TWIST_RAD: float = 0.27
const RECOIL_ROLL_RAD: float = 0.21
const LUNGE_POSE_DURATION_S: float = 0.50
const LUNGE_RECOVERY_DURATION_S: float = 0.30
const LUNGE_FOLLOW_THROUGH_RAD: float = 0.34
enum Phase { IDLE, WINDUP, JAB, LUNGE, LUNGE_RECOVERY }
var _player: Node
var _phase: Phase = Phase.IDLE
var _phase_elapsed: float = 0.0
var _recoil_elapsed: float = -1.0
var _jab_direction: Vector3 = Vector3.FORWARD
var _lunge_direction: Vector3 = Vector3.FORWARD
var _recoil_direction: Vector3 = Vector3.FORWARD
var _recoil_strength: float = 1.0
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
	if not hand.begin_action(camera.global_position + _jab_direction):
		hand.set_punching(false)
		_phase = Phase.IDLE
func play_charged_lunge(direction: Vector3) -> void:
	var hand: Hand = _get_right_hand()
	if hand == null or not direction.is_finite() or direction.length_squared() < 0.0001 or not _can_present():
		cancel()
		return
	var camera: Camera3D = _player.get("camera") as Camera3D
	if camera == null:
		cancel()
		return
	_phase = Phase.LUNGE
	_phase_elapsed = 0.0
	_lunge_direction = direction.normalized()
	hand.set_punching(true)
	if not hand.begin_action(camera.global_position + _lunge_direction * 1.4):
		hand.set_punching(false)
		_phase = Phase.IDLE
func end_charged_lunge() -> void:
	if _phase != Phase.LUNGE:
		return
	_phase = Phase.LUNGE_RECOVERY
	_phase_elapsed = 0.0
func play_recoil(direction: Vector3, strength: float = 1.0) -> void:
	if not _can_present() or not direction.is_finite() or direction.length_squared() < 0.0001:
		return
	_recoil_direction = direction.normalized()
	_recoil_elapsed = 0.0
	_recoil_strength = clampf(strength, 1.0, 1.35)
func advance(delta: float) -> void:
	if not _can_present():
		cancel()
		return
	_phase_elapsed += maxf(delta, 0.0)
	var body_pose: Vector3 = Vector3.ZERO
	var hand: Hand = _get_right_hand()
	match _phase:
		Phase.WINDUP:
			var weight: float = 1.0 - exp(-18.0 * _phase_elapsed)
			body_pose.x = WINDUP_LEAN_RAD * weight
			if hand != null:
				hand.punch_position_offset = get_windup_hand_offset(_base_punch_position_offset, _phase_elapsed)
		Phase.JAB:
			body_pose += get_jab_body_pose(_phase_elapsed, _local_direction(_jab_direction))
			if hand != null:
				hand.punch_position_offset = get_jab_hand_offset(_base_punch_position_offset, _phase_elapsed)
			if _phase_elapsed >= JAB_POSE_DURATION_S:
				_phase = Phase.IDLE
				if hand != null:
					hand.set_punching(false)
					hand.punch_position_offset = _base_punch_position_offset
		Phase.LUNGE:
			body_pose += get_charged_lunge_body_pose(_phase_elapsed, _local_direction(_lunge_direction))
			if hand != null:
				hand.punch_position_offset = get_charged_lunge_hand_offset(_base_punch_position_offset, _phase_elapsed)
		Phase.LUNGE_RECOVERY:
			var recovery: float = smoothstep(0.0, LUNGE_RECOVERY_DURATION_S, _phase_elapsed)
			body_pose = get_charged_lunge_body_pose(LUNGE_POSE_DURATION_S, _local_direction(_lunge_direction)) * (1.0 - recovery)
			if hand != null:
				var extended: Vector3 = get_charged_lunge_hand_offset(_base_punch_position_offset, LUNGE_POSE_DURATION_S)
				hand.punch_position_offset = _base_punch_position_offset.lerp(extended, 1.0 - recovery)
			if _phase_elapsed >= LUNGE_RECOVERY_DURATION_S:
				_phase = Phase.IDLE
				if hand != null:
					hand.set_punching(false)
					hand.punch_position_offset = _base_punch_position_offset
	if _recoil_elapsed >= 0.0:
		body_pose += get_recoil_body_pose(_recoil_elapsed, _local_direction(_recoil_direction), _recoil_strength)
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
	_recoil_strength = 1.0
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
	var weight: float = 1.0 - exp(-18.0 * maxf(elapsed, 0.0))
	return base_offset + Vector3(0.0, 0.018 * weight, 0.14 * weight)
static func get_jab_hand_offset(base_offset: Vector3, elapsed: float) -> Vector3:
	var t: float = maxf(elapsed, 0.0)
	var progress: float = clampf(t / JAB_EXTENSION_END_S, 0.0, 1.0)
	var ease_out: float = 1.0 - pow(1.0 - progress, 3.0)
	var extension_depth: float = lerpf(0.14, -0.045, ease_out)
	var return_start: float = JAB_EXTENSION_END_S + JAB_CONTACT_HOLD_S
	var return_weight: float = smoothstep(return_start, JAB_POSE_DURATION_S, t)
	var depth: float = lerpf(extension_depth, 0.0, return_weight) if t > return_start else extension_depth
	var height: float = 0.018 * sin(PI * clampf(t / JAB_POSE_DURATION_S, 0.0, 1.0))
	return base_offset + Vector3(0.0, height, depth)
static func get_jab_body_pose(elapsed: float, local_direction: Vector3) -> Vector3:
	var t: float = maxf(elapsed, 0.0)
	var return_start: float = JAB_EXTENSION_END_S + JAB_CONTACT_HOLD_S
	var pitch: float
	if t < JAB_EXTENSION_END_S:
		pitch = lerpf(WINDUP_LEAN_RAD, JAB_FOLLOW_THROUGH_RAD, 1.0 - pow(1.0 - clampf(t / JAB_EXTENSION_END_S, 0.0, 1.0), 3.0))
	elif t < return_start:
		pitch = JAB_FOLLOW_THROUGH_RAD
	else:
		pitch = lerpf(JAB_FOLLOW_THROUGH_RAD, 0.0, smoothstep(return_start, JAB_POSE_DURATION_S, t))
	var direction_yaw: float = clampf(atan2(-local_direction.x, -local_direction.z), -0.6, 0.6)
	var yaw: float = direction_yaw * 0.22 * sin(PI * clampf(t / JAB_POSE_DURATION_S, 0.0, 1.0))
	return Vector3(pitch, yaw, -yaw * 0.18)
static func get_charged_lunge_body_pose(elapsed: float, local_direction: Vector3) -> Vector3:
	var t: float = clampf(maxf(elapsed, 0.0) / LUNGE_POSE_DURATION_S, 0.0, 1.0)
	var drive: float = 1.0 - pow(1.0 - t, 3.0)
	var direction_yaw: float = clampf(atan2(-local_direction.x, -local_direction.z), -0.6, 0.6)
	return Vector3(lerpf(WINDUP_LEAN_RAD, LUNGE_FOLLOW_THROUGH_RAD, drive), direction_yaw * 0.18 * drive, -direction_yaw * 0.12 * drive)
static func get_charged_lunge_hand_offset(base_offset: Vector3, elapsed: float) -> Vector3:
	var t: float = clampf(maxf(elapsed, 0.0) / 0.12, 0.0, 1.0)
	var extension: float = 1.0 - pow(1.0 - t, 3.0)
	return base_offset + Vector3(0.0, -0.025 * extension, -0.20 * extension)
static func get_recoil_body_pose(elapsed: float, local_direction: Vector3, strength: float = 1.0) -> Vector3:
	var t: float = maxf(elapsed, 0.0)
	if t >= RECOIL_POSE_DURATION_S:
		return Vector3.ZERO
	var spring: float = exp(-7.5 * t) * cos(17.0 * t)
	var side: float = clampf(local_direction.x, -1.0, 1.0)
	var scale: float = clampf(strength, 1.0, 1.35)
	return Vector3(RECOIL_LEAN_RAD * spring * scale, -side * RECOIL_TWIST_RAD * spring * scale, side * RECOIL_ROLL_RAD * spring * scale)
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
