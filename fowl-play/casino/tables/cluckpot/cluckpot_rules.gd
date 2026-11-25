## Pure slot outcome and payout rules for Cluckpot.
class_name CluckpotRules
extends RefCounted

const SYMBOLS: Array[String] = ["SEVEN", "WILD", "ROOSTER", "CHICK", "EGG", "CORN", "WINGS"]
const SYMBOL_WEIGHTS: Array[int] = [4, 8, 10, 13, 16, 21, 28]
const PAYOUTS: Dictionary = {
	# Single center-line paytable: 4.5x the previous line values to compensate
	# for removing four paylines while targeting a roughly 91.7% theoretical return.
	"SEVEN": 126.0,
	"WILD": 63.0,
	"ROOSTER": 31.5,
	"CHICK": 14.4,
	"EGG": 9.9,
	"CORN": 5.85,
	"WINGS": 3.6,
}
const PAYLINES: Array[Array] = [
	[1, 1, 1], # single front-facing center line
]


static func roll_outcome(rng: RandomNumberGenerator) -> Dictionary:
	var columns: Array = []
	for reel_index: int in range(3):
		var column: Array[String] = []
		for row_index: int in range(3):
			column.append(_roll_symbol(rng))
		columns.append(column)
	var wins: Array[Dictionary] = evaluate_lines(columns)
	return {"symbols": columns, "line_wins": wins}


static func _roll_symbol(rng: RandomNumberGenerator) -> String:
	var total_weight: int = 0
	for weight: int in SYMBOL_WEIGHTS:
		total_weight += weight
	var roll: int = rng.randi_range(1, total_weight)
	for index: int in range(SYMBOLS.size()):
		roll -= SYMBOL_WEIGHTS[index]
		if roll <= 0:
			return SYMBOLS[index]
	return "WINGS"


static func evaluate_lines(columns: Array) -> Array[Dictionary]:
	var wins: Array[Dictionary] = []
	if columns.size() != 3:
		return wins
	for line_index: int in range(PAYLINES.size()):
		var line: Array = PAYLINES[line_index]
		var symbols: Array[String] = []
		for reel_index: int in range(3):
			var column: Array = columns[reel_index]
			symbols.append(str(column[int(line[reel_index])]))
		var matched: String = _resolve_match(symbols)
		if matched.is_empty():
			continue
		wins.append({
			"line": line_index,
			"symbol": matched,
			"multiplier": float(PAYOUTS[matched]),
		})
	return wins


static func _resolve_match(symbols: Array[String]) -> String:
	if symbols.size() != 3:
		return ""
	var chosen: String = ""
	for symbol: String in symbols:
		if symbol != "WILD":
			if chosen.is_empty():
				chosen = symbol
			elif symbol != chosen:
				return ""
	if chosen.is_empty():
		return "WILD"
	return chosen


static func calculate_payout(stake: int, outcome: Dictionary) -> int:
	if stake <= 0:
		return 0
	var total: int = 0
	for win: Dictionary in outcome.get("line_wins", []):
		total += floori(float(stake) * float(win.get("multiplier", 0.0)))
	return total


static func get_symbol_display(symbol: String) -> String:
	match symbol:
		"SEVEN": return "7"
		"WILD": return "GOLDEN CHICKEN"
		"ROOSTER": return "CHICKEN"
		"CHICK": return "CHICK"
		"EGG": return "EGG"
		"CORN": return "CORN"
		"WINGS": return "WINGS"
	return "?"


static func get_symbol_color(symbol: String) -> Color:
	match symbol:
		"SEVEN": return Color(1.0, 0.72, 0.12, 1.0)
		"WILD": return Color(1.0, 0.86, 0.38, 1.0)
		"ROOSTER": return Color(0.9, 0.24, 0.13, 1.0)
		"CHICK": return Color(1.0, 0.82, 0.35, 1.0)
		"EGG": return Color(0.82, 0.91, 0.83, 1.0)
		"CORN": return Color(0.98, 0.76, 0.16, 1.0)
		"WINGS": return Color(0.78, 0.56, 0.34, 1.0)
	return Color.WHITE


static func format_money(amount: int) -> String:
	var digits: String = str(maxi(amount, 0))
	var result: String = ""
	for index: int in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			result += ","
		result += digits.substr(index, 1)
	return result
