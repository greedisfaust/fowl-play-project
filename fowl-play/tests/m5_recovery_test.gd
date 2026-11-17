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
	player.global_position = Vector3(0.0, 0.6, 0.0)
	check(bool(network.call("start_ragdoll_spike", 1)), "host starts limp")
	for frame: int in range(30):
		await physics_frame
	var hips: Vector3 = rig.call("get_hips_world_position")
	check(hips.y < 2.0, "saved animation preview does not launch the physical rig")
	player.set("_limp_elapsed_s", 3.4)
	player.call("_process", 0.0)
	check(bool(player.get("is_limp")), "cannot recover before minimum duration")
	var final_pose: PackedInt32Array = rig.call("capture_quantized_pose")
	var old_world: Transform3D = (rig.get_node("Skeleton3D") as Node3D).global_transform
	player.set("_limp_elapsed_s", 6.0)
	player.call("_process", 0.0)
	check(not bool(player.get("is_limp")), "hard cap ends moving ragdoll")
	check(bool(player.get("is_recovering")), "hard cap starts get-up blend")
	check(not simulator.is_simulating_physics() and not rig.top_level, "one cleanup leaves simulation")
	check(player.collision_layer != 0 and player.collision_mask != 0, "standing capsule collisions restored")
	check(player.global_position.distance_to(Vector3(hips.x, 0.53, hips.z)) < 0.18, "capsule planted at final hips on arena floor")
	check(not bool(player.get("wall_clearance_active")), "own ragdoll does not force a clearance offset")
	check_recovery_pose(rig, final_pose, old_world)
	await wait_for_recovery(player)
	check(not bool(player.get("is_recovering")), "hard-cap get-up blend completes")
	check(bool(network.call("start_ragdoll_spike", 1)), "second limp can start after recovery")
	var bones: Array = rig.get("physical_bones")
	for bone: PhysicalBone3D in bones:
		bone.linear_velocity = Vector3.ZERO
		bone.angular_velocity = Vector3.ZERO
	player.set("_limp_elapsed_s", 3.5)
	player.call("_process", 0.0)
	check(not bool(player.get("is_limp")), "settled ragdoll recovers at minimum duration")
	await wait_for_recovery(player)
	check(not bool(player.get("is_recovering")), "settled get-up blend completes")
	check(int(player.get("limp_epoch")) == 2, "recovery preserves epoch sequencing")
	await check_remote_recovery(player, rig)
	await check_clearance(player, rig)
	if not failed:
		print("M5 recovery checks passed")
	quit(1 if failed else 0)

func wait_for_recovery(player: Node) -> void:
	# Authored recovery is 0.5 s blend + 1.2 s clip, independent of FPS.
	var deadline: int = Time.get_ticks_msec() + 4000
	while bool(player.get("is_recovering")) and Time.get_ticks_msec() < deadline:
		await process_frame

