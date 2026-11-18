## Headless checks for the first procedural arm IK slice.
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
	print("M2 procedural right arm checks passed")
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
	if upper_index < 0 or hand_index < 0:
		_fail("Right arm bone chain is incomplete")
		rig.free()
		return
	var target: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(upper_index).origin) + Vector3(0.18, -0.06, -0.38)
	var before: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(hand_index).origin)
	var applied: bool = bool(rig.call("update_procedural_right_arm", target, 1.0))
	skeleton.force_update_all_bone_transforms()
	var after: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(hand_index).origin)
	if not applied:
		_fail("Standing Player Rig should accept a valid right wrist target")
	if after.distance_to(target) >= before.distance_to(target):
		_fail("Right wrist should move closer to the requested Viewmodel wrist target")
	var started: bool = bool(rig.call("begin_host_simulation"))
	if not started:
		_fail("Player Rig should enter ragdoll for ownership test")
	var frozen_rotation: Quaternion = skeleton.get_bone_pose_rotation(upper_index)
	rig.call("update_procedural_right_arm", target + Vector3(0.1, 0.0, 0.0), 1.0)
	if skeleton.get_bone_pose_rotation(upper_index).angle_to(frozen_rotation) > 0.001:
		_fail("Procedural IK must yield immediately when ragdoll physics owns the arm")
	rig.call("stop_host_simulation")
	rig.free()

func _fail(message: String) -> void:
	_failed = true
	push_error(message)
