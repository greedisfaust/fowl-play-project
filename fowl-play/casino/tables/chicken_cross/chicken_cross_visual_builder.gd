@tool
class_name ChickenCrossVisualBuilder
extends Node3D

## Procedural luxury finish for the editor-authored Chicken Cross table.
## Attach to the existing Visuals node. Generated details are kept in one child.

const GENERATED_NAME: StringName = &"_GeneratedChickenCrossDetails"
const TILE_COUNT: int = 12
const TILE_FIRST_X: float = -1.38
const TILE_STEP_X: float = 0.25
const SURFACE_Y: float = 1.09

@export var rebuild_visuals: bool = false:
	set(value):
		rebuild_visuals = false
		if value and is_inside_tree():
			_apply_existing_finishes()
			_rebuild_details()

@export var dark_stone_color: Color = Color(0.035, 0.043, 0.052, 1.0)
@export var bronze_color: Color = Color(0.36, 0.22, 0.105, 1.0)
@export var felt_color: Color = Color(0.012, 0.19, 0.125, 1.0)
@export var warm_light_color: Color = Color(1.0, 0.48, 0.19, 1.0)
@export var add_risk_lights: bool = true
@export var add_leg_details: bool = true

func _ready() -> void:
	_apply_existing_finishes()
	_rebuild_details()

func _apply_existing_finishes() -> void:
	var stone: StandardMaterial3D = _make_material(dark_stone_color, 0.42, 0.28)
	var leg_finish: StandardMaterial3D = _make_material(Color(0.075, 0.085, 0.095, 1.0), 0.62, 0.3)
	var felt: StandardMaterial3D = _make_material(felt_color, 0.0, 0.88)
	var tile: StandardMaterial3D = _make_material(Color(0.055, 0.075, 0.082, 1.0), 0.24, 0.56)
	var marking: StandardMaterial3D = _make_material(Color(0.78, 0.72, 0.59, 1.0), 0.12, 0.62)
	var bronze: StandardMaterial3D = _make_material(bronze_color, 0.78, 0.26)
	var number_plate: StandardMaterial3D = _make_material(Color(0.045, 0.052, 0.06, 1.0), 0.5, 0.3)
	var number_text: StandardMaterial3D = _make_material(Color(0.96, 0.78, 0.43, 1.0), 0.25, 0.34)

	_set_override("TableTop", stone)
	_set_override("PlayingSurface", felt)
	for leg_name: String in ["Leg_Front_Left", "Leg_Front_Right", "Leg_Back_Left", "Leg_Back_Right"]:
		_set_override(leg_name, leg_finish)

	var tile_lane: Node = get_node_or_null("TileLane")
	if tile_lane == null:
		return
	for tile_index: int in range(1, TILE_COUNT + 1):
		var tile_name: String = "Tile_%02d" % tile_index
		var tile_node: Node = tile_lane.get_node_or_null(tile_name)
		if tile_node == null:
			continue
		if tile_node is MeshInstance3D:
			(tile_node as MeshInstance3D).material_override = tile
		_set_child_override(tile_node, "RoadMarking", marking)
		_set_child_override(tile_node, "RoadEdge_Left", bronze)
		_set_child_override(tile_node, "RoadEdge_Right", bronze)
		_set_child_override(tile_node, "TileNumberPlate", number_plate)
		var number_mesh: MeshInstance3D = tile_node.get_node_or_null("TileNumber%02d/CSGPolygon3D/TileNumber" % tile_index) as MeshInstance3D
		if is_instance_valid(number_mesh):
			number_mesh.material_override = number_text

func _set_override(path: String, material: Material) -> void:
	var mesh_instance: MeshInstance3D = get_node_or_null(path) as MeshInstance3D
	if is_instance_valid(mesh_instance):
		mesh_instance.material_override = material

func _set_child_override(parent_node: Node, child_name: String, material: Material) -> void:
	var mesh_instance: MeshInstance3D = parent_node.get_node_or_null(child_name) as MeshInstance3D
	if is_instance_valid(mesh_instance):
		mesh_instance.material_override = material

