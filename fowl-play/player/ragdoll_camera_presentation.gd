## Local-only filtering for the first-person view while the body is ragdolled.
## It smooths the simulated head pose without changing physics or replicated state.
extends RefCounted

const POSITION_RESPONSE: float = 14.0
const ROTATION_RESPONSE: float = 9.0

var _current_transform: Transform3D = Transform3D.IDENTITY
var _initialized: bool = false

func begin(initial_transform: Transform3D) -> void:
	_current_transform = initial_transform.orthonormalized()
	_initialized = true

func advance(target_transform: Transform3D, delta: float) -> Transform3D:
	if not target_transform.is_finite():
		return _current_transform
	if not _initialized:
		_current_transform = target_transform.orthonormalized()
		_initialized = true
		return _current_transform
	var step: float = maxf(delta, 0.0)
	var position_weight: float = 1.0 - exp(-POSITION_RESPONSE * step)
	var rotation_weight: float = 1.0 - exp(-ROTATION_RESPONSE * step)
	var current_rotation: Quaternion = _current_transform.basis.get_rotation_quaternion()
	var target_rotation: Quaternion = target_transform.basis.get_rotation_quaternion()
	var blended_rotation: Quaternion = current_rotation.slerp(target_rotation, rotation_weight).normalized()
	var blended_origin: Vector3 = _current_transform.origin.lerp(target_transform.origin, position_weight)
	_current_transform = Transform3D(Basis(blended_rotation), blended_origin)
	return _current_transform

static func recovery_weight(elapsed: float, duration: float) -> float:
	if duration <= 0.0001:
		return 1.0
	var progress: float = clampf(elapsed / duration, 0.0, 1.0)
	# Quintic smootherstep eases both the start and end of the get-up blend.
	return progress * progress * progress * (progress * (progress * 6.0 - 15.0) + 10.0)

func reset() -> void:
	_current_transform = Transform3D.IDENTITY
	_initialized = false
