## Shared multiplayer Egg Plinko table.
## Each egg owns an independent CasinoWallet round so launches never block one another.
extends BaseTable

const Rules = preload("res://casino/tables/egg_plinko/egg_plinko_rules.gd")
const EggScript = preload("res://casino/tables/egg_plinko/egg_plinko_egg.gd")
const KeypadControllerScript = preload("res://casino/terminals/components/betting_keypad_controller.gd")

signal egg_launched(egg_record: Dictionary)
signal egg_settled(egg_record: Dictionary, settlement: Dictionary)
signal selected_wager_changed(peer_id: int, amount: int)

@export_group("Scene References")
@export var proximity_area: Area3D
@export var plinko_interactable: Interactable
@export var visuals: Node3D
@export var terminal_display: Node

@export_group("Wager Safety")
@export_range(0.0, 0.75, 0.01) var quota_safety_bias: float = 0.15
@export_range(1, 128, 1) var maximum_airborne_eggs: int = 32
@export_range(0.1, 10.0, 0.1) var egg_flight_duration: float = 3.4

var _network: Node
var _day_manager: Node
var _selected_wagers: Dictionary = {}
var _active_eggs: Dictionary = {}
var _egg_nodes: Dictionary = {}
var _recent_results: Array[Dictionary] = []
var _egg_sequence: int = 1
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	_network = get_node_or_null("/root/Network")
	_day_manager = get_node_or_null("/root/CasinoDayManager")
	_rng.randomize()
	if is_instance_valid(proximity_area):
		proximity_area.body_entered.connect(_on_proximity_body_entered)
		proximity_area.body_exited.connect(_on_proximity_body_exited)
	if is_instance_valid(plinko_interactable):
		plinko_interactable.interacted.connect(_on_plinko_interacted)
	_setup_betting_keypad()
	_update_terminal_status()


func _exit_tree() -> void:
	if is_instance_valid(proximity_area):
		if proximity_area.body_entered.is_connected(_on_proximity_body_entered):
			proximity_area.body_entered.disconnect(_on_proximity_body_entered)
		if proximity_area.body_exited.is_connected(_on_proximity_body_exited):
			proximity_area.body_exited.disconnect(_on_proximity_body_exited)
	if is_instance_valid(plinko_interactable) and plinko_interactable.interacted.is_connected(_on_plinko_interacted):
		plinko_interactable.interacted.disconnect(_on_plinko_interacted)
	super._exit_tree()


## Dynamic limits are recalculated from the live quota and currently available wallet.
## The safety bias protects a configurable share of the quota target, while the live quota gap caps each wager.
func get_wager_limits() -> Dictionary:
	var available: int = _get_available_balance()
	var base_minimum: int = 100
	var base_maximum: int = 5000
	if is_instance_valid(terminal_display):
		var profile: BettingTerminalProfile = terminal_display.get("profile") as BettingTerminalProfile
		if profile != null:
			base_minimum = profile.get_effective_minimum()
			base_maximum = profile.get_effective_maximum()
	var quota: int = int(_day_manager.get("daily_quota")) if is_instance_valid(_day_manager) and bool(_day_manager.get("day_active")) else 0
	var quota_remaining: int = maxi(quota - available, 0)
	var safety_reserve: int = ceili(float(quota) * quota_safety_bias)
	var spendable: int = maxi(available - safety_reserve, 0)
	var quota_cap: int = quota_remaining if quota_remaining > 0 else spendable
	var maximum: int = mini(base_maximum, mini(spendable, quota_cap))
	var minimum: int = base_minimum
	if quota_remaining > 0:
		minimum = mini(base_minimum, maxi(1, quota_remaining))
	if maximum > 0:
		minimum = mini(minimum, maximum)
	else:
		minimum = 0
	return {
		"minimum": minimum,
		"maximum": maximum,
		"available_balance": available,
		"quota": quota,
		"quota_remaining": quota_remaining,
		"safety_reserve": safety_reserve,
		"spendable_balance": spendable,
	}