func check_recovery_pose(rig: Node3D, final_pose: PackedInt32Array, old_world: Transform3D) -> void:
	var skeleton: Skeleton3D = rig.get_node("Skeleton3D") as Skeleton3D
	var indices: PackedInt32Array = rig.get("_bone_indices")
	for i: int in range(indices.size()):
		var offset: int = i * 7
		var expected: Vector3 = old_world * (Vector3(final_pose[offset], final_pose[offset + 1], final_pose[offset + 2]) / 1000.0)
		var actual: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(indices[i]).origin
		check(actual.distance_to(expected) < 0.003, "handoff preserves world position of %s" % skeleton.get_bone_name(indices[i]))
		var received_rotation: Quaternion = Quaternion(final_pose[offset + 3], final_pose[offset + 4], final_pose[offset + 5], final_pose[offset + 6]).normalized()
		var expected_rotation: Quaternion = (old_world.basis * Basis(received_rotation)).get_rotation_quaternion()
		var actual_rotation: Quaternion = (skeleton.global_basis * skeleton.get_bone_global_pose(indices[i]).basis).get_rotation_quaternion()
		check(actual_rotation.angle_to(expected_rotation) < 0.002, "handoff preserves world rotation of %s" % skeleton.get_bone_name(indices[i]))
	var animation_player: AnimationPlayer = rig.get_node("RecoveryAnimationPlayer") as AnimationPlayer
	var clip_name: StringName = rig.get("_pending_recovery_animation")
	check(clip_name != &"", "authored clip selected")
	if clip_name == &"":
		return
	var clip: Animation = animation_player.get_animation(clip_name)
	var target: Array = rig.get("_pose_blend_target")
	for track: int in range(clip.get_track_count()):
		var bone_name: StringName = clip.track_get_path(track).get_subname(0)
		var index: int = skeleton.find_bone(bone_name)
		if clip.track_get_type(track) == Animation.TYPE_POSITION_3D:
			check(target[index].origin.distance_to(clip.position_track_interpolate(track, 0.0)) < 0.001, "blend targets clip opening position: %s" % bone_name)
		elif clip.track_get_type(track) == Animation.TYPE_ROTATION_3D:
			check(target[index].basis.get_rotation_quaternion().angle_to(clip.rotation_track_interpolate(track, 0.0)) < 0.002, "blend targets clip opening rotation: %s" % bone_name)
	# Complete the blend synchronously and check no reset happens at playback.
	rig.call("_process_pose_blend", 0.5)
	check(animation_player.is_playing(), "clip starts immediately at blend boundary")
	for index: int in range(target.size()):
		check(skeleton.get_bone_pose(index).origin.distance_to(target[index].origin) < 0.001, "clip boundary has no position pop: %s" % skeleton.get_bone_name(index))

func check_remote_recovery(player: CharacterBody3D, rig: Node3D) -> void:
	var initial: PackedInt32Array = rig.call("capture_quantized_pose")
	for variant: StringName in [&"get_up_face_up", &"get_up_face_down"]:
		var epoch: int = int(player.get("limp_epoch")) + 1
		var world: Transform3D = Transform3D(Basis(Vector3.UP, 0.7), Vector3(2.0, 0.53, 2.0))
		check(bool(player.call("begin_remote_limp", epoch, world, initial)), "remote limp starts")
		check(bool(player.call("end_remote_limp", epoch, Vector3(2.8, 0.53, 2.5), initial, variant)), "remote recovery starts after capsule relocation")
		check_recovery_pose(rig, initial, world)
		await wait_for_recovery(player)
		check(not bool(player.get("is_recovering")), "remote authored recovery finishes")

func check_clearance(player: CharacterBody3D, rig: Node3D) -> void:
	player.global_position = Vector3(0.0, 0.53, 0.0)
	check(bool(player.call("begin_host_limp")), "clearance fixture starts limp")
	# A device-layer obstacle at head height blocks standing but not floor rays.
	var obstacle: StaticBody3D = StaticBody3D.new()
	obstacle.collision_layer = 2
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.8, 0.2, 0.8)
	shape_node.shape = box
	obstacle.add_child(shape_node)
	root.add_child(obstacle)
	var hips: Vector3 = rig.call("get_hips_world_position")
	obstacle.global_position = Vector3(hips.x, 2.1, hips.z)
	await physics_frame
	await physics_frame
	var candidate: Vector3 = player.call("_find_recovery_position")
	check(candidate.is_finite() and bool(player.get("wall_clearance_active")), "device obstacle triggers outward clearance")
	check(absf(candidate.y - 0.53) < 0.01, "clearance returns floor height, not capsule center")
	# Enclose the entire search area. Never enable the capsule in this obstacle.
	box.size = Vector3(8.0, 0.2, 8.0)
	await physics_frame
	await physics_frame
	check(not bool(player.call("stop_host_limp")), "blocked recovery is rejected")
	check(bool(player.get("is_limp")) and player.collision_layer == 0, "blocked recovery keeps ragdoll and capsule state")
	obstacle.queue_free()
	await physics_frame
	await physics_frame
	check(bool(player.call("stop_host_limp")), "recovery retries after obstruction removal")
	await wait_for_recovery(player)
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = (player.get_node("CollisionShape3D") as CollisionShape3D).shape
	query.collision_mask = 103
	var unsupported: Vector3 = player.call("_recovery_candidate", Vector3(30.0, 1.0, 30.0), Transform3D.IDENTITY, query)
	check(not unsupported.is_finite(), "unsupported ledge candidate is rejected")

func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
