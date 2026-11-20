## Host-side jab ray query. Network validates and applies every result.
extends RefCounted
const LAYERS = preload("res://core/layers.gd")
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
