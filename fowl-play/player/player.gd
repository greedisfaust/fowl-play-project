## M0 player controller.
## Owns local capsule movement, mouse look, camera capture, and debug state.

extends CharacterBody3D

const TUNING = preload("res://core/tuning.gd")
const MOVEMENT_CONTROLLER_SCRIPT = preload("res://core/movement_controller.gd")
const JUMP_CONTROLLER_SCRIPT = preload("res://core/jump_controller.gd")
const COMBAT_CONTROLLER_SCRIPT = preload("res://combat/combat_controller.gd")
const COMBAT_PRESENTATION_SCRIPT = preload("res://combat/combat_presentation.gd")
const PARRY_BARRIER_SCRIPT = preload("res://combat/parry_barrier_presentation.gd")
const MOVEMENT_PRESENTATION_SCRIPT = preload("res://ragdoll/procedural_movement_presentation.gd")
var _movement_controller: RefCounted = MOVEMENT_CONTROLLER_SCRIPT.new()
var _jump_controller: RefCounted = JUMP_CONTROLLER_SCRIPT.new()
var _combat_controller: RefCounted = COMBAT_CONTROLLER_SCRIPT.new()
var _combat_presentation: RefCounted = COMBAT_PRESENTATION_SCRIPT.new()
var _parry_barrier: RefCounted = PARRY_BARRIER_SCRIPT.new()
var _movement_presentation: RefCounted = MOVEMENT_PRESENTATION_SCRIPT.new()
var _movement_presentation_last_yaw: float = 0.0
var _movement_presentation_yaw_initialized: bool = false
var _parry_active: bool = false
const LAYERS = preload("res://core/layers.gd")
const PlayerIdentity = preload("res://core/player_identity.gd")
const LIMP_LOOK_YAW_LIMIT: float = deg_to_rad(75.0)
const LIMP_LOOK_PITCH_LIMIT: float = deg_to_rad(75.0)

# M3: owner drives standing movement; host validates before relay.
var input_peer_id: int = 0
var is_local_player: bool = true
var is_limp: bool = false
var is_recovering: bool = false
var terminal_movement_locked: bool = false
var limp_epoch: int = 0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var rig: Node3D = get_node_or_null("Rig") as Node3D
@onready var world_right_hand: Hand = get_node_or_null("Rig/Skeleton3D/HandAttachment_R/HandMount_R/Hand") as Hand
@onready var world_left_hand: Hand = get_node_or_null("Rig/Skeleton3D/HandAttachment_L/HandMount_L/Hand") as Hand
@onready var viewmodel_hands: Node3D = get_node_or_null("Head/Camera3D/ViewmodelHands") as Node3D
@onready var viewmodel_left_hand: Hand = get_node_or_null("Head/Camera3D/ViewmodelHands/LeftHand") as Hand
@onready var viewmodel_right_hand: Hand = get_node_or_null("Head/Camera3D/ViewmodelHands/RightHand") as Hand
@onready var viewmodel_right_hand_pose_root: Node3D = get_node_or_null("Head/Camera3D/ViewmodelHands/RightHand/PoseRoot") as Node3D
@onready var viewmodel_left_hand_pose_root: Node3D = get_node_or_null("Head/Camera3D/ViewmodelHands/LeftHand/PoseRoot") as Node3D
@onready var carrier: Carrier = get_node_or_null("Carrier") as Carrier
@onready var limp_interactable: Interactable = get_node_or_null("Interactable") as Interactable
@onready var limp_interaction_proxy: StaticBody3D = get_node_or_null("LimpInteractionProxy") as StaticBody3D
@onready var focus: Node = get_node_or_null("Head/Camera3D/Focus")
@onready var gameplay_cursor: Control = get_node_or_null("GameplayCursor/CursorDisplay") as Control
@onready var nameplate: Node3D = get_node_or_null("NamePlate") as Node3D
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
var _combat_lunge_active: bool = false
var _combat_lunge_elapsed: float = 0.0
var _combat_lunge_direction: Vector3 = Vector3.FORWARD

