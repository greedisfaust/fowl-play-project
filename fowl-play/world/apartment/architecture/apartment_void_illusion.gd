@tool
extends Node3D
class_name ApartmentVoidIllusion

## Creates a gradual black fade at the far (+Z) end of the Apartment hallway.
## Attach to a Node3D under Apartment and keep that node at local origin.
## All generated geometry is local to this node.

@export_group("Hallway")
@export var hallway_center_x: float = -12.75
@export_range(2.0, 6.0, 0.1) var hallway_width: float = 3.5
@export_range(2.0, 6.0, 0.1) var hallway_height: float = 4.0

@export_group("Void Fade")
@export var fade_start_z: float = 4.0
@export var barrier_z: float = 16.7
@export_range(6, 40, 1) var fade_layers: int = 18
@export_range(0.0, 0.5, 0.01) var first_layer_opacity: float = 0.04
@export var generate_collision_barrier: bool = true

@export_group("Generation")
@export var rebuild_illusion: bool = false:
	set(value):
		if value:
			call_deferred("_rebuild_illusion")

const GENERATED_ROOT_NAME: String = "_GeneratedHallwayVoid"

func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild_illusion()

func _rebuild_illusion() -> void:
	if not Engine.is_editor_hint():
		return
	if fade_layers < 1 or barrier_z <= fade_start_z:
		push_warning("ApartmentVoidIllusion: barrier must be beyond the fade start.")
		return
	var scene_root: Node = get_tree().edited_scene_root
	if scene_root == null:
		return
	var old_root: Node = get_node_or_null(GENERATED_ROOT_NAME)
	if old_root != null:
		old_root.free()

	var generated_root: Node3D = Node3D.new()
	generated_root.name = GENERATED_ROOT_NAME
	add_child(generated_root)
	generated_root.owner = scene_root

	var fade_distance: float = barrier_z - fade_start_z
	for layer_index: int in range(fade_layers):
		var progress: float = float(layer_index + 1) / float(fade_layers + 1)
		var layer_z: float = fade_start_z + fade_distance * progress
		var opacity: float = lerpf(first_layer_opacity, 0.88, progress)
		_add_fade_plane(generated_root, "DarknessLayer_" + str(layer_index + 1),
			layer_z, opacity, scene_root)

	# The final plane is completely black, concealing the invisible stop boundary.
	_add_fade_plane(generated_root, "EndlessBlack", barrier_z, 1.0, scene_root)

	if generate_collision_barrier:
		_add_invisible_barrier(generated_root, scene_root)

func _add_fade_plane(parent: Node3D, node_name: String, plane_z: float, opacity: float, scene_root: Node) -> void:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = node_name
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(hallway_width, hallway_height)
	mesh_instance.mesh = quad
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.0, 0.0, 0.0, clampf(opacity, 0.0, 1.0))
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_instance.material_override = material
	mesh_instance.position = Vector3(hallway_center_x, hallway_height * 0.5, plane_z)
	parent.add_child(mesh_instance)
	mesh_instance.owner = scene_root

func _add_invisible_barrier(parent: Node3D, scene_root: Node) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "InvisibleVoidBarrier"
	body.position = Vector3(hallway_center_x, hallway_height * 0.5, barrier_z + 0.12)
	parent.add_child(body)
	body.owner = scene_root
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(hallway_width, hallway_height, 0.25)
	collision.shape = shape
	body.add_child(collision)
	collision.owner = scene_root
