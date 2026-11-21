## Shared casino keypad controller.
## Runtime-attached by the table so editor-authored keypad scene content stays untouched.
class_name BettingKeypadController
extends Node

signal wager_confirmation_result(peer_id: int, result: Dictionary)

const MAX_WAGER_DIGITS: int = 19
const MAX_WAGER_AMOUNT: int = 9223372036854775807
const TABLE_STATE_IDLE: int = 0
const TABLE_STATE_OPEN: int = 1

@export var table: BaseTable
@export var display: Node
@export var profile: BettingTerminalProfile
@export var one_wager_per_player: bool = true

var _wallet: Node = null
var _network: Node = null
var _debug_hub: Node = null
var _debug_watch_prefix: String = ""
var _last_confirmation_status: String = "No wager confirmed yet."
var _pending_digits: String = "0"
var _snapshot_revision: int = 0
var _snapshot_request_sent: bool = false
var _connected_buttons: Array[Node] = []

func _ready() -> void:
	_wallet = get_node_or_null("/root/CasinoWallet")
	_network = get_node_or_null("/root/Network")
	_debug_hub = get_node_or_null("/root/DebugHub")
	if is_instance_valid(_debug_hub):
		var table_key: String = table.table_id if is_instance_valid(table) else str(name)
		_debug_watch_prefix = "casino_keypad/%s/" % table_key
		_debug_hub.call("watch", StringName(_debug_watch_prefix + "pending_amount"), func() -> int: return get_pending_wager_amount())
		_debug_hub.call("watch", StringName(_debug_watch_prefix + "snapshot_revision"), func() -> int: return _snapshot_revision)
		_debug_hub.call("watch", StringName(_debug_watch_prefix + "connected_buttons"), func() -> int: return _connected_buttons.size())
		_debug_hub.call("watch", StringName(_debug_watch_prefix + "last_confirmation"), func() -> String: return _last_confirmation_status)
	if profile == null and is_instance_valid(display):
		profile = display.get("profile") as BettingTerminalProfile
	if not is_instance_valid(table):
		push_warning("BettingKeypadController requires its BaseTable reference.")
	if profile == null:
		push_warning("BettingKeypadController requires a BettingTerminalProfile.")
	_connect_key_buttons()
	_connect_authority_signals()
	_apply_pending_amount()
	_try_request_snapshot()

func _exit_tree() -> void:
	for button: Node in _connected_buttons:
		if is_instance_valid(button) and button.is_connected("button_activated", _on_button_activated):
			button.disconnect("button_activated", _on_button_activated)
	_connected_buttons.clear()
	if is_instance_valid(_debug_hub) and not _debug_watch_prefix.is_empty():
		_debug_hub.call("unwatch", StringName(_debug_watch_prefix + "pending_amount"))
		_debug_hub.call("unwatch", StringName(_debug_watch_prefix + "snapshot_revision"))
		_debug_hub.call("unwatch", StringName(_debug_watch_prefix + "connected_buttons"))
		_debug_hub.call("unwatch", StringName(_debug_watch_prefix + "last_confirmation"))
	if is_instance_valid(table):
		_disconnect_table_signal(&"participants_changed", _on_participants_changed)
		_disconnect_table_signal(&"proximity_changed", _on_proximity_changed)
		_disconnect_table_signal(&"state_changed", _on_state_changed)
		_disconnect_table_signal(&"round_opened", _on_round_opened)
		_disconnect_table_signal(&"round_started", _on_round_started)
		_disconnect_table_signal(&"round_settled", _on_round_settled)
		_disconnect_table_signal(&"round_cancelled", _on_round_cancelled)
	if is_instance_valid(_wallet) and _wallet.has_signal("wallet_changed") and _wallet.is_connected("wallet_changed", _on_wallet_changed):
		_wallet.disconnect("wallet_changed", _on_wallet_changed)
	if is_instance_valid(_network) and _network.has_signal("session_ended") and _network.is_connected("session_ended", _on_session_ended):
		_network.disconnect("session_ended", _on_session_ended)
	if is_instance_valid(_network) and _network.has_signal("roster_changed") and _network.is_connected("roster_changed", _on_roster_changed):
		_network.disconnect("roster_changed", _on_roster_changed)

