## Headless checks for the local procedural leg gait and ragdoll ownership gate.
extends SceneTree

const TUNING = preload("res://core/tuning.gd")
const LEG_CONTROLLER_SCRIPT = preload("res://ragdoll/procedural_leg_controller.gd")
const FOOT_PLANT_SCRIPT = preload("res://ragdoll/procedural_foot_plant.gd")
const FOOTSTEP_PLANNER_SCRIPT = preload("res://ragdoll/procedural_footstep_planner.gd")
const LEG_IK = preload("res://ragdoll/procedural_arm_ik.gd")
const RIG_SCENE: PackedScene = preload("res://ragdoll/player_rig.tscn")

var _failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_check_controller_gait()
	_check_leg_reach_tuning()
	_check_footstep_planner()
	_check_foot_plant_targets()
	_check_emergency_replant()
	_check_two_bone_solver()
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
	var expected_phase: float = (5.0 / TUNING.LEG_STEP_CYCLE_DISTANCE_M) * TAU * TUNING.LEG_GAIT_RATE_MULTIPLIER * 0.125
	if not is_equal_approx(phase_after_walk, expected_phase):
		_fail("Gait phase should advance at the configured stride cadence")
	if TUNING.LEG_STEP_CYCLE_DISTANCE_M >= 1.6:
		_fail("Stride cycle distance should keep planted feet from exceeding natural reach before swing begins")
	var stance_travel_m: float = TUNING.LEG_STEP_CYCLE_DISTANCE_M * TUNING.LEG_STANCE_FRACTION
	var natural_leg_reach_m: float = 0.84 + TUNING.LEG_REPLANT_EXTRA_STRETCH_M
	if stance_travel_m >= natural_leg_reach_m:
		_fail("A stance foot should enter its next swing before the player outruns natural leg reach")
	if left_thigh.angle_to(Quaternion.IDENTITY) < 0.1:
		_fail("Walking should move the left thigh away from its rest rotation")
	if right_thigh.angle_to(Quaternion.IDENTITY) < 0.1:
		_fail("Walking should move the right thigh away from its rest rotation")
	if left_thigh.angle_to(right_thigh) < 0.2:
		_fail("Left and right legs should alternate their swing")
	var left_forward: Vector3 = left_thigh * Vector3.DOWN
	if left_forward.z >= -0.05:
		_fail("Forward walking should swing the leg toward the character's forward axis")

	# Rapid WASD-style direction changes should update the planner heading
	# quickly rather than averaging several old directions into a stale vector.
	var zigzag_controller: RefCounted = LEG_CONTROLLER_SCRIPT.new()
	var zigzag_directions: Array[Vector3] = [
		Vector3(0.0, 0.0, -5.0),
		Vector3(5.0, 0.0, 0.0),
		Vector3(0.0, 0.0, 5.0),
		Vector3(-5.0, 0.0, 0.0)
	]
	for repeat_index: int in range(3):
		for zigzag_direction: Vector3 in zigzag_directions:
			zigzag_controller.call("update", 0.05, zigzag_direction, true)
			var filtered_direction: Vector3 = zigzag_controller.get("smoothed_velocity")
			if filtered_direction.length_squared() < 0.01 or filtered_direction.normalized().dot(zigzag_direction.normalized()) < 0.80:
				_fail("Rapid directional changes should quickly redirect the footstep planner without stale heading")
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

	# A stop in mid-swing must complete into a stable two-foot stance. Otherwise
	# the foot target tracker can keep one shoe suspended indefinitely.
	var settling_controller: RefCounted = LEG_CONTROLLER_SCRIPT.new()
	settling_controller.set("phase", TAU * 0.80)
	settling_controller.set("motion_weight", 1.0)
	for settle_frame: int in range(120):
		settling_controller.call("update", 1.0 / 60.0, Vector3.ZERO, true)
	if bool(settling_controller.get("left_in_swing")) or bool(settling_controller.get("right_in_swing")):
		_fail("A stopped gait should settle both feet into stance")
	if absf(float(settling_controller.get("phase")) - PI) > 0.001:
		_fail("A stopped gait should settle at the shared double-stance phase")

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
	var swing_knee: Quaternion = controller.get("left_shin_rotation")
	if swing_knee.angle_to(Quaternion.IDENTITY) < deg_to_rad(20.0):
		_fail("The knee should visibly bend during the lifted portion of swing")
	if float(controller.get("left_swing_progress")) <= 0.0:
		_fail("Swing phase should expose a normalized progress value")
	if float(controller.get("left_knee_bend_weight")) <= 0.1:
		_fail("Swing knee bend weight should be exposed for the IK pole to preserve the walking bend")

	if bool(controller.get("right_in_swing")) == bool(controller.get("left_in_swing")):
		_fail("Opposite feet should occupy opposite gait phases")


