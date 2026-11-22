## Host-authoritative shared wallet and wager ledger.
## All mutations are synchronous and must be invoked by the multiplayer authority.
extends Node

signal wallet_changed(available_balance: int, reserved_total: int)
signal wager_changed(wager_id: String, status: String)
signal round_changed(table_id: String, round_id: String, status: String)

const STATUS_RESERVED: String = "reserved"
const STATUS_LOCKED: String = "locked"
const STATUS_SETTLED: String = "settled"
const STATUS_REFUNDED: String = "refunded"

const ROUND_OPEN: String = "open"
const ROUND_LOCKED: String = "locked"
const ROUND_SETTLED: String = "settled"
const ROUND_CANCELLED: String = "cancelled"

var _debug_hub: Node = null
var _run_active: bool = false
var _initial_balance: int = 0
var _available_balance: int = 0
var _next_wager_sequence: int = 1
var _wagers: Dictionary = {}
var _rounds: Dictionary = {}

func _ready() -> void:
	_debug_hub = get_node_or_null("/root/DebugHub")
	if _debug_hub == null:
		return
	_debug_hub.call("watch", &"casino_wallet/available_balance", func() -> int: return _available_balance)
	_debug_hub.call("watch", &"casino_wallet/reserved_total", func() -> int: return _get_reserved_total())
	_debug_hub.call("watch", &"casino_wallet/wager_count", func() -> int: return _wagers.size())
	_debug_hub.call("watch", &"casino_wallet/round_count", func() -> int: return _rounds.size())
	_debug_hub.call("command", &"casino_wallet_status", _debug_wallet_status, "Show the shared wallet balance and reserved funds.", true, false)
	_debug_hub.call("command", &"casino_wallet_wagers", _debug_wallet_wagers, "List wager IDs, bettors, stakes and statuses.", true, false)

func _exit_tree() -> void:
	if _debug_hub == null or not is_instance_valid(_debug_hub):
		return
	_debug_hub.call("unwatch", &"casino_wallet/available_balance")
	_debug_hub.call("unwatch", &"casino_wallet/reserved_total")
	_debug_hub.call("unwatch", &"casino_wallet/wager_count")
	_debug_hub.call("unwatch", &"casino_wallet/round_count")
	_debug_hub.call("unregister_command", &"casino_wallet_status")
	_debug_hub.call("unregister_command", &"casino_wallet_wagers")

## Starts a fresh run. Active reserved or locked wagers prevent resetting the ledger.
func begin_run(initial_balance: int) -> Dictionary:
	if not _is_authority():
		return _failure("Only the host can initialize the shared wallet.")
	if initial_balance < 0:
		return _failure("Initial balance cannot be negative.")
	if _has_unsettled_wagers():
		return _failure("Cannot reset the wallet while wagers are still active.")
	_initial_balance = initial_balance
	_available_balance = initial_balance
	_next_wager_sequence = 1
	_wagers.clear()
	_rounds.clear()
	_run_active = true
	_log_wallet("Run wallet initialized with %d." % initial_balance)
	_emit_wallet_changed()
	return _success({"initial_balance": _initial_balance, "available_balance": _available_balance})

## Clears the local ledger after the multiplayer session has ended.
## This intentionally discards outstanding wagers because the disconnected run cannot continue.
func reset_for_session_end() -> bool:
	var active_peer: MultiplayerPeer = multiplayer.multiplayer_peer
	if not active_peer is OfflineMultiplayerPeer:
		return false
	_run_active = false
	_initial_balance = 0
	_available_balance = 0
	_next_wager_sequence = 1
	_wagers.clear()
	_rounds.clear()
	_emit_wallet_changed()
	return true

## Opens a betting round. Round IDs must be unique within their table for the current run.
func open_round(table_id: String, round_id: String) -> Dictionary:
	if not _is_authority():
		return _failure("Only the host can open a betting round.")
	if not _run_active:
		return _failure("No active wallet run.")
	if not _valid_round_ids(table_id, round_id):
		return _failure("Table and round IDs must be non-empty and cannot contain '::'.")
	var key: String = _round_key(table_id, round_id)
	if _rounds.has(key):
		return _failure("This table round ID has already been used.")
	_rounds[key] = {"table_id": table_id, "round_id": round_id, "state": ROUND_OPEN, "wager_ids": []}
	round_changed.emit(table_id, round_id, ROUND_OPEN)
	_log_wallet("Opened round %s/%s." % [table_id, round_id])
	return _success({"table_id": table_id, "round_id": round_id, "state": ROUND_OPEN})

