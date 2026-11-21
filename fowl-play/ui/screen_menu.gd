## Input-independent selectable menu model for reusable WorldScreen displays.
## A terminal/device forwards its validated semantic actions to handle_action().
class_name ScreenMenu
extends RefCounted

signal opened
signal selection_changed(selected_index: int, option_id: StringName)
signal option_confirmed(option_id: StringName, option_label: String)
signal cancelled
signal closed

const ACTION_UP: StringName = &"menu_up"
const ACTION_DOWN: StringName = &"menu_down"
const ACTION_CONFIRM: StringName = &"menu_confirm"
const ACTION_CANCEL: StringName = &"menu_cancel"

var wrap_navigation: bool = true
var _screen: WorldScreen = null
var _header: String = ""
var _description: String = ""
var _prompt: String = ""
var _options: Array[Dictionary] = []
var _selected_index: int = -1
var _active: bool = false

func is_active() -> bool:
	return _active

func get_selected_index() -> int:
	return _selected_index

func get_selected_option_id() -> StringName:
	if not _active or _selected_index < 0 or _selected_index >= _options.size():
		return &""
	return StringName(_options[_selected_index]["id"])

func get_options() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for option: Dictionary in _options:
		result.append(option.duplicate(true))
	return result

## Options require unique non-empty ids and labels. enabled defaults to true.
func open(target_screen: WorldScreen, header: String, description: String, options: Array[Dictionary], prompt: String = "UP/DOWN NAVIGATE  •  USE SELECT") -> bool:
	if not is_instance_valid(target_screen) or options.is_empty():
		return false
	var normalized: Array[Dictionary] = []
	var seen_ids: Dictionary = {}
	var first_enabled: int = -1
	for option: Dictionary in options:
		var option_id: StringName = StringName(str(option.get("id", "")).strip_edges())
		var option_label: String = str(option.get("label", "")).strip_edges()
		var enabled: bool = bool(option.get("enabled", true))
		if option_id == &"" or option_label.is_empty() or seen_ids.has(option_id):
			return false
		seen_ids[option_id] = true
		normalized.append({"id": option_id, "label": option_label, "enabled": enabled})
		if enabled and first_enabled < 0:
			first_enabled = normalized.size() - 1
	if first_enabled < 0:
		return false
	if _active:
		close()
	_screen = target_screen
	_header = header
	_description = description
	_prompt = prompt
	_options = normalized
	_selected_index = first_enabled
	_active = true
	_render()
	opened.emit()
	_emit_selection_changed()
	return true

## Positive direction moves down; negative direction moves up.
func move_selection(direction: int) -> bool:
	if not _active or direction == 0:
		return false
	var next_index: int = _find_next_enabled(_selected_index, 1 if direction > 0 else -1)
	if next_index < 0 or next_index == _selected_index:
		return false
	_selected_index = next_index
	_render()
	_emit_selection_changed()
	return true

func select_index(index: int) -> bool:
	if not _active or index < 0 or index >= _options.size() or not bool(_options[index]["enabled"]) or index == _selected_index:
		return false
	_selected_index = index
	_render()
	_emit_selection_changed()
	return true

func confirm() -> bool:
	if not _active or _selected_index < 0:
		return false
	var option: Dictionary = _options[_selected_index]
	if not bool(option["enabled"]):
		return false
	option_confirmed.emit(StringName(option["id"]), str(option["label"]))
	return true

func cancel() -> bool:
	if not _active:
		return false
	cancelled.emit()
	close()
	return true

func close() -> void:
	if not _active:
		return
	_active = false
	if is_instance_valid(_screen):
		_screen.clear_screen()
	_screen = null
	_options.clear()
	_selected_index = -1
	closed.emit()

## This model never captures global input; an active input owner forwards semantic actions.
func handle_action(action: StringName) -> bool:
	match action:
		ACTION_UP:
			return move_selection(-1)
		ACTION_DOWN:
			return move_selection(1)
		ACTION_CONFIRM:
			return confirm()
		ACTION_CANCEL:
			return cancel()
		_:
			return false

func _find_next_enabled(from_index: int, direction: int) -> int:
	var candidate: int = from_index
	for _step: int in range(_options.size()):
		candidate += direction
		if wrap_navigation:
			candidate = posmod(candidate, _options.size())
		elif candidate < 0 or candidate >= _options.size():
			return -1
		if bool(_options[candidate]["enabled"]):
			return candidate
	return -1

func _render() -> void:
	if is_instance_valid(_screen):
		_screen.show_menu(_header, _description, _options, _selected_index, _prompt)

func _emit_selection_changed() -> void:
	selection_changed.emit(_selected_index, get_selected_option_id())
