## Host-authoritative Perya color table. Every color click reserves a distinct wager.
extends BaseTable
class_name PeryaTable

const Rules = preload("res://casino/tables/perya/perya_rules.gd")
const KeypadControllerScript = preload("res://casino/terminals/components/betting_keypad_controller.gd")
const IdentityScript = preload("res://core/player_identity.gd")

@export var proximity_area: Area3D
@export var visuals: PeryaVisualBuilder
@export var terminal_display: Node
@export var roll_interactable: Interactable

var _network: Node
var _rng := RandomNumberGenerator.new()
var _selected_wagers: Dictionary = {}
var _bet_visual_totals: Dictionary = {}
var _round_dice: Array[int] = []
var _rolling: bool = false
var _round_serial: int = 0
var _last_result_line: String = ""

func _ready() -> void:
	super._ready()
	_network = get_node_or_null("/root/Network")
	_rng.randomize()
	if not is_instance_valid(roll_interactable) and is_instance_valid(visuals):
		roll_interactable = visuals.roll_interactable
	if is_instance_valid(proximity_area):
		proximity_area.body_entered.connect(_on_proximity_entered)
		proximity_area.body_exited.connect(_on_proximity_exited)
	if is_instance_valid(visuals):
		for zone in visuals.color_zones:
			var interactable := zone.get_parent().get_node_or_null("Interactable") as Interactable
			if is_instance_valid(interactable):
				interactable.interacted.connect(_on_color_interacted.bind(int(interactable.get_meta("perya_color_index", -1))))
	if is_instance_valid(roll_interactable):
		roll_interactable.interacted.connect(_on_roll_interacted)
	round_auto_resolution_requested.connect(_on_auto_resolution_requested)
	round_cancelled.connect(_on_round_cancelled)
	_setup_betting_keypad()
	_update_terminal_status()

func _exit_tree() -> void:
	if is_instance_valid(proximity_area):
		if proximity_area.body_entered.is_connected(_on_proximity_entered):
			proximity_area.body_entered.disconnect(_on_proximity_entered)
		if proximity_area.body_exited.is_connected(_on_proximity_exited):
			proximity_area.body_exited.disconnect(_on_proximity_exited)
	if is_instance_valid(roll_interactable) and roll_interactable.interacted.is_connected(_on_roll_interacted):
		roll_interactable.interacted.disconnect(_on_roll_interacted)
	if is_instance_valid(visuals):
		for zone in visuals.color_zones:
			var interactable := zone.get_parent().get_node_or_null("Interactable") as Interactable
			if is_instance_valid(interactable):
				for connection in interactable.interacted.get_connections():
					if connection.callable.get_object() == self:
						interactable.interacted.disconnect(connection.callable)
	if round_cancelled.is_connected(_on_round_cancelled):
		round_cancelled.disconnect(_on_round_cancelled)
	if round_auto_resolution_requested.is_connected(_on_auto_resolution_requested):
		round_auto_resolution_requested.disconnect(_on_auto_resolution_requested)
	super._exit_tree()

## Keep physical chip stacks consistent with BaseTable's pre-start departure refunds.
func exit_proximity(peer_id: int) -> Dictionary:
	var result: Dictionary = super.exit_proximity(peer_id)
	if bool(result.get("ok", false)) and state == TableState.OPEN:
		_rebuild_chip_stacks_from_wagers()
	return result

func _rebuild_chip_stacks_from_wagers() -> void:
	var records: Array[Dictionary] = []
	for wager in get_round_wagers():
		if str(wager.get("status", "")) != "reserved":
			continue
		var payload: Dictionary = wager.get("payload", {})
		var peer_id := int(wager.get("peer_id", 0))
		var color_index := int(payload.get("color_index", -1))
		records.append(_build_bet_presentation(peer_id, color_index, int(wager.get("stake", 0)), str(wager.get("wager_id", ""))))
	_apply_chip_snapshot(records)
	if multiplayer.multiplayer_peer != null:
		_rpc_sync_chip_snapshot.rpc(records)

@rpc("authority", "call_remote", "reliable")
func _rpc_sync_chip_snapshot(records: Array[Dictionary]) -> void:
	_apply_chip_snapshot(records)

