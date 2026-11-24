## Large, high-contrast cabinet readout for Cluckpot's keypad wager and spin result.
extends Node

@export var profile: BettingTerminalProfile
@export var table: BaseTable
@export var screen: WorldScreen

var pending_wager_amount: int = 0
var _status_header: String = "READY"
var _status_detail: String = ""
var _status_valid: bool = false


func set_pending_wager_amount(amount: int) -> void:
	pending_wager_amount = maxi(amount, 0)
	_status_header = "WAGER CHECK"
	_status_detail = ""
	var limits: Dictionary = _get_limits()
	_status_valid = pending_wager_amount > 0 and pending_wager_amount >= int(limits.get("minimum", 0)) and pending_wager_amount <= int(limits.get("maximum", 0))
	refresh_display()


func get_pending_wager_amount() -> int:
	return pending_wager_amount


func set_status(header: String, detail: String = "", valid: bool = false) -> void:
	_status_header = header
	_status_detail = detail
	_status_valid = valid
	refresh_display()


func refresh_display() -> void:
	if not is_instance_valid(screen):
		return
	var screen_text: ScreenText = screen.get_screen_text()
	if screen_text == null:
		return
	var limits: Dictionary = _get_limits()
	var minimum: int = int(limits.get("minimum", profile.get_effective_minimum() if profile != null else 0))
	var maximum: int = int(limits.get("maximum", profile.get_effective_maximum() if profile != null else 0))
	var wager_valid: bool = pending_wager_amount > 0 and pending_wager_amount >= minimum and pending_wager_amount <= maximum
	var header: String = _status_header
	var detail: String = _status_detail
	var state_color: String = "#54e58b" if _status_valid else "#ff525c"
	var title_color: String = "#e7d5ad"
	screen_text.clear_screen()
	screen_text.scroll_active = false
	screen_text.scroll_following = false
	if header == "READY" or header == "WAGER CHECK" or header == "WAGER SELECTED":
		header = "CLUCKPOT"
		state_color = "#54e58b" if wager_valid else "#ff525c"
		screen_text.append_text("[center][color=%s][font_size=62][b]CLUCKPOT[/b][/font_size][/color][/center]\n" % title_color)
		screen_text.append_text("[center][color=#f4eee2][font_size=54]MIN  $%s     MAX  $%s[/font_size][/color][/center]\n" % [_format_money(minimum), _format_money(maximum)])
		var wager_text: String = _format_money(pending_wager_amount) if pending_wager_amount > 0 else "--"
		screen_text.append_text("[center][color=%s][font_size=112][b]WAGER  $%s[/b][/font_size][/color][/center]\n" % [state_color, wager_text])
		screen_text.append_text("[center][color=%s][font_size=42][b]%s[/b][/font_size][/color]" % [state_color, "VALID WAGER" if wager_valid else "INVALID / SET WAGER"])
		return
	screen_text.append_text("[center][color=%s][font_size=68][b]%s[/b][/font_size][/color][/center]\n" % [title_color, _escape(header)])
	if not detail.is_empty():
		var detail_lines: PackedStringArray = detail.split("\n")
		for line: String in detail_lines:
			var safe_line: String = _escape(line)
			var line_color: String = state_color if header.begins_with("WIN") or header.begins_with("GOLDEN") else "#f4eee2"
			var font_size: int = 68 if line.begins_with("WAGER") or line.begins_with("STAKE") else 58
			screen_text.append_text("[center][color=%s][font_size=%d][b]%s[/b][/font_size][/color][/center]\n" % [line_color, font_size, safe_line])


func clear_network_snapshot() -> void:
	pending_wager_amount = 0
	_status_header = "READY"
	_status_detail = ""
	_status_valid = false
	refresh_display()


func _get_limits() -> Dictionary:
	if is_instance_valid(table):
		return table.get_wager_limits()
	return {}


func _format_money(amount: int) -> String:
	var digits: String = str(maxi(amount, 0))
	var result: String = ""
	for index: int in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			result += ","
		result += digits.substr(index, 1)
	return result


func _escape(value: String) -> String:
	return value.replace("[", "[lb]").replace("]", "[rb]")
