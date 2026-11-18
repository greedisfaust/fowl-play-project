## Headless M1 checks for the reusable interaction contract and outline lifecycle.
extends SceneTree

var _failed: bool = false
var _interacted: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var target: Node3D = Node3D.new()
	target.name = "M1Target"
	root.add_child(target)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	var original_overlay: StandardMaterial3D = StandardMaterial3D.new()
	mesh.material_overlay = original_overlay
	target.add_child(mesh)
	var interactable: Interactable = Interactable.new()
	interactable.kind = Interactable.InteractionKind.BOTH
	interactable.prompt_text = "Test target"
	target.add_child(interactable)

	var unrelated_target: Node3D = Node3D.new()
	unrelated_target.name = "UnrelatedTarget"
	root.add_child(unrelated_target)
	var non_interactable: MeshInstance3D = MeshInstance3D.new()
	non_interactable.mesh = BoxMesh.new()
	unrelated_target.add_child(non_interactable)

	var actor: Node3D = Node3D.new()
	root.add_child(actor)
	interactable.interacted.connect(_on_interacted)
	await process_frame

	if interactable.action_for_input(&"primary") != &"use":
		_fail("BOTH target did not resolve primary to use")
	if interactable.action_for_input(&"interact") != &"grab":
		_fail("BOTH target did not resolve interact to grab")
	if not interactable.interact(actor, &"use"):
		_fail("Valid use interaction was rejected")
	if not _interacted:
		_fail("Interaction signal was not emitted")
	if mesh.material_overlay == null:
		_fail("Interactable mesh did not receive its idle outline")
	if non_interactable.material_overlay != null:
		_fail("Unrelated non-interactable mesh unexpectedly received an outline")
	var idle_material: ShaderMaterial = mesh.material_overlay as ShaderMaterial
	if idle_material == null or idle_material.shader != load("res://interaction/interactable_outline.gdshader"):
		_fail("Idle outline is not using the silhouette shader")

	interactable.set_focused(true)
	interactable._set_highlight_amount(1.0)
	if not interactable.is_focused:
		_fail("Focus state did not enable")
	if is_equal_approx(float(idle_material.get_shader_parameter("glow_strength")), 0.0):
		_fail("Focused outline did not enable its glow")
	if not Color(idle_material.get_shader_parameter("outline_color")).is_equal_approx(Interactable.FOCUSED_OUTLINE_COLOR):
		_fail("Focused outline did not transition to gold")

	interactable.set_focused(false)
	interactable._set_highlight_amount(0.0)
	if interactable.is_focused:
		_fail("Focus state did not clear")
	if mesh.material_overlay != idle_material:
		_fail("Idle outline should remain applied after focus clears")
	if not Color(idle_material.get_shader_parameter("outline_color")).is_equal_approx(Interactable.IDLE_OUTLINE_COLOR):
		_fail("Outline did not return to its idle black state")

	target.remove_child(interactable)
	if mesh.material_overlay != original_overlay:
		_fail("Original overlay was not restored when Interactable left the tree")
	interactable.free()
	target.free()
	unrelated_target.free()
	actor.free()
	if _failed:
		quit(1)
		return
	print("M1 interaction checks passed")
	quit(0)

func _on_interacted(_actor: Node, _action: StringName) -> void:
	_interacted = true

func _fail(message: String) -> void:
	_failed = true
	push_error(message)
