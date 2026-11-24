## Adapter lets the shared physical BettingKeypad update Cluckpot's own WorldScreen.
extends Node

@export var profile: BettingTerminalProfile
@export var table: BaseTable
@export var screen: WorldScreen
var pending_wager_amount: int = 0


func set_pending_wager_amount(amount: int) -> void:
	pending_wager_amount = maxi(amount, 0)
	refresh_display()


func get_pending_wager_amount() -> int:
	return pending_wager_amount


func refresh_display() -> void:
	if not is_instance_valid(screen):
		return
	var limits: Dictionary = {}
	if is_instance_valid(table):
		limits = table.get_wager_limits()
	var minimum: int = int(limits.get("minimum", profile.get_effective_minimum() if profile != null else 0))
	var maximum: int = int(limits.get("maximum", profile.get_effective_maximum() if profile != null else 0))
	var wager_text: String = "--" if pending_wager_amount <= 0 else "$" + _format_money(pending_wager_amount)
	var screen_text: ScreenText = screen.get_screen_text()
	if screen_text != null:
		screen_text.set_content(
			"CLUCKPOT",
			"MIN  $%s\nMAX  $%s\nWAGER  %s" % [_format_money(minimum), _format_money(maximum), wager_text],
			"CONFIRM TO SPIN"
		)


func clear_network_snapshot() -> void:
	pending_wager_amount = 0
	refresh_display()


func _format_money(amount: int) -> String:
	var digits: String = str(maxi(amount, 0))
	var result: String = ""
	for index: int in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			result += ","
		result += digits.substr(index, 1)
	return result
