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
var is_recovering: bool = false
var limp_epoch: int = 0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var rig: Node3D = get_node_or_null("Rig") as Node3D
@onready var world_right_hand: Hand = get_node_or_null("Rig/Skeleton3D/HandAttachment_R/HandMount_R/Hand") as Hand
@onready var carrier: Carrier = get_node_or_null("Carrier") as Carrier
@onready var limp_interactable: Interactable = get_node_or_null("Interactable") as Interactable
@onready var limp_interaction_proxy: StaticBody3D = get_node_or_null("LimpInteractionProxy") as StaticBody3D
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
var _recovery_retry_s: float = 0.0
var _recovery_blocked: bool = false
# M5 wall clearance: true when recovery placement had to move away from a wall/prop.
var wall_clearance_active: bool = false
# Profiling can keep a spike alive beyond the gameplay recovery deadline.
var auto_recovery_enabled: bool = true
var accepted_position: Vector3
# True when another player's Carrier is holding this player (limp carry).
var _is_carried: bool = false

var _pitch_radians: float = 0.0
var _limp_look_yaw: float = 0.0
var _limp_look_pitch: float = 0.0
var _carry_camera_smoothing_initialized: bool = false
var _carry_camera_smoothed_origin: Vector3 = Vector3.ZERO
var _carry_camera_smoothed_rotation: Quaternion = Quaternion.IDENTITY

# Smooth only the ragdoll-head contribution; mouse look and dynamic FOV stay untouched.
const CARRY_CAMERA_ROTATION_RESPONSE: float = 9.0
const CARRY_CAMERA_POSITION_RESPONSE: float = 14.0
var _recovery_elapsed_s: float = 0.0
var _recovery_camera_start: Transform3D
var _recovery_camera_target: Transform3D
var _debug_command_name: StringName
var _debug_speed_watch_name: StringName
var _debug_floor_watch_name: StringName
var _debug_limp_watch_name: StringName
var _debug_recovering_watch_name: StringName
var _debug_limp_elapsed_watch_name: StringName
var _debug_camera_follow_watch_name: StringName
var _debug_wall_clearance_watch_name: StringName
var _debug_carrying_watch_name: StringName
var _debug_limp_target_watch_name: StringName

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
	if limp_interactable != null:
		limp_interactable.enabled = false
		limp_interactable.availability_check = _can_be_carried
		limp_interactable.interacted.connect(_on_limp_interacted)
	if limp_interaction_proxy != null:
		limp_interaction_proxy.collision_layer = 0
	_debug_speed_watch_name = StringName("player/%s/speed_mps" % name)
	_debug_floor_watch_name = StringName("player/%s/on_floor" % name)
	_debug_limp_watch_name = StringName("player/%s/limp" % name)
	_debug_recovering_watch_name = StringName("player/%s/recovering" % name)
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
	debug_hub.call("watch", _debug_recovering_watch_name, func() -> bool: return is_recovering)
	debug_hub.call("watch", _debug_limp_elapsed_watch_name, func() -> float: return _limp_elapsed_s)
	debug_hub.call("watch", _debug_camera_follow_watch_name, func() -> bool: return is_local_player and is_limp and camera.top_level)
	debug_hub.call("watch", _debug_wall_clearance_watch_name, func() -> bool: return wall_clearance_active)
	debug_hub.call("watch", _debug_carrying_watch_name, func() -> bool: return is_carrying())
	if limp_interactable != null:
		_debug_limp_target_watch_name = StringName("player/%s/limp_interactable_enabled" % name)
		debug_hub.call("watch", _debug_limp_target_watch_name, func() -> bool: return limp_interactable.enabled)
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
	if (is_limp or is_recovering) and is_instance_valid(rig):
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
	debug_hub.call("unwatch", _debug_recovering_watch_name)
	debug_hub.call("unwatch", _debug_limp_elapsed_watch_name)
	debug_hub.call("unwatch", _debug_camera_follow_watch_name)
	debug_hub.call("unwatch", _debug_wall_clearance_watch_name)
	debug_hub.call("unwatch", _debug_carrying_watch_name)
	if not _debug_limp_target_watch_name.is_empty():
		debug_hub.call("unwatch", _debug_limp_target_watch_name)

