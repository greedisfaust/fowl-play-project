## Pure horizontal movement response shared by the Player controller and headless checks.
extends RefCounted

func advance_horizontal_velocity(
	current_velocity: Vector3,
	move_direction: Vector3,
	target_speed: float,
	acceleration: float,
	deceleration: float,
	delta: float
) -> Vector3:
	var safe_direction: Vector3 = Vector3(move_direction.x, 0.0, move_direction.z)
	if safe_direction.length_squared() > 1.0:
		safe_direction = safe_direction.normalized()
	var target_velocity: Vector3 = safe_direction * maxf(target_speed, 0.0)
	var horizontal_velocity: Vector3 = Vector3(current_velocity.x, 0.0, current_velocity.z)
	var response: float = acceleration if not safe_direction.is_zero_approx() else deceleration
	return horizontal_velocity.move_toward(target_velocity, maxf(response, 0.0) * maxf(delta, 0.0))
