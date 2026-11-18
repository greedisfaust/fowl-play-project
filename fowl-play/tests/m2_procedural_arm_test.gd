## Headless checks for procedural two-arm IK.
extends SceneTree

var _failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_check_solver_geometry()
	_check_rig_arm_target()
	if _failed:
		quit(1)
		return
	print("M2 procedural two-arm checks passed")
	quit(0)

func _check_solver_geometry() -> void:
	var shoulder: Vector3 = Vector3.ZERO
	var target: Vector3 = Vector3(0.18, 0.02, -0.42)
	var result: Dictionary = ProceduralArmIK.solve_two_bone(shoulder, target, Vector3.DOWN, 0.28, 0.25)
	if result.is_empty():
		_fail("Reachable arm target should produce a two-bone solution")
		return
	var elbow: Vector3 = result["elbow"]
	var solved_target: Vector3 = result["target"]
	if absf(elbow.distance_to(shoulder) - 0.28) > 0.001:
		_fail("Upper arm solution must preserve its authored 0.28 m length")
	if absf(solved_target.distance_to(elbow) - 0.25) > 0.001:
		_fail("Forearm solution must preserve its authored 0.25 m length")
	if not elbow.is_finite():
		_fail("Elbow solution must remain finite")
	var too_far: Dictionary = ProceduralArmIK.solve_two_bone(shoulder, Vector3(0.0, 0.0, -2.0), Vector3.DOWN, 0.28, 0.25)
	if not bool(too_far.get("clamped", false)):
		_fail("Targets beyond arm length must be clamped instead of stretching the bones")
	var too_far_target: Vector3 = too_far["target"]
	if absf(too_far_target.length() - 0.529) > 0.002:
		_fail("Reach clamp should preserve total arm length with a small safety margin")
	var too_close: Dictionary = ProceduralArmIK.solve_two_bone(shoulder, Vector3(0.0, 0.0, -0.01), Vector3.DOWN, 0.28, 0.25)
	var too_close_target: Vector3 = too_close["target"]
	if too_close_target.length() < 0.031:
		_fail("Unreachable close targets must respect minimum two-bone separation")

