@tool
## Builds the elevator's first-pass luxury cabin visuals from reusable primitive meshes.
## Attach this script to the Elevator root. The authored scene hierarchy remains untouched.
class_name ElevatorVisuals
extends Node3D

const INTERIOR_WIDTH: float = 3.2
const INTERIOR_DEPTH: float = 3.0
const INTERIOR_HEIGHT: float = 2.8
const DOOR_WIDTH: float = 2.4
const DOOR_HEIGHT: float = 2.2
const WALL_THICKNESS: float = 0.16

@export_group("Visual Generation")
@export var build_on_ready: bool = true
@export var rebuild_visuals: bool = false:
	set(value):
		if value:
			if is_inside_tree():
				call_deferred("_build_visuals")
			rebuild_visuals = false

@export_group("Finish Colors")
@export var lacquer_color: Color = Color("#111216")
@export var brass_color: Color = Color("#c6a56a")
@export var walnut_color: Color = Color("#39251b")
@export var floor_color: Color = Color("#242326")
@export var warm_light_color: Color = Color("#ffd49a")


func _ready() -> void:
	if build_on_ready and not _has_generated_visuals():
		_build_visuals()


func _has_generated_visuals() -> bool:
	var structure: Node = get_node_or_null("Structure")
	return structure != null and structure.has_node("GeneratedShell")


func _build_visuals() -> void:
	var structure: Node3D = get_node_or_null("Structure") as Node3D
	var doors: Node3D = get_node_or_null("DoorAssembly") as Node3D
	var interior: Node3D = get_node_or_null("InteriorDetails") as Node3D
	var lighting: Node3D = get_node_or_null("Lighting") as Node3D
	if structure == null or doors == null or interior == null or lighting == null:
		push_error("ElevatorVisuals requires Structure, DoorAssembly, InteriorDetails, and Lighting children.")
		return

	var shell: Node3D = _reset_container(structure, "GeneratedShell")
	var interior_root: Node3D = _reset_container(interior, "GeneratedInterior")
	var lighting_root: Node3D = _reset_container(lighting, "GeneratedLighting")

	_build_shell(shell)
	_build_interior(interior_root)
	_build_doors(doors)
	_build_lighting(lighting_root)


func _build_shell(parent: Node3D) -> void:
	var lacquer: StandardMaterial3D = _material(lacquer_color, 0.28, 0.32)
	var brass: StandardMaterial3D = _material(brass_color, 0.72, 0.24, 0.18)
	var floor_material: StandardMaterial3D = _material(floor_color, 0.18, 0.42)
	var dark_glass: StandardMaterial3D = _material(Color("#202126"), 0.38, 0.16)

	# The cabin floor is at Y=0; the entrance faces negative Z.
	_add_box(parent, "CabinFloor", Vector3(3.52, 0.16, 3.32), Vector3(0.0, -0.08, 0.0), floor_material)
	_add_box(parent, "BackWall", Vector3(3.52, 2.8, 0.16), Vector3(0.0, 1.4, 1.58), lacquer)
	_add_box(parent, "LeftWall", Vector3(0.16, 2.8, 3.16), Vector3(-1.68, 1.4, 0.0), lacquer)
	_add_box(parent, "RightWall", Vector3(0.16, 2.8, 3.16), Vector3(1.68, 1.4, 0.0), lacquer)
	_add_box(parent, "CeilingSlab", Vector3(3.52, 0.16, 3.32), Vector3(0.0, 2.88, 0.0), lacquer)

	# Front portal leaves the full 2.4 m door opening clear.
	var side_width: float = (3.52 - DOOR_WIDTH) * 0.5
	_add_box(parent, "FrontLeftPier", Vector3(side_width, 2.8, 0.16), Vector3(-1.76 + side_width * 0.5, 1.4, -1.58), lacquer)
	_add_box(parent, "FrontRightPier", Vector3(side_width, 2.8, 0.16), Vector3(1.76 - side_width * 0.5, 1.4, -1.58), lacquer)
	_add_box(parent, "FrontHeader", Vector3(DOOR_WIDTH, 0.6, 0.18), Vector3(0.0, 2.5, -1.58), lacquer)

	# Brass portal trim and restrained smoked-glass side accents.
	_add_box(parent, "PortalTopTrim", Vector3(2.52, 0.055, 0.22), Vector3(0.0, 2.22, -1.66), brass)
	_add_box(parent, "PortalLeftTrim", Vector3(0.055, 2.25, 0.22), Vector3(-1.24, 1.1, -1.66), brass)
	_add_box(parent, "PortalRightTrim", Vector3(0.055, 2.25, 0.22), Vector3(1.24, 1.1, -1.66), brass)
	_add_box(parent, "LeftGlassAccent", Vector3(0.025, 1.65, 0.018), Vector3(-1.56, 1.42, -1.49), dark_glass)
	_add_box(parent, "RightGlassAccent", Vector3(0.025, 1.65, 0.018), Vector3(1.56, 1.42, -1.49), dark_glass)