func _process(delta: float) -> void:
	if is_limp:
		_update_limp_camera(delta)
		_update_limp_interaction_proxy()
		if _has_host_authority() and rig != null:
			if not _is_carried:
				_limp_elapsed_s += delta
				_recovery_retry_s = maxf(0.0, _recovery_retry_s - delta)
				var bones_slow: bool = bool(rig.call("are_physical_bones_slow"))
				if auto_recovery_enabled and _recovery_retry_s <= 0.0 and (_limp_elapsed_s >= TUNING.LIMP_MAX_SECONDS or (_limp_elapsed_s >= TUNING.LIMP_SECONDS and bones_slow)):
					var reason: String = "hard cap" if _limp_elapsed_s >= TUNING.LIMP_MAX_SECONDS else "settled"
					if bool(network.call("stop_ragdoll_spike", input_peer_id, reason)):
						return
					_recovery_retry_s = 0.25
				if bones_slow:
					_ragdoll_slow_elapsed += delta
					if _ragdoll_slow_elapsed >= 0.35 and not _ragdoll_settled_sent:
						_ragdoll_sequence += 1
						network.call("publish_settled_ragdoll_pose", input_peer_id, limp_epoch, _ragdoll_sequence, rig.call("capture_quantized_pose"))
						_ragdoll_settled_sent = true
				else:
					_ragdoll_slow_elapsed = 0.0
					_ragdoll_settled_sent = false
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
	if is_recovering:
		_update_recovery_camera(delta)
		if rig != null and not bool(rig.call("is_pose_blending")):
			_finish_recovery()
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

func _has_host_authority() -> bool:
	return network.get("peer") == null or bool(network.get("is_host"))

func _set_limp_interaction_proxy(active: bool) -> void:
	if limp_interaction_proxy == null:
		return
	if active:
		limp_interaction_proxy.top_level = true
		limp_interaction_proxy.collision_layer = 1 << (LAYERS.LIMP_BODIES - 1)
		_update_limp_interaction_proxy()
	else:
		limp_interaction_proxy.collision_layer = 0
		limp_interaction_proxy.top_level = false
		limp_interaction_proxy.transform = Transform3D.IDENTITY

func _update_limp_interaction_proxy() -> void:
	if limp_interaction_proxy == null or limp_interaction_proxy.collision_layer == 0 or not is_limp or rig == null:
		return
	limp_interaction_proxy.global_position = rig.call("get_hips_world_position")

func accept_movement(sequence: int, at: Vector3, speed: Vector3, yaw: float, pitch: float) -> bool:
	if is_limp or is_recovering:
		return false
	var now: float = Time.get_ticks_msec() / 1000.0
	if not _movement.accept(sequence, at, speed, yaw, pitch, now):
		return false
	accepted_position = at
	receive_movement(sequence, at, speed, yaw, pitch)
	return true

## Returns true while this player holds a carried item (prop or limp body).
func is_carrying() -> bool:
	return carrier != null and bool(carrier.call("is_holding"))

## Plays a host-approved poke on this player's visible world right hand.
## The local owner already sees the first-person poke, so only remote copies animate.
func play_world_hand_poke(world_point: Vector3) -> bool:
	if is_local_player or is_limp or is_recovering or is_carrying() or not world_point.is_finite():
		return false
	if not is_instance_valid(world_right_hand):
		return false
	return world_right_hand.reach(world_point)

## Returns true while another player's Carrier is holding this player (limp carry).
func is_carried() -> bool:
	return _is_carried

func _can_be_carried(actor: Node, action: StringName) -> bool:
	return action == &"grab" and actor != self and is_limp and not is_recovering and not _is_carried

func set_carried(carried: bool, by: Node3D = null) -> void:
	if carried:
		if _is_carried or not is_limp or is_recovering:
			return
		_is_carried = true
		_carry_camera_smoothing_initialized = false
		_set_limp_interaction_proxy(false)
		if _has_host_authority() and rig != null:
			rig.call("disable_collisions")
			rig.call("stop_carry_support")
			rig.call("begin_carry_physics")
			_ragdoll_slow_elapsed = 0.0
			_ragdoll_settled_sent = false
			_ragdoll_send_elapsed = 0.0
		debug_hub.call("log", &"carry", "%s is now carried by %s" % [name, by.name if by != null else "unknown"])
		return
	if not _is_carried:
		return
	_is_carried = false
	_carry_camera_smoothing_initialized = false
	if _has_host_authority() and is_limp and rig != null:
		rig.call("end_carry_physics")
		rig.call("stop_carry_support")
		rig.call("enable_host_collisions")
		_reset_limp_recovery_deadline()
	elif is_limp:
		_set_limp_interaction_proxy(true)
	debug_hub.call("log", &"carry", "%s was released by %s" % [name, by.name if by != null else "unknown"])