## Called by the shared keypad in selection-only mode. No money is reserved here.
func set_selected_wager(peer_id: int, amount: int) -> Dictionary:
	if not _is_authority():
		return _failure("Only the host can change the selected Plinko wager.")
	if not _is_near_table(peer_id):
		return _failure("Move closer to the Plinko table before selecting a wager.")
	var limits: Dictionary = get_wager_limits()
	var minimum: int = int(limits["minimum"])
	var maximum: int = int(limits["maximum"])
	if amount < minimum or amount > maximum:
		return _failure("Selected wager must be between %d and %d." % [minimum, maximum])
	_selected_wagers[peer_id] = amount
	selected_wager_changed.emit(peer_id, amount)
	if multiplayer.multiplayer_peer != null:
		_rpc_sync_selected_wager.rpc(peer_id, amount)
	_update_terminal_status()
	return _success({"peer_id": peer_id, "selected_wager": amount, "limits": limits})


@rpc("authority", "call_remote", "reliable")
func _rpc_sync_selected_wager(peer_id: int, amount: int) -> void:
	_selected_wagers[peer_id] = amount
	selected_wager_changed.emit(peer_id, amount)
	_update_terminal_status()


func get_selected_wager(peer_id: int) -> int:
	return int(_selected_wagers.get(peer_id, 0))


## BaseTable's shared terminal queries this method; expose all currently airborne eggs.
func get_round_wagers() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not is_instance_valid(_wallet):
		return result
	for egg_id_value: Variant in _active_eggs.keys():
		var record: Dictionary = _active_eggs[egg_id_value]
		var wager: Dictionary = _wallet.call("get_wager", str(record.get("wager_id", "")))
		if not wager.is_empty():
			result.append(wager)
	return result


## Plinko keeps BaseTable's round state idle because each egg owns its own wallet round.
## Resolve every airborne egg explicitly when the casino day ends or the team departs.
func request_day_end_cleanup(reason: String) -> Dictionary:
	if not _is_authority():
		return _failure("Only the host can clean up Egg Plinko.")
	if reason.strip_edges().is_empty():
		return _failure("A cleanup reason is required.")
	var egg_ids: Array[String] = []
	for egg_id_value: Variant in _active_eggs.keys():
		egg_ids.append(str(egg_id_value))
	var settled_count: int = 0
	var settled_ids: Array[String] = []
	var failed_ids: Array[String] = []
	for egg_id: String in egg_ids:
		if not _active_eggs.has(egg_id):
			continue
		var record: Dictionary = _active_eggs[egg_id]
		var payouts: Dictionary = {str(record["wager_id"]): int(record["gross_return"])}
		var settlement: Dictionary = _wallet.call("settle_round", table_id, str(record["round_id"]), payouts)
		if not bool(settlement.get("ok", false)):
			failed_ids.append(egg_id)
			push_error("Egg Plinko day-end settlement failed for %s: %s" % [egg_id, str(settlement.get("reason", ""))])
			continue
		var result_record: Dictionary = record.duplicate(true)
		result_record["status"] = "settled"
		result_record["finish_reason"] = reason
		_recent_results.append(result_record)
		while _recent_results.size() > 8:
			_recent_results.pop_front()
		egg_settled.emit(result_record, settlement.duplicate(true))
		_active_eggs.erase(egg_id)
		var egg_node: Node = _egg_nodes.get(egg_id) as Node
		if is_instance_valid(egg_node):
			egg_node.queue_free()
		_egg_nodes.erase(egg_id)
		settled_ids.append(egg_id)
		settled_count += 1
	_selected_wagers.clear()
	if multiplayer.multiplayer_peer != null:
		_rpc_clear_active_eggs.rpc(settled_ids)
	_publish_keypad_snapshot()
	_update_terminal_status()
	if not failed_ids.is_empty():
		return _failure("Could not settle airborne eggs: %s" % ", ".join(failed_ids))
	return _success({"round_id": "", "action": "settled_in_flight", "settled_count": settled_count})


