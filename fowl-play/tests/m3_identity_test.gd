## Focused identity-core checks. Network authority is exercised through the host assignment path.
extends SceneTree

const PlayerIdentity = preload("res://core/player_identity.gd")

var _failed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var network: Node = root.get_node("Network")
	network.set("is_host", true)
	var connected_ids: Array[int] = [1, 2, 3, 4]
	network.set("connected_peers", connected_ids)
	network.set("player_identities", {})
	if not bool(network.call("_assign_player_identity", 1, "Chicken", 0)):
		_fail("Host identity assignment failed")
	if not bool(network.call("_assign_player_identity", 2, "Chicken", 0)):
		_fail("Duplicate nickname/color assignment failed")
	if not bool(network.call("_assign_player_identity", 3, "Chicken", 0)):
		_fail("Third duplicate identity assignment failed")
	if not bool(network.call("_assign_player_identity", 4, "  ", 0)):
		_fail("Blank nickname fallback failed")
	var host_identity: PlayerIdentity = network.call("get_player_identity", 1) as PlayerIdentity
	var second_identity: PlayerIdentity = network.call("get_player_identity", 2) as PlayerIdentity
	var third_identity: PlayerIdentity = network.call("get_player_identity", 3) as PlayerIdentity
	var fourth_identity: PlayerIdentity = network.call("get_player_identity", 4) as PlayerIdentity
	_check(host_identity != null and host_identity.peer_id == 1, "Peer ID remains the host identity key")
	_check(host_identity != null and host_identity.get_display_label() == "Chicken (#1)", "Display label format")
	_check(second_identity != null and second_identity.nickname == "Chicken 2", "Duplicate nickname gets numeric suffix")
	_check(third_identity != null and third_identity.nickname == "Chicken 3", "Third duplicate nickname gets numeric suffix")
	_check(fourth_identity != null and fourth_identity.nickname == "Chicken 4", "Blank nickname receives a safe fallback and duplicate suffix")
	_check(host_identity != null and host_identity.color_index == 0, "First requested color is honored")
	_check(second_identity != null and second_identity.color_index == 1, "Taken color falls forward to next available color")
	_check(third_identity != null and third_identity.color_index == 2, "Fallback skips all already assigned colors")
	_check(fourth_identity != null and fourth_identity.color_index == 3, "Color allocation remains unique")
	var seen_colors: Dictionary = {}
	for peer_id: int in [1, 2, 3, 4]:
		var identity: PlayerIdentity = network.call("get_player_identity", peer_id) as PlayerIdentity
		if identity != null:
			_check(not seen_colors.has(identity.color_index), "No duplicate lobby colors")
			seen_colors[identity.color_index] = true
	_check(not bool(network.call("_assign_player_identity", 5, "Intruder", 0)), "Inactive peer assignment rejected")
	_check(not bool(network.call("_assign_player_identity", 4, "Invalid", 99)), "Invalid palette index rejected")
	_check(PlayerIdentity.palette_size() == 10, "Ten identity colors are available")
	_check(PlayerIdentity.color_name_for_index(9) == "White", "Palette names are stable")
	if not _failed:
		print("IDENTITY CORE PASS")
	network.call("shutdown")
	quit(1 if _failed else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	_failed = true
	push_error("IDENTITY CORE FAIL: %s" % message)
