@tool
extends Node3D
class_name CasinoNightExterior

## Local, non-networked nighttime dressing for the casino exterior.
## Coordinates are relative to the Casino root. The panoramic façade faces -Z.

@export_group("Moon")
@export var generate_moon: bool = true
@export var moon_position: Vector3 = Vector3(17.0, 22.0, -78.0)
@export_range(1.0, 12.0, 0.5) var moon_radius: float = 4.5

@export_group("City Skyline")
@export var generate_city: bool = true
@export_range(6, 32, 1) var building_count: int = 18
@export_range(0.0, 1.0, 0.05) var window_lit_ratio: float = 0.68

@export_group("Rain")
@export var generate_rain: bool = true
@export_range(100, 2000, 50) var rain_amount: int = 900
@export_range(4.0, 24.0, 0.5) var rain_fall_speed: float = 13.0
@export_range(0.1, 1.0, 0.05) var rain_opacity: float = 0.62

@export_group("Window Rain")
@export var generate_window_rain: bool = true
@export_range(0.1, 1.0, 0.05) var window_rain_opacity: float = 0.72

@export_group("Exterior Atmosphere")
@export var generate_exterior_mist: bool = true
@export_range(0.001, 0.08, 0.001) var mist_density: float = 0.024

@export_group("Lightning")
@export var generate_lightning: bool = true
@export_range(6.0, 40.0, 1.0) var lightning_interval_min: float = 12.0
@export_range(8.0, 60.0, 1.0) var lightning_interval_max: float = 27.0

const CITY_Z: float = -66.0
const CITY_START_X: float = -43.0
const CITY_WIDTH: float = 86.0
const CITY_BASE_Y: float = -2.0
const RAIN_ORIGIN: Vector3 = Vector3(0.0, 13.0, -42.0)
const RAIN_EXTENTS: Vector3 = Vector3(35.0, 0.5, 8.0)

var _built: bool = false
var _lightning: OmniLight3D
var _lightning_cooldown: float = 0.0
var _lightning_phase: int = 0
var _lightning_phase_time: float = 0.0

func _ready() -> void:
	if not _built:
		_build_exterior()
		_built = true
	_lightning_cooldown = randf_range(lightning_interval_min, lightning_interval_max)

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not generate_lightning or _lightning == null:
		return
	_update_lightning(delta)

func _update_lightning(delta: float) -> void:
	if _lightning_phase == 0:
		_lightning_cooldown -= delta
		if _lightning_cooldown <= 0.0:
			_lightning_phase = 1
			_lightning_phase_time = 0.0
			_lightning.light_energy = randf_range(1.8, 2.8)
		return

	_lightning_phase_time += delta
	match _lightning_phase:
		1:
			if _lightning_phase_time >= 0.075:
				_lightning.light_energy = 0.0
				_lightning_phase = 2
				_lightning_phase_time = 0.0
		2:
			if _lightning_phase_time >= 0.10:
				_lightning.light_energy = randf_range(0.9, 1.55)
				_lightning_phase = 3
				_lightning_phase_time = 0.0
		3:
			if _lightning_phase_time >= 0.13:
				_lightning.light_energy = 0.35
				_lightning_phase = 4
				_lightning_phase_time = 0.12
		4:
			_lightning.light_energy = move_toward(_lightning.light_energy, 0.0, delta * 4.5)
			if _lightning.light_energy <= 0.01:
				_lightning_phase = 0
				_lightning_cooldown = randf_range(lightning_interval_min, lightning_interval_max)

func _build_exterior() -> void:
	if generate_moon:
		_build_moon()
	if generate_city:
		_build_city()
	if generate_rain:
		_build_rain()
	if generate_window_rain:
		_build_window_rain()
	if generate_exterior_mist:
		_build_exterior_mist()
	if generate_lightning:
		_build_lightning()

