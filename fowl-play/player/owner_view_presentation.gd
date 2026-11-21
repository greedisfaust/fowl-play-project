## Pure first-person owner body visibility response.
extends RefCounted

const LEG_FADE_START: float = deg_to_rad(18.0)
const LEG_FADE_END: float = deg_to_rad(55.0)

## Camera pitch is negative when looking down in Godot's first-person setup.
static func leg_visibility_weight(camera_pitch: float) -> float:
	var look_down_angle: float = maxf(0.0, -camera_pitch)
	var weight: float = clampf(inverse_lerp(LEG_FADE_START, LEG_FADE_END, look_down_angle), 0.0, 1.0)
	return weight * weight * (3.0 - 2.0 * weight)
