## Headless contract checks for RegistrationTerminal's InteractiveTerminal integration.
extends SceneTree

const WorldScreenScene = preload("res://environment/kit/world_screen.tscn")
const RegistrationTerminalScript = preload("res://ui/registration_terminal.gd")
const InteractableScript = preload("res://interaction/interactable.gd")
const LocalActorScript = preload("res://tests/support/local_terminal_test_actor.gd")

var _failed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	var terminal: RegistrationTerminal = RegistrationTerminalScript.new() as RegistrationTerminal
	var screen: WorldScreen = WorldScreenScene.instantiate() as WorldScreen
	var sensor: Area3D = Area3D.new()
	var screen_interactable: Interactable = InteractableScript.new() as Interactable
	var actor: Node3D = LocalActorScript.new() as Node3D
	terminal.add_child(screen)
	terminal.add_child(sensor)
	terminal.add_child(screen_interactable)
	terminal.screen = screen
	terminal.proximity_area = sensor
	terminal.screen_interactable = screen_interactable
	root.add_child(terminal)
	root.add_child(actor)
	await process_frame
	_check(not terminal.is_awake(), "Terminal should start asleep")
	screen_interactable.interaction_requested.emit(actor, &"use")
	_check(not terminal.has_active_session(), "Screen use should not activate before proximity wake")
	terminal.call("_on_proximity_body_entered", actor)
	_check(terminal.is_awake(), "Local actor proximity should wake the terminal")
	_check(not terminal.has_active_session(), "Proximity wake alone should not begin registration")
	screen_interactable.interaction_requested.emit(actor, &"use")
	_check(terminal.has_active_session(), "Screen interaction should begin the base terminal session")
	var menu: ScreenMenu = terminal.get("_menu") as ScreenMenu
	_check(menu != null and menu.is_active(), "Registration menu should become active")
	_check(Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE, "Opening registration should reveal the mouse cursor")
	_check(not _has_property(actor, "registration_terminal_active"), "Registration actor should not require the obsolete session-wide lock property")
	var rendered: String = screen.get_screen_text().get_parsed_text()
	_check(rendered.contains("PLAYER REGISTRATION") and rendered.contains("EDIT NICKNAME"), "Main menu should render")
	_check(not rendered.contains("SELECT COLOR") and not rendered.contains("COLOR:"), "Registration menu should no longer expose player color selection")
	var initial_options: Array[Dictionary] = menu.get_options()
	_check(initial_options.size() == 3, "Registration menu should contain nickname, register, and close options only")
	_check(str(initial_options[1].get("id", "")) == "register", "Register should be the second menu option")
	terminal.registration_header = "CUSTOM REGISTRATION"
	terminal.edit_nickname_option_label = "CUSTOM NAME LABEL"
	terminal.call("_show_main_menu")
	var customized: String = screen.get_screen_text().get_parsed_text()
	_check(customized.contains("CUSTOM REGISTRATION") and customized.contains("CUSTOM NAME LABEL"), "Inspector copy exports should customize the rendered main menu")
	terminal.registration_header = "PLAYER REGISTRATION"
	terminal.edit_nickname_option_label = "EDIT NICKNAME"
	terminal.call("_show_main_menu")
	_check(bool(terminal.handle_menu_action(ScreenMenu.ACTION_DOWN)), "Menu navigation should be forwarded")
	_check(menu.get_selected_option_id() == &"register", "Down action should select registration now that color selection is separate")
	menu.select_index(0)
	_check(bool(terminal.handle_menu_action(ScreenMenu.ACTION_CONFIRM)), "Nickname edit option should open")
	_check(bool(actor.get("terminal_movement_locked")), "Entering nickname editing should lock player movement")
	var confirm_key: InputEventKey = InputEventKey.new()
	confirm_key.keycode = KEY_ENTER
	terminal.call("_handle_nickname_key", confirm_key)
	_check(not bool(actor.get("terminal_movement_locked")), "Confirming the nickname should restore player movement")
	menu.select_index(0)
	_check(bool(terminal.handle_menu_action(ScreenMenu.ACTION_CONFIRM)), "Nickname edit should be reopenable")
	_check(bool(actor.get("terminal_movement_locked")), "Reopening nickname editing should lock movement again")
	var cancel_key: InputEventKey = InputEventKey.new()
	cancel_key.keycode = KEY_ESCAPE
	terminal.call("_handle_nickname_key", cancel_key)
	_check(not bool(actor.get("terminal_movement_locked")), "Cancelling nickname editing should restore player movement")
	menu.select_index(1)
	_check(menu.get_selected_option_id() == &"register", "Registration action remains available after nickname editing")
	_check(not screen.get_screen_text().get_parsed_text().contains("SELECT PLAYER COLOR"), "Registration terminal should not render a color submenu")
	terminal.close_registration_session()
	_check(not terminal.has_active_session() and not menu.is_active(), "Closing should end the base session and menu")
	_check(not bool(actor.get("terminal_movement_locked")), "Closing the terminal should never leave movement locked")
	_check(Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED, "Closing registration should restore the previous mouse mode")
	screen_interactable.interaction_requested.emit(actor, &"use")
	_check(terminal.has_active_session(), "Nearby player should be able to reopen registration")
	terminal.interaction_distance = 1.0
	actor.position = Vector3(2.0, 0.0, 0.0)
	terminal.call("_process", 0.0)
	_check(not terminal.has_active_session(), "Walking beyond interaction distance should reset the session")
	_check(not bool(actor.get("terminal_movement_locked")), "Range disconnect should always release the movement lock")
	_check(screen.get_screen_text().get_parsed_text().contains("CONNECTION LOST"), "Leaving interaction range should show a disconnect message")
	terminal.call("_on_proximity_body_exited", actor)
	_check(not terminal.is_awake(), "Leaving the sensor should put the terminal to sleep")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	terminal.queue_free()
	actor.queue_free()
	await process_frame
	if _failed:
		quit(1)
		return
	print("REGISTRATION TERMINAL PASS")
	quit(0)

func _has_property(target: Object, property_name: String) -> bool:
	for property: Dictionary in target.get_property_list():
		if str(property.get("name", "")) == property_name:
			return true
	return false

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("REGISTRATION TERMINAL FAIL: %s" % message)
