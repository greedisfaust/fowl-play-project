## Reusable, network-safe player identity data.
## The color is represented on the wire by a palette index, never an arbitrary client Color.
class_name PlayerIdentity
extends RefCounted

const MAX_NICKNAME_LENGTH: int = 16

var peer_id: int = 0
var nickname: String = "Chicken"
var color_index: int = 0

func _init(owner_peer_id: int = 0, player_nickname: String = "Chicken", assigned_color_index: int = 0) -> void:
	peer_id = owner_peer_id
	nickname = player_nickname
	color_index = assigned_color_index

static func palette_size() -> int:
	return 10

static func color_name_for_index(index: int) -> String:
	match index:
		0: return "Red"
		1: return "Orange"
		2: return "Yellow"
		3: return "Green"
		4: return "Cyan"
		5: return "Blue"
		6: return "Purple"
		7: return "Pink"
		8: return "Black"
		9: return "White"
	return "Unknown"

static func color_for_index(index: int) -> Color:
	match index:
		0: return Color("#ef5350")
		1: return Color("#ff9800")
		2: return Color("#fdd835")
		3: return Color("#66bb6a")
		4: return Color("#26c6da")
		5: return Color("#42a5f5")
		6: return Color("#ab7ae8")
		7: return Color("#ec407a")
		8: return Color("#42464d")
		9: return Color("#f5f5f5")
	return Color.WHITE

func get_color() -> Color:
	return color_for_index(color_index)

func get_color_name() -> String:
	return color_name_for_index(color_index)

func get_display_label() -> String:
	return "%s (#%d)" % [nickname, peer_id]

func to_network_data() -> Dictionary:
	return {
		"peer_id": peer_id,
		"nickname": nickname,
		"color_index": color_index,
	}
