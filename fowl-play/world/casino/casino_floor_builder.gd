@tool
extends Node3D
class_name CasinoFloorBuilder

## Generates decorative flooring over the existing Casino floor collision.
## Attach to Architecture/FloorDetails. All coordinates are relative to Casino root.

@export_group("Floor Surface")
@export var gaming_floor_top_height: float = 0.15
@export var bar_floor_top_height: float = 0.0
@export var gaming_stone_color: Color = Color(0.075, 0.082, 0.095, 1.0)
@export var gaming_stone_variation: float = 0.012
@export var bar_stone_color: Color = Color(0.105, 0.078, 0.058, 1.0)
@export_range(1.5, 4.0, 0.1) var gaming_tile_size: float = 2.4
@export_range(0.01, 0.10, 0.005) var grout_width: float = 0.035

@export_group("Bronze Floor Inlay")
@export var generate_perimeter_inlay: bool = true
@export var generate_bar_threshold: bool = true
@export var bronze_color: Color = Color(0.34, 0.205, 0.095, 1.0)
@export_range(0.2, 1.2, 0.05) var perimeter_inset: float = 0.62

@export_group("Signature Medallion")
@export var generate_medallion: bool = true
@export var medallion_center: Vector2 = Vector2(-9.0, -15.5)
@export_range(0.8, 3.0, 0.1) var medallion_radius: float = 1.65

@export_group("Bar Flooring")
@export var generate_bar_planks: bool = true
@export var bar_min_x: float = 1.5
@export_range(0.12, 0.35, 0.01) var bar_plank_width: float = 0.22
@export_range(1.0, 2.5, 0.1) var bar_plank_length: float = 1.8

@export_group("Generation")
@export var rebuild_floor: bool = false:
	set(value):
		if value:
			call_deferred("_rebuild_floor")

const GENERATED_ROOT_NAME: String = "_GeneratedFloorDetails"
const FLOOR_FOOTPRINT: Array[Vector2] = [
	Vector2(-24.0, -18.665),
	Vector2(-14.0, -28.665),
	Vector2(11.0, -28.665),
	Vector2(11.0, -1.665),
	Vector2(-24.0, -1.665)
]

func _ready() -> void:
	# Generated children are serialized into the scene. Preserve editor-authored
	# tweaks on reopen; the inspector rebuild toggle remains the explicit reset.
	if Engine.is_editor_hint() and get_node_or_null(GENERATED_ROOT_NAME) == null:
		_rebuild_floor()

func _rebuild_floor() -> void:
	if not Engine.is_editor_hint():
		return
	if gaming_tile_size <= 0.5 or gaming_floor_top_height < 0.0 or bar_floor_top_height < 0.0:
		push_warning("CasinoFloorBuilder has invalid floor dimensions.")
		return

	var old_root: Node = get_node_or_null(GENERATED_ROOT_NAME)
	if old_root != null:
		old_root.free()

	var scene_root: Node = get_tree().edited_scene_root
	if scene_root == null:
		return

	var generated_root: Node3D = Node3D.new()
	generated_root.name = GENERATED_ROOT_NAME
	add_child(generated_root)
	generated_root.owner = scene_root

	var stone_material: StandardMaterial3D = _make_material(gaming_stone_color, 0.22, 0.31)
	var bar_material: StandardMaterial3D = _make_material(bar_stone_color, 0.12, 0.43)
	var bronze_material: StandardMaterial3D = _make_material(bronze_color, 0.78, 0.26)
	var dark_material: StandardMaterial3D = _make_material(Color(0.035, 0.039, 0.047, 1.0), 0.16, 0.38)

	_build_gaming_tiles(generated_root, stone_material, scene_root)
	if generate_bar_planks:
		_build_bar_planks(generated_root, bar_material, scene_root)
	else:
		_build_bar_stone(generated_root, bar_material, scene_root)

	if generate_perimeter_inlay:
		_build_perimeter_inlay(generated_root, bronze_material, scene_root)
	if generate_bar_threshold:
		_build_bar_threshold(generated_root, bronze_material, scene_root)
	if generate_medallion:
		_build_medallion(generated_root, bronze_material, dark_material, scene_root)

