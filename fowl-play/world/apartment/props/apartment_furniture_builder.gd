@tool
extends Node3D
class_name ApartmentFurnitureBuilder

## Warm-modern Apartment furniture and dressing collection.
## Attach to Environment/Props at local origin. All generated geometry is grouped
## under one clearly named root. Carryable pieces instance the existing base_prop.tscn.

@export_group("Collection")
@export var generate_living_room: bool = true
@export var generate_dining_area: bool = true
@export var generate_storage_and_decor: bool = true
@export var generate_carryable_props: bool = true

@export_group("Materials")
@export var walnut_color: Color = Color(0.16, 0.092, 0.052, 1.0)
@export var walnut_dark_color: Color = Color(0.075, 0.041, 0.025, 1.0)
@export var charcoal_color: Color = Color(0.035, 0.043, 0.052, 1.0)
@export var bronze_color: Color = Color(0.42, 0.255, 0.12, 1.0)
@export var upholstery_color: Color = Color(0.34, 0.29, 0.23, 1.0)
@export var upholstery_light_color: Color = Color(0.48, 0.41, 0.32, 1.0)
@export var stone_color: Color = Color(0.22, 0.235, 0.24, 1.0)
@export var rug_color: Color = Color(0.16, 0.145, 0.125, 1.0)
@export var ceramic_color: Color = Color(0.72, 0.66, 0.55, 1.0)
@export var leaf_color: Color = Color(0.12, 0.22, 0.13, 1.0)

@export_group("Generation")
@export var rebuild_props: bool = false:
	set(value):
		if value:
			call_deferred("_rebuild_props")

const GENERATED_ROOT_NAME: String = "_GeneratedApartmentProps"
const BASE_PROP_PATH: String = "res://props/base_prop.tscn"
const LIGHT_SMALL_PROFILE: String = "res://world/apartment/props/profiles/light_small_prop.tres"
const LIGHT_MEDIUM_PROFILE: String = "res://world/apartment/props/profiles/light_medium_prop.tres"
const MEDIUM_PROFILE: String = "res://world/apartment/props/profiles/medium_medium_prop.tres"

var _walnut: StandardMaterial3D
var _walnut_dark: StandardMaterial3D
var _bronze: StandardMaterial3D
var _charcoal: StandardMaterial3D
var _upholstery: StandardMaterial3D
var _upholstery_light: StandardMaterial3D
var _stone: StandardMaterial3D
var _rug: StandardMaterial3D
var _ceramic: StandardMaterial3D
var _leaf: StandardMaterial3D
var _metal: StandardMaterial3D
var _glass: StandardMaterial3D

func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild_props()

func _rebuild_props() -> void:
	if not Engine.is_editor_hint():
		return
	var scene_root: Node = get_tree().edited_scene_root
	if scene_root == null:
		return
	var previous: Node = get_node_or_null(GENERATED_ROOT_NAME)
	if previous != null:
		previous.free()

	_create_materials()
	var generated: Node3D = Node3D.new()
	generated.name = GENERATED_ROOT_NAME
	add_child(generated)
	generated.owner = scene_root

	if generate_living_room:
		_build_living_room(generated, scene_root)
	if generate_dining_area:
		_build_dining_area(generated, scene_root)
	if generate_storage_and_decor:
		_build_storage_and_decor(generated, scene_root)
	if generate_carryable_props:
		_build_carryable_props(generated, scene_root)

func _create_materials() -> void:
	_walnut = _material(walnut_color, 0.0, 0.34)
	_walnut_dark = _material(walnut_dark_color, 0.0, 0.4)
	_bronze = _material(bronze_color, 0.78, 0.27)
	_charcoal = _material(charcoal_color, 0.08, 0.3)
	_upholstery = _material(upholstery_color, 0.0, 0.92)
	_upholstery_light = _material(upholstery_light_color, 0.0, 0.9)
	_stone = _material(stone_color, 0.12, 0.24)
	_rug = _material(rug_color, 0.0, 1.0)
	_ceramic = _material(ceramic_color, 0.0, 0.22)
	_leaf = _material(leaf_color, 0.0, 0.72)
	_metal = _material(Color(0.075, 0.08, 0.085, 1.0), 0.82, 0.25)
	_glass = _material(Color(0.12, 0.19, 0.22, 0.48), 0.35, 0.12)
	_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

