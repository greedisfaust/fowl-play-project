## Presentation-only controller for the reusable two-column casino betting display.
## Attach to a terminal controller node and assign its BaseTable, ScreenText, and profile.
extends Node

signal display_refreshed

@export_group("References")
@export var table: BaseTable
@export var screen_text: ScreenText
@export var profile: BettingTerminalProfile

var _pending_wager_amount: int = 0
var _wallet: Node = null
var _network: Node = null

func _ready() -> void:
	_wallet = get_node_or_null("/root/CasinoWallet")
	_network = get_node_or_null("/root/Network")
	if not is_instance_valid(table):
		push_warning("BettingTerminalDisplay requires a BaseTable reference.")
	if not is_instance_valid(screen_text):
		push_warning("BettingTerminalDisplay requires a ScreenText reference.")
	if profile == null:
		push_warning("BettingTerminalDisplay requires a BettingTerminalProfile resource.")
	if is_instance_valid(table):
		_connect_table_signals()
	if is_instance_valid(_wallet):
		if _wallet.has_signal("wallet_changed"):
			_wallet.wallet_changed.connect(_on_wallet_changed)
		if _wallet.has_signal("wager_changed"):
			_wallet.wager_changed.connect(_on_wager_changed)
	if is_instance_valid(_network) and _network.has_signal("identity_roster_changed"):
		_network.identity_roster_changed.connect(refresh_display)
	# This controller is an earlier sibling than the nested WorldScreen in some
	# terminal scenes. Defer the first render until every ScreenText child has
	# completed _ready() and its BBCode/font setup.
	call_deferred("refresh_display")

func _exit_tree() -> void:
	_disconnect_table_signals()
	if is_instance_valid(_wallet):
		if _wallet.has_signal("wallet_changed") and _wallet.wallet_changed.is_connected(_on_wallet_changed):
			_wallet.wallet_changed.disconnect(_on_wallet_changed)
		if _wallet.has_signal("wager_changed") and _wallet.wager_changed.is_connected(_on_wager_changed):
			_wallet.wager_changed.disconnect(_on_wager_changed)
	if is_instance_valid(_network) and _network.has_signal("identity_roster_changed") and _network.identity_roster_changed.is_connected(refresh_display):
		_network.identity_roster_changed.disconnect(refresh_display)

## Called by the shared keypad controller whenever any player edits the shared amount.
func set_pending_wager_amount(amount: int) -> void:
	_pending_wager_amount = maxi(amount, 0)
	refresh_display()

func get_pending_wager_amount() -> int:
	return _pending_wager_amount

## Call after profile/context changes made at runtime.
func set_profile(next_profile: BettingTerminalProfile) -> void:
	profile = next_profile
	refresh_display()

## Rebuilds the readout as paired rows: each column owns a fixed character budget.
## The longest column determines row count; no blank-line positioning is used.
func refresh_display() -> void:
	if not is_instance_valid(screen_text) or profile == null:
		return

	screen_text.clear_screen()
	# This is a fixed physical readout, not a scrollable document. Following the
	# newest appended row would scroll the title and headings out of view.
	screen_text.scroll_active = false
	screen_text.scroll_following = false
	var left_width: int = maxi(profile.left_column_width, 12)
	var right_width: int = maxi(profile.right_column_width, 12)
	var total_width: int = left_width + right_width + 3

	screen_text.header_color = profile.accent_color
	screen_text.body_color = profile.body_color
	screen_text.prompt_color = profile.accent_color
	# Keep the game identity in a dedicated, full-width header area.
	# The title stays large/bold and left-aligned; the description is capped at
	# two wrapped lines so it can never consume the betting columns' space.
	screen_text.append_header(_fit_text(profile.game_title, total_width))
	for description_line: String in _build_description_lines(profile.game_description, total_width, 2):
		screen_text.append_paragraph(description_line)
	screen_text.append_paragraph("-".repeat(mini(total_width, 64)))

	# The two betting columns begin only after the complete header block.
	screen_text.append_header(_two_columns(profile.pending_heading, profile.player_list_heading))
	screen_text.append_paragraph(_two_columns("-".repeat(mini(left_width, 24)), "-".repeat(mini(right_width, 32))))

	var left_rows: Array[String] = _build_pending_rows()
	var right_rows: Array[String] = _build_player_rows()
	var row_count: int = maxi(left_rows.size(), right_rows.size() + 1)
	var available_balance: int = _get_available_balance()
	var minimum_value: int = profile.get_effective_minimum()
	var maximum_value: int = profile.get_effective_maximum()
	var valid: bool = _pending_wager_amount >= minimum_value and _pending_wager_amount <= maximum_value and _pending_wager_amount <= available_balance
	var amount_color: Color = profile.valid_color if valid else profile.invalid_color
	var amount_font_size: int = roundi(float(screen_text.terminal_font_size) * 1.45)
	for row_index: int in range(row_count):
		var left_value: String = left_rows[row_index] if row_index < left_rows.size() else ""
		# Give the enlarged pending amount its own row. The confirmed-wager column
		# starts on the following row so RichTextLabel's larger glyphs can never
		# push player text sideways or wrap it into another line.
		var right_index: int = row_index - 1
		var right_value: String = right_rows[right_index] if right_index >= 0 and right_index < right_rows.size() else ""
		var left_color: Color = profile.body_color
		var left_size: int = 0
		var center_left: bool = true
		if row_index == 0:
			left_color = amount_color
			left_size = amount_font_size
		elif row_index == 1:
			left_color = profile.valid_color if valid else profile.invalid_color
			if _pending_wager_amount > available_balance and _pending_wager_amount > 0:
				left_color = profile.invalid_color
		screen_text.append_text(_format_split_row(left_value, right_value, left_width, right_width, center_left, left_color, left_size))

	screen_text.body_color = profile.body_color
	screen_text.fit_font_size_to_columns(total_width)
	display_refreshed.emit()

