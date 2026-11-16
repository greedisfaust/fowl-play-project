## M0 player controller.
## Owns local capsule movement, mouse look, camera capture, and debug state.

extends CharacterBody3D

const TUNING = preload("res://core/tuning.gd")

# M3: owner drives standing movement; host validates before relay.
var input_peer_id: int = 0
var is_local_player: bool = true

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var focus: Node = get_node_or_null("Head/Camera3D/Focus")
@onready var debug_hub: Node = get_node("/root/DebugHub")
@onready var network: Node = get_node("/root/Network")

const MOVEMENT_STREAM = preload("res://core/movement_stream.gd")
var _movement: MOVEMENT_STREAM = MOVEMENT_STREAM.new()
var _send_elapsed: float = 0.0
var _movement_sequence: int = 0
var accepted_position: Vector3

var _pitch_radians: float = 0.0
var _debug_command_name: StringName
var _debug_speed_watch_name: StringName
var _debug_floor_watch_name: StringName

func _ready() -> void:
	accepted_position = global_position
	_movement.reset(global_position, Time.get_ticks_msec() / 1000.0)
	network.call("register_movement_player", input_peer_id, self)
	is_local_player = input_peer_id == 0 or input_peer_id == multiplayer.get_unique_id()
	camera.current = is_local_player
	set_process_unhandled_input(is_local_player)
	set_physics_process(is_local_player)
	if focus != null:
		focus.call("set_active", is_local_player)
	_debug_command_name = StringName("player_status_%s" % name)
	_debug_speed_watch_name = StringName("player/%s/speed_mps" % name)
	_debug_floor_watch_name = StringName("player/%s/on_floor" % name)
	debug_hub.call(
		"watch",
		_debug_speed_watch_name,
		func() -> float:
			return velocity.length()
	)
	debug_hub.call(
		"watch",
		_debug_floor_watch_name,
		func() -> bool:
			return is_on_floor()
	)
	debug_hub.call(
		"command",
		_debug_command_name,
		_debug_status,
		"Report this player's movement state.",
		false,
		false
	)
	if is_local_player and not bool(debug_hub.call("is_console_open")):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _exit_tree() -> void:
	if is_instance_valid(network):
		network.call("unregister_movement_player", input_peer_id, self)
	if not is_instance_valid(debug_hub):
		return
	# Use the original registration names even if the node was renamed.
	debug_hub.call("unregister_command", _debug_command_name)
	debug_hub.call("unwatch", _debug_speed_watch_name)
	debug_hub.call("unwatch", _debug_floor_watch_name)

func _process(delta: float) -> void:
	if is_local_player:
		_send_elapsed += delta
		if _send_elapsed >= 1.0 / TUNING.MOVE_SEND_HZ:
			_send_elapsed = 0.0
			_movement_sequence += 1
			network.call("send_movement", input_peer_id, _movement_sequence, global_position, velocity, rotation.y, _pitch_radians)
	else:
		var snapshot: Dictionary = _movement.sample(Time.get_ticks_msec() / 1000.0)
		if not snapshot.is_empty():
			global_position = snapshot.position
			velocity = snapshot.velocity
			rotation.y = snapshot.yaw
			head.rotation.x = snapshot.pitch

func accept_movement(sequence: int, at: Vector3, speed: Vector3, yaw: float, pitch: float) -> bool:
	var now: float = Time.get_ticks_msec() / 1000.0
	if not _movement.accept(sequence, at, speed, yaw, pitch, now):
		return false
	accepted_position = at
	receive_movement(sequence, at, speed, yaw, pitch)
	return true

func receive_movement(sequence: int, at: Vector3, speed: Vector3, yaw: float, pitch: float) -> void:
	if not is_local_player:
		_movement.push(sequence, at, speed, yaw, pitch, Time.get_ticks_msec() / 1000.0)

func correct_movement(at: Vector3) -> void:
	global_position = at
	velocity = Vector3.ZERO
	debug_hub.call("log", &"net", "Movement corrected for player %s" % name)

func _unhandled_input(event: InputEvent) -> void:
	if bool(debug_hub.call("is_console_open")):
		return
	if event is InputEventMouseMotion:
		var mouse_event: InputEventMouseMotion = event
		_rotate_view(mouse_event.relative)
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event
		if mouse_button.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= TUNING.GRAVITY_MPS2 * delta

	if bool(debug_hub.call("is_console_open")):
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = TUNING.JUMP_SPEED_MPS

	var input_vector: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_back"
	)
	var local_direction: Vector3 = Vector3(input_vector.x, 0.0, input_vector.y)
	var move_direction: Vector3 = (transform.basis * local_direction).normalized()
	if move_direction != Vector3.ZERO:
		velocity.x = move_direction.x * TUNING.PLAYER_SPEED_MPS
		velocity.z = move_direction.z * TUNING.PLAYER_SPEED_MPS
	else:
		velocity.x = move_toward(velocity.x, 0.0, TUNING.PLAYER_SPEED_MPS * 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, TUNING.PLAYER_SPEED_MPS * 8.0 * delta)

	move_and_slide()

func _rotate_view(mouse_delta: Vector2) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	rotate_y(-mouse_delta.x * TUNING.MOUSE_SENSITIVITY)
	_pitch_radians = clampf(
		_pitch_radians - mouse_delta.y * TUNING.MOUSE_SENSITIVITY,
		deg_to_rad(-85.0),
		deg_to_rad(85.0)
	)
	head.rotation.x = _pitch_radians

func _debug_status(_args: Array[Variant]) -> String:
	return "position=%s velocity=%s on_floor=%s" % [
		global_position,
		velocity,
		is_on_floor(),
	]
