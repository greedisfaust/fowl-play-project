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
	var local_right_hand: Hand = actor.get_node("Head/Camera3D/ViewmodelHands/RightHand") as Hand
	check(local_right_hand._action_phase == Hand.HandActionPhase.EXTENDING and local_right_hand._action_result_received, "Authoritative interaction acceptance should confirm the active local hand action")
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
	var world_hand: Hand = remote_player.get_node("Head/Camera3D/ViewmodelHands/RightHand") as Hand
	var rig_world_hand: Hand = remote_player.get_node("Rig/Skeleton3D/HandAttachment_R/HandMount_R/Hand") as Hand
	var hover_point: Vector3 = remote_player.global_position + Vector3(0.5, 1.2, -1.5)
	var hover_applied_before: int = int(network.get("hand_hover_received"))
	network.call("_receive_hand_hover", 77, true, hover_point)
	check(world_hand.is_hovering, "Remote player's Viewmodel right hand should enter pointing pose")
	check(world_hand.hover_point.is_equal_approx(hover_point), "Remote Viewmodel pointing hand should receive the hover world point")
	check(not rig_world_hand.is_hovering, "Ragdoll Rig hand must not receive ordinary hover pointing")
	check(int(network.get("hand_hover_received")) == hover_applied_before + 1, "Host-side remote world-hand hover application should increment its receive watch")
	for frame: int in 30:
		await process_frame
	check(world_hand._resolve_pose_state() == Hand.PoseState.POINT, "Remote Viewmodel hand should resolve its procedural point pose")
	var world_index: Node3D = world_hand.get_node("PoseRoot/IndexAim/Index/Joint1") as Node3D
	var world_middle: Node3D = world_hand.get_node("PoseRoot/Middle/Joint1") as Node3D
	check(absf(world_index.rotation_degrees.x) < 2.0, "Remote Viewmodel hand should procedurally straighten its index finger while pointing")
	check(absf(world_middle.rotation_degrees.x + 75.0) < 2.0, "Remote Viewmodel hand should curl its other fingers while pointing")
	network.call("_receive_hand_hover", 77, false, Vector3.ZERO)
	for frame: int in 30:
		await process_frame
	check(not world_hand.is_hovering, "Remote player's Viewmodel right hand should return to idle after hover clears")
	check(not rig_world_hand.is_hovering, "Ragdoll Rig hand should remain unaffected when hover clears")
	check(absf(world_middle.rotation_degrees.x + 12.0) < 2.0, "Remote Viewmodel hand should procedurally relax its middle finger after hover clears")
	# Carry events must drive both hands on the correct presentation rig.
	var remote_carrier: Carrier = remote_player.get_node("Carrier") as Carrier
	var held_test_item: Node3D = Node3D.new()
	remote_carrier.attach_item(held_test_item)
	for frame: int in 30:
		await process_frame
	var world_left_hand: Hand = remote_player.get_node("Rig/Skeleton3D/HandAttachment_L/HandMount_L/Hand") as Hand
	check(world_left_hand.is_carrying and rig_world_hand.is_carrying, "Remote carry event should activate both ragdoll Rig hands")
	check(world_left_hand._resolve_pose_state() == Hand.PoseState.CARRY and rig_world_hand._resolve_pose_state() == Hand.PoseState.CARRY, "Remote Rig hands should resolve the carry pose")
	check(world_left_hand.carry_side < 0.0 and rig_world_hand.carry_side > 0.0, "Remote Rig hands should receive opposite grip sides")
	remote_carrier.detach_item()
	check(not world_left_hand.is_carrying and not rig_world_hand.is_carrying, "Remote carry end should clear both ragdoll Rig hands")
	remote_player.set("is_local_player", true)
	var local_test_item: Node3D = Node3D.new()
	remote_carrier.attach_item(local_test_item)
	var viewmodel_left_hand: Hand = remote_player.get_node("Head/Camera3D/ViewmodelHands/LeftHand") as Hand
	var viewmodel_right_hand: Hand = remote_player.get_node("Head/Camera3D/ViewmodelHands/RightHand") as Hand
	check(viewmodel_left_hand.is_carrying and viewmodel_right_hand.is_carrying, "Local carry event should activate both first-person hands")
	remote_carrier.detach_item()
	check(not viewmodel_left_hand.is_carrying and not viewmodel_right_hand.is_carrying, "Local carry end should clear both first-person hands")
	remote_player.set("is_local_player", false)
	var previous_poke_count: int = int(network.get("hand_poke_received"))
	network.call("_receive_hand_poke", 77, remote_point)
	check(world_hand._reach_elapsed >= 0.0, "Remote player's Viewmodel right hand should begin a poke")
	check(rig_world_hand._reach_elapsed < 0.0, "Ragdoll Rig hand must not play the replicated Viewmodel poke")
	check(int(network.get("hand_poke_received")) == previous_poke_count + 1, "Remote world-hand poke should increment its receive watch")
	network.call("_receive_hand_poke", 77, remote_point + Vector3(0.1, 0.0, 0.0))
	check(world_hand._action_phase == Hand.HandActionPhase.EXTENDING, "Remote Viewmodel hand should accept a second poke while the first is active")
	check(int(network.get("hand_poke_received")) == previous_poke_count + 2, "Rapid remote pokes should both be presented")
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
