## Persistent casino HUD controller.
## Presentation only: authoritative managers remain the source of all gameplay state.
extends CanvasLayer

const PHASE_CASINO: int = 2
const TERMINAL_FONT: Font = preload("res://assets/fonts/JetBrainsMonoNL-Regular.ttf")
const BOLD_FONT: Font = preload("res://assets/fonts/JetBrainsMono-Bold.ttf")
const QUOTA_GLOW_SHADER: Shader = preload("res://ui/hud/quota_glow.gdshader")
const COLOR_WALLET: Color = Color(0.25, 0.88, 0.49, 1.0)
const COLOR_QUOTA_UNMET: Color = Color(0.94, 0.29, 0.32, 1.0)
const COLOR_QUOTA_MET: Color = Color(1.0, 0.78, 0.38, 1.0)
const COLOR_TEXT: Color = Color(0.94, 0.94, 0.91, 1.0)
const COLOR_MUTED: Color = Color(0.57, 0.59, 0.60, 1.0)
const COLOR_PANEL: Color = Color(0.018, 0.023, 0.026, 0.84)
const COLOR_PANEL_EDGE: Color = Color(0.72, 0.75, 0.73, 0.9)
const COLOR_TIMER_URGENT: Color = Color(0.96, 0.34, 0.31, 1.0)

@export_group("Display Nodes")
@export var day_label_path: NodePath = ^"MarginContainer/LayoutRoot/TopLeft/WalletStack/DayLabel"
@export var wallet_label_path: NodePath = ^"MarginContainer/LayoutRoot/TopLeft/WalletStack/WalletLabel"
@export var quota_label_path: NodePath = ^"MarginContainer/LayoutRoot/TopLeft/WalletStack/QuotaLabel"
@export var timer_label_path: NodePath = ^"MarginContainer/LayoutRoot/TopCenter/TimerLabel"

@export_group("Terminal Typography")
@export var terminal_font: Font
@export_range(8, 64, 1) var day_font_size: int = 17
@export_range(16, 96, 1) var wallet_font_size: int = 46
@export_range(12, 72, 1) var quota_font_size: int = 29
@export_range(16, 96, 1) var timer_font_size: int = 34

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
var _network: Node
var _players_root: Node
var _local_player: Node
var _focused_interactable: Interactable
var _last_day_snapshot: Dictionary = {}
var _last_run_active: bool = false
var _last_quota_reached: bool = false

var _contributions: Dictionary = {}
var _counted_wagers: Dictionary = {}
var _current_contribution_day: int = 0
var _contribution_list: VBoxContainer
var _modifier_panel: PanelContainer
var _blessed_label: Label
var _watched_label: Label

var _action_list: VBoxContainer
var _action_rows: Dictionary = {}
var _action_refresh_elapsed: float = 0.0
var _last_action_signature: String = ""

var _announcement_panel: PanelContainer
var _announcement_label: Label
var _announcement_subtitle: Label
var _announcement_queue: Array[Dictionary] = []
var _announcement_tween: Tween
var _announcement_active: bool = false
var _connected_tables: Array[BaseTable] = []
var _wallet_glow_material: ShaderMaterial
var _quota_glow_material: ShaderMaterial
var _glow_tween: Tween


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

	add_to_group("casino_hud")
	get_tree().node_added.connect(_on_tree_node_added)
	_apply_typography()
	_connect_services()
	_build_runtime_hud_sections()
	_set_hud_controls_mouse_passthrough()
	for table_node: Node in get_tree().get_nodes_in_group("casino_tables"):
		_connect_table_feedback_source(table_node)
	_connect_focus_sources()
	_refresh_all()
	call_deferred("_refresh_visibility")
	set_process(true)


func _process(delta: float) -> void:
	_action_refresh_elapsed += delta
	if _action_refresh_elapsed >= 0.12:
		_action_refresh_elapsed = 0.0
		_refresh_action_prompt()