func set_carry_target(target_world: Vector3, facing_world: Vector3 = Vector3.ZERO) -> void:
	if _is_carried and is_limp and rig != null and _has_host_authority():
		rig.call("set_carry_target", target_world, facing_world)

func get_carry_world_position() -> Vector3:
	return Vector3(rig.call("get_hips_world_position")) if is_limp and rig != null else global_position

func get_interaction_world_position() -> Vector3:
	return get_carry_world_position()

func _reset_limp_recovery_deadline() -> void:
	_limp_elapsed_s = 0.0
	_recovery_retry_s = 0.0
	_ragdoll_slow_elapsed = 0.0
	_ragdoll_settled_sent = false
	_ragdoll_send_elapsed = 0.0

func apply_release(at: Vector3, linear: Vector3, angular: Vector3) -> void:
	if _is_carried:
		set_carried(false, null)
	if is_limp and rig != null:
		if _has_host_authority():
			rig.call("release_carry", linear, angular)
			_reset_limp_recovery_deadline()
		velocity = linear
		return
	global_position = at
	velocity = linear

func receive_movement(sequence: int, at: Vector3, speed: Vector3, yaw: float, pitch: float) -> void:
	if is_limp or is_recovering:
		return
	if not is_local_player:
		_movement.push(sequence, at, speed, yaw, pitch, Time.get_ticks_msec() / 1000.0)

func correct_movement(at: Vector3) -> void:
	if is_limp or is_recovering:
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
	elif event.is_action_pressed("punch"):
		# While carrying, punch is owned by the Carrier (tap = drop, hold = throw).
		# Do not also process it as combat input; M7 combat reads punch only when
		# not carrying. When not carrying, fall through so M7 can claim it.
		if is_carrying():
			return
	elif event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event
		if mouse_button.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	if is_limp:
		if _is_carried and _has_host_authority() and rig != null:
			rig.call("apply_carry_support")
		return
	if is_recovering:
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

## Host-only: called when another player grabs this limp player's Interactable.
## Delegates to Network.host_begin_carry so host validation applies.
func _on_limp_interacted(actor: Node, action: StringName) -> void:
	if action != &"grab":
		return
	var network_node: Node = get_node("/root/Network")
	if bool(network_node.call("host_begin_carry", actor, self)):
		debug_hub.call("log", &"carry", "%s grabbed by %s" % [name, actor.name])
	else:
		debug_hub.call("warn", &"carry", "%s grab rejected by %s" % [name, actor.name])

## Internal host-only handoff. A later reliable limp event will invoke this.
func begin_host_limp() -> bool:
	if is_limp or is_recovering or rig == null or (network.get("peer") != null and not bool(network.get("is_host"))):
		return false
	if is_carrying():
		network.call("force_drop_carry", input_peer_id, "entered limp")
	collision_layer = 0
	collision_mask = 0
	if not bool(rig.call("begin_host_simulation")):
		collision_layer = 1 << (LAYERS.HEALTHY_PLAYERS - 1)
		collision_mask = LAYERS.LAYER_MASK_HEALTHY_PLAYERS
		return false
	is_limp = true
	set_physics_process(true)
	_set_limp_interaction_proxy(false)
	if limp_interactable != null:
		limp_interactable.enabled = true
		debug_hub.call("log", &"carry", "%s limp Interactable enabled as grab target." % name)
	_ragdoll_sequence = 0
	_ragdoll_send_elapsed = 0.0
	_ragdoll_slow_elapsed = 0.0
	_ragdoll_settled_sent = false
	_limp_elapsed_s = 0.0
	_recovery_retry_s = 0.0
	_recovery_blocked = false
	wall_clearance_active = false
	velocity = Vector3.ZERO
	if focus != null:
		focus.call("set_active", false)
	_begin_limp_camera()
	debug_hub.call("log", &"limp", "Player %s entered host-simulated limp." % name)
	return true

