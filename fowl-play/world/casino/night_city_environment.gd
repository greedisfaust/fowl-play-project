@tool
extends Node3D
class_name NightCityEnvironment

## Reusable, window-facing rainy megacity dressing for Casino and Apartment.
## facade_points are local X/Z coordinates along the window line. The city is
## generated on the outward side of that line.

@export_group("Facade")
@export var facade_points: PackedVector2Array = PackedVector2Array([
	Vector2(-24.0, -18.665), Vector2(-14.0, -28.665), Vector2(11.0, -28.665)
])
@export_range(0.5, 5.0, 0.1) var glass_clearance: float = 1.55

@export_group("City")
@export_range(12, 72, 1) var buildings_per_segment: int = 38
@export_range(0.65, 1.0, 0.01) var window_lit_ratio: float = 0.78
@export var city_seed: int = 7319

@export_group("Rain")
@export_range(300, 3600, 100) var rain_amount: int = 2100
@export_range(12.0, 30.0, 0.5) var rain_speed: float = 21.0
@export_range(0.35, 1.0, 0.05) var rain_opacity: float = 0.82
@export var wind_direction: Vector3 = Vector3(0.10, 0.0, 0.035)

@export_group("Storm")
@export var enable_lightning: bool = true
@export_range(8.0, 45.0, 1.0) var lightning_interval_min: float = 15.0
@export_range(12.0, 70.0, 1.0) var lightning_interval_max: float = 32.0

const GENERATED_ROOT := "_GeneratedNightCity"
const RAIN_SHADER_PATH := "res://world/casino/shaders/night_city_rain.gdshader"
const RAIN_LAYERS := [1.8, 8.0, 17.0]
const RAIN_SPEED_MULTIPLIERS := [1.0, 0.88, 0.72]
var _rng := RandomNumberGenerator.new()
var _flash: OmniLight3D
var _flash_timer := 0.0
var _flash_phase := 0
var _flash_energy := 0.0
var _built := false

func _ready() -> void:
	if not _built:
		_build_environment()
		_built = true
	if not Engine.is_editor_hint():
		_reset_lightning()

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not enable_lightning or _flash == null:
		return
	if _flash_phase == 0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_flash_phase = 1
			_flash_timer = 0.07
			_flash_energy = _rng.randf_range(2.2, 3.8)
			_flash.light_energy = _flash_energy
		return
	_flash_timer -= delta
	if _flash_phase == 1 and _flash_timer <= 0.0:
		_flash.light_energy = 0.0
		_flash_phase = 2
		_flash_timer = 0.11
	elif _flash_phase == 2 and _flash_timer <= 0.0:
		_flash.light_energy = _flash_energy * 0.58
		_flash_phase = 3
		_flash_timer = 0.12
	elif _flash_phase == 3 and _flash_timer <= 0.0:
		_flash.light_energy = _flash_energy * 0.16
		_flash_phase = 4
		_flash_timer = 0.18
	elif _flash_phase == 4 and _flash_timer <= 0.0:
		_flash.light_energy = 0.0
		_reset_lightning()

func _reset_lightning() -> void:
	_flash_phase = 0
	_flash_timer = _rng.randf_range(lightning_interval_min, lightning_interval_max)