func _build_living_room(parent: Node3D, scene_root: Node) -> void:
	var room: Node3D = _group(parent, "LivingRoom", scene_root)

	# Large low-profile sectional: deep plinth, separate seat cushions, back cushions,
	# upholstered arms, inset walnut feet and subtle bronze foot caps.
	var sofa: Node3D = _group(room, "MainSectionalSofa", scene_root)
	_box(sofa, "Sofa_Base", Vector3(4.65, 0.34, 1.18), Vector3(-2.4, 0.34, 2.2), _walnut_dark, scene_root)
	_box(sofa, "Sofa_Front_Apron", Vector3(4.55, 0.22, 0.12), Vector3(-2.4, 0.47, 1.62), _walnut, scene_root)
	for index: int in range(3):
		var x: float = -3.95 + float(index) * 1.55
		_box(sofa, "Seat_Cushion_%02d" % (index + 1), Vector3(1.48, 0.22, 1.02), Vector3(x, 0.66, 2.18), _upholstery_light, scene_root)
		_box(sofa, "Back_Cushion_%02d" % (index + 1), Vector3(1.48, 0.94, 0.28), Vector3(x, 1.12, 2.68), _upholstery, scene_root)
		_box(sofa, "Walnut_Foot_%02d" % (index + 1), Vector3(0.12, 0.22, 0.12), Vector3(x, 0.12, 1.78), _walnut_dark, scene_root)
	_box(sofa, "Left_Arm", Vector3(0.34, 0.82, 1.22), Vector3(-4.78, 0.76, 2.18), _upholstery, scene_root)
	_box(sofa, "Right_Arm", Vector3(0.34, 0.82, 1.22), Vector3(0.0, 0.76, 2.18), _upholstery, scene_root)
	_box(sofa, "Chaise_Seat", Vector3(1.55, 0.23, 1.35), Vector3(-4.15, 0.67, 0.96), _upholstery_light, scene_root)
	_box(sofa, "Chaise_Back", Vector3(1.55, 0.9, 0.28), Vector3(-4.15, 1.1, 1.57), _upholstery, scene_root)
	_box(sofa, "Chaise_Walnut_Base", Vector3(1.62, 0.32, 1.4), Vector3(-4.15, 0.34, 0.98), _walnut_dark, scene_root)
	_box(sofa, "Sofa_Throw_Pillow_Left", Vector3(0.48, 0.48, 0.2), Vector3(-3.8, 1.25, 2.42), _upholstery_light, scene_root)
	_box(sofa, "Sofa_Throw_Pillow_Right", Vector3(0.48, 0.48, 0.2), Vector3(-0.95, 1.25, 2.42), _upholstery_light, scene_root)
	_static_box_collision(room, "SectionalSofaCollision", Vector3(5.3, 1.55, 2.55), Vector3(-2.4, 0.78, 1.55), scene_root)

	# Layered rug and inset border.
	var rug: Node3D = _group(room, "Large_Woven_Area_Rug", scene_root)
	_box(rug, "Rug_Main_Field", Vector3(6.9, 0.035, 4.5), Vector3(-2.35, 0.025, -0.05), _rug, scene_root)
	_box(rug, "Rug_Border_North", Vector3(6.65, 0.012, 0.035), Vector3(-2.35, 0.05, -2.24), _upholstery_light, scene_root)
	_box(rug, "Rug_Border_South", Vector3(6.65, 0.012, 0.035), Vector3(-2.35, 0.05, 2.14), _upholstery_light, scene_root)
	_box(rug, "Rug_Border_West", Vector3(0.035, 0.012, 4.25), Vector3(-5.72, 0.05, -0.05), _upholstery_light, scene_root)
	_box(rug, "Rug_Border_East", Vector3(0.035, 0.012, 4.25), Vector3(1.02, 0.05, -0.05), _upholstery_light, scene_root)

	# Sculptural coffee table: chamfered-looking layered top, inset shadow reveal,
	# twin pedestal supports and bronze detailing.
	var coffee: Node3D = _group(room, "Sculpted_Walnut_Coffee_Table", scene_root)
	_box(coffee, "Stone_Inlay_Top", Vector3(2.55, 0.13, 1.12), Vector3(-2.3, 0.63, -0.1), _stone, scene_root)
	_box(coffee, "Walnut_Top_Lip", Vector3(2.66, 0.075, 1.22), Vector3(-2.3, 0.55, -0.1), _walnut, scene_root)
	_box(coffee, "Shadow_Reveal", Vector3(2.3, 0.06, 0.88), Vector3(-2.3, 0.48, -0.1), _charcoal, scene_root)
	_box(coffee, "Pedestal_Left", Vector3(0.72, 0.43, 0.78), Vector3(-3.05, 0.25, -0.1), _walnut_dark, scene_root)
	_box(coffee, "Pedestal_Right", Vector3(0.72, 0.43, 0.78), Vector3(-1.55, 0.25, -0.1), _walnut_dark, scene_root)
	_box(coffee, "Bronze_Inlay", Vector3(2.3, 0.018, 0.025), Vector3(-2.3, 0.69, -0.1), _bronze, scene_root)
	_static_box_collision(room, "CoffeeTableCollision", Vector3(2.72, 0.72, 1.28), Vector3(-2.3, 0.36, -0.1), scene_root)

	# Low media wall console and a large slim television.
	var media: Node3D = _group(room, "Walnut_Media_Console", scene_root)
	_box(media, "Console_Carcass", Vector3(4.8, 0.52, 0.48), Vector3(-2.5, 0.43, -7.85), _walnut, scene_root)
	_box(media, "Console_Shadow_Base", Vector3(4.55, 0.12, 0.4), Vector3(-2.5, 0.12, -7.82), _charcoal, scene_root)
	_box(media, "Console_Stone_Top", Vector3(4.92, 0.075, 0.54), Vector3(-2.5, 0.72, -7.85), _stone, scene_root)
	for index: int in range(4):
		var drawer_x: float = -4.25 + float(index) * 1.17
		_box(media, "Drawer_Front_%02d" % (index + 1), Vector3(1.08, 0.32, 0.035), Vector3(drawer_x, 0.43, -7.59), _walnut_dark, scene_root)
		_box(media, "Drawer_Handle_%02d" % (index + 1), Vector3(0.24, 0.025, 0.025), Vector3(drawer_x, 0.46, -7.55), _bronze, scene_root)
	_box(media, "Television_Screen", Vector3(3.45, 1.92, 0.09), Vector3(-2.5, 2.08, -8.25), _charcoal, scene_root)
	_box(media, "Television_Bezel", Vector3(3.55, 2.02, 0.055), Vector3(-2.5, 2.08, -8.29), _metal, scene_root)
	_box(media, "TV_Stand_Left", Vector3(0.42, 0.12, 0.25), Vector3(-3.6, 1.08, -8.12), _metal, scene_root)
	_box(media, "TV_Stand_Right", Vector3(0.42, 0.12, 0.25), Vector3(-1.4, 1.08, -8.12), _metal, scene_root)
	_static_box_collision(room, "MediaConsoleCollision", Vector3(4.95, 0.82, 0.58), Vector3(-2.5, 0.42, -7.85), scene_root)

	_build_side_table(room, "Window_Side_Table", Vector3(2.0, 0.0, 2.05), scene_root)
	_build_side_table(room, "Sofa_Side_Table", Vector3(-5.55, 0.0, 2.15), scene_root)
	_build_floor_lamp(room, "Arc_Floor_Lamp", Vector3(1.3, 0.0, 2.75), scene_root)

