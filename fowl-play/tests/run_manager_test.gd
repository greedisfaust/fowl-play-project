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
	transition_source.emit_signal("world_changed", 1, 0)
	if int(manager.call("get_snapshot").get("phase", -1)) != 3:
		_finish(false, "Completing Casino to Apartment should advance into the Rest phase.")
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
	var repeated_start: Dictionary = manager.call("begin_new_run")
	if bool(repeated_start.get("ok", false)):
		_finish(false, "A second run must not overwrite an active run.")
		return

	transition_source.free()
	_finish(true, "Day 1 initialization, MainController arrival signal, Apartment/Casino/Rest-phase flow, quota gate, and day increment")


func _finish(passed: bool, message: String) -> void:
	if passed:
		print("RUN MANAGER PASS: %s" % message)
		quit(0)
	else:
		push_error("RUN MANAGER FAIL: %s" % message)
		quit(1)
