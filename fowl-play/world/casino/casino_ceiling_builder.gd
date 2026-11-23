@tool
extends Node3D
class_name CasinoCeilingBuilder

## Generates the casino ceiling and its architectural lighting details.
## Coordinates follow the Casino root footprint; attach to Architecture/Ceiling.

@export_group("Ceiling")
@export_range(3.5, 6.0, 0.05) var ceiling_height: float = 4.2
@export_range(0.05, 0.4, 0.01) var ceiling_thickness: float = 0.18
@export var ceiling_color: Color = Color(0.035, 0.041, 0.049, 1.0)

@export_group("Perimeter Cove")
@export var generate_perimeter_cove: bool = true
@export_range(0.2, 1.2, 0.05) var cove_inset: float = 0.62
@export_range(0.015, 0.08, 0.005) var cove_light_width: float = 0.035

@export_group("Gaming Floor Details")
@export var generate_gaming_light_rails: bool = true
@export_range(0.02, 0.10, 0.005) var gaming_rail_width: float = 0.045

@export_group("Bar Feature")
@export var generate_bar_feature: bool = true
@export var bar_frame_min: Vector2 = Vector2(2.6, -22.0)
@export var bar_frame_max: Vector2 = Vector2(9.5, -8.5)

@export_group("Downlights")
@export var generate_downlights: bool = true
@export var generate_light_nodes: bool = true
@export_range(0.1, 1.5, 0.05) var downlight_energy: float = 0.65
@export_range(4.0, 12.0, 0.5) var downlight_range: float = 8.0

@export_group("Materials")
@export var bronze_color: Color = Color(0.36, 0.22, 0.105, 1.0)
@export var warm_light_color: Color = Color(1.0, 0.48, 0.19, 1.0)

@export_group("Generation")
@export var rebuild_geometry: bool = false:
	set(value):
		if value:
			call_deferred("_rebuild_geometry")

const GENERATED_ROOT_NAME: String = "_GeneratedCeiling"

func _get_ceiling_footprint() -> PackedVector2Array:
	# PackedVector2Array construction is not permitted in a GDScript const.
	# Build this small, fixed footprint when geometry is generated instead.
	return PackedVector2Array([
		Vector2(-24.0, -18.665),
		Vector2(-14.0, -28.665),
		Vector2(11.0, -28.665),
		Vector2(11.0, -1.665),
		Vector2(-24.0, -1.665)
	])

func _ready() -> void:
	# Generated children are serialized into the scene. Preserve editor-authored
	# tweaks on reopen; the inspector rebuild toggle remains the explicit reset.
	if Engine.is_editor_hint() and get_node_or_null(GENERATED_ROOT_NAME) == null:
		_rebuild_geometry()

func _rebuild_geometry() -> void:
	if not Engine.is_editor_hint():
		return
	if ceiling_height <= ceiling_thickness + 0.5:
		push_warning("CasinoCeilingBuilder has invalid ceiling dimensions.")
		return

	var old_root: Node = get_node_or_null(GENERATED_ROOT_NAME)
	if old_root != null:
		old_root.free()

	var scene_root: Node = get_tree().edited_scene_root
	var generated_root: Node3D = Node3D.new()
	generated_root.name = GENERATED_ROOT_NAME
	add_child(generated_root)
	generated_root.owner = scene_root

	var ceiling_material: StandardMaterial3D = _make_material(ceiling_color, 0.08, 0.48)
	var bronze_material: StandardMaterial3D = _make_material(bronze_color, 0.72, 0.27)
	var dark_detail_material: StandardMaterial3D = _make_material(Color(0.018, 0.022, 0.028, 1.0), 0.12, 0.42)
	var light_material: StandardMaterial3D = _make_emissive_material(warm_light_color, 1.6)

	_build_ceiling_slab(generated_root, ceiling_material, scene_root)

	if generate_perimeter_cove:
		_build_perimeter_cove(generated_root, bronze_material, light_material, scene_root)

	if generate_gaming_light_rails:
		_build_gaming_rails(generated_root, bronze_material, light_material, scene_root)

	if generate_bar_feature:
		_build_bar_feature(generated_root, bronze_material, light_material, scene_root)

	if generate_downlights:
		_build_downlights(generated_root, bronze_material, light_material, dark_detail_material, scene_root)

	_build_grand_circular_fixture(generated_root, scene_root)