func _apply_chip_snapshot(records: Array[Dictionary]) -> void:
	_bet_visual_totals.clear()
	if is_instance_valid(visuals):
		visuals.clear_chip_stacks()
	for record in records:
		_apply_bet_presentation(record)

func _on_round_cancelled(_table_id: String, _round_id: String, _refund_total: int) -> void:
	_selected_wagers.clear()
	if multiplayer.multiplayer_peer != null:
		_rpc_clear_round_visuals.rpc()
	_clear_round_visuals_local()

## Selection is only a keypad confirmation. No money is reserved until a color is clicked.
func set_selected_wager(peer_id: int, amount: int) -> Dictionary:
	if not _is_authority():
		return _failure("Only the host can set the Perya wager amount.")
	if not _is_near_table(peer_id):
		return _failure("Move closer to Perya before selecting a wager.")
	if state == TableState.RUNNING or state == TableState.RESOLVING:
		return _failure("Wagers are locked until this dice round is finished.")
	var snapshot: Dictionary = _wallet.call("get_snapshot")
	var available := maxi(int(snapshot.get("available_balance", 0)), 0)
	if amount <= 0 or amount > available:
		return _failure("Choose an amount from $1 to your available wallet balance.")
	_selected_wagers[peer_id] = amount
	_rpc_sync_selected_wager.rpc(peer_id, amount) if multiplayer.multiplayer_peer != null else _rpc_sync_selected_wager(peer_id, amount)
	_update_terminal_status()
	return _success({"peer_id": peer_id, "selected_wager": amount, "available_balance": available})

@rpc("authority", "call_remote", "reliable")
func _rpc_sync_selected_wager(peer_id: int, amount: int) -> void:
	_selected_wagers[peer_id] = amount
	_update_terminal_status()

func get_selected_wager(peer_id: int = 0) -> int:
	return int(_selected_wagers.get(peer_id, 0))

func get_shared_selected_wager() -> int:
	if _selected_wagers.is_empty():
		return 0
	var peer_ids: Array = _selected_wagers.keys()
	peer_ids.sort()
	return int(_selected_wagers[peer_ids[0]])

## Perya allows any positive stake up to the live available balance; no profile cap or safety hold.
func get_wager_limits() -> Dictionary:
	var available := 0
	if is_instance_valid(_wallet) and _wallet.has_method("get_snapshot"):
		available = maxi(int(_wallet.call("get_snapshot").get("available_balance", 0)), 0)
	return {"minimum": 1 if available > 0 else 0, "maximum": available, "available_balance": available}

func place_color_bet(color_index: int, peer_id: int) -> Dictionary:
	if multiplayer.is_server():
		return _handle_color_bet(peer_id, color_index)
	if multiplayer.multiplayer_peer == null:
		return _failure("No multiplayer session is active.")
	_rpc_request_color_bet.rpc_id(1, color_index)
	return _success({"pending": true})

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_color_bet(color_index: int) -> void:
	if not multiplayer.is_server() or not _validate_remote_sender():
		return
	_handle_color_bet(multiplayer.get_remote_sender_id(), color_index)

func _handle_color_bet(peer_id: int, color_index: int) -> Dictionary:
	if not _is_authority() or color_index < 0 or color_index >= Rules.COLOR_COUNT:
		return _reject(peer_id, "That color is not available.")
	if not _is_near_table(peer_id):
		return _reject(peer_id, "Move closer to the Perya table to place a bet.")
	if state == TableState.IDLE:
		_last_result_line = ""
		var opened := open_round(peer_id)
		if not bool(opened.get("ok", false)):
			return _reject(peer_id, str(opened.get("reason", "Could not open betting.")))
	if state != TableState.OPEN:
		return _reject(peer_id, "Bets are locked. Wait for the dice to finish.")
	var joined := join_table(peer_id)
	if not bool(joined.get("ok", false)):
		return _reject(peer_id, str(joined.get("reason", "Could not join this round.")))
	var stake := int(_selected_wagers.get(peer_id, 0))
	if stake <= 0:
		return _reject(peer_id, "Enter an amount on the keypad and press CONFIRM first.")
	var available := int(_wallet.call("get_snapshot").get("available_balance", 0))
	if stake > available:
		return _reject(peer_id, "Your selected amount is above your remaining wallet balance.")
	var result: Dictionary = _wallet.call("reserve_wager", peer_id, table_id, current_round_id, stake, {
		"color_index": color_index,
		"source": "perya_color_board",
	})
	if not bool(result.get("ok", false)):
		return _reject(peer_id, str(result.get("reason", "The wallet rejected this bet.")))
	_reset_open_round_inactivity()
	var wager_id := str(result.get("wager_id", ""))
	var record := _build_bet_presentation(peer_id, color_index, stake, wager_id)
	_apply_bet_presentation(record)
	if multiplayer.multiplayer_peer != null:
		_rpc_sync_bet.rpc(record)
	report_player_feedback(peer_id, "BET PLACED  /  %s  /  %s" % [Rules.COLOR_NAMES[color_index], _format_money(stake)], &"success")
	_update_terminal_status()
	return _success({"wager_id": wager_id, "color_index": color_index, "stake": stake})

