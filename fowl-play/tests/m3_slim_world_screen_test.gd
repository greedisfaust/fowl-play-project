## Contract checks against the editor-authored AURELION S-01 SLIM scene.
extends SceneTree

var _failed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var packed: PackedScene = load("res://environment/kit/slim_world_screen.tscn") as PackedScene
	if packed == null:
		_fail("Could not load slim_world_screen.tscn")
		quit(1)
		return
	var instance: SlimWorldScreen = packed.instantiate() as SlimWorldScreen
	if instance == null:
		_fail("SLIM scene root should use SlimWorldScreen")
		quit(1)
		return
	var first_parent: Node3D = Node3D.new()
	first_parent.name = "FirstInstanceParent"
	root.add_child(first_parent)
	first_parent.add_child(instance)
	await process_frame
	var second_parent: Node3D = Node3D.new()
	second_parent.name = "SecondInstanceParent"
	root.add_child(second_parent)
	instance.reparent(second_parent, true)
	await process_frame

	var screen: WorldScreen = instance.get_node_or_null("WorldScreen") as WorldScreen
	var chassis: Node3D = instance.get_node_or_null("Chassis") as Node3D
	var glass: MeshInstance3D = instance.get_node_or_null("Glass") as MeshInstance3D
	_check(screen != null, "WorldScreen should be a direct child")
	_check(chassis != null, "Chassis should be a direct child")
	_check(glass != null, "Glass should be a direct child")
	if screen == null or chassis == null or glass == null:
		instance.queue_free()
		await process_frame
		quit(1)
		return

	var left_vents: Node3D = chassis.get_node("SideDetails/LeftVent") as Node3D
	_check(is_equal_approx((chassis.get_node("LightChannels") as Node3D).position.z, -0.1), "Light-channel group authored depth should survive runtime initialization")
	_check(is_equal_approx((chassis.get_node("Fasteners") as Node3D).position.z, -0.081), "Fastener group authored depth should survive runtime initialization")
	var right_vents: Node3D = chassis.get_node("SideDetails/RightVent") as Node3D
	_check(is_equal_approx((chassis.get_node("LightChannels/TopChannel") as Node3D).position.y, 0.551), "Authored top light-channel position should be preserved")
	_check(is_equal_approx((chassis.get_node("Fasteners") as Node3D).position.y, -0.081), "Authored fastener-group offset should be preserved")
	_check(is_equal_approx((chassis.get_node("ControlPanel") as Node3D).position.y, -0.048), "Authored control-panel offset should be preserved")
	_check(is_equal_approx(glass.position.z, 0.013), "Authored glass depth should be preserved")
	_check(glass.material_override is ShaderMaterial, "Glass should use the clear optical-coating material")
	_check(left_vents.get_child_count() == 5, "Left vent bank should contain five vents")
	_check(right_vents.get_child_count() == 5, "Right vent bank should contain five vents")
	_check(is_equal_approx((left_vents.get_node("Vent1") as Node3D).position.y, -0.34), "First left vent should retain authored spacing")
	_check(is_equal_approx((right_vents.get_node("Vent5") as Node3D).position.y, 0.34), "Last right vent should retain authored spacing")
	_check(is_equal_approx((chassis.get_node("OuterArmor/CornerArmor/TopLeft") as Node3D).position.z, 0.105), "Corner armor authored depth should survive runtime initialization")

	instance.display_size = Vector2(3.0, 1.6875)
	await process_frame
	var body: MeshInstance3D = chassis.get_node("MainBody") as MeshInstance3D
	_check((body.mesh as BoxMesh).size.is_equal_approx(Vector3(3.42, 1.9825, 0.14)), "Main body should resize with the display")
	_check(is_equal_approx((chassis.get_node("Bezel/TopRail") as Node3D).position.y, 0.87625), "Top rail should follow the display-height delta")
	_check(is_equal_approx((chassis.get_node("LightChannels/TopChannel") as Node3D).position.y, 0.83225), "Top channel should retain its authored offset while following display height")
	_check(is_equal_approx((chassis.get_node("Fasteners/TopRightFastener") as Node3D).position.x, 1.62), "Fasteners should follow the resized outer width")
	_check(is_equal_approx(right_vents.position.x, 1.67), "Right vent bank should follow the resized outer edge")
	_check(is_equal_approx((chassis.get_node("ControlPanel/PanelBody") as Node3D).position.y, -0.94625), "Control panel should follow the resized lower edge")
	_check((glass.mesh as PlaneMesh).size == Vector2(3.0, 1.6875), "Glass PlaneMesh should resize with the display")
	_check(screen.display_size == Vector2(3.0, 1.6875), "WorldScreen content should receive the new display size")

	instance.queue_free()
	await process_frame
	if _failed:
		quit(1)
		return
	print("SLIM WORLD SCREEN PASS")
	quit(0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	_failed = true
	push_error("SLIM WORLD SCREEN FAIL: %s" % message)