func _build_grand_circular_fixture(parent: Node3D, scene_root: Node) -> void:
	var center: Vector3 = Vector3(-8.0, ceiling_height - 0.20, -17.0)
	var bronze: StandardMaterial3D = _make_material(Color(0.48, 0.30, 0.13, 1.0), 0.82, 0.20)
	var dark_bronze: StandardMaterial3D = _make_material(Color(0.075, 0.045, 0.022, 1.0), 0.78, 0.25)
	var luminous: StandardMaterial3D = _make_emissive_material(Color(1.0, 0.72, 0.43, 1.0), 3.0)
	var soft_luminous: StandardMaterial3D = _make_emissive_material(Color(1.0, 0.88, 0.68, 1.0), 2.1)

	_add_torus(parent, "GrandCasinoRing_OuterBronze", 3.42, 3.30, center, bronze, scene_root)
	_add_torus(parent, "GrandCasinoRing_OuterLight", 3.27, 3.22, center + Vector3.DOWN * 0.035, luminous, scene_root)
	_add_torus(parent, "GrandCasinoRing_InnerBronze", 2.62, 2.53, center + Vector3.DOWN * 0.025, dark_bronze, scene_root)
	_add_torus(parent, "GrandCasinoRing_InnerLight", 2.51, 2.46, center + Vector3.DOWN * 0.055, soft_luminous, scene_root)

	# Twelve repeating illuminated medallions make the ring read as a designed ceiling centerpiece.
	for index: int in range(12):
		var angle: float = TAU * float(index) / 12.0
		var radial: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
		var medallion_position: Vector3 = center + radial * 2.95 + Vector3.DOWN * 0.105
		_add_cylinder(parent, "GrandCasinoRing_MedallionBronze_%02d" % index, 0.205, 0.055, medallion_position, bronze, scene_root)
		_add_cylinder(parent, "GrandCasinoRing_MedallionLens_%02d" % index, 0.145, 0.025, medallion_position + Vector3.DOWN * 0.04, soft_luminous, scene_root)
		if index % 2 == 0:
			var downlight: SpotLight3D = SpotLight3D.new()
			downlight.name = "GrandCasinoRing_Downlight_%02d" % index
			downlight.position = center + radial * 2.95 + Vector3.DOWN * 0.24
			downlight.rotation.x = -PI * 0.5
			downlight.light_color = Color(1.0, 0.78, 0.56, 1.0)
			downlight.light_energy = 1.05
			downlight.spot_range = 8.5
			downlight.spot_angle = 48.0
			downlight.shadow_enabled = false
			parent.add_child(downlight)
			downlight.owner = scene_root

func _add_torus(parent: Node3D, node_name: String, outer_radius: float, inner_radius: float, center: Vector3, material: Material, scene_root: Node) -> void:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = node_name
	var torus: TorusMesh = TorusMesh.new()
	torus.outer_radius = outer_radius
	torus.inner_radius = inner_radius
	torus.rings = 64
	torus.ring_segments = 12
	mesh_instance.mesh = torus
	mesh_instance.material_override = material
	mesh_instance.position = center
	mesh_instance.rotation.x = PI * 0.5
	parent.add_child(mesh_instance)
	mesh_instance.owner = scene_root

func _build_ceiling_slab(parent: Node3D, material: Material, scene_root: Node) -> void:
	# Match the floor's CSGPolygon3D orientation: local polygon Y maps to world Z,
	# and the extrusion points down from the 4.2m ceiling line.
	var ceiling_basis: Basis = Basis(
		Vector3.RIGHT,
		Vector3(0.0, 0.0, 1.0),
		Vector3(0.0, -1.0, 0.0)
	)
	var slab: CSGPolygon3D = CSGPolygon3D.new()
	slab.name = "Ceiling_SculptedFootprint"
	slab.polygon = _get_ceiling_footprint()
	slab.depth = ceiling_thickness
	slab.use_collision = true
	slab.material = material
	slab.transform = Transform3D(ceiling_basis, Vector3(0.0, ceiling_height, 0.0))
	parent.add_child(slab)
	slab.owner = scene_root