func _build_pending_rows() -> Array[String]:
	var rows: Array[String] = []
	var minimum_value: int = profile.get_effective_minimum()
	var maximum_value: int = profile.get_effective_maximum()
	var available_balance: int = _get_available_balance()
	var valid: bool = _pending_wager_amount >= minimum_value and _pending_wager_amount <= maximum_value and _pending_wager_amount <= available_balance
	var status_text: String = profile.valid_message if valid else profile.invalid_message
	if _pending_wager_amount > available_balance and _pending_wager_amount > 0:
		status_text = profile.insufficient_funds_message
	rows.append(_format_compact_money(_pending_wager_amount))
	rows.append(status_text)
	rows.append("%s: %s" % [profile.minimum_label, _format_compact_money(minimum_value)])
	rows.append("%s: %s" % [profile.maximum_label, _format_compact_money(maximum_value)])
	return rows

func _build_player_rows() -> Array[String]:
	var rows: Array[String] = []
	var participants: Array[Dictionary] = []
	var wagers: Array[Dictionary] = []
	if is_instance_valid(table):
		participants = table.get_participants()
		wagers = table.get_round_wagers()
	var capacity: int = table.max_participants if is_instance_valid(table) else 0
	rows.append(profile.player_count_format % [participants.size(), capacity])

	var totals_by_peer: Dictionary = {}
	var total_reserved: int = 0
	for wager: Dictionary in wagers:
		var status: String = str(wager.get("status", ""))
		if status != "reserved" and status != "locked":
			continue
		var peer_id: int = int(wager.get("peer_id", 0))
		var stake: int = int(wager.get("stake", 0))
		if peer_id <= 0 or stake <= 0:
			continue
		totals_by_peer[peer_id] = int(totals_by_peer.get(peer_id, 0)) + stake
		total_reserved += stake

	var peer_ids: Array = totals_by_peer.keys()
	peer_ids.sort()
	if peer_ids.is_empty():
		rows.append(profile.no_wagers_message)
	else:
		var visible_count: int = mini(peer_ids.size(), profile.list_rows)
		for index: int in range(visible_count):
			var peer_id: int = int(peer_ids[index])
			rows.append("%s — %s" % [_get_player_label(peer_id), _format_money(int(totals_by_peer[peer_id]))])
		if peer_ids.size() > visible_count:
			rows.append("+ %d MORE" % (peer_ids.size() - visible_count))
	rows.append("%s: %s" % [profile.total_reserved_label, _format_money(total_reserved)])
	return rows

func _get_available_balance() -> int:
	if not is_instance_valid(_wallet) or not _wallet.has_method("get_snapshot"):
		return 0
	var snapshot: Dictionary = _wallet.call("get_snapshot")
	return int(snapshot.get("available_balance", 0))

func _get_player_label(peer_id: int) -> String:
	if is_instance_valid(_network):
		var identities_value: Variant = _network.get("player_identities")
		if typeof(identities_value) == TYPE_DICTIONARY:
			var identities: Dictionary = identities_value
			var identity_value: Variant = identities.get(peer_id)
			if identity_value is Object:
				var identity: Object = identity_value
				if identity.has_method("get_display_label"):
					return str(identity.call("get_display_label")).to_upper()
				var nickname_value: Variant = identity.get("nickname")
				if nickname_value != null and not str(nickname_value).is_empty():
					return str(nickname_value).to_upper()
	return "PLAYER %d" % peer_id

func _format_compact_money(amount: int) -> String:
	var absolute_amount: float = absf(float(amount))
	var compact_value: String = str(amount)
	if absolute_amount >= 1000000000.0:
		compact_value = _trim_decimal(absolute_amount / 1000000000.0) + "B"
	elif absolute_amount >= 1000000.0:
		compact_value = _trim_decimal(absolute_amount / 1000000.0) + "M"
	elif absolute_amount >= 1000.0:
		compact_value = _trim_decimal(absolute_amount / 1000.0) + "K"
	if amount < 0:
		compact_value = "-" + compact_value.trim_prefix("-")
	return compact_value + profile.currency_symbol


func _trim_decimal(value: float) -> String:
	var rounded_value: float = snappedf(value, 0.01)
	var result: String = "%.2f" % rounded_value
	while result.contains(".") and result.ends_with("0"):
		result = result.left(result.length() - 1)
	if result.ends_with("."):
		result = result.left(result.length() - 1)
	return result