## Public entry point used by physical TerminalButton instances and headless tests.
func handle_button_input(button_id: StringName, peer_id: int) -> Dictionary:
	if not multiplayer.is_server():
		return _failure("Only the host processes keypad actions.")
	if peer_id <= 0:
		return _failure("The interacting player's peer ID is invalid.")
	var action: String = _normalize_button_id(String(button_id))
	if action.length() == 1 and action.is_valid_int():
		if _pending_digits.length() >= MAX_WAGER_DIGITS:
			return _failure("The wager amount has reached the maximum supported digits.")
		var next_amount: int = int(_pending_digits) * 10 + int(action)
		if next_amount > MAX_WAGER_AMOUNT:
			return _failure("The wager amount exceeds the supported 64-bit wallet limit.")
		if _pending_digits == "0":
			_pending_digits = action
		else:
			_pending_digits += action
		_publish_snapshot()
		return _success({"pending_amount": get_pending_wager_amount()})
	match action:
		"CLEAR", "CLR", "RESET", "C":
			_pending_digits = "0"
			_publish_snapshot()
			return _success({"pending_amount": 0})
		"BACKSPACE", "BACK", "DELETE", "DEL", "BKSP", "←", "⌫":
			_pending_digits = _pending_digits.left(_pending_digits.length() - 1) if _pending_digits.length() > 1 else "0"
			_publish_snapshot()
			return _success({"pending_amount": get_pending_wager_amount()})
		"CONFIRM", "ENTER", "OK", "SUBMIT":
			return _confirm_pending_wager(peer_id)
		_:
			return _failure("Unknown keypad button ID '%s'." % action)

func get_pending_wager_amount() -> int:
	return int(_pending_digits) if _pending_digits.is_valid_int() else 0

func get_pending_digits() -> String:
	return _pending_digits

func _normalize_button_id(raw_id: String) -> String:
	var normalized: String = raw_id.strip_edges().to_upper().replace(" ", "_").replace("-", "_")
	for prefix: String in ["KEYPAD_", "NUMPAD_", "NUMBER_", "DIGIT_", "NUM_", "KEY_"]:
		if normalized.begins_with(prefix):
			normalized = normalized.trim_prefix(prefix)
			break
	return normalized

func _confirm_pending_wager(peer_id: int) -> Dictionary:
	if not is_instance_valid(table):
		return _failure("The betting table is unavailable.")
	var amount: int = get_pending_wager_amount()
	var minimum_value: int = profile.get_effective_minimum() if profile != null else 1
	var maximum_value: int = profile.get_effective_maximum() if profile != null else 2147483647
	if amount < minimum_value or amount > maximum_value:
		return _failure("Wager must be between %d and %d." % [minimum_value, maximum_value])
	if not is_instance_valid(_wallet) or not _wallet.has_method("get_snapshot"):
		return _failure("The shared wallet is unavailable.")
	var wallet_snapshot: Dictionary = _wallet.call("get_snapshot")
	if amount > int(wallet_snapshot.get("available_balance", 0)):
		return _failure("Insufficient available shared funds.")

	# Chicken Cross accepts one active wager per participant. Keep this option
	# configurable so other games can use the same terminal with multiple wagers.
	if one_wager_per_player:
		for wager: Dictionary in table.get_round_wagers():
			var status: String = str(wager.get("status", ""))
			if int(wager.get("peer_id", 0)) == peer_id and (status == "reserved" or status == "locked"):
				return _failure("You already have a confirmed wager in this round.")

	var table_state: int = int(table.get("state"))
	if table_state == TABLE_STATE_IDLE:
		var open_result: Dictionary = table.open_round(peer_id)
		if not bool(open_result.get("ok", false)):
			return open_result
	elif table_state != TABLE_STATE_OPEN:
		return _failure("This table is not accepting wagers right now.")

	var join_result: Dictionary = table.join_table(peer_id)
	if not bool(join_result.get("ok", false)):
		return join_result
	var wager_result: Dictionary = table.place_wager(peer_id, amount, {"source": "betting_keypad"})
	if not bool(wager_result.get("ok", false)):
		_last_confirmation_status = "Rejected: %s" % str(wager_result.get("reason", "unknown error"))
		return wager_result

	_last_confirmation_status = "Peer %d confirmed %d." % [peer_id, amount]
	_pending_digits = "0"
	_publish_snapshot()
	wager_confirmation_result.emit(peer_id, wager_result.duplicate(true))
	return wager_result

func _connect_key_buttons() -> void:
	if get_parent() == null:
		return
	_connect_key_buttons_recursive(get_parent())

func _connect_key_buttons_recursive(parent_node: Node) -> void:
	for child: Node in parent_node.get_children():
		if child.has_signal("button_activated") and not child.is_connected("button_activated", _on_button_activated):
			child.connect("button_activated", _on_button_activated)
			_connected_buttons.append(child)
		_connect_key_buttons_recursive(child)

func _on_button_activated(button_id: StringName, peer_id: int) -> void:
	handle_button_input(button_id, peer_id)

func _connect_authority_signals() -> void:
	if is_instance_valid(table):
		_connect_table_signal(&"participants_changed", _on_participants_changed)
		_connect_table_signal(&"proximity_changed", _on_proximity_changed)
		_connect_table_signal(&"state_changed", _on_state_changed)
		_connect_table_signal(&"round_opened", _on_round_opened)
		_connect_table_signal(&"round_started", _on_round_started)
		_connect_table_signal(&"round_settled", _on_round_settled)
		_connect_table_signal(&"round_cancelled", _on_round_cancelled)
	if is_instance_valid(_wallet) and _wallet.has_signal("wallet_changed"):
		_wallet.connect("wallet_changed", _on_wallet_changed)
	if is_instance_valid(_network) and _network.has_signal("session_ended"):
		_network.connect("session_ended", _on_session_ended)
	if is_instance_valid(_network) and _network.has_signal("roster_changed"):
		_network.connect("roster_changed", _on_roster_changed)

