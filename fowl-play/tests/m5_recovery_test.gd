## Host-owned recovery deadline, floor placement, and shared cleanup path.
extends SceneTree

var failed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var network: Node = root.get_node("Network")
	var arena: Node3D = load("res://arena/test_arena.tscn").instantiate()
	root.add_child(arena)
	await physics_frame
	await physics_frame
	check(bool(network.get("is_host")), "test runs as host")
	var player: CharacterBody3D = arena.get_node("Players/1") as CharacterBody3D
	var rig: Node3D = player.get_node("Rig") as Node3D
	var simulator: PhysicalBoneSimulator3D = rig.get_node("Skeleton3D/PhysicalBoneSimulator3D") as PhysicalBoneSimulator3D
	check(bool(network.call("start_ragdoll_spike", 1)), "host starts limp")
	for frame: int in range(30):
		await physics_frame
	var hips: Vector3 = rig.call("get_hips_world_position")
	player.set("_limp_elapsed_s", 3.4)
	player.call("_process", 0.0)
	check(bool(player.get("is_limp")), "cannot recover before minimum duration")
	player.set("_limp_elapsed_s", 6.0)
	player.call("_process", 0.0)
	check(not bool(player.get("is_limp")), "hard cap ends moving ragdoll")
	check(not simulator.is_simulating_physics() and not rig.top_level, "one cleanup restores standing rig")
	check(player.collision_layer != 0 and player.collision_mask != 0, "standing capsule collisions restored")
	check(player.global_position.distance_to(Vector3(hips.x, 0.53, hips.z)) < 0.18, "capsule planted at final hips on arena floor")
	check(bool(network.call("start_ragdoll_spike", 1)), "second limp can start after recovery")
	var bones: Array = rig.get("physical_bones")
	for bone: PhysicalBone3D in bones:
		bone.linear_velocity = Vector3.ZERO
		bone.angular_velocity = Vector3.ZERO
	player.set("_limp_elapsed_s", 3.5)
	player.call("_process", 0.0)
	check(not bool(player.get("is_limp")), "settled ragdoll recovers at minimum duration")
	check(int(player.get("limp_epoch")) == 2, "recovery preserves epoch sequencing")
	if not failed:
		print("M5 recovery checks passed")
	quit(1 if failed else 0)

func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
