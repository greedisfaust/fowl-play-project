## Pure horizontal movement response shared by the Player controller and headless checks.
extends RefCounted

func advance_horizontal_velocity(
	current_velocity: Vector3,
	move_direction: Vector3,
	target_speed: float,
	acceleration: float,
	deceleration: float,
	delta: float,
	turn_acceleration: float = -1.0
) -> Vector3:
	var safe_direction: Vector3 = Vector3(move_direction.x, 0.0, move_direction.z)
	if safe_direction.length_squared() > 1.0:
		safe_direction = safe_direction.normalized()
	var target_velocity: Vector3 = safe_direction * maxf(target_speed, 0.0)
	var horizontal_velocity: Vector3 = Vector3(current_velocity.x, 0.0, current_velocity.z)
	var response: float = acceleration if not safe_direction.is_zero_approx() else deceleration
	if not safe_direction.is_zero_approx() and horizontal_velocity.length_squared() > 0.04:
		var direction_dot: float = horizontal_velocity.normalized().dot(safe_direction)
		if direction_dot < 0.75 and turn_acceleration > 0.0:
			response = maxf(response, turn_acceleration)
	return horizontal_velocity.move_toward(target_velocity, maxf(response, 0.0) * maxf(delta, 0.0))
