## Run as two processes to verify reliable limp state and moving client poses.
extends SceneTree

var _role: String = "host"
var _target: String = "host"
var _late_join: bool = false
var _join_after_settled: bool = false
var _test_rate_hz: int = 30
var _auto_recovery: bool = false
var _host_wire_bps: float = 0.0
var _arena: Node3D
var _network: Node
var _started_at_ms: int = 0
var _pair_at_ms: int = 0
var _first_client_hips_y: float = NAN
var _saw_client_pose_move: bool = false
var _client_max_sequence: int = -1
var _client_lowest_hips_y: float = INF
var _stopped: bool = false
var _finished: bool = false
var _checked_client_authority: bool = false
var _client_camera_start_y: float = NAN
var _saw_client_camera_follow: bool = false
var _max_client_hips_error_m: float = 0.0

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--test-role="):
			_role = argument.trim_prefix("--test-role=")
		elif argument.begins_with("--test-target="):
			_target = argument.trim_prefix("--test-target=")
		elif argument == "--test-late":
			_late_join = true
		elif argument == "--test-join-after-settled":
			_join_after_settled = true
		elif argument.begins_with("--test-rate="):
			_test_rate_hz = int(argument.trim_prefix("--test-rate="))
		elif argument == "--test-auto-recovery":
			_auto_recovery = true
	_setup.call_deferred()

func _setup() -> void:
	_network = root.get_node("Network")
	_network.set("ragdoll_send_hz", _test_rate_hz)
	_arena = load("res://arena/test_arena.tscn").instantiate()
	root.add_child(_arena)
	create_timer(15.0).timeout.connect(func() -> void: _finish(false, "timed out"))

