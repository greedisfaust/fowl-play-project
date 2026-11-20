extends CharacterBody3D

var is_local_player: bool = true

var terminal_movement_locked: bool = false

func set_terminal_movement_locked(locked: bool) -> void:
	terminal_movement_locked = locked
