extends BaseTable

const RoundModel = preload("res://casino/tables/chicken_cross/chicken_cross_round.gd")
const Rules = preload("res://casino/tables/chicken_cross/chicken_cross_rules.gd")
const BettingKeypadControllerScript = preload("res://casino/terminals/components/betting_keypad_controller.gd")
const ChickenVisualScript = preload("res://casino/tables/chicken_cross/chicken_cross_chicken.gd")

signal player_state_changed(peer_id: int, player_state: Dictionary)
signal round_finished(payouts: Dictionary, settlement: Dictionary)

var _round_model: RefCounted = null
var _network: Node = null
## Last authoritative state for every participant; used by the shared table display.
var _round_player_states: Dictionary = {}

@export var proximity_area: Area3D
@export var cross_interactable: Interactable
@export var cash_out_interactable: Interactable

func _ready() -> void:
	super._ready()
	_setup_physical_collisions()
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

## Add simple, stable primitive collision to the authored table and its mounted devices.
## The chicken contestants remain visual-only so they never obstruct players or each other.
func _setup_physical_collisions() -> void:
	if get_node_or_null("ChickenCrossPhysicalBody") == null:
		var table_body: StaticBody3D = StaticBody3D.new()
		table_body.name = "ChickenCrossPhysicalBody"
		table_body.collision_layer = 1
		table_body.collision_mask = 1
		add_child(table_body)
		_add_box_collision(table_body, "TableTop", Vector3(3.4, 0.1975, 2.2), Vector3(0.0, 0.96875, 0.0))
		_add_box_collision(table_body, "FrontLeftLeg", Vector3(0.22, 0.9, 0.22), Vector3(-1.48, 0.45, 0.88))
		_add_box_collision(table_body, "FrontRightLeg", Vector3(0.22, 0.9, 0.22), Vector3(1.48, 0.45, 0.88))
		_add_box_collision(table_body, "BackLeftLeg", Vector3(0.22, 0.9, 0.22), Vector3(-1.48, 0.45, -0.88))
		_add_box_collision(table_body, "BackRightLeg", Vector3(0.22, 0.9, 0.22), Vector3(1.48, 0.45, -0.88))

	var screen: Node3D = get_node_or_null("SlimWorldScreen") as Node3D
	if is_instance_valid(screen) and screen.get_node_or_null("ChickenCrossScreenCollision") == null:
		var screen_body: StaticBody3D = StaticBody3D.new()
		screen_body.name = "ChickenCrossScreenCollision"
		screen_body.collision_layer = 1
		screen_body.collision_mask = 1
		screen.add_child(screen_body)
		_add_box_collision(screen_body, "ScreenHousing", Vector3(3.62, 1.72, 0.32), Vector3(0.0, 0.0, 0.0))

	_add_button_housing_collision(NodePath("Controls/CrossButton"))
	_add_button_housing_collision(NodePath("Controls/CashOutButton"))

	var keypad_housing: Node3D = get_node_or_null("BettingKeypad/Housing") as Node3D
	var housing_mesh: MeshInstance3D = get_node_or_null("BettingKeypad/Housing/MeshInstance3D") as MeshInstance3D
	if is_instance_valid(keypad_housing) and is_instance_valid(housing_mesh) and keypad_housing.get_node_or_null("ChickenCrossHousingCollision") == null:
		var keypad_body: StaticBody3D = StaticBody3D.new()
		keypad_body.name = "ChickenCrossHousingCollision"
		keypad_body.collision_layer = 1
		keypad_body.collision_mask = 1
		keypad_housing.add_child(keypad_body)
		var housing_shape: BoxShape3D = BoxShape3D.new()
		housing_shape.size = housing_mesh.get_aabb().size
		var housing_collision: CollisionShape3D = CollisionShape3D.new()
		housing_collision.name = "HousingShape"
		housing_collision.shape = housing_shape
		housing_collision.transform = housing_mesh.transform
		keypad_body.add_child(housing_collision)

func _add_button_housing_collision(button_path: NodePath) -> void:
	var button: Node3D = get_node_or_null(button_path) as Node3D
	if not is_instance_valid(button) or button.get_node_or_null("ChickenCrossHousingCollision") != null:
		return
	var housing: MeshInstance3D = button.get_node_or_null("Visuals/ButtonHousing") as MeshInstance3D
	if not is_instance_valid(housing) or housing.mesh == null:
		return
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "ChickenCrossHousingCollision"
	body.collision_layer = 1
	body.collision_mask = 1
	button.add_child(body)
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = housing.get_aabb().size
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "HousingShape"
	collision.shape = shape
	collision.transform = housing.transform
	body.add_child(collision)