## Reserves stake immediately and creates a uniquely attributed wager record.
func reserve_wager(peer_id: int, table_id: String, round_id: String, amount: int, payload: Dictionary = {}) -> Dictionary:
	if not _is_authority():
		return _failure("Only the host can reserve a wager.")
	if peer_id <= 0:
		return _failure("Bettor peer ID must be positive.")
	if amount <= 0:
		return _failure("Wager amount must be greater than zero.")
	var round_data: Dictionary = _get_open_round(table_id, round_id)
	if round_data.is_empty():
		return _failure("The requested round is not open.")
	if amount > _available_balance:
		return _failure("Insufficient available shared funds.")
	_available_balance -= amount
	var wager_id: String = "W%08d" % _next_wager_sequence
	_next_wager_sequence += 1
	var wager: Dictionary = {
		"wager_id": wager_id,
		"peer_id": peer_id,
		"table_id": table_id,
		"round_id": round_id,
		"stake": amount,
		"payload": payload.duplicate(true),
		"status": STATUS_RESERVED,
		"return_amount": 0,
		"net_result": 0,
	}
	_wagers[wager_id] = wager
	var wager_ids: Array = round_data["wager_ids"]
	wager_ids.append(wager_id)
	round_data["wager_ids"] = wager_ids
	_rounds[_round_key(table_id, round_id)] = round_data
	wager_changed.emit(wager_id, STATUS_RESERVED)
	_log_wallet("Reserved %d for %s (peer %d)." % [amount, wager_id, peer_id])
	_emit_wallet_changed()
	return _success({"wager_id": wager_id, "available_balance": _available_balance})

## Edits an open wager. Only the difference is reserved or returned.
func update_wager(wager_id: String, amount: int, payload: Dictionary = {}) -> Dictionary:
	if not _is_authority():
		return _failure("Only the host can edit a wager.")
	if amount <= 0:
		return _failure("Wager amount must be greater than zero.")
	if not _wagers.has(wager_id):
		return _failure("Unknown wager ID.")
	var wager: Dictionary = _wagers[wager_id]
	if str(wager["status"]) != STATUS_RESERVED:
		return _failure("Only an unstarted reserved wager can be edited.")
	var round_data: Dictionary = _get_open_round(str(wager["table_id"]), str(wager["round_id"]))
	if round_data.is_empty():
		return _failure("The wager's round is no longer open.")
	var old_amount: int = int(wager["stake"])
	var difference: int = amount - old_amount
	if difference > _available_balance:
		return _failure("Insufficient available shared funds for the increase.")
	_available_balance -= difference
	wager["stake"] = amount
	wager["payload"] = payload.duplicate(true)
	_wagers[wager_id] = wager
	wager_changed.emit(wager_id, STATUS_RESERVED)
	_log_wallet("Updated %s from %d to %d." % [wager_id, old_amount, amount])
	_emit_wallet_changed()
	return _success({"wager_id": wager_id, "stake": amount, "available_balance": _available_balance})

## Withdraws an open wager and returns its entire reserved stake.
func withdraw_wager(wager_id: String) -> Dictionary:
	if not _is_authority():
		return _failure("Only the host can withdraw a wager.")
	if not _wagers.has(wager_id):
		return _failure("Unknown wager ID.")
	var wager: Dictionary = _wagers[wager_id]
	if str(wager["status"]) != STATUS_RESERVED:
		return _failure("Only an unstarted reserved wager can be withdrawn.")
	if _get_open_round(str(wager["table_id"]), str(wager["round_id"])).is_empty():
		return _failure("The wager's round is no longer open.")
	var amount: int = int(wager["stake"])
	_available_balance += amount
	wager["status"] = STATUS_REFUNDED
	wager["refund_reason"] = "manual_withdrawal"
	_wagers[wager_id] = wager
	wager_changed.emit(wager_id, STATUS_REFUNDED)
	_log_wallet("Withdrew %s and refunded %d." % [wager_id, amount])
	_emit_wallet_changed()
	return _success({"wager_id": wager_id, "refunded": amount, "available_balance": _available_balance})

