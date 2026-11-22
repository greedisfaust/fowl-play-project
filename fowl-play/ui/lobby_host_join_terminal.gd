## Host / Join / Leave flow for the Apartment lobby's reusable Slim WorldScreen.
class_name LobbyHostJoinTerminal
extends InteractiveTerminal

const MAIN_MENU_HEADER: String = "MULTIPLAYER"
const MAIN_MENU_DESCRIPTION: String = "HOST A SESSION, JOIN A FRIEND, OR LEAVE YOUR CURRENT SESSION."
const MAIN_MENU_PROMPT: String = "UP/DOWN MOVE  •  ENTER / USE SELECT  •  ESC BACK"
const JOIN_HEADER: String = "JOIN SESSION"
const JOIN_PROMPT: String = "TYPE HOST IP  •  ENTER CONNECTS  •  ESC BACK"
const HOST_HEADER: String = "SESSION HOSTING"
const CLIENT_HEADER: String = "CONNECTED"
const ERROR_HEADER: String = "CONNECTION FAILED"
const LEAVE_CONFIRM_HEADER: String = "CLOSE HOST SESSION?"
const LEAVE_CONFIRM_BODY: String = "Other players are connected. Leaving will close this host session and disconnect everyone. They can host or join another session afterward."

var _menu: ScreenMenu = ScreenMenu.new()
var _network: Node = null
var _local_actor: Node = null
var _session_active: bool = false
var _editing_address: bool = false
var _address_buffer: String = ""
var _previous_mouse_mode: int = Input.MOUSE_MODE_CAPTURED
var _mouse_released_for_menu: bool = false
var _status_presentation: String = ""
var _was_client: bool = false
var _returning_to_apartment: bool = false

func _ready() -> void:
	super._ready()
	if not is_instance_valid(screen) or not is_instance_valid(proximity_area) or not is_instance_valid(screen_interactable):
		set_process_input(false)
		return
	_network = get_node_or_null("/root/Network")
	_menu.option_confirmed.connect(_on_option_confirmed)
	if is_instance_valid(_network) and _network.has_signal("session_ended"):
		_network.connect("session_ended", _on_network_session_ended)
	set_process_input(true)

func _exit_tree() -> void:
	_set_actor_movement_locked(false)
	_restore_mouse_mode()
	if is_instance_valid(_network) and _network.has_signal("session_ended") and _network.is_connected("session_ended", _on_network_session_ended):
		_network.disconnect("session_ended", _on_network_session_ended)

func _process(delta: float) -> void:
	super._process(delta)
	if is_instance_valid(_network) and bool(_network.get("is_client")):
		_was_client = true
	if not _session_active or _editing_address or not is_instance_valid(_network):
		return
	var status: String = str(_network.get("status"))
	if status == "hosting" and _status_presentation != "hosting":
		_status_presentation = "hosting"
		_show_host_details()
	elif status == "connected" and _status_presentation != "connected":
		_status_presentation = "connected"
		_show_client_details()
	elif status == "failed" and _status_presentation != "failed":
		_status_presentation = "failed"
		_menu.close()
		screen.show_layout("warning", ERROR_HEADER, "Could not connect to that address. Check the IP and make sure the host is online.", "ESC RETURN TO MENU")

func handle_menu_action(action: StringName) -> bool:
	if not _session_active or _editing_address:
		return false
	return _menu.handle_action(action)

func _on_terminal_session_started(actor: Node) -> void:
	_local_actor = actor
	_session_active = true
	_editing_address = false
	_address_buffer = ""
	_status_presentation = ""
	_was_client = is_instance_valid(_network) and bool(_network.get("is_client"))
	_release_mouse_for_menu()
	_show_main_menu()

func _on_terminal_session_ended(actor: Node, _reason: StringName) -> void:
	if actor != _local_actor:
		return
	_set_actor_movement_locked(false)
	if _menu.is_active():
		_menu.close()
	_editing_address = false
	_session_active = false
	_local_actor = null
	_restore_mouse_mode()
	if is_awake():
		screen.show_layout("information", idle_header, idle_description, idle_prompt)

