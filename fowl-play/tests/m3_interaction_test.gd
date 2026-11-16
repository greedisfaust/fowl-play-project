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
