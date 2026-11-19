## Headless contract checks for the responsive industrial FAT WorldScreen housing.
extends SceneTree

const FatScript = preload("res://environment/kit/fat_world_screen.gd")
const WorldScreenScript = preload("res://environment/kit/world_screen.gd")
const ScreenTextScript = preload("res://ui/screen_text.gd")

var _failed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var root_node: Node3D = Node3D.new()
	root_node.set_script(FatScript)
	root_node.name = "FatWorldScreen"

	var screen_node: Node3D = Node3D.new()
	screen_node.set_script(WorldScreenScript)
	screen_node.name = "WorldScreen"
	root_node.add_child(screen_node)
	var display: MeshInstance3D = MeshInstance3D.new()
	display.name = "Display"
	display.mesh = PlaneMesh.new()
	display.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	screen_node.add_child(display)
	var viewport: SubViewport = SubViewport.new()
	viewport.name = "SubViewport"
	screen_node.add_child(viewport)
	var terminal: RichTextLabel = RichTextLabel.new()
	terminal.set_script(ScreenTextScript)
	terminal.name = "ScreenText"
	viewport.add_child(terminal)
	var text_display: MeshInstance3D = MeshInstance3D.new()
	text_display.name = "TextDisplay"
	text_display.mesh = PlaneMesh.new()
	text_display.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	screen_node.add_child(text_display)

	var chassis: Node3D = Node3D.new()
	chassis.name = "Chassis"
	root_node.add_child(chassis)
	var shell: CSGPolygon3D = _add_csg(chassis, "OuterShell")
	var inner: Node3D = Node3D.new()
	inner.name = "InnerArmor"
	chassis.add_child(inner)
	for piece_name: String in ["TopArmor", "BottomArmor", "LeftArmor", "RightArmor"]:
		_add_csg(inner, piece_name)
	var corners: Node3D = Node3D.new()
	corners.name = "CornerArmor"
	chassis.add_child(corners)
	for piece_name: String in ["TopLeft", "TopRight", "BottomLeft", "BottomRight"]:
		_add_csg(corners, piece_name)
	var side_details: Node3D = Node3D.new()
	side_details.name = "SideDetails"
	chassis.add_child(side_details)
	for side_name: String in ["LeftVent", "RightVent"]:
		var vent_group: Node3D = Node3D.new()
		vent_group.name = side_name
		side_details.add_child(vent_group)
		for vent_index: int in range(5):
			var vent: MeshInstance3D = MeshInstance3D.new()
			vent.name = "Vent%d" % vent_index
			vent.mesh = BoxMesh.new()
			vent_group.add_child(vent)
	var control: Node3D = Node3D.new()
	control.name = "ControlPanel"
	chassis.add_child(control)
	var panel_body: MeshInstance3D = MeshInstance3D.new()
	panel_body.name = "PanelBody"
	panel_body.mesh = BoxMesh.new()
	control.add_child(panel_body)
	var indicators: Node3D = Node3D.new()
	indicators.name = "IndicatorGroup"
	control.add_child(indicators)
	for indicator_index: int in range(3):
		var indicator: MeshInstance3D = MeshInstance3D.new()
		indicator.name = "Indicator%d" % indicator_index
		indicator.mesh = CylinderMesh.new()
		indicators.add_child(indicator)
	var plate_group: Node3D = Node3D.new()
	plate_group.name = "IdentificationPlate"
	control.add_child(plate_group)
	var plate: MeshInstance3D = MeshInstance3D.new()
	plate.name = "PlateMesh"
	plate.mesh = BoxMesh.new()
	plate_group.add_child(plate)
	var lettering: MeshInstance3D = MeshInstance3D.new()
	lettering.name = "EngravedText"
	lettering.mesh = TextMesh.new()
	plate_group.add_child(lettering)
	var fasteners: Node3D = Node3D.new()
	fasteners.name = "Fasteners"
	chassis.add_child(fasteners)
	for fastener_name: String in ["TopLeft", "TopRight", "BottomLeft", "BottomRight"]:
		var fastener: MeshInstance3D = MeshInstance3D.new()
		fastener.name = fastener_name
		fastener.mesh = CylinderMesh.new()
		fasteners.add_child(fastener)
	var glass: MeshInstance3D = MeshInstance3D.new()
	glass.name = "Glass"
	glass.mesh = PlaneMesh.new()
	root_node.add_child(glass)

	root.add_child(root_node)
	var controller: FatWorldScreen = root_node as FatWorldScreen
	await process_frame

	_check(shell.polygon.size() == 8, "Outer shell should keep its clipped eight-point silhouette")
	_check(is_equal_approx(shell.depth, 0.30), "Outer shell should use the default 0.30 depth")
	_check(shell.position.is_equal_approx(Vector3(0.0, 0.0, -0.005)), "Outer shell front face should sit just behind the display and extrude backward")
	_check((inner.get_node("TopArmor") as CSGPolygon3D).polygon.size() == 4, "Top armor should be a four-point polygon")
	_check((corners.get_node("TopLeft") as CSGPolygon3D).position.z == 0.045, "Corner armor should sit forward of the inner frame")
	_check((panel_body.mesh as BoxMesh).size.is_equal_approx(Vector3(1.35, 0.16, 0.055)), "Control strip should match the default design width")
	_check((glass.mesh as PlaneMesh).size == Vector2(2.0, 1.125), "Glass should match the display dimensions")
	_check(glass.rotation_degrees.is_equal_approx(Vector3(-90.0, 0.0, 0.0)), "Glass should face the WorldScreen display")
	_check(glass.material_override is ShaderMaterial, "Glass should receive the shared protective glass shader")
	_check(is_equal_approx((plate.mesh as BoxMesh).size.x, 0.48), "Identification plate should use its proportional default width")
	_check(lettering.position.is_equal_approx(Vector3(0.27, 0.0, 0.049)), "TextMesh lettering should sit on the identification plate")

	controller.display_size = Vector2(3.0, 1.6875)
	_check(lettering.scale.is_equal_approx(Vector3(1.5, 1.5, 1.5)), "TextMesh lettering should scale proportionally with the display")
	_check(screen_node.display_size == Vector2(3.0, 1.6875), "WorldScreen content should receive the new display size")
	_check((glass.mesh as PlaneMesh).size == Vector2(3.0, 1.6875), "Glass should resize with the display")
	_check(is_equal_approx(shell.polygon[0].x, -1.60), "Outer shell should expand with the display and retain its clipped corner")
	_check(is_equal_approx((panel_body.mesh as BoxMesh).size.x, 2.025), "Control panel should resize proportionally")
	_check(is_equal_approx((fasteners.get_node("TopRight") as Node3D).position.x, 1.5792), "Fasteners should move outward with the display")
	_check(is_equal_approx((side_details.get_node("RightVent") as Node3D).position.x, 1.6694), "Side vents should move outward with the display")

	root_node.queue_free()
	await process_frame
	if _failed:
		quit(1)
		return
	print("FAT WORLD SCREEN PASS")
	quit(0)

func _add_csg(parent: Node, node_name: String) -> CSGPolygon3D:
	var polygon: CSGPolygon3D = CSGPolygon3D.new()
	polygon.name = node_name
	parent.add_child(polygon)
	return polygon

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("FAT WORLD SCREEN FAIL: %s" % message)
