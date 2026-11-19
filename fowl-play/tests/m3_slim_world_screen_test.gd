## Headless contract checks for the responsive SLIM WorldScreen housing.
extends SceneTree

const SlimScript = preload("res://environment/kit/slim_world_screen.gd")
const WorldScreenScript = preload("res://environment/kit/world_screen.gd")
const ScreenTextScript = preload("res://ui/screen_text.gd")

var _failed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var root_node: Node3D = Node3D.new()
	root_node.set_script(SlimScript)
	root_node.name = "SlimWorldScreen"

	var screen_node: Node3D = Node3D.new()
	screen_node.set_script(WorldScreenScript)
	screen_node.name = "WorldScreen"
	root_node.add_child(screen_node)
	var screen: WorldScreen = screen_node as WorldScreen

	var display: MeshInstance3D = MeshInstance3D.new()
	display.name = "Display"
	display.mesh = PlaneMesh.new()
	screen.add_child(display)
	var text_viewport: SubViewport = SubViewport.new()
	text_viewport.name = "SubViewport"
	screen.add_child(text_viewport)
	var terminal_node: RichTextLabel = RichTextLabel.new()
	terminal_node.set_script(ScreenTextScript)
	terminal_node.name = "ScreenText"
	text_viewport.add_child(terminal_node)
	var text_display: MeshInstance3D = MeshInstance3D.new()
	text_display.name = "TextDisplay"
	text_display.mesh = PlaneMesh.new()
	screen.add_child(text_display)

	var housing: MeshInstance3D = MeshInstance3D.new()
	housing.name = "Housing"
	housing.mesh = BoxMesh.new()
	root_node.add_child(housing)
	var bezel: Node3D = Node3D.new()
	bezel.name = "Bezel"
	root_node.add_child(bezel)
	for piece_name in ["Top", "Bottom", "Left", "Right"]:
		var piece: MeshInstance3D = MeshInstance3D.new()
		piece.name = piece_name
		piece.mesh = BoxMesh.new()
		bezel.add_child(piece)
	var glass: MeshInstance3D = MeshInstance3D.new()
	glass.name = "Glass"
	glass.mesh = PlaneMesh.new()
	root_node.add_child(glass)

	root.add_child(root_node)
	var controller: SlimWorldScreen = root_node as SlimWorldScreen
	await process_frame
	_check((housing.mesh as BoxMesh).size == Vector3(2.16, 1.285, 0.1), "Housing should match default display plus bezel dimensions")
	_check((bezel.get_node("Top").mesh as BoxMesh).size == Vector3(2.16, 0.08, 0.025), "Top bezel should use the full outer width")
	_check((glass.mesh as PlaneMesh).size == Vector2(2.0, 1.125), "Glass should match the display size")
	_check(glass.material_override is ShaderMaterial, "Glass should receive the dedicated sheen shader")
	_check(glass.rotation_degrees.is_equal_approx(Vector3.ZERO), "Glass PlaneMesh should remain on its default XZ display plane")

	controller.display_size = Vector2(3.0, 1.6875)
	_check((housing.mesh as BoxMesh).size == Vector3(3.16, 1.8475, 0.1), "Housing should resize with the display")
	_check((bezel.get_node("Top").mesh as BoxMesh).size == Vector3(3.16, 0.08, 0.025), "Top bezel should resize with the display")
	_check((bezel.get_node("Left").mesh as BoxMesh).size == Vector3(0.08, 1.6875, 0.025), "Side bezels should resize with the display")
	_check((glass.mesh as PlaneMesh).size == Vector2(3.0, 1.6875), "Glass should resize with the display")
	_check(screen.display_size == Vector2(3.0, 1.6875), "WorldScreen content surface should receive the new display size")
	_check(glass.position.is_equal_approx(Vector3(0.0, 0.0, 0.012)), "Glass should stay in front of the display")

	root_node.queue_free()
	await process_frame
	if _failed:
		quit(1)
		return
	print("SLIM WORLD SCREEN PASS")
	quit(0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("SLIM WORLD SCREEN FAIL: %s" % message)
