## Local registration UI controller for a reusable WorldScreen and physical USE button.
class_name RegistrationTerminal
extends Node3D

const PlayerIdentity = preload("res://core/player_identity.gd")

@export var screen: WorldScreen
@export var use_interactable: Interactable
@export_range(0.5, 10.0, 0.25) var interaction_break_distance: float = 3.0

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
var _previous_mouse_mode: int = Input.MOUSE_MODE_CAPTURED
var _mouse_released_for_menu: bool = false

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
	set_process(true)

func _exit_tree() -> void:
	_restore_mouse_mode()
	if is_instance_valid(use_interactable) and use_interactable.interaction_requested.is_connected(_on_local_interaction_requested):
		use_interactable.interaction_requested.disconnect(_on_local_interaction_requested)
	if is_instance_valid(_network) and _network.is_connected("identity_roster_changed", _on_identity_roster_changed):
		_network.disconnect("identity_roster_changed", _on_identity_roster_changed)

func open_registration_for_actor(actor: Node) -> bool:
	if not is_instance_valid(screen) or not is_instance_valid(use_interactable) or not is_instance_valid(actor):
		return false
	if _session_active:
		return actor == _local_actor
	_local_actor = actor
	_session_active = true
	_release_mouse_for_menu()
	_editing_nickname = false
	_registration_pending = false
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
	_local_actor = null
	_restore_mouse_mode()

func _on_local_interaction_requested(actor: Node, action: StringName) -> void:
	if action != &"use" or not is_instance_valid(actor):
		return
	if _session_active:
		if actor == _local_actor and not _editing_nickname:
			_menu.handle_action(ScreenMenu.ACTION_CONFIRM)
		return
	open_registration_for_actor(actor)

func _process(_delta: float) -> void:
	if not _session_active or _registration_pending or not is_instance_valid(_local_actor):
		return
	if not _local_actor is Node3D:
		return
	var actor_position: Vector3 = (_local_actor as Node3D).global_position
	var actor_flat: Vector2 = Vector2(actor_position.x, actor_position.z)
	var terminal_flat: Vector2 = Vector2(global_position.x, global_position.z)
	if actor_flat.distance_to(terminal_flat) > interaction_break_distance:
		close_registration_session()
		screen.show_layout("warning", "CONNECTION LOST", "You moved too far from the terminal. Registration was reset.", "RETURN TO THE TERMINAL TO RECONNECT")

func _input(event: InputEvent) -> void:
	if not _session_active:
		return
	if event is InputEventMouseButton:
		if _handle_screen_click(event as InputEventMouseButton):
			get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey:
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

func _handle_screen_click(event: InputEventMouseButton) -> bool:
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT or _editing_nickname or not _menu.is_active():
		return false
	if not is_instance_valid(_local_actor):
		return false
	var camera: Camera3D = _local_actor.get_node_or_null("Head/Camera3D") as Camera3D
	if camera == null:
		var camera_nodes: Array[Node] = _local_actor.find_children("*", "Camera3D", true, false)
		if not camera_nodes.is_empty():
			camera = camera_nodes[0] as Camera3D
	if camera == null or not camera.is_inside_tree():
		return false
	var ray_origin: Vector3 = camera.project_ray_origin(event.position)
	var ray_direction: Vector3 = camera.project_ray_normal(event.position).normalized()
	var screen_normal: Vector3 = screen.global_transform.basis.z.normalized()
	var denominator: float = screen_normal.dot(ray_direction)
	if denominator >= -0.0001:
		return false
	var hit_distance: float = screen_normal.dot(screen.global_position - ray_origin) / denominator
	if hit_distance < 0.0:
		return false
	var hit_position: Vector3 = ray_origin + ray_direction * hit_distance
	var local_hit: Vector3 = screen.to_local(hit_position)
	if absf(local_hit.x) > screen.display_size.x * 0.5 or absf(local_hit.y) > screen.display_size.y * 0.5:
		return false
	var viewport: SubViewport = screen.get_node_or_null("SubViewport") as SubViewport
	var terminal_text: ScreenText = screen.get_screen_text()
	if viewport == null or terminal_text == null:
		return false
	var pixel_position: Vector2 = Vector2(
		(local_hit.x / screen.display_size.x + 0.5) * float(viewport.size.x),
		(0.5 - local_hit.y / screen.display_size.y) * float(viewport.size.y)
	)
	var option_index: int = terminal_text.get_menu_option_at_position(pixel_position)
	if option_index < 0:
		return false
	if not _menu.select_index(option_index) and _menu.get_selected_index() != option_index:
		return false
	return _menu.confirm()

func _release_mouse_for_menu() -> void:
	if _mouse_released_for_menu:
		return
	_previous_mouse_mode = Input.get_mouse_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_mouse_released_for_menu = true

func _restore_mouse_mode() -> void:
	if not _mouse_released_for_menu:
		return
	Input.set_mouse_mode(_previous_mouse_mode)
	_mouse_released_for_menu = false

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
		"CLICK OPTION  •  ARROWS MOVE  •  USE / ENTER SELECT"
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
		_local_actor = null
		_restore_mouse_mode()
		return
	_pending_nickname = _requested_nickname
	_registration_pending = true
	var submitted: bool = bool(_network.call("request_identity", _requested_nickname, _requested_color_index))
	if not submitted:
		_registration_pending = false
		_menu.close()
		screen.show_layout("warning", "REGISTRATION REJECTED", "Connect to a host and try again. The request was not submitted.", "PRESS THE BUTTON TO REOPEN")
		_session_active = false
		_local_actor = null
		_restore_mouse_mode()
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
	_local_actor = null
	_restore_mouse_mode()