func _build_environment() -> void:
	if facade_points.size() < 2:
		push_warning("NightCityEnvironment needs at least two facade points.")
		return
	_rng.seed = city_seed
	var old := get_node_or_null(GENERATED_ROOT)
	if old != null:
		old.free()
	var root := Node3D.new()
	root.name = GENERATED_ROOT
	add_child(root)
	if Engine.is_editor_hint():
		root.owner = get_tree().edited_scene_root
	var building_material := _material(Color(0.012, 0.019, 0.034), 0.0)
	var warm := _emissive(Color(1.0, 0.48, 0.19), 1.65)
	var cyan := _emissive(Color(0.16, 0.66, 0.92), 1.5)
	var pink := _emissive(Color(0.92, 0.19, 0.53), 1.55)
	var gold := _emissive(Color(1.0, 0.72, 0.32), 1.8)
	var window_mesh := BoxMesh.new()
	window_mesh.size = Vector3(0.38, 0.56, 0.045)
	var window_batches: Array = [[], [], [], []]
	var total_length := 0.0
	for i in range(facade_points.size() - 1):
		total_length += facade_points[i].distance_to(facade_points[i + 1])
	var facade_center := Vector3.ZERO
	for point in facade_points:
		facade_center += Vector3(point.x, 0.0, point.y)
	facade_center /= float(facade_points.size())
	var first_edge := Vector3(facade_points[1].x - facade_points[0].x, 0.0, facade_points[1].y - facade_points[0].y).normalized()
	var facade_outward := -first_edge.cross(Vector3.UP).normalized()
	for segment_index in range(facade_points.size() - 1):
		var a := Vector3(facade_points[segment_index].x, 0.0, facade_points[segment_index].y)
		var b := Vector3(facade_points[segment_index + 1].x, 0.0, facade_points[segment_index + 1].y)
		var edge := b - a
		var length := edge.length()
		if length < 1.0:
			continue
		var tangent := edge / length
		var inward := tangent.cross(Vector3.UP).normalized()
		var outward := -inward
		var basis := Basis(tangent, Vector3.UP, inward)
		var midpoint := (a + b) * 0.5
		var segment_buildings := maxi(8, roundi(float(buildings_per_segment) * length / maxf(1.0, total_length)))
		for layer in range(3):
			var depth_from_glass := [27.0, 51.0, 79.0][layer]
			var layer_count := int(ceil(float(segment_buildings) * [1.0, 0.82, 0.68][layer]))
			for index in range(layer_count):
				var along := -length * 0.5 + (float(index) + _rng.randf_range(-0.34, 0.34)) * length / float(layer_count)
				var width := _rng.randf_range(2.6, 7.0) * [1.0, 1.18, 1.35][layer]
				var depth := _rng.randf_range(4.0, 8.5)
				var height := _rng.randf_range(12.0, 31.0) * [1.0, 0.82, 0.65][layer]
				if _rng.randf() < 0.13:
					height *= 1.42
				var center := midpoint + tangent * along + outward * depth_from_glass + Vector3.UP * (height * 0.5 - 2.1)
				var tower := MeshInstance3D.new()
				tower.name = "Tower_%d_%02d_%02d" % [segment_index, layer, index]
				var tower_mesh := BoxMesh.new()
				tower_mesh.size = Vector3(width, height, depth)
				tower.mesh = tower_mesh
				tower.material_override = building_material
				tower.transform = Transform3D(basis, center)
				root.add_child(tower)
				if Engine.is_editor_hint():
					tower.owner = get_tree().edited_scene_root
				var columns := maxi(2, int(width / 0.92))
				var rows := maxi(3, int(height / 1.45))
				for row in range(rows):
					for column in range(columns):
						if _rng.randf() > window_lit_ratio:
							continue
						var x := -width * 0.5 + 0.48 + float(column) * (width - 0.9) / float(maxi(1, columns - 1))
						var y := -height * 0.5 + 0.95 + float(row) * 1.42
						var z := depth * 0.5 + 0.026
						var transform := Transform3D(basis, center + basis * Vector3(x, y, z))
						var choice := _rng.randi_range(0, 19)
						var batch := 0 if choice < 10 else (1 if choice < 15 else (2 if choice < 19 else 3))
						window_batches[batch].append(transform)
		_add_window_batch(root, "WarmWindows", window_mesh, warm, window_batches[0])
		_add_window_batch(root, "CyanWindows", window_mesh, cyan, window_batches[1])
		_add_window_batch(root, "PinkWindows", window_mesh, pink, window_batches[2])
		_add_window_batch(root, "GoldWindows", window_mesh, gold, window_batches[3])
		_build_rain_for_segment(root, midpoint, tangent, inward, length, segment_index, total_length)
	_build_moon(root, facade_center, facade_outward)
	_build_atmosphere(root, facade_center, facade_outward)
	_build_lightning(root, facade_center, facade_outward)

