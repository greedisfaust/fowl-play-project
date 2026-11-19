## Contract checks against the editor-authored FAT scene and responsive controller.
extends SceneTree

const FatScript = preload("res://environment/kit/fat_world_screen.gd")

var _failed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var packed: PackedScene = load("res://environment/kit/fat_world_screen.tscn") as PackedScene
	if packed == null:
		_fail("Could not load fat_world_screen.tscn")
		quit(1)
		return

	var instance: Node3D = packed.instantiate() as Node3D
	instance.set_script(FatScript)
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

	_check((glass.mesh as PlaneMesh).size == Vector2(2.0, 1.125), "Glass should match the default display size")
	_check(glass.material_override is ShaderMaterial, "Glass should receive the shared optical sheen shader")
	_check((chassis.get_node("OuterShell") as CSGPolygon3D).polygon.size() == 8, "Outer shell should retain its clipped silhouette")
	_check(chassis.get_node("CornerArmor").get_child_count() == 4, "All four corner plates should remain present")
	_check((chassis.get_node("ControlPanel/PanelBody/MeshInstance3D") == null), "Control panel should keep its authored flat hierarchy")
	_check((chassis.get_node("ControlPanel/PanelBody") as MeshInstance3D).mesh is BoxMesh, "Control panel body should remain a BoxMesh")

	instance.set("display_size", Vector2(3.0, 1.6875))
	await process_frame
	_check((glass.mesh as PlaneMesh).size == Vector2(3.0, 1.6875), "Glass should resize with the display")
	_check(screen.display_size == Vector2(3.0, 1.6875), "WorldScreen text surface should receive the new size")
	_check(is_equal_approx((chassis.get_node("OuterShell") as CSGPolygon3D).polygon[0].x, -1.72), "Outer shell should expand with the display")
	_check((chassis.get_node("Fasteners/TopRightFastener") as Node3D).position.x > 1.5, "Fasteners should move outward with the display")

	instance.queue_free()
	await process_frame
	if _failed:
		quit(1)
		return
	print("FAT WORLD SCREEN PASS")
	quit(0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	_failed = true
	push_error("FAT WORLD SCREEN FAIL: %s" % message)