func _on_terminal_use_again(actor: Node) -> void:
	if actor == _local_actor and _session_active and not _editing_address and _menu.is_active():
		_menu.handle_action(ScreenMenu.ACTION_CONFIRM)

func _input(event: InputEvent) -> void:
	if not _session_active:
		return
	if event is InputEventMouseButton and _handle_screen_click(event as InputEventMouseButton):
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if _editing_address:
		_handle_address_key(key_event)
		get_viewport().set_input_as_handled()
		return
	if _status_presentation == "hosting" or _status_presentation == "connected" or _status_presentation == "failed":
		if key_event.keycode == KEY_ESCAPE:
			_status_presentation = ""
			_show_main_menu()
			get_viewport().set_input_as_handled()
		return
	if key_event.keycode == KEY_UP:
		_menu.handle_action(ScreenMenu.ACTION_UP)
	elif key_event.keycode == KEY_DOWN:
		_menu.handle_action(ScreenMenu.ACTION_DOWN)
	elif key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
		_menu.handle_action(ScreenMenu.ACTION_CONFIRM)
	elif key_event.keycode == KEY_ESCAPE:
		if _menu.is_active():
			end_session(END_CLOSED)
	else:
		return
	get_viewport().set_input_as_handled()

func _show_main_menu() -> void:
	if not is_instance_valid(screen):
		return
	var active_network: bool = is_instance_valid(_network) and _network.get("peer") != null
	var options: Array[Dictionary] = [
		{"id": &"host", "label": "HOST", "enabled": not active_network},
		{"id": &"join", "label": "JOIN", "enabled": not active_network},
		{"id": &"leave", "label": "LEAVE", "enabled": active_network}
	]
	_menu.open(screen, MAIN_MENU_HEADER, MAIN_MENU_DESCRIPTION, options, MAIN_MENU_PROMPT)

func _on_option_confirmed(option_id: StringName, _option_label: String) -> void:
	match option_id:
		&"host":
			_start_host()
		&"join":
			_begin_address_entry()
		&"leave":
			_request_leave()
		&"confirm_leave":
			_leave_network_session()
		&"cancel_leave":
			_show_main_menu()

func _start_host() -> void:
	if not is_instance_valid(_network):
		_show_error("NETWORK AUTOLOAD IS UNAVAILABLE.")
		return
	_menu.close()
	var result: int = int(_network.call("start_host"))
	if result != OK:
		_show_error("HOST START FAILED: %s" % error_string(result))
		return
	_status_presentation = "hosting"
	_show_host_details()

func _show_host_details() -> void:
	var addresses: PackedStringArray = PackedStringArray()
	for address: String in IP.get_local_addresses():
		if address.is_valid_ip_address() and address.contains(".") and not address.begins_with("127."):
			if not addresses.has(address):
				addresses.append(address)
	var address_text: String = "\n".join(addresses)
	if address_text.is_empty():
		address_text = "No LAN IPv4 address detected. Check your network adapter."
	var port_value: int = int(_network.get("port"))
	screen.show_layout(
		"success",
		HOST_HEADER,
		"YOUR SESSION IS OPEN.\n\nSHARE ONE OF THESE LAN ADDRESSES:\n%s\n\nPORT: %d" % [address_text, port_value],
		"ESC BACK TO MENU  •  FRIENDS SELECT JOIN"
	)

func _begin_address_entry() -> void:
	_menu.close()
	_editing_address = true
	_address_buffer = ""
	_set_actor_movement_locked(true)
	_render_address_entry()

func _render_address_entry() -> void:
	screen.show_layout(
		"information",
		JOIN_HEADER,
		"%s_\n\nENTER THE HOST'S IPv4 ADDRESS." % _address_buffer,
		JOIN_PROMPT
	)

