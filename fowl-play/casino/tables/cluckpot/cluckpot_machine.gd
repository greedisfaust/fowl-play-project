## Host-authoritative Cluckpot slot machine. Each scene instance is one independent cabinet.
extends BaseTable

const Rules = preload("res://casino/tables/cluckpot/cluckpot_rules.gd")
const LAYERS = preload("res://core/layers.gd")
const KeypadControllerScript = preload("res://casino/terminals/components/betting_keypad_controller.gd")
const KeypadScene: PackedScene = preload("res://casino/terminals/components/betting_keypad.tscn")
const Profile: BettingTerminalProfile = preload("res://casino/tables/cluckpot/cluckpot_profile.tres")

signal spin_started(record: Dictionary)
signal spin_settled(record: Dictionary, settlement: Dictionary)
signal selected_wager_changed(peer_id: int, amount: int)

@export var machine_number: int = 1
@export var spin_duration: float = 3.8

var _network: Node
var _rng := RandomNumberGenerator.new()
var _selected_wagers: Dictionary = {}
var _active_spin: Dictionary = {}
var _spin_sequence: int = 1
var _visuals: Node3D
var _proximity: Area3D
var _keypad: Node3D
var _display: Node
var _reel_cells: Array[Array] = []
var _wager_screen: WorldScreen
var _spin_locked: bool = false


func _ready() -> void:
	super._ready()
	_network = get_node_or_null("/root/Network")
	_rng.randomize()
	_build_machine()
	_setup_keypad()


func _exit_tree() -> void:
	if is_instance_valid(_proximity):
		if _proximity.body_entered.is_connected(_on_body_entered):
			_proximity.body_entered.disconnect(_on_body_entered)
		if _proximity.body_exited.is_connected(_on_body_exited):
			_proximity.body_exited.disconnect(_on_body_exited)
	super._exit_tree()


func set_selected_wager(peer_id: int, amount: int) -> Dictionary:
	if not _is_authority():
		return _failure("Only the host can change a Cluckpot wager.")
	if not _is_near_table(peer_id):
		return _failure("Move closer to this slot machine before selecting a wager.")
	var limits: Dictionary = get_wager_limits()
	var minimum: int = int(limits.get("minimum", 0))
	var maximum: int = int(limits.get("maximum", 0))
	if minimum <= 0 or maximum <= 0 or amount < minimum or amount > maximum:
		return _failure("Wager must be between %d and %d." % [minimum, maximum])
	_selected_wagers[peer_id] = amount
	_set_status("WAGER SELECTED", "MIN %s  MAX %s\nWAGER %s" % [_format_money(int(limits.get("minimum", 0))), _format_money(int(limits.get("maximum", 0))), _format_money(amount)])
	if multiplayer.multiplayer_peer != null:
		_rpc_sync_selected_wager.rpc(peer_id, amount)
	selected_wager_changed.emit(peer_id, amount)
	report_player_feedback(peer_id, "CLUCKPOT WAGER SET  /  %s" % _format_money(amount), &"success")
	return _success({"peer_id": peer_id, "selected_wager": amount, "limits": limits})


@rpc("authority", "call_remote", "reliable")
func _rpc_sync_selected_wager(peer_id: int, amount: int) -> void:
	_selected_wagers[peer_id] = amount
	var limits: Dictionary = get_wager_limits()
	_set_status("WAGER SELECTED", "MIN %s  MAX %s\nWAGER %s" % [
		_format_money(int(limits.get("minimum", 0))),
		_format_money(int(limits.get("maximum", 0))),
		_format_money(amount),
	])
	selected_wager_changed.emit(peer_id, amount)


func get_selected_wager(peer_id: int = 0) -> int:
	return int(_selected_wagers.get(peer_id, 0))


func get_shared_selected_wager() -> int:
	var peer_ids: Array = _selected_wagers.keys()
	if peer_ids.is_empty():
		return 0
	peer_ids.sort()
	return int(_selected_wagers[peer_ids[0]])


