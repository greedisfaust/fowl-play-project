## Procedural, replicated-by-state cylindrical parry barrier.
## The host decides parry success; this component is presentation only.
extends RefCounted

const HEIGHT: float = 2.12
const RADIUS: float = 0.82
const ACTIVATION_SECONDS: float = 0.18
const FADE_SECONDS: float = 0.24
const RING_ALPHA: float = 0.38
const RING_EMISSION_ENERGY: float = 0.85
const COLOR_WHITE_BLEND: float = 0.22

const SHIELD_SHADER_CODE: String = """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

uniform vec4 shield_color : source_color = vec4(0.18, 0.78, 1.0, 1.0);
uniform float opacity = 0.0;
uniform vec2 impact_uv = vec2(0.0, 0.5);
uniform float impact_age = -1.0;

void fragment() {
	float scan = 0.5 + 0.5 * sin(UV.y * 27.0 - TIME * 2.4);
	float ribs = pow(max(0.0, sin(UV.x * 6.28318 * 18.0 + TIME * 0.75)), 16.0);
	float weave = 0.5 + 0.5 * sin((UV.x * 12.0 + UV.y * 4.0) * 6.28318 - TIME * 1.4);
	float vertical_streams = pow(max(0.0, sin(UV.x * 6.28318 * 6.0 - UV.y * 6.0 - TIME * 1.1)), 9.0);
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 3.2);
	float angle_delta = abs(UV.x - impact_uv.x);
	angle_delta = min(angle_delta, 1.0 - angle_delta);
	vec2 ripple_offset = vec2(angle_delta * 6.28318, (UV.y - impact_uv.y) * 2.12);
	float ripple_distance = length(ripple_offset);
	float ripple = 0.0;
	if (impact_age >= 0.0) {
		float ring_distance = abs(ripple_distance - impact_age * 3.2);
		ripple = exp(-ring_distance * 26.0) * exp(-impact_age * 2.4);
	}
	float pattern = scan * 0.12 + ribs * 0.22 + weave * 0.08 + vertical_streams * 0.14;
	ALBEDO = shield_color.rgb * (0.22 + pattern + rim * 0.30 + ripple * 0.9);
	EMISSION = shield_color.rgb * (0.08 + pattern * 0.38 + rim * 0.72 + ripple * 1.65);
	ALPHA = opacity * (0.035 + scan * 0.028 + ribs * 0.038 + weave * 0.018 + vertical_streams * 0.025 + rim * 0.045 + ripple * 0.42);
}
"""

var _player: Node3D
var _root: Node3D
var _shell: MeshInstance3D
var _top_ring: MeshInstance3D
var _bottom_ring: MeshInstance3D
var _shell_material: ShaderMaterial
var _ring_material: StandardMaterial3D
var _active: bool = false
var _activation_elapsed: float = 0.0
var _fade_elapsed: float = -1.0
var _impact_age: float = -1.0
var _opacity: float = 0.0
var _player_color: Color = Color("#42a5f5")

func configure(player: Node3D) -> void:
	_player = player
	_root = Node3D.new()
	_root.name = "ParryBarrierRuntime"
	_player.add_child(_root)
	_root.visible = false
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = RADIUS
	cylinder.bottom_radius = RADIUS
	cylinder.height = HEIGHT
	cylinder.radial_segments = 48
	cylinder.rings = 6
	cylinder.cap_top = false
	cylinder.cap_bottom = false
	_shell = MeshInstance3D.new()
	_shell.name = "EnergyCylinder"
	_shell.mesh = cylinder
	_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shell_material = ShaderMaterial.new()
	var shield_shader: Shader = Shader.new()
	shield_shader.code = SHIELD_SHADER_CODE
	_shell_material.shader = shield_shader
	_shell.material_override = _shell_material
	_root.add_child(_shell)
	_ring_material = StandardMaterial3D.new()
	_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring_material.albedo_color = Color(0.18, 0.82, 1.0, RING_ALPHA)
	_ring_material.emission_enabled = true
	_ring_material.emission = Color(0.10, 0.65, 1.0)
	_ring_material.emission_energy_multiplier = RING_EMISSION_ENERGY
	set_color(_player_color)
	_top_ring = _make_ring("TopEnergyRing")
	_top_ring.position.y = HEIGHT * 0.5
	_bottom_ring = _make_ring("BottomEnergyRing")
	_bottom_ring.position.y = -HEIGHT * 0.5
	_root.add_child(_top_ring)
	_root.add_child(_bottom_ring)

