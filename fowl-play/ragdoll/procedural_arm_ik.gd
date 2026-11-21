## Small, allocation-light two-bone IK position solver shared by procedural limbs.
class_name ProceduralArmIK
extends RefCounted

static func solve_two_bone(shoulder: Vector3, target: Vector3, pole: Vector3, upper_length: float, forearm_length: float) -> Dictionary:
	if not shoulder.is_finite() or not target.is_finite() or not pole.is_finite():
		return {}
	if upper_length <= 0.001 or forearm_length <= 0.001:
		return {}
	var offset: Vector3 = target - shoulder
	var raw_distance: float = offset.length()
	if raw_distance <= 0.0001:
		return {}
	var direction: Vector3 = offset / raw_distance
	var minimum_distance: float = absf(upper_length - forearm_length) + 0.001
	var maximum_distance: float = upper_length + forearm_length - 0.001
	var solved_distance: float = clampf(raw_distance, minimum_distance, maximum_distance)
	var along: float = (upper_length * upper_length - forearm_length * forearm_length + solved_distance * solved_distance) / (2.0 * solved_distance)
	var height_squared: float = maxf(upper_length * upper_length - along * along, 0.0)
	var bend_direction: Vector3 = pole - direction * pole.dot(direction)
	if bend_direction.length_squared() <= 0.000001:
		var fallback: Vector3 = Vector3.DOWN if absf(direction.dot(Vector3.DOWN)) < 0.95 else Vector3.RIGHT
		bend_direction = fallback - direction * fallback.dot(direction)
	bend_direction = bend_direction.normalized()
	var solved_target: Vector3 = shoulder + direction * solved_distance
	var elbow: Vector3 = shoulder + direction * along + bend_direction * sqrt(height_squared)
	return {"elbow": elbow, "target": solved_target, "clamped": not is_equal_approx(raw_distance, solved_distance)}
