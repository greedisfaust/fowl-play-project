## Verifies the saved Player and Rig scenes hand motion to the physical body
## without moving the Player root or leaving collisions active after cleanup.
extends SceneTree

var failed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: PackedScene = load("res://player/player.tscn")
	var player: CharacterBody3D = scene.instantiate()
	player.name = "1"
	player.position = Vector3(0.0, 2.5, 0.0)
	root.add_child(player)
	await physics_frame

	var rig: Node3D = player.get_node("Rig") as Node3D
	var simulator: PhysicalBoneSimulator3D = rig.get_node("Skeleton3D/PhysicalBoneSimulator3D") as PhysicalBoneSimulator3D
	var hips: PhysicalBone3D = simulator.get_node("Physical Bone Hips") as PhysicalBone3D
	var chest: PhysicalBone3D = simulator.get_node("Physical Bone Chest") as PhysicalBone3D
	var forearm_l: PhysicalBone3D = simulator.get_node("Physical Bone Forearm_L") as PhysicalBone3D
	var upper_arm_l: PhysicalBone3D = simulator.get_node("Physical Bone UpperArm_L") as PhysicalBone3D
	var thigh_l: PhysicalBone3D = simulator.get_node("Physical Bone Thigh_L") as PhysicalBone3D
	var shin_l: PhysicalBone3D = simulator.get_node("Physical Bone Shin_L") as PhysicalBone3D
	check(not chest.get_collision_exceptions().has(forearm_l) and not forearm_l.get_collision_exceptions().has(chest), "forearm can contact chest")
	check(not hips.get_collision_exceptions().has(shin_l) and not shin_l.get_collision_exceptions().has(hips), "shin can contact hips")
	check(chest.get_collision_exceptions().has(upper_arm_l) or upper_arm_l.get_collision_exceptions().has(chest), "connected shoulder stays exempt")
	check(thigh_l.get_collision_exceptions().has(shin_l) or shin_l.get_collision_exceptions().has(thigh_l), "connected knee stays exempt")
	var start_root: Vector3 = player.global_position
	var start_hips_y: float = hips.global_position.y
	var camera: Camera3D = player.get_node("Head/Camera3D") as Camera3D
	var start_camera_y: float = camera.global_position.y
	var head_attachment: BoneAttachment3D = rig.get_node("Skeleton3D/HeadAttachment") as BoneAttachment3D
	check(player.call("begin_host_limp"), "host handoff accepted")
	check(bool(player.get("is_limp")), "limp state set")
	check(rig.top_level, "rig detached from Player transform")
	check(player.collision_layer == 0 and player.collision_mask == 0, "capsule collisions disabled")
	check(simulator.is_simulating_physics(), "physical bones simulating")
	check(camera.top_level and rig.visible and not head_attachment.visible, "owner camera detached, body visible, and head hidden")

	for index: int in range(12):
		await physics_frame
	check(player.global_position.distance_to(start_root) < 0.001, "Player root stayed fixed")
	check(hips.global_position.y < start_hips_y - 0.01, "hips fell independently")
	player.call("_update_limp_camera", 0.0)
	check(camera.global_position.y < start_camera_y - 0.01, "owner camera followed falling head")
	var eye_transform: Transform3D = rig.call("get_head_eye_transform")
	check(camera.global_position.distance_to(eye_transform.origin) < 0.01, "owner camera anchored at head eye point")
	var before_look: Vector3 = camera.global_basis.z
	player.call("_rotate_limp_view", Vector2(-100000.0, -100000.0))
	check(is_equal_approx(float(player.get("_limp_look_yaw")), deg_to_rad(75.0)), "limp look cannot turn behind head")
	check(is_equal_approx(float(player.get("_limp_look_pitch")), deg_to_rad(75.0)), "limp look pitch is limited")
	player.call("_update_limp_camera", 0.0)
	check(camera.global_basis.z.distance_to(before_look) > 0.001, "look offset rotates the ragdoll view")
	player.call("_rotate_limp_view", Vector2(100000.0, 100000.0))
	check(is_equal_approx(float(player.get("_limp_look_yaw")), deg_to_rad(-75.0)), "limp look stops at opposite shoulder")
	check(is_equal_approx(float(player.get("_limp_look_pitch")), deg_to_rad(-75.0)), "limp look pitch stops in both directions")

	player.call("stop_host_limp")
	check(not bool(player.get("is_limp")), "limp state cleared")
	check(bool(player.get("is_recovering")), "get-up blend started")
	check(not rig.top_level and not simulator.is_simulating_physics(), "rig left simulation for recovery")
	check(camera.top_level and rig.visible and not head_attachment.visible, "camera and body remain active during recovery")
	for frame: int in range(120):
		await process_frame
		if not bool(player.get("is_recovering")):
			break
	check(not bool(player.get("is_recovering")), "get-up blend completed")
	check(not camera.top_level and not rig.visible and head_attachment.visible, "owner camera and model returned to standing")
	check(player.collision_layer == 1 << 4 and player.collision_mask == 103, "capsule collisions restored")
	for child: Node in simulator.get_children():
		if child is PhysicalBone3D:
			var bone: PhysicalBone3D = child
			check(bone.collision_layer == 0 and bone.collision_mask == 0, "dormant bone collision disabled")
	player.queue_free()
	await process_frame
	if not failed:
		print("M4 limp handoff checks passed")
	quit(1 if failed else 0)

func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