func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_on_tree_node_added):
		get_tree().node_added.disconnect(_on_tree_node_added)
	for table: BaseTable in _connected_tables:
		if is_instance_valid(table) and table.player_feedback.is_connected(_on_table_feedback):
			table.player_feedback.disconnect(_on_table_feedback)
	_connected_tables.clear()
	_disconnect_services()
	if _announcement_tween != null and _announcement_tween.is_running():
		_announcement_tween.kill()
	if _glow_tween != null and _glow_tween.is_running():
		_glow_tween.kill()


func _validate_display_nodes() -> bool:
	var valid: bool = true
	for pair: Array in [[_day_label, "DayLabel"], [_wallet_label, "WalletLabel"], [_quota_label, "QuotaLabel"], [_timer_label, "TimerLabel"]]:
		if pair[0] == null:
			push_error("CasinoHUD is missing %s. Check its exported NodePath." % pair[1])
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
	for label: Label in [_day_label, _wallet_label, _quota_label, _timer_label]:
		label.add_theme_font_override("font", terminal_font)
		label.add_theme_color_override("font_color", COLOR_TEXT)
	_day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_wallet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_quota_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_day_label.add_theme_font_size_override("font_size", day_font_size)
	_wallet_label.add_theme_font_override("font", BOLD_FONT)
	_wallet_label.add_theme_font_size_override("font_size", wallet_font_size)
	_quota_label.add_theme_font_size_override("font_size", quota_font_size)
	_timer_label.add_theme_font_override("font", BOLD_FONT)
	_timer_label.add_theme_font_size_override("font_size", timer_font_size)
	_day_label.add_theme_color_override("font_color", COLOR_TEXT)


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
	_disconnect_signal(_run_manager, &"run_state_changed", _on_run_state_changed)
	_disconnect_signal(_day_manager, &"day_state_changed", _on_day_state_changed)
	_disconnect_signal(_wallet, &"wallet_changed", _on_wallet_changed)
	_disconnect_signal(_wallet, &"wager_changed", _on_wager_changed)
	_disconnect_signal(_day_manager, &"day_finished", _on_day_finished)
	_disconnect_signal(_network, &"identity_roster_changed", _on_identity_roster_changed)
	_disconnect_signal(_players_root, &"child_entered_tree", _on_player_added)
	_disconnect_signal(_main_controller, &"world_changed", _on_world_changed)


func _disconnect_signal(source: Node, signal_name: StringName, callback: Callable) -> void:
	if is_instance_valid(source) and source.has_signal(signal_name) and source.is_connected(signal_name, callback):
		source.disconnect(signal_name, callback)


func _on_tree_node_added(node: Node) -> void:
	_connect_table_feedback_source(node)


func _connect_table_feedback_source(node: Node) -> void:
	var table: BaseTable = node as BaseTable
	if not is_instance_valid(table) or _connected_tables.has(table):
		return
	if not table.player_feedback.is_connected(_on_table_feedback):
		table.player_feedback.connect(_on_table_feedback)
	_connected_tables.append(table)


func _on_table_feedback(peer_id: int, message: String, severity: StringName) -> void:
	if peer_id != _get_local_peer_id():
		return
	var tint: Color = COLOR_TEXT
	var priority: int = 0
	match severity:
		&"success":
			tint = COLOR_WALLET
		&"warning":
			tint = COLOR_QUOTA_MET
			priority = 1
		&"error":
			tint = COLOR_QUOTA_UNMET
			priority = 1
	_show_announcement(message, tint, priority)


func _get_local_peer_id() -> int:
	if is_instance_valid(_local_player):
		var peer_id: int = int(_local_player.get("input_peer_id"))
		if peer_id > 0:
			return peer_id
	return multiplayer.get_unique_id()


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
	if int(snapshot.get("phase", -1)) == PHASE_CASINO:
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
		_show_announcement("DAILY QUOTA REACHED", COLOR_QUOTA_MET, 3, "EARLY DEPARTURE UNLOCKED")
		if is_instance_valid(_wallet_glow_material):
			_play_quota_glow_pulse()
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
		_timer_label.add_theme_color_override("font_color", COLOR_TIMER_URGENT if seconds_remaining <= urgent_timer_threshold_seconds else COLOR_TEXT)
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
	if _wallet_glow_material == null or _quota_glow_material == null:
		return
	if _glow_tween != null and _glow_tween.is_running():
		_glow_tween.kill()
	var target: float = 1.0 if enabled else 0.0
	_wallet_glow_material.set_shader_parameter("glow_strength", target)
	_quota_glow_material.set_shader_parameter("glow_strength", target)


