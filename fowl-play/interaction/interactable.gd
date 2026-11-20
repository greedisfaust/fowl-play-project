## Reusable interaction contract for devices, props, and limp players.
## Owns interaction kind, prompt text, focus state, and automatic visual highlighting.

class_name Interactable
extends Node

enum InteractionKind {
	USE,
	GRAB,
	BOTH,
}

const OUTLINE_SHADER: Shader = preload("res://interaction/interactable_outline.gdshader")
const IDLE_OUTLINE_COLOR: Color = Color(0.015, 0.015, 0.02, 1.0)
const FOCUSED_OUTLINE_COLOR: Color = Color(1.0, 0.72, 0.18, 1.0)
const IDLE_OUTLINE_WIDTH: float = 0.008
const FOCUSED_OUTLINE_WIDTH: float = 0.018
const FOCUSED_GLOW_STRENGTH: float = 1.8
const GLOW_PULSE_PERIOD_SECONDS: float = 2.0
const GLOW_PULSE_AMOUNT: float = 0.20
const TRANSITION_SECONDS: float = 0.18

@export var kind: InteractionKind = InteractionKind.USE
@export var prompt_text: String = ""
@export var enabled: bool = true

## Optional host-side state predicate supplied by the target owner.
var availability_check: Callable

signal focused_changed(focused: bool)
## Local presentation/input hook; this does not grant interaction authority.
signal interaction_requested(actor: Node, action: StringName)
signal interacted(actor: Node, action: StringName)

var is_focused: bool = false
var _highlighted_geometry: Array[GeometryInstance3D] = []
var _original_overlays: Array[Material] = []
var _outline_materials: Array[ShaderMaterial] = []
var _highlight_amount: float = 0.0
var _highlight_tween: Tween = null
var _glow_pulse_elapsed: float = 0.0
var _debug_hub: Node = null
var _debug_watch_name: StringName = &""

func _ready() -> void:
	_debug_hub = get_node_or_null("/root/DebugHub")
	_setup_highlight()
	set_process(false)
	if is_instance_valid(_debug_hub):
		_debug_watch_name = StringName("interact/highlight/%s/state" % str(get_path()))
		_debug_hub.call(
			"watch",
			_debug_watch_name,
			func() -> String: return "focused" if is_focused else "idle"
		)

func _exit_tree() -> void:
	if _highlight_tween != null and _highlight_tween.is_running():
		_highlight_tween.kill()
	_restore_overlays()
	if is_instance_valid(_debug_hub) and not _debug_watch_name.is_empty():
		_debug_hub.call("unwatch", _debug_watch_name)

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
	if focused:
		_glow_pulse_elapsed = 0.0
		set_process(true)
	else:
		set_process(false)
	if _highlight_tween != null and _highlight_tween.is_running():
		_highlight_tween.kill()
	_highlight_tween = create_tween()
	_highlight_tween.set_trans(Tween.TRANS_CUBIC)
	_highlight_tween.set_ease(Tween.EASE_OUT)
	_highlight_tween.tween_method(
		_set_highlight_amount,
		_highlight_amount,
		1.0 if is_focused else 0.0,
		TRANSITION_SECONDS
	)
	if is_instance_valid(_debug_hub) and _debug_hub.call("is_on", &"interact"):
		_debug_hub.call("log", &"interact", "%s highlight %s" % [name, "focused" if is_focused else "idle"])
	focused_changed.emit(is_focused)

func _process(delta: float) -> void:
	if not is_focused:
		return
	_glow_pulse_elapsed += delta
	_set_highlight_amount(_highlight_amount)

func _setup_highlight() -> void:
	var target: Node = get_parent()
	if target == null:
		return
	for child: Node in target.find_children("*", "GeometryInstance3D", true, false):
		var geometry: GeometryInstance3D = child as GeometryInstance3D
		if geometry == null:
			continue
		var outline: ShaderMaterial = ShaderMaterial.new()
		outline.shader = OUTLINE_SHADER
		outline.set_shader_parameter("outline_color", IDLE_OUTLINE_COLOR)
		outline.set_shader_parameter("outline_width", IDLE_OUTLINE_WIDTH)
		outline.set_shader_parameter("glow_strength", 0.0)
		_highlighted_geometry.append(geometry)
		_original_overlays.append(geometry.material_overlay)
		_outline_materials.append(outline)
		geometry.material_overlay = outline

func _set_highlight_amount(amount: float) -> void:
	_highlight_amount = clampf(amount, 0.0, 1.0)
	var outline_color: Color = IDLE_OUTLINE_COLOR.lerp(FOCUSED_OUTLINE_COLOR, _highlight_amount)
	var outline_width: float = lerpf(IDLE_OUTLINE_WIDTH, FOCUSED_OUTLINE_WIDTH, _highlight_amount)
	var pulse: float = 1.0
	if is_focused:
		pulse += sin(_glow_pulse_elapsed * TAU / GLOW_PULSE_PERIOD_SECONDS) * GLOW_PULSE_AMOUNT
	var glow_strength: float = FOCUSED_GLOW_STRENGTH * _highlight_amount * pulse
	for material: ShaderMaterial in _outline_materials:
		if not is_instance_valid(material):
			continue
		material.set_shader_parameter("outline_color", outline_color)
		material.set_shader_parameter("outline_width", outline_width)
		material.set_shader_parameter("glow_strength", glow_strength)

func _restore_overlays() -> void:
	for index: int in _highlighted_geometry.size():
		var geometry: GeometryInstance3D = _highlighted_geometry[index]
		if is_instance_valid(geometry):
			geometry.material_overlay = _original_overlays[index]
	_highlighted_geometry.clear()
	_original_overlays.clear()
	_outline_materials.clear()
