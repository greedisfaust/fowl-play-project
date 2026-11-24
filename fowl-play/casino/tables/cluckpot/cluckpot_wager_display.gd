## Minimal adapter lets the shared physical BettingKeypad work without a terminal screen.
extends Node

@export var profile: BettingTerminalProfile
@export var amount_label: MeshInstance3D
var pending_wager_amount: int = 0


func set_pending_wager_amount(amount: int) -> void:
	pending_wager_amount = maxi(amount, 0)
	if is_instance_valid(amount_label):
		var source: TextMesh = amount_label.mesh as TextMesh
		if source != null:
			var copy: TextMesh = source.duplicate() as TextMesh
			copy.text = "$" + _format_money(pending_wager_amount)
			amount_label.mesh = copy


func get_pending_wager_amount() -> int:
	return pending_wager_amount


func _format_money(amount: int) -> String:
	var digits: String = str(maxi(amount, 0))
	var result: String = ""
	for index: int in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			result += ","
		result += digits.substr(index, 1)
	return result


func refresh_display() -> void:
	# Cluckpot presents wager and result information on the machine's own fascia.
	pass


func clear_network_snapshot() -> void:
	pass
