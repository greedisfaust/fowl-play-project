## M0 player controller.
## Owns local capsule movement, mouse look, camera capture, and debug state.

extends CharacterBody3D

const TUNING = preload("res://core/tuning.gd")

@onready var head: Node3D = $Head
@onready var debug_hub: Node = get_node("/root/DebugHub")

var _pitch_radians: float = 0.0
var _debug_command_name: StringName

func _ready() -> void:
	_debug_command_name = StringName("player_status_%s" % name)
	debug_hub.call(
		"watch",
		StringName("player/%s/speed_mps" % name),
		func() -> float:
			return velocity.length()
	)
	debug_hub.call(
		"watch",
		StringName("player/%s/on_floor" % name),
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
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

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
	if bool(debug_hub.call("is_console_open")):
		velocity.x = 0.0
		velocity.z = 0.0
		return
	if not is_on_floor():
		velocity.y -= TUNING.GRAVITY_MPS2 * delta
	elif Input.is_action_just_pressed("jump"):
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