func _build_rain_for_segment(parent: Node3D, midpoint: Vector3, tangent: Vector3, inward: Vector3, length: float, segment_index: int, total_length: float) -> void:
	var basis := Basis(tangent, Vector3.UP, inward)
	var shader := load(RAIN_SHADER_PATH) as Shader
	var shader_material := ShaderMaterial.new()
	if shader != null:
		shader_material.shader = shader
		shader_material.set_shader_parameter("streak_opacity", rain_opacity)
	for layer in range(RAIN_LAYERS.size()):
		var particles := GPUParticles3D.new()
		particles.name = "Rain_%d_Distance_%d" % [segment_index, layer]
		particles.amount = maxi(100, roundi(float(rain_amount) * length / maxf(1.0, total_length) / 3.0))
		particles.lifetime = 1.45
		particles.preprocess = 1.45
		particles.explosiveness = 0.0
		particles.emitting = true
		particles.local_coords = true
		particles.transform = Transform3D(basis, midpoint + Vector3.UP * 15.0 - inward * (glass_clearance + RAIN_LAYERS[layer]))
		particles.visibility_aabb = AABB(Vector3(-length * 0.5 - 3.0, -34.0, -2.2), Vector3(length + 6.0, 38.0, 4.4))
		var process := ParticleProcessMaterial.new()
		process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		process.emission_box_extents = Vector3(length * 0.5, 0.4, 1.7)
		process.direction = Vector3(wind_direction.x, -1.0, wind_direction.z)
		process.spread = 4.0
		process.initial_velocity_min = rain_speed * RAIN_SPEED_MULTIPLIERS[layer] * 0.88
		process.initial_velocity_max = rain_speed * RAIN_SPEED_MULTIPLIERS[layer] * 1.12
		process.gravity = Vector3(1.6, -1.1, 0.65)
		process.particle_flag_align_y = true
		process.scale_min = [0.72, 0.48, 0.30][layer]
		process.scale_max = [1.24, 0.88, 0.62][layer]
		particles.process_material = process
		var streak := QuadMesh.new()
		streak.size = Vector2([0.026, 0.018, 0.012][layer], [0.52, 0.34, 0.22][layer])
		particles.draw_pass_1 = streak
		particles.material_override = shader_material
		parent.add_child(particles)
		if Engine.is_editor_hint():
			particles.owner = get_tree().edited_scene_root

func _build_moon(parent: Node3D, facade_center: Vector3, facade_outward: Vector3) -> void:
	var moon := MeshInstance3D.new()
	moon.name = "DistantMoon"
	var sphere := SphereMesh.new()
	sphere.radius = 3.4
	sphere.height = 6.8
	sphere.radial_segments = 32
	sphere.rings = 16
	moon.mesh = sphere
	moon.position = facade_center + facade_outward * 112.0 + Vector3.UP * 34.0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.78, 0.82, 0.86)
	material.emission_enabled = true
	material.emission = Color(0.28, 0.30, 0.32)
	material.emission_energy_multiplier = 0.55
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	moon.material_override = material
	parent.add_child(moon)
	if Engine.is_editor_hint():
		moon.owner = get_tree().edited_scene_root

func _build_atmosphere(parent: Node3D, facade_center: Vector3, facade_outward: Vector3) -> void:
	var fog := FogVolume.new()
	fog.name = "CityRainHaze"
	fog.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	fog.size = Vector3(92.0, 30.0, 90.0)
	fog.position = facade_center + facade_outward * 54.0 + Vector3.UP * 9.0
	var material := FogMaterial.new()
	material.density = 0.018
	material.albedo = Color(0.24, 0.27, 0.32)
	material.height_falloff = 0.16
	fog.material = material
	parent.add_child(fog)
	if Engine.is_editor_hint():
		fog.owner = get_tree().edited_scene_root

func _build_lightning(parent: Node3D, facade_center: Vector3, facade_outward: Vector3) -> void:
	_flash = OmniLight3D.new()
	_flash.name = "DistantStormFlash"
	_flash.position = facade_center + facade_outward * 55.0 + Vector3.UP * 20.0
	_flash.light_color = Color(0.72, 0.80, 0.92)
	_flash.light_energy = 0.0
	_flash.omni_range = 105.0
	_flash.omni_attenuation = 1.25
	_flash.shadow_enabled = false
	parent.add_child(_flash)
	if Engine.is_editor_hint():
		_flash.owner = get_tree().edited_scene_root

func _add_window_batch(parent: Node3D, node_name: String, mesh: Mesh, material: Material, transforms: Array) -> void:
	if transforms.is_empty():
		return
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for i in range(transforms.size()):
		multi.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multi
	instance.material_override = material
	parent.add_child(instance)
	if Engine.is_editor_hint():
		instance.owner = get_tree().edited_scene_root

func _material(color: Color, metallic: float) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metallic
	result.roughness = 0.88
	return result

func _emissive(color: Color, energy: float) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.emission_enabled = true
	result.emission = color
	result.emission_energy_multiplier = energy
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return result
