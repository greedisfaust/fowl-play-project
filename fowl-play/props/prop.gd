## Base runtime behavior for an editor-authored simulated prop.
## Owns profile validation and the M1 grab interaction signal.

class_name Prop
extends RigidBody3D

const LAYERS = preload("res://core/layers.gd")

@export var profile: PropProfile = null

@onready var interactable: Interactable = $Interactable
@onready var debug_hub: Node = get_node("/root/DebugHub")

var _debug_profile_watch_name: StringName

func _ready() -> void:
	collision_layer = 1 << (LAYERS.PROPS - 1)
	collision_mask = LAYERS.LAYER_MASK_PROPS
	if profile == null:
		debug_hub.call("warn", &"props", "%s has no PropProfile" % name)
	else:
		_debug_profile_watch_name = StringName("props/%s/pickup_allowed" % name)
		debug_hub.call(
			"watch",
			_debug_profile_watch_name,
			func() -> bool: return profile.pickup_allowed
		)
	interactable.interacted.connect(_on_interacted)

func _exit_tree() -> void:
	if is_instance_valid(debug_hub) and not _debug_profile_watch_name.is_empty():
		debug_hub.call("unwatch", _debug_profile_watch_name)

func _on_interacted(_actor: Node, action: StringName) -> void:
	if action != &"grab":
		return
	if profile == null or not profile.pickup_allowed:
		debug_hub.call("warn", &"props", "%s rejected grab: pickup is disabled" % name)
		return
	debug_hub.call("log", &"props", "%s grab accepted; carry is deferred to M6" % name)
