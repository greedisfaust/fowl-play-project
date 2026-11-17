## M0 player controller.
## Owns local capsule movement, mouse look, camera capture, and debug state.

extends CharacterBody3D

const TUNING = preload("res://core/tuning.gd")
const LAYERS = preload("res://core/layers.gd")
const LIMP_LOOK_YAW_LIMIT: float = deg_to_rad(75.0)
const LIMP_LOOK_PITCH_LIMIT: float = deg_to_rad(75.0)

# M3: owner drives standing movement; host validates before relay.
var input_peer_id: int = 0
var is_local_player: bool = true
var is_limp: bool = false
var limp_epoch: int = 0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var rig: Node3D = get_node_or_null("Rig") as Node3D
@onready var focus: Node = get_node_or_null("Head/Camera3D/Focus")
@onready var debug_hub: Node = get_node("/root/DebugHub")
@onready var network: Node = get_node("/root/Network")

const MOVEMENT_STREAM = preload("res://core/movement_stream.gd")
var _movement: MOVEMENT_STREAM = MOVEMENT_STREAM.new()
var _send_elapsed: float = 0.0
var _movement_sequence: int = 0
var _ragdoll_send_elapsed: float = 0.0
var _ragdoll_sequence: int = 0
var _ragdoll_slow_elapsed: float = 0.0
var _ragdoll_settled_sent: bool = false
var _limp_elapsed_s: float = 0.0
# Profiling can keep a spike alive beyond the gameplay recovery deadline.
var auto_recovery_enabled: bool = true
var accepted_position: Vector3

var _pitch_radians: float = 0.0
var _limp_look_yaw: float = 0.0
var _limp_look_pitch: float = 0.0
var _debug_command_name: StringName
var _debug_speed_watch_name: StringName
var _debug_floor_watch_name: StringName
var _debug_limp_watch_name: StringName
var _debug_limp_elapsed_watch_name: StringName
var _debug_camera_follow_watch_name: StringName

func _ready() -> void:
	accepted_position = global_position
	_movement.reset(global_position, Time.get_ticks_msec() / 1000.0)
	network.call("register_movement_player", input_peer_id, self)
	is_local_player = input_peer_id == 0 or input_peer_id == multiplayer.get_unique_id()
	camera.current = is_local_player
	if rig != null:
		# Hide the owner's world model until the first-person body visibility pass.
		rig.visible = not is_local_player
	set_process_unhandled_input(is_local_player)
	set_physics_process(is_local_player)
	if focus != null:
		focus.call("set_active", is_local_player)
	_debug_command_name = StringName("player_status_%s" % name)
	_debug_speed_watch_name = StringName("player/%s/speed_mps" % name)
	_debug_floor_watch_name = StringName("player/%s/on_floor" % name)
	_debug_limp_watch_name = StringName("player/%s/limp" % name)
	_debug_limp_elapsed_watch_name = StringName("player/%s/limp_elapsed_s" % name)
	_debug_camera_follow_watch_name = StringName("player/%s/camera_following_ragdoll" % name)
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
	debug_hub.call("watch", _debug_limp_watch_name, func() -> bool: return is_limp)
	debug_hub.call("watch", _debug_limp_elapsed_watch_name, func() -> float: return _limp_elapsed_s)
	debug_hub.call("watch", _debug_camera_follow_watch_name, func() -> bool: return is_local_player and is_limp and camera.top_level)
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
	network.call("apply_pending_ragdoll_start", input_peer_id, self)

func _exit_tree() -> void:
	if is_limp and is_instance_valid(rig):
		rig.call("stop_host_simulation")
	if is_instance_valid(network):
		network.call("unregister_movement_player", input_peer_id, self)
	if not is_instance_valid(debug_hub):
		return
	# Use the original registration names even if the node was renamed.
	debug_hub.call("unregister_command", _debug_command_name)
	debug_hub.call("unwatch", _debug_speed_watch_name)
	debug_hub.call("unwatch", _debug_floor_watch_name)
	debug_hub.call("unwatch", _debug_limp_watch_name)
	debug_hub.call("unwatch", _debug_limp_elapsed_watch_name)
	debug_hub.call("unwatch", _debug_camera_follow_watch_name)

