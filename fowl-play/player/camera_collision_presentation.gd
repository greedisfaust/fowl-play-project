## Smooth first-person camera obstruction response.
extends RefCounted

const CAMERA_CLEARANCE: float = 0.14
const RELEASE_RESPONSE: float = 12.0

var _current_distance: float = 0.0
var _initialized: bool = false

func advance(origin: Vector3, desired_position: Vector3, has_hit: bool, hit_position: Vector3, delta: float) -> Vector3:
	var ray: Vector3 = desired_position - origin
	var desired_distance: float = ray.length()
	if desired_distance <= 0.0001:
		return origin
	var target_distance: float = desired_distance
	if has_hit:
		target_distance = clampf(origin.distance_to(hit_position) - CAMERA_CLEARANCE, 0.0, desired_distance)
	if not _initialized:
		_current_distance = target_distance
		_initialized = true
	elif has_hit:
		_current_distance = minf(_current_distance, target_distance)
	else:
		var blend: float = 1.0 - exp(-RELEASE_RESPONSE * maxf(delta, 0.0))
		_current_distance = lerpf(_current_distance, target_distance, blend)
	return origin + ray / desired_distance * _current_distance

func reset() -> void:
	_current_distance = 0.0
	_initialized = false
