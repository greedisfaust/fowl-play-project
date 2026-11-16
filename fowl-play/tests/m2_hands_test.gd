## Headless M2 checks for the scene-backed hand controller API.
## Verifies state changes, reach throttling, and debug registration without creating geometry.

extends SceneTree

var _failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var hand: Hand = Hand.new()
	hand.name = "M2TestHand"
	root.add_child(hand)
	hand.set_color(Color(0.2, 0.4, 0.8, 1.0))
	hand.set_hover(true, Vector3(1.0, 0.0, -2.0))
	hand.set_guard(true)
	hand.set_speed(3.0)
	hand.set_carrying(true)
	hand.set_limp(true)
	if not hand.is_hovering or not hand.is_guarding or not hand.is_carrying or not hand.is_limp:
		_fail("Hand state API did not apply state changes")
	if hand.speed_mps != 3.0:
		_fail("Hand speed state was not stored")
	if hand.reach(Vector3(0, 0, -2)):
		_fail("Limp/guard/carry should reject reach")
	hand.set_limp(false)
	hand.set_guard(false)
	hand.set_carrying(false)
	if not hand.reach(Vector3(0, 0, -2)):
		_fail("First hand reach was unexpectedly throttled")
	if hand.reach(Vector3.ZERO):
		_fail("Hand reach cooldown did not throttle a repeated reach")
	if hand.get_node_or_null("MissingNode") != null:
		_fail("Unexpected hand test node exists")
	if not hand.get_node("/root/DebugHub").get_command_names().has(&"hand_status_M2TestHand"):
		_fail("Hand status command was not registered")
	hand.free()
	_check_scene_poses()
	_check_isolation_and_aim()
	_check_authored_thumb()
	if _failed:
		quit(1)
		return
	print("M2 hand checks passed")
	quit(0)

func _fail(message: String) -> void:
	_failed = true
	push_error(message)

func _check_authored_thumb() -> void:
	var scene: PackedScene = load("res://hands/hand.tscn") as PackedScene
	var study_scene: PackedScene = load("res://hands/hand_pose_study.tscn") as PackedScene
	# Read the study off-tree so its attached controller cannot animate the reference.
	var study: Node3D = study_scene.instantiate() as Node3D
	var hand: Hand = scene.instantiate() as Hand
	root.add_child(hand)
	hand.set_process(false)
	# Existing preview overrides must not replace the newly approved pose.
	hand.guard_thumb_root_degrees = Vector3(-5, -80, 0)
	hand.guard_thumb_curl_degrees = Vector2(-10, -20)
	hand.set_guard(true)
	for frame: int in 90:
		hand._process(1.0 / 60.0)
	for path: String in ["PoseRoot/ThumbRoot", "PoseRoot/ThumbRoot/ThumbJoint1", "PoseRoot/ThumbRoot/ThumbJoint1/ThumbJoint2"]:
		var actual: Node3D = hand.get_node(path) as Node3D
		var expected: Node3D = study.get_node(path) as Node3D
		if actual.quaternion.angle_to(expected.quaternion) > 0.001 or actual.position.distance_to(expected.position) > 0.00001:
			_fail("Guard thumb differs from approved study: %s angle=%s position=%s actual=%s expected=%s" % [path, actual.quaternion.angle_to(expected.quaternion), actual.position.distance_to(expected.position), actual.quaternion, expected.quaternion])
	hand.set_guard(false)
	hand.point_thumb_root_degrees = Vector3(-5, -55, 0)
	hand.point_thumb_curl_degrees = Vector2(-8, -12)
	hand.set_hover(true, Vector3(0, 0, -2))
	hand._process(1.0)
	for path: String in ["PoseRoot/ThumbRoot", "PoseRoot/ThumbRoot/ThumbJoint1", "PoseRoot/ThumbRoot/ThumbJoint1/ThumbJoint2"]:
		var actual: Node3D = hand.get_node(path) as Node3D
		var expected: Node3D = study.get_node(path) as Node3D
		if actual.quaternion.angle_to(expected.quaternion) > 0.001:
			_fail("Point thumb differs from approved study: %s" % path)
	for finger: String in ["Middle", "Ring", "Pinky"]:
		var path: String = "PoseRoot/" + finger
		for index: int in 3:
			path += "/Joint%d" % (index + 1)
			var joint: Node3D = hand.get_node(path) as Node3D
			if absf(joint.rotation_degrees.x - hand.guard_curl_degrees[index]) > 0.1:
				_fail("Point finger does not match guard curl: %s" % path)
	hand.set_hover(false, Vector3.ZERO)
	hand._process(1.0)
	var thumb: Node3D = hand.get_node("PoseRoot/ThumbRoot") as Node3D
	var study_thumb: Node3D = study.get_node("PoseRoot/ThumbRoot") as Node3D
	if thumb.quaternion.angle_to(study_thumb.quaternion) < 0.01:
		_fail("Thumb remained stuck in authored guard pose")
	hand.free()
	study.free()

