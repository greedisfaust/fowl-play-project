## Persistent application root controller.
## World scenes are replaceable children; players and session services remain persistent.
class_name MainController
extends Node3D

const PLAYER_SCENE: PackedScene = preload("res://player/player.tscn")
const TUNING = preload("res://core/tuning.gd")
const PLAYER_COLOR_PANEL_CONTROLLER = preload("res://ui/player_color_panel.gd")

enum World {
	APARTMENT,
	CASINO,
}

signal world_changed(previous_world: int, current_world: int)

@export_group("World Scenes")
@export_enum("Apartment", "Casino") var initial_world: int = World.APARTMENT
@export var apartment_scene: PackedScene
@export var casino_scene: PackedScene

@export_group("Scene References")
@export var world_root_path: NodePath = ^"WorldRoot"
@export var players_path: NodePath = ^"Players"
@export var player_spawner_path: NodePath = ^"MultiplayerSpawner"

@export_group("Transition")
@export_range(0.0, 2.0, 0.05) var fade_duration_seconds: float = 0.35
@export var fade_color: Color = Color.BLACK

var active_world: int = World.APARTMENT
var active_world_instance: Node3D = null
var _has_active_world: bool = false
var _transition_in_progress: bool = false

var _world_root: Node3D
var _players: Node3D
var _player_spawner: MultiplayerSpawner
var _network: Node
var _debug_hub: Node
var _transition_layer: CanvasLayer
var _fade_rect: ColorRect
## Stable peer-to-spawn-marker assignment, mirrored by MultiplayerSpawner spawn data.
var _spawn_slots: Dictionary = {}


func _ready() -> void:
	_world_root = get_node_or_null(world_root_path) as Node3D
	_players = get_node_or_null(players_path) as Node3D
	_player_spawner = get_node_or_null(player_spawner_path) as MultiplayerSpawner
	_network = get_node_or_null("/root/Network")
	_debug_hub = get_node_or_null("/root/DebugHub")

	if _world_root == null or _players == null or _player_spawner == null:
		push_error("MainController requires WorldRoot, Players, and MultiplayerSpawner nodes.")
		return
	if _network == null:
		push_error("MainController requires the Network autoload.")
		return
	var run_manager: Node = get_node_or_null("/root/RunManager")
	if run_manager != null and run_manager.has_method("bind_main_controller"):
		run_manager.call("bind_main_controller", self)

	_player_spawner.spawn_path = _player_spawner.get_path_to(_players)
	_player_spawner.spawn_limit = TUNING.MAX_PLAYERS
	_player_spawner.spawn_function = _create_player
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if not _network.is_connected("session_started", _on_session_started):
		_network.connect("session_started", _on_session_started)
	if not _network.is_connected("session_ended", _on_session_ended):
		_network.connect("session_ended", _on_session_ended)

	if _debug_hub != null:
		_debug_hub.call("watch", &"net/player_count", func() -> int: return _players.get_child_count())

	_create_transition_overlay()
	var initial_scene: PackedScene = _get_scene_for_world(initial_world)
	if initial_scene == null:
		push_warning("MainController has no Initial World scene assigned yet; player spawning will wait for a world.")
		return

	_install_world(initial_world, initial_scene)
	_refresh_players_for_world.call_deferred()


func _exit_tree() -> void:
	if is_instance_valid(_debug_hub):
		_debug_hub.call("unwatch", &"net/player_count")


## Validates a destination before a departure sequence starts.
func can_transition_to(destination: int) -> bool:
	if destination < World.APARTMENT or destination > World.CASINO:
		return false
	if _transition_in_progress or (_has_active_world and active_world == destination):
		return false
	return _get_scene_for_world(destination) != null


## Called by the host when the team moves to another world.
## Every peer receives the same world ID and loads its local copy of that scene.
func transition_to(destination: int) -> void:
	if destination < World.APARTMENT or destination > World.CASINO:
		push_warning("Rejected invalid world transition ID: %d" % destination)
		return
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

	rpc("_rpc_transition_to", destination)


@rpc("authority", "call_local", "reliable")
func _rpc_transition_to(destination: int) -> void:
	if destination < World.APARTMENT or destination > World.CASINO:
		push_warning("Rejected invalid world transition ID: %d" % destination)
		return

	var destination_scene: PackedScene = _get_scene_for_world(destination)
	if destination_scene == null:
		push_error("A peer is missing the PackedScene for %s." % _world_name(destination))
		return

	await _perform_transition(destination, destination_scene)


func get_active_world() -> Node3D:
	return active_world_instance


func _get_scene_for_world(world: int) -> PackedScene:
	match world:
		World.APARTMENT:
			return apartment_scene
		World.CASINO:
			return casino_scene
	return null


