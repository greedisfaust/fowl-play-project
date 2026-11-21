## Reusable host-authoritative lifecycle controller for casino tables.
## Attach to an editor-authored table scene; game-specific rules stay outside this class.
class_name BaseTable
extends Node3D

enum TableState {
	IDLE,
	OPEN,
	RUNNING,
	RESOLVING,
	CLOSED,
}

signal state_changed(previous_state: int, new_state: int)
signal participants_changed(participants: Array[Dictionary])
signal round_opened(table_id: String, round_id: String)
signal round_started(table_id: String, round_id: String)
signal participant_left_after_start(peer_id: int, table_id: String, round_id: String)
signal round_settled(table_id: String, round_id: String, settlement: Dictionary)
signal round_cancelled(table_id: String, round_id: String, refund_total: int)
signal round_auto_resolution_requested(table_id: String, round_id: String, reason: String)

@export var open_round_inactivity_seconds: float = 45.0
@export var table_id: String = ""
@export var game_id: String = ""
@export_range(1, 4, 1) var max_participants: int = 4

var state: TableState = TableState.IDLE
var current_round_id: String = ""

var _wallet: Node = null
var _debug_hub: Node = null
var _inside_proximity: Dictionary = {}
var _participants: Dictionary = {}
var _round_sequence: int = 1
var _open_round_inactivity_remaining: float = 0.0

func _ready() -> void:
	_wallet = get_node_or_null("/root/CasinoWallet")
	_debug_hub = get_node_or_null("/root/DebugHub")
	if _wallet == null:
		push_error("BaseTable requires the CasinoWallet autoload.")
	if is_instance_valid(_debug_hub):
		var watch_prefix: String = "casino_table/%s/" % _debug_table_key()
		_debug_hub.call("watch", StringName(watch_prefix + "state"), func() -> String: return _state_name())
		_debug_hub.call("watch", StringName(watch_prefix + "participants"), func() -> int: return _participants.size())
		_debug_hub.call("watch", StringName(watch_prefix + "round_id"), func() -> String: return current_round_id)
	_log("Table controller ready for game '%s'." % game_id)

func _process(delta: float) -> void:
	if state != TableState.OPEN:
		return
	_open_round_inactivity_remaining -= delta
	if _open_round_inactivity_remaining <= 0.0:
		_log("Open round %s expired after inactivity; cancelling and refunding reserved wagers." % current_round_id)
		cancel_open_round()

func _exit_tree() -> void:
	if not is_instance_valid(_debug_hub):
		return
	var watch_prefix: String = "casino_table/%s/" % _debug_table_key()
	_debug_hub.call("unwatch", StringName(watch_prefix + "state"))
	_debug_hub.call("unwatch", StringName(watch_prefix + "participants"))
	_debug_hub.call("unwatch", StringName(watch_prefix + "round_id"))

## The scene's Area3D/proximity adapter calls this on the host when a player enters range.
func enter_proximity(peer_id: int) -> Dictionary:
	if not _is_authority():
		return _failure("Only the host can update table proximity.")
	if not _is_valid_peer(peer_id):
		return _failure("Unknown or invalid player peer ID.")
	_inside_proximity[peer_id] = true
	return _success({"peer_id": peer_id})

## Leaving before round start refunds that player's reserved wagers.
## Leaving after start preserves the locked wager and notifies the game to auto-resolve.
func exit_proximity(peer_id: int) -> Dictionary:
	if not _is_authority():
		return _failure("Only the host can update table proximity.")
	if not _inside_proximity.has(peer_id):
		return _failure("Player is not registered in this table's proximity.")
	if not _participants.has(peer_id):
		_inside_proximity.erase(peer_id)
		return _success({"peer_id": peer_id, "participant_removed": false})
	if state == TableState.OPEN:
		var refund_result: Dictionary = _refund_peer_open_wagers(peer_id)
		if not bool(refund_result.get("ok", false)):
			return refund_result
		_inside_proximity.erase(peer_id)
		_participants.erase(peer_id)
		_emit_participants_changed()
		_reset_open_round_inactivity()
		_log("Peer %d left before start; refunded %d." % [peer_id, int(refund_result.get("refunded_total", 0))])
		return _success({
			"peer_id": peer_id,
			"participant_removed": true,
			"refunded_total": int(refund_result.get("refunded_total", 0)),
		})
	_inside_proximity.erase(peer_id)
	if state == TableState.RUNNING or state == TableState.RESOLVING:
		var participant: Dictionary = _participants[peer_id]
		participant["status"] = "left_after_start"
		_participants[peer_id] = participant
		_emit_participants_changed()
		participant_left_after_start.emit(peer_id, table_id, current_round_id)
		_log("Peer %d left after start; game must auto-resolve their participation." % peer_id)
		return _success({"peer_id": peer_id, "participant_removed": false, "auto_resolve_required": true})
	_participants.erase(peer_id)
	_emit_participants_changed()
	return _success({"peer_id": peer_id, "participant_removed": true})