func _handle_address_key(event: InputEventKey) -> void:
	if event.keycode == KEY_ESCAPE:
		_editing_address = false
		_set_actor_movement_locked(false)
		_show_main_menu()
	elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		_confirm_join()
	elif event.keycode == KEY_BACKSPACE:
		if not _address_buffer.is_empty():
			_address_buffer = _address_buffer.left(_address_buffer.length() - 1)
			_render_address_entry()
	elif event.unicode >= 48 and event.unicode <= 57 or event.unicode == 46:
		if _address_buffer.length() < 15:
			_address_buffer += String.chr(event.unicode)
			_render_address_entry()

func _confirm_join() -> void:
	var address: String = _address_buffer.strip_edges()
	if not address.is_valid_ip_address() or not address.contains("."):
		screen.show_layout("warning", "INVALID IP ADDRESS", "Enter a valid IPv4 address, for example 192.168.1.20.", "TYPE AGAIN  •  ESC CANCELS")
		return
	if not is_instance_valid(_network):
		_show_error("NETWORK AUTOLOAD IS UNAVAILABLE.")
		return
	_editing_address = false
	_set_actor_movement_locked(false)
	var result: int = int(_network.call("join_server", address))
	if result != OK:
		_show_error("JOIN FAILED TO START: %s" % error_string(result))
		return
	_menu.close()
	_status_presentation = "connecting"
	screen.show_layout("information", "CONNECTING", "CONTACTING %s:%d..." % [address, int(_network.get("port"))], "PLEASE WAIT")
	_status_presentation = "connecting"

func _show_client_details() -> void:
	screen.show_layout("success", CLIENT_HEADER, "YOU ARE CONNECTED TO THE HOST SESSION.", "ESC BACK TO MENU  •  LEAVE TO DISCONNECT")

func _request_leave() -> void:
	if not is_instance_valid(_network) or _network.get("peer") == null:
		_show_main_menu()
		return
	if bool(_network.get("is_host")):
		var peers: Array[int] = _network.get("connected_peers")
		if peers.size() > 1:
			var options: Array[Dictionary] = [
				{"id": &"confirm_leave", "label": "YES, CLOSE SESSION"},
				{"id": &"cancel_leave", "label": "CANCEL"}
			]
			_menu.open(screen, LEAVE_CONFIRM_HEADER, LEAVE_CONFIRM_BODY, options, "UP/DOWN MOVE  •  ENTER CONFIRM")
			return
	_leave_network_session()

func _leave_network_session() -> void:
	if not is_instance_valid(_network):
		return
	_network.call("shutdown")
	_was_client = false
	_status_presentation = ""
	_return_to_apartment()

func _on_network_session_ended() -> void:
	if _was_client and not _returning_to_apartment:
		_handle_network_session_ended_deferred.call_deferred()

func _handle_network_session_ended_deferred() -> void:
	if not _was_client or _returning_to_apartment or not is_instance_valid(_network):
		return
	_was_client = false
	if str(_network.get("status")) == "failed":
		_show_error("The host could not be reached. Check the address and try again.")
		return
	_return_to_apartment()

func _return_to_apartment() -> void:
	if _returning_to_apartment:
		return
	_returning_to_apartment = true
	if has_active_session():
		end_session(END_CLOSED)
	var main: Node = get_tree().root.get_node_or_null("Main")
	if main == null:
		_returning_to_apartment = false
		return
	var active_world: int = int(main.get("active_world"))
	if active_world != 0:
		main.call("transition_to", 0)
	else:
		main.call_deferred("_refresh_players_for_world")
	_returning_to_apartment = false

func _show_error(message: String) -> void:
	_menu.close()
	_status_presentation = "failed"
	screen.show_layout("warning", ERROR_HEADER, message, "ESC RETURN TO MENU")

func _set_actor_movement_locked(locked: bool) -> void:
	if is_instance_valid(_local_actor) and _local_actor.has_method("set_terminal_movement_locked"):
		_local_actor.call("set_terminal_movement_locked", locked)

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

func _handle_screen_click(event: InputEventMouseButton) -> bool:
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT or _editing_address or not _menu.is_active():
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
	_menu.confirm()
	return true
