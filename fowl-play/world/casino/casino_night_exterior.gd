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

const CITY_Z: float = -66.0
const CITY_START_X: float = -43.0
const CITY_WIDTH: float = 86.0
const CITY_BASE_Y: float = -2.0
const RAIN_ORIGIN: Vector3 = Vector3(0.0, 13.0, -38.0)
const RAIN_EXTENTS: Vector3 = Vector3(35.0, 0.5, 15.0)

var _built: bool = false

func _ready() -> void:
	if not _built:
		_build_exterior()
		_built = true

func _build_exterior() -> void:
	if generate_moon:
		_build_moon()
	if generate_city:
		_build_city()
	if generate_rain:
		_build_rain()

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
	process.direction = Vector3(0.015, -1.0, -0.025)
	process.spread = 3.0
	process.initial_velocity_min = rain_fall_speed * 0.82
	process.initial_velocity_max = rain_fall_speed * 1.18
	process.gravity = Vector3(0.0, -1.5, 0.0)
	process.scale_min = 0.8
	process.scale_max = 1.2
	particles.process_material = process

	var drop := BoxMesh.new()
	drop.size = Vector3(0.012, 0.48, 0.012)
	var drop_material := StandardMaterial3D.new()
	drop_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop_material.albedo_color = Color(0.48, 0.72, 1.0, rain_opacity)
	drop_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop_material.roughness = 0.25
	particles.draw_pass_1 = drop
	particles.material_override = drop_material
	add_child(particles)

func _make_emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material