## Opens a round. The opener does not have to join or place a wager.
func open_round(peer_id: int) -> Dictionary:
	if not _is_authority():
		return _failure("Only the host can open a table round.")
	if not _is_valid_peer(peer_id) or not _is_near_table(peer_id):
		return _failure("Only a valid nearby player can open this table.")
	if state != TableState.IDLE:
		return _failure("The table is not idle.")
	if table_id.strip_edges().is_empty() or game_id.strip_edges().is_empty():
		return _failure("Table ID and game ID must be configured in the scene.")
	if _wallet == null or not is_instance_valid(_wallet):
		return _failure("CasinoWallet is unavailable.")
	var next_round_id: String = "%s_%06d" % [table_id, _round_sequence]
	_round_sequence += 1
	var result: Dictionary = _wallet.call("open_round", table_id, next_round_id)
	if not bool(result.get("ok", false)):
		return result
	current_round_id = next_round_id
	_set_state(TableState.OPEN)
	_reset_open_round_inactivity()
	round_opened.emit(table_id, current_round_id)
	_log("Peer %d opened round %s." % [peer_id, current_round_id])
	return _success({"table_id": table_id, "game_id": game_id, "round_id": current_round_id})

## Registers a nearby player as a participant. Participants may wager; openers/starters need not.
func join_table(peer_id: int) -> Dictionary:
	if not _is_authority():
		return _failure("Only the host can register table participants.")
	if state != TableState.OPEN:
		return _failure("Players can only join while a round is open.")
	if not _is_valid_peer(peer_id) or not _is_near_table(peer_id):
		return _failure("Only a valid nearby player can join this table.")
	if _participants.has(peer_id):
		return _success({"peer_id": peer_id, "already_joined": true})
	if _participants.size() >= max_participants:
		return _failure("This game has reached its participant limit.")
	_participants[peer_id] = {
		"peer_id": peer_id,
		"status": "joined",
		"joined_sequence": _participants.size() + 1,
	}
	_emit_participants_changed()
	_reset_open_round_inactivity()
	_log("Peer %d joined table %s." % [peer_id, table_id])
	return _success({"peer_id": peer_id, "participant_count": _participants.size()})

## Confirms a wager for a joined participant; the shared wallet records bettor attribution.
func place_wager(peer_id: int, amount: int, payload: Dictionary = {}) -> Dictionary:
	if not _is_authority():
		return _failure("Only the host can submit a wager.")
	if state != TableState.OPEN or not _participants.has(peer_id):
		return _failure("Player must be joined to an open round before wagering.")
	if not _is_near_table(peer_id):
		return _failure("Player is no longer within table proximity.")
	if _wallet == null or not is_instance_valid(_wallet):
		return _failure("CasinoWallet is unavailable.")
	var result: Dictionary = _wallet.call("reserve_wager", peer_id, table_id, current_round_id, amount, payload)
	if bool(result.get("ok", false)):
		_reset_open_round_inactivity()
	return result

## Updates only a wager belonging to this player in this table's current open round.
func update_wager(peer_id: int, wager_id: String, amount: int, payload: Dictionary = {}) -> Dictionary:
	if not _is_authority():
		return _failure("Only the host can edit a wager.")
	if not _is_near_table(peer_id):
		return _failure("Player is no longer within table proximity.")
	var wager: Dictionary = _get_owned_current_wager(peer_id, wager_id)
	if wager.is_empty():
		return _failure("Wager does not belong to this player and table round.")
	var result: Dictionary = _wallet.call("update_wager", wager_id, amount, payload)
	if bool(result.get("ok", false)):
		_reset_open_round_inactivity()
	return result

