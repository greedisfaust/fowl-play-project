## Persistent application root controller.
## World scenes are replaceable children; session services remain in autoloads.
extends Node3D

enum World {
	APARTMENT,
	CASINO,
	REST_AREA,
}

signal world_changed(previous_world: int, current_world: int)

@export_group("World Scenes")
@export var initial_world: World = World.APARTMENT
@export var apartment_scene: PackedScene
@export var casino_scene: PackedScene
@export var rest_area_scene: PackedScene

@export_group("Scene References")
@export var world_root_path: NodePath = ^"WorldRoot"

@export_group("Transition")
@export_range(0.0, 2.0, 0.05) var fade_duration_seconds: float = 0.35
@export var fade_color: Color = Color.BLACK

var active_world: World = World.APARTMENT
var active_world_instance: Node3D = null
var _has_active_world: bool = false
var _transition_in_progress: bool = false

var _world_root: Node3D
var _transition_layer: CanvasLayer
var _fade_rect: ColorRect


func _ready() -> void:
	_world_root = get_node_or_null(world_root_path) as Node3D
	if _world_root == null:
		push_error("MainController requires a Node3D at WorldRoot.")
		return

	_create_transition_overlay()
	var initial_scene: PackedScene = _get_scene_for_world(initial_world)
	if initial_scene == null:
		push_warning("MainController has no Initial World scene assigned yet.")
		return

	_install_world(initial_world, initial_scene)


## Called by the host when the team moves to another world.
## Every peer receives the same world ID and loads its local copy of that scene.
func transition_to(destination: World) -> void:
	if _transition_in_progress:
		return
	if _has_active_world and active_world == destination:
		return

	var destination_scene: PackedScene = _get_scene_for_world(destination)
	if destination_scene == null:
		push_warning("No PackedScene is assigned for world %s." % _world_name(destination))
		return

	var network_peer: MultiplayerPeer = multiplayer.multiplayer_peer
	if network_peer is OfflineMultiplayerPeer:
		await _perform_transition(destination, destination_scene)
		return

	if not multiplayer.is_server():
		push_warning("Only the host may request a world transition.")
		return

	rpc("_rpc_transition_to", int(destination))


@rpc("authority", "call_local", "reliable")
func _rpc_transition_to(destination_value: int) -> void:
	if destination_value < World.APARTMENT or destination_value > World.REST_AREA:
		push_warning("Rejected invalid world transition ID: %d" % destination_value)
		return

	var destination: World = destination_value
	var destination_scene: PackedScene = _get_scene_for_world(destination)
	if destination_scene == null:
		push_error("A peer is missing the PackedScene for %s." % _world_name(destination))
		return

	await _perform_transition(destination, destination_scene)


func get_active_world() -> Node3D:
	return active_world_instance


func _get_scene_for_world(world: World) -> PackedScene:
	match world:
		World.APARTMENT:
			return apartment_scene
		World.CASINO:
			return casino_scene
		World.REST_AREA:
			return rest_area_scene
	return null


func _install_world(world: World, packed_scene: PackedScene) -> bool:
	var instance: Node = packed_scene.instantiate()
	var world_instance: Node3D = instance as Node3D
	if world_instance == null:
		instance.free()
		push_error("World scenes must have a Node3D root.")
		return false

	world_instance.name = _world_name(world)
	_world_root.add_child(world_instance)

	var previous_world: int = int(active_world) if _has_active_world else -1
	active_world = world
	active_world_instance = world_instance
	_has_active_world = true
	world_changed.emit(previous_world, int(active_world))
	return true


func _perform_transition(destination: World, packed_scene: PackedScene) -> void:
	if _transition_in_progress:
		return

	var instance: Node = packed_scene.instantiate()
	var next_world: Node3D = instance as Node3D
	if next_world == null:
		instance.free()
		push_error("World scenes must have a Node3D root.")
		return

	_transition_in_progress = true
	await _fade_to(1.0)

	if _has_active_world and is_instance_valid(active_world_instance):
		_world_root.remove_child(active_world_instance)
		active_world_instance.queue_free()
		active_world_instance = null

	next_world.name = _world_name(destination)
	_world_root.add_child(next_world)

	var previous_world: int = int(active_world) if _has_active_world else -1
	active_world = destination
	active_world_instance = next_world
	_has_active_world = true
	world_changed.emit(previous_world, int(active_world))

	await _fade_to(0.0)
	_transition_in_progress = false


func _create_transition_overlay() -> void:
	_transition_layer = CanvasLayer.new()
	_transition_layer.name = "WorldTransitionOverlay"
	_transition_layer.layer = 100
	add_child(_transition_layer)

	_fade_rect = ColorRect.new()
	_fade_rect.name = "Fade"
	_fade_rect.color = Color(fade_color.r, fade_color.g, fade_color.b, 0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_transition_layer.add_child(_fade_rect)


func _fade_to(alpha: float) -> void:
	if fade_duration_seconds <= 0.0:
		_fade_rect.color = Color(fade_color.r, fade_color.g, fade_color.b, alpha)
		return

	var target_color: Color = Color(fade_color.r, fade_color.g, fade_color.b, alpha)
	var tween: Tween = create_tween()
	tween.tween_property(_fade_rect, "color", target_color, fade_duration_seconds)
	await tween.finished


func _world_name(world: World) -> String:
	match world:
		World.APARTMENT:
			return "Apartment"
		World.CASINO:
			return "Casino"
		World.REST_AREA:
			return "RestArea"
	return "UnknownWorld"