func _build_side_table(parent: Node3D, table_name: String, origin: Vector3, scene_root: Node) -> void:
	var table: Node3D = _group(parent, table_name, scene_root)
	_box(table, "Walnut_Tabletop", Vector3(0.82, 0.11, 0.72), origin + Vector3(0.0, 0.58, 0.0), _walnut, scene_root)
	_box(table, "Bronze_Shadow_Line", Vector3(0.76, 0.018, 0.66), origin + Vector3(0.0, 0.51, 0.0), _bronze, scene_root)
	_box(table, "Pedestal", Vector3(0.36, 0.47, 0.34), origin + Vector3(0.0, 0.27, 0.0), _walnut_dark, scene_root)
	_box(table, "Stone_Foot", Vector3(0.64, 0.08, 0.58), origin + Vector3(0.0, 0.06, 0.0), _stone, scene_root)
	_static_box_collision(parent, table_name + "Collision", Vector3(0.86, 0.72, 0.76), origin + Vector3(0.0, 0.36, 0.0), scene_root)

func _build_floor_lamp(parent: Node3D, lamp_name: String, origin: Vector3, scene_root: Node) -> void:
	var lamp: Node3D = _group(parent, lamp_name, scene_root)
	_cylinder(lamp, "Weighted_Base", 0.32, 0.08, origin + Vector3(0.0, 0.04, 0.0), _metal, scene_root)
	_cylinder(lamp, "Stem", 0.035, 1.72, origin + Vector3(0.0, 0.94, 0.0), _bronze, scene_root)
	_box(lamp, "Crossbar", Vector3(0.9, 0.035, 0.035), origin + Vector3(0.38, 1.78, 0.0), _bronze, scene_root)
	_cylinder(lamp, "Shade", 0.24, 0.28, origin + Vector3(0.76, 1.68, 0.0), _ceramic, scene_root)
	_static_box_collision(parent, lamp_name + "Collision", Vector3(0.5, 1.9, 0.5), origin + Vector3(0.38, 0.95, 0.0), scene_root)