func _add_box_collision(parent: StaticBody3D, shape_name: String, size: Vector3, local_position: Vector3) -> void:
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = shape_name
	collision.shape = shape
	collision.position = local_position
	parent.add_child(collision)

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

func open_round(peer_id: int) -> Dictionary:
	var result: Dictionary = super.open_round(peer_id)
	if bool(result.get("ok", false)):
		_round_player_states.clear()
		_clear_chicken_visuals()
		_update_table_terminal_display()
	return result

## A successful wager immediately creates that player's visible contestant on every peer.
func place_wager(peer_id: int, amount: int, payload: Dictionary = {}) -> Dictionary:
	var result: Dictionary = super.place_wager(peer_id, amount, payload)
	if not bool(result.get("ok", false)):
		return result
	var player_state: Dictionary = {
		"peer_id": peer_id,
		"stake": amount,
		"tile": 0,
		"status": "active",
		"multiplier": 0.0,
		"gross_return": 0,
	}
	_publish_player_presentation(peer_id, player_state)
	return result

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

	# Validate and prepare the game model BEFORE BaseTable locks the wallet.
	# A malformed wager must never leave a live round with committed stakes
	# but no usable Chicken Cross state.
	var seen_peers: Dictionary = {}
	var seen_wager_ids: Dictionary = {}
	var model_wagers: Array[Dictionary] = []
	for wager: Dictionary in reserved_wagers:
		var bettor_id: int = int(wager.get("peer_id", 0))
		var wager_id: String = str(wager.get("wager_id", ""))
		var stake: int = int(wager.get("stake", 0))
		if bettor_id <= 0 or wager_id.is_empty() or stake <= 0:
			return _failure("Every Chicken Cross wager needs a valid player, wager ID, and positive stake.")
		if seen_peers.has(bettor_id):
			return _failure("Chicken Cross allows exactly one active wager per participant.")
		if seen_wager_ids.has(wager_id):
			return _failure("Chicken Cross wager IDs must be unique.")
		seen_peers[bettor_id] = true
		seen_wager_ids[wager_id] = true
		var model_wager: Dictionary = wager.duplicate(true)
		model_wager["status"] = "locked"
		model_wagers.append(model_wager)

	if not seen_peers.has(peer_id):
		return _failure("Only a player with a confirmed wager can start Chicken Cross.")

	var prepared_model: RefCounted = RoundModel.new()
	var model_result: Dictionary = prepared_model.call("begin", model_wagers)
	if not bool(model_result.get("ok", false)):
		return _failure("Chicken Cross could not prepare its wagers: %s" % str(model_result.get("reason", "")))

	var start_result: Dictionary = super.start_round(peer_id)
	if not bool(start_result.get("ok", false)):
		return start_result
	_round_model = prepared_model
	_round_player_states.clear()
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

	# Area3D body_entered can report any physics body, not only a Player.
	# Check that this actor actually exposes the player identity property
	# before reading it; Object.get() returns null for a missing property,
	# and converting that null with int() raises a runtime error.
	var has_input_peer_id: bool = false
	for property_info: Dictionary in actor.get_property_list():
		if str(property_info.get("name", "")) == "input_peer_id":
			has_input_peer_id = true
			break
	if not has_input_peer_id:
		return 0

	var peer_value: Variant = actor.get("input_peer_id")
	if typeof(peer_value) != TYPE_INT:
		return 0
	var peer_id: int = peer_value

	# Offline players may not receive a network owner ID. Treat the local
	# offline player as the offline multiplayer peer so table proximity and
	# keypad confirmation use the same identity.
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
	if not multiplayer.is_server() or not _validate_remote_action_sender():
		return
	_handle_player_action(multiplayer.get_remote_sender_id(), true)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_cash_out() -> void:
	if not multiplayer.is_server() or not _validate_remote_action_sender():
		return
	_handle_player_action(multiplayer.get_remote_sender_id(), false)