func _check_rig_arm_target() -> void:
	var scene: PackedScene = load("res://ragdoll/player_rig.tscn") as PackedScene
	if scene == null:
		_fail("Could not load Player Rig scene")
		return
	var rig: Node3D = scene.instantiate() as Node3D
	root.add_child(rig)
	var skeleton: Skeleton3D = rig.get_node("Skeleton3D") as Skeleton3D
	var upper_index: int = skeleton.find_bone("UpperArm_L")
	var hand_index: int = skeleton.find_bone("Hand_L")
	var left_upper_index: int = skeleton.find_bone("UpperArm_R")
	var left_hand_index: int = skeleton.find_bone("Hand_R")
	var rig_hand_visual: MeshInstance3D = rig.get_node("Skeleton3D/HandAttachment_L/HandMount_L/Hand/PoseRoot/Wrist") as MeshInstance3D
	var left_rig_hand_visual: MeshInstance3D = rig.get_node("Skeleton3D/HandAttachment_R/HandMount_R/Hand/PoseRoot/Wrist") as MeshInstance3D
	var right_world_hand_forearm: MeshInstance3D = rig.get_node("Skeleton3D/HandAttachment_L/HandMount_L/Hand/PoseRoot/Forearm") as MeshInstance3D
	var left_world_hand_forearm: MeshInstance3D = rig.get_node("Skeleton3D/HandAttachment_R/HandMount_R/Hand/PoseRoot/Forearm") as MeshInstance3D
	if upper_index < 0 or hand_index < 0 or left_upper_index < 0 or left_hand_index < 0:
		_fail("One of the Rig arm bone chains is incomplete")
		rig.free()
		return
	if rig_hand_visual.visible:
		_fail("Duplicate positive-X Rig hand should be hidden while the Viewmodel hand owns standing presentation")
	if left_rig_hand_visual.visible:
		_fail("Duplicate negative-X Rig hand should be hidden while the Viewmodel hand owns standing presentation")
	if right_world_hand_forearm.visible or left_world_hand_forearm.visible:
		_fail("Hand-scene Forearm meshes must stay hidden on both world Rig hands")
	var target: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(upper_index).origin) + Vector3(0.18, -0.06, -0.38)
	var before: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(hand_index).origin)
	var applied: bool = bool(rig.call("update_procedural_right_arm", target, 1.0))
	skeleton.force_update_all_bone_transforms()
	var after: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(hand_index).origin)
	if not applied:
		_fail("Standing Player Rig should accept a valid right wrist target")
	var stretched_scale: Vector3 = skeleton.get_bone_pose_scale(upper_index)
	if stretched_scale.is_equal_approx(Vector3.ONE):
		_fail("A wrist target just beyond normal reach should apply a small visual arm stretch")
	if after.distance_to(target) >= before.distance_to(target):
		_fail("Right wrist should move closer to the requested Viewmodel wrist target")
	var extended_target: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(upper_index).origin) + Vector3(0.0, 0.0, -0.60)
	rig.call("update_procedural_right_arm", extended_target, 1.0)
	var extended_scale: Vector3 = skeleton.get_bone_pose_scale(upper_index)
	if extended_scale.is_equal_approx(Vector3.ONE):
		_fail("Right arm should apply a limited bone-axis scale when the wrist target exceeds normal reach")
	if extended_scale.x > 1.121 or extended_scale.y > 1.121 or extended_scale.z > 1.121:
		_fail("Procedural arm stretch must remain within the 12 percent limit")
	var left_target: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(left_upper_index).origin) + Vector3(-0.18, -0.06, -0.38)
	var left_before: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(left_hand_index).origin)
	var left_applied: bool = bool(rig.call("update_procedural_left_arm", left_target, 1.0))
	skeleton.force_update_all_bone_transforms()
	var left_after: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(left_hand_index).origin)
	if not left_applied:
		_fail("Standing Player Rig should accept a valid left wrist target")
	if left_after.distance_to(left_target) >= left_before.distance_to(left_target):
		_fail("Left wrist should move closer to the requested Viewmodel wrist target")
	var started: bool = bool(rig.call("begin_host_simulation"))
	if not started:
		_fail("Player Rig should enter ragdoll for ownership test")
	if not rig_hand_visual.visible:
		_fail("Rig hand visual should return when ragdoll physics takes ownership")
	if not left_rig_hand_visual.visible:
		_fail("Left Rig hand visual should return when ragdoll physics takes ownership")
	if right_world_hand_forearm.visible or left_world_hand_forearm.visible:
		_fail("World Hand Forearm meshes must remain hidden even while ragdoll Rig hands are visible")
	var frozen_rotation: Quaternion = skeleton.get_bone_pose_rotation(upper_index)
	var left_frozen_rotation: Quaternion = skeleton.get_bone_pose_rotation(left_upper_index)
	rig.call("update_procedural_right_arm", target + Vector3(0.1, 0.0, 0.0), 1.0)
	rig.call("update_procedural_left_arm", left_target + Vector3(-0.1, 0.0, 0.0), 1.0)
	if skeleton.get_bone_pose_rotation(upper_index).angle_to(frozen_rotation) > 0.001:
		_fail("Right procedural IK must yield immediately when ragdoll physics owns the arm")
	if skeleton.get_bone_pose_rotation(left_upper_index).angle_to(left_frozen_rotation) > 0.001:
		_fail("Left procedural IK must yield immediately when ragdoll physics owns the arm")
	rig.call("stop_host_simulation")
	if rig_hand_visual.visible:
		_fail("Duplicate Rig hand should hide again after ragdoll simulation stops")
	if left_rig_hand_visual.visible:
		_fail("Duplicate left Rig hand should hide again after ragdoll simulation stops")
	rig.free()

func _fail(message: String) -> void:
	_failed = true
	push_error(message)
