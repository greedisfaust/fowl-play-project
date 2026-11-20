## Headless checks for M7.1 jab gameplay and M7.2 presentation/recoil behavior.
extends SceneTree
const PLAYER_SCENE: PackedScene = preload("res://player/player.tscn")
const TUNING = preload("res://core/tuning.gd")
const LAYERS = preload("res://core/layers.gd")
const COMBAT_CONTROLLER = preload("res://combat/combat_controller.gd")
const HIT_DETECTOR = preload("res://combat/combat_hit_detector.gd")
const COMBAT_PRESENTATION = preload("res://combat/combat_presentation.gd")
const NETWORK = preload("res://core/network.gd")
var _failed: bool = false
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	_check_tap_window()
	_check_jab_endpoint()
	_check_presentation_curves()
	await _check_world_hit_and_recoil()
	if _failed:
		quit(1)
		return
	print("M7.2 jab presentation and M7.1 jab checks passed")
	quit(0)
func _check_tap_window() -> void:
	if not COMBAT_CONTROLLER.is_jab_tap(0.10):
		_fail("A short press/release should qualify as a jab")
	if not COMBAT_CONTROLLER.is_jab_tap(TUNING.TAP_MAX_SECONDS):
		_fail("The exact tap threshold should still qualify as a jab")
	if COMBAT_CONTROLLER.is_jab_tap(TUNING.TAP_MAX_SECONDS + 0.001):
		_fail("A hold beyond the tap threshold must not fire a jab")
	if COMBAT_CONTROLLER.is_jab_tap(-0.01) or COMBAT_CONTROLLER.is_jab_tap(INF):
		_fail("Invalid hold durations must not qualify as a jab")
func _check_jab_endpoint() -> void:
	var origin: Vector3 = Vector3(1.0, 2.0, 3.0)
	var endpoint: Vector3 = HIT_DETECTOR.get_jab_endpoint(origin, Vector3(0.0, 0.0, -4.0), TUNING.QUICK_PUNCH_RANGE_M)
	if not endpoint.is_equal_approx(origin + Vector3(0.0, 0.0, -TUNING.QUICK_PUNCH_RANGE_M)):
		_fail("The jab ray should normalize aim direction and use the configured range")
	if not HIT_DETECTOR.get_jab_endpoint(origin, Vector3.ZERO, 2.0).is_equal_approx(origin):
		_fail("A zero direction must not produce a jab ray")
func _check_presentation_curves() -> void:
	var windup: Vector3 = COMBAT_PRESENTATION.get_jab_body_pose(0.0, Vector3.FORWARD)
	var extension: Vector3 = COMBAT_PRESENTATION.get_jab_body_pose(COMBAT_PRESENTATION.JAB_EXTENSION_END_S, Vector3.FORWARD)
	var follow_through: Vector3 = COMBAT_PRESENTATION.get_jab_body_pose(COMBAT_PRESENTATION.JAB_EXTENSION_END_S + COMBAT_PRESENTATION.JAB_CONTACT_HOLD_S, Vector3.FORWARD)
	var returned: Vector3 = COMBAT_PRESENTATION.get_jab_body_pose(COMBAT_PRESENTATION.JAB_POSE_DURATION_S, Vector3.FORWARD)
	var base_hand_offset: Vector3 = Vector3(-0.025, -0.025, 0.075)
	var windup_hand: Vector3 = COMBAT_PRESENTATION.get_windup_hand_offset(base_hand_offset, 0.20)
	var jab_start_hand: Vector3 = COMBAT_PRESENTATION.get_jab_hand_offset(base_hand_offset, 0.0)
	var jab_extension_hand: Vector3 = COMBAT_PRESENTATION.get_jab_hand_offset(base_hand_offset, COMBAT_PRESENTATION.JAB_EXTENSION_END_S)
	var jab_return_hand: Vector3 = COMBAT_PRESENTATION.get_jab_hand_offset(base_hand_offset, COMBAT_PRESENTATION.JAB_POSE_DURATION_S)
	if windup.x >= 0.0 or extension.x <= 0.0:
		_fail("Jab presentation should move from anticipation lean into a forward extension")
	if windup_hand.z <= base_hand_offset.z or jab_start_hand.z <= base_hand_offset.z or jab_extension_hand.z >= base_hand_offset.z or not jab_return_hand.is_equal_approx(base_hand_offset):
		_fail("Fist should pull back, extend forward, and return to its authored offset")
	if follow_through.x <= 0.0:
		_fail("Jab should hold a readable forward follow-through")
	if absf(returned.x) > 0.001 or absf(returned.y) > 0.001 or absf(returned.z) > 0.001:
		_fail("Jab body pose should return smoothly to neutral")
	if not is_equal_approx(COMBAT_PRESENTATION.JAB_POSE_DURATION_S, 0.21) or not is_equal_approx(COMBAT_PRESENTATION.JAB_EXTENSION_END_S, 0.058) or COMBAT_PRESENTATION.JAB_EXTENSION_END_S >= COMBAT_PRESENTATION.JAB_POSE_DURATION_S:
		_fail("Jab should use a compact 0.21 s pose with a fast, readable extension")
	var recoil_peak: Vector3 = COMBAT_PRESENTATION.get_recoil_body_pose(0.0, Vector3.FORWARD, 1.0)
	var recoil_overshoot: Vector3 = COMBAT_PRESENTATION.get_recoil_body_pose(0.20, Vector3.FORWARD)
	var recoil_end: Vector3 = COMBAT_PRESENTATION.get_recoil_body_pose(COMBAT_PRESENTATION.RECOIL_POSE_DURATION_S, Vector3.FORWARD)
	if recoil_peak.x >= -0.05 or recoil_overshoot.x <= 0.0 or recoil_end.length() > 0.001:
		_fail("Torso recoil should snap, spring past neutral, and settle cleanly")
	var stronger_recoil: Vector3 = COMBAT_PRESENTATION.get_recoil_body_pose(0.0, Vector3.FORWARD, 1.35)
	if stronger_recoil.x >= recoil_peak.x:
		_fail("Higher impact strength should visibly increase the recoil pose")
	if not is_equal_approx(NETWORK.get_jab_impact_strength(Vector3.ZERO, Vector3.FORWARD), 1.0):
		_fail("A stationary attacker should use baseline jab impact strength")
	if not is_equal_approx(NETWORK.get_jab_impact_strength(Vector3(0.0, 0.0, -8.0), Vector3.FORWARD), 1.35):
		_fail("A fast attacker moving into the target should reach the bounded maximum strength")
	if not is_equal_approx(NETWORK.get_jab_impact_strength(Vector3(8.0, 0.0, 0.0), Vector3.FORWARD), 1.0):
		_fail("Sideways attacker movement should not increase jab strength")