func _format_split_row(left_text: String, right_text: String, left_width: int, right_width: int, center_left: bool, left_color: Color, left_font_size: int) -> String:
	var safe_left: String = _fit_text(left_text, left_width)
	var leading_padding: int = 0
	var trailing_padding: int = maxi(left_width - safe_left.length(), 0)
	if center_left:
		leading_padding = maxi(floori(float(left_width - safe_left.length()) / 2.0), 0)
		trailing_padding = maxi(left_width - safe_left.length() - leading_padding, 0)
	var right_value: String = _fit_text(right_text, right_width)
	var right_padding: String = " ".repeat(maxi(right_width - right_value.length(), 0))
	var color_hex: String = left_color.to_html(false)
	var left_markup: String = "[color=#%s]" % color_hex
	if left_font_size > 0:
		left_markup += "[font_size=%d]" % left_font_size
	left_markup += " ".repeat(leading_padding) + _escape_display_markup(safe_left)
	if left_font_size > 0:
		left_markup += "[/font_size]"
	left_markup += "[/color]"
	return left_markup + " ".repeat(trailing_padding) + " | " + right_padding + _escape_display_markup(right_value) + "\n"


func _escape_display_markup(value: String) -> String:
	return value.replace("[", "[lb]").replace("]", "[rb]")


func _format_money(amount: int) -> String:
	var absolute_digits: String = str(absi(amount))
	var grouped: String = ""
	for index: int in range(absolute_digits.length()):
		if index > 0 and (absolute_digits.length() - index) % 3 == 0:
			grouped += ","
		grouped += absolute_digits.substr(index, 1)
	var sign: String = "-" if amount < 0 else ""
	return "%s%s%s" % [sign, profile.currency_symbol, grouped]

func _two_columns(left_text: String, right_text: String) -> String:
	var left_width: int = maxi(profile.left_column_width, 12)
	var right_width: int = maxi(profile.right_column_width, 12)
	var left_value: String = _fit_text(left_text, left_width)
	var right_value: String = _fit_text(right_text, right_width)
	return left_value + " ".repeat(left_width - left_value.length()) + " | " + right_value

func _build_description_lines(value: String, width: int, maximum_lines: int) -> Array[String]:
	var lines: Array[String] = []
	if value.strip_edges().is_empty() or width <= 0 or maximum_lines <= 0:
		return lines

	var words: PackedStringArray = value.strip_edges().split(" ", false)
	var current_line: String = ""
	var word_index: int = 0
	while word_index < words.size():
		var word: String = words[word_index]
		if current_line.is_empty():
			current_line = word
		elif current_line.length() + word.length() + 1 <= width:
			current_line += " " + word
		else:
			lines.append(current_line)
			current_line = word
			if lines.size() >= maximum_lines:
				break
		word_index += 1

	if lines.size() < maximum_lines and not current_line.is_empty():
		lines.append(current_line)

	var all_words_consumed: bool = word_index >= words.size()
	if not all_words_consumed and not lines.is_empty():
		var last_line: String = lines[lines.size() - 1]
		lines[lines.size() - 1] = _fit_text(last_line, maxi(width - 1, 1)) + "…"

	# Also protect against unusually long unbroken words.
	for line_index: int in range(lines.size()):
		lines[line_index] = _fit_text(lines[line_index], width)
	return lines


func _fit_text(value: String, width: int) -> String:
	if width <= 0 or value.is_empty():
		return ""
	if value.length() <= width:
		return value
	if width <= 3:
		return value.left(width)
	return value.left(width - 1) + "…"


func _connect_table_signals() -> void:
	var callbacks: Array[Dictionary] = [
		{"signal_name": "participants_changed", "callback": Callable(self, "refresh_display")},
		{"signal_name": "state_changed", "callback": Callable(self, "refresh_display")},
		{"signal_name": "round_opened", "callback": Callable(self, "refresh_display")},
		{"signal_name": "round_started", "callback": Callable(self, "refresh_display")},
		{"signal_name": "round_settled", "callback": Callable(self, "refresh_display")},
		{"signal_name": "round_cancelled", "callback": Callable(self, "refresh_display")}
	]
	for item: Dictionary in callbacks:
		var signal_name: StringName = StringName(item["signal_name"])
		var callback: Callable = item["callback"]
		if table.has_signal(signal_name) and not table.is_connected(signal_name, callback):
			table.connect(signal_name, callback)

func _disconnect_table_signals() -> void:
	if not is_instance_valid(table):
		return
	var signal_names: Array[StringName] = [&"participants_changed", &"state_changed", &"round_opened", &"round_started", &"round_settled", &"round_cancelled"]
	for signal_name: StringName in signal_names:
		var callback: Callable = Callable(self, "refresh_display")
		if table.has_signal(signal_name) and table.is_connected(signal_name, callback):
			table.disconnect(signal_name, callback)

func _on_wallet_changed(_available_balance: int, _reserved_total: int) -> void:
	refresh_display()

func _on_wager_changed(_wager_id: String, _status: String) -> void:
	refresh_display()
