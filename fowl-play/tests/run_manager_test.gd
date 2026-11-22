## Offline tests for the persistent RunManager autoload.
extends SceneTree

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var manager: Node = root.get_node_or_null("RunManager")
	if manager == null:
		_finish(false, "RunManager autoload was not registered.")
		return

	var transition_source: Node = Node.new()
	transition_source.add_user_signal("world_changed", [
		{"name": "previous_world", "type": TYPE_INT},
		{"name": "current_world", "type": TYPE_INT},
	])
	manager.call("bind_main_controller", transition_source)

	var start_result: Dictionary = manager.call("begin_new_run")
	if not bool(start_result.get("ok", false)):
		_finish(false, "A new run should begin successfully: %s" % str(start_result.get("reason", "")))
		return
	var wallet: Node = root.get_node_or_null("CasinoWallet")
	if not is_instance_valid(wallet):
		_finish(false, "CasinoWallet autoload should be available.")
		return
	var wallet_snapshot: Dictionary = wallet.call("get_snapshot")
	if not bool(wallet_snapshot.get("run_active", false)) or int(wallet_snapshot.get("initial_balance", -1)) != 1000 or int(wallet_snapshot.get("available_balance", -1)) != 1000:
		_finish(false, "A fresh run should initialize the wallet ledger and available balance to 1,000.")
		return
	var snapshot: Dictionary = manager.call("get_snapshot")
	if not bool(snapshot.get("run_active", false)) or int(snapshot.get("current_day", 0)) != 1 or int(snapshot.get("phase", -1)) != 1:
		_finish(false, "A new run should start active on Day 1 in the Apartment.")
		return

	if int(manager.call("get_departure_destination", 0)) != 1:
		_finish(false, "Apartment departure should lead to the Casino.")
		return
	if int(manager.call("get_departure_destination", 2)) != -1:
		_finish(false, "The Apartment phase should reject a departure from an invalid world ID.")
		return
	transition_source.emit_signal("world_changed", 0, 1)
	if int(manager.call("get_snapshot").get("phase", -1)) != 2:
		_finish(false, "Completing Apartment to Casino should advance the phase.")
		return

	snapshot = manager.call("get_snapshot")
	if int(snapshot.get("phase", -1)) != 2 or int(snapshot.get("current_day", 0)) != 1:
		_finish(false, "Entering the Casino should preserve Day 1 and set the Casino phase.")
		return
	if int(manager.call("get_departure_destination", 1)) != -1:
		_finish(false, "Casino departure must remain locked until quota/deadline logic allows it.")
		return
	if not bool(manager.call("set_casino_departure_allowed", true)):
		_finish(false, "The host should be able to unlock Casino departure during the Casino phase.")
		return
	if int(manager.call("get_departure_destination", 1)) != 0:
		_finish(false, "An unlocked Casino departure should return to the Apartment for the Rest phase.")
		return
	var day_manager: Node = root.get_node_or_null("CasinoDayManager")
	if not is_instance_valid(day_manager) or not bool(day_manager.get("day_active")):
		_finish(false, "Day 1 casino state should be active before its deadline is simulated.")
		return
	day_manager.call("advance_day_timer", 300.0, 1000)
	if bool(day_manager.get("day_active")) or not bool(day_manager.get("day_result_recorded")):
		_finish(false, "Simulating the deadline should close Day 1 before entering Rest.")
		return
	transition_source.emit_signal("world_changed", 1, 0)
	snapshot = manager.call("get_snapshot")
	if int(snapshot.get("phase", -1)) != 3:
		_finish(false, "Completing Casino to Apartment should advance into the Rest phase.")
		return
	if not bool(snapshot.get("continuation_used", false)) or int(snapshot.get("continuation_loan_amount", 0)) != 500:
		_finish(false, "The first failed quota should consume the one-time 50% House continuation.")
		return
	wallet_snapshot = wallet.call("get_snapshot")
	if int(wallet_snapshot.get("available_balance", 0)) != 1500:
		_finish(false, "The House continuation should be added to the remaining shared wallet.")
		return
	if int(manager.call("get_departure_destination", 0)) != 1:
		_finish(false, "Apartment Rest-phase departure should lead to the next Casino day.")
		return
	transition_source.emit_signal("world_changed", 0, 1)
	if int(manager.call("get_snapshot").get("current_day", 0)) != 2:
		_finish(false, "Completing Apartment Rest phase to Casino should advance the day.")
		return

	snapshot = manager.call("get_snapshot")
	if int(snapshot.get("current_day", 0)) != 2 or int(snapshot.get("phase", -1)) != 2:
		_finish(false, "Returning from the Apartment Rest phase should begin Day 2 in the Casino.")
		return
	if not bool(day_manager.get("day_active")) or int(day_manager.get("starting_wallet")) != 1500 or int(day_manager.get("daily_quota")) != 2670:
		_finish(false, "Day 2 should start with the continued wallet and recalculate its quota.")
		return
	day_manager.call("advance_day_timer", 300.0, 2670)
	transition_source.emit_signal("world_changed", 1, 0)
	if int(manager.call("get_snapshot").get("phase", -1)) != 3:
		_finish(false, "A successful Day 2 should enter the Apartment Rest phase.")
		return
	transition_source.emit_signal("world_changed", 0, 1)
	if int(manager.call("get_snapshot").get("current_day", 0)) != 3:
		_finish(false, "A successful Day 2 should advance the next Casino day to Day 3.")
		return
	var repeated_start: Dictionary = manager.call("begin_new_run")
	if bool(repeated_start.get("ok", false)):
		_finish(false, "A second run must not overwrite an active run.")
		return

	if not bool(day_manager.get("day_active")) or int(day_manager.get("day_number")) != 3:
		_finish(false, "The Day 2 casino state should be active before session cleanup is tested.")
		return

	var reset_ok: bool = bool(manager.call("reset_for_session_end"))
	if not reset_ok:
		_finish(false, "RunManager should permit local reset after the network session ends.")
		return
	snapshot = manager.call("get_snapshot")
	if bool(snapshot.get("run_active", true)) or int(snapshot.get("current_day", -1)) != 0 or int(snapshot.get("phase", -1)) != 0:
		_finish(false, "Session reset should return progression to IDLE with no active day.")
		return
	var wallet_after_reset: Dictionary = wallet.call("get_snapshot")
	if bool(wallet_after_reset.get("run_active", true)) or int(wallet_after_reset.get("available_balance", -1)) != 0:
		_finish(false, "Session reset should clear the local wallet ledger.")
		return
	if bool(day_manager.get("day_active")) or int(day_manager.get("day_number")) != 0:
		_finish(false, "Session reset should clear the local casino-day state.")
		return

	transition_source.free()
	_finish(true, "Day 1 failure continuation loan, carried wallet and recalculated Day 2 quota, successful progression to Day 3, and session cleanup")


func _finish(passed: bool, message: String) -> void:
	if passed:
		print("RUN MANAGER PASS: %s" % message)
		quit(0)
	else:
		push_error("RUN MANAGER FAIL: %s" % message)
		quit(1)
