## Casino keypad button presentation.
## Attach to the TerminalButton root and assign ButtonKey + Interactable.
extends Node3D

@export var button_key: Node3D
@export var interactable: Interactable
@export_range(0.001, 0.03, 0.001, "suffix:m") var press_depth: float = 0.008
@export_range(0.02, 0.2, 0.01, "suffix:s") var press_duration: float = 0.07
@export_range(0.05, 0.4, 0.01, "suffix:s") var return_duration: float = 0.18

var press_count: int = 0
var _rest_position: Vector3 = Vector3.ZERO
var _press_tween: Tween = null
var _click_player: AudioStreamPlayer3D = null

func _ready() -> void:
	if not is_instance_valid(button_key):
		push_warning("TerminalButton requires its ButtonKey reference.")
		set_process(false)
		return
	if not is_instance_valid(interactable):
		push_warning("TerminalButton requires its Interactable reference.")
		set_process(false)
		return
	_rest_position = button_key.position
	_setup_click_audio()
	interactable.interacted.connect(_on_interacted)

func _exit_tree() -> void:
	if _press_tween != null and _press_tween.is_running():
		_press_tween.kill()

func _on_interacted(_actor: Node, action: StringName) -> void:
	if action != &"use":
		return
	var network: Node = get_node_or_null("/root/Network")
	if not is_instance_valid(network):
		return
	var network_peer: MultiplayerPeer = network.get("peer") as MultiplayerPeer
	# Interactable emits on the authority. Offline mode has no ENet peer but
	# still owns the local interaction.
	if network_peer != null and not bool(network.get("is_host")):
		return
	_play_press_local()
	if network_peer != null:
		_receive_press_presentation.rpc()

@rpc("authority", "call_remote", "reliable", 0)
func _receive_press_presentation() -> void:
	var network: Node = get_node_or_null("/root/Network")
	if not is_instance_valid(network) or not bool(network.call("validate_rpc", 1)):
		return
	_play_press_local()

func _play_press_local() -> void:
	if not is_instance_valid(button_key):
		return
	press_count += 1
	if is_instance_valid(_click_player):
		_click_player.play()
	if _press_tween != null and _press_tween.is_running():
		_press_tween.kill()
	var pressed_position: Vector3 = _rest_position + Vector3.DOWN * press_depth
	_press_tween = create_tween()
	_press_tween.set_trans(Tween.TRANS_CUBIC)
	_press_tween.set_ease(Tween.EASE_OUT)
	_press_tween.tween_property(button_key, "position", pressed_position, press_duration)
	_press_tween.set_trans(Tween.TRANS_SPRING)
	_press_tween.set_ease(Tween.EASE_OUT)
	_press_tween.tween_property(button_key, "position", _rest_position, return_duration)

func _setup_click_audio() -> void:
	var audio_parent: Node = get_node_or_null("Audio")
	if audio_parent == null:
		audio_parent = self
	_click_player = AudioStreamPlayer3D.new()
	_click_player.name = "GeneratedClickPlayer"
	_click_player.stream = _make_click_sound()
	_click_player.volume_db = -7.0
	_click_player.unit_size = 1.0
	_click_player.max_distance = 7.0
	audio_parent.add_child(_click_player)

func _make_click_sound() -> AudioStreamWAV:
	const SAMPLE_RATE: int = 22050
	const DURATION_SECONDS: float = 0.055
	var sample_count: int = int(float(SAMPLE_RATE) * DURATION_SECONDS)
	var samples: PackedByteArray = PackedByteArray()
	samples.resize(sample_count * 2)
	for sample_index: int in range(sample_count):
		var time: float = float(sample_index) / float(SAMPLE_RATE)
		var envelope: float = exp(-time * 95.0)
		var noise: float = randf_range(-1.0, 1.0)
		var high_click: float = sin(TAU * 1850.0 * time) * 0.32
		var low_thock: float = sin(TAU * 240.0 * time) * 0.22
		var sample_value: float = clampf((noise * 0.28 + high_click + low_thock) * envelope, -1.0, 1.0)
		samples.encode_s16(sample_index * 2, int(sample_value * 32767.0))
	var click_stream: AudioStreamWAV = AudioStreamWAV.new()
	click_stream.format = AudioStreamWAV.FORMAT_16_BITS
	click_stream.mix_rate = SAMPLE_RATE
	click_stream.stereo = false
	click_stream.data = samples
	return click_stream