func _check_isolation_and_aim() -> void:
	var scene: PackedScene = load("res://hands/hand.tscn") as PackedScene
	var holder: Node3D = Node3D.new()
	root.add_child(holder)
	var first: Hand = scene.instantiate() as Hand
	var second: Hand = scene.instantiate() as Hand
	root.add_child(first)
	holder.add_child(second)
	first.set_process(false)
	second.set_process(false)
	var hub: Node = root.get_node("DebugHub")
	var second_command: StringName = second._pose_command_name
	if first._pose_command_name == second_command:
		_fail("Same-named hands share a debug command")
	var mesh: GeometryInstance3D = first.get_node("PoseRoot/Wrist") as GeometryInstance3D
	var other_mesh: GeometryInstance3D = second.get_node("PoseRoot/Wrist") as GeometryInstance3D
	var original: Material = mesh.material_override
	first.set_color(Color(0.2, 0.4, 0.8, 0.1))
	var tinted: BaseMaterial3D = mesh.material_override as BaseMaterial3D
	if other_mesh.material_override != original or mesh.material_override == original:
		_fail("Tint changed shared materials")
	if tinted.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or tinted.albedo_color.a != 1.0:
		_fail("Tint is not opaque")
	var first_color: Color = tinted.albedo_color
	first.set_color(Color(0.2, 0.4, 0.8))
	if not (mesh.material_override as BaseMaterial3D).albedo_color.is_equal_approx(first_color):
		_fail("Repeated tint compounded material darkness")
	var aim: Node3D = first.get_node("PoseRoot/IndexAim") as Node3D
	first.set_hover(true, aim.global_position + Vector3(10, 10, -1))
	first._process(0.016)
	var initial_angle: float = aim.quaternion.angle_to(Quaternion.IDENTITY)
	if initial_angle <= 0.0 or initial_angle >= deg_to_rad(first.index_aim_limit_degrees):
		_fail("Aim snapped or did not move")
	first._process(1.0)
	if aim.quaternion.angle_to(Quaternion.IDENTITY) > deg_to_rad(first.index_aim_limit_degrees) + 0.001:
		_fail("Aim exceeded its angular limit")
	first.set_hover(false, Vector3.ZERO)
	first._process(1.0)
	if aim.quaternion.angle_to(Quaternion.IDENTITY) > 0.001:
		_fail("Aim failed to return to rest")
	first.free()
	if not hub.get_command_names().has(second_command):
		_fail("Removing one hand removed another hand's command")
	hub.execute_command(second_command, ["guard"])
	if not second.is_guarding:
		_fail("Remaining hand command no longer works")
	holder.free()
	if hub.get_command_names().has(second_command):
		_fail("Hand command leaked after cleanup")

func _check_scene_poses() -> void:
	var scene: PackedScene = load("res://hands/hand.tscn") as PackedScene
	var instance: Node3D = scene.instantiate() as Node3D
	instance.set_script(load("res://hands/hand.gd"))
	var hand: Hand = instance as Hand
	hand.name = "ScenePoseTest"
	root.add_child(hand)
	hand.set_process(false)
	var middle: Node3D = hand.get_node("PoseRoot/Middle/Joint1") as Node3D
	var index: Node3D = hand.get_node("PoseRoot/IndexAim/Index/Joint1") as Node3D
	var root_transform: Transform3D = hand.transform
	var pose: Node3D = hand.get_node("PoseRoot") as Node3D
	var thumb: Node3D = hand.get_node("PoseRoot/ThumbRoot") as Node3D
	var pose_rest: Transform3D = pose.transform
	var thumb_rest: Quaternion = thumb.quaternion
	hand._process(1.0)
	var thumb_idle: Quaternion = thumb.quaternion
	if thumb_idle.angle_to(thumb_rest) < 0.01:
		_fail("Idle thumb remained in the straight authored pose")
	hand.set_guard(true)
	hand._process(0.016)
	if pose.position.is_equal_approx(pose_rest.origin) or pose.position.is_equal_approx(pose_rest.origin + hand.guard_position_offset):
		_fail("Guard should blend rather than remain still or snap")
	hand._process(1.0)
	if thumb.quaternion.is_equal_approx(thumb_rest) or pose.quaternion.is_equal_approx(pose_rest.basis.get_rotation_quaternion()):
		_fail("Guard did not move thumb and whole hand")
	if absf(middle.rotation_degrees.x + 75.0) > 0.1:
		_fail("Scene finger did not curl into guard")
	hand.set_hover(true, Vector3(0.0, 0.0, -2.0))
	hand._process(1.0)
	if absf(index.rotation_degrees.x + 75.0) > 0.1:
		_fail("Hover incorrectly overrode guard")
	hand.set_guard(false)
	hand._process(1.0)
	if thumb.quaternion.angle_to(thumb_idle) < 0.01:
		_fail("Point thumb did not change from idle")
	if absf(index.rotation_degrees.x) > 0.1 or middle.rotation_degrees.x > -50.0:
		_fail("Point pose did not straighten only the index")
	hand.set_hover(false, Vector3.ZERO)
	hand._process(1.0)
	if absf(middle.rotation_degrees.x + 12.0) > 0.1:
		_fail("Finger did not return to relaxed pose")
	if hand.transform != root_transform:
		_fail("Finger poses moved the attachment root")
	if not pose.transform.is_equal_approx(pose_rest) or thumb.quaternion.angle_to(thumb_idle) > 0.001:
		_fail("Guard release did not restore relaxed pose")
	hand.set_guard(true)
	hand._process(1.0)
	hand.set_limp(true)
	hand._process(1.0)
	if not pose.transform.is_equal_approx(pose_rest) or thumb.quaternion.angle_to(thumb_rest) > 0.001:
		_fail("Limp did not override thumb and whole-hand guard")
	hand.set_limp(false)
	hand.set_guard(false)
	hand._process(1.0)
	if not hand.reach(hand.to_global(Vector3(1, 0, -2))):
		_fail("Scene reach was rejected")
	for frame: int in 6:
		hand._process(1.0 / 60.0)
	if pose.position.x <= pose_rest.origin.x or pose.position.z >= pose_rest.origin.z:
		_fail("Reach did not extend toward its target")
	if hand.reach(Vector3(0, 0, -2)):
		_fail("Active reach restarted")
	for frame: int in 90:
		hand._process(1.0 / 60.0)
	if not pose.position.is_equal_approx(pose_rest.origin) or hand.transform != root_transform:
		_fail("Reach failed to return or moved the attachment root")
	hand.free()
