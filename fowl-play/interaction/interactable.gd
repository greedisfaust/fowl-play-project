## Reusable interaction contract for devices, props, and limp players.
## Owns interaction kind, prompt text, focus state, and interaction signals.

class_name Interactable
extends Node

enum InteractionKind {
	USE,
	GRAB,
	BOTH,
}

@export var kind: InteractionKind = InteractionKind.USE
@export var prompt_text: String = ""
@export var enabled: bool = true

## Optional host-side state predicate supplied by the target owner.
var availability_check: Callable

signal focused_changed(focused: bool)
signal interacted(actor: Node, action: StringName)

var is_focused: bool = false
var _highlight_material: StandardMaterial3D = null
var _highlighted_geometry: Array[GeometryInstance3D] = []
var _original_overlays: Array[Material] = []

func action_for_input(input_action: StringName) -> StringName:
	if input_action == &"primary":
		if kind == InteractionKind.USE or kind == InteractionKind.BOTH:
			return &"use"
		return &""
	if input_action == &"interact":
		if kind == InteractionKind.GRAB or kind == InteractionKind.BOTH:
			return &"grab"
		if kind == InteractionKind.USE:
			return &"use"
	return &""

func can_interact(actor: Node, action: StringName) -> bool:
	if not enabled or not is_instance_valid(actor):
		return false
	var supported: bool = (action == &"use" and kind != InteractionKind.GRAB) or (action == &"grab" and kind != InteractionKind.USE)
	return supported and (not availability_check.is_valid() or bool(availability_check.call(actor, action)))

func interact(actor: Node, action: StringName) -> bool:
	if not can_interact(actor, action):
		return false
	interacted.emit(actor, action)
	return true

func set_focused(focused: bool) -> void:
	if is_focused == focused:
		return
	is_focused = focused
	if is_focused:
		_apply_highlight()
	else:
		_clear_highlight()
	focused_changed.emit(is_focused)

func _apply_highlight() -> void:
	var target: Node = get_parent()
	if target == null:
		return
	_highlighted_geometry.clear()
	_original_overlays.clear()
	for child: Node in target.find_children("*", "GeometryInstance3D", true, false):
		var geometry: GeometryInstance3D = child as GeometryInstance3D
		if geometry == null:
			continue
		_highlighted_geometry.append(geometry)
		_original_overlays.append(geometry.material_overlay)
		geometry.material_overlay = _get_highlight_material()

func _clear_highlight() -> void:
	for index: int in _highlighted_geometry.size():
		var geometry: GeometryInstance3D = _highlighted_geometry[index]
		if is_instance_valid(geometry):
			geometry.material_overlay = _original_overlays[index]
	_highlighted_geometry.clear()
	_original_overlays.clear()

func _get_highlight_material() -> StandardMaterial3D:
	if _highlight_material != null:
		return _highlight_material
	_highlight_material = StandardMaterial3D.new()
	_highlight_material.albedo_color = Color(1.0, 0.85, 0.25, 1.0)
	_highlight_material.emission_enabled = true
	_highlight_material.emission = Color(0.35, 0.2, 0.02, 1.0)
	_highlight_material.emission_energy_multiplier = 0.8
	return _highlight_material