func _build_bet_presentation(peer_id: int, color_index: int, stake: int, wager_id: String) -> Dictionary:
	var identity: PlayerIdentity = _network.call("get_player_identity", peer_id) as PlayerIdentity if is_instance_valid(_network) and _network.has_method("get_player_identity") else null
	var color_index_player := identity.color_index if identity != null else posmod(peer_id - 1, IdentityScript.palette_size())
	return {
		"wager_id": wager_id,
		"peer_id": peer_id,
		"nickname": identity.nickname if identity != null else "PLAYER %d" % peer_id,
		"player_color_index": color_index_player,
		"player_color": IdentityScript.color_for_index(color_index_player),
		"color_index": color_index,
		"stake": stake,
	}

@rpc("authority", "call_remote", "reliable")
func _rpc_sync_bet(record: Dictionary) -> void:
	_apply_bet_presentation(record)

func _apply_bet_presentation(record: Dictionary) -> void:
	if _bet_visual_totals.is_empty():
		_last_result_line = ""
	var peer_id := int(record.get("peer_id", 0))
	var color_index := int(record.get("color_index", -1))
	if peer_id <= 0 or color_index < 0 or color_index >= Rules.COLOR_COUNT:
		return
	var key := "%d:%d" % [color_index, peer_id]
	var totals: Dictionary = _bet_visual_totals.get(key, {"count": 0, "stake": 0})
	totals["count"] = int(totals["count"]) + 1
	totals["stake"] = int(totals["stake"]) + int(record.get("stake", 0))
	_bet_visual_totals[key] = totals
	if is_instance_valid(visuals):
		visuals.animate_color_selection(color_index)
		visuals.add_or_update_chip_stack(
			color_index, peer_id, str(record.get("nickname", "PLAYER")),
			record.get("player_color", Color.WHITE),
			int(totals["count"]), int(totals["stake"])
		)
	_update_terminal_status()

func start_roll(peer_id: int) -> Dictionary:
	if multiplayer.is_server():
		return _handle_start_roll(peer_id)
	if multiplayer.multiplayer_peer == null:
		return _failure("No multiplayer session is active.")
	_rpc_request_start_roll.rpc_id(1)
	return _success({"pending": true})

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_start_roll() -> void:
	if not multiplayer.is_server() or not _validate_remote_sender():
		return
	_handle_start_roll(multiplayer.get_remote_sender_id())

func _handle_start_roll(peer_id: int) -> Dictionary:
	if not _is_authority() or not _is_near_table(peer_id):
		return _reject(peer_id, "Move closer to start Perya.")
	if state != TableState.OPEN:
		return _reject(peer_id, "Place at least one color bet before rolling.")
	var start_result := super.start_round(peer_id)
	if not bool(start_result.get("ok", false)):
		return _reject(peer_id, str(start_result.get("reason", "The round could not start.")))
	_round_dice = Rules.roll_dice(_rng)
	_round_serial += 1
	_rolling = true
	if is_instance_valid(visuals):
		visuals.animate_roll_button()
	if multiplayer.multiplayer_peer != null:
		_rpc_begin_roll.rpc(_round_dice, _round_serial)
	await _play_roll_and_settle(_round_dice, _round_serial)
	return _success({"dice": _round_dice.duplicate()})

