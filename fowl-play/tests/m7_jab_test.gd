## Headless checks for M7.1 jab timing, ray targeting and limp impulse behavior.
extends SceneTree
const PLAYER_SCENE: PackedScene = preload("res://player/player.tscn")
const TUNING = preload("res://core/tuning.gd")
const LAYERS = preload("res://core/layers.gd")
const COMBAT_CONTROLLER = preload("res://combat/combat_controller.gd")
const HIT_DETECTOR = preload("res://combat/combat_hit_detector.gd")
var _failed: bool = false
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	_check_tap_window()
	_check_jab_endpoint()
	await _check_world_hit_and_recoil()
	if _failed:
		quit(1)
		return
	print("M7.1 jab checks passed")
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
func _check_world_hit_and_recoil() -> void:
	var arena: Node3D = load("res://arena/test_arena.tscn").instantiate() as Node3D
	root.add_child(arena)
	for frame_index: int in range(3):
		await physics_frame
	var players: Node3D = arena.get_node("Players") as Node3D
	var attacker: CharacterBody3D = players.get_node("1") as CharacterBody3D
	attacker.set_physics_process(false)
	var target: CharacterBody3D = PLAYER_SCENE.instantiate() as CharacterBody3D
	target.name = "2"
	target.set("input_peer_id", 2)
	players.add_child(target)
	target.global_position = attacker.global_position + Vector3(0.0, 0.0, -1.5)
	for frame_index: int in range(3):
		await physics_frame
	var camera: Camera3D = attacker.get_node("Head/Camera3D") as Camera3D
	var result: Dictionary = HIT_DETECTOR.trace_jab(attacker, camera.global_position, -camera.global_basis.z, TUNING.QUICK_PUNCH_RANGE_M)
	if result.get("target") != target:
		_fail("A clear ray within range should identify the target Player")
	var mask: int = HIT_DETECTOR.get_jab_collision_mask()
	if (mask & (1 << (LAYERS.WORLD_STATIC - 1))) == 0 or (mask & (1 << (LAYERS.ELEVATOR - 1))) == 0:
		_fail("Jab ray should include static world and elevator layers so obstacles block hits")
	var network: Node = root.get_node("Network")
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
	if target.velocity.z >= -0.5:
		_fail("A standing target should receive a weak movement recoil")
	target.set("auto_recovery_enabled", false)
	var network: Node = root.get_node("Network")
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
	arena.queue_free()
func _fail(message: String) -> void:
	_failed = true
	push_error(message)