func _rebuild_details() -> void:
	var previous: Node = get_node_or_null(NodePath(GENERATED_NAME))
	if previous != null:
		previous.free()
	var generated: Node3D = Node3D.new()
	generated.name = GENERATED_NAME
	add_child(generated)
	_set_generated_owner(generated)

	var bronze: StandardMaterial3D = _make_material(bronze_color, 0.82, 0.24)
	var dark_metal: StandardMaterial3D = _make_material(Color(0.025, 0.032, 0.04, 1.0), 0.72, 0.3)
	var warm_emission: StandardMaterial3D = _make_material(warm_light_color, 0.28, 0.3, warm_light_color, 1.35)

	_build_table_perimeter(generated, bronze, dark_metal)
	_build_lane_details(generated, bronze, warm_emission)
	if add_leg_details:
		_build_leg_details(generated, bronze, dark_metal)

func _build_table_perimeter(parent: Node3D, bronze: Material, dark_metal: Material) -> void:
	# Fine bronze reveal around the dark tabletop, kept outside the green play field.
	_add_box(parent, "Rim_Front", Vector3(3.28, 0.018, 0.026), Vector3(0.0, 1.045, 1.045), bronze)
	_add_box(parent, "Rim_Back", Vector3(3.28, 0.018, 0.026), Vector3(0.0, 1.045, -1.045), bronze)
	_add_box(parent, "Rim_Left", Vector3(0.026, 0.018, 2.08), Vector3(-1.645, 1.045, 0.0), bronze)
	_add_box(parent, "Rim_Right", Vector3(0.026, 0.018, 2.08), Vector3(1.645, 1.045, 0.0), bronze)

	# Floating shadow-line apron under the top gives the table a heavier, machined profile.
	_add_box(parent, "Apron_Front", Vector3(3.16, 0.16, 0.075), Vector3(0.0, 0.835, 1.005), dark_metal)
	_add_box(parent, "Apron_Back", Vector3(3.16, 0.16, 0.075), Vector3(0.0, 0.835, -1.005), dark_metal)
	_add_box(parent, "Apron_Left", Vector3(0.075, 0.16, 1.94), Vector3(-1.56, 0.835, 0.0), dark_metal)
	_add_box(parent, "Apron_Right", Vector3(0.075, 0.16, 1.94), Vector3(1.56, 0.835, 0.0), dark_metal)

	_add_box(parent, "Apron_Front_Reveal", Vector3(3.12, 0.012, 0.012), Vector3(0.0, 0.925, 1.046), bronze)
	_add_box(parent, "Apron_Back_Reveal", Vector3(3.12, 0.012, 0.012), Vector3(0.0, 0.925, -1.046), bronze)
	_add_box(parent, "Apron_Left_Reveal", Vector3(0.012, 0.012, 1.9), Vector3(-1.601, 0.925, 0.0), bronze)
	_add_box(parent, "Apron_Right_Reveal", Vector3(0.012, 0.012, 1.9), Vector3(1.601, 0.925, 0.0), bronze)

func _build_lane_details(parent: Node3D, bronze: Material, warm_emission: Material) -> void:
	# Raised edge rails frame the twelve-step road without covering the existing markings.
	_add_box(parent, "LaneRail_Left", Vector3(3.04, 0.012, 0.018), Vector3(0.0, SURFACE_Y, -0.462), bronze)
	_add_box(parent, "LaneRail_Right", Vector3(3.04, 0.012, 0.018), Vector3(0.0, SURFACE_Y, 0.462), bronze)

	# Tiny separators make each step read as a deliberate inlaid module.
	for separator_index: int in range(TILE_COUNT - 1):
		var x_position: float = TILE_FIRST_X + (float(separator_index) + 0.5) * TILE_STEP_X
		_add_box(parent, "TileDivider_%02d" % (separator_index + 1), Vector3(0.009, 0.006, 0.82), Vector3(x_position, 1.091, 0.0), bronze)

	if add_risk_lights:
		for tile_index: int in range(TILE_COUNT):
			var x_position: float = TILE_FIRST_X + float(tile_index) * TILE_STEP_X
			var progress: float = float(tile_index) / float(TILE_COUNT - 1)
			var risk_color: Color = Color(0.16, 0.72, 0.43, 1.0).lerp(Color(1.0, 0.19, 0.12, 1.0), progress)
			var socket_material: StandardMaterial3D = _make_material(Color(0.018, 0.024, 0.03, 1.0), 0.65, 0.28)
			var lamp_material: StandardMaterial3D = _make_material(risk_color, 0.18, 0.28, risk_color, 1.25)
			_add_box(parent, "RiskSocket_%02d" % (tile_index + 1), Vector3(0.07, 0.012, 0.07), Vector3(x_position, 1.086, -0.535), socket_material)
			_add_sphere(parent, "RiskLamp_%02d" % (tile_index + 1), 0.018, 0.014, Vector3(x_position, 1.101, -0.535), lamp_material)

	# A restrained warm start/finish glow at the two ends of the road.
	_add_box(parent, "StartGlow", Vector3(0.035, 0.008, 0.58), Vector3(-1.535, 1.09, 0.0), warm_emission)
	_add_box(parent, "FinishGlow", Vector3(0.035, 0.008, 0.58), Vector3(1.535, 1.09, 0.0), warm_emission)

