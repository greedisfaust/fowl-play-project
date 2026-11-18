## M0 arena player spawning. Host owns creation/removal and spawn-slot assignment.
## Uses editor-authored nodes and player scene; movement replication belongs to M3.
extends Node3D

const PLAYER_SCENE: PackedScene = preload("res://player/player.tscn")
const TUNING = preload("res://core/tuning.gd")

@onready var players: Node3D = $Players
@onready var spawner: MultiplayerSpawner = $PlayerSpawner
@onready var spawn_points: Node3D = $SpawnPoints
@onready var network: Node = get_node("/root/Network")
@onready var hub: Node = get_node("/root/DebugHub")

var _slots: Dictionary = {}

func _ready() -> void:
	spawner.spawn_function = _create_player
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	network.connect("session_ended", _clear_players)
	network.connect("session_started", _start_players)
	hub.call("watch", &"net/player_count", func() -> int: return players.get_child_count())
	_start_players.call_deferred()

func _exit_tree() -> void:
	if is_instance_valid(hub):
		hub.call("unwatch", &"net/player_count")

func _start_players() -> void:
	if network.get("status") == "offline" or bool(network.get("is_host")):
		_spawn_player(TUNING.PEER_ID_HOST)
		for peer_id: int in multiplayer.get_peers():
			_spawn_player(peer_id)

func _on_peer_connected(peer_id: int) -> void:
	if bool(network.get("is_host")):
		_spawn_player(peer_id)

func _spawn_player(peer_id: int) -> void:
	if not multiplayer.is_server() or players.has_node(str(peer_id)):
		return
	for slot: int in range(mini(spawn_points.get_child_count(), TUNING.MAX_PLAYERS)):
		if not _slots.values().has(slot):
			_slots[peer_id] = slot
			if spawner.spawn({"peer_id": peer_id, "slot": slot}) == null:
				_slots.erase(peer_id)
				hub.call("warn", &"net", "Failed to spawn player %d" % peer_id)
			return
	hub.call("warn", &"net", "No spawn slot for peer %d" % peer_id)

func _create_player(data: Variant) -> Node:
	# MultiplayerSpawner invokes this locally from host-authorized spawn data.
	if not data is Dictionary:
		return null
	var peer_id: int = int(data.get("peer_id", 0))
	var slot: int = int(data.get("slot", -1))
	if peer_id <= 0 or slot < 0 or slot >= spawn_points.get_child_count():
		return null
	var marker: Node3D = spawn_points.get_child(slot) as Node3D
	var player: CharacterBody3D = PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	player.set("input_peer_id", peer_id)
	# Prevent a newly entering remote camera from taking the local camera's place.
	var camera: Camera3D = player.get_node("Head/Camera3D")
	camera.current = false
	player.position = players.to_local(marker.global_position)
	hub.call("log", &"net", "Spawning player %d in slot %d" % [peer_id, slot])
	return player

func _on_peer_disconnected(peer_id: int) -> void:
	if not bool(network.get("is_host")):
		return
	var player: Node = players.get_node_or_null(str(peer_id))
	if player != null:
		player.queue_free()
	_slots.erase(peer_id)
	hub.call("log", &"net", "Despawning player %d" % peer_id)

func _clear_players() -> void:
	for player: Node in players.get_children():
		player.queue_free()
	_slots.clear()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
