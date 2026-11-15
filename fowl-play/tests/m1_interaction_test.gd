## Headless M1 checks for the reusable interaction contract.
## Verifies input resolution, focus state, highlighting, and interaction signals.

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
	target.add_child(mesh)
	var interactable: Interactable = Interactable.new()
	interactable.kind = Interactable.InteractionKind.BOTH
	interactable.prompt_text = "Test target"
	target.add_child(interactable)
	var actor: Node3D = Node3D.new()
	root.add_child(actor)
	interactable.interacted.connect(_on_interacted)

	if interactable.action_for_input(&"primary") != &"use":
		_fail("BOTH target did not resolve primary to use")
	if interactable.action_for_input(&"interact") != &"grab":
		_fail("BOTH target did not resolve interact to grab")
	if not interactable.interact(actor, &"use"):
		_fail("Valid use interaction was rejected")
	if not _interacted:
		_fail("Interaction signal was not emitted")
	interactable.set_focused(true)
	if not interactable.is_focused:
		_fail("Focus state did not enable")
	if mesh.material_overlay == null:
		_fail("Focused target did not receive a highlight overlay")
	interactable.set_focused(false)
	if interactable.is_focused:
		_fail("Focus state did not clear")
	if mesh.material_overlay != null:
		_fail("Highlight overlay was not restored")
	target.free()
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