var _pitch_radians: float = 0.0
var _remote_grounded: bool = true
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
var _debug_coyote_watch_name: StringName
var _debug_jump_buffer_watch_name: StringName
var _debug_limp_watch_name: StringName
var _debug_recovering_watch_name: StringName
var _debug_limp_elapsed_watch_name: StringName
var _debug_camera_follow_watch_name: StringName
var _debug_wall_clearance_watch_name: StringName
var _debug_carrying_watch_name: StringName
var _debug_limp_target_watch_name: StringName
var _debug_hands_command_name: StringName

func _ready() -> void:
	accepted_position = global_position
	_movement.reset(global_position, Time.get_ticks_msec() / 1000.0)
	network.call("register_movement_player", input_peer_id, self)
	is_local_player = input_peer_id == 0 or input_peer_id == multiplayer.get_unique_id()
	_combat_controller.call("configure", self, network)
	_combat_presentation.call("configure", self)
	_parry_barrier.call("configure", self)
	_configure_boxer_guard_hands()
	camera.current = is_local_player
	if rig != null:
		# Hide the owner's world model until the first-person body visibility pass.
		rig.visible = not is_local_player
	set_process_unhandled_input(is_local_player)
	set_physics_process(is_local_player)
	if focus != null:
		focus.call("set_active", is_local_player)
	if gameplay_cursor != null:
		gameplay_cursor.call("bind_focus_source", focus)
		gameplay_cursor.call("set_cursor_enabled", is_local_player)
	if not network.is_connected("identity_roster_changed", _on_identity_roster_changed):
		network.connect("identity_roster_changed", _on_identity_roster_changed)
	_attach_nameplate_to_ragdoll_head()
	_refresh_identity_presentation()
	if carrier != null:
		carrier.carry_started.connect(_on_carry_started)
		carrier.carry_ended.connect(_on_carry_ended)
		if carrier.is_holding():
			_on_carry_started(carrier.held_item)
	_debug_command_name = StringName("player_status_%s" % name)
	_debug_hands_command_name = StringName("player_hands_%s" % name)
	if limp_interactable != null:
		limp_interactable.enabled = false
		limp_interactable.availability_check = _can_be_carried
		limp_interactable.interacted.connect(_on_limp_interacted)
	if limp_interaction_proxy != null:
		limp_interaction_proxy.collision_layer = 0
	_debug_speed_watch_name = StringName("player/%s/speed_mps" % name)
	_debug_floor_watch_name = StringName("player/%s/on_floor" % name)
	_debug_coyote_watch_name = StringName("player/%s/jump_coyote_s" % name)
	_debug_jump_buffer_watch_name = StringName("player/%s/jump_buffer_s" % name)
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
	debug_hub.call("watch", _debug_coyote_watch_name, func() -> float: return float(_jump_controller.call("get_coyote_remaining_s")))
	debug_hub.call("watch", _debug_jump_buffer_watch_name, func() -> float: return float(_jump_controller.call("get_jump_buffer_remaining_s")))
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
	debug_hub.call("command", _debug_hands_command_name, _debug_hands_status, "Report this player FPS and world hands separately.", false, false)
	if is_local_player and not bool(debug_hub.call("is_console_open")):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	network.call("apply_pending_ragdoll_start", input_peer_id, self)

func _exit_tree() -> void:
	_combat_controller.call("abandon")
	end_parry_presentation(false)
	_combat_presentation.call("cancel")
	_parry_barrier.call("dispose")
	if (is_limp or is_recovering) and is_instance_valid(rig):
		rig.call("stop_host_simulation")
	if is_instance_valid(network):
		network.call("unregister_movement_player", input_peer_id, self)
		if network.is_connected("identity_roster_changed", _on_identity_roster_changed):
			network.disconnect("identity_roster_changed", _on_identity_roster_changed)
	if not is_instance_valid(debug_hub):
		return
	# Use the original registration names even if the node was renamed.
	debug_hub.call("unregister_command", _debug_command_name)
	debug_hub.call("unregister_command", _debug_hands_command_name)
	debug_hub.call("unwatch", _debug_speed_watch_name)
	debug_hub.call("unwatch", _debug_floor_watch_name)
	debug_hub.call("unwatch", _debug_coyote_watch_name)
	debug_hub.call("unwatch", _debug_jump_buffer_watch_name)
	debug_hub.call("unwatch", _debug_limp_watch_name)
	debug_hub.call("unwatch", _debug_recovering_watch_name)
	debug_hub.call("unwatch", _debug_limp_elapsed_watch_name)
	debug_hub.call("unwatch", _debug_camera_follow_watch_name)
	debug_hub.call("unwatch", _debug_wall_clearance_watch_name)
	debug_hub.call("unwatch", _debug_carrying_watch_name)
	if not _debug_limp_target_watch_name.is_empty():
		debug_hub.call("unwatch", _debug_limp_target_watch_name)

