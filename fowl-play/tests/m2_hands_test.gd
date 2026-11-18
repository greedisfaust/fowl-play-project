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
	if hand._resolve_pose_state() != Hand.PoseState.LIMP:
		_fail("Limp must have the highest procedural pose priority")
	if hand.speed_mps != 3.0:
		_fail("Hand speed state was not stored")
	if hand.reach(Vector3(0, 0, -2)):
		_fail("Limp/guard/carry should reject reach")
	hand.set_limp(false)
	if hand._resolve_pose_state() != Hand.PoseState.CARRY:
		_fail("Carry must override guard and hover")
	hand.set_carrying(false)
	var grip_item: Node3D = Node3D.new()
	root.add_child(grip_item)
	grip_item.global_position = Vector3(1.0, 0.5, -2.0)
	hand.set_carrying(true, grip_item, -1.0)
	var left_grip: Vector3 = hand._get_carry_pose_position()
	hand.set_carrying(true, grip_item, 1.0)
	var right_grip: Vector3 = hand._get_carry_pose_position()
	if left_grip.distance_to(right_grip) < 0.3:
		_fail("Left and right carry targets should approach opposite sides of the prop")
	hand.set_carrying(false)
	grip_item.free()
	_check_shape_aware_grip(hand)
	_check_individual_carry_finger_curls()
	if hand._resolve_pose_state() != Hand.PoseState.GUARD:
		_fail("Guard must override hover")
	hand.set_guard(false)
	if hand._resolve_pose_state() != Hand.PoseState.POINT:
		_fail("Hover must resolve to point when no higher-priority state is active")
	hand.set_hover(false, Vector3.ZERO)
	if hand._resolve_pose_state() != Hand.PoseState.IDLE:
		_fail("Cleared hover must resolve to idle")
	if not hand.reach(Vector3(0, 0, -2)):
		_fail("First hand reach was unexpectedly throttled")
	if hand._resolve_pose_state() != Hand.PoseState.REACH:
		_fail("Active poke must resolve above point and idle")
	if hand.reach(Vector3.ZERO):
		_fail("An active hand action should not restart from a second request")
	hand.finish_action(false)
	if hand._action_phase != Hand.HandActionPhase.RETURNING:
		_fail("Rejected interaction should transition the hand into recovery")
	hand._process(hand.action_return_seconds + 0.1)
	if hand._action_phase != Hand.HandActionPhase.NONE or hand._reach_amount > 0.001:
		_fail("Hand action recovery should return to its resting amount")
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

