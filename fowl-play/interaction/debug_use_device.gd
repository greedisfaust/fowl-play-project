## Minimal M1 USE device for the test arena.
## Owns a toggled active state so the interaction path has an observable result.

extends Node3D

@onready var interactable: Interactable = $Interactable
@onready var debug_hub: Node = get_node("/root/DebugHub")

var is_active: bool = false
var _debug_watch_name: StringName

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	_debug_watch_name = StringName("interact/device/%s/active" % name)
	debug_hub.call("watch", _debug_watch_name, func() -> bool: return is_active)

func _exit_tree() -> void:
	if is_instance_valid(debug_hub):
		debug_hub.call("unwatch", _debug_watch_name)

func _on_interacted(_actor: Node, action: StringName) -> void:
	if action != &"use":
		return
	is_active = not is_active
	if debug_hub.call("is_on", &"interact"):
		debug_hub.call("log", &"interact", "%s active=%s" % [name, is_active])
