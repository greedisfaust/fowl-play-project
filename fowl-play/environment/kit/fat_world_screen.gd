## Responsive controller for the editor-authored industrial FAT WorldScreen housing.
@tool
class_name FatWorldScreen
extends Node3D

const GLASS_SHADER: Shader = preload("res://environment/kit/world_screen_glass.gdshader")

@export_group("Display")
@export var display_size: Vector2 = Vector2(2.0, 1.125):
	set(value):
		display_size = Vector2(maxf(value.x, 0.1), maxf(value.y, 0.1))
		_apply_configuration()

@export_group("Industrial Chassis")
@export_range(0.05, 0.5, 0.01) var chassis_margin: float = 0.22:
	set(value):
		chassis_margin = clampf(value, 0.05, 0.5)
		_apply_configuration()
@export_range(0.04, 0.3, 0.01) var chassis_depth: float = 0.30:
	set(value):
		chassis_depth = clampf(value, 0.04, 0.3)
		_apply_configuration()
@export_range(0.04, 0.25, 0.005) var armor_thickness: float = 0.12:
	set(value):
		armor_thickness = clampf(value, 0.04, 0.25)
		_apply_configuration()
@export_range(0.02, 0.3, 0.01) var corner_cut: float = 0.12:
	set(value):
		corner_cut = clampf(value, 0.02, 0.3)
		_apply_configuration()

@export_group("Identification")
@export_range(0.25, 4.0, 0.05) var identification_text_scale: float = 1.0:
	set(value):
		identification_text_scale = clampf(value, 0.25, 4.0)
		_apply_configuration()

@export_group("Glass Finish")
@export_range(0.0, 0.15, 0.005) var glass_base_opacity: float = 0.035:
	set(value):
		glass_base_opacity = clampf(value, 0.0, 0.15)
		_apply_configuration()
@export_range(0.0, 1.0, 0.01) var glass_sheen_strength: float = 0.55:
	set(value):
		glass_sheen_strength = clampf(value, 0.0, 1.0)
		_apply_configuration()
@export_range(0.25, 10.0, 0.25) var glass_sheen_near_distance: float = 1.5:
	set(value):
		glass_sheen_near_distance = maxf(value, 0.25)
		_apply_configuration()
@export_range(1.0, 20.0, 0.25) var glass_sheen_far_distance: float = 5.0:
	set(value):
		glass_sheen_far_distance = maxf(value, glass_sheen_near_distance + 0.1)
		_apply_configuration()

var _glass_material: ShaderMaterial
var _lettering_base_scale: Vector3 = Vector3.ONE
var _lettering_scale_captured: bool = false
var _warning_sent: bool = false
var _authored_positions: Dictionary = {}
var _layout_initialized: bool = false

## Cache authored local positions by node identity, not absolute scene path.
## Absolute paths change when this scene is instanced under a different parent
## or the instance is reparented; node references remain stable for this instance.
func _capture_authored_positions(node: Node) -> void:
	if node == self:
		_authored_positions.clear()
	if node is Node3D:
		var spatial: Node3D = node as Node3D
		_authored_positions[spatial] = spatial.position
	for child: Node in node.get_children():
		_capture_authored_positions(child)

func _authored_position(node: Node3D) -> Vector3:
	if _authored_positions.has(node):
		var authored_position: Vector3 = _authored_positions[node]
		return authored_position
	return node.position

func _width_delta() -> float:
	return (display_size.x - 2.0) * 0.5

func _height_delta() -> float:
	return (display_size.y - 1.125) * 0.5


func _ready() -> void:
	# Keep chassis and glass mesh/material changes local to this placed instance.
	_make_housing_resources_local(get_node_or_null("Chassis"))
	_make_housing_resources_local(get_node_or_null("Glass"))
	_capture_authored_positions(self)
	_layout_initialized = true
	var lettering: MeshInstance3D = get_node_or_null("Chassis/ControlPanel/IdentificationPlate/EngravedText") as MeshInstance3D
	if lettering != null:
		_lettering_base_scale = lettering.scale
		_lettering_scale_captured = true
	_apply_configuration()

func _make_housing_resources_local(node: Node) -> void:
	if node == null:
		return
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh != null:
			mesh_instance.mesh = mesh_instance.mesh.duplicate(true) as Mesh
		if mesh_instance.material_override != null:
			mesh_instance.material_override = mesh_instance.material_override.duplicate(true) as Material
		if mesh_instance.material_overlay != null:
			mesh_instance.material_overlay = mesh_instance.material_overlay.duplicate(true) as Material
	elif node is GeometryInstance3D:
		var geometry: GeometryInstance3D = node as GeometryInstance3D
		if geometry.material_override != null:
			geometry.material_override = geometry.material_override.duplicate(true) as Material
	for child: Node in node.get_children():
		_make_housing_resources_local(child)