func _check_footstep_planner() -> void:
	var planner: RefCounted = FOOTSTEP_PLANNER_SCRIPT.new()
	var hip: Vector3 = Vector3(2.0, 1.0, 3.0)
	var forward_left: Vector3 = planner.call(
		"get_landing_target", hip, Basis.IDENTITY, Vector3(0.0, 0.0, -5.0), 1.0
	)
	if forward_left.distance_to(Vector3(2.18, 1.0, 2.64)) > 0.001:
		_fail("Forward foot targets should be placed ahead of the hips with left/right separation")
	var forward_right: Vector3 = planner.call(
		"get_landing_target", hip, Basis.IDENTITY, Vector3(0.0, 0.0, -5.0), -1.0
	)
	if forward_right.distance_to(Vector3(1.82, 1.0, 2.64)) > 0.001:
		_fail("Right foot target should mirror the left foot's lateral offset")
	var predicted_landing: Vector3 = planner.call(
		"get_landing_target", hip, Basis.IDENTITY, Vector3(0.0, 0.0, -5.0), 1.0,
		0.0, 0.18, 0.756
	)
	if predicted_landing.distance_to(Vector3(2.18, 1.0, 2.244)) > 0.001:
		_fail("Predicted swing travel should move the landing target ahead of the current hip position")
	var planned_step: Vector3 = planner.call(
		"get_landing_target", hip, Basis.IDENTITY, Vector3(0.0, 0.0, -5.0), 1.0,
		TUNING.LEG_NORMAL_FORWARD_PLACEMENT_M, 0.24,
		TUNING.LEG_STEP_CYCLE_DISTANCE_M * (1.0 - TUNING.LEG_STANCE_FRACTION)
	)
	var expected_planned_step: Vector3 = Vector3(2.24, 1.0, 2.012)
	if planned_step.distance_to(expected_planned_step) > 0.001:
		_fail("Normal steps should land ahead of the hip after predicted swing travel to prevent stance drag")
	var predicted_replant: Vector3 = planner.call(
		"get_landing_target", hip, Basis.IDENTITY, Vector3(0.0, 0.0, -5.0), 1.0,
		TUNING.LEG_EMERGENCY_FORWARD_PLACEMENT_M, TUNING.LEG_MIN_LANDING_LATERAL_M,
		5.0 * TUNING.LEG_REPLANT_RECOVERY_SECONDS
	)
	if predicted_replant.z > hip.z - 1.0:
		_fail("Emergency replant should predict player travel during its recovery arc")
	var strafe: Vector3 = planner.call(
		"get_landing_target", hip, Basis.IDENTITY, Vector3(5.0, 0.0, 0.0), -1.0
	)
	if strafe.x <= hip.x or strafe.z <= hip.z:
		_fail("Rightward strafing should move the right foot ahead while keeping its front/back lane")
	var strafe_left: Vector3 = planner.call(
		"get_landing_target", hip, Basis.IDENTITY, Vector3(5.0, 0.0, 0.0), 1.0
	)
	if strafe_left.x <= hip.x or strafe_left.z >= hip.z or strafe_left.distance_to(strafe) < 0.35:
		_fail("Sideways foot lanes should separate along the character's forward axis instead of crossing the centerline")
	var left_strafe_right: Vector3 = planner.call(
		"get_landing_target", hip, Basis.IDENTITY, Vector3(-5.0, 0.0, 0.0), -1.0
	)
	var left_strafe_left: Vector3 = planner.call(
		"get_landing_target", hip, Basis.IDENTITY, Vector3(-5.0, 0.0, 0.0), 1.0
	)
	if left_strafe_right.x >= hip.x or left_strafe_right.z <= hip.z or left_strafe_left.z >= hip.z:
		_fail("Leftward strafing should mirror rightward travel while preserving the same front/back foot lanes")
	var diagonal_left: Vector3 = planner.call(
		"get_landing_target", hip, Basis.IDENTITY, Vector3(5.0, 0.0, -5.0), 1.0
	)
	var diagonal_right: Vector3 = planner.call(
		"get_landing_target", hip, Basis.IDENTITY, Vector3(5.0, 0.0, -5.0), -1.0
	)
	if diagonal_left.distance_to(diagonal_right) < 0.35:
		_fail("Diagonal foot targets should preserve minimum left/right separation")
	var backward: Vector3 = planner.call(
		"get_landing_target", hip, Basis.IDENTITY, Vector3(0.0, 0.0, 5.0), 1.0
	)
	if backward.z <= hip.z:
		_fail("Backward movement should place the landing target behind the hips")
	var rotated_basis: Basis = Basis(Vector3.UP, PI * 0.5)
	var rotated_forward: Vector3 = planner.call(
		"get_landing_target", hip, rotated_basis, Vector3(0.0, 0.0, -5.0), 1.0
	)
	if rotated_forward.x >= hip.x:
		_fail("Footstep targets should respect the rig's world-facing orientation")

	var crossed_left: Vector3 = planner.call("constrain_anatomical_side", hip, hip, Basis.IDENTITY, 1.0, 0.20)
	var crossed_right: Vector3 = planner.call("constrain_anatomical_side", hip, hip, Basis.IDENTITY, -1.0, 0.20)
	if crossed_left.x < hip.x + 0.199:
		_fail("Forward-walking left landing targets must remain on the rig's positive-X side")
	if crossed_right.x > hip.x - 0.199:
		_fail("Forward-walking right landing targets must remain on the rig's negative-X side")
	var strafe_constrained_left: Vector3 = planner.call(
		"constrain_anatomical_side", hip, hip, Basis.IDENTITY, 1.0, 0.20, Vector3(5.0, 0.0, 0.0)
	)
	var strafe_constrained_right: Vector3 = planner.call(
		"constrain_anatomical_side", hip, hip, Basis.IDENTITY, -1.0, 0.20, Vector3(5.0, 0.0, 0.0)
	)
	if strafe_constrained_left.z >= hip.z - 0.199 or strafe_constrained_right.z <= hip.z + 0.199:
		_fail("Sideways replant constraints must use stable front/back lanes instead of anatomical left/right lanes")