func _validate_remote_action_sender() -> bool:
	if not is_instance_valid(_network) or not _network.has_method("validate_rpc"):
		return false
	return bool(_network.call("validate_rpc"))

func _handle_player_action(peer_id: int, advance_chicken: bool) -> Dictionary:
	var result: Dictionary = _resolve_player_action(peer_id, advance_chicken)
	var feedback_message: String = ""
	var feedback_severity: StringName = &"error"
	if bool(result.get("ok", false)):
		feedback_message = "CHICKEN ADVANCED" if advance_chicken else "CASH OUT ACCEPTED"
		feedback_severity = &"success"
	else:
		feedback_message = str(result.get("reason", "Chicken Cross action rejected."))
	report_player_feedback(peer_id, feedback_message, feedback_severity)
	return result


func _resolve_player_action(peer_id: int, advance_chicken: bool) -> Dictionary:
	if not _is_authority():
		return _failure("Only the host can resolve Chicken Cross actions.")
	if not _is_near_table(peer_id):
		return _failure("The player must remain within table proximity.")
	# The first CROSS starts the shared round and is announced once to every player.
	var round_just_started: bool = false
	if state == TableState.OPEN:
		if not advance_chicken:
			return _failure("CROSS must start the round before any player can cash out.")
		var start_result: Dictionary = start_round(peer_id)
		if not bool(start_result.get("ok", false)):
			return start_result
		round_just_started = true
	if state != TableState.RUNNING or _round_model == null:
		return _failure("Chicken Cross is not currently running.")
	var result: Dictionary
	if advance_chicken:
		result = _round_model.call("advance", peer_id, randf())
	else:
		result = _round_model.call("cash_out", peer_id)
	if not bool(result.get("ok", false)):
		return result
	if round_just_started:
		report_global_announcement("CHICKEN CROSS STARTED", "CHICKEN CROSS", 2)
	if not advance_chicken:
		report_global_announcement("PLAYER %d CASHED OUT" % peer_id, "CASH OUT", 2)
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
	_publish_player_presentation(peer_id, player_state)

func _publish_player_presentation(peer_id: int, source_state: Dictionary) -> void:
	var player_state: Dictionary = source_state.duplicate(true)
	player_state["peer_id"] = peer_id
	player_state["nickname"] = _get_player_nickname(peer_id)
	player_state["color_index"] = _get_player_color_index(peer_id)
	_round_player_states[peer_id] = player_state.duplicate(true)
	player_state_changed.emit(peer_id, player_state.duplicate(true))
	_sync_chicken_visual(peer_id, player_state)
	_reposition_chicken_visuals()
	_apply_local_player_presentation(peer_id, player_state)
	_update_table_terminal_display()
	if multiplayer.multiplayer_peer != null:
		_receive_player_state.rpc(peer_id, player_state)


func _apply_local_player_presentation(peer_id: int, player_state: Dictionary) -> void:
	# The lane's single-player highlight is a local convenience only. The shared
	# terminal below always reports every participant, on every peer.
	if peer_id != multiplayer.get_unique_id():
		return
	var visuals: Node = get_node_or_null("Visuals")
	if visuals != null and visuals.has_method("apply_player_state"):
		visuals.call("apply_player_state", player_state)


func get_round_player_display_lines() -> Array[String]:
	var lines: Array[String] = []
	var peer_ids: Array[int] = []
	for peer_value: Variant in _round_player_states.keys():
		peer_ids.append(int(peer_value))
	peer_ids.sort()
	for peer_id: int in peer_ids:
		var player_state: Dictionary = _round_player_states[peer_id]
		var nickname: String = str(player_state.get("nickname", "PLAYER %d" % peer_id))
		var color_name: String = PlayerIdentity.color_name_for_index(int(player_state.get("color_index", _get_player_color_index(peer_id)))).to_upper()
		var tile_number: int = int(player_state.get("tile", 0))
		var stake: int = int(player_state.get("stake", 0))
		var status: String = str(player_state.get("status", "active"))
		var detail: String = ""
		match status:
			"failed":
				detail = "FAILED AT %02d" % tile_number
			"cashed_out":
				detail = "BANKED $%s" % _format_currency(int(player_state.get("gross_return", 0)))
			_:
				detail = "READY" if tile_number <= 0 else "TILE %02d/%02d  %.1fX" % [
					tile_number,
					Rules.TILE_COUNT,
					float(player_state.get("multiplier", 0.0))
				]
		lines.append("%s  %s  BET $%s  %s" % [color_name, nickname, _format_currency(stake), detail])
	return lines


