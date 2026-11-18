## Headless D0 verification for DebugHub registration and bounded logging.

extends SceneTree

var _failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var hub: Node = root.get_node_or_null("DebugHub")
	if hub == null:
		_fail("DebugHub autoload is missing")
		_finish()
		return

	hub.watch(&"d0_test_value", func() -> int: return 7)
	hub.command(&"d0_test_command", _test_command, "D0 test command.", false, false)
	if not hub.get_watch_names().has(&"d0_test_value"):
		_fail("D0 watch was not registered")
	if not hub.get_command_names().has(&"d0_test_command"):
		_fail("D0 command was not registered")
	var value: Variant = hub.get_watch(&"d0_test_value")
	if value != 7:
		_fail("D0 watch returned %s instead of 7" % value)
	var command_result: Variant = hub.execute_command(&"d0_test_command", [])
	if command_result != "d0-ok":
		_fail("D0 command returned %s" % command_result)
	hub.log(&"net", "D0 verification log")
	if hub.get_log_lines().is_empty():
		_fail("D0 log buffer did not record an enabled log")
	hub.unwatch(&"d0_test_value")
	if hub.get_watch_names().has(&"d0_test_value"):
		_fail("D0 watch was not removed")
	_check_console_commands(hub)
	await _check_player_cleanup(hub)
	_finish()

func _check_player_cleanup(hub: Node) -> void:
	var player_scene: PackedScene = load("res://player/player.tscn")
	var console_scene: PackedScene = load("res://ui/debug/debug_console.tscn")
	var console: Control = console_scene.instantiate()
	root.add_child(console)
	var departing: CharacterBody3D = player_scene.instantiate()
	departing.name = "CleanupDeparting"
	root.add_child(departing)
	var remaining: CharacterBody3D = player_scene.instantiate()
	remaining.name = "CleanupRemaining"
	root.add_child(remaining)
	if not hub.get_command_names().has(&"player_status_CleanupDeparting"):
		_fail("Player status command was not registered")
	if hub.get_watch(&"player/CleanupDeparting/speed_mps") != 0.0:
		_fail("Player speed watch was not registered correctly")
	if hub.get_watch(&"player/CleanupDeparting/on_floor") == null:
		_fail("Player floor watch was not registered")
	departing.name = "RenamedBeforeRemoval"
	departing.queue_free()
	await process_frame
	if hub.get_command_names().has(&"player_status_CleanupDeparting"):
		_fail("Deleted player's command remains registered")
	for watch_name: StringName in [&"player/CleanupDeparting/speed_mps", &"player/CleanupDeparting/on_floor"]:
		if hub.get_watch_names().has(watch_name) or hub.get_watch(watch_name) != null:
			_fail("Deleted player's watch remains: %s" % watch_name)
	if hub.execute_command(&"player_status_CleanupDeparting", []) != null:
		_fail("Deleted player's command should not execute")
	if hub.get_watch(&"player/CleanupRemaining/speed_mps") == null:
		_fail("Other player's watch was removed")
	var status: Variant = hub.execute_command(&"player_status_CleanupRemaining", [])
	if not status is String or not str(status).contains("position="):
		_fail("Other player's command stopped working")
	var replacement: CharacterBody3D = player_scene.instantiate()
	replacement.name = "CleanupDeparting"
	root.add_child(replacement)
	if hub.get_watch(&"player/CleanupDeparting/speed_mps") != 0.0:
		_fail("Replacement player's watch did not register")
	if hub.execute_command(&"player_status_CleanupDeparting", []) == null:
		_fail("Replacement player's command did not register")
	replacement.free()
	remaining.free()
	console.free()

func _check_console_commands(hub: Node) -> void:
	var console_scene: PackedScene = load("res://ui/debug/debug_console.tscn")
	var console: Control = console_scene.instantiate()
	root.add_child(console)
	var input: LineEdit = console.get_node("Window/Layout/CommandRow/CommandInput")
	var run_button: Button = console.get_node("Window/Layout/CommandRow/RunButton")
	var result: Label = console.get_node("Window/Layout/CommandResult")
	input.text_submitted.emit("  debug_disable   net  ")
	if hub.is_on(&"net") or not result.text.contains("Disabled category: net"):
		_fail("Enter did not disable net and display feedback with logging off")
	input.text = "debug_enable\tnet"
	run_button.pressed.emit()
	if not hub.is_on(&"net") or not result.text.contains("Enabled category: net"):
		_fail("Run did not enable net with a tab-separated argument")
	input.text_submitted.emit("debug_disable")
	if not result.text.contains("Usage:") or not hub.is_on(&"net"):
		_fail("Missing arguments should display usage without changing net")
	input.text_submitted.emit("does_not_exist")
	if not result.text.contains("Unknown command:"):
		_fail("Unknown command feedback is missing")
	input.text_submitted.emit("   ")
	if not result.text.begins_with("Enter a command"):
		_fail("Empty command should display a prompt")
	console.free()

func _test_command(_args: Array[Variant]) -> String:
	return "d0-ok"

func _fail(message: String) -> void:
	_failed = true
	push_error(message)

func _finish() -> void:
	if _failed:
		quit(1)
		return
	print("D0 debug hub checks passed")
	quit(0)
