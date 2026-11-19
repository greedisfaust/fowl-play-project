## Local registration UI controller for a reusable WorldScreen and physical USE button.
class_name RegistrationTerminal
extends Node3D

const PlayerIdentity = preload("res://core/player_identity.gd")

@export var screen: WorldScreen
@export var use_interactable: Interactable

var _menu: ScreenMenu = ScreenMenu.new()
var _network: Node = null
var _local_actor: Node = null
var _session_active: bool = false
var _editing_nickname: bool = false
var _nickname_buffer: String = "Chicken"
var _requested_nickname: String = "Chicken"
var _requested_color_index: int = 0
var _registration_pending: bool = false
var _pending_nickname: String = ""

func _ready() -> void:
	if not is_instance_valid(screen):
		push_warning("RegistrationTerminal requires a WorldScreen reference.")
		set_process_input(false)
		return
	if not is_instance_valid(use_interactable):
		push_warning("RegistrationTerminal requires the physical USE button Interactable reference.")
		set_process_input(false)
		return
	_network = get_node_or_null("/root/Network")
	use_interactable.interaction_requested.connect(_on_local_interaction_requested)
	_menu.option_confirmed.connect(_on_option_confirmed)
	if is_instance_valid(_network):
		_network.connect("identity_roster_changed", _on_identity_roster_changed)
	set_process_input(true)

func _exit_tree() -> void:
	if is_instance_valid(use_interactable) and use_interactable.interaction_requested.is_connected(_on_local_interaction_requested):
		use_interactable.interaction_requested.disconnect(_on_local_interaction_requested)
	if is_instance_valid(_network) and _network.is_connected("identity_roster_changed", _on_identity_roster_changed):
		_network.disconnect("identity_roster_changed", _on_identity_roster_changed)
	_release_actor_lock()

func open_registration_for_actor(actor: Node) -> bool:
	if not is_instance_valid(screen) or not is_instance_valid(use_interactable) or not is_instance_valid(actor):
		return false
	if _session_active:
		return actor == _local_actor
	_local_actor = actor
	_session_active = true
	_editing_nickname = false
	_registration_pending = false
	if actor.has_method("set_registration_terminal_active"):
		actor.call("set_registration_terminal_active", true)
	var current_identity: PlayerIdentity = null
	if is_instance_valid(_network):
		current_identity = _network.call("get_local_player_identity") as PlayerIdentity
	if current_identity != null:
		_nickname_buffer = current_identity.nickname
		_requested_nickname = current_identity.nickname
		_requested_color_index = current_identity.color_index
	else:
		_nickname_buffer = "Chicken"
		_requested_nickname = "Chicken"
		_requested_color_index = 0
	_show_main_menu()
	return true

func handle_menu_action(action: StringName) -> bool:
	if not _session_active or _editing_nickname:
		return false
	return _menu.handle_action(action)

func close_registration_session() -> void:
	if _menu.is_active():
		_menu.close()
	_editing_nickname = false
	_session_active = false
	_release_actor_lock()
	_local_actor = null

func _on_local_interaction_requested(actor: Node, action: StringName) -> void:
	if action != &"use" or not is_instance_valid(actor):
		return
	if _session_active:
		if actor == _local_actor and not _editing_nickname:
			_menu.handle_action(ScreenMenu.ACTION_CONFIRM)
		return
	open_registration_for_actor(actor)

func _input(event: InputEvent) -> void:
	if not _session_active or not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if _editing_nickname:
		_handle_nickname_key(key_event)
		get_viewport().set_input_as_handled()
		return
	if key_event.keycode == KEY_UP:
		_menu.handle_action(ScreenMenu.ACTION_UP)
	elif key_event.keycode == KEY_DOWN:
		_menu.handle_action(ScreenMenu.ACTION_DOWN)
	elif key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
		_menu.handle_action(ScreenMenu.ACTION_CONFIRM)
	elif key_event.keycode == KEY_ESCAPE:
		close_registration_session()
	else:
		return
	get_viewport().set_input_as_handled()

func _handle_nickname_key(event: InputEventKey) -> void:
	if event.keycode == KEY_ESCAPE:
		_editing_nickname = false
		_show_main_menu()
	elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		_requested_nickname = _nickname_buffer.strip_edges()
		if _requested_nickname.is_empty():
			_requested_nickname = "Chicken"
		_editing_nickname = false
		_show_main_menu()
	elif event.keycode == KEY_BACKSPACE:
		if not _nickname_buffer.is_empty():
			_nickname_buffer = _nickname_buffer.left(_nickname_buffer.length() - 1)
		_render_nickname_editor()
	elif event.unicode >= 32 and event.unicode != 127 and _nickname_buffer.length() < PlayerIdentity.MAX_NICKNAME_LENGTH:
		_nickname_buffer += String.chr(event.unicode)
		_render_nickname_editor()

