## Host-authoritative casino-day timer, dynamic quota, and day-end coordination.
## This service survives world swaps; it reads and never directly mutates wallet balances.
extends Node

const DAY_MULTIPLIERS: Array[float] = [
	0.25, 0.28, 0.32, 0.36, 0.40,
	0.45, 0.50, 0.55, 0.62, 0.70,
]

signal day_state_changed(snapshot: Dictionary)
signal day_finished(day_number: int, success: bool, final_wallet: int, quota: int)

@export_range(1.0, 1800.0, 1.0) var casino_day_duration_seconds: float = 300.0

var day_active: bool = false
var day_number: int = 0
var starting_wallet: int = 0
var current_wallet_balance: int = 0
var daily_quota: int = 0
var seconds_remaining: float = 0.0
var quota_reached: bool = false
var day_result_recorded: bool = false
var day_start_pending: bool = false
var day_success: bool = false
var final_wallet_snapshot: int = 0

var _wallet: Node
var _run_manager: Node
var _debug_hub: Node
var _last_published_second: int = -1


func _ready() -> void:
	_wallet = get_node_or_null("/root/CasinoWallet")
	_run_manager = get_node_or_null("/root/RunManager")
	_debug_hub = get_node_or_null("/root/DebugHub")
	if is_instance_valid(_wallet) and _wallet.has_signal("wallet_changed"):
		_wallet.wallet_changed.connect(_on_wallet_changed)
	if is_instance_valid(_run_manager) and _run_manager.has_signal("run_state_changed"):
		_run_manager.run_state_changed.connect(_on_run_state_changed)
	if is_instance_valid(_debug_hub):
		_debug_hub.call("watch", &"casino_day/active", func() -> bool: return day_active)
		_debug_hub.call("watch", &"casino_day/day", func() -> int: return day_number)
		_debug_hub.call("watch", &"casino_day/starting_wallet", func() -> int: return starting_wallet)
		_debug_hub.call("watch", &"casino_day/quota", func() -> int: return daily_quota)
		_debug_hub.call("watch", &"casino_day/wallet", func() -> int: return current_wallet_balance)
		_debug_hub.call("watch", &"casino_day/seconds_remaining", func() -> int: return ceili(seconds_remaining))
		_debug_hub.call("watch", &"casino_day/quota_reached", func() -> bool: return quota_reached)


func _exit_tree() -> void:
	if is_instance_valid(_wallet) and _wallet.has_signal("wallet_changed"):
		if _wallet.wallet_changed.is_connected(_on_wallet_changed):
			_wallet.wallet_changed.disconnect(_on_wallet_changed)
	if is_instance_valid(_run_manager) and _run_manager.has_signal("run_state_changed"):
		if _run_manager.run_state_changed.is_connected(_on_run_state_changed):
			_run_manager.run_state_changed.disconnect(_on_run_state_changed)
	if is_instance_valid(_debug_hub):
		for watch_name: StringName in [
			&"casino_day/active", &"casino_day/day", &"casino_day/starting_wallet",
			&"casino_day/quota", &"casino_day/wallet", &"casino_day/seconds_remaining",
			&"casino_day/quota_reached",
		]:
			_debug_hub.call("unwatch", watch_name)


func _process(delta: float) -> void:
	if not _is_authority() or not day_active:
		return
	advance_day_timer(delta, _get_current_wallet_balance())


static func multiplier_for_day(requested_day: int) -> float:
	if requested_day < 1 or requested_day > DAY_MULTIPLIERS.size():
		return -1.0
	return DAY_MULTIPLIERS[requested_day - 1]


## Quota = W + (W * 0.50) + (W * M), rounded up to the next whole wallet unit.
static func calculate_daily_quota(wallet_at_day_start: int, requested_day: int) -> int:
	if wallet_at_day_start < 0:
		return -1
	var multiplier: float = multiplier_for_day(requested_day)
	if multiplier < 0.0:
		return -1
	return ceili(float(wallet_at_day_start) * (1.50 + multiplier))


func begin_casino_day(requested_day: int, wallet_at_day_start: int) -> Dictionary:
	if not _is_authority():
		return _failure("Only the host can begin a casino day.")
	if requested_day < 1 or requested_day > 10:
		return _failure("Casino day must be between 1 and 10.")
	if wallet_at_day_start < 0:
		return _failure("Starting wallet cannot be negative.")
	if day_active:
		return _failure("A casino day is already active.")
	if day_result_recorded and requested_day == day_number:
		return _failure("This casino day has already been recorded.")
	day_start_pending = false
	day_number = requested_day
	starting_wallet = wallet_at_day_start
	current_wallet_balance = wallet_at_day_start
	daily_quota = calculate_daily_quota(starting_wallet, day_number)
	seconds_remaining = casino_day_duration_seconds
	quota_reached = starting_wallet >= daily_quota
	day_active = true
	day_result_recorded = false
	day_success = false
	final_wallet_snapshot = 0
	_last_published_second = ceili(seconds_remaining)
	# Departure permission always mirrors the current wallet, including a fresh day.
	_set_departure_allowed(quota_reached)
	_publish_state()
	_log("Day %d started: wallet %d, quota %d, timer %.0fs." % [day_number, starting_wallet, daily_quota, seconds_remaining])
	return _success(get_snapshot())