func _check_world_hit_and_recoil() -> void:
	var players: Node3D = Node3D.new()
	players.name = "Players"
	root.add_child(players)
	var attacker: CharacterBody3D = PLAYER_SCENE.instantiate() as CharacterBody3D
	attacker.name = "1"
	attacker.set("input_peer_id", 1)
	players.add_child(attacker)
	attacker.global_position = Vector3.ZERO
	attacker.set_physics_process(false)
	var target: CharacterBody3D = PLAYER_SCENE.instantiate() as CharacterBody3D
	target.name = "2"
	target.set("input_peer_id", 2)
	players.add_child(target)
	target.global_position = Vector3(0.0, 0.0, -1.5)
	for frame_index: int in range(4):
		await physics_frame
	var mask: int = HIT_DETECTOR.get_jab_collision_mask()
	if (mask & (1 << (LAYERS.WORLD_STATIC - 1))) == 0 or (mask & (1 << (LAYERS.DEVICES - 1))) == 0 or (mask & (1 << (LAYERS.CARRIED - 1))) == 0 or (mask & (1 << (LAYERS.ELEVATOR - 1))) == 0:
		_fail("Jab ray should include world, device, carried-prop and elevator layers so obstacles block hits")
	var network: Node = root.get_node("Network")
	var target_position_before_recoil: Vector3 = target.global_position
	var jab_count_before_cancel: int = int(network.get("combat_jabs"))
	if not bool(network.call("_receive_combat_input", 1, true)):
		_fail("Host should accept a punch press before cancellation")
	if not bool(network.call("_receive_combat_cancel", 1)):
		_fail("Host should accept an explicit combat-input cancellation")
	var press_times: Dictionary = network.get("_combat_press_times")
	if int(network.get("combat_jabs")) != jab_count_before_cancel or press_times.has(1):
		_fail("Cancelling a wind-up must not accidentally fire a jab or leave the press latched")
	if not bool(network.call("_receive_combat_input", 1, true)):
		_fail("Host should accept the local player's punch press")
	for frame_index: int in range(3):
		await physics_frame
	if not bool(network.call("_receive_combat_input", 1, false)):
		_fail("A short host-timed press/release should accept a jab")
	for frame_index: int in range(10):
		await physics_frame
	if int(network.get("combat_jabs")) != 1 or int(network.get("combat_hits")) != 1:
		_fail("A clear in-range jab should be accepted and confirm exactly one hit")
	if absf(target.velocity.x) > 0.05 or absf(target.velocity.z) > 0.05:
		_fail("A weak jab torso reaction must not add player-root movement velocity")
	if target.global_position.distance_to(target_position_before_recoil) > 0.08:
		_fail("A weak jab torso reaction must not push the player root backward")
	target.set("auto_recovery_enabled", false)
	if not bool(network.call("start_ragdoll_spike", 2)):
		_fail("The test target should enter host-simulated limp")
		return
	for frame_index: int in range(12):
		await physics_frame
	var rig: Node3D = target.get_node("Rig") as Node3D
	var limp_elapsed_before: float = float(target.get("_limp_elapsed_s"))
	var bones: Array = rig.get("physical_bones")
	if bones.is_empty():
		_fail("The limp rig should expose its physical bones")
	else:
		var hit_bone: PhysicalBone3D = bones[0] as PhysicalBone3D
		var before_velocity: Vector3 = hit_bone.linear_velocity
		var impulse_applied: bool = bool(rig.call("apply_combat_impulse", Vector3(0.0, 0.0, -1.0), hit_bone.global_position, TUNING.JAB_LIMP_IMPULSE_MPS))
		if not impulse_applied:
			_fail("A jab should apply a physical impulse to an already-limp body")
		if (hit_bone.linear_velocity - before_velocity).dot(Vector3(0.0, 0.0, -1.0)) <= 1.0:
			_fail("The struck limp physical bone should receive a forward velocity change")
		if not is_equal_approx(float(target.get("_limp_elapsed_s")), limp_elapsed_before):
			_fail("A limp-player jab must not reset or extend the recovery timer")
	players.queue_free()

func _fail(message: String) -> void:
	_failed = true
	push_error(message)
