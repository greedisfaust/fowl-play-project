## Base runtime behavior for an editor-authored simulated prop.
## Owns profile validation, the M1 grab interaction, and carry attach/detach hooks.

class_name Prop
extends RigidBody3D

const LAYERS = preload("res://core/layers.gd")
## After release, ignore collisions with the previous holder so a drop/throw
## does not instantly clip or shove the player.
const RELEASE_GRACE_SECONDS: float = 0.3

signal carried_changed(is_carried: bool)

@export var profile: PropProfile = null

@onready var interactable: Interactable = $Interactable
@onready var debug_hub: Node = get_node("/root/DebugHub")

## The Carrier node currently holding this prop (null when free).
var carrier: Node3D = null

var _debug_profile_watch_name: StringName
var _debug_carried_watch_name: StringName
var _saved_layer: int = 0
var _saved_mask: int = 0

func _ready() -> void:
	interactable.availability_check = _can_interact
	collision_layer = 1 << (LAYERS.PROPS - 1)
	collision_mask = LAYERS.LAYER_MASK_PROPS
	_saved_layer = collision_layer
	_saved_mask = collision_mask
	if profile == null:
		debug_hub.call("warn", &"props", "%s has no PropProfile" % name)
	else:
		_debug_profile_watch_name = StringName("props/%s/pickup_allowed" % name)
		debug_hub.call(
			"watch",
			_debug_profile_watch_name,
			func() -> bool: return profile.pickup_allowed
		)
	_debug_carried_watch_name = StringName("props/%s/carried_by" % name)
	debug_hub.call(
		"watch",
		_debug_carried_watch_name,
		func() -> String: return str(carrier.get_parent().name) if is_instance_valid(carrier) and carrier.get_parent() != null else ""
	)
	interactable.interacted.connect(_on_interacted)

func _exit_tree() -> void:
	if not is_instance_valid(debug_hub):
		return
	if not _debug_profile_watch_name.is_empty():
		debug_hub.call("unwatch", _debug_profile_watch_name)
	if not _debug_carried_watch_name.is_empty():
		debug_hub.call("unwatch", _debug_carried_watch_name)

func is_carried() -> bool:
	return is_instance_valid(carrier)

func _can_interact(_actor: Node, action: StringName) -> bool:
	return action == &"grab" and profile != null and profile.pickup_allowed and not is_carried()

## Runs on the host only (Network._receive_interaction is host-authoritative).
func _on_interacted(actor: Node, action: StringName) -> void:
	if action != &"grab":
		return
	if profile == null or not profile.pickup_allowed:
		debug_hub.call("warn", &"props", "%s rejected grab: pickup is disabled" % name)
		return
	if is_carried():
		debug_hub.call("warn", &"props", "%s rejected grab: already carried" % name)
		return
	var network: Node = get_node("/root/Network")
	if bool(network.call("host_begin_carry", actor, self)):
		debug_hub.call("log", &"props", "%s grab accepted; carried by %s" % [name, actor.name])
	else:
		debug_hub.call("warn", &"props", "%s grab rejected by carry rules" % name)

## Called by Carrier.attach_item / detach_item on every peer.
func set_carried(carried: bool, by: Node3D = null) -> void:
	if carried:
		if carrier == by and is_carried():
			return
		if not is_carried():
			_saved_layer = collision_layer
			_saved_mask = collision_mask
		carrier = by
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		# Kinematic freeze: the Carrier moves us each frame; physics must not fight it.
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		freeze = true
		collision_layer = 0
		collision_mask = 0
		carried_changed.emit(true)
		debug_hub.call("log", &"props", "%s set carried=true by %s" % [name, by.name if by != null else "unknown"])
		return

	if not is_carried():
		return
	var holder: Node3D = carrier
	carrier = null
	collision_layer = _saved_layer
	collision_mask = _saved_mask
	freeze = false
	sleeping = false
	_ignore_holder_briefly(holder)
	carried_changed.emit(false)
	debug_hub.call("log", &"props", "%s set carried=false (released by %s)" % [name, holder.name if holder != null else "unknown"])

## Final placement + velocities from the host. Safe to call even if the carrier
## link was already cleared (e.g. the holder despawned before the message).
func apply_release(at: Vector3, linear: Vector3, angular: Vector3) -> void:
	if is_carried():
		set_carried(false, null)
	global_position = at
	linear_velocity = linear
	angular_velocity = angular
	debug_hub.call("log", &"props", "%s apply_release at=%s linear=%s" % [name, str(at), str(linear)])

func _ignore_holder_briefly(holder: Node3D) -> void:
	if not is_instance_valid(holder):
		return
	var body: PhysicsBody3D = holder.get_parent() as PhysicsBody3D
	if body == null:
		return
	add_collision_exception_with(body)
	get_tree().create_timer(RELEASE_GRACE_SECONDS).timeout.connect(_clear_holder_exception.bind(body))

func _clear_holder_exception(body: PhysicsBody3D) -> void:
	if is_instance_valid(body):
		remove_collision_exception_with(body)