## Clears a recorded Day 10 failure before replaying that same day with the House loan.
func prepare_day_replay() -> Dictionary:
	if not _is_authority():
		return _failure("Only the host can prepare a casino-day replay.")
	if day_active or not day_result_recorded or day_success:
		return _failure("Only a completed failed day can be replayed.")
	day_result_recorded = false
	day_success = false
	final_wallet_snapshot = 0
	quota_reached = false
	seconds_remaining = 0.0
	current_wallet_balance = _get_current_wallet_balance()
	_last_published_second = -1
	_publish_state()
	_log("Day %d replay prepared with carried wallet %d." % [day_number, current_wallet_balance])
	return _success(get_snapshot())


func advance_day_timer(delta: float, current_balance: int) -> void:
	if not _is_authority() or not day_active or delta <= 0.0:
		return
	current_wallet_balance = current_balance
	_evaluate_quota(current_balance)
	seconds_remaining = maxf(0.0, seconds_remaining - delta)
	var displayed_second: int = ceili(seconds_remaining)
	if displayed_second != _last_published_second:
		_last_published_second = displayed_second
		_publish_state()
	if seconds_remaining <= 0.0:
		_finish_at_deadline(current_balance)


func _on_wallet_changed(available_balance: int, _reserved_total: int) -> void:
	if not _is_authority() or not day_active:
		return
	current_wallet_balance = available_balance
	_evaluate_quota(available_balance)
	_publish_state()


func _on_run_state_changed(snapshot: Dictionary) -> void:
	var run_is_active: bool = bool(snapshot.get("run_active", false))
	if not run_is_active:
		day_start_pending = false
		day_active = false
		day_number = 0
		starting_wallet = 0
		current_wallet_balance = 0
		daily_quota = 0
		seconds_remaining = 0.0
		quota_reached = false
		day_result_recorded = false
		day_success = false
		final_wallet_snapshot = 0
		_last_published_second = -1
		day_state_changed.emit(get_snapshot())
		return
	var phase_value: int = int(snapshot.get("phase", -1))
	if phase_value != 2:
		day_start_pending = false
		return
	var incoming_day: int = int(snapshot.get("current_day", 0))
	if day_active and day_number == incoming_day:
		return
	if day_result_recorded and day_number == incoming_day:
		return
	# Mirror the incoming day immediately, but defer its actual timer/quota snapshot
	# until the host observes the first player leaving the destination elevator.
	day_active = false
	day_number = incoming_day
	starting_wallet = _get_current_wallet_balance()
	current_wallet_balance = starting_wallet
	daily_quota = 0
	seconds_remaining = 0.0
	quota_reached = false
	day_result_recorded = false
	day_success = false
	final_wallet_snapshot = 0
	_last_published_second = -1
	day_start_pending = _is_authority()
	day_state_changed.emit(get_snapshot())
	if _is_authority():
		_log("Day %d is waiting for the first player to leave the elevator." % incoming_day)

func start_casino_day_after_disembark() -> Dictionary:
	if not _is_authority():
		return _failure("Only the host can start the casino day.")
	if not day_start_pending or day_active:
		return _failure("The casino day is not waiting for its first disembark.")
	if not is_instance_valid(_run_manager) or int(_run_manager.get("phase")) != 2:
		return _failure("The run is no longer in the Casino phase.")
	var requested_day: int = int(_run_manager.get("current_day"))
	var result: Dictionary = begin_casino_day(requested_day, _get_current_wallet_balance())
	if not bool(result.get("ok", false)):
		_log("Could not start casino day after disembark: %s" % str(result.get("reason", "")))
		return result
	_log("Day %d timer started after the first player left the elevator." % requested_day)
	return result

func _evaluate_quota(current_balance: int) -> void:
	if not day_active:
		return
	var quota_is_currently_met: bool = current_balance >= daily_quota
	if quota_is_currently_met == quota_reached:
		return

	# Quota is a live condition, not a permanent achievement flag. If a later
	# wager drops the available wallet below target, lock departure again.
	quota_reached = quota_is_currently_met
	_set_departure_allowed(quota_reached)
	if quota_reached:
		_log("Day %d quota reached at wallet %d (target %d). Early departure is unlocked; play may continue." % [day_number, current_balance, daily_quota])
	else:
		_log("Day %d wallet fell below quota (%d / %d). Early departure is locked again." % [day_number, current_balance, daily_quota])


