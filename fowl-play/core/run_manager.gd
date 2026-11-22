## Host-authoritative run and day progression state.
## This autoload survives world swaps; it does not own world loading or wallet mutations.
extends Node

enum Phase {
	IDLE,
	APARTMENT,
	CASINO,
	REST,
	CONTRACT_FULFILLED,
	CONTRACT_EXTENDED,
	RUN_FAILED,
}

const MAX_DAYS: int = 10
const INITIAL_RUN_WALLET: int = 1000
const WORLD_APARTMENT: int = 0
const WORLD_CASINO: int = 1

signal run_state_changed(snapshot: Dictionary)

var run_active: bool = false
var current_day: int = 0
var phase: int = Phase.IDLE
var casino_departure_allowed: bool = false
var continuation_used: bool = false
var continuation_loan_amount: int = 0
var repeat_day_after_rest: bool = false
var last_day_success: bool = false
var last_day_final_wallet: int = 0
var last_day_quota: int = 0

var _debug_hub: Node
var _casino_wallet: Node


func _ready() -> void:
	_debug_hub = get_node_or_null("/root/DebugHub")
	_casino_wallet = get_node_or_null("/root/CasinoWallet")
	if not is_instance_valid(_debug_hub):
		return
	_debug_hub.call("watch", &"run/active", func() -> bool: return run_active)
	_debug_hub.call("watch", &"run/day", func() -> int: return current_day)
	_debug_hub.call("watch", &"run/phase", func() -> String: return _phase_name(phase))
	_debug_hub.call("watch", &"run/casino_departure_allowed", func() -> bool: return casino_departure_allowed)
	_debug_hub.call(
		"command",
		&"run_begin",
		Callable(self, "_debug_begin_new_run"),
		"Start a fresh development run and initialize the shared wallet.",
		true,
		false
	)
	_debug_hub.call(
		"command",
		&"run_status",
		Callable(self, "_debug_run_status"),
		"Show the current run phase and wallet balance.",
		false,
		false
	)


func _exit_tree() -> void:
	if not is_instance_valid(_debug_hub):
		return
	_debug_hub.call("unwatch", &"run/active")
	_debug_hub.call("unwatch", &"run/day")
	_debug_hub.call("unwatch", &"run/phase")
	_debug_hub.call("unwatch", &"run/casino_departure_allowed")


## MainController is persistent; bind its world signal once so progression commits survive elevator scene swaps.
func bind_main_controller(controller: Node) -> void:
	if controller == null or not controller.has_signal("world_changed"):
		return
	var callback: Callable = Callable(self, "_on_main_world_changed")
	if not controller.is_connected("world_changed", callback):
		controller.connect("world_changed", callback)


func _on_main_world_changed(previous_world: int, current_world: int) -> void:
	if previous_world < 0 or not _is_authority():
		return
	complete_world_transition(previous_world, current_world)


## Starts a new run in the Apartment on Day 1.
## CasinoWallet owns the actual balance reset; RunManager coordinates when it occurs.
func begin_new_run() -> Dictionary:
	if not _is_authority():
		return _failure("Only the host can begin a run.")
	if run_active:
		return _failure("A run is already active.")
	if not is_instance_valid(_casino_wallet):
		return _failure("CasinoWallet is unavailable; cannot initialize a new run.")
	var wallet_result: Dictionary = _casino_wallet.call("begin_run", INITIAL_RUN_WALLET)
	if not bool(wallet_result.get("ok", false)):
		return _failure("Could not initialize the run wallet: %s" % str(wallet_result.get("reason", "unknown wallet error")))
	continuation_used = false
	continuation_loan_amount = 0
	repeat_day_after_rest = false
	last_day_success = false
	last_day_final_wallet = 0
	last_day_quota = 0
	_publish_state(true, 1, Phase.APARTMENT, false)
	_log("New run started. Day 1 begins in the Apartment.")
	return _success(get_snapshot())


## Clears local run progression after Network has replaced the session peer with OfflineMultiplayerPeer.
## Each disconnected peer resets its own local mirror; the host's shutdown does not affect other peers' state.
func reset_for_session_end() -> bool:
	var active_peer: MultiplayerPeer = multiplayer.multiplayer_peer
	if not active_peer is OfflineMultiplayerPeer:
		return false
	continuation_used = false
	continuation_loan_amount = 0
	repeat_day_after_rest = false
	last_day_success = false
	last_day_final_wallet = 0
	last_day_quota = 0
	_apply_state({
		"run_active": false,
		"current_day": 0,
		"phase": Phase.IDLE,
		"casino_departure_allowed": false,
		"continuation_used": false,
		"continuation_loan_amount": 0,
		"repeat_day_after_rest": false,
		"last_day_success": false,
		"last_day_final_wallet": 0,
		"last_day_quota": 0,
	})
	if is_instance_valid(_casino_wallet) and _casino_wallet.has_method("reset_for_session_end"):
		_casino_wallet.call("reset_for_session_end")
	_log("Run state reset after network session ended.")
	return true