func _get_player_color_index(peer_id: int) -> int:
	if is_instance_valid(_network) and _network.has_method("get_player_identity"):
		var identity: PlayerIdentity = _network.call("get_player_identity", peer_id) as PlayerIdentity
		if identity != null:
			return identity.color_index
	return posmod(peer_id - 1, PlayerIdentity.palette_size())

func _get_chicken_visual_root() -> Node3D:
	var visuals: Node3D = get_node_or_null("Visuals") as Node3D
	if not is_instance_valid(visuals):
		return null
	var root: Node3D = visuals.get_node_or_null("_ChickenCrossContestants") as Node3D
	if not is_instance_valid(root):
		root = Node3D.new()
		root.name = "_ChickenCrossContestants"
		visuals.add_child(root)
	return root

func _clear_chicken_visuals() -> void:
	var root: Node = get_node_or_null("Visuals/_ChickenCrossContestants")
	if not is_instance_valid(root):
		return
	for child: Node in root.get_children():
		child.queue_free()

func _sync_chicken_visual(peer_id: int, player_state: Dictionary) -> void:
	var root: Node3D = _get_chicken_visual_root()
	if not is_instance_valid(root):
		return
	var chicken: ChickenCrossChicken = root.get_node_or_null("Chicken_%d" % peer_id) as ChickenCrossChicken
	var is_new: bool = not is_instance_valid(chicken)
	var status: String = str(player_state.get("status", "active"))
	var previous_status: String = str(chicken.get_meta("display_status", "active")) if not is_new else "active"
	if not is_new and status == "active" and previous_status in ["failed", "cashed_out"]:
		root.remove_child(chicken)
		chicken.queue_free()
		chicken = null
		is_new = true
	if is_new:
		chicken = ChickenVisualScript.new() as ChickenCrossChicken
		chicken.name = "Chicken_%d" % peer_id
		root.add_child(chicken)
		chicken.scale = Vector3.ONE * 0.42
	var tile_number: int = clampi(int(player_state.get("tile", 0)), 0, Rules.TILE_COUNT)
	var lane_index: int = _lane_index_for_peer(peer_id)
	chicken.configure(peer_id, str(player_state.get("nickname", _get_player_nickname(peer_id))), int(player_state.get("color_index", _get_player_color_index(peer_id))))
	chicken.set_board_position(_contestant_position(tile_number, lane_index, 0.16), not is_new)
	if not is_new and previous_status != status:
		if status == "failed":
			chicken.play_failure()
		elif status == "cashed_out":
			chicken.play_cash_out()
	chicken.set_meta("display_status", status)
	_sync_player_tile_marker(peer_id, player_state)

func _sync_player_tile_marker(peer_id: int, player_state: Dictionary) -> void:
	var root: Node3D = _get_chicken_visual_root()
	if not is_instance_valid(root):
		return
	var marker_name: String = "PlayerTileMarker_%d" % peer_id
	var marker: MeshInstance3D = root.get_node_or_null(marker_name) as MeshInstance3D
	if not is_instance_valid(marker):
		marker = MeshInstance3D.new()
		marker.name = marker_name
		var marker_mesh: BoxMesh = BoxMesh.new()
		marker_mesh.size = Vector3(0.205, 0.009, 0.17)
		marker.mesh = marker_mesh
		root.add_child(marker)
	var tile_number: int = clampi(int(player_state.get("tile", 0)), 0, Rules.TILE_COUNT)
	var marker_position: Vector3 = _contestant_position(tile_number, _lane_index_for_peer(peer_id), 0.008)
	marker.position = marker_position
	var marker_mesh: BoxMesh = marker.mesh as BoxMesh
	if marker_mesh != null:
		marker_mesh.size = Vector3(0.13, 0.008, 0.11)
	var marker_color: Color = PlayerIdentity.color_for_index(int(player_state.get("color_index", _get_player_color_index(peer_id))))
	var status: String = str(player_state.get("status", "active"))
	if status == "failed":
		marker_color = Color("#e53935")
	elif status == "cashed_out":
		marker_color = Color("#ffc45b")
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = marker_color
	material.emission_enabled = true
	material.emission = marker_color
	material.emission_energy_multiplier = 0.85
	material.roughness = 0.32
	marker.material_override = material

