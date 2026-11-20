## Responsive jump timing and variable jump height.
extends RefCounted

var _coyote_remaining_s: float = 0.0
var _jump_buffer_remaining_s: float = 0.0
var _jump_held: bool = false

func advance(
	delta: float,
	grounded: bool,
	jump_pressed: bool,
	jump_released: bool,
	vertical_velocity: float,
	jump_speed: float,
	coyote_time: float,
	buffer_time: float,
	release_multiplier: float
) -> Dictionary:
	var safe_delta: float = maxf(delta, 0.0)
	if grounded:
		_coyote_remaining_s = maxf(coyote_time, 0.0)
	else:
		_coyote_remaining_s = maxf(0.0, _coyote_remaining_s - safe_delta)
	if jump_pressed:
		_jump_buffer_remaining_s = maxf(buffer_time, 0.0)
	else:
		_jump_buffer_remaining_s = maxf(0.0, _jump_buffer_remaining_s - safe_delta)

	var next_vertical_velocity: float = vertical_velocity
	var jumped: bool = false
	var jump_cut: bool = false
	if _jump_buffer_remaining_s > 0.0 and (grounded or _coyote_remaining_s > 0.0):
		next_vertical_velocity = maxf(jump_speed, 0.0)
		_jump_buffer_remaining_s = 0.0
		_coyote_remaining_s = 0.0
		_jump_held = true
		jumped = true
	elif jump_released:
		if _jump_held and next_vertical_velocity > 0.0:
			next_vertical_velocity *= clampf(release_multiplier, 0.0, 1.0)
			jump_cut = true
		_jump_held = false
	elif grounded and next_vertical_velocity <= 0.0:
		_jump_held = false

	return {
		"vertical_velocity": next_vertical_velocity,
		"jumped": jumped,
		"jump_cut": jump_cut,
	}

func get_coyote_remaining_s() -> float:
	return _coyote_remaining_s

func get_jump_buffer_remaining_s() -> float:
	return _jump_buffer_remaining_s

func reset() -> void:
	_coyote_remaining_s = 0.0
	_jump_buffer_remaining_s = 0.0
	_jump_held = false
