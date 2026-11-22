@tool
extends Node3D
class_name CasinoPerimeterBuilder

## Generates solid casino perimeter walls with substantial lower-half wainscoting.
## The panoramic façade edges are intentionally omitted.
## Coordinates are relative to the Casino root. Attach to Architecture/Perimeter.

@export_group("Wall")
@export_range(2.0, 8.0, 0.05) var wall_height: float = 4.2
@export_range(0.1, 1.0, 0.01) var wall_thickness: float = 0.38
@export var floor_level: float = 0.0
@export_range(0.0, 0.5, 0.01) var end_overlap: float = 0.08
@export var wall_color: Color = Color(0.055, 0.062, 0.072, 1.0)

@export_group("Lower Wainscoting")
@export var generate_wainscoting: bool = true
@export_range(0.8, 1.8, 0.05) var wainscoting_height: float = 1.3
@export_range(1.2, 3.2, 0.1) var panel_spacing: float = 2.2
@export_range(0.04, 0.14, 0.01) var molding_width: float = 0.075
@export_range(0.02, 0.10, 0.01) var molding_depth: float = 0.055
@export_range(0.02, 0.08, 0.01) var panel_face_depth: float = 0.03
@export var wainscoting_color: Color = Color(0.075, 0.083, 0.094, 1.0)
@export var panel_color: Color = Color(0.095, 0.105, 0.118, 1.0)
@export var molding_color: Color = Color(0.20, 0.15, 0.105, 1.0)

@export_group("Elevator Opening")
@export var generate_elevator_opening: bool = true
@export_range(0.0, 35.0, 0.05) var elevator_opening_center_distance: float = 4.8
@export_range(3.5, 5.0, 0.05) var elevator_opening_width: float = 3.9
@export_range(2.8, 3.8, 0.05) var elevator_opening_height: float = 3.15

const ELEVATOR_WALL_SEGMENT_INDEX: int = 1

@export var generate_elevator_portal: bool = true
@export_range(0.02, 0.18, 0.01) var elevator_portal_trim_width: float = 0.08
@export_range(0.02, 0.12, 0.01) var elevator_portal_trim_depth: float = 0.055
@export var elevator_portal_trim_color: Color = Color(0.36, 0.22, 0.105, 1.0)
@export var elevator_portal_return_color: Color = Color(0.035, 0.041, 0.049, 1.0)

@export_group("Collision")
@export var generate_collision: bool = true

@export_group("Generation")
@export var rebuild_geometry: bool = false:
	set(value):
		if value:
			call_deferred("_rebuild_geometry")

const GENERATED_ROOT_NAME: String = "_GeneratedPerimeter"

# Three solid edges of the footprint. The two panoramic-window edges stay open.
const SOLID_WALL_PATH: Array[Vector2] = [
	Vector2(11.0, -28.665),
	Vector2(11.0, -1.665),
	Vector2(-24.0, -1.665),
	Vector2(-24.0, -18.665)
]

func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild_geometry()

func _rebuild_geometry() -> void:
	if not Engine.is_editor_hint():
		return
	if wall_height <= 0.1 or wall_thickness <= 0.05:
		push_warning("CasinoPerimeterBuilder has invalid wall dimensions.")
		return

	var old_root: Node = get_node_or_null(GENERATED_ROOT_NAME)
	if old_root != null:
		old_root.free()

	var scene_root: Node = get_tree().edited_scene_root
	var generated_root: Node3D = Node3D.new()
	generated_root.name = GENERATED_ROOT_NAME
	add_child(generated_root)
	generated_root.owner = scene_root

	var wall_material: StandardMaterial3D = _make_material(wall_color, 0.08, 0.38)
	var wainscoting_material: StandardMaterial3D = _make_material(wainscoting_color, 0.10, 0.34)
	var panel_material: StandardMaterial3D = _make_material(panel_color, 0.08, 0.30)
	var molding_material: StandardMaterial3D = _make_material(molding_color, 0.55, 0.30)

	for index: int in range(SOLID_WALL_PATH.size() - 1):
		_build_wall_segment(
			generated_root,
			SOLID_WALL_PATH[index],
			SOLID_WALL_PATH[index + 1],
			index,
			wall_material,
			wainscoting_material,
			panel_material,
			molding_material,
			scene_root
		)