func _attach_nameplate_to_ragdoll_head() -> void:
	if not is_instance_valid(nameplate) or not is_instance_valid(rig):
		return
	var head_attachment: BoneAttachment3D = rig.get_node_or_null("Skeleton3D/HeadAttachment") as BoneAttachment3D
	if head_attachment == null:
		push_warning("Player NamePlate could not find Rig/Skeleton3D/HeadAttachment; it will remain attached to Player.")
		return
	# The rig becomes independent of Player during ragdoll. Parenting the plate
	# to the Head bone keeps it aligned through host simulation, remote playback,
	# and the recovery blend without changing any ragdoll physics.
	nameplate.reparent(head_attachment, false)
	nameplate.position = Vector3(0.0, 0.62, 0.0)
	nameplate.rotation = Vector3.ZERO

func _on_identity_roster_changed() -> void:
	_refresh_identity_presentation()

func _refresh_identity_presentation() -> void:
	var owner_peer_id: int = input_peer_id
	if owner_peer_id <= 0:
		owner_peer_id = multiplayer.get_unique_id()
	var identity: PlayerIdentity = network.call("get_player_identity", owner_peer_id) as PlayerIdentity
	var identity_color: Color = identity.get_color() if identity != null else Color.WHITE
	if is_instance_valid(rig) and rig.has_method("set_player_color"):
		rig.call("set_player_color", identity_color)
	_parry_barrier.call("set_color", identity_color)
	if is_instance_valid(viewmodel_left_hand):
		viewmodel_left_hand.set_color(identity_color)
	if is_instance_valid(viewmodel_right_hand):
		viewmodel_right_hand.set_color(identity_color)
	if is_instance_valid(gameplay_cursor) and is_local_player:
		if identity != null:
			gameplay_cursor.call("set_identity_color", identity.get_color())
		else:
			gameplay_cursor.call("reset_identity_color")
	if is_instance_valid(nameplate) and nameplate.has_method("apply_player_identity"):
		nameplate.call("apply_player_identity", identity, is_local_player)


func _configure_boxer_guard_hands() -> void:
	# The mirrored Viewmodel hand roots make the same inward local offset converge
	# toward the centerline on both sides. The closed-fist curl remains Hand-owned.
	for hand: Hand in [viewmodel_left_hand, viewmodel_right_hand]:
		if not is_instance_valid(hand):
			continue
		hand.guard_position_offset = Vector3(-0.16, 0.27, -0.08)
		hand.guard_rotation_degrees = Vector3(30.0, -10.0, 190.0)

func _process(delta: float) -> void:
	_parry_barrier.call("advance", delta)
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
	_combat_presentation.call("advance", delta)
	var grounded_for_legs: bool = is_on_floor() if is_local_player else _remote_grounded
	if rig != null:
		rig.call("update_procedural_legs", velocity, grounded_for_legs, delta)
	# The camera-attached Viewmodel hand is the pose source for remote-visible arms.
	# Its authored wrist pivot sits 0.32 hand-local units behind the palm.
	if rig != null and is_instance_valid(viewmodel_right_hand_pose_root):
		var wrist_target_world: Vector3 = viewmodel_right_hand_pose_root.to_global(Vector3(0.0, 0.0, 0.32))
		rig.call("update_procedural_right_arm", wrist_target_world, delta)
	if rig != null and is_instance_valid(viewmodel_left_hand_pose_root):
		var left_wrist_target_world: Vector3 = viewmodel_left_hand_pose_root.to_global(Vector3(0.0, 0.0, 0.32))
		rig.call("update_procedural_left_arm", left_wrist_target_world, delta)
	if is_local_player:
		_send_elapsed += delta
		if _send_elapsed >= 1.0 / TUNING.MOVE_SEND_HZ:
			_send_elapsed = 0.0
			_movement_sequence += 1
			network.call("send_movement", input_peer_id, _movement_sequence, global_position, velocity, rotation.y, _pitch_radians, is_on_floor())
	else:
		var snapshot: Dictionary = _movement.sample(Time.get_ticks_msec() / 1000.0)
		if not snapshot.is_empty():
			global_position = snapshot.position
			velocity = snapshot.velocity
			rotation.y = snapshot.yaw
			head.rotation.x = snapshot.pitch
			_remote_grounded = bool(snapshot.get("grounded", true))

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

