## Headless checks for dynamic quota calculation and casino-day timing.
extends SceneTree

const CasinoDayManagerScript = preload("res://casino/casino_day_manager.gd")
var _failed: bool = false
var _day_finished_count: int = 0

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var manager: Node = root.get_node_or_null("CasinoDayManager")
	if not is_instance_valid(manager):
		_finish(false, "CasinoDayManager autoload was not registered.")
		return

	_check(CasinoDayManagerScript.calculate_daily_quota(1000, 1) == 1750, "Day 1 quota from 1,000 wallet")
	_check(CasinoDayManagerScript.calculate_daily_quota(2000, 2) == 3560, "Day 2 quota recalculates from carried 2,000 wallet")
	_check(CasinoDayManagerScript.calculate_daily_quota(1000, 10) == 2200, "Day 10 multiplier")
	_check(CasinoDayManagerScript.calculate_daily_quota(1000, 0) == -1, "Invalid day is rejected")
	_check(CasinoDayManagerScript.calculate_daily_quota(-1, 1) == -1, "Negative wallet is rejected")

	manager.set("casino_day_duration_seconds", 300.0)
	var day_finished_callback: Callable = Callable(self, "_on_day_finished")
	manager.connect("day_finished", day_finished_callback)
	var day_one: Dictionary = manager.call("begin_casino_day", 1, 1000)
	if not bool(day_one.get("ok", false)):
		_finish(false, "Day 1 should initialize: %s" % str(day_one.get("reason", "")))
		return
	var snapshot: Dictionary = manager.call("get_snapshot")
	_check(int(snapshot.get("starting_wallet", 0)) == 1000, "Day 1 stores its actual starting wallet")
	_check(int(snapshot.get("daily_quota", 0)) == 1750, "Day 1 stores the calculated quota")
	_check(bool(snapshot.get("day_active", false)), "Day 1 timer starts active")
	_check(int(snapshot.get("seconds_remaining", 0)) == 300, "Casino day starts with five minutes")

	manager.call("advance_day_timer", 1.0, 1750)
	snapshot = manager.call("get_snapshot")
	_check(bool(snapshot.get("quota_reached", false)), "Reaching quota unlocks early departure")
	_check(bool(snapshot.get("day_active", false)), "Reaching quota does not automatically end the day")
	_check(int(snapshot.get("seconds_remaining", 0)) == 299, "Timer continues after quota is reached")

	# A later wager can reduce the available wallet after the quota was met.
	manager.call("advance_day_timer", 1.0, 1280)
	snapshot = manager.call("get_snapshot")
	_check(not bool(snapshot.get("quota_reached", true)), "Dropping below quota revokes the reached state")
	_check(int(snapshot.get("wallet_balance", 0)) == 1280, "Wallet snapshot reflects the later loss")
	var rejected_departure: Dictionary = manager.call("finish_early_departure", 1280)
	_check(not bool(rejected_departure.get("ok", true)), "Early departure is rejected when the current wallet is below quota")
	_check(bool(manager.get("day_active")), "Rejected departure leaves the casino day active")
	_check(not bool(manager.get("day_result_recorded")), "Rejected departure does not record a day result")

	# Reaching the target again should unlock departure again.
	manager.call("advance_day_timer", 1.0, 1780)
	snapshot = manager.call("get_snapshot")
	_check(bool(snapshot.get("quota_reached", false)), "Regaining the quota unlocks early departure again")

	var early_result: Dictionary = manager.call("finish_early_departure", 1800)
	_check(bool(early_result.get("ok", false)), "Early departure succeeds after quota is reached")
	snapshot = manager.call("get_snapshot")
	_check(bool(snapshot.get("day_result_recorded", false)), "Early departure records the day result")
	_check(bool(snapshot.get("day_success", false)), "Early departure records success when final wallet exceeds quota")
	_check(int(snapshot.get("final_wallet_snapshot", 0)) == 1800, "Early departure records the final wallet snapshot")
	_check(not bool(snapshot.get("day_active", true)), "Early departure stops the timer")
	_check(_day_finished_count == 1, "Early departure emits one day-finished signal")

	var day_two: Dictionary = manager.call("begin_casino_day", 2, 2000)
	if not bool(day_two.get("ok", false)):
		_finish(false, "Day 2 should initialize from carried wallet: %s" % str(day_two.get("reason", "")))
		return
	snapshot = manager.call("get_snapshot")
	_check(int(snapshot.get("starting_wallet", 0)) == 2000, "Day 2 starts with the full carried wallet")
	_check(int(snapshot.get("daily_quota", 0)) == 3560, "Day 2 quota uses its new starting wallet")
	manager.call("advance_day_timer", 300.0, 3559)
	snapshot = manager.call("get_snapshot")
	_check(bool(snapshot.get("day_result_recorded", false)), "Five-minute deadline records a result")
	_check(not bool(snapshot.get("day_success", true)), "Wallet one below quota fails at deadline")
	_check(int(snapshot.get("final_wallet_snapshot", 0)) == 3559, "Deadline snapshots wallet before table cleanup")
	_check(int(snapshot.get("seconds_remaining", -1)) == 0, "Deadline stops the timer")
	_check(_day_finished_count == 2, "Five-minute deadline emits day-finished for the forced elevator return")
	manager.disconnect("day_finished", day_finished_callback)

	if _failed:
		quit(1)
		return
	print("CASINO DAY PASS: dynamic quota, live quota revocation, re-unlock, carried wallet, five-minute timer, early departure, and deadline snapshot")
	quit(0)


func _on_day_finished(_day_number: int, _success: bool, _final_wallet: int, _quota: int) -> void:
	_day_finished_count += 1


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failed = true
		push_error("CASINO DAY FAIL: %s" % label)


func _finish(passed: bool, message: String) -> void:
	if passed:
		print("CASINO DAY PASS: %s" % message)
		quit(0)
	else:
		push_error("CASINO DAY FAIL: %s" % message)
		quit(1)
