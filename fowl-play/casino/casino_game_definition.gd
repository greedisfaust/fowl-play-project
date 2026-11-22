## Data contract for one selectable casino game type.
extends Resource
class_name CasinoGameDefinition

@export var game_id: StringName = &""
@export var display_name: String = ""
@export var table_scene: PackedScene
