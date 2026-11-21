## Inspector-editable copy, limits, and visual identity for a reusable casino betting terminal.
## Assign one profile per table/terminal. This resource never performs wallet mutations.
class_name BettingTerminalProfile
extends Resource

@export_group("Game Identity")
@export var game_title: String = "CASINO GAME"
@export_multiline var game_description: String = "PLACE YOUR WAGER TO JOIN THE ROUND."

@export_group("Display Copy")
@export var pending_heading: String = "UNCONFIRMED WAGER"
@export var player_list_heading: String = "PLAYER WAGERS"
@export var minimum_label: String = "MINIMUM"
@export var maximum_label: String = "MAXIMUM"
@export var valid_message: String = "VALID WAGER"
@export var invalid_message: String = "INVALID WAGER"
@export var insufficient_funds_message: String = "INSUFFICIENT SHARED FUNDS"
@export var no_wagers_message: String = "AWAITING CONFIRMED WAGERS"
@export var player_count_format: String = "%d / %d PLAYERS"
@export var total_reserved_label: String = "TOTAL RESERVED"
@export var currency_symbol: String = "$"
@export var empty_amount_text: String = "0"

@export_group("Wager Limits")
@export_range(1, 9223372036854775807, 1) var minimum_wager: int = 100
@export_range(1, 9223372036854775807, 1) var maximum_wager: int = 5000

@export_group("Terminal Display Colors")
@export var valid_color: Color = Color(0.28, 0.88, 0.48, 1.0)
@export var invalid_color: Color = Color(1.0, 0.25, 0.22, 1.0)
@export var accent_color: Color = Color(0.85, 0.71, 0.36, 1.0)
@export var body_color: Color = Color(0.92, 0.94, 0.98, 1.0)

@export_group("Layout")
@export_range(12, 48, 1) var left_column_width: int = 30
@export_range(12, 64, 1) var right_column_width: int = 42
@export_range(1, 8, 1) var list_rows: int = 6

func get_effective_minimum() -> int:
	return maxi(minimum_wager, 1)

func get_effective_maximum() -> int:
	return maxi(maximum_wager, get_effective_minimum())
