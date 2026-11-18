## Minimal center-screen gameplay cursor.
## Focus is supplied by the existing Player/Focus ray; this UI never raycasts.

extends Control

const IDLE_RADIUS: float = 4.0
const HOVER_HORIZONTAL_SCALE: float = 1.85
const HOVER_RESPONSE: float = 14.0
const PULSE_PERIOD_SECONDS: float = 1.8
const PULSE_AMOUNT: float = 0.025
const OUTLINE_COLOR: Color = Color(0.015, 0.015, 0.02, 1.0)

## Temporary identity-color default until the player identity system supplies a color.
@export var identity_color: Color = Color(0.30, 0.70, 1.0, 1.0)

var is_hovering: bool = false
var _cursor_enabled: bool = false
var _hover_amount: float = 0.0
var _pulse_elapsed: float = 0.0

func _ready() -> void:
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
	var horizontal_scale: float = lerpf(1.0, HOVER_HORIZONTAL_SCALE, _hover_amount) * pulse
	draw_set_transform(center, 0.0, Vector2(horizontal_scale, pulse))
	var fill_color: Color = Color.WHITE.lerp(identity_color, _hover_amount)
	draw_circle(Vector2.ZERO, IDLE_RADIUS, fill_color)
	draw_arc(Vector2.ZERO, IDLE_RADIUS, 0.0, TAU, 48, OUTLINE_COLOR, 1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