func _build_gaming_tiles(parent: Node3D, base_material: Material, scene_root: Node) -> void:
	var x: float = -23.0
	var row: int = 0
	while x + gaming_tile_size * 0.5 < bar_min_x - 0.25:
		var z: float = -28.0
		while z + gaming_tile_size * 0.5 < -1.9:
			var half: float = (gaming_tile_size - grout_width) * 0.5
			var corners: Array[Vector2] = [
				Vector2(x - half, z - half), Vector2(x + half, z - half),
				Vector2(x + half, z + half), Vector2(x - half, z + half)
			]
			var fits: bool = true
			for corner: Vector2 in corners:
				if not Geometry2D.is_point_in_polygon(corner, PackedVector2Array(FLOOR_FOOTPRINT)):
					fits = false
					break
			if fits:
				var material: StandardMaterial3D = base_material.duplicate() as StandardMaterial3D
				var variation: float = float((row * 7 + int(absf(x) * 3.0)) % 5) * gaming_stone_variation * 0.25
				material.albedo_color = gaming_stone_color.lightened(variation)
				_add_box(
					parent, "Gaming_MarbleTile_%02d_%02d" % [row, int((x + 24.0) / gaming_tile_size)],
					Vector3(gaming_tile_size - grout_width, 0.012, gaming_tile_size - grout_width),
					Transform3D(Basis.IDENTITY, Vector3(x, gaming_floor_top_height + 0.006, z)),
					material, scene_root
				)
			z += gaming_tile_size
		x += gaming_tile_size
		row += 1

func _build_bar_planks(parent: Node3D, material: Material, scene_root: Node) -> void:
	var z: float = -28.0
	var row: int = 0
	while z < -1.9:
		var x: float = bar_min_x + (bar_plank_length * 0.5 if row % 2 == 1 else 0.0)
		while x < 10.7:
			var plank_center: Vector2 = Vector2(x, z)
			var half_length: float = bar_plank_length * 0.5 - 0.025
			var half_width: float = bar_plank_width * 0.5 - 0.012
			var corners: Array[Vector2] = [
				plank_center + Vector2(-half_length, -half_width),
				plank_center + Vector2(half_length, -half_width),
				plank_center + Vector2(half_length, half_width),
				plank_center + Vector2(-half_length, half_width)
			]
			var fits: bool = true
			for corner: Vector2 in corners:
				if corner.x < bar_min_x or not Geometry2D.is_point_in_polygon(corner, PackedVector2Array(FLOOR_FOOTPRINT)):
					fits = false
					break
			if fits:
				var plank_material: StandardMaterial3D = material.duplicate() as StandardMaterial3D
				var shade: float = 0.025 if (row + int(x * 2.0)) % 3 == 0 else 0.0
				plank_material.albedo_color = bar_stone_color.lightened(shade)
				_add_box(
					parent, "Bar_SmokedOak_Plank_%02d_%02d" % [row, int(x * 2.0)],
					Vector3(bar_plank_length - 0.05, 0.012, bar_plank_width - 0.024),
					Transform3D(Basis.IDENTITY, Vector3(x, bar_floor_top_height + 0.006, z)),
					plank_material, scene_root
				)
			x += bar_plank_length
		z += bar_plank_width
		row += 1

func _build_bar_stone(parent: Node3D, material: Material, scene_root: Node) -> void:
	var mesh_material: StandardMaterial3D = material as StandardMaterial3D
	for x_index: int in range(4):
		for z_index: int in range(6):
			var center: Vector3 = Vector3(bar_min_x + 1.1 + float(x_index) * 2.1, bar_floor_top_height + 0.006, -27.0 + float(z_index) * 4.2)
			_add_box(parent, "Bar_StoneTile_%02d_%02d" % [x_index, z_index], Vector3(2.05, 0.012, 4.12), Transform3D(Basis.IDENTITY, center), mesh_material, scene_root)

func _build_perimeter_inlay(parent: Node3D, material: Material, scene_root: Node) -> void:
	var center: Vector2 = Vector2(-8.0, -17.0)
	var footprint: PackedVector2Array = PackedVector2Array(FLOOR_FOOTPRINT)
	for index: int in range(footprint.size()):
		var start: Vector2 = footprint[index]
		var finish: Vector2 = footprint[(index + 1) % footprint.size()]
		var inward: Vector2 = (center - (start + finish) * 0.5).normalized()
		var inset_start: Vector2 = start + inward * perimeter_inset
		var inset_end: Vector2 = finish + inward * perimeter_inset
		_add_floor_line_by_zone(parent, "Bronze_Perimeter_Inlay_%02d" % index, inset_start, inset_end, 0.035, material, scene_root)
		_add_floor_line_by_zone(parent, "Dark_Perimeter_Pinstripe_%02d" % index, inset_start + inward * 0.075, inset_end + inward * 0.075, 0.018, material, scene_root)