func _play_quota_glow_pulse() -> void:
	if _glow_tween != null and _glow_tween.is_running():
		_glow_tween.kill()
	_glow_tween = create_tween()
	_glow_tween.tween_method(_set_glow_strength, 0.35, 1.65, 0.42)
	_glow_tween.tween_method(_set_glow_strength, 1.65, 1.0, 0.8)


func _set_glow_strength(value: float) -> void:
	if is_instance_valid(_wallet_glow_material):
		_wallet_glow_material.set_shader_parameter("glow_strength", value)
	if is_instance_valid(_quota_glow_material):
		_quota_glow_material.set_shader_parameter("glow_strength", value)


func _refresh_visibility() -> void:
	var in_casino: bool = false
	if is_instance_valid(_main_controller):
		in_casino = _main_controller.get("active_world") == 1
	else:
		var run_snapshot: Dictionary = _run_manager.call("get_snapshot")
		in_casino = int(run_snapshot.get("phase", -1)) == PHASE_CASINO
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
	return "%02d:%02d" % [floori(float(safe_seconds) / 60.0), safe_seconds % 60]


func _build_runtime_hud_sections() -> void:
	# Top-right status placeholder. It stays visible as a reserved, intentionally empty readout.
	_modifier_panel = _make_panel()
	_modifier_panel.name = "ModifierStatusPanel"
	_modifier_panel.anchor_left = 1.0
	_modifier_panel.anchor_right = 1.0
	_modifier_panel.offset_left = -360.0
	_modifier_panel.offset_top = 28.0
	_modifier_panel.offset_right = -30.0
	_modifier_panel.offset_bottom = 94.0
	add_child(_modifier_panel)
	var modifier_stack: VBoxContainer = VBoxContainer.new()
	modifier_stack.add_theme_constant_override("separation", 2)
	modifier_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modifier_panel.add_child(modifier_stack)
	_blessed_label = _make_runtime_label("BLESSED   —", 14, HORIZONTAL_ALIGNMENT_LEFT, true)
	_watched_label = _make_runtime_label("WATCHED  —", 14, HORIZONTAL_ALIGNMENT_LEFT, true)
	modifier_stack.add_child(_blessed_label)
	modifier_stack.add_child(_watched_label)

	# Contributions keep their existing settled-wager semantics, now in a quiet framed readout.
	var contribution_panel: PanelContainer = _make_panel()
	contribution_panel.name = "ContributionPanel"
	contribution_panel.anchor_left = 1.0
	contribution_panel.anchor_right = 1.0
	contribution_panel.offset_left = -360.0
	contribution_panel.offset_top = 104.0
	contribution_panel.offset_right = -30.0
	contribution_panel.offset_bottom = 292.0
	add_child(contribution_panel)
	var contribution_root: VBoxContainer = VBoxContainer.new()
	contribution_root.add_theme_constant_override("separation", 7)
	contribution_panel.add_child(contribution_root)
	var heading: Label = _make_runtime_label("TODAY'S CONTRIBUTOR", 13, HORIZONTAL_ALIGNMENT_LEFT, true)
	heading.add_theme_color_override("font_color", COLOR_MUTED)
	contribution_root.add_child(heading)
	_contribution_list = VBoxContainer.new()
	_contribution_list.add_theme_constant_override("separation", 5)
	contribution_root.add_child(_contribution_list)
	_refresh_contribution_panel()

	# The control list is intentionally unboxed and anchored to the lower-right corner.
	_action_list = VBoxContainer.new()
	_action_list.name = "ContextualControls"
	_action_list.anchor_left = 1.0
	_action_list.anchor_top = 1.0
	_action_list.anchor_right = 1.0
	_action_list.anchor_bottom = 1.0
	_action_list.offset_left = -390.0
	_action_list.offset_top = -280.0
	_action_list.offset_right = -32.0
	_action_list.offset_bottom = -28.0
	_action_list.alignment = BoxContainer.ALIGNMENT_END
	_action_list.add_theme_constant_override("separation", 4)
	_action_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_action_list)

	# Announcement is the only prominent center-screen panel; its queue is priority-aware.
	_announcement_panel = _make_panel()
	_announcement_panel.name = "CenterAnnouncer"
	_announcement_panel.anchor_left = 0.5
	_announcement_panel.anchor_right = 0.5
	_announcement_panel.offset_left = -330.0
	_announcement_panel.offset_top = 104.0
	_announcement_panel.offset_right = 330.0
	_announcement_panel.offset_bottom = 170.0
	_announcement_panel.modulate.a = 0.0
	add_child(_announcement_panel)
	var announcement_stack: VBoxContainer = VBoxContainer.new()
	announcement_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	announcement_stack.add_theme_constant_override("separation", 4)
	_announcement_panel.add_child(announcement_stack)
	_announcement_subtitle = _make_runtime_label("CASINO NOTICE", 10, HORIZONTAL_ALIGNMENT_CENTER, true)
	_announcement_subtitle.add_theme_color_override("font_color", COLOR_MUTED)
	_announcement_label = _make_runtime_label("", 19, HORIZONTAL_ALIGNMENT_CENTER, true)
	_announcement_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	announcement_stack.add_child(_announcement_subtitle)
	announcement_stack.add_child(_announcement_label)

	_wallet_glow_material = _make_glow_material()
	_quota_glow_material = _make_glow_material()
	_wallet_label.material = _wallet_glow_material
	_quota_label.material = _quota_glow_material
	_set_quota_glow(bool(_last_day_snapshot.get("quota_reached", false)))
	_refresh_action_prompt()


