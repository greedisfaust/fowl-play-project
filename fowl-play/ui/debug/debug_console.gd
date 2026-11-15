## Editor-built local debug console controller.
## Expects the node tree described in the D0 editor task.

extends Control

@onready var window: Control = $Window
@onready var logs_view: RichTextLabel = $Window/Layout/Tabs/Logs
@onready var watches_view: RichTextLabel = $Window/Layout/Tabs/Watches
@onready var commands_view: VBoxContainer = $Window/Layout/Tabs/Commands
@onready var command_input: LineEdit = $Window/Layout/CommandRow/CommandInput
@onready var run_button: Button = $Window/Layout/CommandRow/RunButton
@onready var command_result: Label = $Window/Layout/CommandResult
@onready var debug_hub: Node = get_node("/root/DebugHub")

func _ready() -> void:
	window.visible = false
	debug_hub.connect("console_opened", _on_console_opened)
	debug_hub.connect("console_closed", _on_console_closed)
	debug_hub.connect("log_added", _on_log_added)
	debug_hub.connect("registry_changed", _refresh_registry_views)
	command_input.text_submitted.connect(_submit_command)
	run_button.pressed.connect(_run_entered_command)
	_refresh_registry_views()

func _process(_delta: float) -> void:
	if bool(debug_hub.call("is_console_open")):
		_refresh_watches()

func _on_console_opened() -> void:
	window.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_refresh_log_view()
	_refresh_registry_views()

func _on_console_closed() -> void:
	window.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_log_added(_line: String) -> void:
	if window.visible:
		_refresh_log_view()

func _refresh_log_view() -> void:
	var lines: Array[String] = debug_hub.call("get_log_lines")
	logs_view.text = "\n".join(lines)
	logs_view.scroll_to_line(maxi(0, lines.size() - 1))

func _refresh_watches() -> void:
	var lines: Array[String] = []
	var watch_names: Array[StringName] = debug_hub.call("get_watch_names")
	for watch_name: StringName in watch_names:
		lines.append("%s = %s" % [watch_name, str(debug_hub.call("get_watch", watch_name))])
	watches_view.text = "\n".join(lines)

func _refresh_registry_views() -> void:
	_refresh_watches()
	for child: Node in commands_view.get_children():
		child.queue_free()
	var command_names: Array[StringName] = debug_hub.call("get_command_names")
	for command_name: StringName in command_names:
		var button: Button = Button.new()
		button.text = str(command_name)
		button.pressed.connect(_execute_command.bind(command_name))
		commands_view.add_child(button)

func _execute_command(command_name: StringName) -> void:
	command_input.text = str(command_name)
	_submit_command(command_input.text)
	command_input.grab_focus()
	command_input.caret_column = command_input.text.length()

func _run_entered_command() -> void:
	_submit_command(command_input.text)

func _submit_command(text: String) -> void:
	# Current commands use whitespace-separated arguments, without quoting.
	var tokens: PackedStringArray = text.strip_edges().replace("\t", " ").split(" ", false)
	if tokens.is_empty():
		command_result.text = "Enter a command, then press Enter or Run."
		return
	var command_name: StringName = StringName(tokens[0])
	var command_names: Array[StringName] = debug_hub.call("get_command_names")
	if not command_names.has(command_name):
		command_result.text = "Unknown command: %s. See the Commands tab." % command_name
		return
	var args: Array[Variant] = []
	for index: int in range(1, tokens.size()):
		args.append(tokens[index])
	var result: Variant = debug_hub.call("execute_command", command_name, args)
	# Feedback must remain visible even when the command disables net logging.
	command_result.text = "%s: %s" % [
		command_name,
		str(result) if result != null else "No result returned; check logs for any rejection.",
	]
	debug_hub.call("log", &"net", command_result.text)
