## Offline M6 checks for limp-player carry, release reset, and re-pick.
extends SceneTree

const PLAYER_SCENE: PackedScene = preload("res://player/player.tscn")
const TUNING = preload("res://core/tuning.gd")

var failed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var network: Node = root.get_node("Network")
	var arena: Node3D = load("res://arena/test_arena.tscn").instantiate()
	root.add_child(arena)
	await physics_frame
	await physics_frame
	var players: Node3D = arena.get_node("Players") as Node3D
	var carrier_player: CharacterBody3D = players.get_node("1") as CharacterBody3D
	carrier_player.set_physics_process(false)

	var carried_player: CharacterBody3D = PLAYER_SCENE.instantiate() as CharacterBody3D
	carried_player.name = "2"
	carried_player.set("input_peer_id", 2)
	carried_player.position = carrier_player.position + Vector3(0.0, 0.0, -2.5)
	players.add_child(carried_player)
	await physics_frame
	await physics_frame
	carried_player.set("auto_recovery_enabled", false)
	check(bool(network.call("start_ragdoll_spike", 2)), "host starts target player's ragdoll")
	for frame: int in range(12):
		await physics_frame

	var rig: Node3D = carried_player.get_node("Rig") as Node3D
	var hips: PhysicalBone3D = rig.get_node("Skeleton3D/PhysicalBoneSimulator3D/Physical Bone Hips") as PhysicalBone3D
	var interactable: Interactable = carried_player.get_node("Interactable") as Interactable
	var carrier: Node = carrier_player.get_node("Carrier")
	var root_before: Vector3 = carried_player.global_position
	carried_player.set("_limp_elapsed_s", 2.5)
	check(interactable.can_interact(carrier_player, &"grab"), "free limp player is a valid grab target")
	check(bool(network.call("host_begin_carry", carrier_player, carried_player)), "host accepts limp-player pickup")
	var carrier_left_hand: Hand = carrier_player.get_node("Head/Camera3D/ViewmodelHands/LeftHand") as Hand
	var carrier_right_hand: Hand = carrier_player.get_node("Head/Camera3D/ViewmodelHands/RightHand") as Hand
	check(carrier_left_hand.carry_side > 0.0 and carrier_right_hand.carry_side < 0.0, "Face-to-face carry should swap chest-side assignments to prevent crossed arms")
	check(bool(carried_player.call("is_carried")), "pickup marks target as carried")
	check(not interactable.can_interact(carrier_player, &"grab"), "carried target cannot be picked up twice")
	check(hips.collision_layer == 0 and hips.collision_mask == 0, "host disables ragdoll collisions while carried")
	carrier.call("_update_held_item_position")
	check(carried_player.global_position.distance_to(root_before) < 0.001, "carry never teleports the Player root")
	check(bool(rig.get("_carry_support_active")), "carrier anchor activates hips spring support")
	carried_player.call("_process", 0.75)
	check(is_equal_approx(float(carried_player.get("_limp_elapsed_s")), 2.5), "recovery timer is suspended while carried")
	for frame: int in range(24):
		await physics_frame
	check(bool(rig.get("_carry_support_active")), "spring support remains active while held")

	network.call("_release_carried", 1, carrier, Vector3.ZERO, Vector3.ZERO)
	check(not bool(carried_player.call("is_carried")), "drop clears carried state")
	check(is_zero_approx(float(carried_player.get("_limp_elapsed_s"))), "drop hard-resets recovery timer")
	check(hips.collision_layer == 1 << 5 and hips.collision_mask != 0, "drop restores host ragdoll collisions")
	check(interactable.can_interact(carrier_player, &"grab"), "dropped player becomes pickable again")

	check(bool(network.call("host_begin_carry", carrier_player, carried_player)), "same player can be picked up again")
	check(bool(carried_player.call("is_carried")), "second pickup sets carried state")
	network.call("_release_carried", 1, carrier, Vector3(0.0, 0.0, -TUNING.THROW_SPEED_LIMP_MPS), Vector3(0.0, 0.5, 0.0))
	check(not bool(carried_player.call("is_carried")), "throw clears carried state")
	check(is_zero_approx(float(carried_player.get("_limp_elapsed_s"))), "throw also hard-resets recovery timer")
	check(hips.linear_velocity.z < -1.0, "throw velocity is applied to the physical hips")

	# Progress before a new pickup is discarded when that body is dropped again.
	carried_player.call("_process", 3.49)
	check(is_equal_approx(float(carried_player.get("_limp_elapsed_s")), 3.49), "fresh post-throw countdown advances from zero")
	check(bool(network.call("host_begin_carry", carrier_player, carried_player)), "player remains pickable before recovery")
	carried_player.call("_process", 0.8)
	check(is_equal_approx(float(carried_player.get("_limp_elapsed_s")), 3.49), "second carry suspends the countdown")
	network.call("_release_carried", 1, carrier, Vector3.ZERO, Vector3.ZERO)
	check(is_zero_approx(float(carried_player.get("_limp_elapsed_s"))), "second drop discards all previous countdown progress")
	carried_player.call("_process", 3.49)
	check(bool(carried_player.get("is_limp")), "body cannot recover before its fresh 3.5-second countdown")
	check(interactable.can_interact(carrier_player, &"grab"), "body remains pickable after repeated drop")

	# Remote peers use a query-only proxy; physical-bone collision stays disabled.
	var remote_visual: CharacterBody3D = PLAYER_SCENE.instantiate() as CharacterBody3D
	remote_visual.name = "3"
	remote_visual.set("input_peer_id", 3)
	players.add_child(remote_visual)
	await physics_frame
	var initial_pose: PackedInt32Array = rig.call("capture_quantized_pose")
	check(bool(remote_visual.call("begin_remote_limp", 1, rig.global_transform, initial_pose)), "remote ragdoll visual starts")
	var proxy: StaticBody3D = remote_visual.get_node("LimpInteractionProxy") as StaticBody3D
	check(proxy.collision_layer == 1 << 5 and proxy.collision_mask == 0, "remote ragdoll exposes a query-only proxy, not physical-bone collision")
	check(proxy.top_level, "remote query proxy follows hips independently of the Player root")
	check(bool((remote_visual.get_node("Interactable") as Interactable).enabled), "remote limp target is enabled for interaction")

	# Removing a carrier mid-carry must run the host release path before the
	# Carrier node disappears, preserving the limp target's physics handoff.
	check(bool(network.call("host_begin_carry", carrier_player, carried_player)), "carrier can pick up the limp target before carrier removal")
	carrier_player.velocity = Vector3(1.5, 0.0, 0.5)
	carrier_player.queue_free()
	await process_frame
	check(not bool(carried_player.call("is_carried")), "carrier removal releases the carried player")
	check(not bool(rig.get("_carry_support_active")), "carrier removal stops carried-body support")
	check(hips.collision_layer == 1 << 5 and hips.collision_mask != 0, "carrier removal restores limp collision")
	check(carried_player.velocity.x > 0.1, "carrier removal preserves inherited carrier velocity")

	if not failed:
		print("M6 carry checks passed")
	quit(1 if failed else 0)

func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