func accept_movement(sequence: int, at: Vector3, speed: Vector3, yaw: float, pitch: float, grounded: bool = true) -> bool:
	if is_limp or is_recovering:
		return false
	var now: float = Time.get_ticks_msec() / 1000.0
	if not _movement.accept(sequence, at, speed, yaw, pitch, now, grounded):
		return false
	accepted_position = at
	receive_movement(sequence, at, speed, yaw, pitch, grounded)
	return true

## Returns true while this player holds a carried item (prop or limp body).
func is_carrying() -> bool:
	return carrier != null and bool(carrier.call("is_holding"))

## Carrier signals drive the camera-attached Viewmodel hands on every peer.
## Remote observers therefore see the same hand instances used for pointing/poking;
## ragdoll Rig hands remain dedicated to physical/ragdoll presentation.
func _on_carry_started(item: Node3D) -> void:
	_combat_controller.call("cancel")
	end_parry_presentation(false)
	_combat_presentation.call("cancel")
	_set_carry_hand_pose(true, item)

func _on_carry_ended() -> void:
	_set_carry_hand_pose(false)

func _set_carry_hand_pose(active: bool, item: Node3D = null) -> void:
	if is_instance_valid(viewmodel_left_hand):
		viewmodel_left_hand.set_carrying(active, item, -1.0)
	if is_instance_valid(viewmodel_right_hand):
		viewmodel_right_hand.set_carrying(active, item, 1.0)

## Applies replicated pointing to this player's camera-attached Viewmodel right hand.
## The local owner already drives that hand directly through Focus.
func set_world_hand_hover(active: bool, world_point: Vector3) -> bool:
	if is_local_player or not is_instance_valid(viewmodel_right_hand):
		return false
	if active and (is_limp or is_recovering or is_carrying() or not world_point.is_finite()):
		return false
	viewmodel_right_hand.set_hover(active, world_point)
	return true

## Plays a host-approved poke on this player's camera-attached Viewmodel right hand.
## The local owner already sees the first-person poke, so only remote copies animate.
func play_world_hand_poke(world_point: Vector3) -> bool:
	if is_local_player or is_limp or is_recovering or is_carrying() or not world_point.is_finite():
		return false
	if not is_instance_valid(viewmodel_right_hand):
		return false
	return viewmodel_right_hand.reach(world_point)

## Interaction authority reports the final result to the local first-person hand.
func finish_local_hand_action(accepted: bool) -> void:
	if not is_local_player or not is_instance_valid(viewmodel_right_hand):
		return
	viewmodel_right_hand.finish_action(accepted)

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

## Cosmetic hand grips follow the actively stabilised chest, not the hips.
## Gameplay interaction and recovery continue using get_carry_world_position().
func get_carry_hand_target_position() -> Vector3:
	return Vector3(rig.call("get_chest_world_position")) if is_limp and rig != null else global_position

func get_carry_hand_target_basis() -> Basis:
	return Basis(rig.call("get_chest_world_basis")).orthonormalized() if is_limp and rig != null else global_basis.orthonormalized()

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

func receive_movement(sequence: int, at: Vector3, speed: Vector3, yaw: float, pitch: float, grounded: bool = true) -> void:
	if is_limp or is_recovering:
		return
	if not is_local_player:
		_movement.push(sequence, at, speed, yaw, pitch, Time.get_ticks_msec() / 1000.0, grounded)

## Locks standing movement while a local terminal text field is being edited.
## Mouse look, gravity, collision, and other presentation remain active.
func set_terminal_movement_locked(locked: bool) -> void:
	terminal_movement_locked = locked
	if locked:
		velocity.x = 0.0
		velocity.z = 0.0

func correct_movement(at: Vector3) -> void:
	if is_limp or is_recovering:
		return
	_jump_controller.call("reset")
	global_position = at
	velocity = Vector3.ZERO
	debug_hub.call("log", &"net", "Movement corrected for player %s" % name)

