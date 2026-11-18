## Shared host validation and real focus-command checks against the saved arena.
extends SceneTree

var failed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: PackedScene = load("res://arena/test_arena.tscn")
	var arena: Node3D = scene.instantiate()
	root.add_child(arena)
	await process_frame
	await physics_frame
	var network: Node = root.get_node("Network")
	var actor: CharacterBody3D = arena.get_node("Players").get_child(0) as CharacterBody3D
	actor.set_physics_process(false)
	actor.global_position = Vector3(-3, 0.6, -4)
	var device: Node3D = arena.get_node("TestUseDevice")
	var target: Interactable = device.get_node("Interactable")
	var camera: Camera3D = actor.get_node("Head/Camera3D")
	camera.look_at(device.global_position)
	await physics_frame
	var hub: Node = root.get_node("DebugHub")
	hub.call("execute_command", StringName("interact_use_%s" % actor.name), [])
	check(bool(device.get("is_active")), "Local focus command must use shared host path")
	check(int(network.get("interaction_accepted")) == 1, "Host acceptance watch")
	check(network.call("_interaction_rejection", actor, target, &"grab") != "", "USE target must reject GRAB")
	target.enabled = false
	check(network.call("_interaction_rejection", actor, target, &"use") != "", "Disabled target")
	target.enabled = true
	check(network.call("_interaction_rejection", null, target, &"use") != "", "Missing actor")
	check(network.call("_interaction_rejection", actor, null, &"use") != "", "Missing target")

	# A remote player's world hand should animate, while the local owner relies
	# on the first-person viewmodel and must not double-play the world hand.
	var player_scene: PackedScene = load("res://player/player.tscn") as PackedScene
	var remote_player: Node3D = player_scene.instantiate() as Node3D
	remote_player.set("input_peer_id", 77)
	root.add_child(remote_player)
	await process_frame
	var remote_point: Vector3 = remote_player.global_position + Vector3(0.0, 1.0, -2.0)
	var world_hand: Hand = remote_player.get_node("Rig/Skeleton3D/HandAttachment_R/HandMount_R/Hand") as Hand
	var hover_point: Vector3 = remote_player.global_position + Vector3(0.5, 1.2, -1.5)
	network.call("_receive_hand_hover", 77, true, hover_point)
	check(world_hand.is_hovering, "Remote player's world right hand should enter pointing pose")
	check(world_hand.hover_point.is_equal_approx(hover_point), "Remote pointing hand should receive the hover world point")
	for frame: int in 30:
		await process_frame
	check(world_hand._resolve_pose_state() == Hand.PoseState.POINT, "Remote world hand should resolve its procedural point pose")
	var world_middle: Node3D = world_hand.get_node("PoseRoot/Middle/Joint1") as Node3D
	check(absf(world_middle.rotation_degrees.x) < 2.0, "Remote world hand should procedurally straighten its middle finger while pointing")
	network.call("_receive_hand_hover", 77, false, Vector3.ZERO)
	for frame: int in 30:
		await process_frame
	check(not world_hand.is_hovering, "Remote player's world right hand should return to idle after hover clears")
	check(absf(world_middle.rotation_degrees.x + 12.0) < 2.0, "Remote world hand should procedurally relax its middle finger after hover clears")
	var previous_poke_count: int = int(network.get("hand_poke_received"))
	network.call("_receive_hand_poke", 77, remote_point)
	check(world_hand._reach_elapsed >= 0.0, "Remote player's world right hand should begin a poke")
	check(int(network.get("hand_poke_received")) == previous_poke_count + 1, "Remote world-hand poke should increment its receive watch")
	remote_player.set("is_local_player", true)
	check(not bool(remote_player.call("play_world_hand_poke", remote_point)), "Local owner must not double-play its hidden world hand")
	check(int(network.get("hand_poke_received")) == previous_poke_count + 1, "Local owner must not count a world-hand poke")
	remote_player.queue_free()
	await process_frame
	var prop: Prop = arena.get_node("TestGrabProp")
	prop.profile = prop.profile.duplicate() as PropProfile
	prop.profile.pickup_allowed = false
	check(not prop.interactable.can_interact(actor, &"grab"), "Pickup-disabled prop must reject before emitting interaction")
	# A small physics fixture exercises real occlusion, without editing the saved scene.
	var wall: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(2, 4, 0.2)
	shape.shape = box
	wall.add_child(shape)
	arena.add_child(wall)
	wall.global_position = Vector3(-3, 1, -5)
	await physics_frame
	await physics_frame
	check(network.call("_interaction_rejection", actor, target, &"use") == "target obstructed", "Wall must block host interaction")
	wall.free()
	actor.global_position = Vector3(20, 1, 20)
	check(network.call("_interaction_rejection", actor, target, &"use") == "out of reach", "Distance validation")
	if not failed:
		print("M3 interaction checks passed")
	quit(1 if failed else 0)

func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