func _build_moon() -> void:
	var moon := MeshInstance3D.new()
	moon.name = "VisibleMoon"
	var sphere := SphereMesh.new()
	sphere.radius = moon_radius
	sphere.height = moon_radius * 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	moon.mesh = sphere
	moon.position = moon_position
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.72, 0.82, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.52, 0.68, 1.0)
	material.emission_energy_multiplier = 1.35
	material.roughness = 1.0
	moon.material_override = material
	add_child(moon)

func _build_city() -> void:
	var city_root := Node3D.new()
	city_root.name = "DenseNightCity"
	add_child(city_root)

	var building_material := StandardMaterial3D.new()
	building_material.albedo_color = Color(0.018, 0.027, 0.052)
	building_material.roughness = 0.92
	building_material.metallic = 0.08

	var warm_window := _make_emissive_material(Color(1.0, 0.58, 0.24), 1.8)
	var cool_window := _make_emissive_material(Color(0.22, 0.68, 1.0), 1.35)
	var pink_window := _make_emissive_material(Color(0.95, 0.22, 0.62), 1.4)
	var window_mesh := BoxMesh.new()
	window_mesh.size = Vector3(0.42, 0.62, 0.055)

	var warm_transforms: Array[Transform3D] = []
	var cool_transforms: Array[Transform3D] = []
	var pink_transforms: Array[Transform3D] = []

	for index: int in range(building_count):
		var t := float(index) / float(maxi(1, building_count - 1))
		var x := CITY_START_X + t * CITY_WIDTH
		var width := 4.0 + float((index * 7) % 5) * 0.72
		var depth := 5.0 + float((index * 3) % 4) * 1.1
		var height := 11.0 + float((index * 11) % 9) * 3.1
		var center_x := x + width * 0.5
		var center_z := CITY_Z - float((index * 13) % 5) * 3.0
		var building := MeshInstance3D.new()
		building.name = "Tower_%02d" % index
		var mesh := BoxMesh.new()
		mesh.size = Vector3(width, height, depth)
		building.mesh = mesh
		building.material_override = building_material
		building.position = Vector3(center_x, CITY_BASE_Y + height * 0.5, center_z)
		city_root.add_child(building)

		var columns := maxi(2, int(width / 1.15))
		var rows := maxi(3, int(height / 1.65))
		for row: int in range(rows):
			for column: int in range(columns):
				var hash_value := (index * 37 + row * 19 + column * 13) % 100
				if float(hash_value) / 100.0 > window_lit_ratio:
					continue
				var wx := center_x - width * 0.5 + 0.65 + float(column) * (width - 1.0) / float(maxi(1, columns - 1))
				var wy := CITY_BASE_Y + 0.9 + float(row) * 1.55
				var wz := center_z + depth * 0.5 + 0.045
				var transform := Transform3D(Basis.IDENTITY, Vector3(wx, wy, wz))
				match hash_value % 9:
					0, 1:
						pink_transforms.append(transform)
					2, 3, 4:
						cool_transforms.append(transform)
					_:
						warm_transforms.append(transform)

	_add_window_multimesh(city_root, "WarmWindows", window_mesh, warm_window, warm_transforms)
	_add_window_multimesh(city_root, "CoolWindows", window_mesh, cool_window, cool_transforms)
	_add_window_multimesh(city_root, "PinkWindows", window_mesh, pink_window, pink_transforms)

func _add_window_multimesh(parent: Node3D, node_name: String, mesh: Mesh, material: Material, transforms: Array[Transform3D]) -> void:
	if transforms.is_empty():
		return
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for index: int in range(transforms.size()):
		multi.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multi
	instance.material_override = material
	parent.add_child(instance)