func _unhandled_input(event: InputEvent) -> void:
	if bool(debug_hub.call("is_console_open")):
		if event.is_action_released("punch") or event.is_action_released("parry"):
			_combat_controller.call("cancel")
		return
	if event is InputEventMouseMotion:
		var mouse_event: InputEventMouseMotion = event
		_rotate_view(mouse_event.relative)
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif event.is_action_pressed("parry") or event.is_action_released("parry"):
		if is_carrying():
			return
		if _combat_controller.call("handle_input", event):
			return
	elif event.is_action_pressed("punch") or event.is_action_released("punch"):
		# While carrying, punch remains exclusively owned by Carrier (drop/throw).
		if is_carrying():
			return
		if _combat_controller.call("handle_input", event):
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
	if _combat_lunge_active:
		_advance_combat_lunge(delta)
		return
	var grounded_before_move: bool = is_on_floor()
	if not grounded_before_move:
		velocity.y -= TUNING.GRAVITY_MPS2 * delta

	var movement_locked: bool = bool(debug_hub.call("is_console_open")) or terminal_movement_locked
	var jump_pressed: bool = not movement_locked and Input.is_action_just_pressed("jump")
	var jump_released: bool = Input.is_action_just_released("jump")
	var jump_state: Dictionary = _jump_controller.call(
		"advance",
		delta,
		grounded_before_move,
		jump_pressed,
		jump_released,
		velocity.y,
		TUNING.JUMP_SPEED_MPS,
		TUNING.JUMP_COYOTE_TIME_S,
		TUNING.JUMP_BUFFER_TIME_S,
		TUNING.JUMP_RELEASE_MULTIPLIER
	)
	velocity.y = float(jump_state.get("vertical_velocity", velocity.y))

	if movement_locked:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var input_vector: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_back"
	)
	var local_direction: Vector3 = Vector3(input_vector.x, 0.0, input_vector.y)
	var move_direction: Vector3 = (transform.basis * local_direction).normalized()
	var target_speed: float = TUNING.PLAYER_SPEED_MPS
	if move_direction != Vector3.ZERO and Input.is_action_pressed("sprint"):
		target_speed = TUNING.PLAYER_RUN_SPEED_MPS
	var air_control: float = 1.0 if grounded_before_move and not bool(jump_state.get("jumped", false)) else TUNING.PLAYER_AIR_CONTROL_MULTIPLIER
	var horizontal_velocity: Vector3 = _movement_controller.call(
		"advance_horizontal_velocity",
		Vector3(velocity.x, 0.0, velocity.z),
		move_direction,
		target_speed,
		TUNING.PLAYER_ACCELERATION_MPS2 * air_control,
		TUNING.PLAYER_DECELERATION_MPS2 * air_control,
		delta,
		TUNING.PLAYER_TURN_ACCELERATION_MPS2 * air_control
	)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

	move_and_slide()

## Host-only: called when another player grabs this limp player's Interactable.
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
	_combat_controller.call("cancel")
	end_parry_presentation(false)
	_combat_presentation.call("cancel")
	_movement_presentation.call("reset", is_on_floor(), global_basis.inverse() * velocity)
	if not bool(rig.call("begin_host_simulation")):
		collision_layer = 1 << (LAYERS.HEALTHY_PLAYERS - 1)
		collision_mask = LAYERS.LAYER_MASK_HEALTHY_PLAYERS
		return false
	is_limp = true
	_set_viewmodel_hands_visible(false)
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
	_jump_controller.call("reset")
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
	_combat_controller.call("cancel")
	end_parry_presentation(false)
	_combat_presentation.call("cancel")
	if not bool(rig.call("begin_remote_pose", world_transform, initial_pose)):
		return false
	limp_epoch = epoch
	is_limp = true
	_set_viewmodel_hands_visible(false)
	_set_limp_interaction_proxy(true)
	if limp_interactable != null:
		limp_interactable.enabled = true
	velocity = Vector3.ZERO
	_movement_presentation.call("reset", true, Vector3.ZERO)
	_movement_presentation_yaw_initialized = false
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

func _set_viewmodel_hands_visible(visible: bool) -> void:
	if is_instance_valid(viewmodel_hands):
		viewmodel_hands.visible = visible

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
	_set_viewmodel_hands_visible(true)
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