@rpc("authority", "call_remote", "reliable")
func _rpc_begin_roll(dice: Array[int], serial: int) -> void:
	if not Rules.is_valid_dice(dice) or serial <= _round_serial:
		return
	_round_serial = serial
	_round_dice = dice.duplicate()
	_rolling = true
	if is_instance_valid(visuals):
		visuals.animate_roll_button()
		await visuals.animate_dice(_round_dice, 2.45)
	_show_result(_round_dice)

func _play_roll_and_settle(dice: Array[int], serial: int) -> void:
	if is_instance_valid(visuals):
		await visuals.animate_dice(dice, 2.45)
	if serial != _round_serial or not _rolling:
		return
	_show_result(dice)
	var round_wagers := get_round_wagers()
	var payouts: Dictionary = Rules.calculate_round_payouts(round_wagers, dice)
	if payouts.is_empty():
		push_error("Perya refused to settle an empty or invalid locked wager set.")
		return
	var player_totals: Dictionary = {}
	for wager in round_wagers:
		var wager_id := str(wager.get("wager_id", ""))
		if not payouts.has(wager_id):
			continue
		var peer_id := int(wager.get("peer_id", 0))
		var totals: Dictionary = player_totals.get(peer_id, {"stake": 0, "gross_return": 0, "bet_count": 0})
		totals["stake"] = int(totals["stake"]) + int(wager.get("stake", 0))
		totals["gross_return"] = int(totals["gross_return"]) + int(payouts[wager_id])
		totals["bet_count"] = int(totals["bet_count"]) + 1
		player_totals[peer_id] = totals
	var settlement := settle_round(payouts)
	if not bool(settlement.get("ok", false)):
		push_error("Perya settlement failed for %s: %s" % [current_round_id, str(settlement.get("reason", ""))])
		return
	for peer_value: Variant in player_totals.keys():
		var settled_peer_id := int(peer_value)
		var player_result: Dictionary = player_totals[settled_peer_id]
		var returned := int(player_result["gross_return"])
		report_player_feedback(
			settled_peer_id,
			"PERYA SETTLED  /  STAKED %s  /  RETURN %s" % [_format_money(int(player_result["stake"])), _format_money(returned)],
			&"success" if returned > 0 else &"warning"
		)
	var result_names := PackedStringArray()
	for color_index in dice:
		result_names.append(Rules.COLOR_NAMES[color_index])
	report_global_announcement("PERYA ROLL  /  %s" % "  •  ".join(result_names), "PERYA COLOR GAME", 1)
	_rolling = false
	_selected_wagers.clear()
	_round_dice.clear()
	_bet_visual_totals.clear()
	if multiplayer.multiplayer_peer != null:
		_rpc_clear_round_visuals.rpc()
	_clear_round_visuals_local()
	_publish_keypad_snapshot()
	_update_terminal_status()

@rpc("authority", "call_remote", "reliable")
func _rpc_clear_round_visuals() -> void:
	_clear_round_visuals_local()

func _clear_round_visuals_local() -> void:
	_rolling = false
	_round_dice.clear()
	_selected_wagers.clear()
	_bet_visual_totals.clear()
	if is_instance_valid(visuals):
		visuals.clear_chip_stacks()
	_update_terminal_status()

func _show_result(dice: Array[int]) -> void:
	var totals: Dictionary = {}
	for color_index in dice:
		totals[color_index] = int(totals.get(color_index, 0)) + 1
	for color_value in totals.keys():
		if is_instance_valid(visuals):
			visuals.highlight_winning_color(int(color_value))
	var parts: PackedStringArray = []
	for color_index in dice:
		parts.append(Rules.COLOR_NAMES[color_index])
	var body := "RESULT  /  %s\nMATCH COUNTS DETERMINE PAYOUT\n1 MATCH  2X   /   2 MATCHES  3X   /   3 MATCHES  4X" % "  •  ".join(parts)
	_last_result_line = "LAST ROLL  /  %s" % "  •  ".join(parts)
	var world_screen := get_node_or_null("SlimWorldScreen/WorldScreen")
	if is_instance_valid(world_screen) and world_screen.has_method("set_content"):
		world_screen.call("set_content", "PERYA  /  RESULT", body, "LOSING COLOR BETS ARE NOT REFUNDED")