@rpc("authority", "call_remote", "reliable")
func _rpc_clear_active_eggs(egg_ids: Array[String]) -> void:
	for egg_id: String in egg_ids:
		_active_eggs.erase(egg_id)
		var egg_node: Node = _egg_nodes.get(egg_id) as Node
		if is_instance_valid(egg_node):
			egg_node.queue_free()
		_egg_nodes.erase(egg_id)
	_selected_wagers.clear()
	_update_terminal_status()


func get_active_egg_records() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record_value: Variant in _active_eggs.values():
		var record: Dictionary = record_value
		result.append(record.duplicate(true))
	return result


func request_plinko_drop() -> Dictionary:
	if multiplayer.is_server():
		return _handle_plinko_drop(multiplayer.get_unique_id())
	if multiplayer.multiplayer_peer == null:
		return _failure("No multiplayer session is active.")
	_rpc_request_plinko_drop.rpc_id(1)
	return {"ok": true, "reason": "", "pending": true}


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_plinko_drop() -> void:
	if not multiplayer.is_server() or not _validate_remote_action_sender():
		return
	_handle_plinko_drop(multiplayer.get_remote_sender_id())


func _handle_plinko_drop(peer_id: int) -> Dictionary:
	if not _is_authority():
		return _failure("Only the host can launch Plinko eggs.")
	if not _is_near_table(peer_id):
		return _reject_drop(peer_id, "Move closer to the Plinko table to launch an egg.")
	if _active_eggs.size() >= maximum_airborne_eggs:
		return _reject_drop(peer_id, "The Plinko board is full. Wait for an egg to land.")
	var stake: int = get_selected_wager(peer_id)
	if stake <= 0:
		return _reject_drop(peer_id, "Select and confirm a wager before pressing PLINKO.")
	var limits: Dictionary = get_wager_limits()
	if stake < int(limits["minimum"]) or stake > int(limits["maximum"]):
		return _reject_drop(peer_id, "Your selected wager is no longer within the live limits.")
	if stake > int(limits["spendable_balance"]):
		return _reject_drop(peer_id, "The shared wallet safety reserve prevents this wager.")

	var egg_sequence: int = _egg_sequence
	_egg_sequence += 1
	var egg_id: String = "%s_E%06d" % [table_id, egg_sequence]
	var round_id: String = "drop_%d_%06d" % [Time.get_ticks_usec(), egg_sequence]
	var path_result: Dictionary = Rules.build_path(_rng)
	var slot_index: int = int(path_result["slot_index"])
	var multiplier: float = float(path_result["multiplier"])
	var gross_return: int = Rules.calculate_gross_return(stake, multiplier)

	# Each egg has its own short-lived wallet round. All calls are synchronous on
	# the host, so the full stake is atomically reserved before another launch runs.
	var open_result: Dictionary = _wallet.call("open_round", table_id, round_id)
	if not bool(open_result.get("ok", false)):
		return _reject_drop(peer_id, str(open_result.get("reason", "Could not open an egg wager.")))
	var wager_result: Dictionary = _wallet.call("reserve_wager", peer_id, table_id, round_id, stake, {
		"egg_id": egg_id,
		"slot_index": slot_index,
		"multiplier": multiplier,
	})
	if not bool(wager_result.get("ok", false)):
		_wallet.call("cancel_open_round", table_id, round_id)
		return _reject_drop(peer_id, str(wager_result.get("reason", "The shared wallet rejected this egg wager.")))
	var wager_id: String = str(wager_result.get("wager_id", ""))
	var lock_result: Dictionary = _wallet.call("lock_round", table_id, round_id)
	if not bool(lock_result.get("ok", false)):
		_wallet.call("cancel_open_round", table_id, round_id)
		return _reject_drop(peer_id, str(lock_result.get("reason", "Could not lock the egg wager.")))

	var color_index: int = _get_player_color_index(peer_id)
	var record: Dictionary = {
		"egg_id": egg_id,
		"round_id": round_id,
		"wager_id": wager_id,
		"peer_id": peer_id,
		"nickname": _get_player_nickname(peer_id),
		"color_index": color_index,
		"player_color": PlayerIdentity.color_for_index(color_index),
		"stake": stake,
		"slot_index": slot_index,
		"multiplier": multiplier,
		"gross_return": gross_return,
		"path": path_result["path"],
		"flight_duration": egg_flight_duration,
	}
	_active_eggs[egg_id] = record
	_spawn_egg_visual(record)
	if multiplayer.multiplayer_peer != null:
		_rpc_spawn_egg.rpc(record)
	egg_launched.emit(record.duplicate(true))
	_publish_keypad_snapshot()
	report_player_feedback(peer_id, "EGG LAUNCHED  /  %s AT %.1fX" % [_format_money(stake), multiplier], &"success")
	_update_terminal_status()
	return _success({"egg_id": egg_id, "wager_id": wager_id, "stake": stake, "multiplier": multiplier, "slot_index": slot_index})