func _finish_at_deadline(current_balance: int) -> void:
	if not day_active:
		return
	# Snapshot before cleanup: post-deadline settlement must not alter the quota result.
	final_wallet_snapshot = current_balance
	day_success = final_wallet_snapshot >= daily_quota
	day_result_recorded = true
	day_active = false
	seconds_remaining = 0.0
	_set_departure_allowed(true)
	_publish_state()
	day_finished.emit(day_number, day_success, final_wallet_snapshot, daily_quota)
	_log("Day %d deadline: wallet %d / quota %d (%s)." % [day_number, final_wallet_snapshot, daily_quota, "PASS" if day_success else "FAIL"])
	_cleanup_tables("casino_deadline")


func finish_early_departure(final_wallet_override: int = -1) -> Dictionary:
	if not _is_authority():
		return _failure("Only the host can end a casino day.")
	if not day_active:
		return _failure("Early departure requires an active casino day.")

	# Re-read the wallet at the point of departure. Never trust the cached
	# quota flag: a wager may have lowered the balance since it was unlocked.
	var departure_balance: int = final_wallet_override if final_wallet_override >= 0 else _get_current_wallet_balance()
	current_wallet_balance = departure_balance
	_evaluate_quota(departure_balance)
	if not quota_reached or departure_balance < daily_quota:
		_publish_state()
		return _failure("Early departure is locked: current wallet %s is below the required quota %s." % [str(departure_balance), str(daily_quota)])

	_cleanup_tables("early_departure")
	# Table cleanup can settle/refund wagers, so validate the final live balance again.
	final_wallet_snapshot = final_wallet_override if final_wallet_override >= 0 else _get_current_wallet_balance()
	current_wallet_balance = final_wallet_snapshot
	_evaluate_quota(final_wallet_snapshot)
	if not quota_reached or final_wallet_snapshot < daily_quota:
		_publish_state()
		return _failure("Early departure cancelled: final wallet no longer meets the daily quota.")
	day_success = true
	day_result_recorded = true
	day_active = false
	seconds_remaining = 0.0
	_set_departure_allowed(true)
	_publish_state()
	day_finished.emit(day_number, day_success, final_wallet_snapshot, daily_quota)
	_log("Day %d ended early: wallet %d / quota %d (%s)." % [day_number, final_wallet_snapshot, daily_quota, "PASS" if day_success else "FAIL"])
	return _success({"day": day_number, "success": day_success, "final_wallet": final_wallet_snapshot, "quota": daily_quota})


func get_snapshot() -> Dictionary:
	return {
		"day_active": day_active,
		"day_number": day_number,
		"starting_wallet": starting_wallet,
		"wallet_balance": current_wallet_balance,
		"daily_quota": daily_quota,
		"seconds_remaining": ceili(seconds_remaining),
		"quota_reached": quota_reached,
		"day_result_recorded": day_result_recorded,
		"day_success": day_success,
		"final_wallet_snapshot": final_wallet_snapshot,
	}


func _cleanup_tables(reason: String) -> void:
	for table: Node in get_tree().get_nodes_in_group("casino_tables"):
		if not is_instance_valid(table) or not table.has_method("request_day_end_cleanup"):
			continue
		var cleanup_result: Dictionary = table.call("request_day_end_cleanup", reason)
		if not bool(cleanup_result.get("ok", false)):
			_log("Table cleanup warning (%s): %s" % [str(table.get("table_id")), str(cleanup_result.get("reason", ""))])


func _get_current_wallet_balance() -> int:
	if not is_instance_valid(_wallet):
		return current_wallet_balance
	var wallet_snapshot: Dictionary = _wallet.call("get_snapshot")
	return int(wallet_snapshot.get("available_balance", current_wallet_balance))


func _set_departure_allowed(allowed: bool) -> void:
	if is_instance_valid(_run_manager):
		_run_manager.call("set_casino_departure_allowed", allowed)


func _publish_state() -> void:
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		_apply_state(get_snapshot())
	else:
		rpc("_rpc_apply_state", get_snapshot())


@rpc("authority", "call_local", "reliable")
func _rpc_apply_state(snapshot: Dictionary) -> void:
	_apply_state(snapshot)


func _apply_state(snapshot: Dictionary) -> void:
	day_active = bool(snapshot.get("day_active", false))
	day_number = int(snapshot.get("day_number", 0))
	starting_wallet = int(snapshot.get("starting_wallet", 0))
	current_wallet_balance = int(snapshot.get("wallet_balance", starting_wallet))
	daily_quota = int(snapshot.get("daily_quota", 0))
	seconds_remaining = float(snapshot.get("seconds_remaining", 0.0))
	quota_reached = bool(snapshot.get("quota_reached", false))
	day_result_recorded = bool(snapshot.get("day_result_recorded", false))
	day_success = bool(snapshot.get("day_success", false))
	final_wallet_snapshot = int(snapshot.get("final_wallet_snapshot", 0))
	day_state_changed.emit(get_snapshot())


func _is_authority() -> bool:
	return multiplayer.is_server()


func _success(data: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"ok": true, "reason": ""}
	result.merge(data, true)
	return result


func _failure(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}


func _log(message: String) -> void:
	if is_instance_valid(_debug_hub):
		_debug_hub.call("log", &"casino_day", message)