func _reposition_chicken_visuals() -> void:
	var root: Node = get_node_or_null("Visuals/_ChickenCrossContestants")
	if not is_instance_valid(root):
		return
	var peer_ids: Array[int] = []
	for value: Variant in _round_player_states.keys():
		peer_ids.append(int(value))
	peer_ids.sort()
	for index: int in range(peer_ids.size()):
		var peer_id: int = peer_ids[index]
		var player_state: Dictionary = _round_player_states.get(peer_id, {})
		var chicken: Node3D = root.get_node_or_null("Chicken_%d" % peer_id) as Node3D
		if is_instance_valid(chicken):
			chicken.set_board_position(_contestant_position(int(player_state.get("tile", 0)), index, 0.16), true)
		_sync_player_tile_marker(peer_id, player_state)

func _lane_index_for_peer(peer_id: int) -> int:
	var peer_ids: Array[int] = []
	for value: Variant in _round_player_states.keys():
		peer_ids.append(int(value))
	if not peer_ids.has(peer_id):
		peer_ids.append(peer_id)
	peer_ids.sort()
	return clampi(peer_ids.find(peer_id), 0, 3)

## Resolve contestant positions from the authored tile meshes instead of guessed
## world coordinates, keeping chickens and markers aligned if the board is moved.
func _contestant_position(tile_number: int, lane_index: int, height_offset: float) -> Vector3:
	var visuals: Node3D = get_node_or_null("Visuals") as Node3D
	if not is_instance_valid(visuals):
		return Vector3.ZERO
	var tile_index: int = clampi(tile_number, 1, Rules.TILE_COUNT)
	var tile: MeshInstance3D = visuals.get_node_or_null("TileLane/Tile_%02d" % tile_index) as MeshInstance3D
	if not is_instance_valid(tile) or tile.mesh == null:
		return Vector3(-1.53 + float(tile_number) * 0.25, 1.09 + height_offset, -0.33 + float(lane_index) * 0.22)
	var bounds: AABB = tile.mesh.get_aabb()
	var local_center: Vector3 = bounds.position + bounds.size * 0.5
	var lane_spacing: float = minf(0.22, bounds.size.z / 4.0)
	var lane_offset: float = (float(lane_index) - 1.5) * lane_spacing
	local_center.z += lane_offset
	local_center.y = bounds.position.y + bounds.size.y
	var surface_world: Vector3 = tile.to_global(local_center)
	if tile_number == 0:
		var next_tile: MeshInstance3D = visuals.get_node_or_null("TileLane/Tile_02") as MeshInstance3D
		if is_instance_valid(next_tile):
			var step: Vector3 = tile.global_position - next_tile.global_position
			surface_world += step
	return visuals.to_local(surface_world + Vector3.UP * height_offset)

func _get_player_nickname(peer_id: int) -> String:
	if is_instance_valid(_network) and _network.has_method("get_player_identity"):
		var identity: Object = _network.call("get_player_identity", peer_id) as Object
		if identity != null:
			var nickname_value: Variant = identity.get("nickname")
			if nickname_value is String and not str(nickname_value).strip_edges().is_empty():
				return str(nickname_value)
	return "PLAYER %d" % peer_id


func _update_table_terminal_display() -> void:
	var world_screen: Node = get_node_or_null("SlimWorldScreen/WorldScreen")
	if world_screen == null or not world_screen.has_method("set_content"):
		return
	var lines: Array[String] = get_round_player_display_lines()
	var body: String = "\n".join(lines)
	var prompt: String = "CROSS TO ADVANCE  /  CASH OUT TO BANK"
	if lines.is_empty():
		body = "PLACE A WAGER TO JOIN THE ROUND"
		prompt = "WAGER TERMINAL READY"
	world_screen.call("set_content", "CHICKEN CROSS  |  PLAYERS %d" % lines.size(), body, prompt)

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
	var received_state: Dictionary = player_state.duplicate(true)
	received_state["peer_id"] = peer_id
	_round_player_states[peer_id] = received_state
	player_state_changed.emit(peer_id, received_state.duplicate(true))
	_sync_chicken_visual(peer_id, received_state)
	_reposition_chicken_visuals()
	_apply_local_player_presentation(peer_id, received_state)
	_update_table_terminal_display()