func _build_interior(parent: Node3D) -> void:
	var walnut: StandardMaterial3D = _material(walnut_color, 0.32, 0.36)
	var brass: StandardMaterial3D = _material(brass_color, 0.72, 0.24, 0.16)
	var dark: StandardMaterial3D = _material(Color("#090a0d"), 0.22, 0.3)
	var stone: StandardMaterial3D = _material(Color("#49464a"), 0.2, 0.3)

	# Back-wall centerpiece: framed walnut panels with narrow brass reveals.
	_add_box(parent, "BackFeaturePanel", Vector3(1.9, 2.15, 0.035), Vector3(0.0, 1.38, 1.485), walnut)
	_add_box(parent, "BackFeatureInset", Vector3(1.72, 1.95, 0.025), Vector3(0.0, 1.38, 1.46), dark)
	_add_box(parent, "BackFeatureTop", Vector3(1.96, 0.035, 0.045), Vector3(0.0, 2.48, 1.44), brass)
	_add_box(parent, "BackFeatureBottom", Vector3(1.96, 0.035, 0.045), Vector3(0.0, 0.28, 1.44), brass)
	_add_box(parent, "BackFeatureLeft", Vector3(0.035, 2.2, 0.045), Vector3(-0.98, 1.38, 1.44), brass)
	_add_box(parent, "BackFeatureRight", Vector3(0.035, 2.2, 0.045), Vector3(0.98, 1.38, 1.44), brass)

	# Side-wall wainscoting and vertical brass divisions.
	for side: int in [-1, 1]:
		var x: float = float(side) * 1.585
		_add_box(parent, "SideWalnut_%d" % side, Vector3(0.035, 1.35, 2.35), Vector3(x, 0.92, 0.0), walnut)
		_add_box(parent, "SideBrassReveal_%d" % side, Vector3(0.045, 1.55, 0.035), Vector3(float(side) * 1.55, 0.98, 0.0), brass)
		_add_box(parent, "SideStoneSkirt_%d" % side, Vector3(0.045, 0.28, 2.5), Vector3(float(side) * 1.55, 0.16, 0.0), stone)

	# Ceiling medallion and floor perimeter inlays.
	_add_box(parent, "CeilingDarkInset", Vector3(2.25, 0.025, 2.05), Vector3(0.0, 2.785, 0.0), dark)
	_add_box(parent, "CeilingBrassFront", Vector3(2.32, 0.025, 0.035), Vector3(0.0, 2.765, -1.04), brass)
	_add_box(parent, "CeilingBrassBack", Vector3(2.32, 0.025, 0.035), Vector3(0.0, 2.765, 1.04), brass)
	_add_box(parent, "FloorInlayFront", Vector3(2.8, 0.012, 0.025), Vector3(0.0, 0.012, -1.32), brass)
	_add_box(parent, "FloorInlayBack", Vector3(2.8, 0.012, 0.025), Vector3(0.0, 0.012, 1.32), brass)


