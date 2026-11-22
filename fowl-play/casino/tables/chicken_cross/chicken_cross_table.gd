extends BaseTable

const RoundModel = preload("res://casino/tables/chicken_cross/chicken_cross_round.gd")
const Rules = preload("res://casino/tables/chicken_cross/chicken_cross_rules.gd")
const BettingKeypadControllerScript = preload("res://casino/terminals/components/betting_keypad_controller.gd")

signal player_state_changed(peer_id: int, player_state: Dictionary)
signal round_finished(payouts: Dictionary, settlement: Dictionary)

var _round_model: RefCounted = null
var _network: Node = null

@export var proximity_area: Area3D
@export var cross_interactable: Interactable
@export var cash_out_interactable: Interactable

func _ready() -> void:
	super._ready()
	participant_left_after_start.connect(_on_participant_left_after_start)
	round_auto_resolution_requested.connect(_on_round_auto_resolution_requested)
	if is_instance_valid(proximity_area):
		proximity_area.body_entered.connect(_on_proximity_body_entered)
		proximity_area.body_exited.connect(_on_proximity_body_exited)
	else:
		push_warning("ChickenCrossTable has no Proximity Area assigned; table range will not update automatically.")
	if is_instance_valid(cross_interactable):
		cross_interactable.interacted.connect(_on_cross_button_interacted)
	else:
		push_warning("ChickenCrossTable has no Cross Interactable assigned.")
	if is_instance_valid(cash_out_interactable):
		cash_out_interactable.interacted.connect(_on_cash_out_button_interacted)
	else:
		push_warning("ChickenCrossTable has no Cash Out Interactable assigned.")
	_network = get_node_or_null("/root/Network")
	if is_instance_valid(_network) and _network.has_signal("roster_changed"):
		var roster_callback: Callable = Callable(self, "_on_network_roster_changed")
		if not _network.is_connected("roster_changed", roster_callback):
			_network.connect("roster_changed", roster_callback)
	_setup_betting_keypad()

## Adds the reusable controller at runtime without changing the editor-authored keypad scene.
func _setup_betting_keypad() -> void:
	var keypad: Node = get_node_or_null("BettingKeypad")
	var display: Node = get_node_or_null("BettingTerminalDisplay")
	if not is_instance_valid(keypad) and not is_instance_valid(display):
		# Lightweight headless table tests instantiate this controller without a scene.
		return
	if not is_instance_valid(keypad) or not is_instance_valid(display):
		push_warning("ChickenCrossTable needs both BettingKeypad and BettingTerminalDisplay nodes.")
		return
	if keypad.get_node_or_null("BettingKeypadController") != null:
		return
	var controller: Node = BettingKeypadControllerScript.new()
	controller.name = "BettingKeypadController"
	controller.set("table", self)
	controller.set("display", display)
	controller.set("profile", display.get("profile"))
	controller.set("one_wager_per_player", true)
	keypad.add_child(controller)

func _exit_tree() -> void:
	if is_instance_valid(_network) and _network.has_signal("roster_changed"):
		var roster_callback: Callable = Callable(self, "_on_network_roster_changed")
		if _network.is_connected("roster_changed", roster_callback):
			_network.disconnect("roster_changed", roster_callback)
	super._exit_tree()

func start_round(peer_id: int) -> Dictionary:
	if not _is_authority():
		return _failure("Only the host can start Chicken Cross.")
	if state != TableState.OPEN:
		return _failure("Chicken Cross is not open for starting.")
	var round_wagers: Array[Dictionary] = get_round_wagers()
	var reserved_wagers: Array[Dictionary] = []
	for wager: Dictionary in round_wagers:
		if str(wager.get("status", "")) == "reserved":
			reserved_wagers.append(wager)
	if reserved_wagers.is_empty():
		return _failure("Chicken Cross needs at least one active wager.")
	var seen_peers: Dictionary = {}
	for wager: Dictionary in reserved_wagers:
		var bettor_id: int = int(wager.get("peer_id", 0))
		if bettor_id <= 0 or seen_peers.has(bettor_id):
			return _failure("Chicken Cross allows exactly one active wager per participant.")
		seen_peers[bettor_id] = true
	var start_result: Dictionary = super.start_round(peer_id)
	if not bool(start_result.get("ok", false)):
		return start_result
	var all_round_wagers: Array[Dictionary] = get_round_wagers()
	var locked_wagers: Array[Dictionary] = []
	for wager: Dictionary in all_round_wagers:
		if str(wager.get("status", "")) == "locked":
			locked_wagers.append(wager)
	_round_model = RoundModel.new()
	var model_result: Dictionary = _round_model.call("begin", locked_wagers)
	if not bool(model_result.get("ok", false)):
		push_error("Chicken Cross model initialization failed after wagers locked: %s" % str(model_result.get("reason", "")))
		return _failure("Chicken Cross could not initialize its locked wagers.")
	for player_state: Dictionary in _round_model.call("get_players"):
		_publish_player_state(int(player_state["peer_id"]))
	return start_result

