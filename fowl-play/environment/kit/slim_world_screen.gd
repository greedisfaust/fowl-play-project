## Responsive physical housing for the reusable WorldScreen display.
@tool
class_name SlimWorldScreen
extends Node3D

const GLASS_SHADER: Shader = preload("res://environment/kit/slim_world_screen_glass.gdshader")

@export_group("Dimensions")
@export var display_size: Vector2 = Vector2(2.0, 1.125):
	set(value):
		display_size = Vector2(maxf(value.x, 0.1), maxf(value.y, 0.1))
		_apply_configuration()

@export_range(0.02, 0.2, 0.005) var bezel_thickness: float = 0.08:
	set(value):
		bezel_thickness = clampf(value, 0.02, 0.2)
		_apply_configuration()

@export_range(0.04, 0.3, 0.005) var housing_depth: float = 0.10:
	set(value):
		housing_depth = clampf(value, 0.04, 0.3)
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
var _warning_sent: bool = false

func _ready() -> void:
	_apply_configuration()

func _apply_configuration() -> void:
	if not is_inside_tree():
		return

	var screen: WorldScreen = get_node_or_null("WorldScreen") as WorldScreen
	var housing: MeshInstance3D = get_node_or_null("Housing") as MeshInstance3D
	var bezel: Node3D = get_node_or_null("Bezel") as Node3D
	var glass: MeshInstance3D = get_node_or_null("Glass") as MeshInstance3D

	if screen != null:
		screen.set_display_size(display_size)

	if housing != null:
		_set_box_mesh(housing, Vector3(display_size.x + bezel_thickness * 2.0, display_size.y + bezel_thickness * 2.0, housing_depth))
		housing.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		housing.position = Vector3(0.0, 0.0, -housing_depth * 0.5 - 0.005)

	if bezel != null:
		bezel.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		_layout_bezel(bezel)

	if glass != null:
		_set_plane_mesh(glass, display_size)
		glass.rotation_degrees = Vector3.ZERO
		glass.position = Vector3(0.0, 0.0, 0.012)
		_apply_glass_material(glass)

	if (screen == null or housing == null or bezel == null or glass == null) and not _warning_sent:
		push_warning("SlimWorldScreen expects WorldScreen, Housing, Bezel, and Glass children. Check the editor-authored scene hierarchy.")
		_warning_sent = true

func _set_box_mesh(instance: MeshInstance3D, size: Vector3) -> void:
	var box: BoxMesh = instance.mesh as BoxMesh
	if box == null:
		box = BoxMesh.new()
		instance.mesh = box
	box.size = size

func _set_plane_mesh(instance: MeshInstance3D, size: Vector2) -> void:
	var plane: PlaneMesh = instance.mesh as PlaneMesh
	if plane == null:
		plane = PlaneMesh.new()
		instance.mesh = plane
	plane.size = size

func _layout_bezel(bezel: Node3D) -> void:
	var half_width: float = display_size.x * 0.5
	var half_height: float = display_size.y * 0.5
	var half_frame: float = bezel_thickness * 0.5
	var top: MeshInstance3D = bezel.get_node_or_null("Top") as MeshInstance3D
	var bottom: MeshInstance3D = bezel.get_node_or_null("Bottom") as MeshInstance3D
	var left: MeshInstance3D = bezel.get_node_or_null("Left") as MeshInstance3D
	var right: MeshInstance3D = bezel.get_node_or_null("Right") as MeshInstance3D

	_set_bezel_piece(top, Vector3(display_size.x + bezel_thickness * 2.0, bezel_thickness, 0.025), Vector3(0.0, half_height + half_frame, 0.008))
	_set_bezel_piece(bottom, Vector3(display_size.x + bezel_thickness * 2.0, bezel_thickness, 0.025), Vector3(0.0, -half_height - half_frame, 0.008))
	_set_bezel_piece(left, Vector3(bezel_thickness, display_size.y, 0.025), Vector3(-half_width - half_frame, 0.0, 0.008))
	_set_bezel_piece(right, Vector3(bezel_thickness, display_size.y, 0.025), Vector3(half_width + half_frame, 0.0, 0.008))

func _set_bezel_piece(piece: MeshInstance3D, size: Vector3, local_position: Vector3) -> void:
	if piece == null:
		return
	_set_box_mesh(piece, size)
	piece.position = local_position

func _apply_glass_material(glass: MeshInstance3D) -> void:
	if _glass_material == null:
		_glass_material = glass.material_override as ShaderMaterial
	if _glass_material == null:
		_glass_material = ShaderMaterial.new()
		glass.material_override = _glass_material
	_glass_material.shader = GLASS_SHADER
	_glass_material.set_shader_parameter("base_opacity", glass_base_opacity)
	_glass_material.set_shader_parameter("sheen_strength", glass_sheen_strength)
	_glass_material.set_shader_parameter("near_distance", glass_sheen_near_distance)
	_glass_material.set_shader_parameter("far_distance", glass_sheen_far_distance)
