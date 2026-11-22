## Host-authoritative physical color selector for the Apartment lobby.
## Each TerminalButton keeps using the shared Focus/Interactable pipeline.
extends Node

const PlayerIdentity = preload("res://core/player_identity.gd")

const COLOR_BUTTONS: Dictionary = {
	&"red": 0,
	&"orange": 1,
	&"yellow": 2,
	&"green": 3,
	&"cyan": 4,
	&"blue": 5,
	&"purple": 6,
	&"pink": 7,
	&"black": 8,
	&"white": 9,
}

const TAKEN_ALBEDO_MULTIPLIER: float = 0.28
const TAKEN_EMISSION_MULTIPLIER: float = 0.12

var _network: Node = null
var _buttons: Dictionary = {}
var _key_materials: Dictionary = {}
var _label_materials: Dictionary = {}


func _ready() -> void:
	_network = get_node_or_null("/root/Network")
	var buttons_root: Node = get_parent().get_node_or_null("ColorButtons")
	if buttons_root == null:
		push_warning("PlayerColorPanel requires ColorButtons.")
		return

	for button_node: Node in buttons_root.get_children():
		var button: Node = button_node
		var color_id: StringName = StringName(str(button.get("button_id")))
		if not COLOR_BUTTONS.has(color_id):
			continue
		var color_index: int = int(COLOR_BUTTONS[color_id])
		_buttons[color_index] = button
		if button.has_signal("button_activated"):
			button.connect("button_activated", _on_button_activated.bind(color_index))
		var interactable: Interactable = button.get_node_or_null("Interactable") as Interactable
		if is_instance_valid(interactable):
			interactable.availability_check = Callable(self, "_can_select_color").bind(color_index)
		_cache_button_materials(color_index, button)

	if is_instance_valid(_network) and _network.has_signal("identity_roster_changed"):
		_network.connect("identity_roster_changed", _on_identity_roster_changed)
	_refresh_panel()


func _exit_tree() -> void:
	if is_instance_valid(_network) and _network.has_signal("identity_roster_changed"):
		if _network.is_connected("identity_roster_changed", _on_identity_roster_changed):
			_network.disconnect("identity_roster_changed", _on_identity_roster_changed)


func _cache_button_materials(color_index: int, button: Node) -> void:
	var key: Node3D = button.get_node_or_null("Visuals/ButtonKey") as Node3D
	if not is_instance_valid(key):
		return
	var key_mesh: MeshInstance3D = key.get_node_or_null("KeyMesh") as MeshInstance3D
	if is_instance_valid(key_mesh) and key_mesh.material_override is StandardMaterial3D:
		_key_materials[color_index] = (key_mesh.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D

	var label: MeshInstance3D = key.get_node_or_null("ButtonLabel") as MeshInstance3D
	if is_instance_valid(label):
		var text_mesh: TextMesh = label.mesh as TextMesh
		if text_mesh != null and text_mesh.material is StandardMaterial3D:
			_label_materials[color_index] = (text_mesh.material as StandardMaterial3D).duplicate() as StandardMaterial3D


func _can_select_color(actor: Node, action: StringName, color_index: int) -> bool:
	if action != &"use" or not is_instance_valid(_network):
		return false
	if not bool(_network.get("is_host")):
		return false
	var peer_id: int = _actor_peer_id(actor)
	if peer_id <= 0:
		return false
	var identities: Dictionary = _network.get("player_identities")
	for owner_key: Variant in identities.keys():
		var owner_id: int = int(owner_key)
		if owner_id == peer_id:
			continue
		var identity: PlayerIdentity = identities[owner_id] as PlayerIdentity
		if identity != null and identity.color_index == color_index:
			return false
	return true


func _on_button_activated(button_id: StringName, peer_id: int, color_index: int) -> void:
	if not is_instance_valid(_network) or not bool(_network.get("is_host")):
		return
	if not COLOR_BUTTONS.has(button_id) or int(COLOR_BUTTONS[button_id]) != color_index:
		return
	var identity: PlayerIdentity = _network.call("get_player_identity", peer_id) as PlayerIdentity
	if identity == null:
		return
	# The Network allocator is the final authority. If two presses race for the
	# same color, it advances to the next free palette entry for this peer.
	_network.call("_assign_player_identity", peer_id, identity.nickname, color_index)


func _on_identity_roster_changed() -> void:
	_refresh_panel()


func _refresh_panel() -> void:
	if not is_instance_valid(_network):
		return
	var identities: Dictionary = _network.get("player_identities")
	var taken_by: Dictionary = {}
	for owner_key: Variant in identities.keys():
		var peer_id: int = int(owner_key)
		var identity: PlayerIdentity = identities[owner_key] as PlayerIdentity
		if identity != null:
			taken_by[identity.color_index] = peer_id

	for color_key: Variant in _buttons.keys():
		var color_index: int = int(color_key)
		var button: Node = _buttons[color_index]
		var owner_id: int = int(taken_by.get(color_index, 0))
		var color_taken: bool = owner_id > 0
		var interactable: Interactable = button.get_node_or_null("Interactable") as Interactable
		if is_instance_valid(interactable):
			interactable.enabled = not color_taken
		_set_button_dimmed(color_index, button, color_taken)


func _set_button_dimmed(color_index: int, button: Node, dimmed: bool) -> void:
	var key: Node3D = button.get_node_or_null("Visuals/ButtonKey") as Node3D
	if not is_instance_valid(key):
		return
	var key_mesh: MeshInstance3D = key.get_node_or_null("KeyMesh") as MeshInstance3D
	if is_instance_valid(key_mesh) and _key_materials.has(color_index):
		var key_material: StandardMaterial3D = (_key_materials[color_index] as StandardMaterial3D).duplicate() as StandardMaterial3D
		if dimmed:
			key_material.albedo_color = key_material.albedo_color * TAKEN_ALBEDO_MULTIPLIER
			key_material.emission = key_material.emission * TAKEN_EMISSION_MULTIPLIER
			key_material.emission_energy_multiplier *= TAKEN_EMISSION_MULTIPLIER
		key_mesh.material_override = key_material

	var label: MeshInstance3D = key.get_node_or_null("ButtonLabel") as MeshInstance3D
	if is_instance_valid(label) and _label_materials.has(color_index):
		var text_mesh: TextMesh = label.mesh as TextMesh
		if text_mesh != null:
			var label_material: StandardMaterial3D = (_label_materials[color_index] as StandardMaterial3D).duplicate() as StandardMaterial3D
			if dimmed:
				label_material.albedo_color = label_material.albedo_color * 0.35
				label_material.emission = label_material.emission * 0.2
				label_material.emission_energy_multiplier *= 0.2
			var unique_text_mesh: TextMesh = text_mesh.duplicate() as TextMesh
			unique_text_mesh.material = label_material
			label.mesh = unique_text_mesh


func _actor_peer_id(actor: Node) -> int:
	if not is_instance_valid(actor):
		return 0
	for property: Dictionary in actor.get_property_list():
		if str(property.get("name", "")) == "input_peer_id":
			return int(actor.get("input_peer_id"))
	return 0