func _on_auto_resolution_requested(_table_id: String, _round_id: String, _reason: String) -> void:
	if _is_authority() and _rolling:
		# The authoritative dice are already fixed. Normal animation completion settles every locked stake.
		return

func _on_color_interacted(actor: Node, action: StringName, color_index: int) -> void:
	if action != &"use" or not is_instance_valid(actor):
		return
	var peer_id := _peer_id_for_actor(actor)
	if peer_id > 0:
		place_color_bet(color_index, peer_id)

func _on_roll_interacted(actor: Node, action: StringName) -> void:
	if action != &"use" or not is_instance_valid(actor):
		return
	var peer_id := _peer_id_for_actor(actor)
	if peer_id > 0:
		start_roll(peer_id)

func _on_proximity_entered(body: Node3D) -> void:
	if _is_authority():
		var peer_id := _peer_id_for_actor(body)
		if peer_id > 0:
			enter_proximity(peer_id)

func _on_proximity_exited(body: Node3D) -> void:
	if _is_authority():
		var peer_id := _peer_id_for_actor(body)
		if peer_id > 0 and _is_near_table(peer_id):
			exit_proximity(peer_id)

func _peer_id_for_actor(actor: Node) -> int:
	if not is_instance_valid(actor):
		return 0
	for property_info in actor.get_property_list():
		if str(property_info.get("name", "")) == "input_peer_id":
			var value: Variant = actor.get("input_peer_id")
			if typeof(value) == TYPE_INT and int(value) > 0:
				return int(value)
	if is_instance_valid(_network) and _network.get("peer") == null:
		return multiplayer.get_unique_id()
	return 0

func _validate_remote_sender() -> bool:
	return is_instance_valid(_network) and _network.has_method("validate_rpc") and bool(_network.call("validate_rpc"))

func _reject(peer_id: int, message: String) -> Dictionary:
	if peer_id > 0:
		report_player_feedback(peer_id, message, &"error")
	return _failure(message)

func _setup_betting_keypad() -> void:
	var keypad := get_node_or_null("BettingKeypad")
	if not is_instance_valid(keypad) or not is_instance_valid(terminal_display):
		push_warning("Perya requires the shared BettingKeypad and terminal display.")
		return
	var controller := KeypadControllerScript.new()
	controller.name = "BettingKeypadController"
	controller.set("table", self)
	controller.set("display", terminal_display)
	controller.set("profile", terminal_display.get("profile"))
	controller.set("one_wager_per_player", false)
	controller.set("selection_only", true)
	keypad.add_child(controller)

func _publish_keypad_snapshot() -> void:
	var controller := get_node_or_null("BettingKeypad/BettingKeypadController")
	if is_instance_valid(controller) and controller.has_method("_publish_snapshot"):
		controller.call("_publish_snapshot")

func _update_terminal_status() -> void:
	if is_instance_valid(terminal_display) and terminal_display.has_method("refresh_display"):
		terminal_display.call("refresh_display")
	var screen := get_node_or_null("SlimWorldScreen/WorldScreen")
	if not is_instance_valid(screen) or not screen.has_method("set_content"):
		return
	var bet_count := 0
	var total := 0
	for totals_value: Variant in _bet_visual_totals.values():
		var totals: Dictionary = totals_value
		bet_count += int(totals.get("count", 0))
		total += int(totals.get("stake", 0))
	var headline := "DICE IN MOTION" if _rolling else ("BETTING OPEN" if state == TableState.OPEN or not _bet_visual_totals.is_empty() else "PLACE YOUR BETS")
	var detail := "ACTIVE BETS  %d\nTOTAL STAKED  %s" % [bet_count, _format_money(total)]
	if not _last_result_line.is_empty():
		detail += "\n" + _last_result_line
	detail += "\nSELECT AMOUNT / CONFIRM / CLICK A COLOR\nPRESS START / ROLL WHEN READY"
	screen.call("set_content", "PERYA  /  %s" % headline, detail, "1 MATCH 2X  /  2 MATCHES 3X  /  3 MATCHES 4X")

func _format_money(amount: int) -> String:
	var digits := str(maxi(amount, 0))
	var formatted := ""
	for index in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			formatted += ","
		formatted += digits.substr(index, 1)
	return "$" + formatted
