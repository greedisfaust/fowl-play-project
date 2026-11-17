extends Node3D

const LAYERS = preload("res://core/layers.gd")
const SELF_COLLISION = preload("res://ragdoll/self_collision_policy.gd")

@export var start_on_ready: bool = false

@onready var skeleton: Skeleton3D = $Skeleton3D
@onready var debug_hub: Node = get_node("/root/DebugHub")
@onready var simulator: PhysicalBoneSimulator3D = $Skeleton3D/PhysicalBoneSimulator3D
@onready var ground: StaticBody3D = $Ground

const START_COMMAND: StringName = &"ragdoll_test_start"
const STOP_COMMAND: StringName = &"ragdoll_test_stop"
const RESET_COMMAND: StringName = &"ragdoll_test_reset"
const STATE_WATCH: StringName = &"ragdoll_test.simulating"

func _ready() -> void:
	_configure_collision_filtering()
	debug_hub.call(
		"command",
		START_COMMAND,
		start_simulation,
		"Start the isolated player ragdoll test.",
		false,
		true
	)
	debug_hub.call(
		"command",
		STOP_COMMAND,
		stop_simulation,
		"Stop the isolated player ragdoll test.",
		false,
		true
	)
	debug_hub.call(
		"command",
		RESET_COMMAND,
		reset_simulation,
		"Stop the test and restore the skeleton rest pose.",
		false,
		true
	)
	debug_hub.call("watch", STATE_WATCH, _is_simulating)

	if start_on_ready:
		start_simulation()

func _configure_collision_filtering() -> void:
	ground.collision_layer = 1 << (LAYERS.WORLD_STATIC - 1)
	ground.collision_mask = LAYERS.LAYER_MASK_WORLD_STATIC

	var physical_bones: Array[PhysicalBone3D] = []
	for child: Node in simulator.get_children():
		if child is PhysicalBone3D:
			var physical_bone: PhysicalBone3D = child
			physical_bone.collision_layer = 1 << (LAYERS.LIMP_BODIES - 1)
			physical_bone.collision_mask = LAYERS.LAYER_MASK_LIMP_BODIES
			physical_bones.append(physical_bone)

	var self_contact_pairs: int = SELF_COLLISION.configure(physical_bones)

	debug_hub.call(
		"log",
		&"ragdoll",
		"Configured %d physical bodies with %d selective same-ragdoll contact pairs."
		% [physical_bones.size(), self_contact_pairs]
	)

func _exit_tree() -> void:
	debug_hub.call("unregister_command", START_COMMAND)
	debug_hub.call("unregister_command", STOP_COMMAND)
	debug_hub.call("unregister_command", RESET_COMMAND)
	debug_hub.call("unwatch", STATE_WATCH)

func start_simulation(_args: Array[Variant] = []) -> void:
	debug_hub.call("log", &"ragdoll", "Starting isolated physical-bone simulation.")
	simulator.physical_bones_start_simulation()

func stop_simulation(_args: Array[Variant] = []) -> void:
	debug_hub.call("log", &"ragdoll", "Stopping isolated physical-bone simulation.")
	simulator.physical_bones_stop_simulation()

func reset_simulation(_args: Array[Variant] = []) -> void:
	debug_hub.call("log", &"ragdoll", "Resetting isolated ragdoll to its rest pose.")
	simulator.physical_bones_stop_simulation()
	skeleton.reset_bone_poses()

func _is_simulating() -> bool:
	return simulator.is_simulating_physics()