func _handle_spin(peer_id: int) -> Dictionary:
	if not _is_authority():
		return _failure("Only the host can spin this machine.")
	if not _is_near_table(peer_id):
		return _reject_spin(peer_id, "Move closer to this machine to spin.")
	if _spin_locked:
		return _reject_spin(peer_id, "THIS MACHINE IS STILL SPINNING.")
	var stake: int = get_selected_wager(peer_id)
	if stake <= 0:
		return _reject_spin(peer_id, "SELECT A WAGER ON THE KEYPAD FIRST.")
	var limits: Dictionary = get_wager_limits()
	if stake < int(limits.get("minimum", 0)) or stake > int(limits.get("maximum", 0)):
		return _reject_spin(peer_id, "YOUR SELECTED WAGER IS OUTSIDE TODAY'S LIMITS.")

	var sequence: int = _spin_sequence
	_spin_sequence += 1
	var round_id: String = "cluckpot_%d_%06d" % [Time.get_ticks_usec(), sequence]
	var outcome: Dictionary = Rules.roll_outcome(_rng)
	var payout: int = Rules.calculate_payout(stake, outcome)
	var opened: Dictionary = _wallet.call("open_round", table_id, round_id)
	if not bool(opened.get("ok", false)):
		return _reject_spin(peer_id, str(opened.get("reason", "Could not open the spin wager.")))
	var reserved: Dictionary = _wallet.call("reserve_wager", peer_id, table_id, round_id, stake, {
		"machine_number": machine_number,
		"symbols": outcome["symbols"],
		"payout": payout,
		"source": "cluckpot_spin",
	})
	if not bool(reserved.get("ok", false)):
		_wallet.call("cancel_open_round", table_id, round_id)
		return _reject_spin(peer_id, str(reserved.get("reason", "The shared wallet rejected this spin.")))
	var locked: Dictionary = _wallet.call("lock_round", table_id, round_id)
	if not bool(locked.get("ok", false)):
		_wallet.call("cancel_open_round", table_id, round_id)
		return _reject_spin(peer_id, str(locked.get("reason", "Could not lock the spin wager.")))

	var record: Dictionary = {
		"round_id": round_id,
		"wager_id": str(reserved.get("wager_id", "")),
		"peer_id": peer_id,
		"nickname": _get_player_nickname(peer_id),
		"stake": stake,
		"symbols": outcome["symbols"],
		"line_wins": outcome["line_wins"],
		"payout": payout,
		"spin_duration": spin_duration,
		"sequence": sequence,
	}
	_active_spin = record
	_spin_locked = true
	_play_spin_visual(record)
	if multiplayer.multiplayer_peer != null:
		_rpc_play_spin.rpc(record)
	spin_started.emit(record.duplicate(true))
	report_player_feedback(peer_id, "CLUCKPOT SPIN  /  %s" % _format_money(stake), &"success")
	return _success({"round_id": round_id, "wager_id": str(reserved.get("wager_id", "")), "stake": stake, "payout": payout, "line_wins": outcome["line_wins"]})


func _reject_spin(peer_id: int, message: String) -> Dictionary:
	report_player_feedback(peer_id, message, &"error")
	return _failure(message)


@rpc("authority", "call_remote", "reliable")
func _rpc_play_spin(record: Dictionary) -> void:
	_active_spin = record.duplicate(true)
	_spin_locked = true
	_play_spin_visual(record)