func set_color(new_color: Color) -> void:
	_player_color = new_color
	# Brighten dark palette entries for visibility while retaining their hue.
	var luminous_color: Color = new_color.lerp(Color.WHITE, COLOR_WHITE_BLEND)
	if is_instance_valid(_shell_material):
		_shell_material.set_shader_parameter("shield_color", luminous_color)
	if is_instance_valid(_ring_material):
		var ring_color: Color = luminous_color
		ring_color.a = _ring_material.albedo_color.a
		_ring_material.albedo_color = ring_color
		_ring_material.emission = luminous_color

func begin() -> void:
	if not is_instance_valid(_root):
		return
	_active = true
	_activation_elapsed = 0.0
	_fade_elapsed = -1.0
	_impact_age = -1.0
	_opacity = 0.0
	_root.visible = true
	_root.scale = Vector3(0.82, 0.06, 0.82)
	_root.position.y = HEIGHT * 0.03
	_top_ring.position.y = -HEIGHT * 0.5
	_bottom_ring.position.y = -HEIGHT * 0.5
	_shell_material.set_shader_parameter("opacity", 0.0)
	_shell_material.set_shader_parameter("impact_age", -1.0)
	var ring_color: Color = _ring_material.albedo_color
	ring_color.a = 0.0
	_ring_material.albedo_color = ring_color

func play_impact(world_position: Vector3) -> void:
	if not _active or not is_instance_valid(_player) or not world_position.is_finite():
		return
	var local_position: Vector3 = _player.to_local(world_position)
	var angle: float = atan2(local_position.x, local_position.z)
	var u: float = fposmod(angle / TAU + 0.5, 1.0)
	var v: float = clampf(local_position.y / HEIGHT, 0.0, 1.0)
	_shell_material.set_shader_parameter("impact_uv", Vector2(u, v))
	_impact_age = 0.0
	_shell_material.set_shader_parameter("impact_age", _impact_age)

func end() -> void:
	if not is_instance_valid(_root) or not _active:
		return
	_active = false
	_fade_elapsed = 0.0

func advance(delta: float) -> void:
	if not is_instance_valid(_root) or not _root.visible:
		return
	var step: float = maxf(delta, 0.0)
	_root.rotation.y += step * 0.42
	if _active:
		_activation_elapsed += step
		var progress: float = clampf(_activation_elapsed / ACTIVATION_SECONDS, 0.0, 1.0)
		var eased: float = 1.0 - pow(1.0 - progress, 3.0)
		var current_height: float = lerpf(HEIGHT * 0.06, HEIGHT, eased)
		_root.position.y = current_height * 0.5
		_root.scale = Vector3(lerpf(0.82, 1.0, eased), current_height / HEIGHT, lerpf(0.82, 1.0, eased))
		_top_ring.position.y = lerpf(-HEIGHT * 0.5, HEIGHT * 0.5, eased)
		_opacity = smoothstep(0.0, 0.75, progress)
		if progress >= 1.0:
			_root.position.y = HEIGHT * 0.5
			_root.scale = Vector3.ONE
	elif _fade_elapsed >= 0.0:
		_fade_elapsed += step
		var fade: float = clampf(_fade_elapsed / FADE_SECONDS, 0.0, 1.0)
		var eased_fade: float = smoothstep(0.0, 1.0, fade)
		_opacity = 1.0 - eased_fade
		_root.position.y = HEIGHT * 0.5
		_root.scale = Vector3(1.0, lerpf(1.0, 0.72, eased_fade), 1.0)
		if fade >= 1.0:
			_root.visible = false
			_fade_elapsed = -1.0
	if _impact_age >= 0.0:
		_impact_age += step
		if _impact_age > 0.75:
			_impact_age = -1.0
		_shell_material.set_shader_parameter("impact_age", _impact_age)
	_shell_material.set_shader_parameter("opacity", _opacity)
	var ring_alpha: float = RING_ALPHA * _opacity
	var ring_color: Color = _ring_material.albedo_color
	ring_color.a = ring_alpha
	_ring_material.albedo_color = ring_color

func dispose() -> void:
	_active = false
	if is_instance_valid(_root):
		_root.queue_free()
	_root = null
	_shell = null
	_top_ring = null
	_bottom_ring = null
	_player = null

func _make_ring(ring_name: String) -> MeshInstance3D:
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = RADIUS * 0.99
	torus.outer_radius = RADIUS * 1.01
	torus.rings = 48
	torus.ring_segments = 8
	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.name = ring_name
	ring.mesh = torus
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.material_override = _ring_material
	return ring
