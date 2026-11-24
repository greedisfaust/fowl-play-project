## Cluckpot rules and four-machine scene integration checks.
extends SceneTree

const Rules = preload("res://casino/tables/cluckpot/cluckpot_rules.gd")
const ArcadeScene: PackedScene = preload("res://casino/tables/cluckpot/cluckpot_arcade.tscn")
var _failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check(Rules.PAYOUTS["SEVEN"] > Rules.PAYOUTS["ROOSTER"], "Golden 7 is the top regular symbol payout")
	_check(Rules.PAYOUTS["WILD"] > Rules.PAYOUTS["ROOSTER"], "Golden Chicken wild has a premium payout")
	var seven_columns: Array = [
		["SEVEN", "CHICK", "EGG"],
		["SEVEN", "CORN", "CORN"],
		["SEVEN", "EGG", "FEATHER"],
	]
	var seven_wins: Array[Dictionary] = Rules.evaluate_lines(seven_columns)
	_check(not seven_wins.is_empty() and str(seven_wins[0].get("symbol", "")) == "SEVEN", "Three Golden 7s form a winning line")
	_check(Rules.calculate_payout(100, {"line_wins": seven_wins}) >= 2800, "Golden 7 line pays the top multiplier")
	var wild_columns: Array = [
		["ROOSTER", "CHICK", "EGG"],
		["WILD", "CORN", "FEATHER"],
		["ROOSTER", "EGG", "CORN"],
	]
	var wild_wins: Array[Dictionary] = Rules.evaluate_lines(wild_columns)
	var found_rooster: bool = false
	for win: Dictionary in wild_wins:
		if str(win.get("symbol", "")) == "ROOSTER":
			found_rooster = true
	_check(found_rooster, "Golden Chicken wild substitutes into a matching rooster line")

	var arcade: Node3D = ArcadeScene.instantiate() as Node3D
	_check(is_instance_valid(arcade), "Cluckpot arcade scene instantiates")
	if not is_instance_valid(arcade):
		_finish()
		return
	root.add_child(arcade)
	await process_frame
	_check(arcade.get_child_count() == 4, "The arcade scene contains exactly four concurrent machines")
	var table_ids: Dictionary = {}
	var first_machine: BaseTable
	for child: Node in arcade.get_children():
		_check(child is BaseTable, "Every cabinet has its own BaseTable controller")
		if not child is BaseTable:
			continue
		var machine: BaseTable = child as BaseTable
		var id: String = str(machine.get("table_id"))
		_check(not table_ids.has(id), "Every machine has a unique wallet table ID")
		table_ids[id] = true
		_check(machine.get_node_or_null("BettingKeypad/BettingKeypadController") != null, "Every machine has an independent shared BettingKeypad controller")
		var reels: Node = machine.get_node_or_null("Visuals/Cabinet/Reels")
		_check(is_instance_valid(reels) and reels.get_child_count() == 3, "Every cabinet builds three physical reel columns")
		if first_machine == null:
			first_machine = machine
	_check(table_ids.size() == 4, "All four machine IDs are unique")

	if is_instance_valid(first_machine):
		var wallet: Node = root.get_node_or_null("CasinoWallet")
		var day_manager: Node = root.get_node_or_null("CasinoDayManager")
		if is_instance_valid(wallet) and is_instance_valid(day_manager):
			_check_result(wallet.call("begin_run", 10000), "Initialize shared wallet")
			_check_result(day_manager.call("begin_casino_day", 1, 17500), "Start casino quota snapshot")
			first_machine.set("spin_duration", 1.0)
			_check_result(first_machine.call("enter_proximity", 1), "Register test player near a machine")
			var limits: Dictionary = first_machine.call("get_wager_limits")
			var stake: int = int(limits.get("minimum", 0))
			_check_result(first_machine.call("set_selected_wager", 1, stake), "Select wager through shared limits")
			var spin: Dictionary = first_machine.call("_handle_spin", 1)
			_check(bool(spin.get("ok", false)), "Host accepts a valid slot spin")
			await create_timer(2.0).timeout
			var wallet_snapshot: Dictionary = wallet.call("get_snapshot")
			_check(int(wallet_snapshot.get("reserved_total", 0)) == 0, "Spin settlement releases the reserved wager")
			var wager: Dictionary = wallet.call("get_wager", str(spin.get("wager_id", "")))
			_check(not wager.is_empty(), "The spin returns a verifiable wallet wager ID")
			if not wager.is_empty():
				_check(str(wager.get("status", "")) == "settled", "The spin's wallet wager settles exactly once")

	arcade.queue_free()
	_finish()


func _check_result(result: Dictionary, label: String) -> void:
	_check(bool(result.get("ok", false)), "%s: %s" % [label, str(result.get("reason", ""))])


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failed = true
		push_error("CLUCKPOT FAIL: " + label)


func _finish() -> void:
	if _failed:
		quit(1)
		return
	print("CLUCKPOT PASS: Golden 7 payouts, Golden Chicken wild, four independent machines, shared keypads, and host settlement")
	quit(0)