func _debug_begin_new_run(_args: Array[Variant]) -> Dictionary:
	var result: Dictionary = begin_new_run()
	if not bool(result.get("ok", false)):
		_log("Could not start development run: %s" % str(result.get("reason", "unknown error")))
	return result


func _debug_run_status(_args: Array[Variant]) -> Dictionary:
	var snapshot: Dictionary = get_snapshot()
	if is_instance_valid(_casino_wallet):
		snapshot["wallet"] = _casino_wallet.call("get_snapshot")
	return snapshot


## The progression manager asks for a destination; the elevator never decides game rules.
## Returns -1 when the current phase/world combination does not permit departure.
func get_departure_destination(current_world: int) -> int:
	if not run_active:
		return -1
	match phase:
		Phase.APARTMENT:
			return WORLD_CASINO if current_world == WORLD_APARTMENT else -1
		Phase.CASINO:
			if current_world == WORLD_CASINO and casino_departure_allowed:
				return WORLD_APARTMENT
		Phase.REST:
			if current_world == WORLD_APARTMENT and (current_day < MAX_DAYS or repeat_day_after_rest):
				return WORLD_CASINO
	return -1


## Called only after MainController has completed the approved world transition.
## Returning from the Apartment Rest phase to the Casino advances the day.
func complete_world_transition(previous_world: int, destination_world: int) -> bool:
	if not _is_authority():
		return false
	if get_departure_destination(previous_world) != destination_world:
		return false

	var next_day: int = current_day
	var next_phase: int = phase
	var next_casino_departure_allowed: bool = casino_departure_allowed
	var next_run_active: bool = true
	match phase:
		Phase.APARTMENT:
			next_phase = Phase.CASINO
		Phase.CASINO:
			var day_result: Dictionary = _resolve_completed_casino_day()
			if not bool(day_result.get("ok", false)):
				_log("Casino-to-Apartment transition rejected: %s" % str(day_result.get("reason", "")))
				return false
			next_day = int(day_result.get("day", current_day))
			next_phase = int(day_result.get("phase", Phase.REST))
			next_casino_departure_allowed = false
		Phase.REST:
			if repeat_day_after_rest:
				var day_manager: Node = get_node_or_null("/root/CasinoDayManager")
				if not is_instance_valid(day_manager):
					return false
				var replay_result: Dictionary = day_manager.call("prepare_day_replay")
				if not bool(replay_result.get("ok", false)):
					_log("Could not prepare Day %d replay: %s" % [current_day, str(replay_result.get("reason", ""))])
					return false
				repeat_day_after_rest = false
			else:
				next_day += 1
			next_phase = Phase.CASINO
			next_casino_departure_allowed = false
		_:
			return false

	if next_phase == Phase.CONTRACT_FULFILLED or next_phase == Phase.RUN_FAILED:
		next_run_active = false
	_publish_state(next_run_active, next_day, next_phase, next_casino_departure_allowed)
	_log("Progression advanced to Day %d (%s)." % [current_day, _phase_name(phase)])
	return true


## Applies the approved success/failure policy only after the day manager has frozen its result.
func _resolve_completed_casino_day() -> Dictionary:
	var day_manager: Node = get_node_or_null("/root/CasinoDayManager")
	if not is_instance_valid(day_manager):
		return _failure("CasinoDayManager is unavailable.")
	var day_snapshot: Dictionary = day_manager.call("get_snapshot")
	if not bool(day_snapshot.get("day_result_recorded", false)):
		return _failure("The casino day has no recorded deadline or early-departure result.")
	if int(day_snapshot.get("day_number", 0)) != current_day:
		return _failure("The recorded casino result does not match the current run day.")

	last_day_success = bool(day_snapshot.get("day_success", false))
	last_day_final_wallet = int(day_snapshot.get("final_wallet_snapshot", 0))
	last_day_quota = int(day_snapshot.get("daily_quota", 0))

	if last_day_success:
		if current_day == MAX_DAYS:
			return _success({"day": current_day, "phase": Phase.CONTRACT_FULFILLED})
		return _success({"day": current_day, "phase": Phase.REST})

	if continuation_used:
		return _success({"day": current_day, "phase": Phase.RUN_FAILED})

	var starting_wallet: int = int(day_snapshot.get("starting_wallet", 0))
	var loan_amount: int = floori(float(starting_wallet) * 0.5)
	if loan_amount <= 0:
		return _failure("The House continuation loan is not valid for this starting wallet.")
	if not is_instance_valid(_casino_wallet):
		return _failure("CasinoWallet is unavailable; cannot apply the House continuation.")
	var loan_result: Dictionary = _casino_wallet.call("credit_house_continuation_loan", loan_amount, current_day)
	if not bool(loan_result.get("ok", false)):
		return _failure("Could not apply the House continuation: %s" % str(loan_result.get("reason", "")))

	continuation_used = true
	continuation_loan_amount = loan_amount
	repeat_day_after_rest = current_day == MAX_DAYS
	_log("House continuation used after Day %d: +%d (50%% of starting wallet)." % [current_day, loan_amount])
	return _success({"day": current_day, "phase": Phase.REST, "loan_amount": loan_amount, "repeat_day": repeat_day_after_rest})