func _build_rain() -> void:
	var particles := GPUParticles3D.new()
	particles.name = "ExteriorRain"
	particles.amount = rain_amount
	particles.lifetime = 1.7
	particles.preprocess = 1.7
	particles.emitting = true
	particles.local_coords = true
	particles.position = RAIN_ORIGIN
	particles.visibility_aabb = AABB(Vector3(-38.0, -18.0, -18.0), Vector3(76.0, 34.0, 36.0))

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = RAIN_EXTENTS
	# A slight diagonal fall and crosswind keep the rain from reading as a
	# perfectly vertical particle curtain. Align-Y makes the long mesh follow
	# each particle's velocity rather than facing the camera like a billboard.
	process.direction = Vector3(0.055, -1.0, -0.035)
	process.spread = 6.0
	process.initial_velocity_min = rain_fall_speed * 0.86
	process.initial_velocity_max = rain_fall_speed * 1.16
	process.gravity = Vector3(1.15, -1.5, 0.45)
	process.particle_flag_align_y = true
	process.scale_min = 0.72
	process.scale_max = 1.28
	particles.process_material = process

	# A procedural tapered quad avoids the plastic capsule silhouette. The
	# shader creates a soft, narrow streak and lets real exterior lighting reveal it.
	var drop := QuadMesh.new()
	drop.size = Vector2(0.018, 0.38)
	var streak_shader := load("res://world/casino/shaders/rain_streak.gdshader") as Shader
	if streak_shader == null:
		push_warning("Rain streak shader could not be loaded.")
	else:
		var streak_material := ShaderMaterial.new()
		streak_material.shader = streak_shader
		streak_material.set_shader_parameter("streak_opacity", rain_opacity * 0.78)
		particles.material_override = streak_material
	particles.draw_pass_1 = drop
	add_child(particles)

func _build_window_rain() -> void:
	var casino_root := get_parent()
	if casino_root == null:
		return
	var facade := casino_root.get_node_or_null("Architecture/WindowFrames/_GeneratedPanoramicFacade")
	if facade == null:
		return

	var rain_shader := load("res://world/casino/shaders/window_rain.gdshader") as Shader
	if rain_shader == null:
		push_warning("Window rain shader could not be loaded.")
		return

	for child: Node in facade.get_children():
		if not child is MeshInstance3D or not child.name.ends_with("_Glass"):
			continue
		var glass := child as MeshInstance3D
		var glass_box := glass.mesh as BoxMesh
		if glass_box == null:
			continue

		var pane := MeshInstance3D.new()
		pane.name = "%s_ExteriorWater" % glass.name
		var quad := QuadMesh.new()
		quad.size = Vector2(glass_box.size.x, glass_box.size.y)
		pane.mesh = quad
		var water_material := ShaderMaterial.new()
		water_material.shader = rain_shader
		water_material.set_shader_parameter("water_opacity", window_rain_opacity)
		pane.material_override = water_material
		pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(pane)
		# The facade's local +Z normal faces into the casino; rain belongs on its exterior (-Z) face.
		var surface_offset := Vector3(0.0, 0.0, -glass_box.size.z * 0.5 - 0.012)
		pane.global_transform = Transform3D(glass.global_transform.basis, glass.global_transform * surface_offset)

func _build_exterior_mist() -> void:
	var fog_volume := FogVolume.new()
	fog_volume.name = "ExteriorRainMist"
	fog_volume.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	fog_volume.size = Vector3(74.0, 22.0, 34.0)
	fog_volume.position = Vector3(0.0, 8.0, -47.0)
	var fog_material := FogMaterial.new()
	fog_material.density = mist_density
	fog_material.albedo = Color(0.24, 0.31, 0.46)
	fog_material.height_falloff = 0.18
	fog_volume.material = fog_material
	add_child(fog_volume)

func _build_lightning() -> void:
	_lightning = OmniLight3D.new()
	_lightning.name = "ExteriorStormFlash"
	_lightning.position = Vector3(0.0, 17.0, -58.0)
	_lightning.light_color = Color(0.68, 0.78, 1.0)
	_lightning.light_energy = 0.0
	_lightning.omni_range = 38.0
	_lightning.omni_attenuation = 1.35
	_lightning.shadow_enabled = false
	add_child(_lightning)

func _make_emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material
