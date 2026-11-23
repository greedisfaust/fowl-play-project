@tool
extends RefCounted
class_name FowlPlayLightingRig

## Shared light construction helpers for the Casino and Apartment.
## Keeps light defaults, naming, ownership, and shadow policy consistent.

static func add_omni(
	parent: Node3D,
	node_name: String,
	light_position: Vector3,
	color: Color,
	energy: float,
	light_range: float,
	scene_root: Node,
	specular: float = 0.35
) -> OmniLight3D:
	var light: OmniLight3D = OmniLight3D.new()
	light.name = node_name
	light.position = light_position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.omni_attenuation = 1.2
	light.light_specular = specular
	light.shadow_enabled = false
	parent.add_child(light)
	light.owner = scene_root
	return light

static func add_spot(
	parent: Node3D,
	node_name: String,
	light_position: Vector3,
	light_rotation: Vector3,
	color: Color,
	energy: float,
	light_range: float,
	spot_angle: float,
	scene_root: Node
) -> SpotLight3D:
	var light: SpotLight3D = SpotLight3D.new()
	light.name = node_name
	light.position = light_position
	light.rotation = light_rotation
	light.light_color = color
	light.light_energy = energy
	light.spot_range = light_range
	light.spot_angle = spot_angle
	light.shadow_enabled = false
	parent.add_child(light)
	light.owner = scene_root
	return light
