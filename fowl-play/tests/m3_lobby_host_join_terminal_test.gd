## Contract checks for the lobby host/join terminal menu and address entry.
extends SceneTree

const ScreenScene = preload("res://environment/kit/world_screen.tscn")
const TerminalScript = preload("res://ui/lobby_host_join_terminal.gd")
const InteractableScript = preload("res://interaction/interactable.gd")
const ActorScript = preload("res://tests/support/local_terminal_test_actor.gd")

var _failed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var terminal: Node3D = Node3D.new()
	terminal.set_script(TerminalScript)
	var screen: WorldScreen = ScreenScene.instantiate() as WorldScreen
	var sensor: Area3D = Area3D.new()
	var interactable: Interactable = InteractableScript.new() as Interactable
	var actor: Node3D = ActorScript.new() as Node3D
	terminal.add_child(screen)
	terminal.add_child(sensor)
	terminal.add_child(interactable)
	terminal.set("screen", screen)
	terminal.set("proximity_area", sensor)
	terminal.set("screen_interactable", interactable)
	root.add_child(terminal)
	root.add_child(actor)
	await process_frame
	terminal.call("_on_proximity_body_entered", actor)
	interactable.interaction_requested.emit(actor, &"use")
	_check(bool(terminal.call("has_active_session")), "Nearby local player should open the terminal session")
	var menu: ScreenMenu = terminal.get("_menu") as ScreenMenu
	_check(menu != null and menu.is_active(), "Main menu should open")
	var options: Array[Dictionary] = menu.get_options()
	_check(options.size() == 3, "Main menu should have exactly HOST, JOIN, and LEAVE")
	_check(options[0].get("id") == &"host" and options[1].get("id") == &"join" and options[2].get("id") == &"leave", "Main menu option order should be HOST, JOIN, LEAVE")
	_check(not bool(options[2].get("enabled")), "LEAVE should be disabled without a session")
	terminal.call("_on_option_confirmed", &"join", "JOIN")
	_check(not menu.is_active(), "Selecting JOIN should close the main menu while entering an address")
	_check(bool(terminal.get("_editing_address")), "JOIN should enter address editing mode")
	var digit: InputEventKey = InputEventKey.new()
	digit.unicode = 49
	terminal.call("_handle_address_key", digit)
	var dot: InputEventKey = InputEventKey.new()
	dot.unicode = 46
	terminal.call("_handle_address_key", dot)
	_check(str(terminal.get("_address_buffer")) == "1.", "Address entry should accept digits and dots")
	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	terminal.call("_handle_address_key", escape)
	_check(not bool(terminal.get("_editing_address")) and menu.is_active(), "Escape should cancel address entry and restore the main menu")
	_check("127.0.0.1".is_valid_ip_address(), "IPv4 loopback should pass Godot IP validation")
	_check(not "not-an-ip".is_valid_ip_address(), "Invalid host text should fail IP validation")
	terminal.call("end_session")
	_check(not bool(terminal.call("has_active_session")), "Closing the terminal should end the session")
	var network: Node = root.get_node_or_null("Network")
	if is_instance_valid(network):
		network.set("status", "failed")
		terminal.call("_on_network_session_ended")
		await process_frame
		_check(str(terminal.get("_status_presentation")) == "failed", "A failed connection should show an error even if the client flag was cleared before the deferred callback")
		_check(screen.get_screen_text().get_parsed_text().contains("CONNECTION FAILED"), "Failed connection should display retry guidance")
	terminal.queue_free()
	actor.queue_free()
	await process_frame
	if _failed:
		quit(1)
		return
	print("LOBBY HOST JOIN TERMINAL PASS")
	quit(0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("LOBBY HOST JOIN TERMINAL FAIL: %s" % message)