func _install_world(world: int, packed_scene: PackedScene) -> bool:
	var instance: Node = packed_scene.instantiate()
	var world_instance: Node3D = instance as Node3D
	if world_instance == null:
		instance.free()
		push_error("World scenes must have a Node3D root.")
		return false

	world_instance.name = _world_name(world)
	_install_lobby_device_controllers(world_instance)
	_world_root.add_child(world_instance)

	var previous_world: int = active_world if _has_active_world else -1
	active_world = world
	active_world_instance = world_instance
	_has_active_world = true
	world_changed.emit(previous_world, active_world)
	_refresh_players_for_world()
	return true



## The Apartment scene already authors a dedicated ColorPanelController node.
## Attach its behavior here so the authored button hierarchy remains untouched.
func _install_lobby_device_controllers(world_instance: Node3D) -> void:
	if world_instance == null or world_instance.name != "Apartment":
		return
	var lobby_devices: Node = world_instance.get_node_or_null("LobbyDevices")
	if not is_instance_valid(lobby_devices):
		push_warning("Apartment is missing LobbyDevices; lobby color selection will not be installed.")
		return
	var player_color_panel: Node = lobby_devices.get_node_or_null("PlayerColorPanel")
	if not is_instance_valid(player_color_panel):
		push_warning("Apartment LobbyDevices is missing PlayerColorPanel.")
		return
	var color_panel_controller: Node = player_color_panel.get_node_or_null("ColorPanelController")
	if not is_instance_valid(color_panel_controller):
		push_warning("PlayerColorPanel is missing its ColorPanelController node.")
		return
	color_panel_controller.set_script(PLAYER_COLOR_PANEL_CONTROLLER)
	if is_instance_valid(_debug_hub):
		_debug_hub.call("log", &"net", "Installed host-authoritative PlayerColorPanel controller.")

func _perform_transition(destination: int, packed_scene: PackedScene) -> void:
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
	_install_lobby_device_controllers(next_world)
	_world_root.add_child(next_world)

	var previous_world: int = active_world if _has_active_world else -1
	active_world = destination
	active_world_instance = next_world
	_has_active_world = true
	world_changed.emit(previous_world, active_world)
	_refresh_players_for_world()

	await _fade_to(0.0)
	_transition_in_progress = false


## The world owns only its spawn markers. Main owns every player instance.
func _refresh_players_for_world() -> void:
	if not _has_active_world or not is_instance_valid(_players):
		return
	var spawn_points: Node3D = _get_player_spawn_points()
	if spawn_points == null:
		push_warning("World %s has no populated player spawn container. Checked SpawnPoints, LobbySpawnPoints, and PlayerSpawnPoints." % active_world_instance.name)
		return

	_place_existing_players(spawn_points)
	_spawn_connected_players(spawn_points)


## World scenes use different authored names for player spawn markers.
## Ignore empty placeholder containers and select the first populated marker group.
func _get_player_spawn_points() -> Node3D:
	if not _has_active_world or not is_instance_valid(active_world_instance):
		return null
	var candidate_names: PackedStringArray = PackedStringArray([
		"SpawnPoints",
		"LobbySpawnPoints",
		"PlayerSpawnPoints"
	])
	for candidate_name: String in candidate_names:
		var candidate: Node3D = active_world_instance.get_node_or_null(candidate_name) as Node3D
		if _count_spawn_markers(candidate) > 0:
			return candidate
	return null


func _count_spawn_markers(spawn_points: Node3D) -> int:
	if spawn_points == null:
		return 0
	var marker_count: int = 0
	for child: Node in spawn_points.get_children():
		if child is Marker3D:
			marker_count += 1
	return marker_count


func _place_existing_players(spawn_points: Node3D) -> void:
	for player: Node in _players.get_children():
		var peer_id: int = int(str(player.name))
		var slot: int = int(_spawn_slots.get(peer_id, -1))
		var marker: Marker3D = _get_spawn_marker(spawn_points, slot)
		if marker == null:
			push_warning("No matching spawn marker for existing player %d in %s." % [peer_id, active_world_instance.name])
			continue
		if bool(player.get("is_limp")) or bool(player.get("is_recovering")):
			push_warning("Player %d is ragdolled/recovering; world placement waits for the elevator reset step." % peer_id)
			continue
		if player.has_method("is_carried") and bool(player.call("is_carried")):
			push_warning("Player %d is being carried; world placement waits for the elevator reset step." % peer_id)
			continue
		if player.has_method("is_carrying") and bool(player.call("is_carrying")):
			push_warning("Player %d is carrying an item; world placement waits for the elevator reset step." % peer_id)
			continue
		if player.has_method("place_at_world_spawn"):
			player.call("place_at_world_spawn", marker.global_transform)
		else:
			player.global_transform = marker.global_transform


func _spawn_connected_players(spawn_points: Node3D) -> void:
	if not _can_spawn_players():
		return
	_spawn_player(TUNING.PEER_ID_HOST, spawn_points)
	for peer_id: int in multiplayer.get_peers():
		_spawn_player(peer_id, spawn_points)