func _build_dining_area(parent: Node3D, scene_root: Node) -> void:
	var dining: Node3D = _group(parent, "DiningArea", scene_root)
	var table: Node3D = _group(dining, "Walnut_Dining_Table", scene_root)
	_box(table, "Tabletop_Core", Vector3(3.15, 0.16, 1.45), Vector3(6.35, 0.79, 5.65), _walnut, scene_root)
	_box(table, "Stone_Inset", Vector3(2.72, 0.025, 1.05), Vector3(6.35, 0.885, 5.65), _stone, scene_root)
	_box(table, "Bronze_Edge_North", Vector3(3.02, 0.025, 0.025), Vector3(6.35, 0.89, 4.96), _bronze, scene_root)
	_box(table, "Bronze_Edge_South", Vector3(3.02, 0.025, 0.025), Vector3(6.35, 0.89, 6.34), _bronze, scene_root)
	for x_offset: float in [-1.18, 1.18]:
		for z_offset: float in [-0.48, 0.48]:
			_box(table, "Tapered_Leg_%s_%s" % [str(x_offset), str(z_offset)], Vector3(0.16, 0.72, 0.16), Vector3(6.35 + x_offset, 0.36, 5.65 + z_offset), _walnut_dark, scene_root)
	_static_box_collision(dining, "DiningTableCollision", Vector3(3.2, 0.95, 1.5), Vector3(6.35, 0.48, 5.65), scene_root)
	for index: int in range(4):
		var chair_x: float = 6.35 + (1.0 if index % 2 == 0 else -1.0) * 2.0
		var chair_z: float = 5.65 + (-0.48 if index < 2 else 0.48)
		_build_dining_chair(dining, "Upholstered_Dining_Chair_%02d" % (index + 1), Vector3(chair_x, 0.0, chair_z), index % 2 == 0, scene_root)

	var sideboard: Node3D = _group(dining, "Dining_Sideboard", scene_root)
	_box(sideboard, "Sideboard_Carcass", Vector3(2.6, 0.86, 0.48), Vector3(8.4, 0.52, 1.8), _walnut, scene_root)
	_box(sideboard, "Stone_Cap", Vector3(2.68, 0.09, 0.54), Vector3(8.4, 1.0, 1.8), _stone, scene_root)
	for index: int in range(3):
		var x: float = 7.55 + float(index) * 0.85
		_box(sideboard, "Cabinet_Door_%02d" % (index + 1), Vector3(0.78, 0.68, 0.035), Vector3(x, 0.53, 1.545), _walnut_dark, scene_root)
		_box(sideboard, "Bronze_Pull_%02d" % (index + 1), Vector3(0.045, 0.22, 0.035), Vector3(x + 0.27, 0.55, 1.51), _bronze, scene_root)
	_static_box_collision(dining, "DiningSideboardCollision", Vector3(2.7, 1.08, 0.56), Vector3(8.4, 0.54, 1.8), scene_root)

