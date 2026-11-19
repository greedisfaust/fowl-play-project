## Headless contract checks for the RegistrationTerminal local menu flow.
extends SceneTree

const WorldScreenScene = preload("res://environment/kit/world_screen.tscn")
const RegistrationTerminalScript = preload("res://ui/registration_terminal.gd")
const InteractableScript = preload("res://interaction/interactable.gd")

var _failed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	var terminal: Node3D = Node3D.new()
	terminal.set_script(RegistrationTerminalScript)
	var screen: WorldScreen = WorldScreenScene.instantiate() as WorldScreen
	var button_interactable: Interactable = InteractableScript.new() as Interactable
	terminal.add_child(screen)
	terminal.add_child(button_interactable)
	terminal.set("screen", screen)
	terminal.set("use_interactable", button_interactable)
	root.add_child(terminal)
	await process_frame
	var actor: Node3D = Node3D.new()
	root.add_child(actor)
	_check(bool(terminal.call("open_registration_for_actor", actor)), "Terminal should open for a valid local actor")
	var menu: ScreenMenu = terminal.get("_menu") as ScreenMenu
	_check(menu != null and menu.is_active(), "Registration menu should become active")
	_check(not actor.has_method("set_registration_terminal_active"), "Registration should not require a movement-lock method")
	var rendered: String = screen.get_screen_text().get_parsed_text()
	_check(rendered.contains("PLAYER REGISTRATION") and rendered.contains("EDIT NICKNAME"), "Main menu should render")
	_check(bool(terminal.call("handle_menu_action", ScreenMenu.ACTION_DOWN)), "Menu navigation should be forwarded")
	_check(menu.get_selected_option_id() == &"choose_color", "Down action should select color settings")
	_check(bool(terminal.call("handle_menu_action", ScreenMenu.ACTION_CONFIRM)), "Color option should open")
	_check(screen.get_screen_text().get_parsed_text().contains("SELECT PLAYER COLOR"), "Color choices should render")
	terminal.call("close_registration_session")
	_check(not menu.is_active(), "Closing the terminal should close its menu")
	terminal.call("open_registration_for_actor", actor)
	terminal.set("interaction_break_distance", 1.0)
	actor.position = Vector3(2.0, 0.0, 0.0)
	terminal.call("_process", 0.0)
	_check(not bool(terminal.get("_session_active")), "Walking beyond range should reset the registration session")
	_check(screen.get_screen_text().get_parsed_text().contains("CONNECTION LOST"), "Leaving range should show a disconnect message")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	terminal.queue_free()
	actor.queue_free()
	await process_frame
	if _failed:
		quit(1)
		return
	print("REGISTRATION TERMINAL PASS")
	quit(0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("REGISTRATION TERMINAL FAIL: %s" % message)
