## Responsive controller for the editor-authored AURELION S-01 SLIM housing.
@tool
class_name SlimWorldScreen
extends Node3D

const GLASS_SHADER: Shader = preload("res://environment/kit/world_screen_glass.gdshader")

@export_group("Display")
@export var display_size: Vector2 = Vector2(2.0, 1.125):
	set(value):
		display_size = Vector2(maxf(value.x, 0.1), maxf(value.y, 0.1))
		_apply_configuration()

@export_group("Glass Finish")
@export_range(0.0, 0.2, 0.005) var glass_base_opacity: float = 0.035:
	set(value):
		glass_base_opacity = clampf(value, 0.0, 0.2)
		_apply_configuration()
@export_range(0.0, 1.0, 0.01) var glass_sheen_strength: float = 0.55:
	set(value):
		glass_sheen_strength = clampf(value, 0.0, 1.0)
		_apply_configuration()
@export_range(0.0, 1.0, 0.01) var glass_edge_strength: float = 0.28:
	set(value):
		glass_edge_strength = clampf(value, 0.0, 1.0)
		_apply_configuration()

var _glass_material: ShaderMaterial
var _warning_sent: bool = false
var _authored_positions: Dictionary = {}
var _layout_initialized: bool = false

## Cache authored local positions by node identity, not absolute scene path.
## Absolute paths change when this scene is instanced under a different parent
## or the instance is reparented; node references remain stable for this instance.
## Capture canonical positions from the original housing scene, not from this
## instance. Parent scenes serialize @tool-edited child transforms as overrides;
## using those values as a fresh baseline applies the resize offset twice.
func _capture_authored_positions(node: Node) -> void:
	_authored_positions.clear()
	var scene_path: String = "res://environment/kit/slim_world_screen.tscn"
	var packed_scene: PackedScene = load(scene_path) as PackedScene
	if packed_scene == null:
		push_warning("Could not load canonical screen scene for resize baselines: %s" % scene_path)
		_capture_current_positions(node)
		return
	var baseline_root: Node = packed_scene.instantiate()
	_capture_positions_from_baseline(node, baseline_root)
	baseline_root.free()

func _capture_positions_from_baseline(current_node: Node, baseline_node: Node) -> void:
	if current_node is Node3D and baseline_node is Node3D:
		var current_spatial: Node3D = current_node as Node3D
		var baseline_spatial: Node3D = baseline_node as Node3D
		_authored_positions[current_spatial] = baseline_spatial.position
	for child: Node in current_node.get_children():
		var relative_path: NodePath = current_node.get_path_to(child)
		var baseline_child: Node = baseline_node.get_node_or_null(relative_path)
		if baseline_child != null:
			_capture_positions_from_baseline(child, baseline_child)
		else:
			_capture_current_positions(child)

func _capture_current_positions(node: Node) -> void:
	if node is Node3D:
		var spatial: Node3D = node as Node3D
		_authored_positions[spatial] = spatial.position
	for child: Node in node.get_children():
		_capture_current_positions(child)

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
	# The nested WorldScreen localizes its own resources. Localize housing resources
	# here so resizing one placed terminal cannot resize another instance's meshes.
	_make_housing_resources_local(get_node_or_null("Chassis"))
	_make_housing_resources_local(get_node_or_null("Glass"))
	_capture_authored_positions(self)
	_layout_initialized = true
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
		push_warning("SlimWorldScreen expects WorldScreen, Chassis, and Glass as direct children.")
		_warning_sent = true

func _half_width() -> float:
	return display_size.x * 0.5

func _half_height() -> float:
	return display_size.y * 0.5

func _set_box(node: Node, size: Vector3) -> void:
	var instance: MeshInstance3D = node as MeshInstance3D
	if instance == null:
		return
	var box: BoxMesh = instance.mesh as BoxMesh
	if box == null:
		box = BoxMesh.new()
		instance.mesh = box
	box.size = size