func _build_perimeter_cove(
	parent: Node3D,
	bronze_material: Material,
	light_material: Material,
	scene_root: Node
) -> void:
	var footprint: PackedVector2Array = _get_ceiling_footprint()
	var visual_center: Vector2 = Vector2(-8.0, -17.0)
	for index: int in range(footprint.size()):
		var start_2d: Vector2 = footprint[index]
		var end_2d: Vector2 = footprint[(index + 1) % footprint.size()]
		var midpoint: Vector2 = (start_2d + end_2d) * 0.5
		var inward_2d: Vector2 = (visual_center - midpoint).normalized()
		var bronze_start: Vector2 = start_2d + inward_2d * cove_inset
		var bronze_end: Vector2 = end_2d + inward_2d * cove_inset
		var light_start: Vector2 = start_2d + inward_2d * (cove_inset + 0.12)
		var light_end: Vector2 = end_2d + inward_2d * (cove_inset + 0.12)
		_add_line(
			parent, "Perimeter_Bronze_Cove_%02d" % index,
			bronze_start, bronze_end, 0.035, 0.055,
			ceiling_height - ceiling_thickness - 0.035, bronze_material, scene_root
		)
		_add_line(
			parent, "Perimeter_Warm_Cove_%02d" % index,
			light_start, light_end, 0.018, cove_light_width,
			ceiling_height - ceiling_thickness - 0.05, light_material, scene_root
		)

func _build_gaming_rails(
	parent: Node3D,
	bronze_material: Material,
	light_material: Material,
	scene_root: Node
) -> void:
	# Three restrained longitudinal light channels over the gaming side.
	var rail_x_positions: Array[float] = [-15.0, -7.5, 0.0]
	var rail_segments: Array[Vector2] = [
		Vector2(-24.0, -14.0),
		Vector2(-12.5, -5.0)
	]
	for rail_index: int in range(rail_x_positions.size()):
		var rail_x: float = rail_x_positions[rail_index]
		for segment_index: int in range(rail_segments.size()):
			var segment: Vector2 = rail_segments[segment_index]
			var bronze_start: Vector2 = Vector2(rail_x, segment.x)
			var bronze_end: Vector2 = Vector2(rail_x, segment.y)
			var light_start: Vector2 = Vector2(rail_x + 0.075, segment.x + 0.12)
			var light_end: Vector2 = Vector2(rail_x + 0.075, segment.y - 0.12)
			_add_line(
				parent, "Gaming_Rail_%d_%d" % [rail_index, segment_index],
				bronze_start, bronze_end, 0.045, gaming_rail_width,
				ceiling_height - ceiling_thickness - 0.035, bronze_material, scene_root
			)
			_add_line(
				parent, "Gaming_Rail_Light_%d_%d" % [rail_index, segment_index],
				light_start, light_end, 0.018, 0.022,
				ceiling_height - ceiling_thickness - 0.05, light_material, scene_root
			)

func _build_bar_feature(
	parent: Node3D,
	bronze_material: Material,
	light_material: Material,
	scene_root: Node
) -> void:
	var min_x: float = minf(bar_frame_min.x, bar_frame_max.x)
	var max_x: float = maxf(bar_frame_min.x, bar_frame_max.x)
	var min_z: float = minf(bar_frame_min.y, bar_frame_max.y)
	var max_z: float = maxf(bar_frame_min.y, bar_frame_max.y)
	var outer_points: Array[Vector2] = [
		Vector2(min_x, min_z), Vector2(max_x, min_z),
		Vector2(max_x, max_z), Vector2(min_x, max_z)
	]
	for index: int in range(4):
		var start_2d: Vector2 = outer_points[index]
		var end_2d: Vector2 = outer_points[(index + 1) % 4]
		_add_line(
			parent, "Bar_Sculpted_Frame_%d" % index,
			start_2d, end_2d, 0.065, 0.075,
			ceiling_height - ceiling_thickness - 0.04, bronze_material, scene_root
		)
		var inset_start: Vector2 = start_2d.lerp((start_2d + end_2d) * 0.5, 0.025)
		var inset_end: Vector2 = end_2d.lerp((start_2d + end_2d) * 0.5, 0.025)
		_add_line(
			parent, "Bar_Warm_Frame_Light_%d" % index,
			inset_start, inset_end, 0.018, 0.028,
			ceiling_height - ceiling_thickness - 0.085, light_material, scene_root
		)

	# Two crosspieces give the bar canopy a deliberate, designed rhythm.
	for cross_index: int in range(2):
		var cross_z: float = min_z + (max_z - min_z) * float(cross_index + 1) / 3.0
		_add_line(
			parent, "Bar_Crossbeam_%d" % cross_index,
			Vector2(min_x + 0.25, cross_z), Vector2(max_x - 0.25, cross_z),
			0.045, 0.055, ceiling_height - ceiling_thickness - 0.04, bronze_material, scene_root
		)

