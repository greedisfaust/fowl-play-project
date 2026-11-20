## Billboard nameplate for a replicated PlayerIdentity.
## Attach to an editor-authored Label3D named NamePlate under the Player root.
extends Label3D

const PlayerIdentity = preload("res://core/player_identity.gd")

@export var outline_color: Color = Color(0.015, 0.02, 0.03, 0.95)
@export_range(0, 32, 1) var outline_thickness: int = 8
@export var hide_for_local_player: bool = true

func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	outline_modulate = outline_color
	outline_size = outline_thickness
	visible = false

func set_identity(identity: PlayerIdentity, is_local_player: bool) -> void:
	if identity == null:
		text = ""
		visible = false
		return
	text = identity.get_display_label()
	modulate = identity.get_color()
	visible = not (hide_for_local_player and is_local_player)