func _build_dining_chair(parent: Node3D, chair_name: String, origin: Vector3, faces_right: bool, scene_root: Node) -> void:
	var chair: Node3D = _group(parent, chair_name, scene_root)
	var rotation_y: float = PI * 0.5 if faces_right else -PI * 0.5
	chair.position = origin
	chair.rotation.y = rotation_y
	_box(chair, "Walnut_Frame_Seat", Vector3(0.72, 0.12, 0.72), Vector3(0.0, 0.48, 0.0), _walnut, scene_root)
	_box(chair, "Padded_Seat", Vector3(0.66, 0.14, 0.66), Vector3(0.0, 0.61, 0.0), _upholstery_light, scene_root)
	_box(chair, "Upholstered_Back", Vector3(0.72, 0.86, 0.16), Vector3(0.0, 1.03, -0.28), _upholstery, scene_root)
	_box(chair, "Back_Walnut_Rail", Vector3(0.76, 0.09, 0.2), Vector3(0.0, 1.48, -0.28), _walnut, scene_root)
	for x_offset: float in [-0.27, 0.27]:
		for z_offset: float in [-0.27, 0.27]:
			_box(chair, "Leg_%s_%s" % [str(x_offset), str(z_offset)], Vector3(0.075, 0.45, 0.075), Vector3(x_offset, 0.23, z_offset), _walnut_dark, scene_root)
	_static_box_collision(chair, "DiningChairCollision", Vector3(0.78, 1.55, 0.82), Vector3(0.0, 0.78, 0.0), scene_root)