func _can_spawn_players() -> bool:
	if _network == null:
		return false
	# A disconnected session still uses OfflineMultiplayerPeer. Allow the local
	# player to respawn after leaving a host/client session instead of requiring
	# the Network status string to be the initial "offline" value.
	var active_peer: MultiplayerPeer = multiplayer.multiplayer_peer
	return active_peer is OfflineMultiplayerPeer or bool(_network.get("is_host"))


func _on_session_started() -> void:
	_refresh_players_for_world.call_deferred()


func _on_session_ended() -> void:
	for player: Node in _players.get_children():
		player.queue_free()
	_spawn_slots.clear()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var run_manager: Node = get_node_or_null("/root/RunManager")
	if is_instance_valid(run_manager) and run_manager.has_method("reset_for_session_end"):
		run_manager.call("reset_for_session_end")
	_restore_local_player_after_session_end.call_deferred()


## Network shutdown clears replicated players on every peer. Once queued deletion has
## completed, restore this instance's local player for offline Apartment play.
func _restore_local_player_after_session_end() -> void:
	# shutdown() is also used internally while starting a host/client session.
	# In that case MultiplayerSpawner must own the incoming player instances;
	# restoring the temporary offline peer here can create a duplicate child
	# (usually Players/1) before the host's replicated spawn arrives.
	if not is_instance_valid(_network) or bool(_network.get("_switching_session")):
		return
	await get_tree().process_frame
	if not is_instance_valid(_network) or bool(_network.get("_switching_session")):
		return
	var active_peer: MultiplayerPeer = multiplayer.multiplayer_peer
	if not active_peer is OfflineMultiplayerPeer:
		return
	_refresh_players_for_world()


func _on_peer_connected(peer_id: int) -> void:
	if not _can_spawn_players() or not _has_active_world:
		return
	var spawn_points: Node3D = _get_player_spawn_points()
	_spawn_player.call_deferred(peer_id, spawn_points)


func _on_peer_disconnected(peer_id: int) -> void:
	_spawn_slots.erase(peer_id)
	if not bool(_network.get("is_host")):
		return
	var player: Node = _players.get_node_or_null(str(peer_id))
	if player != null:
		player.queue_free()
	if _debug_hub != null:
		_debug_hub.call("log", &"net", "Despawning player %d from persistent Main." % peer_id)


func _spawn_player(peer_id: int, spawn_points: Node3D) -> void:
	if peer_id <= 0 or _players.has_node(str(peer_id)):
		return
	if spawn_points == null:
		return
	var slot: int = _find_available_spawn_slot(_count_spawn_markers(spawn_points))
	if slot < 0:
		if _debug_hub != null:
			_debug_hub.call("warn", &"net", "No spawn slot available for peer %d." % peer_id)
		return
	_spawn_slots[peer_id] = slot
	if _player_spawner.spawn({"peer_id": peer_id, "slot": slot}) == null:
		_spawn_slots.erase(peer_id)
		if _debug_hub != null:
			_debug_hub.call("warn", &"net", "Failed to spawn player %d." % peer_id)


func _find_available_spawn_slot(spawn_count: int) -> int:
	for slot: int in range(mini(spawn_count, TUNING.MAX_PLAYERS)):
		if not _spawn_slots.values().has(slot):
			return slot
	return -1


func _create_player(data: Variant) -> Node:
	if not data is Dictionary:
		return null
	var spawn_data: Dictionary = data
	var peer_id: int = int(spawn_data.get("peer_id", 0))
	var slot: int = int(spawn_data.get("slot", -1))
	if peer_id <= 0:
		return null
	var spawn_points: Node3D = _get_player_spawn_points()
	var marker: Marker3D = _get_spawn_marker(spawn_points, slot)
	if marker == null:
		push_warning("Rejected player spawn for peer %d: invalid spawn slot %d." % [peer_id, slot])
		return null

	var player: CharacterBody3D = PLAYER_SCENE.instantiate() as CharacterBody3D
	if player == null:
		push_error("Player scene root must be CharacterBody3D.")
		return null
	player.name = str(peer_id)
	player.set("input_peer_id", peer_id)
	player.transform = _players.global_transform.affine_inverse() * marker.global_transform
	_spawn_slots[peer_id] = slot
	return player


func _get_spawn_marker(spawn_points: Node3D, slot: int) -> Marker3D:
	if spawn_points == null or slot < 0:
		return null
	var marker_index: int = 0
	for child: Node in spawn_points.get_children():
		var marker: Marker3D = child as Marker3D
		if marker == null:
			continue
		if marker_index == slot:
			return marker
		marker_index += 1
	return null


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


func _world_name(world: int) -> String:
	match world:
		World.APARTMENT:
			return "Apartment"
		World.CASINO:
			return "Casino"
	return "UnknownWorld"