func request_cross() -> Dictionary:
	return _submit_player_action(true)

func request_cash_out() -> Dictionary:
	return _submit_player_action(false)

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

func _on_cross_button_interacted(actor: Node, action: StringName) -> void:
	if action == &"use":
		_handle_interacted_button(actor, true)

func _on_cash_out_button_interacted(actor: Node, action: StringName) -> void:
	if action == &"use":
		_handle_interacted_button(actor, false)

func _handle_interacted_button(actor: Node, advance_chicken: bool) -> void:
	if not _is_authority() or not is_instance_valid(actor):
		return
	var peer_id: int = _peer_id_for_actor(actor)
	if peer_id <= 0:
		return
	_handle_player_action(peer_id, advance_chicken)

func _peer_id_for_actor(actor: Node) -> int:
	if not is_instance_valid(actor):
		return 0
	var peer_id: int = int(actor.get("input_peer_id"))
	# Offline test-arena players may not receive a network owner ID. Treat the
	# local offline player as the offline multiplayer peer so table proximity
	# and keypad confirmation use the same identity.
	if peer_id <= 0 and _network != null and _network.get("peer") == null:
		peer_id = multiplayer.get_unique_id()
	return peer_id

func _submit_player_action(advance_chicken: bool) -> Dictionary:
	if multiplayer.is_server():
		return _handle_player_action(multiplayer.get_unique_id(), advance_chicken)
	if multiplayer.multiplayer_peer == null:
		return _failure("No multiplayer session is active.")
	if advance_chicken:
		_rpc_request_cross.rpc_id(1)
	else:
		_rpc_request_cash_out.rpc_id(1)
	return {"ok": true, "reason": "", "pending": true}

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_cross() -> void:
	if multiplayer.is_server():
		_handle_player_action(multiplayer.get_remote_sender_id(), true)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_cash_out() -> void:
	if multiplayer.is_server():
		_handle_player_action(multiplayer.get_remote_sender_id(), false)

func _handle_player_action(peer_id: int, advance_chicken: bool) -> Dictionary:
	if not _is_authority():
		return _failure("Only the host can resolve Chicken Cross actions.")
	if state != TableState.RUNNING or _round_model == null:
		return _failure("Chicken Cross is not currently running.")
	if not _is_near_table(peer_id):
		return _failure("The player must remain within table proximity.")
	var result: Dictionary
	if advance_chicken:
		result = _round_model.call("advance", peer_id, randf())
	else:
		result = _round_model.call("cash_out", peer_id)
	if not bool(result.get("ok", false)):
		return result
	_publish_player_state(peer_id)
	_try_settle_completed_round()
	return result

func get_player_state(peer_id: int) -> Dictionary:
	if _round_model == null:
		return {}
	return _round_model.call("get_player", peer_id)

func get_round_players() -> Array[Dictionary]:
	if _round_model == null:
		return []
	return _round_model.call("get_players")

func _on_participant_left_after_start(peer_id: int, _table_id: String, _round_id: String) -> void:
	_auto_resolve_player(peer_id, "left_after_start")

func _on_round_auto_resolution_requested(_table_id: String, _round_id: String, reason: String) -> void:
	if not _is_authority() or _round_model == null:
		return
	var active_players: Array[Dictionary] = _round_model.call("get_players")
	for player_state: Dictionary in active_players:
		if str(player_state.get("status", "")) == RoundModel.PLAYER_ACTIVE:
			_auto_resolve_player(int(player_state["peer_id"]), reason)

func _on_network_roster_changed() -> void:
	if not _is_authority() or _round_model == null or not is_instance_valid(_network):
		return
	if _network.get("peer") == null:
		return
	var roster_value: Variant = _network.get("roster")
	if typeof(roster_value) != TYPE_ARRAY:
		return
	var roster: Array = roster_value
	var active_players: Array[Dictionary] = _round_model.call("get_players")
	for player_state: Dictionary in active_players:
		var peer_id: int = int(player_state["peer_id"])
		if str(player_state.get("status", "")) == RoundModel.PLAYER_ACTIVE and not roster.has(peer_id):
			_auto_resolve_player(peer_id, "disconnected")

