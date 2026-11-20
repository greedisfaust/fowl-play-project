## Contract checks for identity-driven world nameplates.
extends SceneTree

const PlayerIdentity = preload("res://core/player_identity.gd")
const PlayerNameplate = preload("res://player/player_nameplate.gd")

var _failed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var plate: Label3D = PlayerNameplate.new() as Label3D
	root.add_child(plate)
	await process_frame
	var identity: PlayerIdentity = PlayerIdentity.new(2, "Soldatos", 5)
	plate.call("apply_player_identity", identity, false)
	_check(plate.text == "Soldatos", "Nameplate displays nickname only, without peer ID")
	_check(plate.modulate.is_equal_approx(identity.get_color()), "Nameplate accent tint uses assigned identity color")
	_check(plate.visible, "Remote player nameplate is visible")
	_check(plate.billboard == BaseMaterial3D.BILLBOARD_ENABLED, "Nameplate faces the viewing camera")
	plate.call("apply_player_identity", identity, true)
	_check(not plate.visible, "Local player's own nameplate is hidden")
	plate.call("apply_player_identity", null, false)
	_check(not plate.visible and plate.text.is_empty(), "Missing/disconnected identity hides and clears nameplate")
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