## Withdraws only a wager belonging to this player in this table's current open round.
func withdraw_wager(peer_id: int, wager_id: String) -> Dictionary:
	if not _is_authority():
		return _failure("Only the host can withdraw a wager.")
	if not _is_near_table(peer_id):
		return _failure("Player is no longer within table proximity.")
	var wager: Dictionary = _get_owned_current_wager(peer_id, wager_id)
	if wager.is_empty():
		return _failure("Wager does not belong to this player and table round.")
	var result: Dictionary = _wallet.call("withdraw_wager", wager_id)
	if bool(result.get("ok", false)):
		_reset_open_round_inactivity()
	return result

## Any nearby player may start the round, even if they did not join or wager.
func start_round(peer_id: int) -> Dictionary:
	if not _is_authority():
		return _failure("Only the host can start a table round.")
	if state != TableState.OPEN:
		return _failure("Only an open round can start.")
	if not _is_valid_peer(peer_id) or not _is_near_table(peer_id):
		return _failure("Only a valid nearby player can start this table.")
	var result: Dictionary = _wallet.call("lock_round", table_id, current_round_id)
	if not bool(result.get("ok", false)):
		return result
	for peer_value: Variant in _participants.keys():
		var participant_peer_id: int = int(peer_value)
		var participant: Dictionary = _participants[participant_peer_id]
		participant["status"] = "playing"
		_participants[participant_peer_id] = participant
	_open_round_inactivity_remaining = 0.0
	_set_state(TableState.RUNNING)
	_emit_participants_changed()
	round_started.emit(table_id, current_round_id)
	_log("Peer %d started round %s." % [peer_id, current_round_id])
	return _success({"round_id": current_round_id, "locked_count": int(result.get("locked_count", 0))})

func begin_resolution() -> Dictionary:
	if not _is_authority():
		return _failure("Only the host can resolve a table round.")
	if state != TableState.RUNNING:
		return _failure("Only a running round can enter resolution.")
	_set_state(TableState.RESOLVING)
	return _success({"round_id": current_round_id})

func settle_round(payouts: Dictionary) -> Dictionary:
	if not _is_authority():
		return _failure("Only the host can settle a table round.")
	if state != TableState.RUNNING and state != TableState.RESOLVING:
		return _failure("Only a running or resolving round can settle.")
	if state == TableState.RUNNING:
		_set_state(TableState.RESOLVING)
	var settled_round_id: String = current_round_id
	var result: Dictionary = _wallet.call("settle_round", table_id, settled_round_id, payouts)
	if not bool(result.get("ok", false)):
		return result
	round_settled.emit(table_id, settled_round_id, result.duplicate(true))
	current_round_id = ""
	_participants.clear()
	_set_state(TableState.IDLE)
	_emit_participants_changed()
	_log("Round %s settled." % settled_round_id)
	return result

func cancel_open_round() -> Dictionary:
	if not _is_authority():
		return _failure("Only the host can cancel a table round.")
	if state != TableState.OPEN:
		return _failure("Only an unstarted open round can be cancelled.")
	var cancelled_round_id: String = current_round_id
	var result: Dictionary = _wallet.call("cancel_open_round", table_id, cancelled_round_id)
	if not bool(result.get("ok", false)):
		return result
	var refund_total: int = int(result.get("refunded_total", 0))
	_open_round_inactivity_remaining = 0.0
	round_cancelled.emit(table_id, cancelled_round_id, refund_total)
	current_round_id = ""
	_participants.clear()
	_set_state(TableState.IDLE)
	_emit_participants_changed()
	_log("Round %s cancelled; refunded %d." % [cancelled_round_id, refund_total])
	return result

## Day coordinator hook for early departure or the hard casino deadline.
## On timer expiry, the coordinator MUST snapshot/check quota BEFORE calling this.
## Open rounds are refunded; started rounds keep locked stakes and auto-resolve.
func request_day_end_cleanup(reason: String) -> Dictionary:
	if not _is_authority():
		return _failure("Only the host can request day-end table cleanup.")
	if reason.strip_edges().is_empty():
		return _failure("A cleanup reason is required.")
	if state == TableState.IDLE or state == TableState.CLOSED:
		return _success({"round_id": "", "action": "none"})
	if state == TableState.OPEN:
		var cancelled_round_id: String = current_round_id
		var cancel_result: Dictionary = cancel_open_round()
		if not bool(cancel_result.get("ok", false)):
			return cancel_result
		return _success({"round_id": cancelled_round_id, "action": "cancelled_and_refunded", "refunded_total": int(cancel_result.get("refunded_total", 0))})
	if state == TableState.RUNNING or state == TableState.RESOLVING:
		round_auto_resolution_requested.emit(table_id, current_round_id, reason)
		_log("Day-end cleanup requested automatic resolution for %s (%s)." % [current_round_id, reason])
		return _success({"round_id": current_round_id, "action": "auto_resolution_requested"})
	return _failure("Table cannot be cleaned up from its current state.")