func _play_spin_visual(record: Dictionary) -> void:
	_animate_lever()
	_animate_cabinet()
	var symbols: Array = record.get("symbols", [])
	if symbols.size() != 3:
		return
	_set_status("REELS IN MOTION", "WAGER %s  /  GOOD LUCK" % _format_money(int(record.get("stake", 0))))
	_flash_win(false)
	var duration: float = maxf(float(record.get("spin_duration", spin_duration)), 1.8)
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	for reel_index: int in range(3):
		var reel_time: float = duration * (0.55 + float(reel_index) * 0.12)
		var spin_step: Callable = func(step: int) -> void: _set_reel_preview(reel_index, step)
		var ramp_steps: int = 4
		var cruise_steps: int = 10
		var stop_steps: int = 4
		tween.tween_method(spin_step, 0, ramp_steps, reel_time * 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_method(spin_step, ramp_steps, ramp_steps + cruise_steps, reel_time * 0.52).set_trans(Tween.TRANS_LINEAR)
		tween.tween_method(spin_step, ramp_steps + cruise_steps, ramp_steps + cruise_steps + stop_steps, reel_time * 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_callback(func() -> void: _show_final_reel(reel_index, symbols[reel_index]))
		tween.tween_callback(func() -> void: _reel_stop_pulse(reel_index))
		tween.tween_interval(0.12)
	tween.tween_callback(func() -> void: _finish_spin_visual(record))


func _set_reel_preview(reel_index: int, step: int) -> void:
	if reel_index < 0 or reel_index >= _reel_cells.size():
		return
	var symbols: Array[String] = Rules.SYMBOLS
	var offset: int = posmod(step + reel_index * 3, symbols.size())
	var builder: CluckpotVisualBuilder = _visuals as CluckpotVisualBuilder
	for row_index: int in range(3):
		var cell: Node3D = _reel_cells[reel_index][row_index] as Node3D
		if is_instance_valid(builder) and is_instance_valid(cell):
			builder.set_symbol_icon(cell, symbols[posmod(offset + row_index, symbols.size())])


func _show_final_reel(reel_index: int, column: Array) -> void:
	if reel_index < 0 or reel_index >= _reel_cells.size():
		return
	var builder: CluckpotVisualBuilder = _visuals as CluckpotVisualBuilder
	for row_index: int in range(mini(column.size(), 3)):
		var cell: Node3D = _reel_cells[reel_index][row_index] as Node3D
		if is_instance_valid(builder) and is_instance_valid(cell):
			builder.set_symbol_icon(cell, str(column[row_index]))


func _reel_stop_pulse(reel_index: int) -> void:
	var reels: Node3D = _visuals.get_node_or_null("Cabinet/Reels") as Node3D
	if not is_instance_valid(reels):
		return
	var reel: Node3D = reels.get_node_or_null("Reel_%d" % reel_index) as Node3D
	if not is_instance_valid(reel):
		return
	var tween := create_tween()
	tween.tween_property(reel, "position:z", 0.035, 0.055)
	tween.tween_property(reel, "position:z", 0.0, 0.12)


func _finish_spin_visual(record: Dictionary) -> void:
	if str(_active_spin.get("round_id", "")) != str(record.get("round_id", "")):
		return
	var payout: int = int(record.get("payout", 0))
	var jackpot: bool = payout >= int(record.get("stake", 0)) * 20 and payout > 0
	var result_text: String = "TRY AGAIN"
	if payout > 0:
		result_text = ("GOLDEN JACKPOT! " if jackpot else "WIN ") + _format_money(payout)
	_set_status(result_text, "STAKE %s  /  RETURN %s" % [_format_money(int(record.get("stake", 0))), _format_money(payout)])
	_flash_win(payout > 0, jackpot)
	if not _is_authority():
		_active_spin.clear()
		_spin_locked = false
		return
	var wager_id: String = str(record.get("wager_id", ""))
	var settlement: Dictionary = _wallet.call("settle_round", table_id, str(record.get("round_id", "")), {wager_id: payout})
	if not bool(settlement.get("ok", false)):
		push_error("Cluckpot settlement failed: %s" % str(settlement.get("reason", "")))
		return
	if payout > 0:
		report_global_announcement("%s HIT CLUCKPOT  /  %s" % [str(record.get("nickname", "PLAYER")).to_upper(), _format_money(payout)], "CLUCKPOT", 2 if payout >= int(record.get("stake", 1)) * 20 else 1)
	else:
		report_player_feedback(int(record.get("peer_id", 0)), "NO WIN  /  TRY AGAIN", &"info")
	var settled: Dictionary = record.duplicate(true)
	settled["status"] = "settled"
	spin_settled.emit(settled, settlement.duplicate(true))
	_active_spin.clear()
	_spin_locked = false


func request_day_end_cleanup(reason: String) -> Dictionary:
	if not _is_authority():
		return _failure("Only the host can clean up Cluckpot.")
	if reason.strip_edges().is_empty():
		return _failure("A cleanup reason is required.")
	if _active_spin.is_empty():
		_selected_wagers.clear()
		return _success({"round_id": "", "action": "none"})
	var record: Dictionary = _active_spin.duplicate(true)
	var settlement: Dictionary = _wallet.call("settle_round", table_id, str(record.get("round_id", "")), {
		str(record.get("wager_id", "")): int(record.get("payout", 0))
	})
	if not bool(settlement.get("ok", false)):
		return settlement
	_active_spin.clear()
	_spin_locked = false
	_selected_wagers.clear()
	_set_status("DAY CLOSED")
	if multiplayer.multiplayer_peer != null:
		_rpc_clear_spin.rpc()
	return _success({"round_id": str(record.get("round_id", "")), "action": "settled_in_flight", "payout": int(record.get("payout", 0))})


@rpc("authority", "call_remote", "reliable")
func _rpc_clear_spin() -> void:
	_active_spin.clear()
	_spin_locked = false
	_selected_wagers.clear()
	_set_status("DAY CLOSED")


func _build_machine() -> void:
	_visuals = get_node_or_null("Visuals") as Node3D
	if not is_instance_valid(_visuals):
		_visuals = Node3D.new()
		_visuals.name = "Visuals"
		add_child(_visuals)
	var builder: CluckpotVisualBuilder = _visuals as CluckpotVisualBuilder
	if is_instance_valid(builder):
		builder.machine_number = machine_number
		builder.call("_rebuild")
		_reel_cells = builder.reel_cells
		_wager_screen = _visuals.get_node_or_null("Cabinet/WagerWorldScreen") as WorldScreen
	else:
		push_warning("CluckpotMachine requires a CluckpotVisualBuilder child named Visuals.")
	_proximity = Area3D.new()
	_proximity.name = "ProximityArea"
	_proximity.collision_layer = 0
	_proximity.collision_mask = (1 << (LAYERS.HEALTHY_PLAYERS - 1)) | (1 << (LAYERS.LIMP_BODIES - 1))
	var proximity_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.5
	proximity_shape.shape = sphere
	proximity_shape.position = Vector3(0.0, 1.0, 1.0)
	_proximity.add_child(proximity_shape)
	add_child(_proximity)
	_proximity.body_entered.connect(_on_body_entered)
	_proximity.body_exited.connect(_on_body_exited)


func _setup_keypad() -> void:
	if not is_instance_valid(KeypadScene):
		return
	_keypad = KeypadScene.instantiate() as Node3D
	if not is_instance_valid(_keypad):
		return
	_keypad.name = "BettingKeypad"
	_keypad.position = Vector3(-0.48, 0.82, 1.08)
	_keypad.rotation = Vector3(deg_to_rad(62.0), 0.0, 0.0)
	_display = Node.new()
	_display.name = "WagerDisplayAdapter"
	_display.set_script(load("res://casino/tables/cluckpot/cluckpot_wager_display.gd"))
	_display.set("profile", Profile)
	_display.set("table", self)
	_display.set("screen", _wager_screen)
	add_child(_display)
	var controller: Node = _keypad.get_node_or_null("BettingKeypadController")
	if not is_instance_valid(controller):
		controller = KeypadControllerScript.new()
		controller.name = "BettingKeypadController"
		_keypad.add_child(controller)
	controller.set("table", self)
	controller.set("display", _display)
	controller.set("profile", Profile)
	controller.set("selection_only", true)
	controller.set("one_wager_per_player", false)
	controller.connect("wager_confirmation_result", _on_keypad_confirmation_result)
	add_child(_keypad)
	_refresh_machine_screen()


func _refresh_machine_screen() -> void:
	var limits: Dictionary = get_wager_limits()
	if is_instance_valid(_display) and _display.has_method("refresh_display"):
		_display.call("refresh_display")
	else:
		_set_status("READY FOR WAGER", "MIN %s  MAX %s\nWAGER --" % [
			_format_money(int(limits.get("minimum", 0))),
			_format_money(int(limits.get("maximum", 0))),
		])


func _on_keypad_confirmation_result(peer_id: int, result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		return
	# A successful keypad confirmation is the spin trigger; no separate button.
	if _is_authority():
		_handle_spin(peer_id)


func _on_body_entered(body: Node3D) -> void:
	if not _is_authority():
		return
	var peer_id: int = _peer_id_for_actor(body)
	if peer_id > 0:
		enter_proximity(peer_id)


func _on_body_exited(body: Node3D) -> void:
	if not _is_authority():
		return
	var peer_id: int = _peer_id_for_actor(body)
	if peer_id > 0 and _is_near_table(peer_id):
		exit_proximity(peer_id)


func _peer_id_for_actor(actor: Node) -> int:
	if not is_instance_valid(actor):
		return 0
	for property_info: Dictionary in actor.get_property_list():
		if str(property_info.get("name", "")) == "input_peer_id":
			var value: Variant = actor.get("input_peer_id")
			if typeof(value) == TYPE_INT and int(value) > 0:
				return int(value)
	if is_instance_valid(_network) and _network.get("peer") == null:
		return multiplayer.get_unique_id()
	return 0


func _validate_remote_action_sender() -> bool:
	return is_instance_valid(_network) and _network.has_method("validate_rpc") and bool(_network.call("validate_rpc"))


func _animate_cabinet() -> void:
	var cabinet: Node3D = _visuals.get_node_or_null("Cabinet") as Node3D
	if not is_instance_valid(cabinet):
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(cabinet, "position:y", -0.018, 0.07)
	tween.tween_property(cabinet, "position:y", 0.008, 0.08)
	tween.tween_property(cabinet, "position:y", 0.0, 0.12)


func _animate_lever() -> void:
	var lever: MeshInstance3D = _visuals.get_node_or_null("Cabinet/LeverArm") as MeshInstance3D
	var grip: MeshInstance3D = _visuals.get_node_or_null("Cabinet/LeverGrip") as MeshInstance3D
	if not is_instance_valid(lever) or not is_instance_valid(grip):
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(lever, "rotation:z", 0.62, 0.22)
	tween.parallel().tween_property(grip, "position:y", 1.72, 0.22)
	tween.tween_interval(0.12)
	tween.tween_property(lever, "rotation:z", deg_to_rad(-22.0), 0.3)
	tween.parallel().tween_property(grip, "position:y", 2.1, 0.3)


func _set_status(header: String, detail: String = "") -> void:
	if is_instance_valid(_display) and _display.has_method("set_status"):
		var valid_state: bool = header == "WAGER SELECTED" or header == "REELS IN MOTION" or header.begins_with("WIN") or header.begins_with("GOLDEN JACKPOT")
		_display.call("set_status", header, detail, valid_state)
		return
	if not is_instance_valid(_wager_screen):
		return
	var screen_text: ScreenText = _wager_screen.get_screen_text()
	if screen_text == null:
		return
	screen_text.show_layout(ScreenText.LAYOUT_WARNING, header, detail)


func _flash_win(won: bool, jackpot: bool = false) -> void:
	var frame: MeshInstance3D = _visuals.get_node_or_null("Cabinet/PaylineGold") as MeshInstance3D
	if not is_instance_valid(frame):
		return
	var material: StandardMaterial3D = frame.material_override as StandardMaterial3D
	if not is_instance_valid(material):
		return
	material.emission_enabled = true
	material.emission = Color("#ffbd58")
	material.emission_energy_multiplier = 5.0 if jackpot else (2.5 if won else 0.25)


func _format_money(amount: int) -> String:
	return "$" + Rules.format_money(amount)


func _get_player_nickname(peer_id: int) -> String:
	if is_instance_valid(_network) and _network.has_method("get_player_identity"):
		var identity: PlayerIdentity = _network.call("get_player_identity", peer_id) as PlayerIdentity
		if is_instance_valid(identity) and not identity.nickname.is_empty():
			return identity.nickname
	return "PLAYER %d" % peer_id