## Host-approved parry presentation, shared by first-person and remote copies.
func begin_parry_presentation() -> void:
	if is_limp or is_recovering or is_carrying():
		return
	_parry_active = true
	_combat_presentation.call("begin_parry")
	if is_instance_valid(viewmodel_left_hand):
		viewmodel_left_hand.set_guard(true)
	if is_instance_valid(viewmodel_right_hand):
		viewmodel_right_hand.set_guard(true)
	_parry_barrier.call("begin")

func play_parry_hit(world_position: Vector3) -> void:
	if _parry_active and world_position.is_finite():
		_parry_barrier.call("play_impact", world_position)

func end_parry_presentation(_successful: bool = false) -> void:
	if not _parry_active:
		return
	_parry_active = false
	if is_instance_valid(viewmodel_left_hand):
		viewmodel_left_hand.set_guard(false)
	if is_instance_valid(viewmodel_right_hand):
		viewmodel_right_hand.set_guard(false)
	_combat_presentation.call("end_parry")
	_parry_barrier.call("end")

## Host-approved combat presentation, shared by first-person and remote copies.
func play_combat_windup() -> void:
	if is_limp or is_recovering or is_carrying():
		return
	_combat_presentation.call("begin_windup")

func play_combat_jab(direction: Vector3) -> void:
	if is_limp or is_recovering or is_carrying() or not direction.is_finite():
		_combat_presentation.call("cancel")
		return
	_combat_presentation.call("play_jab", direction)

## Host-approved charged punch. Only the owning player drives the lunge movement.
func begin_combat_lunge(direction: Vector3) -> void:
	if is_limp or is_recovering or is_carrying() or not direction.is_finite() or direction.length_squared() < 0.0001:
		return
	_combat_lunge_active = true
	_combat_lunge_elapsed = 0.0
	_combat_lunge_direction = direction.normalized()
	_combat_presentation.call("play_charged_lunge", _combat_lunge_direction)

func stop_combat_lunge() -> void:
	if not _combat_lunge_active:
		return
	_combat_lunge_active = false
	_combat_lunge_elapsed = 0.0
	if is_local_player:
		velocity = Vector3.ZERO
	_combat_presentation.call("end_charged_lunge")

func _advance_combat_lunge(delta: float) -> void:
	_combat_lunge_elapsed += maxf(delta, 0.0)
	var desired_direction: Vector3 = -camera.global_basis.z
	_combat_lunge_direction = COMBAT_CONTROLLER_SCRIPT.steer_lunge_direction(
		_combat_lunge_direction,
		desired_direction,
		delta
	)
	velocity = _combat_lunge_direction * TUNING.LUNGE_SPEED_MPS
	move_and_slide()
	if _combat_lunge_elapsed >= TUNING.LUNGE_DURATION_S:
		stop_combat_lunge()

func cancel_combat_presentation() -> void:
	_combat_presentation.call("cancel")

## Weak standing reactions are visual torso impulses, not player knockback or knockdowns.
func apply_combat_recoil(direction: Vector3, strength: float = 1.0) -> void:
	if is_limp or is_recovering or not direction.is_finite():
		return
	var horizontal: Vector3 = Vector3(direction.x, 0.0, direction.z)
	if horizontal.length_squared() < 0.0001:
		return
	var bounded_strength: float = clampf(strength, 1.0, 1.35)
	_combat_presentation.call("play_recoil", direction, bounded_strength)

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

func _debug_hands_status(_args: Array[Variant]) -> String:
	return "player=%s local=%s\nFPS left: %s\nFPS right: %s\nWORLD left: %s\nWORLD right: %s" % [
		name,
		is_local_player,
		_hand_debug_line(viewmodel_left_hand),
		_hand_debug_line(viewmodel_right_hand),
		_hand_debug_line(world_left_hand),
		_hand_debug_line(world_right_hand),
	]

func _hand_debug_line(hand: Hand) -> String:
	if not is_instance_valid(hand):
		return "missing"
	return "name=%s id=%d world_mode=%s %s" % [
		hand.name,
		hand.get_instance_id(),
		hand.world_mode,
		hand.call("_debug_state"),
	]

func _debug_status(_args: Array[Variant]) -> String:
	return "position=%s velocity=%s on_floor=%s" % [
		global_position,
		velocity,
		is_on_floor(),
	]
