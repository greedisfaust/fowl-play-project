## Lightweight synchronized egg presentation. The host supplies the complete path.
class_name EggPlinkoEgg
extends Node3D

signal animation_finished(egg_id: String)

var egg_id: String = ""
var path: PackedVector3Array = PackedVector3Array()
var flight_duration: float = 3.4
var _elapsed: float = 0.0
var _finished: bool = false


func configure(record: Dictionary) -> void:
	egg_id = str(record.get("egg_id", ""))
	var path_value: Variant = record.get("path", PackedVector3Array())
	if path_value is PackedVector3Array:
		path = path_value
	elif path_value is Array:
		path = PackedVector3Array(path_value)
	flight_duration = maxf(float(record.get("flight_duration", 3.4)), 0.1)
	_elapsed = 0.0
	_finished = false
	_build_shell(Color(record.get("player_color", Color.WHITE)))


func _process(delta: float) -> void:
	if _finished or path.size() < 2:
		return
	_elapsed += delta
	var progress: float = clampf(_elapsed / flight_duration, 0.0, 1.0)
	var segment_float: float = progress * float(path.size() - 1)
	var segment_index: int = mini(floori(segment_float), path.size() - 2)
	var segment_progress: float = segment_float - float(segment_index)
	var eased: float = _ease_in_out(segment_progress)
	var position_a: Vector3 = path[segment_index]
	var position_b: Vector3 = path[segment_index + 1]
	position = position_a.lerp(position_b, eased)
	var travel_direction: Vector3 = position_b - position_a
	if travel_direction.length_squared() > 0.0001:
		rotation.z = atan2(-travel_direction.x, -travel_direction.y)
	rotation.x = sin(_elapsed * 15.0) * 0.045
	if progress >= 1.0:
		_finished = true
		position = path[path.size() - 1]
		animation_finished.emit(egg_id)


func _build_shell(player_color: Color) -> void:
	for child: Node in get_children():
		child.queue_free()
	var shell := MeshInstance3D.new()
	shell.name = "EggShell"
	var egg_mesh := SphereMesh.new()
	egg_mesh.radius = 0.04
	egg_mesh.height = 0.08
	egg_mesh.radial_segments = 20
	egg_mesh.rings = 12
	shell.mesh = egg_mesh
	shell.scale = Vector3(0.82, 1.0, 0.82)
	var shell_material := StandardMaterial3D.new()
	shell_material.albedo_color = player_color
	shell_material.metallic = 0.12
	shell_material.roughness = 0.24
	shell_material.emission_enabled = true
	shell_material.emission = player_color
	shell_material.emission_energy_multiplier = 0.12
	shell.material_override = shell_material
	add_child(shell)

	var crown := MeshInstance3D.new()
	crown.name = "GoldCrown"
	var crown_mesh := TorusMesh.new()
	crown_mesh.inner_radius = 0.024
	crown_mesh.outer_radius = 0.029
	crown_mesh.rings = 8
	crown_mesh.ring_segments = 16
	crown.mesh = crown_mesh
	crown.position.y = 0.012
	crown.rotation.x = PI * 0.5
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.92, 0.68, 0.27, 1.0)
	gold.metallic = 0.82
	gold.roughness = 0.24
	crown.material_override = gold
	add_child(crown)


func _ease_in_out(value: float) -> float:
	return value * value * (3.0 - 2.0 * value)