## The host chooses the standing capsule position before restoring the rig.
func stop_host_limp(recovery_variant: StringName = &"") -> bool:
	if not is_limp or _is_carried:
		return false
	var recovery_position: Vector3 = _find_recovery_position()
	if not recovery_position.is_finite():
		if not _recovery_blocked:
			debug_hub.call("warn", &"limp", "Player %s recovery blocked: no supported, clear capsule position; retrying while limp." % name)
		_recovery_blocked = true
		return false
	_recovery_blocked = false
	# Move the capsule while the ragdoll is still independent of its parent.
	global_position = recovery_position
	rig.call("stop_host_simulation_with_blend", TUNING.GET_UP_BLEND_SECONDS, recovery_variant)
	is_limp = false
	is_recovering = true
	_set_limp_interaction_proxy(false)
	set_physics_process(is_local_player)
	if limp_interactable != null:
		limp_interactable.enabled = false
		debug_hub.call("log", &"carry", "%s limp Interactable disabled on recovery." % name)
	_limp_elapsed_s = 0.0
	_begin_recovery_camera()
	velocity = Vector3.ZERO
	collision_layer = 1 << (LAYERS.HEALTHY_PLAYERS - 1)
	collision_mask = LAYERS.LAYER_MASK_HEALTHY_PLAYERS
	if focus != null:
		focus.call("set_active", false)
	_reset_movement_after_limp()
	debug_hub.call("log", &"limp", "Player %s recovered at %s." % [name, recovery_position])
	return true

func _find_recovery_position() -> Vector3:
	var hips: Vector3 = rig.call("get_hips_world_position")
	wall_clearance_active = false
	if not hips.is_finite():
		return Vector3.INF
	var collider: CollisionShape3D = $CollisionShape3D
	var excluded: Array[RID] = [get_rid()]
	for bone: PhysicalBone3D in rig.get("physical_bones"):
		excluded.append(bone.get_rid())
	var params: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	params.shape = collider.shape
	params.collision_mask = LAYERS.LAYER_MASK_HEALTHY_PLAYERS | (1 << (LAYERS.HEALTHY_PLAYERS - 1))
	params.exclude = excluded
	params.margin = 0.01
	var standing_at: Vector3 = _recovery_candidate(hips, collider.transform, params)
	if standing_at.is_finite():
		return standing_at
	for step_count: int in range(1, int(TUNING.WALL_CLEARANCE_MAX_RADIUS / TUNING.WALL_CLEARANCE_STEP) + 1):
		var radius: float = step_count * TUNING.WALL_CLEARANCE_STEP
		for angle_index: int in range(TUNING.WALL_CLEARANCE_ANGLE_COUNT):
			var angle: float = float(angle_index) * TAU / float(TUNING.WALL_CLEARANCE_ANGLE_COUNT)
			var candidate: Vector3 = hips + Vector3(cos(angle), 0.0, sin(angle)) * radius
			standing_at = _recovery_candidate(candidate, collider.transform, params)
			if standing_at.is_finite():
				wall_clearance_active = true
				debug_hub.call("log", &"limp", "Player %s wall clearance: offset recovery by %.2f m at %.0f degrees." % [name, radius, rad_to_deg(angle)])
				return standing_at
	return Vector3.INF

func _recovery_candidate(at: Vector3, collider_transform: Transform3D, params: PhysicsShapeQueryParameters3D) -> Vector3:
	# Every candidate needs its own walkable support, including near ledges.
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	ray.from = at + Vector3.UP * 0.6
	ray.to = at + Vector3.DOWN * 2.5
	ray.collision_mask = (1 << (LAYERS.WORLD_STATIC - 1)) | (1 << (LAYERS.ELEVATOR - 1))
	ray.exclude = params.exclude
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or (hit.normal as Vector3).dot(Vector3.UP) <= 0.6:
		return Vector3.INF
	var standing_at: Vector3 = Vector3(at.x, (hit.position as Vector3).y + 0.03, at.z)
	params.transform = Transform3D(global_basis, standing_at) * collider_transform
	if not get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty():
		return Vector3.INF
	return standing_at

func begin_remote_limp(epoch: int, world_transform: Transform3D, initial_pose: PackedInt32Array) -> bool:
	if is_limp or is_recovering or epoch <= limp_epoch or rig == null:
		return false
	if not bool(rig.call("begin_remote_pose", world_transform, initial_pose)):
		return false
	limp_epoch = epoch
	is_limp = true
	_set_limp_interaction_proxy(true)
	if limp_interactable != null:
		limp_interactable.enabled = true
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