func _check_foot_plant_targets() -> void:
	var tracker: RefCounted = FOOT_PLANT_SCRIPT.new()
	var current: Vector3 = Vector3(0.0, 0.1, 0.0)
	var first_landing: Vector3 = Vector3(0.0, 0.05, 0.0)
	var planted: Vector3 = tracker.call("update_target", current, first_landing, true, false, 0.0, 0.28)
	if planted.distance_to(first_landing) > 0.001:
		_fail("A new stance should capture the grounded landing target")

	var moved_root_foot: Vector3 = current + Vector3(0.0, 0.0, -0.4)
	var locked: Vector3 = tracker.call("update_target", moved_root_foot, first_landing, true, false, 0.0, 0.28)
	if locked.distance_to(first_landing) > 0.001:
		_fail("A planted foot should remain locked in world space while the player moves")

	var next_landing: Vector3 = Vector3(0.0, 0.05, -0.8)
	var swing_start: Vector3 = tracker.call("update_target", moved_root_foot, next_landing, true, true, 0.0, 0.28)
	if swing_start.distance_to(first_landing) > 0.001:
		_fail("A swing should begin at the previous planted anchor")
	var drifting_probe: Vector3 = next_landing + Vector3(0.0, 0.0, -0.25)
	var swing_middle: Vector3 = tracker.call("update_target", moved_root_foot, drifting_probe, true, true, 0.5, 0.28)
	if swing_middle.z >= first_landing.z or swing_middle.z <= next_landing.z:
		_fail("The swing target should interpolate between the old and next foot positions")
	if swing_middle.distance_to((first_landing + next_landing) * 0.5 + Vector3.UP * 0.28) > 0.001:
		_fail("A swing should retain its captured landing target instead of chasing a moving ground probe")
	if swing_middle.y <= first_landing.y:
		_fail("The swing target should lift above the ground during mid-swing")
	var landed: Vector3 = tracker.call("update_target", next_landing, drifting_probe, true, false, 0.0, 0.28)
	if landed.distance_to(next_landing) > 0.001:
		_fail("The foot should lock to its new landing point when stance begins")

	var airborne: Vector3 = tracker.call("update_target", next_landing + Vector3.UP, next_landing, false, false, 0.0, 0.28)
	if airborne.distance_to(next_landing + Vector3.UP) > 0.001:
		_fail("Foot planting should yield to the current foot position while airborne")

	# A planted foot on a moving support must follow the support's local contact point.
	var moving_support: Node3D = Node3D.new()
	root.add_child(moving_support)
	var moving_tracker: RefCounted = FOOT_PLANT_SCRIPT.new()
	var support_contact: Vector3 = Vector3(0.2, 0.05, 0.1)
	var initial_support_target: Vector3 = moving_tracker.call(
		"update_target", support_contact, support_contact, true, false, 0.0, 0.28,
		0.0, Vector3.ZERO, 1000000.0, 0.18, false, moving_support
	)
	moving_support.position = Vector3(1.0, 0.0, 0.0)
	var carried_support_target: Vector3 = moving_tracker.call(
		"update_target", initial_support_target, support_contact, true, false, 0.0, 0.28,
		0.0, Vector3.ZERO, 1000000.0, 0.18, false, moving_support
	)
	if not is_equal_approx(carried_support_target.x, initial_support_target.x + 1.0):
		_fail("A planted foot should follow a translating moving support without sliding")
	moving_support.rotation.y = PI * 0.5
	var rotated_support_target: Vector3 = moving_tracker.call(
		"update_target", carried_support_target, support_contact, true, false, 0.0, 0.28,
		0.0, Vector3.ZERO, 1000000.0, 0.18, false, moving_support
	)
	if rotated_support_target.distance_to(moving_support.global_transform * support_contact) > 0.001:
		_fail("A planted foot should preserve its local contact point when its support rotates")
	moving_support.queue_free()