func _build_wall_segment(
	parent: Node3D,
	start_2d: Vector2,
	end_2d: Vector2,
	segment_index: int,
	wall_material: Material,
	wainscoting_material: Material,
	panel_material: Material,
	molding_material: Material,
	scene_root: Node
) -> void:
	var start: Vector3 = Vector3(start_2d.x, 0.0, start_2d.y)
	var end: Vector3 = Vector3(end_2d.x, 0.0, end_2d.y)
	var edge: Vector3 = end - start
	var edge_length: float = edge.length()
	if edge_length <= 0.1:
		return

	var tangent: Vector3 = edge / edge_length
	var inward: Vector3 = tangent.cross(Vector3.UP).normalized()
	var segment_basis: Basis = Basis(tangent, Vector3.UP, inward)
	var prefix: String = "Wall_%02d_" % segment_index

	# Segment 1 is the long rear wall, where the existing elevator faces.
	# Leave a full-height opening centered on the elevator's committed position.
	if segment_index == ELEVATOR_WALL_SEGMENT_INDEX:
		var opening_start: float = elevator_opening_center_distance - elevator_opening_width * 0.5
		var opening_end: float = elevator_opening_center_distance + elevator_opening_width * 0.5
		opening_start = clampf(opening_start, 0.0, edge_length)
		opening_end = clampf(opening_end, 0.0, edge_length)

		if opening_start > 0.1:
			_build_wall_piece(
				parent, prefix + "Left", start, tangent, inward, opening_start,
				segment_basis, wall_material, wainscoting_material, panel_material,
				molding_material, scene_root
			)
		if edge_length - opening_end > 0.1:
			_build_wall_piece(
				parent, prefix + "Right", start + tangent * opening_end, tangent, inward,
				edge_length - opening_end, segment_basis, wall_material,
				wainscoting_material, panel_material, molding_material, scene_root
			)

		if generate_elevator_portal:
			_build_elevator_portal(
				parent, start, tangent, inward, edge_length, segment_basis,
				molding_material, scene_root
			)

		# Solid stone header above the opening; the space below remains clear.
		var header_height: float = wall_height - elevator_opening_height
		if header_height > 0.1:
			var header_center: Vector3 = start + tangent * elevator_opening_center_distance
			header_center += Vector3.UP * (floor_level + elevator_opening_height + header_height * 0.5)
			_add_box(
				parent, prefix + "ElevatorOpening_Header",
				Vector3(elevator_opening_width, header_height, wall_thickness),
				Transform3D(segment_basis, header_center),
				wall_material, scene_root, true
			)
		return

	_build_wall_piece(
		parent, prefix, start, tangent, inward, edge_length, segment_basis,
		wall_material, wainscoting_material, panel_material, molding_material, scene_root
	)

func _build_wall_piece(
	parent: Node3D,
	prefix: String,
	start: Vector3,
	tangent: Vector3,
	inward: Vector3,
	edge_length: float,
	segment_basis: Basis,
	wall_material: Material,
	wainscoting_material: Material,
	panel_material: Material,
	molding_material: Material,
	scene_root: Node
) -> void:
	var midpoint: Vector3 = start + tangent * (edge_length * 0.5)
	var wall_center: Vector3 = midpoint + Vector3.UP * (floor_level + wall_height * 0.5)
	_add_box(
		parent, prefix + "Stone",
		Vector3(edge_length + end_overlap, wall_height, wall_thickness),
		Transform3D(segment_basis, wall_center),
		wall_material, scene_root, true
	)

	if generate_wainscoting:
		_build_wainscoting(
			parent, prefix, start, tangent, inward, edge_length,
			segment_basis, wainscoting_material, panel_material, molding_material, scene_root
		)


