## Minimal adapter lets the shared physical BettingKeypad work without a terminal screen.
extends Node

@export var profile: BettingTerminalProfile
var pending_wager_amount: int = 0


func set_pending_wager_amount(amount: int) -> void:
	pending_wager_amount = maxi(amount, 0)


func get_pending_wager_amount() -> int:
	return pending_wager_amount


func refresh_display() -> void:
	# Cluckpot presents wager and result information on the machine's own fascia.
	pass


func clear_network_snapshot() -> void:
	pass
