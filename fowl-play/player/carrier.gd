## Carrier component for the player.
## Manages the held item, wall-obstruction adjustment, and the drop/throw input
## (tap = drop, hold = charge then auto-throw). Every peer runs this node so the
## held item follows each player's anchor locally; only the HOST decides when an
## item is picked up, dropped or thrown (see Network.request_carry_action).

class_name Carrier
extends Node3D

const TUNING = preload("res://core/tuning.gd")

## Input action used for drop (tap) / throw (hold). Rebind here, e.g. &"carry_release".
const RELEASE_ACTION: StringName = &"punch"
const MIN_HOLD_DISTANCE_M: float = 0.4
const WALL_PULL_IN_M: float = 0.3

signal carry_started(item: Node3D)
signal carry_ended

@export var player_path: NodePath = NodePath("..")
@export var anchor_path: NodePath = NodePath("../Head/Camera3D/CarryAnchor")
@export var wall_ray_path: NodePath = NodePath("../Head/Camera3D/CarryWallRay")
@export var camera_path: NodePath = NodePath("../Head/Camera3D")

var held_item: Node3D = null
var is_charging_throw: bool = false
var throw_charge_time: float = 0.0

@onready var player: CharacterBody3D = get_node(player_path) as CharacterBody3D
@onready var anchor: Marker3D = get_node_or_null(anchor_path) as Marker3D
@onready var wall_ray: RayCast3D = get_node_or_null(wall_ray_path) as RayCast3D
@onready var camera: Camera3D = get_node_or_null(camera_path) as Camera3D
@onready var debug_hub: Node = get_node("/root/DebugHub")
@onready var network: Node = get_node("/root/Network")

var _release_held: bool = false
var _release_press_time: float = 0.0
var _is_local_player: bool = false
var _debug_holding_watch: StringName
var _debug_charge_watch: StringName
var _debug_drop_command: StringName
var _debug_throw_command: StringName

func _ready() -> void:
	var player_name: String = player.name if player != null else str(get_parent().name)
	_debug_holding_watch = StringName("carry/%s/holding" % player_name)
	_debug_charge_watch = StringName("carry/%s/throw_charge_s" % player_name)
	_debug_drop_command = StringName("carry_drop_%s" % player_name)
	_debug_throw_command = StringName("carry_throw_%s" % player_name)

	if anchor == null:
		debug_hub.call("warn", &"carry", "%s has no CarryAnchor; carrying is disabled" % player_name)
	if wall_ray != null and player != null:
		wall_ray.add_exception(player)

	debug_hub.call("watch", _debug_holding_watch, func() -> String:
		return held_item.name if is_holding() else ""
	)
	debug_hub.call("watch", _debug_charge_watch, func() -> float:
		return throw_charge_time
	)
	debug_hub.call("command", _debug_drop_command, _command_drop, "Request a drop of the carried item.", false, false)
	debug_hub.call("command", _debug_throw_command, _command_throw, "Request a throw of the carried item.", false, false)

	if player != null:
		_is_local_player = bool(player.get("is_local_player"))
		set_process_unhandled_input(_is_local_player)

func _exit_tree() -> void:
	# Never leave a prop frozen if the carrier disappears (disconnect, level unload).
	if is_holding():
		detach_item()
	if is_instance_valid(debug_hub):
		debug_hub.call("unwatch", _debug_holding_watch)
		debug_hub.call("unwatch", _debug_charge_watch)
		debug_hub.call("unregister_command", _debug_drop_command)
		debug_hub.call("unregister_command", _debug_throw_command)

func is_holding() -> bool:
	return is_instance_valid(held_item)

## 0..1 progress of the hold-to-throw charge, handy for a HUD ring.
func get_charge_ratio() -> float:
	var window: float = maxf(TUNING.THROW_AUTO_FIRE_SECONDS - TUNING.TAP_MAX_SECONDS, 0.001)
	return clampf(throw_charge_time / window, 0.0, 1.0)