## Locks every reserved wager in the round. A locked wager cannot be edited or withdrawn.
func lock_round(table_id: String, round_id: String) -> Dictionary:
	if not _is_authority():
		return _failure("Only the host can start a betting round.")
	var key: String = _round_key(table_id, round_id)
	if not _rounds.has(key):
		return _failure("Unknown table round.")
	var round_data: Dictionary = _rounds[key]
	if str(round_data["state"]) != ROUND_OPEN:
		return _failure("Only an open round can be locked.")
	var wager_ids: Array = round_data["wager_ids"]
	var locked_count: int = 0
	for wager_id_value: Variant in wager_ids:
		var wager_id: String = str(wager_id_value)
		var wager: Dictionary = _wagers[wager_id]
		if str(wager["status"]) == STATUS_RESERVED:
			wager["status"] = STATUS_LOCKED
			_wagers[wager_id] = wager
			wager_changed.emit(wager_id, STATUS_LOCKED)
			locked_count += 1
	if locked_count == 0:
		return _failure("Cannot start a round without at least one active wager.")
	round_data["state"] = ROUND_LOCKED
	_rounds[key] = round_data
	round_changed.emit(table_id, round_id, ROUND_LOCKED)
	_log_wallet("Locked %d wagers in %s/%s." % [locked_count, table_id, round_id])
	return _success({"locked_count": locked_count})

## Cancels an unstarted round and refunds every still-reserved wager in it.
func cancel_open_round(table_id: String, round_id: String) -> Dictionary:
	if not _is_authority():
		return _failure("Only the host can cancel a betting round.")
	var key: String = _round_key(table_id, round_id)
	if not _rounds.has(key):
		return _failure("Unknown table round.")
	var round_data: Dictionary = _rounds[key]
	if str(round_data["state"]) != ROUND_OPEN:
		return _failure("Only an open round can be cancelled and refunded.")
	var wager_ids: Array = round_data["wager_ids"]
	var refunded_total: int = 0
	for wager_id_value: Variant in wager_ids:
		var wager_id: String = str(wager_id_value)
		var wager: Dictionary = _wagers[wager_id]
		if str(wager["status"]) != STATUS_RESERVED:
			continue
		var amount: int = int(wager["stake"])
		_available_balance += amount
		refunded_total += amount
		wager["status"] = STATUS_REFUNDED
		wager["refund_reason"] = "round_cancelled"
		_wagers[wager_id] = wager
		wager_changed.emit(wager_id, STATUS_REFUNDED)
	round_data["state"] = ROUND_CANCELLED
	_rounds[key] = round_data
	round_changed.emit(table_id, round_id, ROUND_CANCELLED)
	_log_wallet("Cancelled %s/%s and refunded %d." % [table_id, round_id, refunded_total])
	_emit_wallet_changed()
	return _success({"refunded_total": refunded_total})

## Settles all locked wagers atomically. Each payout is a gross return credited to the wallet.
func settle_round(table_id: String, round_id: String, payouts: Dictionary) -> Dictionary:
	if not _is_authority():
		return _failure("Only the host can settle a betting round.")
	var key: String = _round_key(table_id, round_id)
	if not _rounds.has(key):
		return _failure("Unknown table round.")
	var round_data: Dictionary = _rounds[key]
	if str(round_data["state"]) != ROUND_LOCKED:
		return _failure("Only a locked round can be settled.")
	var wager_ids: Array = round_data["wager_ids"]
	var locked_ids: Array[String] = []
	for wager_id_value: Variant in wager_ids:
		var wager_id: String = str(wager_id_value)
		var wager: Dictionary = _wagers[wager_id]
		if str(wager["status"]) == STATUS_LOCKED:
			locked_ids.append(wager_id)
	if locked_ids.is_empty() or payouts.size() != locked_ids.size():
		return _failure("Settlement must include exactly one payout for every locked wager.")
	for wager_id: String in locked_ids:
		if not payouts.has(wager_id):
			return _failure("Settlement is missing payout for %s." % wager_id)
		if typeof(payouts[wager_id]) != TYPE_INT or int(payouts[wager_id]) < 0:
			return _failure("Payouts must be non-negative integer gross returns.")
	for wager_id: String in locked_ids:
		var wager: Dictionary = _wagers[wager_id]
		var return_amount: int = int(payouts[wager_id])
		var stake: int = int(wager["stake"])
		_available_balance += return_amount
		wager["status"] = STATUS_SETTLED
		wager["return_amount"] = return_amount
		wager["net_result"] = return_amount - stake
		_wagers[wager_id] = wager
		wager_changed.emit(wager_id, STATUS_SETTLED)
	round_data["state"] = ROUND_SETTLED
	_rounds[key] = round_data
	round_changed.emit(table_id, round_id, ROUND_SETTLED)
	_log_wallet("Settled %s/%s; gross returns credited: %d." % [table_id, round_id, _sum_payouts(payouts)])
	_emit_wallet_changed()
	return _success({"available_balance": _available_balance, "gross_return": _sum_payouts(payouts)})

