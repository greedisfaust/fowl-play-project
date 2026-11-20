## Headless checks for the local procedural leg gait and ragdoll ownership gate.
extends SceneTree

const LEG_CONTROLLER_SCRIPT = preload("res://ragdoll/procedural_leg_controller.gd")
const RIG_SCENE: PackedScene = preload("res://ragdoll/player_rig.tscn")

var _failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_check_controller_gait()
	_check_rig_ownership()
	if _failed:
		quit(1)
		return
	print("M8 procedural leg checks passed")
	quit(0)

func _check_controller_gait() -> void:
	var controller: RefCounted = LEG_CONTROLLER_SCRIPT.new()
	controller.call("update", 0.125, Vector3(0.0, 0.0, -5.0), true)
	var phase_after_walk: float = float(controller.get("phase"))
	var left_thigh: Quaternion = controller.get("left_thigh_rotation")
	var right_thigh: Quaternion = controller.get("right_thigh_rotation")
	if phase_after_walk <= 0.0:
		_fail("Grounded movement should advance the gait phase")
	if left_thigh.angle_to(Quaternion.IDENTITY) < 0.1:
		_fail("Walking should move the left thigh away from its rest rotation")
	if right_thigh.angle_to(Quaternion.IDENTITY) < 0.1:
		_fail("Walking should move the right thigh away from its rest rotation")
	if left_thigh.angle_to(right_thigh) < 0.2:
		_fail("Left and right legs should alternate their swing")
	var left_forward: Vector3 = left_thigh * Vector3.DOWN
	if left_forward.z >= -0.05:
		_fail("Forward walking should swing the leg toward the character's forward axis")

	var phase_before_air: float = phase_after_walk
	var angle_before_air: float = left_thigh.angle_to(Quaternion.IDENTITY)
	controller.call("update", 0.1, Vector3(0.0, 0.0, -5.0), false)
	var phase_after_air: float = float(controller.get("phase"))
	var left_air_thigh: Quaternion = controller.get("left_thigh_rotation")
	var angle_after_air: float = left_air_thigh.angle_to(Quaternion.IDENTITY)
	if not is_equal_approx(phase_before_air, phase_after_air):
		_fail("Airborne movement must not advance the grounded step cycle")
	if angle_after_air >= angle_before_air:
		_fail("Leg pose should blend toward neutral while airborne")

	var strafe_controller: RefCounted = LEG_CONTROLLER_SCRIPT.new()
	strafe_controller.call("update", 0.125, Vector3(5.0, 0.0, 0.0), true)
	var strafe_thigh: Quaternion = strafe_controller.get("left_thigh_rotation")
	var left_sideways: Vector3 = strafe_thigh * Vector3.DOWN
	if left_sideways.x <= 0.05:
		_fail("Strafing should orient the leg swing plane toward lateral movement")

	var transition_controller: RefCounted = LEG_CONTROLLER_SCRIPT.new()
	transition_controller.call("update", 0.125, Vector3(0.0, 0.0, -5.0), true)
	var velocity_before_turn: Vector3 = transition_controller.get("smoothed_velocity")
	transition_controller.call("update", 0.02, Vector3(5.0, 0.0, 0.0), true)
	var velocity_during_turn: Vector3 = transition_controller.get("smoothed_velocity")
	if velocity_during_turn.x <= 0.0 or velocity_during_turn.z >= 0.0:
		_fail("Directional changes should blend through the previous movement direction")
	if velocity_during_turn.distance_to(Vector3(5.0, 0.0, 0.0)) < velocity_before_turn.length() * 0.1:
		_fail("A direction change should not snap instantly to the new velocity")

	var weight_before_stop: float = float(transition_controller.get("motion_weight"))
	var speed_before_stop: float = velocity_during_turn.length()
	for stop_step: int in range(5):
		transition_controller.call("update", 0.1, Vector3.ZERO, true)
	var velocity_after_stop: Vector3 = transition_controller.get("smoothed_velocity")
	var speed_after_stop: float = velocity_after_stop.length()
	var weight_after_stop: float = float(transition_controller.get("motion_weight"))
	if speed_after_stop >= speed_before_stop:
		_fail("Smoothed movement speed should decay after the player stops")
	if weight_after_stop >= weight_before_stop:
		_fail("Leg motion weight should ease down after stopping")

func _check_rig_ownership() -> void:
	var rig: Node3D = RIG_SCENE.instantiate() as Node3D
	rig.name = "M8TestRig"
	root.add_child(rig)
	var skeleton: Skeleton3D = rig.get_node("Skeleton3D") as Skeleton3D
	var left_thigh_index: int = skeleton.find_bone("Thigh_L")
	if left_thigh_index < 0:
		_fail("Rig must contain the authored left thigh bone")
		rig.free()
		return
	var applied: bool = bool(rig.call("update_procedural_legs", Vector3(0.0, 0.0, -5.0), true, 0.125))
	if not applied:
		_fail("Standing rig should accept procedural leg targets")
	skeleton.force_update_all_bone_transforms()
	var standing_rotation: Quaternion = skeleton.get_bone_pose_rotation(left_thigh_index)
	if standing_rotation.angle_to(Quaternion.IDENTITY) < 0.1:
		_fail("Rig should apply the procedural gait to its skeleton")
	var started: bool = bool(rig.call("begin_host_simulation"))
	if not started:
		_fail("Rig should enter ragdoll for the ownership check")
	var frozen_rotation: Quaternion = skeleton.get_bone_pose_rotation(left_thigh_index)
	var applied_during_limp: bool = bool(rig.call("update_procedural_legs", Vector3(0.0, 0.0, -5.0), true, 0.125))
	if applied_during_limp:
		_fail("Procedural legs must yield while PhysicalBoneSimulator owns the rig")
	if skeleton.get_bone_pose_rotation(left_thigh_index).angle_to(frozen_rotation) > 0.001:
		_fail("Procedural leg updates must not alter a ragdoll-owned skeleton")
	rig.call("stop_host_simulation")
	rig.free()

func _fail(message: String) -> void:
	_failed = true
	push_error(message)