func _show_main_menu() -> void:
	var options: Array[Dictionary] = [
		{"id": &"edit_nickname", "label": "EDIT NICKNAME"},
		{"id": &"choose_color", "label": "SELECT COLOR"},
		{"id": &"register", "label": "CONFIRM REGISTRATION"},
		{"id": &"close", "label": "CLOSE TERMINAL"}
	]
	_menu.open(
		screen,
		"PLAYER REGISTRATION",
		"NICKNAME: %s\nCOLOR: %s\n\nChoose your identity settings." % [
			_requested_nickname,
			PlayerIdentity.color_name_for_index(_requested_color_index).to_upper()
		],
		options,
		"ARROWS NAVIGATE  •  BUTTON / ENTER SELECT"
	)

func _show_color_menu() -> void:
	var options: Array[Dictionary] = []
	for index: int in range(PlayerIdentity.palette_size()):
		options.append({
			"id": StringName("color_%d" % index),
			"label": "%s%s" % [
				PlayerIdentity.color_name_for_index(index).to_upper(),
				"  [CURRENT]" if index == _requested_color_index else ""
			]
		})
	_menu.open(
		screen,
		"SELECT PLAYER COLOR",
		"Choose a preferred color. If occupied, the host assigns the next available color.",
		options,
		"ARROWS NAVIGATE  •  BUTTON / ENTER SELECT"
	)
	_menu.select_index(_requested_color_index)

func _begin_nickname_edit() -> void:
	_menu.close()
	_editing_nickname = true
	_nickname_buffer = _requested_nickname
	_render_nickname_editor()

func _render_nickname_editor() -> void:
	screen.show_layout(
		"information",
		"SET NICKNAME",
		"%s_\n\nTYPE A NAME (MAX %d CHARACTERS)." % [
			_nickname_buffer,
			PlayerIdentity.MAX_NICKNAME_LENGTH
		],
		"ENTER ACCEPTS  •  ESC CANCELS  •  BACKSPACE ERASES"
	)

func _on_option_confirmed(option_id: StringName, _option_label: String) -> void:
	if str(option_id).begins_with("color_"):
		_requested_color_index = int(str(option_id).trim_prefix("color_"))
		_show_main_menu()
		return
	match option_id:
		&"edit_nickname":
			_begin_nickname_edit()
		&"choose_color":
			_show_color_menu()
		&"register":
			_submit_registration()
		&"close":
			close_registration_session()

func _submit_registration() -> void:
	if not is_instance_valid(_network):
		_menu.close()
		screen.show_layout("warning", "NETWORK UNAVAILABLE", "The identity service is not available.", "PRESS THE BUTTON TO REOPEN")
		_session_active = false
		_release_actor_lock()
		_local_actor = null
		return
	_pending_nickname = _requested_nickname
	_registration_pending = true
	var submitted: bool = bool(_network.call("request_identity", _requested_nickname, _requested_color_index))
	if not submitted:
		_registration_pending = false
		_menu.close()
		screen.show_layout("warning", "REGISTRATION REJECTED", "Connect to a host and try again. The request was not submitted.", "PRESS THE BUTTON TO REOPEN")
		_session_active = false
		_release_actor_lock()
		_local_actor = null
		return
	if _registration_pending:
		_menu.close()
		screen.show_layout("information", "REGISTRATION SENT", "Waiting for the host to assign your identity...", "PLEASE WAIT")

func _on_identity_roster_changed() -> void:
	if not _registration_pending or not is_instance_valid(_network):
		return
	var identity: PlayerIdentity = _network.call("get_local_player_identity") as PlayerIdentity
	if identity == null:
		return
	var matches_name: bool = identity.nickname == _pending_nickname or identity.nickname.begins_with(_pending_nickname + " ")
	if not matches_name:
		return
	_registration_pending = false
	_menu.close()
	screen.show_layout(
		"success",
		"REGISTRATION COMPLETE",
		"%s\nCOLOR: %s" % [identity.get_display_label(), identity.get_color_name().to_upper()],
		"IDENTITY ASSIGNED BY HOST"
	)
	_session_active = false
	_release_actor_lock()
	_local_actor = null

func _release_actor_lock() -> void:
	if is_instance_valid(_local_actor) and _local_actor.has_method("set_registration_terminal_active"):
		_local_actor.call("set_registration_terminal_active", false)
