@tool
extends Marker3D
class_name CasinoTableSpawnPoint

## Editor-visible footprint marker for one casino table location.
## Attach to a Marker3D under Casino/Architecture/TableSpawners/SpawnPoints.

@export_group("Table Assignment")
@export var table_id: String = ""
@export var game_id: String = ""
@export var table_scene: PackedScene
@export var enabled: bool = true

@export_group("Preview")
@export var footprint_size: Vector2 = Vector2(3.2, 2.4)
@export var indicator_color: Color = Color(0.20, 0.72, 0.78, 0.20)
@export var outline_color: Color = Color(0.62, 0.39, 0.17, 0.95)
@export var show_indicator: bool = true

const PREVIEW_ROOT_NAME: String = "_TableSpawnPreview"
var _last_footprint_size: Vector2 = Vector2.ZERO
var _last_show_indicator: bool = true
var _last_enabled: bool = true

func _ready() -> void:
	set_process(Engine.is_editor_hint())
	if Engine.is_editor_hint():
		_rebuild_preview()
	else:
		_set_preview_visible(false)

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	if footprint_size != _last_footprint_size or show_indicator != _last_show_indicator or enabled != _last_enabled:
		_rebuild_preview()

func _rebuild_preview() -> void:
	var old_preview: Node = get_node_or_null(PREVIEW_ROOT_NAME)
	if old_preview != null:
		old_preview.free()
	if not show_indicator:
		_cache_preview_settings()
		return

	var preview: Node3D = Node3D.new()
	preview.name = PREVIEW_ROOT_NAME
	add_child(preview)
	var scene_root: Node = get_tree().edited_scene_root
	if scene_root != null:
		preview.owner = scene_root

	var footprint: Vector2 = Vector2(maxf(footprint_size.x, 0.5), maxf(footprint_size.y, 0.5))
	var fill_material: StandardMaterial3D = _make_preview_material(indicator_color, true)
	var line_material: StandardMaterial3D = _make_preview_material(outline_color, false)
	if not enabled:
		fill_material.albedo_color = Color(0.35, 0.35, 0.35, 0.10)
		line_material.albedo_color = Color(0.45, 0.45, 0.45, 0.65)

	var floor_mesh: PlaneMesh = PlaneMesh.new()
	floor_mesh.size = footprint
	var floor_instance: MeshInstance3D = MeshInstance3D.new()
	floor_instance.name = "Footprint"
	floor_instance.mesh = floor_mesh
	floor_instance.position.y = 0.012
	floor_instance.material_override = fill_material
	preview.add_child(floor_instance)
	if scene_root != null:
		floor_instance.owner = scene_root

	var line_height: float = 0.035
	var border_width: float = 0.055
	_add_preview_box(preview, "FrontEdge", Vector3(footprint.x, line_height, border_width), Vector3(0.0, 0.025, -footprint.y * 0.5), line_material, scene_root)
	_add_preview_box(preview, "BackEdge", Vector3(footprint.x, line_height, border_width), Vector3(0.0, 0.025, footprint.y * 0.5), line_material, scene_root)
	_add_preview_box(preview, "LeftEdge", Vector3(border_width, line_height, footprint.y), Vector3(-footprint.x * 0.5, 0.025, 0.0), line_material, scene_root)
	_add_preview_box(preview, "RightEdge", Vector3(border_width, line_height, footprint.y), Vector3(footprint.x * 0.5, 0.025, 0.0), line_material, scene_root)

	var center_mesh: TorusMesh = TorusMesh.new()
	center_mesh.inner_radius = 0.18
	center_mesh.outer_radius = 0.23
	center_mesh.rings = 24
	center_mesh.ring_segments = 8
	var center_instance: MeshInstance3D = MeshInstance3D.new()
	center_instance.name = "CenterOrientationRing"
	center_instance.mesh = center_mesh
	center_instance.position.y = 0.045
	center_instance.material_override = line_material
	preview.add_child(center_instance)
	if scene_root != null:
		center_instance.owner = scene_root

	_cache_preview_settings()

func _add_preview_box(parent: Node3D, node_name: String, size: Vector3, local_position: Vector3, material: Material, scene_root: Node) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = local_position
	instance.material_override = material
	parent.add_child(instance)
	if scene_root != null:
		instance.owner = scene_root

func _make_preview_material(color: Color, transparent: bool) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	else:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.35
	return material

func _set_preview_visible(is_visible: bool) -> void:
	var preview: Node3D = get_node_or_null(PREVIEW_ROOT_NAME) as Node3D
	if preview != null:
		preview.visible = is_visible

func _cache_preview_settings() -> void:
	_last_footprint_size = footprint_size
	_last_show_indicator = show_indicator
	_last_enabled = enabled
