## Persistent casino HUD controller.
## Reads authoritative progression and wallet services; it never mutates game state.
extends CanvasLayer

const PHASE_CASINO: int = 2
const TERMINAL_FONT: Font = preload("res://assets/fonts/JetBrainsMonoNL-Regular.ttf")
const COLOR_WALLET: Color = Color(0.25, 0.82, 0.48, 1.0)
const COLOR_QUOTA_UNMET: Color = Color(0.88, 0.27, 0.29, 1.0)
const COLOR_QUOTA_MET: Color = Color(0.91, 0.72, 0.34, 1.0)
const COLOR_TIMER_NORMAL: Color = Color(0.96, 0.94, 0.88, 1.0)
const COLOR_TIMER_URGENT: Color = Color(0.91, 0.34, 0.31, 1.0)

@export_group("Display Nodes")
@export var day_label_path: NodePath = ^"MarginContainer/LayoutRoot/TopLeft/WalletStack/DayLabel"
@export var wallet_label_path: NodePath = ^"MarginContainer/LayoutRoot/TopLeft/WalletStack/WalletLabel"
@export var quota_label_path: NodePath = ^"MarginContainer/LayoutRoot/TopLeft/WalletStack/QuotaLabel"
@export var timer_label_path: NodePath = ^"MarginContainer/LayoutRoot/TopCenter/TimerLabel"

@export_group("Terminal Typography")
@export var terminal_font: Font
@export_range(8, 64, 1) var day_font_size: int = 16
@export_range(16, 96, 1) var wallet_font_size: int = 42
@export_range(12, 72, 1) var quota_font_size: int = 30
@export_range(16, 96, 1) var timer_font_size: int = 36

@export_group("Timer Warning")
@export_range(1, 120, 1) var urgent_timer_threshold_seconds: int = 30

var _day_label: Label
var _wallet_label: Label
var _quota_label: Label
var _timer_label: Label

var _run_manager: Node
var _day_manager: Node
var _wallet: Node
var _main_controller: Node
var _last_day_snapshot: Dictionary = {}
var _network: Node
var _players_root: Node
var _local_player: Node
var _focused_interactable: Interactable
var _contributions: Dictionary = {}
var _counted_wagers: Dictionary = {}
var _current_contribution_day: int = 0
var _last_run_active: bool = false
var _last_quota_reached: bool = false
var _contribution_list: VBoxContainer
var _modifier_panel: HBoxContainer
var _blessed_label: Label
var _watched_label: Label
var _action_prompt: VBoxContainer
var _announcement_label: Label
var _announcement_tween: Tween


func _ready() -> void:
	_day_label = get_node_or_null(day_label_path) as Label
	_wallet_label = get_node_or_null(wallet_label_path) as Label
	_quota_label = get_node_or_null(quota_label_path) as Label
	_timer_label = get_node_or_null(timer_label_path) as Label

	if not _validate_display_nodes():
		set_process(false)
		return

	_run_manager = get_node_or_null("/root/RunManager")
	_day_manager = get_node_or_null("/root/CasinoDayManager")
	_wallet = get_node_or_null("/root/CasinoWallet")
	_main_controller = get_parent()

	if not is_instance_valid(_run_manager) or not is_instance_valid(_day_manager) or not is_instance_valid(_wallet):
		push_error("CasinoHUD requires RunManager, CasinoDayManager, and CasinoWallet autoloads.")
		visible = false
		return

	_apply_typography()
	_connect_services()
	_build_runtime_hud_sections()
	_connect_focus_sources()
	_refresh_all()
	call_deferred("_refresh_visibility")


func _exit_tree() -> void:
	_disconnect_services()


func _validate_display_nodes() -> bool:
	var valid: bool = true
	if _day_label == null:
		push_error("CasinoHUD is missing its DayLabel. Check day_label_path.")
		valid = false
	if _wallet_label == null:
		push_error("CasinoHUD is missing its WalletLabel. Check wallet_label_path.")
		valid = false
	if _quota_label == null:
		push_error("CasinoHUD is missing its QuotaLabel. Check quota_label_path.")
		valid = false
	if _timer_label == null:
		push_error("CasinoHUD is missing its TimerLabel. Check timer_label_path.")
		valid = false
	return valid