func set_display_size(value: Vector2) -> void:
	display_size = value

func _apply_configuration() -> void:
	if not is_inside_tree() or not _layout_initialized:
		return

	var screen: WorldScreen = get_node_or_null("WorldScreen") as WorldScreen
	var chassis: Node3D = get_node_or_null("Chassis") as Node3D
	var glass: MeshInstance3D = get_node_or_null("Glass") as MeshInstance3D
	if screen != null:
		screen.set_display_size(display_size)
	if chassis != null:
		_layout_chassis(chassis)
	if glass != null:
		_layout_glass(glass)

	if (screen == null or chassis == null or glass == null) and not _warning_sent:
		push_warning("FatWorldScreen expects WorldScreen, Chassis, and Glass children. Check the editor-authored hierarchy.")
		_warning_sent = true

func _half_width() -> float:
	return display_size.x * 0.5

func _half_height() -> float:
	return display_size.y * 0.5

func _outer_half_width() -> float:
	return _half_width() + chassis_margin

func _outer_half_height() -> float:
	return _half_height() + chassis_margin

func _set_polygon(node: CSGPolygon3D, points: PackedVector2Array, depth: float, z_position: float) -> void:
	if node == null:
		return
	# Keep all polygon faces consistently wound so mirrored corner plates do not flip.
	var signed_area: float = 0.0
	for index: int in range(points.size()):
		var current: Vector2 = points[index]
		var next: Vector2 = points[(index + 1) % points.size()]
		signed_area += current.x * next.y - next.x * current.y
	if signed_area < 0.0:
		var reversed_points: PackedVector2Array = PackedVector2Array()
		for index: int in range(points.size() - 1, -1, -1):
			reversed_points.append(points[index])
		points = reversed_points
	node.mode = CSGPolygon3D.MODE_DEPTH
	node.use_collision = false
	node.polygon = points
	node.depth = depth
	node.position = Vector3(0.0, 0.0, z_position)

func _layout_chassis(chassis: Node3D) -> void:
	var outer_shell: CSGPolygon3D = chassis.get_node_or_null("OuterShell") as CSGPolygon3D
	if outer_shell != null:
		_layout_outer_shell(outer_shell)

	var inner_armor: Node3D = chassis.get_node_or_null("InnerArmor") as Node3D
	if inner_armor != null:
		_layout_inner_armor(inner_armor)

	var corner_armor: Node3D = chassis.get_node_or_null("CornerArmor") as Node3D
	if corner_armor != null:
		_layout_corner_armor(corner_armor)

	var side_details: Node3D = chassis.get_node_or_null("SideDetails") as Node3D
	if side_details != null:
		_layout_side_details(side_details)

	var control_panel: Node3D = chassis.get_node_or_null("ControlPanel") as Node3D
	if control_panel != null:
		_layout_control_panel(control_panel)

	var fasteners: Node3D = chassis.get_node_or_null("Fasteners") as Node3D
	if fasteners != null:
		_layout_fasteners(fasteners)

func _layout_outer_shell(shell: CSGPolygon3D) -> void:
	var half_width: float = _outer_half_width()
	var half_height: float = _outer_half_height()
	var cut: float = minf(corner_cut, minf(half_width, half_height) * 0.45)
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(-half_width + cut, -half_height),
		Vector2(half_width - cut, -half_height),
		Vector2(half_width, -half_height + cut),
		Vector2(half_width, half_height - cut),
		Vector2(half_width - cut, half_height),
		Vector2(-half_width + cut, half_height),
		Vector2(-half_width, half_height - cut),
		Vector2(-half_width, -half_height + cut)
	])
	_set_polygon(shell, points, chassis_depth, -0.005)