func _process(delta: float) -> void:
	if is_limp:
		_update_limp_camera(delta)
		if bool(network.get("is_host")) and rig != null:
			_limp_elapsed_s += delta
			var bones_slow: bool = bool(rig.call("are_physical_bones_slow"))
			if auto_recovery_enabled and (_limp_elapsed_s >= TUNING.LIMP_MAX_SECONDS or (_limp_elapsed_s >= TUNING.LIMP_SECONDS and bones_slow)):
				var reason: String = "hard cap" if _limp_elapsed_s >= TUNING.LIMP_MAX_SECONDS else "settled"
				network.call("stop_ragdoll_spike", input_peer_id, reason)
				return
			if bones_slow:
				_ragdoll_slow_elapsed += delta
				if _ragdoll_slow_elapsed >= 0.35 and not _ragdoll_settled_sent:
					_ragdoll_sequence += 1
					network.call("publish_settled_ragdoll_pose", input_peer_id, limp_epoch, _ragdoll_sequence, rig.call("capture_quantized_pose"))
					_ragdoll_settled_sent = true
			else:
				_ragdoll_slow_elapsed = 0.0
				_ragdoll_settled_sent = false
			if _ragdoll_settled_sent:
				return
			_ragdoll_send_elapsed += delta
			var send_interval: float = 1.0 / maxi(int(network.get("ragdoll_send_hz")), 1)
			if _ragdoll_send_elapsed >= send_interval:
				_ragdoll_send_elapsed -= send_interval
				_ragdoll_sequence += 1
				network.call("publish_ragdoll_pose", input_peer_id, limp_epoch, _ragdoll_sequence, rig.call("capture_quantized_pose"))
		return
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
	if is_limp:
		return false
	var now: float = Time.get_ticks_msec() / 1000.0
	if not _movement.accept(sequence, at, speed, yaw, pitch, now):
		return false
	accepted_position = at
	receive_movement(sequence, at, speed, yaw, pitch)
	return true

func receive_movement(sequence: int, at: Vector3, speed: Vector3, yaw: float, pitch: float) -> void:
	if is_limp:
		return
	if not is_local_player:
		_movement.push(sequence, at, speed, yaw, pitch, Time.get_ticks_msec() / 1000.0)

func correct_movement(at: Vector3) -> void:
	if is_limp:
		return
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
	if is_limp:
		return
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

## Internal host-only handoff. A later reliable limp event will invoke this.
func begin_host_limp() -> bool:
	if is_limp or rig == null or (network.get("peer") != null and not bool(network.get("is_host"))):
		return false
	collision_layer = 0
	collision_mask = 0
	if not bool(rig.call("begin_host_simulation")):
		collision_layer = 1 << (LAYERS.HEALTHY_PLAYERS - 1)
		collision_mask = LAYERS.LAYER_MASK_HEALTHY_PLAYERS
		return false
	is_limp = true
	_ragdoll_sequence = 0
	_ragdoll_send_elapsed = 0.0
	_ragdoll_slow_elapsed = 0.0
	_ragdoll_settled_sent = false
	_limp_elapsed_s = 0.0
	velocity = Vector3.ZERO
	if focus != null:
		focus.call("set_active", false)
	_begin_limp_camera()
	debug_hub.call("log", &"limp", "Player %s entered host-simulated limp." % name)
	return true

## The host chooses the standing capsule position before restoring the rig.
func stop_host_limp() -> void:
	if not is_limp:
		return
	var recovery_position: Vector3 = _find_recovery_position()
	rig.call("stop_host_simulation")
	global_position = recovery_position
	is_limp = false
	_limp_elapsed_s = 0.0
	_end_limp_camera()
	velocity = Vector3.ZERO
	collision_layer = 1 << (LAYERS.HEALTHY_PLAYERS - 1)
	collision_mask = LAYERS.LAYER_MASK_HEALTHY_PLAYERS
	if focus != null:
		focus.call("set_active", is_local_player)
	_reset_movement_after_limp()
	debug_hub.call("log", &"limp", "Player %s recovered at %s." % [name, recovery_position])

func _find_recovery_position() -> Vector3:
	var hips: Vector3 = rig.call("get_hips_world_position")
	if not hips.is_finite():
		return global_position
	var standing_at: Vector3 = Vector3(hips.x, global_position.y, hips.z)
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		hips + Vector3.UP * 0.6,
		hips + Vector3.DOWN * 2.5,
		(1 << (LAYERS.WORLD_STATIC - 1)) | (1 << (LAYERS.ELEVATOR - 1))
	)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty() and (hit.normal as Vector3).dot(Vector3.UP) > 0.6:
		standing_at.y = (hit.position as Vector3).y + 0.03
	else:
		debug_hub.call("warn", &"limp", "No walkable floor beneath player %s; retaining previous standing height." % name)
	return standing_at