func _apply_typography() -> void:
	if terminal_font == null:
		terminal_font = TERMINAL_FONT
	var layout_root: Control = get_node_or_null("MarginContainer/LayoutRoot") as Control
	var top_left: Control = get_node_or_null("MarginContainer/LayoutRoot/TopLeft") as Control
	var top_center: Control = get_node_or_null("MarginContainer/LayoutRoot/TopCenter") as Control
	if is_instance_valid(layout_root):
		layout_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if is_instance_valid(top_left):
		top_left.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if is_instance_valid(top_center):
		top_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_wallet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_quota_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	for label: Label in [_day_label, _wallet_label, _quota_label, _timer_label]:
		if terminal_font != null:
			label.add_theme_font_override("font", terminal_font)

	_day_label.add_theme_font_size_override("font_size", day_font_size)
	_wallet_label.add_theme_font_size_override("font_size", wallet_font_size)
	_quota_label.add_theme_font_size_override("font_size", quota_font_size)
	_timer_label.add_theme_font_size_override("font_size", timer_font_size)


func _connect_services() -> void:
	if _run_manager.has_signal("run_state_changed"):
		_run_manager.run_state_changed.connect(_on_run_state_changed)
	if _day_manager.has_signal("day_state_changed"):
		_day_manager.day_state_changed.connect(_on_day_state_changed)
	if _wallet.has_signal("wallet_changed"):
		_wallet.wallet_changed.connect(_on_wallet_changed)
	if _wallet.has_signal("wager_changed"):
		_wallet.wager_changed.connect(_on_wager_changed)
	if _day_manager.has_signal("day_finished"):
		_day_manager.day_finished.connect(_on_day_finished)
	_network = get_node_or_null("/root/Network")
	if is_instance_valid(_network) and _network.has_signal("identity_roster_changed"):
		_network.identity_roster_changed.connect(_on_identity_roster_changed)
	_players_root = get_node_or_null("../Players")
	if is_instance_valid(_players_root) and _players_root.has_signal("child_entered_tree"):
		_players_root.child_entered_tree.connect(_on_player_added)
	if is_instance_valid(_main_controller) and _main_controller.has_signal("world_changed"):
		_main_controller.world_changed.connect(_on_world_changed)


func _disconnect_services() -> void:
	if is_instance_valid(_run_manager) and _run_manager.has_signal("run_state_changed"):
		if _run_manager.run_state_changed.is_connected(_on_run_state_changed):
			_run_manager.run_state_changed.disconnect(_on_run_state_changed)
	if is_instance_valid(_day_manager) and _day_manager.has_signal("day_state_changed"):
		if _day_manager.day_state_changed.is_connected(_on_day_state_changed):
			_day_manager.day_state_changed.disconnect(_on_day_state_changed)
	if is_instance_valid(_wallet) and _wallet.has_signal("wallet_changed"):
		if _wallet.wallet_changed.is_connected(_on_wallet_changed):
			_wallet.wallet_changed.disconnect(_on_wallet_changed)
	if is_instance_valid(_wallet) and _wallet.has_signal("wager_changed"):
		if _wallet.wager_changed.is_connected(_on_wager_changed):
			_wallet.wager_changed.disconnect(_on_wager_changed)
	if is_instance_valid(_day_manager) and _day_manager.has_signal("day_finished"):
		if _day_manager.day_finished.is_connected(_on_day_finished):
			_day_manager.day_finished.disconnect(_on_day_finished)
	if is_instance_valid(_network) and _network.has_signal("identity_roster_changed"):
		if _network.identity_roster_changed.is_connected(_on_identity_roster_changed):
			_network.identity_roster_changed.disconnect(_on_identity_roster_changed)
	if is_instance_valid(_players_root) and _players_root.has_signal("child_entered_tree"):
		if _players_root.child_entered_tree.is_connected(_on_player_added):
			_players_root.child_entered_tree.disconnect(_on_player_added)
	if is_instance_valid(_main_controller) and _main_controller.has_signal("world_changed"):
		if _main_controller.world_changed.is_connected(_on_world_changed):
			_main_controller.world_changed.disconnect(_on_world_changed)


func _on_run_state_changed(snapshot: Dictionary) -> void:
	var run_active: bool = bool(snapshot.get("run_active", false))
	if run_active and not _last_run_active:
		_contributions.clear()
		_counted_wagers.clear()
		_current_contribution_day = int(snapshot.get("current_day", 0))
		_last_quota_reached = false
		_refresh_contribution_panel()
	_last_run_active = run_active
	_refresh_visibility()
	_day_label.text = "DAY %d" % int(snapshot.get("current_day", 0))
	if int(snapshot.get("phase", -1)) != PHASE_CASINO:
		return
	_refresh_day_and_wallet()


