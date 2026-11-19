## Contract checks against the editor-authored SLIM scene and responsive controller.
extends SceneTree

const SlimScript = preload("res://environment/kit/slim_world_screen.gd")

var _failed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var packed: PackedScene = load("res://environment/kit/slim_world_screen.tscn") as PackedScene
	if packed == null:
		_fail("Could not load slim_world_screen.tscn")
		quit(1)
		return

	var instance: Node3D = packed.instantiate() as Node3D
	instance.set_script(SlimScript)
	root.add_child(instance)
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

	var body: MeshInstance3D = chassis.get_node("MainBody") as MeshInstance3D
	_check((body.mesh as BoxMesh).size.is_equal_approx(Vector3(2.42, 1.42, 0.14)), "Main body should match the default display footprint")
	_check((glass.mesh as PlaneMesh).size == Vector2(2.0, 1.125), "Glass should match the default display size")
	_check(glass.rotation_degrees.is_equal_approx(Vector3(-90.0, 0.0, 0.0)), "Glass should face the camera")
	_check(glass.material_override is ShaderMaterial, "Glass should receive the optical sheen shader")
	_check(chassis.get_node("OuterArmor/CornerArmor").get_child_count() == 4, "All four corner armor pieces should be preserved")
	_check(chassis.get_node("LightChannels").get_child_count() == 4, "All four gold light channels should be preserved")

	instance.set("display_size", Vector2(3.0, 1.6875))
	await process_frame
	_check((glass.mesh as PlaneMesh).size == Vector2(3.0, 1.6875), "Glass should resize with the display")
	_check(screen.display_size == Vector2(3.0, 1.6875), "WorldScreen text surface should receive the new size")
	_check((body.mesh as BoxMesh).size.is_equal_approx(Vector3(3.42, 1.9825, 0.14)), "Main body should resize with the display")
	_check((chassis.get_node("OuterArmor/TopArmor") as MeshInstance3D).position.y > 0.8, "Top armor should move outward with the display")
	_check((chassis.get_node("Fasteners/TopRightFastener") as Node3D).position.x > 1.5, "Fasteners should move outward with the display")

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