func _reset_open_round_inactivity() -> void:
	if state == TableState.OPEN:
		_open_round_inactivity_remaining = maxf(open_round_inactivity_seconds, 0.01)

func get_participants() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for peer_value: Variant in _participants.keys():
		var peer_id: int = int(peer_value)
		var participant: Dictionary = _participants[peer_id]
		result.append(participant.duplicate(true))
	return result

func get_round_wagers() -> Array[Dictionary]:
	if current_round_id.is_empty() or _wallet == null or not is_instance_valid(_wallet):
		return []
	var result: Array[Dictionary] = _wallet.call("get_round_wagers", table_id, current_round_id)
	return result

func get_snapshot() -> Dictionary:
	return {
		"table_id": table_id,
		"game_id": game_id,
		"state": _state_name(),
		"round_id": current_round_id,
		"participant_count": _participants.size(),
		"max_participants": max_participants,
		"nearby_peer_ids": _inside_proximity.keys(),
	}

func _get_owned_current_wager(peer_id: int, wager_id: String) -> Dictionary:
	if state != TableState.OPEN or current_round_id.is_empty():
		return {}
	if _wallet == null or not is_instance_valid(_wallet):
		return {}
	var wager: Dictionary = _wallet.call("get_wager", wager_id)
	if wager.is_empty():
		return {}
	if int(wager.get("peer_id", 0)) != peer_id:
		return {}
	if str(wager.get("table_id", "")) != table_id:
		return {}
	if str(wager.get("round_id", "")) != current_round_id:
		return {}
	if str(wager.get("status", "")) != "reserved":
		return {}
	return wager

func _refund_peer_open_wagers(peer_id: int) -> Dictionary:
	if _wallet == null or not is_instance_valid(_wallet):
		return _failure("CasinoWallet is unavailable.")
	var wagers: Array[Dictionary] = _wallet.call("get_round_wagers", table_id, current_round_id)
	var refunded_total: int = 0
	for wager: Dictionary in wagers:
		if int(wager.get("peer_id", 0)) != peer_id or str(wager.get("status", "")) != "reserved":
			continue
		var result: Dictionary = _wallet.call("withdraw_wager", str(wager.get("wager_id", "")))
		if not bool(result.get("ok", false)):
			return _failure("Could not refund wager %s: %s" % [str(wager.get("wager_id", "")), str(result.get("reason", "unknown error"))])
		refunded_total += int(result.get("refunded", 0))
	return _success({"refunded_total": refunded_total})

func _is_valid_peer(peer_id: int) -> bool:
	if peer_id <= 0:
		return false
	var network: Node = get_node_or_null("/root/Network")
	if network == null:
		return true
	var network_peer: Variant = network.get("peer")
	if network_peer == null:
		return true
	var roster_value: Variant = network.get("roster")
	if typeof(roster_value) != TYPE_ARRAY:
		return false
	var roster: Array = roster_value
	return roster.has(peer_id)

func _is_near_table(peer_id: int) -> bool:
	return bool(_inside_proximity.get(peer_id, false))

func _is_authority() -> bool:
	return multiplayer.is_server()

func _set_state(next_state: TableState) -> void:
	if state == next_state:
		return
	var previous_state: int = state
	state = next_state
	state_changed.emit(previous_state, int(state))

func _emit_participants_changed() -> void:
	participants_changed.emit(get_participants())

func _state_name() -> String:
	match state:
		TableState.IDLE: return "idle"
		TableState.OPEN: return "open"
		TableState.RUNNING: return "running"
		TableState.RESOLVING: return "resolving"
		TableState.CLOSED: return "closed"
	return "unknown"

func _debug_table_key() -> String:
	return table_id if not table_id.is_empty() else str(get_instance_id())

func _log(message: String) -> void:
	if is_instance_valid(_debug_hub):
		_debug_hub.call("log", &"wallet", "[%s] %s" % [_debug_table_key(), message])

func _success(data: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"ok": true, "reason": ""}
	result.merge(data, true)
	return result

func _failure(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
