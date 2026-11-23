extends Node3D
class_name ChickenCrossChicken

## Procedural, reusable Chicken Cross contestant. All animation is presentation-only;
## authoritative tile/status updates arrive from ChickenCrossTable on every peer.

const IDLE_BOB_HEIGHT: float = 0.018
const TILE_STEP: float = 0.25

var peer_id: int = 0
var display_name: String = "CHICKEN"
var color_index: int = 0
var _clock: float = 0.0
var _head_pivot: Node3D
var _left_foot: Node3D
var _right_foot: Node3D
var _body_pivot: Node3D
var _base_y: float = 0.0
var _finished_animation: bool = false
var _body_material: StandardMaterial3D
var _wing_material: StandardMaterial3D
var _eye_meshes: Array[MeshInstance3D] = []
var _eye_base_scales: Array[Vector3] = []

func _ready() -> void:
	_build_character()
	_base_y = position.y

func configure(owner_peer_id: int, owner_name: String, owner_color_index: int) -> void:
	peer_id = owner_peer_id
	display_name = owner_name
	color_index = owner_color_index
	if is_inside_tree():
		_rebuild_character_material()

func _process(delta: float) -> void:
	if _finished_animation:
		return
	_clock += delta
	position.y = _base_y + sin(_clock * 3.2) * IDLE_BOB_HEIGHT
	if is_instance_valid(_head_pivot):
		_head_pivot.rotation.y = sin(_clock * 1.35 + float(peer_id)) * 0.16
		_head_pivot.rotation.z = sin(_clock * 2.1) * 0.035
	if is_instance_valid(_body_pivot):
		_body_pivot.rotation.z = sin(_clock * 3.2) * 0.025
	if is_instance_valid(_left_foot):
		_left_foot.rotation.z = sin(_clock * 4.0) * 0.12
	if is_instance_valid(_right_foot):
		_right_foot.rotation.z = -sin(_clock * 4.0) * 0.12
	var blink_phase: float = fposmod(_clock + float(peer_id) * 0.37, 3.8)
	var blink_scale: float = 0.12 if blink_phase < 0.13 else 1.0
	for eye_index: int in range(_eye_meshes.size()):
		var eye: MeshInstance3D = _eye_meshes[eye_index]
		if is_instance_valid(eye):
			var eye_scale: Vector3 = _eye_base_scales[eye_index]
			eye.scale = Vector3(eye_scale.x, eye_scale.y * blink_scale, eye_scale.z)

func set_tile(tile_number: int, animate: bool = true) -> void:
	var target_x: float = -1.53 + float(clampi(tile_number, 0, 12)) * TILE_STEP
	if not animate or not is_inside_tree():
		position.x = target_x
		return
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:x", target_x, 0.28)

func play_cash_out() -> void:
	if _finished_animation:
		return
	_finished_animation = true
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "rotation:z", -0.18, 0.18)
	tween.tween_property(self, "scale", Vector3.ONE * 1.12, 0.18)
	tween.chain().tween_property(self, "scale", Vector3.ONE, 0.22)
	tween.parallel().tween_property(self, "rotation:z", 0.0, 0.22)
	tween.tween_callback(func() -> void: _finished_animation = false)

func play_failure() -> void:
	if _finished_animation:
		return
	_finished_animation = true
	set_process(false)
	_spawn_tiny_car()
	_spawn_feather_burst()
	var impact: Tween = create_tween()
	impact.tween_interval(0.62)
	impact.tween_property(self, "rotation:z", 1.45, 0.16)
	impact.parallel().tween_property(self, "position:y", position.y + 0.22, 0.16)
	impact.tween_property(self, "rotation:z", 4.8, 0.42)
	impact.parallel().tween_property(self, "scale", Vector3(1.25, 0.32, 1.25), 0.2)
	impact.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.18)
	impact.tween_callback(queue_free)

