## Local debug infrastructure for Fowl Play.
## Owns logs, watches, commands, category switches, and no gameplay state.

extends Node

const TUNING = preload("res://core/tuning.gd")

signal console_opened
signal console_closed
signal log_added(line: String)
signal registry_changed

const CATEGORY_NET: StringName = &"net"
const CATEGORY_COMBAT: StringName = &"combat"
const CATEGORY_LIMP: StringName = &"limp"
const CATEGORY_CARRY: StringName = &"carry"
const CATEGORY_HANDS: StringName = &"hands"
const CATEGORY_INTERACT: StringName = &"interact"
const CATEGORY_LEGS: StringName = &"legs"
const CATEGORY_PROPS: StringName = &"props"

var _active: bool = false
var _log_lines: Array[String] = []
var _enabled_categories: Dictionary = {}
var _watches: Dictionary = {}
var _commands: Dictionary = {}
var _console_open: bool = false
var _unlock_buffer: String = ""
var _last_unlock_input_ms: int = 0

func _ready() -> void:
	_active = OS.is_debug_build() or _has_debug_tools_argument()
	for category: StringName in [
		CATEGORY_NET,
		CATEGORY_COMBAT,
		CATEGORY_LIMP,
		CATEGORY_CARRY,
		CATEGORY_HANDS,
		CATEGORY_INTERACT,
		CATEGORY_LEGS,
		CATEGORY_PROPS,
	]:
		_enabled_categories[category] = true
	command(&"debug_categories", _command_list_categories,
		"List enabled debug categories.", false, false)
	command(&"debug_enable", _command_enable_category,
		"Enable a category: debug_enable <category>.", false, false)
	command(&"debug_disable", _command_disable_category,
		"Disable a category: debug_disable <category>.", false, false)
	command(&"debug_watches", _command_list_watches,
		"List registered watches and current values.", false, false)

func _input(event: InputEvent) -> void:
	if not _active or not event is InputEventKey:
		return
	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return
	if _console_open:
		if key_event.is_action_pressed("ui_cancel"):
			close_console()
		return
	var character: String = String.chr(key_event.unicode).to_lower()
	if character.is_empty():
		return
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - _last_unlock_input_ms > int(TUNING.DEBUG_UNLOCK_BUFFER_TIMEOUT_S * 1000.0):
		_unlock_buffer = ""
	_unlock_buffer += character
	_last_unlock_input_ms = now_ms
	if not TUNING.DEBUG_CONSOLE_WORD.begins_with(_unlock_buffer):
		_unlock_buffer = ""
		return
	get_viewport().set_input_as_handled()
	if _unlock_buffer == TUNING.DEBUG_CONSOLE_WORD:
		_unlock_buffer = ""
		toggle_console()

func is_console_open() -> bool:
	return _console_open

func toggle_console() -> void:
	if _console_open:
		close_console()
	else:
		open_console()

func open_console() -> void:
	if _console_open:
		return
	_console_open = true
	console_opened.emit()

func close_console() -> void:
	if not _console_open:
		return
	_console_open = false
	console_closed.emit()

func log(category: StringName, message: String) -> void:
	_write_line(category, message, false)

func warn(category: StringName, message: String) -> void:
	_write_line(category, message, true)

func is_on(category: StringName) -> bool:
	return _active and bool(_enabled_categories.get(category, false))

func watch(watch_name: StringName, getter: Callable) -> void:
	if not _active:
		return
	_watches[watch_name] = getter
	registry_changed.emit()

func unwatch(watch_name: StringName) -> void:
	_watches.erase(watch_name)
	registry_changed.emit()

func get_watch(watch_name: StringName) -> Variant:
	if not _watches.has(watch_name):
		return null
	var getter: Callable = _watches[watch_name]
	return getter.call()

func command(
	command_name: StringName,
	callable: Callable,
	help: String,
	host_only: bool = false,
	cheat: bool = false
) -> void:
	if not _active:
		return
	_commands[command_name] = {
		"callable": callable,
		"help": help,
		"host_only": host_only,
		"cheat": cheat,
	}
	registry_changed.emit()

func execute_command(command_name: StringName, args: Array[Variant]) -> Variant:
	if not _active or not _commands.has(command_name):
		return null
	var command_data: Dictionary = _commands[command_name]
	var host_only: bool = command_data["host_only"]
	if host_only and multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		warn(CATEGORY_NET, "Rejected debug command %s: host only" % command_name)
		return null
	var callable: Callable = command_data["callable"]
	return callable.call(args)

func get_log_lines() -> Array[String]:
	return _log_lines.duplicate()

func get_watch_names() -> Array[StringName]:
	var names: Array[StringName] = []
	for watch_name: StringName in _watches.keys():
		names.append(watch_name)
	return names

func get_command_names() -> Array[StringName]:
	var names: Array[StringName] = []
	for command_name: StringName in _commands.keys():
		names.append(command_name)
	return names

func _write_line(category: StringName, message: String, warning: bool) -> void:
	if not is_on(category):
		return
	var timestamp_ms: int = Time.get_ticks_msec()
	var peer_id: int = multiplayer.get_unique_id()
	var prefix: String = "WARN " if warning else ""
	var line: String = "%d peer=%d %s[%s] %s" % [
		timestamp_ms,
		peer_id,
		prefix,
		category,
		message,
	]
	_log_lines.append(line)
	if _log_lines.size() > TUNING.DEBUG_LOG_CAPACITY:
		_log_lines.pop_front()
	print("[DebugHub] %s" % line)
	log_added.emit(line)

func _has_debug_tools_argument() -> bool:
	for argument: String in OS.get_cmdline_args():
		if argument == "--debug-tools":
			return true
	return false

func _command_list_categories(_args: Array[Variant]) -> String:
	var result: String = ""
	for category: StringName in _enabled_categories.keys():
		result += "%s=%s\n" % [category, str(is_on(category))]
	return result.strip_edges()

func _command_enable_category(args: Array[Variant]) -> String:
	if args.is_empty():
		return "Usage: debug_enable <category>"
	var category: StringName = StringName(str(args[0]))
	_enabled_categories[category] = true
	return "Enabled category: %s" % category

func _command_disable_category(args: Array[Variant]) -> String:
	if args.is_empty():
		return "Usage: debug_disable <category>"
	var category: StringName = StringName(str(args[0]))
	_enabled_categories[category] = false
	return "Disabled category: %s" % category

func _command_list_watches(_args: Array[Variant]) -> String:
	var result: String = ""
	for watch_name: StringName in _watches.keys():
		result += "%s=%s\n" % [watch_name, str(get_watch(watch_name))]
	return result.strip_edges()
