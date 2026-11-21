## Separate-process M0 tests using the editor-authored arena and player scenes.
## Tests the saved scene directly, including its script attachment.
extends SceneTree

var _role: String = "offline"
var _case: String = "client-leaves"
var _arena: Node3D
var _network: Node
var _hub: Node
var _saw_pair: bool = false
var _departed_id: int = 0
var _pair_time: int = 0
var _ended: bool = false
var _console_started: bool = false
var _remote_start: Vector3
var _saw_remote_movement: bool = false
var _bad_move_sent: bool = false
var _interaction_started: bool = false

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--test-role="):
			_role = argument.trim_prefix("--test-role=")
		elif argument.begins_with("--test-case="):
			_case = argument.trim_prefix("--test-case=")
	_setup.call_deferred()

func _setup() -> void:
	_network = root.get_node("Network")
	_hub = root.get_node("DebugHub")
	var arena_scene: PackedScene = load("res://arena/test_arena.tscn")
	_arena = arena_scene.instantiate()
	if _case == "interaction":
		_arena.get_node("SpawnPoints/Spawn2").position = Vector3(-3, 0.6, -4)
	if _arena.has_node("PlayerPreview") or _arena.get_script() != load("res://arena/test_arena.gd"):
		_arena.free()
		_arena = null
		_finish(false, "Arena needs its spawning script and no PlayerPreview")
		return
	root.add_child(_arena)
	create_timer(15.0).timeout.connect(func() -> void: _finish(false, "Timed out"))

func _process(_delta: float) -> bool:
	if _arena == null or _ended:
		return false
	var players: Node = _arena.get_node("Players")
	var count: int = players.get_child_count()
	if _case.begins_with("console-") and not _console_started and count == 1:
		_console_started = true
		var input: LineEdit = _arena.get_node("DebugConsole/Window/Layout/CommandRow/CommandInput")
		var result: Label = _arena.get_node("DebugConsole/Window/Layout/CommandResult")
		input.text_submitted.emit("net_join invalid-ip")
		if not result.text.contains("Invalid IP") or _network.get("status") != "offline":
			_finish(false, "Invalid address should not end offline play")
		if _role == "host":
			input.text_submitted.emit("net_host")
		else:
			input.text_submitted.emit("net_join" if _case.ends_with("client-leaves") else "net_join 127.0.0.1")
		return false
	if _role == "offline":
		if count == 1:
			_check_local_selection(players)
			_finish(true, "offline spawn")
		return false
	if count == 2 and not _saw_pair:
		_check_local_selection(players)
		_saw_pair = true
		_pair_time = Time.get_ticks_msec()
		if _case.begins_with("movement"):
			for player: Node3D in players.get_children():
				if not bool(player.get("is_local_player")):
					_remote_start = player.global_position
			Input.action_press("move_right")
		for player: Node in players.get_children():
			if int(str(player.name)) != 1:
				_departed_id = int(str(player.name))
		print("M0 PAIR READY %s" % _role)
	if not _saw_pair:
		return false
	if _case == "interaction":
		if not _interaction_started:
			_interaction_started = true
			_check_interaction.call_deferred()
		return false
	if _case.begins_with("movement"):
		for player: Node3D in players.get_children():
			if not bool(player.get("is_local_player")) and player.global_position.distance_to(_remote_start) > 1.0:
				_saw_remote_movement = true
		var elapsed: int = Time.get_ticks_msec() - _pair_time
		if _case == "movement-reject" and _role == "client" and elapsed > 500 and not _bad_move_sent:
			_bad_move_sent = true
			_network.rpc_id(1, "_submit_movement", 99999, Vector3(1000, 0, 0), Vector3.ZERO, 0.0, 0.0)
		if elapsed > 800:
			Input.action_release("move_right")
		if elapsed > (2500 if _role == "host" else 2000):
			var rejections: int = int(_network.get("movement_rejected"))
			var rejection_ok: bool = rejections > 0 if _case == "movement-reject" and _role == "host" else rejections == 0
			for player: Node3D in players.get_children():
				if absf(player.global_position.x) > 50.0:
					rejection_ok = false
			_finish(_saw_remote_movement and rejection_ok, "bidirectional movement replication / rejection")
		return false
	if _case.ends_with("client-leaves"):
		if _role == "client" and Time.get_ticks_msec() - _pair_time > 1000:
			_hub.call("execute_command", &"net_disconnect", [])
			_finish(true, "client departure")
		elif _role == "host" and count == 1:
			_check_removed_debug(_departed_id)
			_finish(true, "host observed client despawn")
	else:
		if _role == "host" and Time.get_ticks_msec() - _pair_time > 1000:
			_hub.call("execute_command", &"net_disconnect", [])
			_finish(true, "host departure")
		elif _role == "client" and _network.get("status") == "disconnected" and count == 0:
			_check_removed_debug(1)
			_check_removed_debug(_departed_id)
			_finish(true, "client cleared players after host departure")
	return false

func _check_local_selection(players: Node) -> void:
	var local_count: int = 0
	for player: Node in players.get_children():
		var expected_local: bool = int(str(player.name)) == players.multiplayer.get_unique_id()
		var camera: Camera3D = player.get_node("Head/Camera3D")
		if bool(player.get("is_local_player")) != expected_local or player.is_physics_processing() != expected_local:
			_finish(false, "Wrong input/physics selection")
		if expected_local:
			local_count += 1
			if not camera.is_current():
				_finish(false, "Local camera is not current")
		elif camera.is_current():
			_finish(false, "Remote camera took control")
	if local_count != 1:
		_finish(false, "Expected exactly one local player")

func _check_interaction() -> void:
	var device: Node = _arena.get_node("TestUseDevice")
	var target: NodePath = device.get_node("Interactable").get_path()
	await create_timer(0.4).timeout
	if _role == "client":
		_network.call("request_interaction", target, &"use")
		_network.call("request_interaction", target, &"use") # Duplicate inside cooldown.
		await create_timer(0.3).timeout
		_network.call("request_interaction", target, &"grab") # USE-only target.
		await create_timer(0.3).timeout
		_network.call("request_interaction", NodePath("/root/MissingTarget"), &"use")
		await create_timer(0.3).timeout
		_network.call("request_interaction", _arena.get_node("TestGrabProp/Interactable").get_path(), &"grab") # Out of reach.
		await create_timer(0.5).timeout
		_finish(bool(device.get("is_active")), "client received authoritative device state")
	else:
		await create_timer(2.0).timeout
		_finish(bool(device.get("is_active")) and int(_network.get("interaction_accepted")) == 1 and int(_network.get("interaction_rejected")) == 4, "host validated client interaction, kind, cooldown, target and reach")

func _check_removed_debug(peer_id: int) -> void:
	if _hub.call("get_command_names").has(StringName("player_status_%d" % peer_id)):
		_finish(false, "Departed player's command remains")
	for suffix: String in ["speed_mps", "on_floor"]:
		if _hub.call("get_watch_names").has(StringName("player/%d/%s" % [peer_id, suffix])):
			_finish(false, "Departed player's watch remains")

func _finish(passed: bool, message: String) -> void:
	if _ended:
		return
	_ended = true
	if passed:
		print("M0 PASS %s: %s" % [_role, message])
	else:
		push_error("M0 FAIL %s: %s" % [_role, message])
	quit(0 if passed else 1)