func _layout_inner_armor(group: Node3D) -> void:
	# The controller owns the armor offsets; clear the authored parent offset before positioning each plate.
	var half_width: float = _half_width()
	var half_height: float = _half_height()
	var frame: float = armor_thickness
	var inner_x: float = half_width - 0.04
	var outer_x: float = half_width + frame * 1.33
	var inner_y: float = half_height - 0.0125
	var outer_y: float = half_height + frame

	_set_polygon(group.get_node_or_null("TopArmor") as CSGPolygon3D, PackedVector2Array([
		Vector2(-half_width - frame * 0.67, inner_y),
		Vector2(half_width + frame * 0.67, inner_y),
		Vector2(outer_x, outer_y),
		Vector2(-outer_x, outer_y)
	]), 0.055, 0.015)
	_set_polygon(group.get_node_or_null("BottomArmor") as CSGPolygon3D, PackedVector2Array([
		Vector2(-outer_x, -outer_y),
		Vector2(outer_x, -outer_y),
		Vector2(half_width + frame * 0.67, -inner_y),
		Vector2(-half_width - frame * 0.67, -inner_y)
	]), 0.055, 0.015)
	_set_polygon(group.get_node_or_null("LeftArmor") as CSGPolygon3D, PackedVector2Array([
		Vector2(-outer_x, -inner_y),
		Vector2(-inner_x, -inner_y),
		Vector2(-inner_x, inner_y),
		Vector2(-outer_x, inner_y)
	]), 0.055, 0.015)
	_set_polygon(group.get_node_or_null("RightArmor") as CSGPolygon3D, PackedVector2Array([
		Vector2(inner_x, -inner_y),
		Vector2(outer_x, -inner_y),
		Vector2(outer_x, inner_y),
		Vector2(inner_x, inner_y)
	]), 0.055, 0.015)

func _layout_corner_armor(group: Node3D) -> void:
	var outer_x: float = _outer_half_width()
	var outer_y: float = _outer_half_height()
	var cut: float = minf(corner_cut, minf(outer_x, outer_y) * 0.45)
	var plate_width: float = maxf(0.16, chassis_margin * 1.55)
	var plate_height: float = maxf(0.12, chassis_margin * 0.72)
	var inner_x: float = outer_x - plate_width
	var inner_y: float = outer_y - plate_height
	var depth: float = 0.035
	var z_position: float = 0.045
	group.position = Vector3(0.0, 0.0, _authored_position(group).z)

	_set_polygon(group.get_node_or_null("TopLeft") as CSGPolygon3D, PackedVector2Array([
		Vector2(-outer_x + 0.02, outer_y - cut),
		Vector2(-outer_x + cut, outer_y - 0.02),
		Vector2(-inner_x, outer_y - 0.02),
		Vector2(-outer_x + cut * 2.0, inner_y)
	]), depth, z_position)
	_set_polygon(group.get_node_or_null("TopRight") as CSGPolygon3D, PackedVector2Array([
		Vector2(outer_x - 0.02, outer_y - cut),
		Vector2(outer_x - cut, outer_y - 0.02),
		Vector2(inner_x, outer_y - 0.02),
		Vector2(outer_x - cut * 2.0, inner_y)
	]), depth, z_position)
	_set_polygon(group.get_node_or_null("BottomLeft") as CSGPolygon3D, PackedVector2Array([
		Vector2(-outer_x + 0.02, -outer_y + cut),
		Vector2(-outer_x + cut, -outer_y + 0.02),
		Vector2(-inner_x, -outer_y + 0.02),
		Vector2(-outer_x + cut * 2.0, -inner_y)
	]), depth, z_position)
	_set_polygon(group.get_node_or_null("BottomRight") as CSGPolygon3D, PackedVector2Array([
		Vector2(outer_x - 0.02, -outer_y + cut),
		Vector2(outer_x - cut, -outer_y + 0.02),
		Vector2(inner_x, -outer_y + 0.02),
		Vector2(outer_x - cut * 2.0, -inner_y)
	]), depth, z_position)

func _layout_side_details(group: Node3D) -> void:
	var side_offset: float = _half_width() + chassis_margin * 0.77
	_layout_vent_group(group.get_node_or_null("LeftVent") as Node3D, -side_offset)
	_layout_vent_group(group.get_node_or_null("RightVent") as Node3D, side_offset)

func _layout_vent_group(group: Node3D, x_position: float) -> void:
	if group == null:
		return
	group.position = _authored_position(group) + Vector3(signf(x_position) * _width_delta(), 0.0, 0.0)
	var height_scale: float = display_size.y / 1.125
	for child: Node in group.get_children():
		var vent: MeshInstance3D = child as MeshInstance3D
		if vent == null:
			continue
		var authored_vent_position: Vector3 = _authored_position(vent)
		vent.position = Vector3(authored_vent_position.x, authored_vent_position.y * height_scale, authored_vent_position.z)
		var box: BoxMesh = vent.mesh as BoxMesh
		if box == null:
			box = BoxMesh.new()
			vent.mesh = box
		box.size = Vector3(0.025, 0.065 * height_scale, 0.012)