func _make_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	panel.add_theme_constant_override("panel", 12)
	return panel


func _make_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.border_color = COLOR_PANEL_EDGE
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	style.shadow_size = 7
	style.content_margin_left = 13.0
	style.content_margin_right = 13.0
	style.content_margin_top = 9.0
	style.content_margin_bottom = 9.0
	return style


func _make_glow_material() -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = QUOTA_GLOW_SHADER
	material.set_shader_parameter("glow_color", COLOR_QUOTA_MET)
	material.set_shader_parameter("glow_radius", 4.0)
	material.set_shader_parameter("glow_strength", 0.0)
	return material


func _set_hud_controls_mouse_passthrough() -> void:
	for node: Node in find_children("*", "Control", true, false):
		var control: Control = node as Control
		if is_instance_valid(control):
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _make_runtime_label(label_text: String, size: int, alignment: int, bold: bool = false) -> Label:
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = label_text
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", COLOR_TEXT)
	label.add_theme_font_override("font", BOLD_FONT if bold else terminal_font)
	return label


func _on_wager_changed(wager_id: String, status: String) -> void:
	if status != "settled" or _counted_wagers.has(wager_id) or not is_instance_valid(_wallet):
		return
	var wager: Dictionary = _wallet.call("get_wager", wager_id)
	if wager.is_empty() or int(wager.get("peer_id", 0)) <= 0:
		return
	_counted_wagers[wager_id] = true
	var peer_id: int = int(wager.get("peer_id", 0))
	_contributions[peer_id] = int(_contributions.get(peer_id, 0)) + int(wager.get("net_result", 0))
	_refresh_contribution_panel()


