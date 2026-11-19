## Headless contract checks for the reusable InteractiveTerminal lifecycle.
extends SceneTree

const WorldScreenScene = preload("res://environment/kit/world_screen.tscn")
const InteractiveTerminalScript = preload("res://ui/interactive_terminal.gd")
const InteractableScript = preload("res://interaction/interactable.gd")
const LocalActorScript = preload("res://tests/support/local_terminal_test_actor.gd")

var _failed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var terminal: Node3D = Node3D.new()
	terminal.set_script(InteractiveTerminalScript)
	var screen: WorldScreen = WorldScreenScene.instantiate() as WorldScreen
	var sensor: Area3D = Area3D.new()
	var interactable: Interactable = InteractableScript.new() as Interactable
	terminal.add_child(screen)
	terminal.add_child(sensor)
	terminal.add_child(interactable)
	terminal.set("screen", screen)
	terminal.set("proximity_area", sensor)
	terminal.set("screen_interactable", interactable)
	root.add_child(terminal)
	await process_frame
	_check(not bool(terminal.call("is_awake")), "Terminal should begin asleep")
	var remote_actor: CharacterBody3D = CharacterBody3D.new()
	remote_actor.set_script(LocalActorScript)
	remote_actor.set("is_local_player", false)
	root.add_child(remote_actor)
	terminal.call("_on_proximity_body_entered", remote_actor)
	_check(not bool(terminal.call("is_awake")), "Remote players must not wake this local terminal")
	var local_actor: CharacterBody3D = CharacterBody3D.new()
	local_actor.set_script(LocalActorScript)
	root.add_child(local_actor)
	terminal.call("_on_proximity_body_entered", local_actor)
	_check(bool(terminal.call("is_awake")), "A nearby local player should wake the terminal")
	_check(interactable.can_interact(local_actor, &"use"), "A nearby local player should be allowed to activate the screen")
	_check(bool(terminal.call("begin_session", local_actor)), "A nearby local player should begin a session")
	_check(bool(terminal.call("has_active_session")), "Terminal should report its active session")
	local_actor.position = Vector3(4.0, 0.0, 0.0)
	terminal.call("_process", 0.0)
	_check(not bool(terminal.call("has_active_session")), "Leaving interaction range should end the active session")
	local_actor.position = Vector3(6.0, 0.0, 0.0)
	terminal.call("_on_proximity_body_exited", local_actor)
	_check(not bool(terminal.call("is_awake")), "Terminal should sleep after the last local player leaves")
	terminal.queue_free()
	local_actor.queue_free()
	remote_actor.queue_free()
	await process_frame
	if _failed:
		quit(1)
		return
	print("INTERACTIVE TERMINAL PASS")
	quit(0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("INTERACTIVE TERMINAL FAIL: %s" % message)
