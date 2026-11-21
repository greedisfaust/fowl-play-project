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
	refresh_display()

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

## Rebuilds the terminal readout from the current table/wallet snapshot.
func refresh_display() -> void:
	if not is_instance_valid(screen_text) or profile == null:
		return
	screen_text.clear_screen()
	# The two-column format is a fixed-width line. Fit its font to the actual
	# ScreenText width before appending content (30 + 42 columns + separator).
	screen_text.fit_font_size_to_columns(maxi(profile.left_column_width, 12) + maxi(profile.right_column_width, 12) + 3)
	var previous_body_color: Color = screen_text.body_color
	screen_text.header_color = profile.accent_color
	screen_text.body_color = profile.body_color
	screen_text.prompt_color = profile.accent_color
	screen_text.append_header(_center_text(profile.game_title, profile.left_column_width + profile.right_column_width + 3))
	if not profile.game_description.is_empty():
		screen_text.append_paragraph(profile.game_description)
	screen_text.append_paragraph("")
	var left_heading: String = profile.pending_heading
	var right_heading: String = profile.player_list_heading
	screen_text.append_header(_two_columns(left_heading, right_heading))
	screen_text.append_paragraph(_two_columns("----------------", "--------------------------------"))
	_render_pending_column()
	_render_player_wagers()
	screen_text.body_color = previous_body_color
	display_refreshed.emit()

func _render_pending_column() -> void:
	var minimum_value: int = profile.get_effective_minimum()
	var maximum_value: int = profile.get_effective_maximum()
	var available_balance: int = _get_available_balance()
	var valid: bool = _pending_wager_amount >= minimum_value and _pending_wager_amount <= maximum_value and _pending_wager_amount <= available_balance
	var status_text: String = profile.valid_message if valid else profile.invalid_message
	if _pending_wager_amount > available_balance and _pending_wager_amount > 0:
		status_text = profile.insufficient_funds_message
	screen_text.append_paragraph(_two_columns(_format_money(_pending_wager_amount), ""))
	var status_color: Color = profile.valid_color if valid else profile.invalid_color
	screen_text.body_color = status_color
	screen_text.append_paragraph(_two_columns(status_text, ""))
	screen_text.body_color = profile.body_color
	screen_text.append_paragraph(_two_columns("%s: %s" % [profile.minimum_label, _format_money(minimum_value)], ""))
	screen_text.append_paragraph(_two_columns("%s: %s" % [profile.maximum_label, _format_money(maximum_value)], ""))
	screen_text.append_paragraph(_two_columns("", ""))
	screen_text.append_paragraph(_two_columns("", ""))
	screen_text.append_paragraph(_two_columns("", ""))

func _render_player_wagers() -> void:
	var participants: Array[Dictionary] = []
	var wagers: Array[Dictionary] = []
	if is_instance_valid(table):
		participants = table.get_participants()
		wagers = table.get_round_wagers()
	var capacity: int = table.max_participants if is_instance_valid(table) else 0
	var right_width: int = maxi(profile.right_column_width, 12)
	var player_count: String = profile.player_count_format % [participants.size(), capacity]
	screen_text.append_header(_two_columns("", player_count))
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
		screen_text.append_paragraph(_two_columns("", profile.no_wagers_message))
	else:
		var visible_count: int = mini(peer_ids.size(), profile.list_rows)
		for index: int in range(visible_count):
			var peer_id: int = int(peer_ids[index])
			var player_label: String = _get_player_label(peer_id)
			var amount_label: String = _format_money(int(totals_by_peer[peer_id]))
			screen_text.append_paragraph(_two_columns("", "%s — %s" % [player_label, amount_label]))
		if peer_ids.size() > visible_count:
			screen_text.append_paragraph(_two_columns("", "+ %d MORE" % (peer_ids.size() - visible_count)))
	screen_text.append_paragraph(_two_columns("", ""))
	screen_text.append_header(_two_columns("", "%s: %s" % [profile.total_reserved_label, _format_money(total_reserved)]))

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
	var left_value: String = left_text.left(left_width)
	var padding: int = maxi(left_width - left_value.length(), 1)
	return left_value + " ".repeat(padding) + " | " + right_text

func _center_text(value: String, width: int) -> String:
	var safe_width: int = maxi(width, value.length())
	var left_padding: int = maxi((safe_width - value.length()) / 2, 0)
	return " ".repeat(left_padding) + value

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