func _refresh_contribution_panel() -> void:
	if not is_instance_valid(_contribution_list):
		return
	for child: Node in _contribution_list.get_children():
		_contribution_list.remove_child(child)
		child.queue_free()
	if _contributions.is_empty():
		_contribution_list.add_child(_make_runtime_label("NO SETTLED WAGERS", 12, HORIZONTAL_ALIGNMENT_LEFT))
		return
	var peer_ids: Array = _contributions.keys()
	peer_ids.sort()
	for peer_value: Variant in peer_ids:
		var peer_id: int = int(peer_value)
		var amount: int = int(_contributions[peer_id])
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var amount_label: Label = _make_runtime_label(_format_signed_money(amount), 14, HORIZONTAL_ALIGNMENT_LEFT, true)
		amount_label.add_theme_color_override("font_color", COLOR_WALLET if amount > 0 else COLOR_QUOTA_UNMET if amount < 0 else COLOR_TEXT)
		amount_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nickname_label: Label = _make_runtime_label(_get_player_nickname(peer_id), 14, HORIZONTAL_ALIGNMENT_RIGHT, true)
		var identity: Object = _get_player_identity(peer_id)
		if identity != null and identity.has_method("get_color"):
			nickname_label.add_theme_color_override("font_color", identity.call("get_color"))
		row.add_child(amount_label)
		row.add_child(nickname_label)
		_contribution_list.add_child(row)
	_set_hud_controls_mouse_passthrough()


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
	return str(identity.get("nickname")) if identity != null else "PLAYER %d" % peer_id


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
			if carrier.is_holding():
				_on_carry_started_for_prompt(carrier.held_item)
		_refresh_action_prompt()
		return


func _on_focus_target_changed(target: Interactable) -> void:
	_focused_interactable = target
	_refresh_action_prompt()


func _refresh_action_prompt() -> void:
	if not is_instance_valid(_action_list):
		return
	var lines: Array[Dictionary] = []
	var carrying: bool = is_instance_valid(_local_player) and _local_player.has_method("is_carrying") and bool(_local_player.call("is_carrying"))
	var limp: bool = is_instance_valid(_local_player) and bool(_local_player.get("is_limp"))
	var recovering: bool = is_instance_valid(_local_player) and bool(_local_player.get("is_recovering"))
	var terminal_locked: bool = is_instance_valid(_local_player) and bool(_local_player.get("terminal_movement_locked"))
	var moving: bool = false
	var grounded: bool = false
	if is_instance_valid(_local_player):
		var velocity_value: Variant = _local_player.get("velocity")
		if velocity_value is Vector3:
			var horizontal: Vector2 = Vector2(velocity_value.x, velocity_value.z)
			moving = horizontal.length() > 0.35
		if _local_player.has_method("is_on_floor"):
			grounded = bool(_local_player.call("is_on_floor"))

	if limp or recovering:
		lines.append({"text": "RECOVER — AUTOMATIC", "indent": 0})
	elif carrying:
		lines.append({"text": "THROW — [HOLD Q]", "indent": 0})
		lines.append({"text": "DROP — [Q]", "indent": 1})
	elif not terminal_locked:
		if is_instance_valid(_focused_interactable) and _focused_interactable.enabled:
			var controls: PackedStringArray = PackedStringArray()
			if _focused_interactable.action_for_input(&"primary") != &"":
				controls.append("M1")
			if _focused_interactable.action_for_input(&"interact") != &"":
				controls.append("E")
			if not controls.is_empty():
				lines.append({"text": "INTERACT — [%s]" % ", ".join(controls), "indent": 0})
		if moving:
			lines.append({"text": "SPRINT — [SHIFT]", "indent": 0})
			if grounded:
				lines.append({"text": "JUMP — [SPACE]", "indent": 1})
		else:
			lines.append({"text": "MOVE — [W] [A] [S] [D]", "indent": 0})
		if moving:
			lines.append({"text": "MOVE — [W] [A] [S] [D]", "indent": 0})
		lines.append({"text": "JAB / CHARGED PUNCH — [Q]", "indent": 1})
		lines.append({"text": "PARRY — [F]", "indent": 1})

	var signature: String = JSON.stringify(lines)
	if signature == _last_action_signature:
		return
	_last_action_signature = signature
	for child: Node in _action_list.get_children():
		_action_list.remove_child(child)
		child.queue_free()
	# VBox reads top-to-bottom; append the baseline movement entry last so it sits at the bottom.
	for line: Dictionary in lines:
		var label: Label = _make_runtime_label(str(line["text"]), 13, HORIZONTAL_ALIGNMENT_LEFT, true)
		label.add_theme_color_override("font_color", COLOR_TEXT if int(line["indent"]) == 0 else COLOR_MUTED)
		if int(line["indent"]) > 0:
			label.add_theme_constant_override("margin_left", 14)
		_action_list.add_child(label)