func _on_day_state_changed(snapshot: Dictionary) -> void:
	var new_day: int = int(snapshot.get("day_number", 0))
	if new_day > 0 and new_day != _current_contribution_day:
		_current_contribution_day = new_day
		_contributions.clear()
		_counted_wagers.clear()
		_refresh_contribution_panel()
	var quota_now: bool = bool(snapshot.get("quota_reached", false))
	if quota_now and not _last_quota_reached:
		_show_announcement("DAILY QUOTA REACHED")
	_last_quota_reached = quota_now
	_last_day_snapshot = snapshot.duplicate(true)
	_refresh_day_display(snapshot)


func _on_wallet_changed(available_balance: int, _reserved_total: int) -> void:
	_wallet_label.text = _format_money(available_balance)
	_refresh_quota_colors()


func _on_world_changed(_previous_world: int, _current_world: int) -> void:
	_refresh_visibility()


func _refresh_all() -> void:
	var run_snapshot: Dictionary = _run_manager.call("get_snapshot")
	_day_label.text = "DAY %d" % int(run_snapshot.get("current_day", 0))
	_refresh_day_and_wallet()
	_refresh_visibility()


func _refresh_day_and_wallet() -> void:
	_last_day_snapshot = _day_manager.call("get_snapshot")
	var wallet_snapshot: Dictionary = _wallet.call("get_snapshot")
	_wallet_label.text = _format_money(int(wallet_snapshot.get("available_balance", 0)))
	_refresh_day_display(_last_day_snapshot)


func _refresh_day_display(snapshot: Dictionary) -> void:
	var day_number: int = int(snapshot.get("day_number", 0))
	var wallet_balance: int = int(snapshot.get("wallet_balance", 0))
	var quota: int = int(snapshot.get("daily_quota", 0))
	var seconds_remaining: int = int(snapshot.get("seconds_remaining", 0))
	var quota_reached: bool = bool(snapshot.get("quota_reached", false))
	var day_active: bool = bool(snapshot.get("day_active", false))

	if day_number > 0:
		_day_label.text = "DAY %d" % day_number
	if day_active:
		_wallet_label.text = _format_money(wallet_balance)
		_quota_label.text = "/ " + _format_money(quota)
		_timer_label.text = _format_time(seconds_remaining)
		_timer_label.add_theme_color_override("font_color", COLOR_TIMER_URGENT if seconds_remaining <= urgent_timer_threshold_seconds else COLOR_TIMER_NORMAL)
	else:
		_quota_label.text = ""
		_timer_label.text = ""

	_wallet_label.add_theme_color_override("font_color", COLOR_QUOTA_MET if quota_reached else COLOR_WALLET)
	_quota_label.add_theme_color_override("font_color", COLOR_QUOTA_MET if quota_reached else COLOR_QUOTA_UNMET)
	_set_quota_glow(quota_reached)


func _refresh_quota_colors() -> void:
	var quota_reached: bool = bool(_last_day_snapshot.get("quota_reached", false))
	_wallet_label.add_theme_color_override("font_color", COLOR_QUOTA_MET if quota_reached else COLOR_WALLET)
	_quota_label.add_theme_color_override("font_color", COLOR_QUOTA_MET if quota_reached else COLOR_QUOTA_UNMET)
	_set_quota_glow(quota_reached)


func _set_quota_glow(enabled: bool) -> void:
	var glow_color: Color = Color(1.0, 0.72, 0.28, 0.78) if enabled else Color(0.0, 0.0, 0.0, 0.0)
	for label: Label in [_wallet_label, _quota_label]:
		label.add_theme_color_override("font_shadow_color", glow_color)
		label.add_theme_constant_override("shadow_outline_size", 10 if enabled else 0)
		label.add_theme_constant_override("shadow_offset_x", 0)
		label.add_theme_constant_override("shadow_offset_y", 0)


func _refresh_visibility() -> void:
	var in_casino: bool = false
	if is_instance_valid(_main_controller):
		in_casino = _main_controller.get("active_world") == 1
	else:
		var run_snapshot: Dictionary = _run_manager.call("get_snapshot")
		in_casino = run_snapshot.get("phase", -1) == PHASE_CASINO
	visible = in_casino