func _reject_drop(peer_id: int, message: String) -> Dictionary:
	report_player_feedback(peer_id, message, &"error")
	return _failure(message)


func _spawn_egg_visual(record: Dictionary) -> void:
	if not is_instance_valid(visuals):
		return
	var egg: EggPlinkoEgg = EggScript.new() as EggPlinkoEgg
	egg.name = "Egg_%s" % str(record.get("egg_id", "Unknown"))
	egg.configure(record)
	egg.animation_finished.connect(_on_egg_animation_finished)
	visuals.add_child(egg)
	_egg_nodes[str(record.get("egg_id", ""))] = egg


@rpc("authority", "call_remote", "reliable")
func _rpc_spawn_egg(record: Dictionary) -> void:
	var egg_id: String = str(record.get("egg_id", ""))
	if egg_id.is_empty() or _egg_nodes.has(egg_id):
		return
	_active_eggs[egg_id] = record.duplicate(true)
	_spawn_egg_visual(record)
	_update_terminal_status()


func _on_egg_animation_finished(egg_id: String) -> void:
	if not _active_eggs.has(egg_id):
		return
	var record: Dictionary = _active_eggs[egg_id]
	if _is_authority():
		var payouts: Dictionary = {str(record["wager_id"]): int(record["gross_return"])}
		var settlement: Dictionary = _wallet.call("settle_round", table_id, str(record["round_id"]), payouts)
		if not bool(settlement.get("ok", false)):
			push_error("Egg Plinko settlement failed for %s: %s" % [egg_id, str(settlement.get("reason", ""))])
			return
		else:
			var result_record: Dictionary = record.duplicate(true)
			result_record["status"] = "settled"
			_recent_results.append(result_record)
			while _recent_results.size() > 8:
				_recent_results.pop_front()
			egg_settled.emit(result_record, settlement.duplicate(true))
			report_global_announcement("%s LANDED  /  %.1fX  /  %s" % [
				str(record["nickname"]).to_upper(),
				float(record["multiplier"]),
				_format_money(int(record["gross_return"]))
			], "EGG PLINKO", 1)
	_active_eggs.erase(egg_id)
	var egg_node: Node = _egg_nodes.get(egg_id) as Node
	if is_instance_valid(egg_node):
		egg_node.queue_free()
	_egg_nodes.erase(egg_id)
	_publish_keypad_snapshot()
	_update_terminal_status()


func _publish_keypad_snapshot() -> void:
	var controller: Node = get_node_or_null("BettingKeypad/BettingKeypadController")
	if is_instance_valid(controller) and controller.has_method("_publish_snapshot"):
		controller.call("_publish_snapshot")


func _setup_betting_keypad() -> void:
	var keypad: Node = get_node_or_null("BettingKeypad")
	if not is_instance_valid(keypad) or not is_instance_valid(terminal_display):
		return
	if keypad.get_node_or_null("BettingKeypadController") != null:
		return
	var controller: Node = KeypadControllerScript.new()
	controller.name = "BettingKeypadController"
	controller.set("table", self)
	controller.set("display", terminal_display)
	controller.set("profile", terminal_display.get("profile"))
	controller.set("one_wager_per_player", false)
	controller.set("selection_only", true)
	keypad.add_child(controller)