func _build_storage_and_decor(parent: Node3D, scene_root: Node) -> void:
	var decor: Node3D = _group(parent, "StorageAndDecor", scene_root)
	var shelf: Node3D = _group(decor, "Open_Walnut_Display_Shelving", scene_root)
	for y_level: float in [0.45, 1.35, 2.25, 3.15]:
		_box(shelf, "Shelf_%s" % str(y_level), Vector3(2.6, 0.09, 0.34), Vector3(8.65, y_level, -5.8), _walnut, scene_root)
	for x_pos: float in [7.42, 9.88]:
		_box(shelf, "Vertical_Support_%s" % str(x_pos), Vector3(0.09, 3.25, 0.32), Vector3(x_pos, 1.7, -5.8), _walnut_dark, scene_root)
	_box(shelf, "Bronze_Back_Accent", Vector3(2.45, 2.95, 0.025), Vector3(8.65, 1.8, -5.59), _bronze, scene_root)
	_static_box_collision(decor, "DisplayShelfCollision", Vector3(2.75, 3.35, 0.42), Vector3(8.65, 1.68, -5.8), scene_root)

	_build_planter(decor, "Large_Indoor_Planter", Vector3(8.6, 0.0, -1.0), 0.42, scene_root)
	_build_planter(decor, "Corner_Indoor_Planter", Vector3(8.7, 0.0, 8.0), 0.34, scene_root)
	_build_planter(decor, "Hall_Side_Planter", Vector3(-9.3, 0.0, 5.5), 0.28, scene_root)

	# Large framed abstract artwork over the media console.
	var art: Node3D = _group(decor, "Framed_Abstract_Wall_Art", scene_root)
	_box(art, "Dark_Frame", Vector3(3.4, 1.55, 0.11), Vector3(-2.5, 3.25, -9.23), _walnut_dark, scene_root)
	_box(art, "Canvas", Vector3(3.2, 1.35, 0.035), Vector3(-2.5, 3.25, -9.15), _stone, scene_root)
	_box(art, "Ochre_Form", Vector3(0.72, 0.96, 0.025), Vector3(-3.18, 3.25, -9.12), _bronze, scene_root)
	_box(art, "Walnut_Form", Vector3(0.48, 1.12, 0.025), Vector3(-2.38, 3.25, -9.11), _walnut, scene_root)
	_box(art, "Ivory_Form", Vector3(0.42, 0.68, 0.025), Vector3(-1.68, 3.25, -9.1), _ceramic, scene_root)

func _build_planter(parent: Node3D, planter_name: String, origin: Vector3, radius: float, scene_root: Node) -> void:
	var planter: Node3D = _group(parent, planter_name, scene_root)
	_cylinder(planter, "Stone_Planter", radius, 0.68, origin + Vector3(0.0, 0.34, 0.0), _stone, scene_root)
	_cylinder(planter, "Bronze_Rim", radius + 0.025, 0.055, origin + Vector3(0.0, 0.68, 0.0), _bronze, scene_root)
	_cylinder(planter, "Soil", radius * 0.82, 0.045, origin + Vector3(0.0, 0.71, 0.0), _walnut_dark, scene_root)
	for index: int in range(7):
		var angle: float = TAU * float(index) / 7.0
		var leaf_position: Vector3 = origin + Vector3(cos(angle) * radius * 0.48, 1.18 + float(index % 3) * 0.16, sin(angle) * radius * 0.48)
		var leaf_instance: MeshInstance3D = _sphere(planter, "Leaf_%02d" % (index + 1), Vector3(radius * 0.34, 0.72, radius * 0.12), leaf_position, _leaf, scene_root)
		leaf_instance.rotation.z = -0.38 if index % 2 == 0 else 0.38
	_cylinder(planter, "Central_Stem", 0.035, 0.95, origin + Vector3(0.0, 1.15, 0.0), _leaf, scene_root)
	_static_box_collision(parent, planter_name + "Collision", Vector3(radius * 2.1, 0.82, radius * 2.1), origin + Vector3(0.0, 0.41, 0.0), scene_root)

