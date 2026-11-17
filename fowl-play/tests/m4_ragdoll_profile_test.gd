## Four-ragdoll host profile. Data-byte counts exclude RPC/ENet framing.
extends SceneTree

var _rate_hz: int = 30
var _ragdoll_count: int = 4
var _duration_s: float = 2.0
var _network: Node
var _arena: Node3D
var _start_ms: int = 0
var _physics_sum_s: float = 0.0
var _physics_max_s: float = 0.0
var _physics_samples: int = 0
var _finished: bool = false

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--profile-hz="):
			_rate_hz = int(argument.trim_prefix("--profile-hz="))
		elif argument.begins_with("--ragdolls="):
			_ragdoll_count = int(argument.trim_prefix("--ragdolls="))
		elif argument.begins_with("--seconds="):
			_duration_s = float(argument.trim_prefix("--seconds="))
	_setup.call_deferred()

func _setup() -> void:
	_network = root.get_node("Network")
	_arena = load("res://arena/test_arena.tscn").instantiate()
	root.add_child(_arena)
	await process_frame
	if not bool(_network.get("is_host")):
		_fail("host was not started")
		return
	_network.set("ragdoll_send_hz", _rate_hz)
	var players: Node3D = _arena.get_node("Players") as Node3D
	var player_scene: PackedScene = load("res://player/player.tscn")
	for player_id: int in range(2, _ragdoll_count + 1):
		var player: CharacterBody3D = player_scene.instantiate()
		player.name = str(player_id)
		player.set("input_peer_id", player_id)
		player.position = Vector3((player_id - 1) * 3.0, 2.5, 0.0)
		players.add_child(player)
	for player_id: int in range(1, _ragdoll_count + 1):
		var player: CharacterBody3D = players.get_node(str(player_id)) as CharacterBody3D
		player.set("auto_recovery_enabled", false)
		var rig: Node3D = player.get_node("Rig") as Node3D
		rig.position.y += 1.0
		if not bool(_network.call("start_ragdoll_spike", player_id)):
			_fail("could not start ragdoll %d" % player_id)
			return
	_start_ms = Time.get_ticks_msec()

func _process(_delta: float) -> bool:
	if _finished or _start_ms == 0:
		return false
	var elapsed_s: float = (Time.get_ticks_msec() - _start_ms) / 1000.0
	if elapsed_s > 0.2:
		var physics_s: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		_physics_sum_s += physics_s
		_physics_max_s = maxf(_physics_max_s, physics_s)
		_physics_samples += 1
	if elapsed_s >= _duration_s:
		var pose_count: int = int(_network.get("ragdoll_pose_sent"))
		var data_bytes: int = int(_network.get("ragdoll_pose_data_bytes_sent"))
		if (_ragdoll_count > 0 and pose_count < _rate_hz / 2) or _physics_samples == 0:
			_fail("insufficient samples: %d" % pose_count)
			return false
		var max_linear_mps: float = 0.0
		var max_angular_rps: float = 0.0
		var fastest_angular_bone: String = "none"
		if _ragdoll_count > 0:
			for player_id: int in range(1, _ragdoll_count + 1):
				var player: CharacterBody3D = _arena.get_node("Players/%d" % player_id) as CharacterBody3D
				var player_rig: Node3D = player.get_node("Rig") as Node3D
				var player_bones: Array = player_rig.get("physical_bones")
				for bone: PhysicalBone3D in player_bones:
					if not bone.global_position.is_finite() or bone.global_position.distance_to(player.global_position) > 20.0:
						_fail("physical bone escaped ragdoll %d: %s" % [player_id, bone.bone_name])
						return false
			var first_rig: Node3D = _arena.get_node("Players/1/Rig") as Node3D
			var bones: Array = first_rig.get("physical_bones")
			for bone: PhysicalBone3D in bones:
				max_linear_mps = maxf(max_linear_mps, bone.linear_velocity.length())
				if bone.angular_velocity.length() > max_angular_rps:
					max_angular_rps = bone.angular_velocity.length()
					fastest_angular_bone = String(bone.bone_name)
		print("M4 PROFILE hz=%d ragdolls=%d poses=%d pose_data_Bps=%.1f avg_physics_ms=%.3f max_physics_ms=%.3f settled=%d max_linear_mps=%.2f max_angular_rps=%.2f fastest_bone=%s" % [
			_rate_hz, _ragdoll_count, pose_count, data_bytes / elapsed_s,
			_physics_sum_s / _physics_samples * 1000.0, _physics_max_s * 1000.0,
			int(_network.get("ragdoll_settled_sent")), max_linear_mps, max_angular_rps, fastest_angular_bone,
		])
		_finished = true
		quit(0)
	return false

func _fail(message: String) -> void:
	_finished = true
	push_error("M4 PROFILE FAIL: %s" % message)
	quit(1)