func _on_proximity_body_entered(body: Node3D) -> void:
	if not _is_authority():
		return
	var peer_id: int = _peer_id_for_actor(body)
	if peer_id > 0:
		enter_proximity(peer_id)


func _on_proximity_body_exited(body: Node3D) -> void:
	if not _is_authority():
		return
	var peer_id: int = _peer_id_for_actor(body)
	if peer_id > 0 and _is_near_table(peer_id):
		exit_proximity(peer_id)


func _on_plinko_interacted(actor: Node, action: StringName) -> void:
	if action != &"use" or not is_instance_valid(actor):
		return
	var peer_id: int = _peer_id_for_actor(actor)
	if peer_id <= 0:
		return
	if multiplayer.is_server():
		_handle_plinko_drop(peer_id)
	elif multiplayer.multiplayer_peer != null:
		_rpc_request_plinko_drop.rpc_id(1)


func _peer_id_for_actor(actor: Node) -> int:
	if not is_instance_valid(actor):
		return 0
	for property_info: Dictionary in actor.get_property_list():
		if str(property_info.get("name", "")) == "input_peer_id":
			var peer_value: Variant = actor.get("input_peer_id")
			if typeof(peer_value) == TYPE_INT:
				var peer_id: int = int(peer_value)
				if peer_id > 0:
					return peer_id
	if is_instance_valid(_network) and _network.get("peer") == null:
		return multiplayer.get_unique_id()
	return 0


func _validate_remote_action_sender() -> bool:
	return is_instance_valid(_network) and _network.has_method("validate_rpc") and bool(_network.call("validate_rpc"))


func _get_available_balance() -> int:
	if not is_instance_valid(_wallet):
		return 0
	var snapshot: Dictionary = _wallet.call("get_snapshot")
	return int(snapshot.get("available_balance", 0))


func _get_player_color_index(peer_id: int) -> int:
	if is_instance_valid(_network) and _network.has_method("get_player_identity"):
		var identity: PlayerIdentity = _network.call("get_player_identity", peer_id) as PlayerIdentity
		if identity != null:
			return identity.color_index
	return posmod(peer_id - 1, PlayerIdentity.palette_size())


func _get_player_nickname(peer_id: int) -> String:
	if is_instance_valid(_network) and _network.has_method("get_player_identity"):
		var identity: PlayerIdentity = _network.call("get_player_identity", peer_id) as PlayerIdentity
		if identity != null and not identity.nickname.strip_edges().is_empty():
			return identity.nickname
	return "PLAYER %d" % peer_id


func _update_terminal_status() -> void:
	if not is_instance_valid(terminal_display):
		return
	if terminal_display.has_method("refresh_display"):
		terminal_display.call("refresh_display")
	var world_screen: Node = get_node_or_null("SlimWorldScreen/WorldScreen")
	if world_screen != null and world_screen.has_method("set_content"):
		var lines: Array[String] = []
		for peer_value: Variant in _selected_wagers.keys():
			var peer_id: int = int(peer_value)
			lines.append("%s  SELECTED %s" % [_get_player_nickname(peer_id).to_upper(), _format_money(int(_selected_wagers[peer_id]))])
		lines.append("EGGS AIRBORNE: %d" % _active_eggs.size())
		var body: String = "\n".join(lines) if not lines.is_empty() else "SELECT A WAGER  /  PRESS PLINKO TO DROP AN EGG"
		world_screen.call("set_content", "EGG PLINKO  |  LIVE BOARD", body, "ONE WAGER PER EGG  /  SHARED WALLET")


func _format_money(amount: int) -> String:
	var digits: String = str(maxi(amount, 0))
	var formatted: String = ""
	for index: int in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			formatted += ","
		formatted += digits.substr(index, 1)
	return "$" + formatted