func get_snapshot() -> Dictionary:
	return {"run_active": _run_active, "initial_balance": _initial_balance, "available_balance": _available_balance, "reserved_total": _get_reserved_total(), "wager_count": _wagers.size(), "round_count": _rounds.size()}

func get_wager(wager_id: String) -> Dictionary:
	if not _wagers.has(wager_id):
		return {}
	var wager: Dictionary = _wagers[wager_id]
	return wager.duplicate(true)

func get_round(table_id: String, round_id: String) -> Dictionary:
	var key: String = _round_key(table_id, round_id)
	if not _rounds.has(key):
		return {}
	var round_data: Dictionary = _rounds[key]
	return round_data.duplicate(true)

func get_round_wagers(table_id: String, round_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var round_data: Dictionary = get_round(table_id, round_id)
	if round_data.is_empty():
		return result
	var wager_ids: Array = round_data["wager_ids"]
	for wager_id_value: Variant in wager_ids:
		var wager: Dictionary = get_wager(str(wager_id_value))
		if not wager.is_empty():
			result.append(wager)
	return result

func _get_open_round(table_id: String, round_id: String) -> Dictionary:
	var key: String = _round_key(table_id, round_id)
	if not _rounds.has(key):
		return {}
	var round_data: Dictionary = _rounds[key]
	if str(round_data["state"]) != ROUND_OPEN:
		return {}
	return round_data

func _valid_round_ids(table_id: String, round_id: String) -> bool:
	return not table_id.is_empty() and not round_id.is_empty() and not table_id.contains("::") and not round_id.contains("::")

func _round_key(table_id: String, round_id: String) -> String:
	return "%s::%s" % [table_id, round_id]

func _is_authority() -> bool:
	return multiplayer.is_server()

func _has_unsettled_wagers() -> bool:
	for wager_value: Variant in _wagers.values():
		var wager: Dictionary = wager_value
		var status: String = str(wager["status"])
		if status == STATUS_RESERVED or status == STATUS_LOCKED:
			return true
	return false

func _get_reserved_total() -> int:
	var total: int = 0
	for wager_value: Variant in _wagers.values():
		var wager: Dictionary = wager_value
		var status: String = str(wager["status"])
		if status == STATUS_RESERVED or status == STATUS_LOCKED:
			total += int(wager["stake"])
	return total

func _sum_payouts(payouts: Dictionary) -> int:
	var total: int = 0
	for payout_value: Variant in payouts.values():
		total += int(payout_value)
	return total

func _emit_wallet_changed() -> void:
	wallet_changed.emit(_available_balance, _get_reserved_total())

func _success(data: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"ok": true, "reason": ""}
	result.merge(data, true)
	return result

func _failure(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}

func _log_wallet(message: String) -> void:
	if _debug_hub != null and is_instance_valid(_debug_hub):
		_debug_hub.call("log", &"wallet", message)

func _debug_wallet_status(_args: Array[Variant]) -> String:
	var snapshot: Dictionary = get_snapshot()
	return "run_active=%s initial=%d available=%d reserved=%d wagers=%d rounds=%d" % [str(snapshot["run_active"]), int(snapshot["initial_balance"]), int(snapshot["available_balance"]), int(snapshot["reserved_total"]), int(snapshot["wager_count"]), int(snapshot["round_count"])]

func _debug_wallet_wagers(_args: Array[Variant]) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for wager_id_value: Variant in _wagers.keys():
		var wager_id: String = str(wager_id_value)
		var wager: Dictionary = _wagers[wager_id]
		lines.append("%s peer=%d %s/%s stake=%d status=%s" % [wager_id, int(wager["peer_id"]), str(wager["table_id"]), str(wager["round_id"]), int(wager["stake"]), str(wager["status"])])
	return "\n".join(lines) if not lines.is_empty() else "No wagers recorded."