func _build_elevator_portal(
	parent: Node3D,
	wall_start: Vector3,
	tangent: Vector3,
	inward: Vector3,
	edge_length: float,
	segment_basis: Basis,
	bronze_material: Material,
	scene_root: Node
) -> void:
	var center: Vector3 = wall_start + tangent * elevator_opening_center_distance
	var wall_face_offset: float = wall_thickness * 0.5 + 0.025
	var return_material: StandardMaterial3D = _make_material(elevator_portal_return_color, 0.08, 0.42)
	var trim_material: StandardMaterial3D = _make_material(elevator_portal_trim_color, 0.62, 0.28)
	var half_width: float = elevator_opening_width * 0.5
	var trim_width: float = elevator_portal_trim_width

	# Dark stone reveals line the inside edges of the wall opening without narrowing it.
	for side_index: int in range(2):
		var side_sign: float = -1.0 if side_index == 0 else 1.0
		var reveal_center: Vector3 = center + tangent * (side_sign * (half_width - 0.018))
		reveal_center += Vector3.UP * (floor_level + elevator_opening_height * 0.5)
		_add_box(
			parent, "ElevatorPortal_Return_%d" % side_index,
			Vector3(0.036, elevator_opening_height, wall_thickness),
			Transform3D(segment_basis, reveal_center),
			return_material, scene_root, false
		)

	# A dark stone reveal across the top of the opening.
	var top_reveal_center: Vector3 = center + Vector3.UP * (floor_level + elevator_opening_height - 0.018)
	_add_box(
		parent, "ElevatorPortal_TopReturn",
		Vector3(elevator_opening_width, 0.036, wall_thickness),
		Transform3D(segment_basis, top_reveal_center),
		return_material, scene_root, false
	)

	# Restrained bronze frame on the casino-facing wall surface.
	for side_index: int in range(2):
		var side_sign: float = -1.0 if side_index == 0 else 1.0
		var jamb_center: Vector3 = center + tangent * (side_sign * (half_width + trim_width * 0.5))
		jamb_center += Vector3.UP * (floor_level + elevator_opening_height * 0.5)
		jamb_center += inward * wall_face_offset
		_add_box(
			parent, "ElevatorPortal_BronzeJamb_%d" % side_index,
			Vector3(trim_width, elevator_opening_height + trim_width, elevator_portal_trim_depth),
			Transform3D(segment_basis, jamb_center),
			trim_material, scene_root, false
		)

	var header_center: Vector3 = center + Vector3.UP * (floor_level + elevator_opening_height + trim_width * 0.5)
	header_center += inward * wall_face_offset
	_add_box(
		parent, "ElevatorPortal_BronzeHeader",
		Vector3(elevator_opening_width + trim_width * 2.0, trim_width, elevator_portal_trim_depth),
		Transform3D(segment_basis, header_center),
		trim_material, scene_root, false
	)