func _check_shape_aware_grip(hand: Hand) -> void:
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.8, 0.8, 0.8)
	var box_prop: Node3D = _make_grip_test_prop(box, Vector3.ONE)
	hand.set_carrying(true, box_prop, -1.0)
	var full_size_left: Vector3 = hand._get_carry_pose_position()
	hand.set_carrying(true, box_prop, 1.0)
	var full_size_right: Vector3 = hand._get_carry_pose_position()
	var full_size_span: float = full_size_left.distance_to(full_size_right)
	var full_size_curl: Vector3 = hand._get_carry_finger_curl_degrees()
	var left_rotation: Quaternion = hand._get_carry_pose_rotation(full_size_left)
	var right_rotation: Quaternion = hand._get_carry_pose_rotation(full_size_right)
	var left_normal: Vector3 = hand.global_basis * (left_rotation * Vector3.DOWN)
	var right_normal: Vector3 = hand.global_basis * (right_rotation * Vector3.DOWN)
	var left_toward_item: Vector3 = (box_prop.global_position - hand.to_global(full_size_left)).normalized()
	var right_toward_item: Vector3 = (box_prop.global_position - hand.to_global(full_size_right)).normalized()
	if left_normal.dot(left_toward_item) < 0.99 or right_normal.dot(right_toward_item) < 0.99:
		_fail("Carry palm normals should face inward toward the prop on both sides")
	var rest_forearm_axis: Vector3 = hand.global_basis * (hand._pose_rest_rotation * Vector3.BACK)
	var left_forearm_axis: Vector3 = hand.global_basis * (left_rotation * Vector3.BACK)
	var right_forearm_axis: Vector3 = hand.global_basis * (right_rotation * Vector3.BACK)
	var left_forearm_flat: Vector3 = rest_forearm_axis - left_normal * rest_forearm_axis.dot(left_normal)
	var right_forearm_flat: Vector3 = rest_forearm_axis - right_normal * rest_forearm_axis.dot(right_normal)
	if left_forearm_flat.length_squared() > 0.0001 and left_forearm_axis.normalized().dot(left_forearm_flat.normalized()) < 0.99:
		_fail("Left carry wrist roll should preserve the forearm direction")
	if right_forearm_flat.length_squared() > 0.0001 and right_forearm_axis.normalized().dot(right_forearm_flat.normalized()) < 0.99:
		_fail("Right carry wrist roll should preserve the forearm direction")
	var collision: CollisionShape3D = box_prop.get_node("CollisionShape3D") as CollisionShape3D
	collision.scale = Vector3.ONE * 0.5
	hand.set_carrying(true, box_prop, -1.0)
	var half_size_left: Vector3 = hand._get_carry_pose_position()
	hand.set_carrying(true, box_prop, 1.0)
	var half_size_right: Vector3 = hand._get_carry_pose_position()
	var half_size_span: float = half_size_left.distance_to(half_size_right)
	var half_size_curl: Vector3 = hand._get_carry_finger_curl_degrees()
	if half_size_curl.length() <= full_size_curl.length():
		_fail("Smaller props should produce a tighter carry finger curl")
	if full_size_span <= half_size_span + 0.2:
		_fail("Scaled box collision bounds did not move the grip targets inward")
	if absf(full_size_span - 0.88) > 0.03 or absf(half_size_span - 0.48) > 0.03:
		_fail("Box grip span did not include collision dimensions and clearance: full=%s half=%s" % [full_size_span, half_size_span])
	box_prop.free()

	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 0.25
	var sphere_prop: Node3D = _make_grip_test_prop(sphere, Vector3.ONE)
	hand.set_carrying(true, sphere_prop, -1.0)
	var sphere_left: Vector3 = hand._get_carry_pose_position()
	hand.set_carrying(true, sphere_prop, 1.0)
	var sphere_right: Vector3 = hand._get_carry_pose_position()
	if absf(sphere_left.distance_to(sphere_right) - 0.58) > 0.04:
		_fail("Sphere grip did not use its collision radius")
	sphere_prop.free()

	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.2
	capsule.height = 0.8
	var capsule_prop: Node3D = _make_grip_test_prop(capsule, Vector3.ONE)
	hand.set_carrying(true, capsule_prop, -1.0)
	var capsule_left: Vector3 = hand._get_carry_pose_position()
	hand.set_carrying(true, capsule_prop, 1.0)
	var capsule_right: Vector3 = hand._get_carry_pose_position()
	if absf(capsule_left.distance_to(capsule_right) - 0.48) > 0.04:
		_fail("Capsule grip did not use its collision radius")
	hand.set_carrying(false)
	capsule_prop.free()

func _check_individual_carry_finger_curls() -> void:
	var hand_scene: PackedScene = load("res://hands/hand.tscn") as PackedScene
	var hand: Hand = hand_scene.instantiate() as Hand
	root.add_child(hand)
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.8, 0.8, 0.8)
	var prop: Node3D = Node3D.new()
	root.add_child(prop)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = box
	prop.add_child(collision)
	hand.set_carrying(true, prop, -1.0)
	var index_curl: Vector3 = hand._get_carry_finger_curl_degrees(0)
	var middle_curl: Vector3 = hand._get_carry_finger_curl_degrees(1)
	var ring_curl: Vector3 = hand._get_carry_finger_curl_degrees(2)
	var pinky_curl: Vector3 = hand._get_carry_finger_curl_degrees(3)
	var large_thumb_curl: Vector2 = hand._get_carry_thumb_curl_degrees()
	collision.scale = Vector3.ONE * 0.25
	var small_thumb_curl: Vector2 = hand._get_carry_thumb_curl_degrees()
	if small_thumb_curl.length() <= large_thumb_curl.length():
		_fail("Smaller props should produce a tighter thumb curl than large props")
	collision.scale = Vector3.ONE
	var thumb_rotation: Quaternion = hand._get_carry_thumb_root_rotation()
	var thumb_direction: Vector3 = thumb_rotation * Vector3.FORWARD
	var thumb_base: Node3D = hand._thumb_nodes[0]
	var thumb_target: Vector3 = hand._pose_root.to_local(prop.global_position) - thumb_base.position
	if thumb_direction.normalized().dot(thumb_target.normalized()) < 0.99:
		_fail("Carry thumb root should aim toward the prop from its authored mount")
	if index_curl.x >= middle_curl.x or pinky_curl.x >= ring_curl.x:
		_fail("Outer fingers should receive a slightly tighter edge-hook curl than inner fingers")
	hand.set_carrying(false)
	hand.free()
	prop.free()

func _make_grip_test_prop(shape: Shape3D, collision_scale: Vector3) -> Node3D:
	var prop: Node3D = Node3D.new()
	root.add_child(prop)
	prop.global_position = Vector3(1.0, 0.5, -2.0)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = shape
	collision.scale = collision_scale
	prop.add_child(collision)
	return prop

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
