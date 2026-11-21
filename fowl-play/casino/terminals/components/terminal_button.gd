@tool
## Casino keypad button presentation.
## Attach to the TerminalButton root and assign ButtonKey + Interactable.
extends Node3D

## Emitted by the authority when this physical key is pressed.
signal button_pressed(button_id: StringName)
## Host-side action signal with the authoritative actor peer ID.
signal button_activated(button_id: StringName, peer_id: int)

## Unique action identifier consumed by the parent keypad/terminal.
@export var button_id: StringName = &"1"

## Text shown on the physical key. Each instance gets its own TextMesh copy.
@export var display_text: String = "":
	set(value):
		display_text = value
		if is_inside_tree():
			_apply_display_text()
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
	# Visual presentation must not depend on interaction setup.
	_apply_display_text()
	if Engine.is_editor_hint():
		return
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

func _apply_display_text() -> void:
	var label: MeshInstance3D = null
	if is_instance_valid(button_key):
		label = button_key.get_node_or_null("ButtonLabel") as MeshInstance3D
	if not is_instance_valid(label):
		push_warning("TerminalButton could not find ButtonLabel under ButtonKey.")
		return
	var source_text_mesh: TextMesh = label.mesh as TextMesh
	if source_text_mesh == null:
		push_warning("TerminalButton ButtonLabel must use a TextMesh.")
		return
	var unique_text_mesh: TextMesh = source_text_mesh.duplicate() as TextMesh
	unique_text_mesh.text = display_text
	label.mesh = unique_text_mesh

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
	var actor_peer_id: int = int(_actor.get("input_peer_id")) if _actor_has_peer_id(_actor) else 0
	if actor_peer_id <= 0:
		actor_peer_id = multiplayer.get_unique_id()
	button_pressed.emit(button_id)
	button_activated.emit(button_id, actor_peer_id)
	_play_press_local()
	if network_peer != null:
		_receive_press_presentation.rpc()

@rpc("authority", "call_remote", "reliable", 0)
func _receive_press_presentation() -> void:
	var network: Node = get_node_or_null("/root/Network")
	if not is_instance_valid(network) or not bool(network.call("validate_rpc", 1)):
		return
	_play_press_local()

func _actor_has_peer_id(actor: Node) -> bool:
	if not is_instance_valid(actor):
		return false
	for property: Dictionary in actor.get_property_list():
		if str(property.get("name", "")) == "input_peer_id":
			return true
	return false

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
