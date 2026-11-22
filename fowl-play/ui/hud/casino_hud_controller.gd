## Persistent casino HUD controller.
## Reads authoritative progression and wallet services; it never mutates game state.
extends CanvasLayer

const PHASE_CASINO: int = 2
const COLOR_WALLET: Color = Color(0.25, 0.82, 0.48, 1.0)
const COLOR_QUOTA_UNMET: Color = Color(0.88, 0.27, 0.29, 1.0)
const COLOR_QUOTA_MET: Color = Color(0.91, 0.72, 0.34, 1.0)
const COLOR_TIMER_NORMAL: Color = Color(0.96, 0.94, 0.88, 1.0)
const COLOR_TIMER_URGENT: Color = Color(0.91, 0.34, 0.31, 1.0)

@export_group("Display Nodes")
@export var day_label_path: NodePath = ^"MarginContainer/TopLeft/DayLabel"
@export var wallet_label_path: NodePath = ^"MarginContainer/TopLeft/WalletLabel"
@export var quota_label_path: NodePath = ^"MarginContainer/TopLeft/QuotaLabel"
@export var timer_label_path: NodePath = ^"MarginContainer/TopCenter/TimerLabel"

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
	if is_instance_valid(_main_controller) and _main_controller.has_signal("world_changed"):
		if _main_controller.world_changed.is_connected(_on_world_changed):
			_main_controller.world_changed.disconnect(_on_world_changed)


func _on_run_state_changed(snapshot: Dictionary) -> void:
	_refresh_visibility()
	_day_label.text = "DAY %d" % int(snapshot.get("current_day", 0))
	if int(snapshot.get("phase", -1)) != PHASE_CASINO:
		return
	_refresh_day_and_wallet()


func _on_day_state_changed(snapshot: Dictionary) -> void:
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


func _refresh_quota_colors() -> void:
	var quota_reached: bool = bool(_last_day_snapshot.get("quota_reached", false))
	_wallet_label.add_theme_color_override("font_color", COLOR_QUOTA_MET if quota_reached else COLOR_WALLET)
	_quota_label.add_theme_color_override("font_color", COLOR_QUOTA_MET if quota_reached else COLOR_QUOTA_UNMET)


func _refresh_visibility() -> void:
	var in_casino: bool = false
	if is_instance_valid(_main_controller):
		in_casino = int(_main_controller.get("active_world")) == 1
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
	var minutes: int = floori(float(safe_seconds) / 60.0)
	var seconds: int = safe_seconds % 60
	return "%02d:%02d" % [minutes, seconds]
