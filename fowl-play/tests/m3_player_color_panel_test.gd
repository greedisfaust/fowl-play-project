## Contract checks for the editor-authored Apartment player color panel.
extends SceneTree

const PANEL_SCENE = preload("res://environment/kit/player_color_panel.tscn")
const PANEL_SCRIPT = preload("res://ui/player_color_panel.gd")
const PlayerIdentity = preload("res://core/player_identity.gd")

var _failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var network: Node = root.get_node("Network")
	network.call("shutdown")
	network.set("is_host", true)
	network.set("connected_peers", [1, 2])
	network.set("player_identities", {})
	_check(bool(network.call("_assign_player_identity", 1, "Host", 0)), "Host receives the first requested color")
	_check(bool(network.call("_assign_player_identity", 2, "Client", 1)), "Client receives a distinct initial color")

	var panel: Node3D = PANEL_SCENE.instantiate() as Node3D
	var controller: Node = panel.get_node("ColorPanelController")
	controller.set_script(PANEL_SCRIPT)
	root.add_child(panel)
	await process_frame

	var red_interactable: Interactable = panel.get_node("ColorButtons/RedButton/Interactable") as Interactable
	var orange_interactable: Interactable = panel.get_node("ColorButtons/OrangeButton/Interactable") as Interactable
	_check(red_interactable != null and not red_interactable.enabled, "Local player's assigned color is marked as taken")
	_check(orange_interactable != null and not orange_interactable.enabled, "Another player's color is disabled")
	var orange_key: MeshInstance3D = panel.get_node("ColorButtons/OrangeButton/Visuals/ButtonKey/KeyMesh") as MeshInstance3D
	var orange_material: StandardMaterial3D = orange_key.material_override as StandardMaterial3D
	_check(orange_material != null and orange_material.albedo_color.v < 0.5, "Taken color key mesh is visibly dimmed")

	controller.call("_on_button_activated", &"blue", 2, 5)
	var client_identity: PlayerIdentity = network.call("get_player_identity", 2) as PlayerIdentity
	_check(client_identity != null and client_identity.color_index == 5, "Physical color button assigns the requested free color")
	_check(orange_interactable.enabled, "The previous color becomes available after it is released")
	var blue_interactable: Interactable = panel.get_node("ColorButtons/BlueButton/Interactable") as Interactable
	_check(not blue_interactable.enabled, "The newly selected color becomes unavailable to other players")

	network.set("connected_peers", [1, 2, 3])
	_check(bool(network.call("_assign_player_identity", 3, "Late", 0)), "Late joiner receives an automatically selected free color")
	var late_identity: PlayerIdentity = network.call("get_player_identity", 3) as PlayerIdentity
	_check(late_identity != null and late_identity.color_index == 1, "Late joiner is moved to the next available color")
	_check(not orange_interactable.enabled, "Late joiner's color is marked as taken on the panel")

	panel.queue_free()
	await process_frame
	network.call("shutdown")
	if not _failed:
		print("PLAYER COLOR PANEL PASS")
	quit(1 if _failed else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("PLAYER COLOR PANEL FAIL: %s" % message)