func _auto_resolve_player(peer_id: int, reason: String) -> void:
	if not _is_authority() or _round_model == null:
		return
	var result: Dictionary = _round_model.call("auto_resolve", peer_id, reason)
	if not bool(result.get("ok", false)):
		return
	_publish_player_state(peer_id)
	_try_settle_completed_round()

func _try_settle_completed_round() -> void:
	if not _is_authority() or _round_model == null or not bool(_round_model.call("is_complete")):
		return
	var payouts: Dictionary = _round_model.call("build_payouts")
	var settlement: Dictionary = settle_round(payouts)
	if not bool(settlement.get("ok", false)):
		push_error("Chicken Cross settlement failed: %s" % str(settlement.get("reason", "")))
		return
	round_finished.emit(payouts.duplicate(true), settlement.duplicate(true))
	_round_model = null

func _publish_player_state(peer_id: int) -> void:
	if _round_model == null:
		return
	var player_state: Dictionary = _round_model.call("get_player", peer_id)
	if player_state.is_empty():
		return
	player_state_changed.emit(peer_id, player_state.duplicate(true))
	_apply_local_player_presentation(peer_id, player_state)
	if multiplayer.multiplayer_peer != null:
		_receive_player_state.rpc(peer_id, player_state)

func _apply_local_player_presentation(peer_id: int, player_state: Dictionary) -> void:
	# The tabletop is shared geometry, so each client presents only its own
	# chicken. Other players' state remains available through player_state_changed.
	if peer_id != multiplayer.get_unique_id():
		return
	var visuals: Node = get_node_or_null("Visuals")
	if visuals != null and visuals.has_method("apply_player_state"):
		visuals.call("apply_player_state", player_state)
	_update_local_terminal_display(player_state)

func _update_local_terminal_display(player_state: Dictionary) -> void:
	var world_screen: Node = get_node_or_null("SlimWorldScreen/WorldScreen")
	if world_screen == null or not world_screen.has_method("set_content"):
		return
	var tile_number: int = int(player_state.get("tile", 0))
	var stake: int = int(player_state.get("stake", 0))
	var status: String = str(player_state.get("status", "active"))
	var header: String = "CHICKEN CROSS"
	var body: String = ""
	var prompt: String = ""
	if status == "failed":
		body = "TILE %02d / %02d\nCHICKEN LOST\nWAGER LOST" % [tile_number, Rules.TILE_COUNT]
		prompt = "ROUND RESOLVED"
	elif status == "cashed_out":
		var multiplier: float = float(player_state.get("multiplier", 0.0))
		var gross_return: int = int(player_state.get("gross_return", 0))
		body = "SAFE AT TILE %02d / %02d\nRETURN %.1fX\nPAYOUT $%s" % [tile_number, Rules.TILE_COUNT, multiplier, _format_currency(gross_return)]
		prompt = "CASH OUT COMPLETE"
	elif tile_number <= 0:
		body = "WAGER LOCKED\nREADY TO CROSS\n12 TILES AHEAD"
		prompt = "CROSS TO BEGIN"
	else:
		var next_tile: int = mini(tile_number + 1, Rules.TILE_COUNT)
		var risk: float = Rules.failure_chance_for_tile(next_tile) * 100.0
		var multiplier: float = Rules.multiplier_for_tile(tile_number)
		var gross_return: int = Rules.gross_return_for_stake(stake, tile_number)
		body = "SAFE TILE %02d / %02d\nNEXT RISK %.0f%%\nCASH OUT %.1fX  $%s" % [tile_number, Rules.TILE_COUNT, risk, multiplier, _format_currency(gross_return)]
		prompt = "CROSS FOR MORE  /  CASH OUT"
	world_screen.call("set_content", header, body, prompt)

func _format_currency(amount: int) -> String:
	var raw: String = str(maxi(amount, 0))
	var formatted: String = ""
	for index: int in range(raw.length()):
		if index > 0 and (raw.length() - index) % 3 == 0:
			formatted += ","
		formatted += raw.substr(index, 1)
	return formatted

@rpc("authority", "call_remote", "reliable")
func _receive_player_state(peer_id: int, player_state: Dictionary) -> void:
	# Each client receives authoritative state but renders only its own chicken.
	player_state_changed.emit(peer_id, player_state.duplicate(true))
	_apply_local_player_presentation(peer_id, player_state)