func _build_character() -> void:
	_body_pivot = Node3D.new()
	_body_pivot.name = "BodyPivot"
	add_child(_body_pivot)
	_body_material = _make_material(PlayerIdentity.color_for_index(color_index), 0.0, 0.48)
	var belly_material: StandardMaterial3D = _make_material(Color("#f5e7c9"), 0.0, 0.72)
	_wing_material = _make_material(PlayerIdentity.color_for_index(color_index).darkened(0.16), 0.0, 0.55)
	var comb_material: StandardMaterial3D = _make_material(Color("#d93435"), 0.0, 0.42)
	var beak_material: StandardMaterial3D = _make_material(Color("#f4a62a"), 0.0, 0.48)
	var foot_material: StandardMaterial3D = _make_material(Color("#e88b24"), 0.0, 0.55)
	var eye_material: StandardMaterial3D = _make_material(Color("#17191d"), 0.0, 0.22)
	var white_material: StandardMaterial3D = _make_material(Color.WHITE, 0.0, 0.2)

	_add_sphere(_body_pivot, "PlumpBody", Vector3(0.34, 0.29, 0.26), Vector3.ZERO, _body_material)
	_add_sphere(_body_pivot, "CreamBib", Vector3(0.205, 0.205, 0.205), Vector3(0.15, -0.055, 0.0), belly_material)
	for side: float in [-1.0, 1.0]:
		_add_sphere(_body_pivot, "Wing_%s" % str(side), Vector3(0.12, 0.17, 0.065), Vector3(-0.015, 0.015, side * 0.235), _wing_material)
		for feather: int in range(3):
			_add_sphere(_body_pivot, "TailFeather_%s_%d" % [str(side), feather], Vector3(0.105, 0.07, 0.055), Vector3(-0.25 - float(feather) * 0.025, 0.15 + float(feather) * 0.045, side * (0.07 + float(feather) * 0.045)), _wing_material)

	_head_pivot = Node3D.new()
	_head_pivot.name = "HeadPivot"
	_head_pivot.position = Vector3(0.19, 0.22, 0.0)
	_body_pivot.add_child(_head_pivot)
	_add_sphere(_head_pivot, "Head", Vector3(0.19, 0.205, 0.18), Vector3(0.035, 0.055, 0.0), _body_material)
	_add_sphere(_head_pivot, "CombBase", Vector3(0.085, 0.07, 0.09), Vector3(0.005, 0.22, 0.0), comb_material)
	for comb_index: int in range(3):
		_add_sphere(_head_pivot, "CombCrown_%d" % comb_index, Vector3(0.052, 0.085, 0.045), Vector3(0.025 + float(comb_index) * 0.055, 0.275, (float(comb_index) - 1.0) * 0.055), comb_material)
	_add_sphere(_head_pivot, "Wattle", Vector3(0.045, 0.075, 0.045), Vector3(0.17, -0.09, 0.0), comb_material)
	_add_sphere(_head_pivot, "Beak", Vector3(0.105, 0.065, 0.075), Vector3(0.205, 0.015, 0.0), beak_material)
	for side: float in [-1.0, 1.0]:
		var eye_white: MeshInstance3D = _add_sphere(_head_pivot, "EyeWhite_%s" % str(side), Vector3(0.035, 0.045, 0.03), Vector3(0.105, 0.105, side * 0.145), white_material)
		var eye_pupil: MeshInstance3D = _add_sphere(_head_pivot, "Eye_%s" % str(side), Vector3(0.018, 0.027, 0.018), Vector3(0.128, 0.105, side * 0.165), eye_material)
		_eye_meshes.append(eye_white)
		_eye_base_scales.append(eye_white.scale)
		_eye_meshes.append(eye_pupil)
		_eye_base_scales.append(eye_pupil.scale)

	_left_foot = _build_foot("LeftFoot", -0.105, foot_material)
	_right_foot = _build_foot("RightFoot", 0.105, foot_material)

func _build_foot(node_name: String, z_offset: float, material: Material) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.name = node_name
	pivot.position = Vector3(0.045, -0.245, z_offset)
	_body_pivot.add_child(pivot)
	_add_box(pivot, "Shank", Vector3(0.045, 0.13, 0.045), Vector3.ZERO, material)
	_add_box(pivot, "Toe", Vector3(0.15, 0.035, 0.075), Vector3(0.045, -0.065, 0.0), material)
	return pivot

func _spawn_tiny_car() -> void:
	var car: Node3D = Node3D.new()
	car.name = "ComedicImpactCar"
	car.position = Vector3(0.0, 0.0, -0.86)
	add_child(car)
	var paint: Material = _make_material(Color("#d63b2f"), 0.18, 0.32)
	var glass: Material = _make_material(Color("#a9d8e8"), 0.0, 0.18)
	_add_box(car, "CarBody", Vector3(0.43, 0.13, 0.28), Vector3.ZERO, paint)
	_add_box(car, "Cabin", Vector3(0.22, 0.13, 0.23), Vector3(-0.035, 0.105, 0.0), glass)
	for x_side: float in [-0.13, 0.13]:
		for z_side: float in [-0.16, 0.16]:
			_add_sphere(car, "Wheel_%s_%s" % [str(x_side), str(z_side)], Vector3(0.055, 0.055, 0.055), Vector3(x_side, -0.075, z_side), eye_dark_material())
	var car_tween: Tween = create_tween()
	car_tween.tween_property(car, "position:z", 0.92, 0.62)
	car_tween.tween_callback(car.queue_free)

func _spawn_feather_burst() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	for index: int in range(10):
		var feather: MeshInstance3D = MeshInstance3D.new()
		feather.name = "FlyingFeather_%02d" % index
		var mesh: SphereMesh = SphereMesh.new()
		mesh.radius = 0.045
		mesh.height = 0.11
		feather.mesh = mesh
		feather.material_override = _body_material
		feather.position = Vector3(0.0, 0.12, 0.0)
		add_child(feather)
		var destination: Vector3 = feather.position + Vector3(rng.randf_range(-0.48, 0.48), rng.randf_range(0.12, 0.7), rng.randf_range(-0.48, 0.48))
		var tween: Tween = create_tween()
		tween.tween_property(feather, "position", destination, rng.randf_range(0.45, 0.85))
		tween.parallel().tween_property(feather, "rotation", Vector3(rng.randf_range(-3.0, 3.0), 0.0, rng.randf_range(-3.0, 3.0)), 0.75)
		tween.tween_callback(feather.queue_free)

func _rebuild_character_material() -> void:
	var assigned_color: Color = PlayerIdentity.color_for_index(color_index)
	_body_material.albedo_color = assigned_color
	_wing_material.albedo_color = assigned_color.darkened(0.16)

func eye_dark_material() -> Material:
	return _make_material(Color("#25282d"), 0.0, 0.3)

func _add_sphere(parent: Node3D, node_name: String, dimensions: Vector3, local_position: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 16
	mesh.rings = 10
	mesh_instance.mesh = mesh
	mesh_instance.scale = dimensions * 2.0
	mesh_instance.position = local_position
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance

func _add_box(parent: Node3D, node_name: String, dimensions: Vector3, local_position: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = dimensions
	mesh_instance.mesh = mesh
	mesh_instance.position = local_position
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance

func _make_material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material
