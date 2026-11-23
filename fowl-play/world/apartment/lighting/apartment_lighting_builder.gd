@tool
extends Node3D
class_name ApartmentLightingBuilder

## Soft residential lighting for the Apartment.
## Attach to Environment/Lighting at local origin. Uses the shared Fowl Play
## light rig so both environments follow the same construction and quality rules.

const LightingRig = preload("res://world/shared/lighting/fowl_play_lighting_rig.gd")

@export_group("Main Room")
@export var generate_main_room_lights: bool = true
@export var main_room_light_color: Color = Color(1.0, 0.82, 0.66, 1.0)
@export_range(0.1, 4.0, 0.05) var main_room_light_energy: float = 0.82
@export_range(3.0, 16.0, 0.5) var main_room_light_range: float = 9.5
@export_range(0.0, 2.0, 0.05) var window_side_fill_energy: float = 0.28

@export_group("Hallway")
@export var generate_hallway_lights: bool = true
@export var hallway_light_color: Color = Color(1.0, 0.76, 0.58, 1.0)
@export_range(0.1, 3.0, 0.05) var hallway_light_energy: float = 0.58
@export_range(2.0, 10.0, 0.5) var hallway_light_range: float = 5.5
@export var hallway_light_start_z: float = -14.0
@export var hallway_light_end_z: float = 1.5
@export_range(2, 8, 1) var hallway_light_count: int = 4

@export_group("Elevator Lobby")
@export var generate_lobby_lights: bool = true
@export var lobby_light_color: Color = Color(1.0, 0.82, 0.66, 1.0)
@export_range(0.1, 4.0, 0.05) var lobby_light_energy: float = 0.92
@export_range(2.0, 10.0, 0.5) var lobby_light_range: float = 5.0

@export_group("Light Quality")
@export var enable_shadows: bool = false
@export_range(0.0, 1.0, 0.05) var light_specular: float = 0.32

@export_group("Generation")
@export var rebuild_lighting: bool = false:
	set(value):
		if value:
			call_deferred("_rebuild_lighting")

const GENERATED_ROOT_NAME: String = "_GeneratedApartmentLighting"

func _ready() -> void:
	if Engine.is_editor_hint() and get_node_or_null(GENERATED_ROOT_NAME) == null:
		_rebuild_lighting()

func _rebuild_lighting() -> void:
	if not Engine.is_editor_hint():
		return
	var scene_root: Node = get_tree().edited_scene_root
	if scene_root == null:
		return
	var old_root: Node = get_node_or_null(GENERATED_ROOT_NAME)
	if old_root != null:
		old_root.free()

	var world_environment: WorldEnvironment = scene_root.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if world_environment == null:
		world_environment = WorldEnvironment.new()
		world_environment.name = "WorldEnvironment"
		scene_root.add_child(world_environment)
		world_environment.owner = scene_root
	world_environment.environment = load("res://world/casino/casino_night_environment.tres") as Environment

	var generated_root: Node3D = Node3D.new()
	generated_root.name = GENERATED_ROOT_NAME
	add_child(generated_root)
	generated_root.owner = scene_root

	if generate_main_room_lights:
		_build_main_room_lights(generated_root, scene_root)
		_build_circular_fixture(generated_root, scene_root)
	if generate_hallway_lights:
		_build_hallway_lights(generated_root, scene_root)
		_build_hallway_sconces(generated_root, scene_root)
	if generate_lobby_lights:
		_build_lobby_lights(generated_root, scene_root)

func _build_main_room_lights(parent: Node3D, scene_root: Node) -> void:
	# Six gentle ceiling pools cover the communal room without flattening its corners.
	var x_positions: Array[float] = [-6.5, 0.0, 6.5]
	var z_positions: Array[float] = [-4.8, 4.8]
	for row_index: int in range(z_positions.size()):
		for column_index: int in range(x_positions.size()):
			var light_name: String = "MainRoom_Ceiling_%d_%d" % [row_index + 1, column_index + 1]
			_add_omni_light(
				parent, light_name,
				Vector3(x_positions[column_index], 3.48, z_positions[row_index]),
				main_room_light_color, main_room_light_energy,
				main_room_light_range, scene_root
			)

	# A very soft cool-neutral edge fill keeps the panoramic seating area legible.
	if window_side_fill_energy > 0.01:
		_add_omni_light(
			parent, "MainRoom_CityWindow_SoftFill",
			Vector3(7.6, 3.25, 0.0),
			Color(0.68, 0.76, 0.88, 1.0), window_side_fill_energy,
			6.5, scene_root
		)

func _build_hallway_lights(parent: Node3D, scene_root: Node) -> void:
	if hallway_light_count < 1:
		return
	for light_index: int in range(hallway_light_count):
		var progress: float = 0.5
		if hallway_light_count > 1:
			progress = float(light_index) / float(hallway_light_count - 1)
		var light_z: float = lerpf(hallway_light_start_z, hallway_light_end_z, progress)
		_add_omni_light(
			parent, "Hallway_Ceiling_%02d" % (light_index + 1),
			Vector3(-12.75, 3.42, light_z),
			hallway_light_color, hallway_light_energy,
			hallway_light_range, scene_root
		)