func _unhandled_input(event: InputEvent) -> void:
	if not bool(player.get("is_local_player")) or bool(debug_hub.call("is_console_open")):
		return
	if not is_holding():
		return

	if event.is_action_pressed(RELEASE_ACTION):
		_release_held = true
		_release_press_time = 0.0
		_reset_charge()
		get_viewport().set_input_as_handled()
	elif event.is_action_released(RELEASE_ACTION) and _release_held:
		# Any release before the auto-fire point is a drop (tap or early release).
		_release_held = false
		_reset_charge()
		get_viewport().set_input_as_handled()
		request_drop()

func _process(delta: float) -> void:
	# The held node can be freed out from under us (despawn); recover cleanly.
	if held_item != null and not is_instance_valid(held_item):
		held_item = null
		_reset_charge()
		_release_held = false
		carry_ended.emit()
	if not is_holding():
		return

	if _release_held and bool(player.get("is_local_player")):
		_release_press_time += delta
		if _release_press_time > TUNING.TAP_MAX_SECONDS:
			is_charging_throw = true
			throw_charge_time = _release_press_time - TUNING.TAP_MAX_SECONDS
			if _release_press_time >= TUNING.THROW_AUTO_FIRE_SECONDS:
				_release_held = false
				_reset_charge()
				request_throw()
				return # held_item is now null; do not position it this frame
	_update_held_item_position()

func _reset_charge() -> void:
	is_charging_throw = false
	throw_charge_time = 0.0

func _update_held_item_position() -> void:
	if anchor == null or camera == null:
		return
	# Work in camera space so a wall pull-in keeps the anchor's side/down offset.
	var local_anchor: Vector3 = camera.global_transform.affine_inverse() * anchor.global_position
	var depth: float = -local_anchor.z
	if wall_ray != null and depth > 0.001:
		wall_ray.force_raycast_update()
		if wall_ray.is_colliding():
			var wall_dist: float = camera.global_position.distance_to(wall_ray.get_collision_point())
			var safe_depth: float = maxf(MIN_HOLD_DISTANCE_M, wall_dist - WALL_PULL_IN_M)
			if safe_depth < depth:
				local_anchor *= safe_depth / depth
	var target_world: Vector3 = camera.global_transform * local_anchor
	if held_item.has_method("set_carry_target"):
		held_item.call("set_carry_target", target_world)
		return
	held_item.global_position = target_world
	# global_rotation (not global_basis) so the prop's own scale is preserved.
	held_item.global_rotation = camera.global_rotation

## Called on EVERY peer when the host announces a pickup.
func attach_item(item: Node3D) -> void:
	if not is_instance_valid(item):
		return
	if is_holding():
		detach_item()
	held_item = item
	_reset_charge()
	_release_held = false
	if item.has_method("set_carried"):
		item.call("set_carried", true, self)
	carry_started.emit(item)
	debug_hub.call("log", &"carry", "Player %s picked up %s" % [player.name, item.name])

## Called on EVERY peer when the host announces a drop/throw (or a forced drop).
func detach_item() -> Node3D:
	if not is_holding():
		return null
	var item: Node3D = held_item
	held_item = null
	_reset_charge()
	_release_held = false
	if item.has_method("set_carried"):
		item.call("set_carried", false, self)
	carry_ended.emit()
	debug_hub.call("log", &"carry", "Player %s released %s" % [player.name, item.name])
	return item

# --- Intent only: the host validates and performs the actual release. ---

func request_drop() -> void:
	if is_holding():
		network.call("request_carry_action", &"drop", Vector3.ZERO)

func request_throw() -> void:
	if not is_holding() or camera == null:
		return
	network.call("request_carry_action", &"throw", (-camera.global_basis.z).normalized())

func _command_drop(_args: Array[Variant]) -> String:
	if not is_holding():
		return "Nothing is being held."
	request_drop()
	return "Drop requested."

func _command_throw(_args: Array[Variant]) -> String:
	if not is_holding():
		return "Nothing is being held."
	request_throw()
	return "Throw requested."
