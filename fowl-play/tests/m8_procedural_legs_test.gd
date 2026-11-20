## Headless checks for the local procedural leg gait and ragdoll ownership gate.
extends SceneTree

const LEG_CONTROLLER_SCRIPT = preload("res://ragdoll/procedural_leg_controller.gd")
const FOOT_PLANT_SCRIPT = preload("res://ragdoll/procedural_foot_plant.gd")
const RIG_SCENE: PackedScene = preload("res://ragdoll/player_rig.tscn")

var _failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_check_controller_gait()
	_check_foot_plant_targets()
	await _check_rig_ownership()
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

	_check_stance_swing_articulation()

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

func _check_stance_swing_articulation() -> void:
	var controller: RefCounted = LEG_CONTROLLER_SCRIPT.new()
	controller.set("phase", TAU * 0.30)
	controller.set("motion_weight", 1.0)
	controller.set("smoothed_velocity", Vector3(0.0, 0.0, -5.0))
	controller.call("update", 0.0, Vector3(0.0, 0.0, -5.0), true)
	var stance_foot: Quaternion = controller.get("left_foot_rotation")
	if bool(controller.get("left_in_swing")):
		_fail("The left foot should be in stance during the first part of its cycle")

	controller.set("phase", TAU * 0.80)
	controller.set("motion_weight", 1.0)
	controller.set("smoothed_velocity", Vector3(0.0, 0.0, -5.0))
	controller.call("update", 0.0, Vector3(0.0, 0.0, -5.0), true)
	var swing_foot: Quaternion = controller.get("left_foot_rotation")
	if not bool(controller.get("left_in_swing")):
		_fail("The left foot should enter swing after the stance fraction")
	if stance_foot.angle_to(swing_foot) < 0.08:
		_fail("Foot articulation should differ between stance and swing")
	if float(controller.get("left_swing_progress")) <= 0.0:
		_fail("Swing phase should expose a normalized progress value")

	if bool(controller.get("right_in_swing")) == bool(controller.get("left_in_swing")):
		_fail("Opposite feet should occupy opposite gait phases")


func _check_foot_plant_targets() -> void:
	var tracker: RefCounted = FOOT_PLANT_SCRIPT.new()
	var current: Vector3 = Vector3(0.0, 0.1, 0.0)
	var first_landing: Vector3 = Vector3(0.0, 0.05, 0.0)
	var planted: Vector3 = tracker.call("update_target", current, first_landing, true, false, 0.0, 0.12)
	if planted.distance_to(first_landing) > 0.001:
		_fail("A new stance should capture the grounded landing target")

	var moved_root_foot: Vector3 = current + Vector3(0.0, 0.0, -0.4)
	var locked: Vector3 = tracker.call("update_target", moved_root_foot, first_landing, true, false, 0.0, 0.12)
	if locked.distance_to(first_landing) > 0.001:
		_fail("A planted foot should remain locked in world space while the player moves")

	var next_landing: Vector3 = Vector3(0.0, 0.05, -0.8)
	var swing_start: Vector3 = tracker.call("update_target", moved_root_foot, next_landing, true, true, 0.0, 0.12)
	if swing_start.distance_to(first_landing) > 0.001:
		_fail("A swing should begin at the previous planted anchor")
	var swing_middle: Vector3 = tracker.call("update_target", moved_root_foot, next_landing, true, true, 0.5, 0.12)
	if swing_middle.z >= first_landing.z or swing_middle.z <= next_landing.z:
		_fail("The swing target should interpolate between the old and next foot positions")
	if swing_middle.y <= first_landing.y:
		_fail("The swing target should lift above the ground during mid-swing")
	var landed: Vector3 = tracker.call("update_target", next_landing, next_landing, true, false, 0.0, 0.12)
	if landed.distance_to(next_landing) > 0.001:
		_fail("The foot should lock to its new landing point when stance begins")

	var airborne: Vector3 = tracker.call("update_target", next_landing + Vector3.UP, next_landing, false, false, 0.0, 0.12)
	if airborne.distance_to(next_landing + Vector3.UP) > 0.001:
		_fail("Foot planting should yield to the current foot position while airborne")

func _check_rig_ownership() -> void:
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.name = "M8GroundProbeFloor"
	floor_body.collision_layer = 1
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var floor_box: BoxShape3D = BoxShape3D.new()
	floor_box.size = Vector3(20.0, 0.2, 20.0)
	floor_shape.shape = floor_box
	floor_shape.position = Vector3(0.0, -0.1, 0.0)
	floor_body.add_child(floor_shape)
	root.add_child(floor_body)
	var rig: Node3D = RIG_SCENE.instantiate() as Node3D
	rig.name = "M8TestRig"
	root.add_child(rig)
	await physics_frame
	var skeleton: Skeleton3D = rig.get_node("Skeleton3D") as Skeleton3D
	var left_thigh_index: int = skeleton.find_bone("Thigh_L")
	if left_thigh_index < 0:
		_fail("Rig must contain the authored left thigh bone")
		rig.free()
		return
	var applied: bool = bool(rig.call("update_procedural_legs", Vector3(0.0, 0.0, -5.0), true, 0.125))
	if not applied:
		_fail("Standing rig should accept procedural leg targets")
	var ground_status: String = str(rig.call("_debug_leg_ground_status", []))
	if not ground_status.contains("left_hit=true") or not ground_status.contains("right_hit=true"):
		_fail("Both feet should detect the static floor through their physics-space probes")
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
	floor_body.free()

func _fail(message: String) -> void:
	_failed = true
	push_error(message)