func _format_money(amount: int) -> String:
	var negative: bool = amount < 0
	var digits: String = str(absi(amount))
	var grouped: String = ""
	while digits.length() > 3:
		grouped = "," + digits.substr(digits.length() - 3, 3) + grouped
		digits = digits.substr(0, digits.length() - 3)
	grouped = digits + grouped
	return ("-$" if negative else "$") + grouped


func _format_time(total_seconds: int) -> String:
	var safe_seconds: int = maxi(0, total_seconds)
	var minutes: int = floori(float(safe_seconds) / 60.0)
	var seconds: int = safe_seconds % 60
	return "%02d:%02d" % [minutes, seconds]



func _build_runtime_hud_sections() -> void:
	# Build the complete visual layer from code. The scene only needs this script;
	# all panels, spacing, typography, and contextual rows are generated here.
	var layout_root: Control = get_node_or_null("MarginContainer/LayoutRoot") as Control
	var top_left: Control = get_node_or_null("MarginContainer/LayoutRoot/TopLeft") as Control
	var top_center: Control = get_node_or_null("MarginContainer/LayoutRoot/TopCenter") as Control

	var wallet_stack: VBoxContainer = get_node_or_null("MarginContainer/LayoutRoot/TopLeft/WalletStack") as VBoxContainer
	if is_instance_valid(wallet_stack) and is_instance_valid(top_left):
		var wallet_panel: PanelContainer = _make_panel()
		wallet_panel.name = "WalletPanel"
		wallet_panel.position = Vector2.ZERO
		wallet_panel.custom_minimum_size = Vector2(360.0, 0.0)
		top_left.add_child(wallet_panel)
		wallet_stack.reparent(wallet_panel)
		wallet_stack.add_theme_constant_override("separation", 2)
		wallet_stack.add_theme_constant_override("margin_left", 0)
		wallet_stack.add_theme_constant_override("margin_right", 0)
		wallet_stack.add_theme_constant_override("margin_top", 0)
		wallet_stack.add_theme_constant_override("margin_bottom", 0)

	var timer_panel: PanelContainer = _make_panel()
	timer_panel.name = "TimerPanel"
	timer_panel.anchor_left = 0.5
	timer_panel.anchor_right = 0.5
	timer_panel.offset_left = -130.0
	timer_panel.offset_top = 0.0
	timer_panel.offset_right = 130.0
	timer_panel.offset_bottom = 58.0
	if is_instance_valid(top_center):
		top_center.add_child(timer_panel)
	if is_instance_valid(_timer_label):
		_timer_label.reparent(timer_panel)
		_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_timer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var right_stack: VBoxContainer = VBoxContainer.new()
	right_stack.name = "RightStatusStack"
	right_stack.anchor_left = 1.0
	right_stack.anchor_right = 1.0
	right_stack.offset_left = -420.0
	right_stack.offset_top = 32.0
	right_stack.offset_right = -32.0
	right_stack.offset_bottom = 330.0
	right_stack.add_theme_constant_override("separation", 8)
	add_child(right_stack)

	var modifier_panel: PanelContainer = _make_panel()
	modifier_panel.name = "ModifierPanel"
	right_stack.add_child(modifier_panel)
	_modifier_panel = HBoxContainer.new()
	_modifier_panel.add_theme_constant_override("separation", 12)
	modifier_panel.add_child(_modifier_panel)
	_blessed_label = _make_runtime_label("BLESSED —", 14, HORIZONTAL_ALIGNMENT_LEFT)
	_watched_label = _make_runtime_label("WATCHED —", 14, HORIZONTAL_ALIGNMENT_RIGHT)
	_blessed_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_watched_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modifier_panel.add_child(_blessed_label)
	_modifier_panel.add_child(_watched_label)

	var contribution_panel: PanelContainer = _make_panel()
	contribution_panel.name = "ContributionPanel"
	right_stack.add_child(contribution_panel)
	var contribution_root: VBoxContainer = VBoxContainer.new()
	contribution_root.add_theme_constant_override("separation", 6)
	contribution_panel.add_child(contribution_root)
	var heading: Label = _make_runtime_label("TODAY'S CONTRIBUTIONS", 13, HORIZONTAL_ALIGNMENT_LEFT)
	heading.add_theme_color_override("font_color", COLOR_QUOTA_MET)
	contribution_root.add_child(heading)
	_contribution_list = VBoxContainer.new()
	_contribution_list.add_theme_constant_override("separation", 4)
	contribution_root.add_child(_contribution_list)
	_refresh_contribution_panel()

	var action_panel: PanelContainer = _make_panel()
	action_panel.name = "ContextualActionPanel"
	action_panel.anchor_top = 1.0
	action_panel.anchor_bottom = 1.0
	action_panel.offset_left = 32.0
	action_panel.offset_top = -218.0
	action_panel.offset_right = 390.0
	action_panel.offset_bottom = -32.0
	add_child(action_panel)
	var action_stack: VBoxContainer = VBoxContainer.new()
	action_stack.name = "ActionList"
	action_stack.add_theme_constant_override("separation", 7)
	action_panel.add_child(action_stack)
	_action_prompt = action_stack

	_announcement_label = _make_runtime_label("", 20, HORIZONTAL_ALIGNMENT_CENTER)
	_announcement_label.anchor_left = 0.5
	_announcement_label.anchor_right = 0.5
	_announcement_label.offset_left = -360.0
	_announcement_label.offset_top = 112.0
	_announcement_label.offset_right = 360.0
	_announcement_label.offset_bottom = 154.0
	_announcement_label.modulate.a = 0.0
	add_child(_announcement_label)
	_refresh_action_prompt()


