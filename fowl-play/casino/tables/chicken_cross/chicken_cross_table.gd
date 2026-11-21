extends BaseTable

const RoundModel = preload("res://casino/tables/chicken_cross/chicken_cross_round.gd")

signal player_state_changed(peer_id: int, player_state: Dictionary)
signal round_finished(payouts: Dictionary, settlement: Dictionary)

var _round_model: RefCounted = null
var _network: Node = null

func _ready() -> void:
	super._ready()
	participant_left_after_start.connect(_on_participant_left_after_start)
	round_auto_resolution_requested.connect(_on_round_auto_resolution_requested)
	_network = get_node_or_null("/root/Network")
	if is_instance_valid(_network) and _network.has_signal("roster_changed"):
		if not _network.roster_changed.is_connected(_on_network_roster_changed):
			_network.roster_changed.connect(_on_network_roster_changed)

func _exit_tree() -> void:
	if is_instance_valid(_network) and _network.has_signal("roster_changed"):
		if _network.roster_changed.is_connected(_on_network_roster_changed):
			_network.roster_changed.disconnect(_on_network_roster_changed)
	super._exit_tree()

func start_round(peer_id: int) -> Dictionary:
	if not _is_authority():
		return _failure("Only the host can start Chicken Cross.")
	if state != TableState.OPEN:
		return _failure("Chicken Cross is not open for starting.")
	var reserved_wagers: Array[Dictionary] = get_round_wagers()
	if reserved_wagers.is_empty():
		return _failure("Chicken Cross needs at least one wager.")
	var seen_peers: Dictionary = {}
	for wager: Dictionary in reserved_wagers:
		var bettor_id: int = int(wager.get("peer_id", 0))
		if bettor_id <= 0 or seen_peers.has(bettor_id):
			return _failure("Chicken Cross allows exactly one wager per participant.")
		if str(wager.get("status", "")) != "reserved":
			return _failure("Every Chicken Cross wager must still be reserved before start.")
		seen_peers[bettor_id] = true
	var start_result: Dictionary = super.start_round(peer_id)
	if not bool(start_result.get("ok", false)):
		return start_result
	var locked_wagers: Array[Dictionary] = get_round_wagers()
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
	if multiplayer.multiplayer_peer != null:
		_receive_player_state.rpc(peer_id, player_state)

@rpc("authority", "call_remote", "reliable")
func _receive_player_state(peer_id: int, player_state: Dictionary) -> void:
	if not validate_rpc(1):
		return
	player_state_changed.emit(peer_id, player_state.duplicate(true))
