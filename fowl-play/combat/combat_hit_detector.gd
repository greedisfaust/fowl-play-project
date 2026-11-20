## Host-side obstruction-aware punch queries. Network validates and applies every result.
extends RefCounted
const LAYERS = preload("res://core/layers.gd")
const TUNING = preload("res://core/tuning.gd")
static func get_jab_collision_mask() -> int:
	return LAYERS.LAYER_MASK_PUNCH_HITBOX | (1 << (LAYERS.WORLD_STATIC - 1)) | (1 << (LAYERS.DEVICES - 1)) | (1 << (LAYERS.CARRIED - 1)) | (1 << (LAYERS.ELEVATOR - 1))
static func trace_jab(attacker: Node3D, origin: Vector3, direction: Vector3, reach: float) -> Dictionary:
	if not is_instance_valid(attacker) or not origin.is_finite() or not direction.is_finite():
		return {}
	if direction.length_squared() < 0.0001 or not is_finite(reach) or reach <= 0.0:
		return {}
	var ray_end: Vector3 = get_jab_endpoint(origin, direction, reach)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, ray_end, get_jab_collision_mask())
	query.exclude = [attacker.get_rid()]
	query.collide_with_areas = false
	var hit: Dictionary = attacker.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var target: Node3D = _find_player(hit.get("collider") as Object)
	if not is_instance_valid(target) or target == attacker:
		return {"blocked": true, "position": hit.get("position", ray_end)}
	return {"target": target, "position": hit.get("position", target.global_position), "normal": hit.get("normal", Vector3.UP)}
## Host-side capsule query follows the attacker through the lunge and gathers
## every distinct player inside the volume, while checking world obstruction.
static func trace_lunge_targets(attacker: Node3D, origin: Vector3, direction: Vector3, reach: float) -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	if not is_instance_valid(attacker) or not origin.is_finite() or not direction.is_finite():
		return targets
	if direction.length_squared() < 0.0001 or not is_finite(reach) or reach <= 0.0:
		return targets
	var forward: Vector3 = direction.normalized()
	var radius: float = TUNING.LUNGE_HIT_RADIUS_M
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = maxf(reach, radius * 2.0)
	var alignment_basis: Basis = Basis.IDENTITY
	var alignment_axis: Vector3 = Vector3.UP.cross(forward)
	if alignment_axis.length_squared() > 0.0001:
		alignment_basis = Basis(alignment_axis.normalized(), Vector3.UP.angle_to(forward))
	elif Vector3.UP.dot(forward) < 0.0:
		alignment_basis = Basis(Vector3.RIGHT, PI)
	var capsule_center: Vector3 = origin + forward * (reach * 0.5)
	var shape_query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	shape_query.shape = capsule
	shape_query.transform = Transform3D(alignment_basis, capsule_center)
	shape_query.collision_mask = 1 << (LAYERS.HEALTHY_PLAYERS - 1)
	shape_query.exclude = [attacker.get_rid()]
	shape_query.collide_with_areas = false
	var space: PhysicsDirectSpaceState3D = attacker.get_world_3d().direct_space_state
	var overlaps: Array[Dictionary] = space.intersect_shape(shape_query, TUNING.MAX_PLAYERS - 1)
	var obstruction_mask: int = (1 << (LAYERS.WORLD_STATIC - 1)) | (1 << (LAYERS.DEVICES - 1)) | (1 << (LAYERS.PROPS - 1)) | (1 << (LAYERS.CARRIED - 1)) | (1 << (LAYERS.ELEVATOR - 1))
	var seen_targets: Dictionary = {}
	for overlap: Dictionary in overlaps:
		var collider: Object = overlap.get("collider") as Object
		var target: Node3D = _find_player(collider)
		if not is_instance_valid(target) or target == attacker or seen_targets.has(target.get_instance_id()):
			continue
		seen_targets[target.get_instance_id()] = true
		var target_point: Vector3 = target.global_position + Vector3.UP * 0.9
		var blocker_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, target_point, obstruction_mask)
		blocker_query.exclude = [attacker.get_rid()]
		blocker_query.collide_with_areas = false
		if not space.intersect_ray(blocker_query).is_empty():
			continue
		targets.append({
			"target": target,
			"position": target_point,
			"normal": Vector3.UP
		})
	return targets

static func get_jab_endpoint(origin: Vector3, direction: Vector3, reach: float) -> Vector3:
	if not origin.is_finite() or not direction.is_finite() or direction.length_squared() < 0.0001:
		return origin
	if not is_finite(reach) or reach <= 0.0:
		return origin
	return origin + direction.normalized() * reach
static func _find_player(collider: Object) -> Node3D:
	var cursor: Node = collider as Node
	while cursor != null:
		if cursor.has_method("begin_host_limp") and cursor.has_method("is_carrying") and cursor is Node3D:
			return cursor as Node3D
		cursor = cursor.get_parent()
	return null