func _check_emergency_replant() -> void:
	var tracker: RefCounted = FOOT_PLANT_SCRIPT.new()
	var planted_foot: Vector3 = Vector3(-0.2, 0.05, 0.0)
	var hip: Vector3 = Vector3(-0.2, 0.85, 0.0)
	tracker.call("update_target", planted_foot, planted_foot, true, false, 0.0, 0.12)
	if not bool(tracker.call("needs_replant", hip, 0.72)):
		_fail("A planted foot beyond comfortable leg reach should request an emergency replant")
	var new_landing: Vector3 = Vector3(-0.2, 0.05, -0.2)
	var recovery_midpoint: Vector3 = tracker.call(
		"update_target", planted_foot, new_landing, true, false, 0.0, 0.12,
		0.09, hip, 0.72, 0.18, true
	)
	if not bool(tracker.get("emergency_replant_active")):
		_fail("Emergency replant should enter its own recovery swing")
	if recovery_midpoint.y <= planted_foot.y:
		_fail("Emergency recovery should lift the foot instead of teleporting it")
	var recovered: Vector3 = tracker.call(
		"update_target", planted_foot, new_landing, true, false, 0.0, 0.12,
		0.09, hip, 0.72, 0.18, false
	)
	if recovered.distance_to(new_landing) > 0.001 or bool(tracker.get("emergency_replant_active")):
		_fail("Emergency recovery should capture its new ground anchor when complete")

