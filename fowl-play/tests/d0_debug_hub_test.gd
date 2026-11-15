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
	_finish()

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