func _build_lobby_lights(parent: Node3D, scene_root: Node) -> void:
	_add_omni_light(
		parent, "ElevatorLobby_Ceiling_Main",
		Vector3(-12.75, 3.42, -19.25),
		lobby_light_color, lobby_light_energy,
		lobby_light_range, scene_root
	)
	_add_omni_light(
		parent, "ElevatorLobby_Elevator_WelcomeFill",
		Vector3(-12.75, 2.9, -20.7),
		lobby_light_color, lobby_light_energy * 0.48,
		3.5, scene_root
	)


func _build_circular_fixture(parent: Node3D, scene_root: Node) -> void:
	var bronze: StandardMaterial3D = StandardMaterial3D.new()
	bronze.albedo_color = Color(0.34, 0.20, 0.095)
	bronze.metallic = 0.82
	bronze.roughness = 0.22
	var diffuser: StandardMaterial3D = StandardMaterial3D.new()
	diffuser.albedo_color = Color(1.0, 0.78, 0.52)
	diffuser.emission_enabled = true
	diffuser.emission = Color(1.0, 0.52, 0.22)
	diffuser.emission_energy_multiplier = 1.7
	var fixture: Node3D = Node3D.new()
	fixture.name = "MainRoom_Grand_Circular_Fixture"
	fixture.position = Vector3(0.0, 3.70, 0.0)
	parent.add_child(fixture)
	fixture.owner = scene_root
	for ring_index: int in range(2):
		var ring: MeshInstance3D = MeshInstance3D.new()
		ring.name = "Bronze_Ring_%d" % ring_index
		var torus: TorusMesh = TorusMesh.new()
		torus.inner_radius = 1.05 + float(ring_index) * 0.62
		torus.outer_radius = torus.inner_radius + 0.045
		ring.mesh = torus
		ring.material_override = bronze
		fixture.add_child(ring)
		ring.owner = scene_root
	var diffuser_ring: MeshInstance3D = MeshInstance3D.new()
	diffuser_ring.name = "Warm_Diffuser_Ring"
	var diffuser_mesh: TorusMesh = TorusMesh.new()
	diffuser_mesh.inner_radius = 1.34
	diffuser_mesh.outer_radius = 1.47
	diffuser_ring.mesh = diffuser_mesh
	diffuser_ring.material_override = diffuser
	fixture.add_child(diffuser_ring)
	diffuser_ring.owner = scene_root
	for index: int in range(8):
		var angle: float = TAU * float(index) / 8.0
		var spot: SpotLight3D = SpotLight3D.new()
		spot.name = "Fixture_Downlight_%02d" % index
		spot.position = Vector3(cos(angle) * 2.0, -0.18, sin(angle) * 2.0)
		spot.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
		spot.light_color = Color(1.0, 0.78, 0.57)
		spot.light_energy = 1.15
		spot.spot_range = 7.0
		spot.spot_angle = 62.0
		spot.shadow_enabled = false
		fixture.add_child(spot)
		spot.owner = scene_root

func _build_hallway_sconces(parent: Node3D, scene_root: Node) -> void:
	var brass: StandardMaterial3D = StandardMaterial3D.new()
	brass.albedo_color = Color(0.42, 0.27, 0.13)
	brass.metallic = 0.82
	brass.roughness = 0.24
	var shade: StandardMaterial3D = StandardMaterial3D.new()
	shade.albedo_color = Color(1.0, 0.72, 0.45)
	shade.emission_enabled = true
	shade.emission = Color(1.0, 0.45, 0.18)
	shade.emission_energy_multiplier = 1.25
	for index: int in range(6):
		var z: float = -14.0 + float(index) * 5.6
		var sconce: Node3D = Node3D.new()
		sconce.name = "Hallway_Wall_Sconce_%02d" % index
		sconce.position = Vector3(-11.17, 2.15, z)
		parent.add_child(sconce)
		sconce.owner = scene_root
		var plate: MeshInstance3D = MeshInstance3D.new()
		plate.name = "Bronze_Backplate"
		var plate_mesh: CylinderMesh = CylinderMesh.new()
		plate_mesh.top_radius = 0.12
		plate_mesh.bottom_radius = 0.12
		plate_mesh.height = 0.035
		plate.mesh = plate_mesh
		plate.material_override = brass
		plate.rotation = Vector3(0.0, 0.0, PI * 0.5)
		sconce.add_child(plate)
		plate.owner = scene_root
		var diffuser: MeshInstance3D = MeshInstance3D.new()
		diffuser.name = "Frosted_Diffuser"
		var capsule: CapsuleMesh = CapsuleMesh.new()
		capsule.radius = 0.09
		capsule.height = 0.52
		diffuser.mesh = capsule
		diffuser.material_override = shade
		diffuser.position = Vector3(0.10, 0.0, 0.0)
		sconce.add_child(diffuser)
		diffuser.owner = scene_root
		var light: OmniLight3D = OmniLight3D.new()
		light.name = "Warm_Wall_Wash"
		light.position = Vector3(0.20, -0.03, 0.0)
		light.light_color = Color(1.0, 0.70, 0.48)
		light.light_energy = 1.15
		light.omni_range = 5.8
		light.shadow_enabled = false
		sconce.add_child(light)
		light.owner = scene_root

func _add_omni_light(
	parent: Node3D,
	node_name: String,
	light_position: Vector3,
	color: Color,
	energy: float,
	range_value: float,
	scene_root: Node
) -> void:
	LightingRig.add_omni(parent, node_name, light_position, color, energy, range_value, scene_root, light_specular, enable_shadows)