func _build_downlights(
	parent: Node3D,
	bronze_material: Material,
	light_material: Material,
	dark_material: Material,
	scene_root: Node
) -> void:
	var x_positions: Array[float] = [-16.0, -8.0, 0.0, 6.0]
	var z_positions: Array[float] = [-22.0, -12.0]
	for row_index: int in range(z_positions.size()):
		for column_index: int in range(x_positions.size()):
			var position: Vector3 = Vector3(
				x_positions[column_index],
				ceiling_height - 0.19,
				z_positions[row_index]
			)
			var fixture_name: String = "Downlight_%d_%d" % [row_index, column_index]
			_add_cylinder(
				parent, fixture_name + "_Bronze_Rim",
				0.13, 0.035, position,
				bronze_material, scene_root
			)
			_add_cylinder(
				parent, fixture_name + "_Lens",
				0.095, 0.012, position + Vector3.DOWN * 0.024,
				light_material, scene_root
			)
			if generate_light_nodes:
				var spotlight: SpotLight3D = SpotLight3D.new()
				spotlight.name = fixture_name + "_Light"
				spotlight.light_color = Color(1.0, 0.78, 0.58, 1.0)
				spotlight.light_energy = downlight_energy
				spotlight.spot_range = downlight_range
				spotlight.spot_angle = 58.0
				spotlight.shadow_enabled = false
				spotlight.position = position + Vector3.DOWN * 0.16
				spotlight.rotation.x = -PI * 0.5
				parent.add_child(spotlight)
				spotlight.owner = scene_root

func _add_line(
	parent: Node3D,
	node_name: String,
	start_2d: Vector2,
	end_2d: Vector2,
	height: float,
	width: float,
	center_y: float,
	material: Material,
	scene_root: Node
) -> void:
	var edge_2d: Vector2 = end_2d - start_2d
	var edge_length: float = edge_2d.length()
	if edge_length <= 0.05:
		return
	var tangent_2d: Vector2 = edge_2d / edge_length
	var tangent: Vector3 = Vector3(tangent_2d.x, 0.0, tangent_2d.y)
	var inward: Vector3 = tangent.cross(Vector3.UP).normalized()
	var line_basis: Basis = Basis(tangent, Vector3.UP, inward)
	var midpoint_2d: Vector2 = (start_2d + end_2d) * 0.5
	var center: Vector3 = Vector3(midpoint_2d.x, center_y, midpoint_2d.y)
	_add_box(
		parent, node_name,
		Vector3(edge_length, height, width),
		Transform3D(line_basis, center),
		material, scene_root
	)

func _add_box(
	parent: Node3D,
	node_name: String,
	box_size: Vector3,
	box_transform: Transform3D,
	material: Material,
	scene_root: Node
) -> void:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = node_name
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = box_size
	mesh_instance.mesh = box_mesh
	mesh_instance.material_override = material
	mesh_instance.transform = box_transform
	parent.add_child(mesh_instance)
	mesh_instance.owner = scene_root

func _add_cylinder(
	parent: Node3D,
	node_name: String,
	radius: float,
	height: float,
	center: Vector3,
	material: Material,
	scene_root: Node
) -> void:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = node_name
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = 24
	mesh_instance.mesh = cylinder
	mesh_instance.material_override = material
	mesh_instance.position = center
	parent.add_child(mesh_instance)
	mesh_instance.owner = scene_root

func _make_material(color: Color, metallic_value: float, roughness_value: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic_value
	material.roughness = roughness_value
	return material

func _make_emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	material.roughness = 0.3
	return material
