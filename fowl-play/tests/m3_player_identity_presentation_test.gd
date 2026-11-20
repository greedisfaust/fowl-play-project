## Contract checks for SubViewport-based identity nameplates.
extends SceneTree

const PlayerIdentity = preload("res://core/player_identity.gd")
const PlayerNameplate = preload("res://player/player_nameplate.gd")

var _failed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var plate: Node3D = PlayerNameplate.new() as Node3D
	plate.name = "NamePlate"
	var panel_mesh: MeshInstance3D = MeshInstance3D.new()
	panel_mesh.name = "Panel"
	plate.add_child(panel_mesh)
	var viewport: SubViewport = SubViewport.new()
	viewport.name = "Display"
	plate.add_child(viewport)
	var ui: Control = Control.new()
	ui.name = "UI"
	viewport.add_child(ui)
	var background: Panel = Panel.new()
	background.name = "Background"
	ui.add_child(background)
	var accent: ColorRect = ColorRect.new()
	accent.name = "Accent"
	ui.add_child(accent)
	var nickname: Label = Label.new()
	nickname.name = "Nickname"
	ui.add_child(nickname)
	var divider: ColorRect = ColorRect.new()
	divider.name = "Divider"
	ui.add_child(divider)
	var status: Label = Label.new()
	status.name = "Status"
	ui.add_child(status)
	root.add_child(plate)
	await process_frame

	var identity: PlayerIdentity = PlayerIdentity.new(2, "Soldatos", 5)
	plate.call("apply_player_identity", identity, false)
	_check(nickname.text == "Soldatos", "Nameplate displays nickname only, without peer ID")
	_check(accent.color.is_equal_approx(identity.get_color()), "Nameplate accent uses assigned identity color")
	_check(plate.visible, "Remote player nameplate is visible")
	_check(viewport.size == Vector2i(512, 128), "Nameplate uses the configured high-resolution SubViewport")
	_check(viewport.transparent_bg, "Nameplate viewport background is transparent")
	_check(panel_mesh.mesh is QuadMesh, "Nameplate is displayed on a 3D quad")
	_check(panel_mesh.material_override is StandardMaterial3D, "Nameplate quad uses a 3D display material")
	plate.call("apply_player_identity", identity, true)
	_check(not plate.visible, "Local player's own nameplate is hidden")
	plate.call("apply_player_identity", null, false)
	_check(not plate.visible and nickname.text.is_empty(), "Missing/disconnected identity hides and clears nameplate")
	plate.free()
	if _failed:
		quit(1)
		return
	print("PLAYER IDENTITY PRESENTATION PASS")
	quit(0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("PLAYER IDENTITY PRESENTATION FAIL: %s" % message)