func _connect_table_signal(signal_name: StringName, callback: Callable) -> void:
	if table.has_signal(signal_name) and not table.is_connected(signal_name, callback):
		table.connect(signal_name, callback)

func _disconnect_table_signal(signal_name: StringName, callback: Callable) -> void:
	if table.has_signal(signal_name) and table.is_connected(signal_name, callback):
		table.disconnect(signal_name, callback)

func _on_participants_changed(_participants: Array[Dictionary]) -> void:
	_publish_snapshot()

func _on_proximity_changed(_nearby_peer_ids: Array[int]) -> void:
	_publish_snapshot()

func _on_state_changed(_previous_state: int, _new_state: int) -> void:
	_publish_snapshot()

func _on_round_opened(_table_id: String, _round_id: String) -> void:
	_publish_snapshot()

func _on_round_started(_table_id: String, _round_id: String) -> void:
	_publish_snapshot()

func _on_round_settled(_table_id: String, _round_id: String, _settlement: Dictionary) -> void:
	_publish_snapshot()

func _on_round_cancelled(_table_id: String, _round_id: String, _refund_total: int) -> void:
	_publish_snapshot()

func _on_wallet_changed(_available_balance: int, _reserved_total: int) -> void:
	_publish_snapshot()

func _on_session_ended() -> void:
	_pending_digits = "0"
	_snapshot_revision = 0
	_snapshot_request_sent = false
	if is_instance_valid(display):
		display.call("clear_network_snapshot")
		_apply_pending_amount()

func _on_roster_changed() -> void:
	_try_request_snapshot()

func _try_request_snapshot() -> void:
	if _snapshot_request_sent or not _is_network_client():
		return
	var network_peer: MultiplayerPeer = _network.get("peer") as MultiplayerPeer
	if network_peer == null or network_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	_snapshot_request_sent = true
	_request_snapshot.rpc_id(1)

func _publish_snapshot() -> void:
	_snapshot_revision += 1
	_apply_pending_amount()
	if not multiplayer.is_server() or not _is_network_session_active():
		return
	var participants: Array[Dictionary] = table.get_participants() if is_instance_valid(table) else []
	var wagers: Array[Dictionary] = table.get_round_wagers() if is_instance_valid(table) else []
	var available_balance: int = 0
	if is_instance_valid(_wallet):
		var wallet_snapshot: Dictionary = _wallet.call("get_snapshot")
		available_balance = int(wallet_snapshot.get("available_balance", 0))
	var nearby_peer_ids: Array[int] = table.get_nearby_peer_ids() if is_instance_valid(table) else []
	_sync_snapshot.rpc(get_pending_wager_amount(), _snapshot_revision, participants, wagers, available_balance, nearby_peer_ids)

func _apply_pending_amount() -> void:
	if is_instance_valid(display) and display.has_method("set_pending_wager_amount"):
		display.call("set_pending_wager_amount", get_pending_wager_amount())

func _is_network_session_active() -> bool:
	return is_instance_valid(_network) and _network.get("peer") != null

func _is_network_client() -> bool:
	return _is_network_session_active() and not multiplayer.is_server()

@rpc("authority", "call_remote", "reliable", 0)
func _sync_snapshot(amount: int, revision: int, participants: Array[Dictionary], wagers: Array[Dictionary], available_balance: int, nearby_peer_ids: Array[int]) -> void:
	if not is_instance_valid(_network) or not bool(_network.call("validate_rpc", 1)):
		return
	if revision < _snapshot_revision:
		return
	_snapshot_revision = revision
	_pending_digits = str(maxi(amount, 0))
	_apply_pending_amount()
	if is_instance_valid(display) and display.has_method("set_network_snapshot"):
		display.call("set_network_snapshot", participants, wagers, available_balance, nearby_peer_ids)

@rpc("any_peer", "call_remote", "reliable", 0)
func _request_snapshot() -> void:
	if not multiplayer.is_server() or not is_instance_valid(_network) or not bool(_network.call("validate_rpc")):
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	var participants: Array[Dictionary] = table.get_participants() if is_instance_valid(table) else []
	var wagers: Array[Dictionary] = table.get_round_wagers() if is_instance_valid(table) else []
	var available_balance: int = 0
	if is_instance_valid(_wallet):
		var wallet_snapshot: Dictionary = _wallet.call("get_snapshot")
		available_balance = int(wallet_snapshot.get("available_balance", 0))
	var nearby_peer_ids: Array[int] = table.get_nearby_peer_ids() if is_instance_valid(table) else []
	_sync_snapshot.rpc_id(sender_id, get_pending_wager_amount(), _snapshot_revision, participants, wagers, available_balance, nearby_peer_ids)

func _success(data: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"ok": true, "reason": ""}
	result.merge(data, true)
	return result

func _failure(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