func _build_wainscoting(
	parent: Node3D,
	prefix: String,
	start: Vector3,
	tangent: Vector3,
	inward: Vector3,
	edge_length: float,
	segment_basis: Basis,
	backing_material: Material,
	panel_material: Material,
	molding_material: Material,
	scene_root: Node
) -> void:
	var panel_top: float = minf(wainscoting_height, wall_height - 0.25)
	var base_height: float = 0.18
	var top_rail_height: float = 0.11
	var panel_bottom: float = base_height + 0.13
	var panel_height: float = panel_top - panel_bottom - top_rail_height - 0.10
	if panel_height <= 0.3:
		return

	# Continuous lower backing board makes this read as architectural wainscoting.
	var backing_height: float = panel_top - base_height
	var backing_center: Vector3 = start + tangent * (edge_length * 0.5)
	backing_center += Vector3.UP * (floor_level + base_height + backing_height * 0.5)
	backing_center += inward * (wall_thickness * 0.5 + 0.018)
	_add_box(
		parent, prefix + "Wainscot_Backboard",
		Vector3(edge_length, backing_height, 0.035),
		Transform3D(segment_basis, backing_center),
		backing_material, scene_root, false
	)

	# Substantial skirting at the floor and a chair rail at the top of the panel field.
	_add_horizontal_trim(
		parent, prefix + "Wainscot_Baseboard", start, tangent, inward,
		edge_length, floor_level + base_height * 0.5,
		0.07, 0.075, segment_basis, molding_material, scene_root
	)
	_add_horizontal_trim(
		parent, prefix + "Wainscot_ChairRail", start, tangent, inward,
		edge_length, floor_level + panel_top - top_rail_height * 0.5,
		 top_rail_height, 0.11, segment_basis, molding_material, scene_root
	)

	# Repeated large framed panels across the lower half of the wall.
	var panel_count: int = maxi(1, int(floor(edge_length / maxf(1.2, panel_spacing))))
	var bay_width: float = edge_length / float(panel_count)
	var frame_width: float = molding_width
	var face_width: float = bay_width - frame_width * 2.0 - 0.20
	var face_height: float = panel_height - frame_width * 2.0
	if face_width <= 0.25 or face_height <= 0.25:
		return

	for panel_index: int in range(panel_count):
		var center_distance: float = (float(panel_index) + 0.5) * bay_width
		var panel_center: Vector3 = start + tangent * center_distance
		var center_y: float = floor_level + panel_bottom + panel_height * 0.5
		var face_center: Vector3 = panel_center + Vector3.UP * center_y
		face_center += inward * (wall_thickness * 0.5 + 0.045)
		_add_box(
			parent, prefix + "Panel_%02d_Face" % panel_index,
			Vector3(face_width, face_height, panel_face_depth),
			Transform3D(segment_basis, face_center),
			panel_material, scene_root, false
		)

		var frame_center: Vector3 = panel_center + Vector3.UP * center_y
		frame_center += inward * (wall_thickness * 0.5 + 0.075)
		# Left and right stiles.
		for side_index: int in range(2):
			var side_offset: float = -(face_width * 0.5 + frame_width * 0.5) if side_index == 0 else (face_width * 0.5 + frame_width * 0.5)
			_add_box(
				parent, prefix + "Panel_%02d_Stile_%d" % [panel_index, side_index],
				Vector3(frame_width, panel_height, molding_depth),
				Transform3D(segment_basis, frame_center + tangent * side_offset),
				molding_material, scene_root, false
			)

		# Top and bottom rails complete the raised rectangular molding.
		for rail_index: int in range(2):
			var rail_y: float = -panel_height * 0.5 + frame_width * 0.5 if rail_index == 0 else panel_height * 0.5 - frame_width * 0.5
			_add_box(
				parent, prefix + "Panel_%02d_Rail_%d" % [panel_index, rail_index],
				Vector3(face_width + frame_width * 2.0, frame_width, molding_depth),
				Transform3D(segment_basis, frame_center + Vector3.UP * rail_y),
				molding_material, scene_root, false
			)

func _add_horizontal_trim(
	parent: Node3D,
	node_name: String,
	start: Vector3,
	tangent: Vector3,
	inward: Vector3,
	edge_length: float,
	height: float,
	trim_height: float,
	trim_depth: float,
	segment_basis: Basis,
	material: Material,
	scene_root: Node
) -> void:
	var center: Vector3 = start + tangent * (edge_length * 0.5)
	center += Vector3.UP * height
	center += inward * (wall_thickness * 0.5 + trim_depth * 0.5 + 0.025)
	_add_box(
		parent, node_name,
		Vector3(edge_length, trim_height, trim_depth),
		Transform3D(segment_basis, center),
		material, scene_root, false
	)

func _add_box(
	parent: Node3D,
	node_name: String,
	box_size: Vector3,
	box_transform: Transform3D,
	material: Material,
	scene_root: Node,
	with_collision: bool
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

	if with_collision and generate_collision:
		var body: StaticBody3D = StaticBody3D.new()
		body.name = node_name + "_Collision"
		parent.add_child(body)
		body.owner = scene_root
		var collision: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = box_size
		collision.shape = shape
		collision.transform = box_transform
		body.add_child(collision)
		collision.owner = scene_root

func _make_material(color: Color, metallic_value: float, roughness_value: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic_value
	material.roughness = roughness_value
	return material