func _build_leg_details(parent: Node3D, bronze: Material, dark_metal: Material) -> void:
	var leg_positions: Array[Vector2] = [
		Vector2(-1.48, -0.88),
		Vector2(1.48, -0.88),
		Vector2(-1.48, 0.88),
		Vector2(1.48, 0.88),
	]
	for leg_index: int in range(leg_positions.size()):
		var leg_position: Vector2 = leg_positions[leg_index]
		_add_leg_collar(parent, "Leg_%02d_Upper" % leg_index, leg_position, 0.76, bronze, dark_metal)
		_add_leg_collar(parent, "Leg_%02d_Lower" % leg_index, leg_position, 0.13, bronze, dark_metal)

func _add_leg_collar(parent: Node3D, prefix: String, leg_position: Vector2, center_y: float, bronze: Material, dark_metal: Material) -> void:
	_add_box(parent, prefix + "_Core", Vector3(0.255, 0.052, 0.255), Vector3(leg_position.x, center_y, leg_position.y), dark_metal)
	_add_box(parent, prefix + "_Front", Vector3(0.27, 0.008, 0.012), Vector3(leg_position.x, center_y + 0.027, leg_position.y + 0.132), bronze)
	_add_box(parent, prefix + "_Back", Vector3(0.27, 0.008, 0.012), Vector3(leg_position.x, center_y + 0.027, leg_position.y - 0.132), bronze)
	_add_box(parent, prefix + "_Left", Vector3(0.012, 0.008, 0.255), Vector3(leg_position.x - 0.132, center_y + 0.027, leg_position.y), bronze)
	_add_box(parent, prefix + "_Right", Vector3(0.012, 0.008, 0.255), Vector3(leg_position.x + 0.132, center_y + 0.027, leg_position.y), bronze)

func _add_box(parent: Node3D, node_name: String, dimensions: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = node_name
	var box: BoxMesh = BoxMesh.new()
	box.size = dimensions
	mesh_instance.mesh = box
	mesh_instance.material_override = material
	mesh_instance.position = position
	parent.add_child(mesh_instance)
	_set_generated_owner(mesh_instance)
	return mesh_instance

func _add_sphere(parent: Node3D, node_name: String, radius: float, height: float, position: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = node_name
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = radius
	sphere.height = height
	sphere.radial_segments = 12
	sphere.rings = 6
	mesh_instance.mesh = sphere
	mesh_instance.material_override = material
	mesh_instance.position = position
	parent.add_child(mesh_instance)
	_set_generated_owner(mesh_instance)
	return mesh_instance

func _make_material(color: Color, metallic: float, roughness: float, emission_color: Color = Color.BLACK, emission_energy: float = 0.0) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = emission_color
		material.emission_energy_multiplier = emission_energy
	return material

func _set_generated_owner(node: Node) -> void:
	if not Engine.is_editor_hint():
		return
	var edited_root: Node = get_tree().edited_scene_root
	if edited_root == null:
		return
	node.owner = edited_root