func _check_leg_reach_tuning() -> void:
	if TUNING.LEG_IK_MAX_STRETCH_RATIO < 1.10 or TUNING.LEG_IK_MAX_STRETCH_RATIO > 1.20:
		_fail("Leg IK stretch should stay within a modest visual compensation range")
	if TUNING.LEG_REPLANT_LIFT_M < 0.25:
		_fail("Swing and emergency replant arcs should visibly clear the floor")
	if TUNING.LEG_MAX_KNEE_BEND_RAD < deg_to_rad(60.0):
		_fail("Walking knee flex should be pronounced enough to read as a step")

func _check_two_bone_solver() -> void:
	var hip: Vector3 = Vector3(0.0, 1.0, 0.0)
	var foot: Vector3 = Vector3(0.0, 0.2, 0.0)
	var pole: Vector3 = Vector3(0.0, 0.0, -1.0)
	var solution: Dictionary = LEG_IK.solve_two_bone(hip, foot, pole, 0.42, 0.42)
	if solution.is_empty():
		_fail("Two-bone IK should solve a reachable leg target")
		return
	var knee: Vector3 = solution["elbow"]
	if not is_equal_approx(knee.distance_to(hip), 0.42) or not is_equal_approx(knee.distance_to(foot), 0.42):
		_fail("Two-bone IK should preserve both authored leg segment lengths")
	if knee.z >= 0.0:
		_fail("The leg pole should bend the knee toward the character's forward side")
	# Left and right knee poles must bend away from the body's centerline,
	# while retaining a forward component for a natural walking knee.
	var left_hip: Vector3 = Vector3(0.1, 1.0, 0.0)
	var left_foot: Vector3 = Vector3(0.2, 0.0, -0.25)
	var left_pole: Vector3 = Vector3(0.18, 0.0, -1.0)
	var left_solution: Dictionary = LEG_IK.solve_two_bone(left_hip, left_foot, left_pole, 0.42, 0.42)
	var left_knee_position: Vector3 = left_solution.get("elbow", Vector3.ZERO)
	if left_solution.is_empty() or left_knee_position.x <= left_hip.x or left_knee_position.z >= left_hip.z:
		_fail("The left knee should bend forward with a mild outward angle")
	var right_hip: Vector3 = Vector3(-0.1, 1.0, 0.0)
	var right_foot: Vector3 = Vector3(-0.2, 0.0, -0.25)
	var right_pole: Vector3 = Vector3(-0.18, 0.0, -1.0)
	var right_solution: Dictionary = LEG_IK.solve_two_bone(right_hip, right_foot, right_pole, 0.42, 0.42)
	var right_knee_position: Vector3 = right_solution.get("elbow", Vector3.ZERO)
	if right_solution.is_empty() or right_knee_position.x >= right_hip.x or right_knee_position.z >= right_hip.z:
		_fail("The right knee should bend forward with a mild outward angle")
	var stretched_solution: Dictionary = LEG_IK.solve_two_bone(
		hip, Vector3(0.0, 0.1, 0.0), pole, 0.42 * 1.14, 0.42 * 1.14
	)
	if stretched_solution.is_empty() or bool(stretched_solution.get("clamped", true)):
		_fail("Modestly stretched leg segments should reach a farther planted-foot target")

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
	if not ground_status.contains("left_ik=true") or not ground_status.contains("right_ik=true"):
		_fail("Both planted feet should apply two-bone IK to their Skeleton3D chains")
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