func _build_doors(door_assembly: Node3D) -> void:
	var panel_material: StandardMaterial3D = _material(lacquer_color, 0.3, 0.28)
	var brass: StandardMaterial3D = _material(brass_color, 0.75, 0.2, 0.14)
	var inset_material: StandardMaterial3D = _material(Color("#252329"), 0.4, 0.2)

	var panel_names: Array[String] = [
		"LeftOuterPanel",
		"LeftInnerPanel",
		"RightInnerPanel",
		"RightOuterPanel"
	]
	var panel_x: Array[float] = [-0.9, -0.3, 0.3, 0.9]
	for index: int in range(panel_names.size()):
		var panel: Node3D = door_assembly.get_node_or_null(panel_names[index]) as Node3D
		if panel == null:
			push_error("Elevator is missing door pivot: %s" % panel_names[index])
			continue
		var depth_offset: float = -1.52 if panel.name == "LeftOuterPanel" or panel.name == "RightOuterPanel" else -1.44
		panel.position = Vector3(panel_x[index], 1.1, depth_offset)
		var visuals: Node3D = _reset_container(panel, "GeneratedPanel")
		_add_box(visuals, "DoorLeaf", Vector3(0.62, 2.18, 0.075), Vector3.ZERO, panel_material)
		_add_box(visuals, "DoorInset", Vector3(0.50, 1.92, 0.018), Vector3(0.0, 0.0, -0.047), inset_material)
		_add_box(visuals, "DoorTopRail", Vector3(0.62, 0.035, 0.11), Vector3(0.0, 1.055, -0.035), brass)
		_add_box(visuals, "DoorBottomRail", Vector3(0.62, 0.035, 0.11), Vector3(0.0, -1.055, -0.035), brass)
		_add_box(visuals, "DoorLeftRail", Vector3(0.025, 2.12, 0.11), Vector3(-0.285, 0.0, -0.035), brass)
		_add_box(visuals, "DoorRightRail", Vector3(0.025, 2.12, 0.11), Vector3(0.285, 0.0, -0.035), brass)


func _build_lighting(parent: Node3D) -> void:
	var emissive: StandardMaterial3D = _material(warm_light_color, 0.35, 0.2)
	emissive.emission_enabled = true
	emissive.emission = warm_light_color
	emissive.emission_energy_multiplier = 1.6

	_add_box(parent, "CeilingLightPanel", Vector3(1.65, 0.025, 1.45), Vector3(0.0, 2.755, 0.0), emissive)
	_add_box(parent, "EntranceLightStrip", Vector3(2.15, 0.025, 0.035), Vector3(0.0, 2.19, -1.62), emissive)

	var ceiling_light: OmniLight3D = OmniLight3D.new()
	ceiling_light.name = "WarmCeilingLight"
	ceiling_light.position = Vector3(0.0, 2.58, 0.0)
	ceiling_light.light_color = warm_light_color
	ceiling_light.light_energy = 1.4
	ceiling_light.omni_range = 5.5
	parent.add_child(ceiling_light)
	_set_owner(ceiling_light)

	var entrance_light: OmniLight3D = OmniLight3D.new()
	entrance_light.name = "EntranceGlow"
	entrance_light.position = Vector3(0.0, 2.25, -1.15)
	entrance_light.light_color = warm_light_color
	entrance_light.light_energy = 0.65
	entrance_light.omni_range = 2.5
	parent.add_child(entrance_light)
	_set_owner(entrance_light)


func _reset_container(parent: Node3D, container_name: String) -> Node3D:
	var existing: Node = parent.get_node_or_null(container_name)
	if existing != null:
		parent.remove_child(existing)
		existing.free()
	var container: Node3D = Node3D.new()
	container.name = container_name
	parent.add_child(container)
	_set_owner(container)
	return container


func _add_box(parent: Node3D, node_name: String, box_size: Vector3, box_position: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = node_name
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = box_size
	box_mesh.material = material
	mesh_instance.mesh = box_mesh
	mesh_instance.position = box_position
	parent.add_child(mesh_instance)
	_set_owner(mesh_instance)
	return mesh_instance


func _material(color: Color, metallic: float, roughness: float, specular: float = 0.5) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	material.metallic_specular = specular
	return material


func _set_owner(node: Node) -> void:
	if Engine.is_editor_hint():
		var edited_root: Node = get_tree().edited_scene_root
		if edited_root != null and node != edited_root:
			node.owner = edited_root