func _on_day_finished(day: int, success: bool, final_wallet: int, quota: int) -> void:
	var result_text: String = "QUOTA MET" if success else "QUOTA MISSED"
	_show_announcement("DAY %d — %s" % [day, result_text], COLOR_QUOTA_MET if success else COLOR_QUOTA_UNMET, 3,
		"WALLET %s  /  %s" % [_format_money(final_wallet), _format_money(quota)])


func _show_announcement(message: String, text_color: Color = COLOR_TEXT, priority: int = -1, subtitle: String = "") -> void:
	if not is_instance_valid(_announcement_panel):
		return
	var resolved_priority: int = priority
	if resolved_priority < 0:
		var upper: String = message.to_upper()
		resolved_priority = 3 if upper.contains("DAY ") or upper.contains("QUOTA REACHED") or upper.contains("GAME OVER") else 1 if upper.contains("WON") or upper.contains("LOST") else 0
	var item: Dictionary = {"message": message, "color": text_color, "priority": resolved_priority, "subtitle": subtitle}
	if _announcement_queue.size() >= 8:
		var lowest_index: int = 0
		for i in range(_announcement_queue.size()):
			if int(_announcement_queue[i]["priority"]) < int(_announcement_queue[lowest_index]["priority"]):
				lowest_index = i
		if int(_announcement_queue[lowest_index]["priority"]) > resolved_priority:
			return
		_announcement_queue.remove_at(lowest_index)
	var insert_at: int = _announcement_queue.size()
	for i in range(_announcement_queue.size()):
		if resolved_priority > int(_announcement_queue[i]["priority"]):
			insert_at = i
			break
	_announcement_queue.insert(insert_at, item)
	if not _announcement_active:
		_play_next_announcement()


func _play_next_announcement() -> void:
	if _announcement_queue.is_empty() or not is_instance_valid(_announcement_panel):
		_announcement_active = false
		return
	_announcement_active = true
	var item: Dictionary = _announcement_queue.pop_front()
	_announcement_label.text = str(item["message"])
	_announcement_label.add_theme_color_override("font_color", item["color"])
	_announcement_subtitle.text = str(item["subtitle"]) if not str(item["subtitle"]).is_empty() else "CASINO NOTICE"
	_announcement_panel.modulate.a = 0.0
	_announcement_panel.scale = Vector2(0.97, 0.97)
	if _announcement_tween != null and _announcement_tween.is_running():
		_announcement_tween.kill()
	_announcement_tween = create_tween()
	_announcement_tween.set_parallel(true)
	_announcement_tween.tween_property(_announcement_panel, "modulate:a", 1.0, 0.22)
	_announcement_tween.tween_property(_announcement_panel, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_announcement_tween.set_parallel(false)
	_announcement_tween.tween_interval(2.45 if int(item["priority"]) < 3 else 3.4)
	_announcement_tween.tween_property(_announcement_panel, "modulate:a", 0.0, 0.38)
	_announcement_tween.finished.connect(_on_announcement_finished)


func _on_announcement_finished() -> void:
	_announcement_active = false
	_play_next_announcement()


## Future modifier service integration point. Only call with authoritative player assignments.
func set_modifier_status(blessed_player: String, watched_player: String) -> void:
	if not is_instance_valid(_modifier_panel):
		return
	_blessed_label.text = "BLESSED  —  %s" % blessed_player if not blessed_player.is_empty() else "BLESSED  —"
	_watched_label.text = "WATCHED —  %s" % watched_player if not watched_player.is_empty() else "WATCHED —"
	_modifier_panel.visible = true


func _on_carry_started_for_prompt(_item: Node3D) -> void:
	_refresh_action_prompt()


func _on_carry_ended_for_prompt() -> void:
	_refresh_action_prompt()