func begin_remote_limp(epoch: int, world_transform: Transform3D, initial_pose: PackedInt32Array) -> bool:
	if is_limp or epoch <= limp_epoch or rig == null:
		return false
	if not bool(rig.call("begin_remote_pose", world_transform, initial_pose)):
		return false
	limp_epoch = epoch
	is_limp = true
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	if focus != null:
		focus.call("set_active", false)
	_begin_limp_camera()
	debug_hub.call("log", &"limp", "Player %s received limp start." % name)
	return true

func receive_remote_pose(epoch: int, sequence: int, host_time_ms: int, pose: PackedInt32Array) -> bool:
	if not is_limp or epoch != limp_epoch or rig == null:
		return false
	return bool(rig.call("push_remote_pose", sequence, host_time_ms, pose))

func receive_remote_settled_pose(epoch: int, sequence: int, host_time_ms: int, pose: PackedInt32Array) -> bool:
	if not is_limp or epoch != limp_epoch or rig == null:
		return false
	return bool(rig.call("push_settled_pose", sequence, host_time_ms, pose))

func end_remote_limp(epoch: int, standing_at: Vector3) -> bool:
	if not is_limp or epoch != limp_epoch or rig == null or not standing_at.is_finite():
		return false
	rig.call("end_remote_pose")
	global_position = standing_at
	is_limp = false
	_end_limp_camera()
	velocity = Vector3.ZERO
	collision_layer = 1 << (LAYERS.HEALTHY_PLAYERS - 1)
	collision_mask = LAYERS.LAYER_MASK_HEALTHY_PLAYERS
	if focus != null:
		focus.call("set_active", is_local_player)
	_reset_movement_after_limp()
	debug_hub.call("log", &"limp", "Player %s received limp end." % name)
	return true

func _reset_movement_after_limp() -> void:
	accepted_position = global_position
	_movement.position = global_position
	_movement.last_time = Time.get_ticks_msec() / 1000.0
	_movement.samples.clear()
	_movement.horizontal_budget = 0.5
	_movement.vertical_budget = 0.5

func _begin_limp_camera() -> void:
	if not is_local_player:
		return
	var camera_transform: Transform3D = camera.global_transform
	camera.top_level = true
	camera.global_transform = camera_transform
	_limp_look_yaw = 0.0
	_limp_look_pitch = clampf(_pitch_radians, -LIMP_LOOK_PITCH_LIMIT, LIMP_LOOK_PITCH_LIMIT)
	# Keep the body visible without placing the camera inside its head mesh.
	if rig != null:
		rig.visible = true
		rig.call("set_owner_head_visible", false)

func _update_limp_camera(_delta: float) -> void:
	if not is_local_player or rig == null:
		return
	var eye_transform: Transform3D = rig.call("get_head_eye_transform")
	if not eye_transform.is_finite():
		return
	var look_yaw: Basis = Basis(Vector3.UP, _limp_look_yaw)
	var look_pitch: Basis = Basis(Vector3.RIGHT, _limp_look_pitch)
	camera.global_transform = Transform3D(eye_transform.basis * look_yaw * look_pitch, eye_transform.origin)

func _end_limp_camera() -> void:
	if not is_local_player:
		return
	rotate_y(_limp_look_yaw)
	_pitch_radians = _limp_look_pitch
	head.rotation.x = _pitch_radians
	camera.top_level = false
	camera.transform = Transform3D.IDENTITY
	if rig != null:
		rig.call("set_owner_head_visible", true)
		rig.visible = false

func _rotate_view(mouse_delta: Vector2) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if is_limp:
		_rotate_limp_view(mouse_delta)
		return
	rotate_y(-mouse_delta.x * TUNING.MOUSE_SENSITIVITY)
	_pitch_radians = clampf(
		_pitch_radians - mouse_delta.y * TUNING.MOUSE_SENSITIVITY,
		deg_to_rad(-85.0),
		deg_to_rad(85.0)
	)
	head.rotation.x = _pitch_radians

func _rotate_limp_view(mouse_delta: Vector2) -> void:
	_limp_look_yaw = clampf(
		_limp_look_yaw - mouse_delta.x * TUNING.MOUSE_SENSITIVITY,
		-LIMP_LOOK_YAW_LIMIT,
		LIMP_LOOK_YAW_LIMIT
	)
	_limp_look_pitch = clampf(
		_limp_look_pitch - mouse_delta.y * TUNING.MOUSE_SENSITIVITY,
		-LIMP_LOOK_PITCH_LIMIT,
		LIMP_LOOK_PITCH_LIMIT
	)

func _debug_status(_args: Array[Variant]) -> String:
	return "position=%s velocity=%s on_floor=%s" % [
		global_position,
		velocity,
		is_on_floor(),
	]