func _make_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.035, 0.035, 0.88)
	style.border_color = Color(0.22, 0.36, 0.31, 0.85)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 14.0
	style.content_margin_top = 10.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _make_runtime_label(label_text: String, size: int, alignment: int) -> Label:
	var label: Label = Label.new()
	label.text = label_text
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", COLOR_TIMER_NORMAL)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.35))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	if terminal_font != null:
		label.add_theme_font_override("font", terminal_font)
	return label

func _on_wager_changed(wager_id: String, status: String) -> void:
	if status != "settled" or _counted_wagers.has(wager_id) or not is_instance_valid(_wallet):
		return
	var wager: Dictionary = _wallet.call("get_wager", wager_id)
	if wager.is_empty():
		return
	if int(wager.get("peer_id", 0)) <= 0:
		return
	_counted_wagers[wager_id] = true
	var peer_id: int = int(wager.get("peer_id", 0))
	var net_result: int = int(wager.get("net_result", 0))
	_contributions[peer_id] = int(_contributions.get(peer_id, 0)) + net_result
	_refresh_contribution_panel()


func _refresh_contribution_panel() -> void:
	if not is_instance_valid(_contribution_list):
		return
	for child: Node in _contribution_list.get_children():
		_contribution_list.remove_child(child)
		child.queue_free()
	if _contributions.is_empty():
		var empty_label: Label = _make_runtime_label("NO SETTLED WAGERS", 14, HORIZONTAL_ALIGNMENT_LEFT)
		_contribution_list.add_child(empty_label)
		return
	var peer_ids: Array = _contributions.keys()
	peer_ids.sort()
	for peer_value: Variant in peer_ids:
		var peer_id: int = int(peer_value)
		var amount: int = int(_contributions[peer_id])
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var amount_label: Label = _make_runtime_label(_format_signed_money(amount), 16, HORIZONTAL_ALIGNMENT_LEFT)
		amount_label.add_theme_color_override("font_color", COLOR_WALLET if amount > 0 else COLOR_QUOTA_UNMET if amount < 0 else COLOR_TIMER_NORMAL)
		amount_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nickname_label: Label = _make_runtime_label(_get_player_nickname(peer_id), 16, HORIZONTAL_ALIGNMENT_RIGHT)
		var identity: Object = _get_player_identity(peer_id)
		if identity != null and identity.has_method("get_color"):
			nickname_label.add_theme_color_override("font_color", identity.call("get_color"))
		row.add_child(amount_label)
		row.add_child(nickname_label)
		_contribution_list.add_child(row)


func _format_signed_money(amount: int) -> String:
	if amount > 0:
		return "+" + _format_money(amount)
	if amount < 0:
		return "-" + _format_money(absi(amount))
	return _format_money(0)


func _get_player_identity(peer_id: int) -> Object:
	if not is_instance_valid(_network) or not _network.has_method("get_player_identity"):
		return null
	return _network.call("get_player_identity", peer_id) as Object


func _get_player_nickname(peer_id: int) -> String:
	var identity: Object = _get_player_identity(peer_id)
	if identity != null:
		return str(identity.get("nickname"))
	return "PLAYER %d" % peer_id


func _on_identity_roster_changed() -> void:
	_refresh_contribution_panel()


func _on_player_added(_player: Node) -> void:
	call_deferred("_connect_focus_sources")