## Quota/deadline systems will unlock this after their authoritative result is known.
func set_casino_departure_allowed(allowed: bool) -> bool:
	if not _is_authority() or not run_active or phase != Phase.CASINO:
		return false
	_publish_state(run_active, current_day, phase, allowed)
	return true


func get_snapshot() -> Dictionary:
	return {
		"run_active": run_active,
		"current_day": current_day,
		"phase": phase,
		"phase_name": _phase_name(phase),
		"casino_departure_allowed": casino_departure_allowed,
		"max_days": MAX_DAYS,
		"continuation_used": continuation_used,
		"continuation_loan_amount": continuation_loan_amount,
		"repeat_day_after_rest": repeat_day_after_rest,
		"last_day_success": last_day_success,
		"last_day_final_wallet": last_day_final_wallet,
		"last_day_quota": last_day_quota,
	}


func _publish_state(active: bool, day: int, next_phase: Phase, departure_allowed: bool) -> void:
	var snapshot: Dictionary = get_snapshot()
	snapshot["run_active"] = active
	snapshot["current_day"] = day
	snapshot["phase"] = next_phase
	snapshot["phase_name"] = _phase_name(next_phase)
	snapshot["casino_departure_allowed"] = departure_allowed
	var network_peer: MultiplayerPeer = multiplayer.multiplayer_peer
	if network_peer is OfflineMultiplayerPeer:
		_apply_state(snapshot)
	else:
		rpc("_rpc_apply_state", snapshot)


@rpc("authority", "call_local", "reliable")
func _rpc_apply_state(snapshot: Dictionary) -> void:
	var day: int = int(snapshot.get("current_day", -1))
	var next_phase: int = int(snapshot.get("phase", -1))
	if day < 0 or day > MAX_DAYS or next_phase < Phase.IDLE or next_phase > Phase.RUN_FAILED:
		return
	_apply_state(snapshot)


func _apply_state(snapshot: Dictionary) -> void:
	run_active = bool(snapshot.get("run_active", false))
	current_day = int(snapshot.get("current_day", 0))
	phase = int(snapshot.get("phase", Phase.IDLE))
	casino_departure_allowed = bool(snapshot.get("casino_departure_allowed", false))
	continuation_used = bool(snapshot.get("continuation_used", false))
	continuation_loan_amount = int(snapshot.get("continuation_loan_amount", 0))
	repeat_day_after_rest = bool(snapshot.get("repeat_day_after_rest", false))
	last_day_success = bool(snapshot.get("last_day_success", false))
	last_day_final_wallet = int(snapshot.get("last_day_final_wallet", 0))
	last_day_quota = int(snapshot.get("last_day_quota", 0))
	run_state_changed.emit(get_snapshot())


func _is_authority() -> bool:
	return multiplayer.is_server()


func _phase_name(value: int) -> String:
	match value:
		Phase.IDLE:
			return "IDLE"
		Phase.APARTMENT:
			return "APARTMENT"
		Phase.CASINO:
			return "CASINO"
		Phase.REST:
			return "REST"
		Phase.CONTRACT_FULFILLED:
			return "CONTRACT_FULFILLED"
		Phase.CONTRACT_EXTENDED:
			return "CONTRACT_EXTENDED"
		Phase.RUN_FAILED:
			return "RUN_FAILED"
	return "UNKNOWN"


func _success(data: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"ok": true, "reason": ""}
	result.merge(data, true)
	return result


func _failure(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}


func _log(message: String) -> void:
	if is_instance_valid(_debug_hub):
		_debug_hub.call("log", &"run", message)