func end_remote_limp(
	epoch: int,
	standing_at: Vector3,
	final_pose: PackedInt32Array,
	recovery_variant: StringName
) -> bool:
	if not is_limp or epoch != limp_epoch or rig == null or not standing_at.is_finite():
		return false
	global_position = standing_at
	rig.call("end_remote_pose_with_blend", TUNING.GET_UP_BLEND_SECONDS, final_pose, recovery_variant)
	is_limp = false
	is_recovering = true
	_set_limp_interaction_proxy(false)
	if limp_interactable != null:
		limp_interactable.enabled = false
		debug_hub.call("log", &"carry", "%s limp Interactable disabled on remote limp end." % name)
	_begin_recovery_camera()
	velocity = Vector3.ZERO
	collision_layer = 1 << (LAYERS.HEALTHY_PLAYERS - 1)
	collision_mask = LAYERS.LAYER_MASK_HEALTHY_PLAYERS
	if focus != null:
		focus.call("set_active", false)
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

func _begin_recovery_camera() -> void:
	_recovery_elapsed_s = 0.0
	if not is_local_player:
		return
	# Do not rotate the Player root only on its owner: that moves the blend
	# start and makes host/client recovery orientations disagree.
	_pitch_radians = _limp_look_pitch
	head.rotation.x = _pitch_radians
	_recovery_camera_start = camera.global_transform
	_recovery_camera_target = Transform3D(head.global_basis, head.global_position)
	if rig != null:
		rig.visible = true
		rig.call("set_owner_head_visible", false)

func _update_recovery_camera(delta: float) -> void:
	_recovery_elapsed_s += delta
	if not is_local_player:
		return
	var weight: float = clampf(_recovery_elapsed_s / TUNING.GET_UP_BLEND_SECONDS, 0.0, 1.0)
	var eased_weight: float = weight * weight * (3.0 - 2.0 * weight)
	var rotation: Quaternion = _recovery_camera_start.basis.get_rotation_quaternion().slerp(
		_recovery_camera_target.basis.get_rotation_quaternion(),
		eased_weight
	)
	camera.global_transform = Transform3D(
		Basis(rotation),
		_recovery_camera_start.origin.lerp(_recovery_camera_target.origin, eased_weight)
	)

func _finish_recovery() -> void:
	is_recovering = false
	if is_local_player:
		camera.top_level = false
		camera.transform = Transform3D.IDENTITY
		if rig != null:
			rig.call("set_owner_head_visible", true)
			rig.visible = false
	if focus != null:
		focus.call("set_active", is_local_player)
	debug_hub.call("log", &"limp", "Player %s finished get-up blend." % name)

func _update_limp_camera(delta: float) -> void:
	if not is_local_player or rig == null:
		return
	var eye_transform: Transform3D = rig.call("get_head_eye_transform")
	if not eye_transform.is_finite():
		return
	var head_rotation: Quaternion = eye_transform.basis.get_rotation_quaternion().normalized()
	var camera_origin: Vector3 = eye_transform.origin
	if _is_carried:
		# Follow the head-mounted eye point with a little inertia, filtering
		# physics jolts without detaching the view or smoothing player mouse-look.
		if not _carry_camera_smoothing_initialized:
			_carry_camera_smoothed_origin = camera_origin
			_carry_camera_smoothed_rotation = head_rotation
			_carry_camera_smoothing_initialized = true
		var rotation_weight: float = 1.0 - exp(-CARRY_CAMERA_ROTATION_RESPONSE * delta)
		var position_weight: float = 1.0 - exp(-CARRY_CAMERA_POSITION_RESPONSE * delta)
		_carry_camera_smoothed_rotation = _carry_camera_smoothed_rotation.slerp(head_rotation, rotation_weight).normalized()
		_carry_camera_smoothed_origin = _carry_camera_smoothed_origin.lerp(camera_origin, position_weight)
		head_rotation = _carry_camera_smoothed_rotation
		camera_origin = _carry_camera_smoothed_origin
	else:
		_carry_camera_smoothing_initialized = false
	var look_yaw: Basis = Basis(Vector3.UP, _limp_look_yaw)
	var look_pitch: Basis = Basis(Vector3.RIGHT, _limp_look_pitch)
	camera.global_transform = Transform3D(Basis(head_rotation) * look_yaw * look_pitch, camera_origin)

func _rotate_view(mouse_delta: Vector2) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if is_recovering:
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
