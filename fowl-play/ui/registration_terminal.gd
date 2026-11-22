## Local registration UI layered on the reusable proximity-aware terminal lifecycle.
class_name RegistrationTerminal
extends InteractiveTerminal

const PlayerIdentity = preload("res://core/player_identity.gd")

@export_group("Registration Copy")
@export var registration_header: String = "PLAYER REGISTRATION"
@export_multiline var main_menu_description_format: String = "NICKNAME: %s\n\nSet your player nickname."
@export var main_menu_prompt: String = "CLICK OPTION  •  ARROWS MOVE  •  M1 / E / ENTER SELECT"
@export var edit_nickname_option_label: String = "EDIT NICKNAME"
@export var confirm_registration_option_label: String = "CONFIRM REGISTRATION"
@export var close_terminal_option_label: String = "CLOSE TERMINAL"
@export var nickname_editor_header: String = "SET NICKNAME"
@export var nickname_editor_instruction_format: String = "TYPE A NAME (MAX %d CHARACTERS)."
@export var nickname_editor_prompt: String = "ENTER ACCEPTS  •  ESC CANCELS  •  BACKSPACE ERASES"
@export var connection_lost_header: String = "CONNECTION LOST"
@export_multiline var connection_lost_description: String = "You moved too far from the terminal. Registration was reset."
@export var connection_lost_prompt: String = "RETURN TO THE TERMINAL TO RECONNECT"
@export var network_unavailable_header: String = "NETWORK UNAVAILABLE"
@export_multiline var network_unavailable_description: String = "The identity service is not available."
@export var reopen_prompt: String = "APPROACH TO REOPEN"
@export var registration_rejected_header: String = "REGISTRATION REJECTED"
@export_multiline var registration_rejected_description: String = "Connect to a host and try again. The request was not submitted."
@export var registration_sent_header: String = "REGISTRATION SENT"
@export_multiline var registration_sent_description: String = "Waiting for the host to assign your identity..."
@export var please_wait_prompt: String = "PLEASE WAIT"
@export var registration_success_header: String = "REGISTRATION COMPLETE"
@export var registration_success_body_format: String = "%s"
@export var registration_success_prompt: String = "IDENTITY ASSIGNED BY HOST"

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
	super._ready()
	if not is_instance_valid(screen) or not is_instance_valid(proximity_area):
		set_process_input(false)
		return
	if not is_instance_valid(screen_interactable):
		push_warning("RegistrationTerminal requires a screen Interactable reference.")
		set_process_input(false)
		return
	_network = get_node_or_null("/root/Network")
	_menu.option_confirmed.connect(_on_option_confirmed)
	if is_instance_valid(_network):
		_network.connect("identity_roster_changed", _on_identity_roster_changed)
	set_process_input(true)

func _exit_tree() -> void:
	_set_actor_movement_locked(false)
	_restore_mouse_mode()
	if is_instance_valid(_network) and _network.is_connected("identity_roster_changed", _on_identity_roster_changed):
		_network.disconnect("identity_roster_changed", _on_identity_roster_changed)

func open_registration_for_actor(actor: Node) -> bool:
	## Compatibility/convenience entry point; the base lifecycle still validates proximity.
	return begin_session(actor)

func handle_menu_action(action: StringName) -> bool:
	if not _session_active or _editing_nickname:
		return false
	return _menu.handle_action(action)

func close_registration_session() -> void:
	if has_active_session():
		end_session(END_CLOSED)

func _on_terminal_session_started(actor: Node) -> void:
	_local_actor = actor
	_set_actor_movement_locked(false)
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

func _on_terminal_session_ended(actor: Node, reason: StringName) -> void:
	if actor != _local_actor:
		return
	_set_actor_movement_locked(false)
	if _menu.is_active():
		_menu.close()
	_editing_nickname = false
	_session_active = false
	_local_actor = null
	_restore_mouse_mode()
	if reason == END_RANGE:
		screen.show_layout("warning", connection_lost_header, connection_lost_description, connection_lost_prompt)
	elif reason == END_CLOSED and is_awake():
		screen.show_layout("information", idle_header, idle_description, idle_prompt)

func _on_terminal_use_again(actor: Node) -> void:
	if actor == _local_actor and _session_active and not _editing_nickname:
		_menu.handle_action(ScreenMenu.ACTION_CONFIRM)

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
		return true
	if not _menu.select_index(option_index) and _menu.get_selected_index() != option_index:
		return true
	# Mouse menu selection is handled locally rather than through Focus, so
	# explicitly play the same first-person hand poke at the screen hit point.
	_play_terminal_click_poke(hit_position)
	_menu.confirm()
	return true

func _play_terminal_click_poke(world_point: Vector3) -> void:
	if not is_instance_valid(_local_actor) or not world_point.is_finite():
		return
	var right_hand: Hand = _local_actor.get_node_or_null("Head/Camera3D/ViewmodelHands/RightHand") as Hand
	if not is_instance_valid(right_hand):
		return
	if right_hand.begin_action(world_point):
		right_hand.finish_action(true)

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
		_set_actor_movement_locked(false)
		_show_main_menu()
	elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		_requested_nickname = _nickname_buffer.strip_edges()
		if _requested_nickname.is_empty():
			_requested_nickname = "Chicken"
		_editing_nickname = false
		_set_actor_movement_locked(false)
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
		{"id": &"edit_nickname", "label": edit_nickname_option_label},
		{"id": &"register", "label": confirm_registration_option_label},
		{"id": &"close", "label": close_terminal_option_label}
	]
	_menu.open(
		screen,
		registration_header,
		main_menu_description_format % [
			_requested_nickname
		],
		options,
		main_menu_prompt
	)

func _begin_nickname_edit() -> void:
	_menu.close()
	_editing_nickname = true
	_set_actor_movement_locked(true)
	_nickname_buffer = _requested_nickname
	_render_nickname_editor()

func _set_actor_movement_locked(locked: bool) -> void:
	if is_instance_valid(_local_actor) and _local_actor.has_method("set_terminal_movement_locked"):
		_local_actor.call("set_terminal_movement_locked", locked)

func _render_nickname_editor() -> void:
	screen.show_layout(
		"information",
		nickname_editor_header,
		"%s_\n\n%s" % [
			_nickname_buffer,
			nickname_editor_instruction_format % [PlayerIdentity.MAX_NICKNAME_LENGTH]
		],
		nickname_editor_prompt
	)

func _on_option_confirmed(option_id: StringName, _option_label: String) -> void:
	match option_id:
		&"edit_nickname":
			_begin_nickname_edit()
		&"register":
			_submit_registration()
		&"close":
			close_registration_session()

func _submit_registration() -> void:
	if not is_instance_valid(_network):
		_menu.close()
		end_session(END_CLOSED)
		screen.show_layout("warning", network_unavailable_header, network_unavailable_description, reopen_prompt)
		return
	_pending_nickname = _requested_nickname
	_registration_pending = true
	var submitted: bool = bool(_network.call("request_identity", _requested_nickname, _requested_color_index))
	if not submitted:
		_registration_pending = false
		_menu.close()
		end_session(END_CLOSED)
		screen.show_layout("warning", registration_rejected_header, registration_rejected_description, reopen_prompt)
		return
	if _registration_pending:
		_menu.close()
		screen.show_layout("information", registration_sent_header, registration_sent_description, please_wait_prompt)

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
	if has_active_session():
		end_session(END_CLOSED)
	_menu.close()
	screen.show_layout(
		"success",
		registration_success_header,
		registration_success_body_format % [identity.get_display_label()],
		registration_success_prompt
	)