func _build_carryable_props(parent: Node3D, scene_root: Node) -> void:
	var carryables: Node3D = _group(parent, "CarryableProps", scene_root)
	_add_physical_prop(carryables, "Decorative_Ceramic_Vase", Vector3(2.0, 0.93, 2.05), _cylinder_mesh(0.16, 0.38), _ceramic, LIGHT_SMALL_PROFILE, Vector3(0.34, 0.4, 0.34), "Grab Ceramic Vase", scene_root)
	_add_physical_prop(carryables, "Walnut_Coaster_Set", Vector3(-2.1, 0.73, -0.12), _box_mesh(Vector3(0.24, 0.035, 0.24)), _walnut, LIGHT_SMALL_PROFILE, Vector3(0.26, 0.06, 0.26), "Grab Coasters", scene_root)
	_add_physical_prop(carryables, "Stoneware_Coffee_Cup", Vector3(-1.55, 0.78, -0.1), _cylinder_mesh(0.075, 0.13), _ceramic, LIGHT_SMALL_PROFILE, Vector3(0.17, 0.16, 0.17), "Grab Coffee Cup", scene_root)
	_add_physical_prop(carryables, "Decorative_Book_Stack", Vector3(-3.2, 0.75, -0.12), _box_mesh(Vector3(0.36, 0.12, 0.27)), _walnut_dark, LIGHT_MEDIUM_PROFILE, Vector3(0.38, 0.14, 0.29), "Grab Books", scene_root)
	_add_physical_prop(carryables, "Dining_Centerpiece_Bowl", Vector3(6.35, 0.96, 5.65), _cylinder_mesh(0.22, 0.10), _stone, LIGHT_MEDIUM_PROFILE, Vector3(0.46, 0.14, 0.46), "Grab Centerpiece Bowl", scene_root)

func _add_physical_prop(
	parent: Node3D,
	prop_name: String,
	prop_position: Vector3,
	mesh: Mesh,
	material: Material,
	profile_path: String,
	collision_size: Vector3,
	prompt: String,
	scene_root: Node
) -> void:
	var base_scene: PackedScene = load(BASE_PROP_PATH) as PackedScene
	var profile: PropProfile = load(profile_path) as PropProfile
	if base_scene == null or profile == null:
		push_warning("ApartmentFurnitureBuilder: could not load base prop or profile for " + prop_name)
		return
	var prop: Prop = base_scene.instantiate() as Prop
	if prop == null:
		return
	prop.name = prop_name
	prop.position = prop_position
	prop.profile = profile
	parent.add_child(prop)
	prop.owner = scene_root
	var visual: MeshInstance3D = prop.get_node("MeshInstance3D") as MeshInstance3D
	visual.name = "Visual"
	visual.mesh = mesh
	visual.material_override = material
	var collision: CollisionShape3D = prop.get_node("CollisionShape3D") as CollisionShape3D
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = collision_size
	collision.shape = shape
	var interactable: Interactable = prop.get_node("Interactable") as Interactable
	interactable.prompt_text = prompt
	interactable.outline_width_multiplier = 1.1

func _static_box_collision(parent: Node, node_name: String, size: Vector3, position: Vector3, scene_root: Node) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.position = position
	parent.add_child(body)
	body.owner = scene_root
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	collision.owner = scene_root

func _group(parent: Node, node_name: String, scene_root: Node) -> Node3D:
	var group: Node3D = Node3D.new()
	group.name = node_name
	parent.add_child(group)
	group.owner = scene_root
	return group

func _box(parent: Node, node_name: String, size: Vector3, position: Vector3, material: Material, scene_root: Node) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	parent.add_child(instance)
	instance.owner = scene_root
	return instance

func _cylinder(parent: Node, node_name: String, radius: float, height: float, position: Vector3, material: Material, scene_root: Node) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	var mesh: CylinderMesh = _cylinder_mesh(radius, height)
	mesh.radial_segments = 32
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	parent.add_child(instance)
	instance.owner = scene_root
	return instance

func _sphere(parent: Node, node_name: String, size: Vector3, position: Vector3, material: Material, scene_root: Node) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 24
	mesh.rings = 12
	instance.mesh = mesh
	instance.scale = size
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
	instance.owner = scene_root
	return instance

func _box_mesh(size: Vector3) -> BoxMesh:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	return mesh

func _cylinder_mesh(radius: float, height: float) -> CylinderMesh:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 0.82
	mesh.height = height
	mesh.radial_segments = 32
	return mesh

func _material(color: Color, metallic_value: float, roughness_value: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic_value
	material.roughness = roughness_value
	return material