func _layout_chassis(chassis: Node3D) -> void:
	var body: MeshInstance3D = chassis.get_node_or_null("MainBody") as MeshInstance3D
	if body != null:
		_set_box(body, Vector3(display_size.x + 0.42, display_size.y + 0.295, 0.14))
		body.position = _authored_position(body)

	var bezel: Node3D = chassis.get_node_or_null("Bezel") as Node3D
	if bezel != null:
		bezel.position = _authored_position(bezel)
		_set_box(bezel.get_node_or_null("TopRail"), Vector3(display_size.x + 0.18, 0.065, 0.055))
		_set_box(bezel.get_node_or_null("BottomRail"), Vector3(display_size.x + 0.18, 0.065, 0.055))
		_set_box(bezel.get_node_or_null("LeftRail"), Vector3(0.065, display_size.y - 0.005, 0.055))
		_set_box(bezel.get_node_or_null("RightRail"), Vector3(0.065, display_size.y - 0.005, 0.055))
		var top: MeshInstance3D = bezel.get_node_or_null("TopRail") as MeshInstance3D
		var bottom: MeshInstance3D = bezel.get_node_or_null("BottomRail") as MeshInstance3D
		var left: MeshInstance3D = bezel.get_node_or_null("LeftRail") as MeshInstance3D
		var right: MeshInstance3D = bezel.get_node_or_null("RightRail") as MeshInstance3D
		if top != null:
			top.position = _authored_position(top) + Vector3(0.0, _height_delta(), 0.0)
		if bottom != null:
			bottom.position = _authored_position(bottom) + Vector3(0.0, -_height_delta(), 0.0)
		if left != null:
			left.position = _authored_position(left) + Vector3(-_width_delta(), 0.0, 0.0)
		if right != null:
			right.position = _authored_position(right) + Vector3(_width_delta(), 0.0, 0.0)

	var armor: Node3D = chassis.get_node_or_null("OuterArmor") as Node3D
	if armor != null:
		armor.position = _authored_position(armor)
		_set_box(armor.get_node_or_null("TopArmor"), Vector3(display_size.x + 0.34, 0.09, 0.08))
		_set_box(armor.get_node_or_null("BottomArmor"), Vector3(display_size.x + 0.34, 0.09, 0.08))
		_set_box(armor.get_node_or_null("LeftArmor"), Vector3(0.09, display_size.y + 0.105, 0.08))
		_set_box(armor.get_node_or_null("RightArmor"), Vector3(0.09, display_size.y + 0.105, 0.08))
		var top_armor: MeshInstance3D = armor.get_node_or_null("TopArmor") as MeshInstance3D
		var bottom_armor: MeshInstance3D = armor.get_node_or_null("BottomArmor") as MeshInstance3D
		var left_armor: MeshInstance3D = armor.get_node_or_null("LeftArmor") as MeshInstance3D
		var right_armor: MeshInstance3D = armor.get_node_or_null("RightArmor") as MeshInstance3D
		if top_armor != null:
			top_armor.position = _authored_position(top_armor) + Vector3(0.0, _height_delta(), 0.0)
		if bottom_armor != null:
			bottom_armor.position = _authored_position(bottom_armor) + Vector3(0.0, -_height_delta(), 0.0)
		if left_armor != null:
			left_armor.position = _authored_position(left_armor) + Vector3(-_width_delta(), 0.0, 0.0)
		if right_armor != null:
			right_armor.position = _authored_position(right_armor) + Vector3(_width_delta(), 0.0, 0.0)
		var corners: Node3D = armor.get_node_or_null("CornerArmor") as Node3D
		if corners != null:
			var cx: float = _half_width() + 0.17
			var cy: float = _half_height() - 0.0425
			var positions: Dictionary = {
				"TopLeft": Vector3(-cx, cy, 0.105),
				"TopRight": Vector3(cx, cy, 0.105),
				"BottomLeft": Vector3(-cx, -cy, 0.105),
				"BottomRight": Vector3(cx, -cy, 0.105)
			}
			for piece_name: String in positions:
				var piece: Node3D = corners.get_node_or_null(piece_name) as Node3D
				if piece == null:
					continue
				var direction_x: float = -1.0 if piece_name.ends_with("Left") else 1.0
				var direction_y: float = 1.0 if piece_name.begins_with("Top") else -1.0
				piece.position = _authored_position(piece) + Vector3(direction_x * _width_delta(), direction_y * _height_delta(), 0.0)

	var channels: Node3D = chassis.get_node_or_null("LightChannels") as Node3D
	if channels != null:
		_set_box(channels.get_node_or_null("TopChannel"), Vector3(display_size.x * 0.725, 0.018, 0.012))
		_set_box(channels.get_node_or_null("BottomChannel"), Vector3(display_size.x * 0.725, 0.018, 0.012))
		_set_box(channels.get_node_or_null("LeftChannel"), Vector3(0.018, display_size.y * 0.8, 0.012))
		_set_box(channels.get_node_or_null("RightChannel"), Vector3(0.018, display_size.y * 0.8, 0.012))
		var top_channel: MeshInstance3D = channels.get_node_or_null("TopChannel") as MeshInstance3D
		var bottom_channel: MeshInstance3D = channels.get_node_or_null("BottomChannel") as MeshInstance3D
		var left_channel: MeshInstance3D = channels.get_node_or_null("LeftChannel") as MeshInstance3D
		var right_channel: MeshInstance3D = channels.get_node_or_null("RightChannel") as MeshInstance3D
		if top_channel != null:
			top_channel.position = _authored_position(top_channel) + Vector3(0.0, _height_delta(), 0.0)
		if bottom_channel != null:
			bottom_channel.position = _authored_position(bottom_channel) + Vector3(0.0, -_height_delta(), 0.0)
		if left_channel != null:
			left_channel.position = _authored_position(left_channel) + Vector3(-_width_delta(), 0.0, 0.0)
		if right_channel != null:
			right_channel.position = _authored_position(right_channel) + Vector3(_width_delta(), 0.0, 0.0)

	var fasteners: Node3D = chassis.get_node_or_null("Fasteners") as Node3D
	if fasteners != null:
		var fx: float = _half_width() + 0.12
		var fy: float = _half_height() - 0.0925
		var positions: Dictionary = {
			"TopLeftFastener": Vector3(-fx, fy, 0.17),
			"TopRightFastener": Vector3(fx, fy, 0.17),
			"BottomLeftFastener": Vector3(-fx, -fy, 0.17),
			"BottomRightFastener": Vector3(fx, -fy, 0.17)
		}
		for fastener_name: String in positions:
			var fastener: MeshInstance3D = fasteners.get_node_or_null(fastener_name) as MeshInstance3D
			if fastener != null:
				var direction_x: float = -1.0 if fastener_name.begins_with("TopLeft") or fastener_name.begins_with("BottomLeft") else 1.0
				var direction_y: float = 1.0 if fastener_name.begins_with("Top") else -1.0
				fastener.position = _authored_position(fastener) + Vector3(direction_x * _width_delta(), direction_y * _height_delta(), 0.0)

	var plate_group: Node3D = chassis.get_node_or_null("IdentificationPlate") as Node3D
	if plate_group != null:
		plate_group.position = _authored_position(plate_group)
		var plate: MeshInstance3D = plate_group.get_node_or_null("PlateMesh") as MeshInstance3D
		if plate != null:
			_set_box(plate, Vector3(0.62, 0.085, 0.018))
			plate.position = _authored_position(plate) + Vector3(0.0, -_height_delta(), 0.0)
		var text_mesh: MeshInstance3D = plate_group.get_node_or_null("EngravedText") as MeshInstance3D
		if text_mesh != null:
			text_mesh.position = _authored_position(text_mesh) + Vector3(0.0, -_height_delta(), 0.0)

	var side_details: Node3D = chassis.get_node_or_null("SideDetails") as Node3D
	if side_details != null:
		_layout_vent_group(side_details.get_node_or_null("LeftVent") as Node3D, -(_half_width() + 0.17))
		_layout_vent_group(side_details.get_node_or_null("RightVent") as Node3D, _half_width() + 0.17)

	var control: Node3D = chassis.get_node_or_null("ControlPanel") as Node3D
	if control != null:
		var panel_y: float = -_half_height() - 0.1025
		var panel_body: MeshInstance3D = control.get_node_or_null("PanelBody") as MeshInstance3D
		if panel_body != null:
			_set_box(panel_body, Vector3(0.42, 0.16, 0.035))
			panel_body.position = _authored_position(panel_body) + Vector3(0.0, -_height_delta(), 0.0)
		var indicators: Node3D = control.get_node_or_null("IndicatorGroup") as Node3D
		if indicators != null:
			indicators.position = _authored_position(indicators) + Vector3(0.0, -_height_delta(), 0.0)

func _layout_vent_group(group: Node3D, x_position: float) -> void:
	if group == null:
		return
	group.position = _authored_position(group) + Vector3(signf(x_position) * _width_delta(), 0.0, 0.0)
	var index: int = 0
	for child: Node in group.get_children():
		var vent: MeshInstance3D = child as MeshInstance3D
		if vent == null:
			continue
		_set_box(vent, Vector3(0.025, 0.10, 0.012))
		# Preserve the five vent transforms authored in the scene.

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
	_glass_material.set_shader_parameter("edge_highlight_strength", glass_edge_strength)