func _connect_focus_sources() -> void:
	if not is_instance_valid(_players_root):
		return
	for player: Node in _players_root.get_children():
		if not bool(player.get("is_local_player")):
			continue
		_local_player = player
		var focus_node: Node = player.find_child("Focus", true, false)
		if is_instance_valid(focus_node) and focus_node.has_signal("focus_target_changed"):
			if not focus_node.focus_target_changed.is_connected(_on_focus_target_changed):
				focus_node.focus_target_changed.connect(_on_focus_target_changed)
		var carrier: Node = player.get("carrier") as Node
		if is_instance_valid(carrier):
			if carrier.has_signal("carry_started") and not carrier.carry_started.is_connected(_on_carry_started_for_prompt):
				carrier.carry_started.connect(_on_carry_started_for_prompt)
			if carrier.has_signal("carry_ended") and not carrier.carry_ended.is_connected(_on_carry_ended_for_prompt):
				carrier.carry_ended.connect(_on_carry_ended_for_prompt)
		_refresh_action_prompt()
		return


func _on_focus_target_changed(target: Interactable) -> void:
	_focused_interactable = target
	_refresh_action_prompt()


func _refresh_action_prompt() -> void:
	if not is_instance_valid(_action_prompt):
		return
	for child: Node in _action_prompt.get_children():
		_action_prompt.remove_child(child)
		child.queue_free()

	var heading: Label = _make_runtime_label("AVAILABLE ACTIONS", 12, HORIZONTAL_ALIGNMENT_LEFT)
	heading.add_theme_color_override("font_color", COLOR_QUOTA_MET)
	_action_prompt.add_child(heading)

	var carrying: bool = is_instance_valid(_local_player) and _local_player.has_method("is_carrying") and bool(_local_player.call("is_carrying"))
	if carrying:
		_add_action_row("Q", "TAP TO DROP")
		_add_action_row("HOLD Q", "CHARGE & AUTO-THROW")
	else:
		_add_action_row("Q", "JAB")
		_add_action_row("HOLD Q", "CHARGED PUNCH")
		_add_action_row("F", "PARRY")

	if is_instance_valid(_focused_interactable) and _focused_interactable.enabled:
		var prompt: String = _focused_interactable.prompt_text.strip_edges()
		if _focused_interactable.action_for_input(&"primary") != &"":
			_add_action_row("M1", prompt)
		if _focused_interactable.action_for_input(&"interact") != &"":
			_add_action_row("E", prompt)


func _add_action_row(key_text: String, action_text: String) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var key_label: Label = _make_runtime_label(key_text, 14, HORIZONTAL_ALIGNMENT_LEFT)
	key_label.custom_minimum_size.x = 78.0
	key_label.add_theme_color_override("font_color", COLOR_QUOTA_MET)
	var action_label: Label = _make_runtime_label(action_text, 14, HORIZONTAL_ALIGNMENT_LEFT)
	action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(key_label)
	row.add_child(action_label)
	_action_prompt.add_child(row)

func _on_day_finished(day: int, success: bool, final_wallet: int, quota: int) -> void:
	var result_text: String = "QUOTA MET" if success else "QUOTA MISSED"
	_show_announcement("DAY %d — %s  |  WALLET %s / %s" % [day, result_text, _format_money(final_wallet), _format_money(quota)])


func _show_announcement(message: String) -> void:
	if not is_instance_valid(_announcement_label):
		return
	_announcement_label.text = message
	if _announcement_tween != null and _announcement_tween.is_running():
		_announcement_tween.kill()
	_announcement_label.modulate.a = 0.0
	_announcement_tween = create_tween()
	_announcement_tween.tween_property(_announcement_label, "modulate:a", 1.0, 0.2)
	_announcement_tween.tween_interval(2.8)
	_announcement_tween.tween_property(_announcement_label, "modulate:a", 0.0, 0.5)


## Future modifier service integration point. Call only with authoritative, real player assignments.
func set_modifier_status(blessed_player: String, watched_player: String) -> void:
	if not is_instance_valid(_modifier_panel):
		return
	_blessed_label.text = "BLESSED — %s" % blessed_player if not blessed_player.is_empty() else "BLESSED —"
	_watched_label.text = "WATCHED — %s" % watched_player if not watched_player.is_empty() else "WATCHED —"
	_modifier_panel.visible = true


func _on_carry_started_for_prompt(_item: Node3D) -> void:
	_refresh_action_prompt()


func _on_carry_ended_for_prompt() -> void:
	_refresh_action_prompt()