func _process(_delta: float) -> bool:
	if _finished or _arena == null:
		return false
	if _role == "host" and _stopped and Time.get_ticks_msec() - _started_at_ms > (4850 if _join_after_settled else 3350 if _late_join else 1850) and (not _auto_recovery or not bool((_arena.get_node("Players/1") as Node).get("is_limp"))):
		_finish(true, "host completed start/stop")
		return false
	var players: Node3D = _arena.get_node("Players") as Node3D
	if players.get_child_count() < (1 if _late_join and _role == "host" else 2):
		return false
	if _pair_at_ms == 0:
		_pair_at_ms = Time.get_ticks_msec()
	var target_id: int = 1 if _target == "host" else _network.multiplayer.get_unique_id()
	if _target == "client" and _role == "host":
		for child: Node in players.get_children():
			if child.name != "1":
				target_id = int(child.name)
	var host_player: CharacterBody3D = players.get_node(str(target_id)) as CharacterBody3D
	if _role == "client" and _target == "client" and is_nan(_client_camera_start_y):
		_client_camera_start_y = (host_player.get_node("Head/Camera3D") as Camera3D).global_position.y
	if _role == "host":
		if _started_at_ms == 0 and Time.get_ticks_msec() - _pair_at_ms > 250:
			# M4's manual-stop measurements keep recovery disabled.
			host_player.set("auto_recovery_enabled", _auto_recovery)
			# Give the physics body room to fall, without moving the Player root.
			var rig: Node3D = host_player.get_node("Rig") as Node3D
			rig.position.y += 1.0
			var connection: ENetConnection = (_network.get("peer") as ENetMultiplayerPeer).host
			connection.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA)
			if not bool(_network.call("start_ragdoll_spike", target_id)):
				_finish(false, "host start rejected")
				return false
			_started_at_ms = Time.get_ticks_msec()
		if _auto_recovery and _started_at_ms > 0 and not bool(host_player.get("is_limp")):
			_stopped = true
		if _late_join and _started_at_ms > 0 and Time.get_ticks_msec() - _started_at_ms > 1700:
			# Drive a deterministic settled state to verify the reliable final-pose
			# path; natural settling is measured separately by the profile.
			var host_rig: Node3D = host_player.get_node("Rig") as Node3D
			var bones: Array = host_rig.get("physical_bones")
			for bone: PhysicalBone3D in bones:
				bone.linear_velocity = Vector3.ZERO
				bone.angular_velocity = Vector3.ZERO
		if not _auto_recovery and _started_at_ms > 0 and not _stopped and Time.get_ticks_msec() - _started_at_ms > (4500 if _join_after_settled else 3000 if _late_join else 1500):
			_stopped = true
			var connection: ENetConnection = (_network.get("peer") as ENetMultiplayerPeer).host
			_host_wire_bps = connection.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA) / ((Time.get_ticks_msec() - _started_at_ms) / 1000.0)
			if not bool(_network.call("stop_ragdoll_spike", target_id)):
				_finish(false, "host stop rejected")
				return false
	else:
		if not _checked_client_authority:
			_checked_client_authority = true
			if bool(_network.call("start_ragdoll_spike", target_id)):
				_finish(false, "client was allowed to start authoritative simulation")
				return false
		var rig: Node3D = host_player.get_node("Rig") as Node3D
		if bool(host_player.get("is_limp")):
			if _target == "client":
				var owner_camera: Camera3D = host_player.get_node("Head/Camera3D") as Camera3D
				if owner_camera.top_level and owner_camera.global_position.y < _client_camera_start_y - 0.05:
					_saw_client_camera_follow = true
			var client_simulator: PhysicalBoneSimulator3D = rig.get_node("Skeleton3D/PhysicalBoneSimulator3D") as PhysicalBoneSimulator3D
			if client_simulator.is_simulating_physics() or client_simulator.active:
				_finish(false, "client simulator ran during remote limp")
				return false
			_client_max_sequence = maxi(_client_max_sequence, int(rig.get("_last_remote_sequence")))
			var hips_pose: Transform3D = (rig.get_node("Skeleton3D") as Skeleton3D).get_bone_global_pose(0)
			var samples: Array = rig.get("_remote_samples")
			if not samples.is_empty() and int(rig.get("_last_remote_sequence")) >= 3:
				var latest: Dictionary = samples.back()
				var data: PackedInt32Array = latest.data
				var received_hips: Vector3 = Vector3(data[0], data[1], data[2]) / 1000.0
				_max_client_hips_error_m = maxf(_max_client_hips_error_m, hips_pose.origin.distance_to(received_hips))
			_client_lowest_hips_y = minf(_client_lowest_hips_y, hips_pose.origin.y)
			if is_nan(_first_client_hips_y):
				_first_client_hips_y = hips_pose.origin.y
			elif hips_pose.origin.y < _first_client_hips_y - 0.05 and int(rig.get("_last_remote_sequence")) >= 3:
				_saw_client_pose_move = true
			if _join_after_settled and int(_network.get("ragdoll_settled_received")) >= 1:
				_finish(true, "late client received already-settled pose")
		elif not is_nan(_first_client_hips_y) and _saw_client_pose_move:
			if _max_client_hips_error_m > 0.251:
				_finish(false, "client hips exceeded 0.25 m from latest host pose")
			elif _late_join and int(_network.get("ragdoll_settled_received")) < 1:
				_finish(false, "late client did not receive reliable settled pose")
			elif _target == "client" and not _saw_client_camera_follow:
				_finish(false, "client owner camera did not follow the ragdoll")
			else:
				_finish(true, "client saw moving poses, camera follow, and reliable end")
	return false

func _finish(passed: bool, detail: String) -> void:
	if _finished:
		return
	_finished = true
	if passed:
		print("M4 PASS %s target=%s hz=%d: %s max_latest_hips_error_m=%.3f host_wire_Bps=%.1f" % [_role, _target, _test_rate_hz, detail, _max_client_hips_error_m, _host_wire_bps])
	else:
		push_error("M4 FAIL %s: %s (max sequence=%d first hips Y=%f lowest hips Y=%f)" % [_role, detail, _client_max_sequence, _first_client_hips_y, _client_lowest_hips_y])
	quit(0 if passed else 1)
