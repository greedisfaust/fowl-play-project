## Center-screen gameplay cursor. Focus is supplied by Player/Focus; this UI never raycasts.
extends Control

const IDLE_RADIUS: float = 5.0
const HOVER_RADIUS: float = 9.0
const HOVER_RESPONSE: float = 9.0
const PULSE_PERIOD_SECONDS: float = 1.8
const PULSE_AMOUNT: float = 0.025
const GLOW_RING_COUNT: int = 3
const OUTLINE_COLOR: Color = Color(0.015, 0.015, 0.02, 1.0)

## Temporary fallback until the lobby identity system supplies this player's color.
## Future identity integration should call set_identity_color() with the assigned color.
@export var identity_color: Color = Color(0.30, 0.70, 1.0, 1.0)

var is_hovering: bool = false
var _cursor_enabled: bool = false
var _default_identity_color: Color = Color(0.30, 0.70, 1.0, 1.0)
var _hover_amount: float = 0.0
var _pulse_elapsed: float = 0.0

func _ready() -> void:
	_default_identity_color = identity_color
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func bind_focus_source(source: Node) -> void:
	if source == null or not source.has_signal("focus_target_changed"):
		push_warning("GameplayCursor requires a Focus node with focus_target_changed.")
		return
	var callback: Callable = Callable(self, "_on_focus_target_changed")
	if not source.is_connected("focus_target_changed", callback):
		source.connect("focus_target_changed", callback)

func set_cursor_enabled(enabled: bool) -> void:
	_cursor_enabled = enabled
	visible = enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func set_identity_color(color: Color) -> void:
	identity_color = color
	queue_redraw()

func reset_identity_color() -> void:
	identity_color = _default_identity_color
	queue_redraw()

func _on_focus_target_changed(target: Interactable) -> void:
	is_hovering = is_instance_valid(target)
	if not is_hovering:
		_pulse_elapsed = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	var should_show: bool = _cursor_enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if visible != should_show:
		visible = should_show
	var previous_amount: float = _hover_amount
	_hover_amount = move_toward(_hover_amount, 1.0 if is_hovering else 0.0, HOVER_RESPONSE * delta)
	if is_hovering:
		_pulse_elapsed += delta
	if not is_equal_approx(previous_amount, _hover_amount) or is_hovering:
		queue_redraw()

func _draw() -> void:
	var center: Vector2 = get_viewport_rect().size * 0.5
	var pulse: float = 1.0
	if is_hovering:
		pulse += sin(_pulse_elapsed * TAU / PULSE_PERIOD_SECONDS) * PULSE_AMOUNT

	var radius: float = lerpf(IDLE_RADIUS, HOVER_RADIUS, _hover_amount)
	var color: Color = Color.WHITE.lerp(identity_color, _hover_amount)
	draw_set_transform(center, 0.0, Vector2(pulse, pulse))

	# Layered translucent rings recreate the soft hover aura from the earlier cursor.
	for ring_index: int in range(GLOW_RING_COUNT):
		if _hover_amount > 0.01:
			var ring_radius: float = radius + 3.0 + float(ring_index) * 3.0
			var ring_alpha: float = 0.10 * _hover_amount * (1.0 - float(ring_index) * 0.18)
			draw_circle(Vector2.ZERO, ring_radius, Color(color, ring_alpha))

	draw_circle(Vector2.ZERO, radius, Color(color, lerpf(0.22, 0.28, _hover_amount)))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, OUTLINE_COLOR, 1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