func _build_bar_threshold(parent: Node3D, material: Material, scene_root: Node) -> void:
	_add_box(
		parent, "Bar_Threshold_Bronze",
		Vector3(0.075, 0.014, 21.0),
		Transform3D(Basis.IDENTITY, Vector3(bar_min_x - 0.18, gaming_floor_top_height + 0.007, -14.75)),
		material, scene_root
	)

func _build_medallion(parent: Node3D, bronze_material: Material, dark_material: Material, scene_root: Node) -> void:
	var outer: TorusMesh = TorusMesh.new()
	outer.inner_radius = medallion_radius - 0.035
	outer.outer_radius = medallion_radius
	var outer_instance: MeshInstance3D = MeshInstance3D.new()
	outer_instance.name = "House_Medallion_Outer_Ring"
	outer_instance.mesh = outer
	outer_instance.material_override = bronze_material
	outer_instance.position = Vector3(medallion_center.x, gaming_floor_top_height + 0.012, medallion_center.y)
	parent.add_child(outer_instance)
	outer_instance.owner = scene_root

	var inner: TorusMesh = TorusMesh.new()
	inner.inner_radius = medallion_radius - 0.27
	inner.outer_radius = medallion_radius - 0.235
	var inner_instance: MeshInstance3D = MeshInstance3D.new()
	inner_instance.name = "House_Medallion_Inner_Ring"
	inner_instance.mesh = inner
	inner_instance.material_override = bronze_material
	inner_instance.position = Vector3(medallion_center.x, gaming_floor_top_height + 0.012, medallion_center.y)
	parent.add_child(inner_instance)
	inner_instance.owner = scene_root

	var center_disc: CylinderMesh = CylinderMesh.new()
	center_disc.top_radius = medallion_radius - 0.31
	center_disc.bottom_radius = medallion_radius - 0.31
	center_disc.height = 0.012
	var disc_instance: MeshInstance3D = MeshInstance3D.new()
	disc_instance.name = "House_Medallion_Enamel_Center"
	disc_instance.mesh = center_disc
	disc_instance.material_override = dark_material
	disc_instance.position = Vector3(medallion_center.x, gaming_floor_top_height + 0.006, medallion_center.y)
	parent.add_child(disc_instance)
	disc_instance.owner = scene_root

func _add_floor_line_by_zone(parent: Node3D, node_name: String, start: Vector2, finish: Vector2, width: float, material: Material, scene_root: Node) -> void:
	var start_side: float = start.x - bar_min_x
	var finish_side: float = finish.x - bar_min_x
	if start_side * finish_side < 0.0:
		var split_amount: float = (bar_min_x - start.x) / (finish.x - start.x)
		var split_point: Vector2 = start.lerp(finish, split_amount)
		if start.x < bar_min_x:
			_add_floor_line(parent, node_name + "_Gaming", start, split_point, width, gaming_floor_top_height, material, scene_root)
			_add_floor_line(parent, node_name + "_Bar", split_point, finish, width, bar_floor_top_height, material, scene_root)
		else:
			_add_floor_line(parent, node_name + "_Bar", start, split_point, width, bar_floor_top_height, material, scene_root)
			_add_floor_line(parent, node_name + "_Gaming", split_point, finish, width, gaming_floor_top_height, material, scene_root)
	elif (start.x + finish.x) * 0.5 >= bar_min_x:
		_add_floor_line(parent, node_name, start, finish, width, bar_floor_top_height, material, scene_root)
	else:
		_add_floor_line(parent, node_name, start, finish, width, gaming_floor_top_height, material, scene_root)

func _add_floor_line(parent: Node3D, node_name: String, start: Vector2, finish: Vector2, width: float, surface_height: float, material: Material, scene_root: Node) -> void:
	var edge: Vector2 = finish - start
	var length: float = edge.length()
	if length <= 0.1:
		return
	var tangent: Vector3 = Vector3(edge.x, 0.0, edge.y).normalized()
	var inward: Vector3 = tangent.cross(Vector3.UP).normalized()
	var basis: Basis = Basis(tangent, Vector3.UP, inward)
	var center: Vector3 = Vector3((start.x + finish.x) * 0.5, surface_height + 0.006, (start.y + finish.y) * 0.5)
	_add_box(parent, node_name, Vector3(length, 0.012, width), Transform3D(basis, center), material, scene_root)

func _add_box(parent: Node3D, node_name: String, size: Vector3, box_transform: Transform3D, material: Material, scene_root: Node) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material
	instance.transform = box_transform
	parent.add_child(instance)
	instance.owner = scene_root

func _make_material(color: Color, metallic_value: float, roughness_value: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic_value
	material.roughness = roughness_value
	return material