func _layout_control_panel(group: Node3D) -> void:
	var panel_y: float = -_half_height() - 0.10
	var body: MeshInstance3D = group.get_node_or_null("PanelBody") as MeshInstance3D
	if body != null:
		var body_mesh: BoxMesh = body.mesh as BoxMesh
		if body_mesh == null:
			body_mesh = BoxMesh.new()
			body.mesh = body_mesh
		body_mesh.size = Vector3(display_size.x * 0.675, 0.16, 0.055)
		body.position = Vector3(0.0, panel_y, 0.035)

	var indicators: Node3D = group.get_node_or_null("IndicatorGroup") as Node3D
	if indicators != null:
		indicators.position = Vector3(0.0, panel_y, 0.035)
		var indicator_index: int = 0
		for child: Node in indicators.get_children():
			var indicator: MeshInstance3D = child as MeshInstance3D
			if indicator == null:
				continue
			indicator.position = Vector3(-display_size.x * 0.225 + float(indicator_index) * 0.08, 0.0, 0.04)
			indicator.rotation_degrees = Vector3(90.0, 0.0, 0.0)
			indicator_index += 1

	var plate_group: Node3D = group.get_node_or_null("IdentificationPlate") as Node3D
	if plate_group != null:
		plate_group.position = Vector3(0.0, panel_y, 0.035)
		var plate: MeshInstance3D = plate_group.get_node_or_null("PlateMesh") as MeshInstance3D
		if plate != null:
			var plate_mesh: BoxMesh = plate.mesh as BoxMesh
			if plate_mesh == null:
				plate_mesh = BoxMesh.new()
				plate.mesh = plate_mesh
			plate_mesh.size = Vector3(display_size.x * 0.24, 0.075, 0.012)
			plate.position = Vector3(display_size.x * 0.135, 0.0, 0.04)
		var lettering: MeshInstance3D = plate_group.get_node_or_null("EngravedText") as MeshInstance3D
		if lettering != null:
			if not _lettering_scale_captured:
				_lettering_base_scale = lettering.scale
				_lettering_scale_captured = true
			lettering.position = Vector3(display_size.x * 0.135, 0.0, 0.049)
			lettering.scale = _lettering_base_scale * (display_size.x / 2.0) * identification_text_scale

func _layout_fasteners(group: Node3D) -> void:
	var x_position: float = _half_width() + chassis_margin * 0.36
	var y_position: float = _half_height() + chassis_margin * 0.58
	var positions: Dictionary = {
		"TopLeftFastener": Vector3(-x_position, y_position, 0.085),
		"TopRightFastener": Vector3(x_position, y_position, 0.085),
		"BottomLeftFastener": Vector3(-x_position, -y_position, 0.085),
		"BottomRightFastener": Vector3(x_position, -y_position, 0.085),
		# Keep compatibility with the shorter names used by the contract fixture.
		"TopLeft": Vector3(-x_position, y_position, 0.085),
		"TopRight": Vector3(x_position, y_position, 0.085),
		"BottomLeft": Vector3(-x_position, -y_position, 0.085),
		"BottomRight": Vector3(x_position, -y_position, 0.085)
	}
	for child_name: String in positions:
		var fastener: MeshInstance3D = group.get_node_or_null(child_name) as MeshInstance3D
		if fastener == null:
			continue
		var direction_x: float = -1.0 if child_name.begins_with("TopLeft") or child_name.begins_with("BottomLeft") else 1.0
		var direction_y: float = 1.0 if child_name.begins_with("Top") else -1.0
		fastener.position = _authored_position(fastener) + Vector3(direction_x * _width_delta(), direction_y * _height_delta(), 0.0)

func _layout_glass(glass: MeshInstance3D) -> void:
	var plane: PlaneMesh = glass.mesh as PlaneMesh
	if plane == null:
		plane = PlaneMesh.new()
		glass.mesh = plane
	plane.size = display_size
	_apply_glass_material(glass)

func _apply_glass_material(glass: MeshInstance3D) -> void:
	if _glass_material == null:
		_glass_material = glass.material_override as ShaderMaterial
	if _glass_material == null:
		_glass_material = ShaderMaterial.new()
		glass.material_override = _glass_material
	_glass_material.shader = GLASS_SHADER
	_glass_material.set_shader_parameter("highlight_opacity", glass_base_opacity)
	_glass_material.set_shader_parameter("reflection_strength", glass_sheen_strength)
	_glass_material.set_shader_parameter("edge_highlight_strength", 0.10)
