## Host-authoritative run and day progression state.
## This autoload survives world swaps; it does not own world loading or wallet mutations.
extends Node

enum Phase {
	IDLE,
	APARTMENT,
	CASINO,
	REST_AREA,
	CONTRACT_FULFILLED,
	CONTRACT_EXTENDED,
	RUN_FAILED,
}

const MAX_DAYS: int = 10
const INITIAL_RUN_WALLET: int = 1000
const WORLD_APARTMENT: int = 0
const WORLD_CASINO: int = 1
const WORLD_REST_AREA: int = 2

signal run_state_changed(snapshot: Dictionary)

var run_active: bool = false
var current_day: int = 0
var phase: int = Phase.IDLE
var casino_departure_allowed: bool = false

var _debug_hub: Node


func _ready() -> void:
	_debug_hub = get_node_or_null("/root/DebugHub")
	if not is_instance_valid(_debug_hub):
		return
	_debug_hub.call("watch", &"run/active", func() -> bool: return run_active)
	_debug_hub.call("watch", &"run/day", func() -> int: return current_day)
	_debug_hub.call("watch", &"run/phase", func() -> String: return _phase_name(phase))
	_debug_hub.call("watch", &"run/casino_departure_allowed", func() -> bool: return casino_departure_allowed)


func _exit_tree() -> void:
	if not is_instance_valid(_debug_hub):
		return
	_debug_hub.call("unwatch", &"run/active")
	_debug_hub.call("unwatch", &"run/day")
	_debug_hub.call("unwatch", &"run/phase")
	_debug_hub.call("unwatch", &"run/casino_departure_allowed")


## MainController is persistent; bind its world signal once so progression commits survive elevator scene swaps.
func bind_main_controller(controller: Node) -> void:
	if controller == null or not controller.has_signal("world_changed"):
		return
	var callback: Callable = Callable(self, "_on_main_world_changed")
	if not controller.is_connected("world_changed", callback):
		controller.connect("world_changed", callback)


func _on_main_world_changed(previous_world: int, current_world: int) -> void:
	if previous_world < 0 or not _is_authority():
		return
	complete_world_transition(previous_world, current_world)


## Starts a new run in the Apartment on Day 1. Wallet initialization remains owned by CasinoWallet.
func begin_new_run() -> Dictionary:
	if not _is_authority():
		return _failure("Only the host can begin a run.")
	if run_active:
		return _failure("A run is already active.")
	_publish_state(true, 1, Phase.APARTMENT, false)
	_log("New run started. Day 1 begins in the Apartment.")
	return _success(get_snapshot())


## The progression manager asks for a destination; the elevator never decides game rules.
## Returns -1 when the current phase/world combination does not permit departure.
func get_departure_destination(current_world: int) -> int:
	if not run_active:
		return -1
	match phase:
		Phase.APARTMENT:
			return WORLD_CASINO if current_world == WORLD_APARTMENT else -1
		Phase.CASINO:
			if current_world == WORLD_CASINO and casino_departure_allowed:
				return WORLD_REST_AREA
		Phase.REST_AREA:
			if current_world == WORLD_REST_AREA and current_day < MAX_DAYS:
				return WORLD_CASINO
	return -1


## Called only after MainController has completed the approved world transition.
## Entering the Casino from the Rest Area advances the day.
func complete_world_transition(previous_world: int, destination_world: int) -> bool:
	if not _is_authority():
		return false
	if get_departure_destination(previous_world) != destination_world:
		return false

	var next_day: int = current_day
	var next_phase: int = phase
	var next_casino_departure_allowed: bool = casino_departure_allowed
	match phase:
		Phase.APARTMENT:
			next_phase = Phase.CASINO
		Phase.CASINO:
			next_phase = Phase.REST_AREA
			next_casino_departure_allowed = false
		Phase.REST_AREA:
			next_day += 1
			next_phase = Phase.CASINO
			next_casino_departure_allowed = false
		_:
			return false

	_publish_state(true, next_day, next_phase, next_casino_departure_allowed)
	_log("Progression advanced to Day %d (%s)." % [current_day, _phase_name(phase)])
	return true


## Quota/deadline systems will unlock this after their authoritative result is known.
func set_casino_departure_allowed(allowed: bool) -> bool:
	if not _is_authority() or not run_active or phase != Phase.CASINO:
		return false
	_publish_state(run_active, current_day, phase, allowed)
	return true


func get_snapshot() -> Dictionary:
	return {
		"run_active": run_active,
		"current_day": current_day,
		"phase": phase,
		"phase_name": _phase_name(phase),
		"casino_departure_allowed": casino_departure_allowed,
		"max_days": MAX_DAYS,
	}


func _publish_state(active: bool, day: int, next_phase: Phase, departure_allowed: bool) -> void:
	var network_peer: MultiplayerPeer = multiplayer.multiplayer_peer
	if network_peer is OfflineMultiplayerPeer:
		_apply_state(active, day, next_phase, departure_allowed)
	else:
		rpc("_rpc_apply_state", active, day, next_phase, departure_allowed)


@rpc("authority", "call_local", "reliable")
func _rpc_apply_state(active: bool, day: int, next_phase: int, departure_allowed: bool) -> void:
	if day < 0 or day > MAX_DAYS or next_phase < Phase.IDLE or next_phase > Phase.RUN_FAILED:
		return
	_apply_state(active, day, next_phase, departure_allowed)


func _apply_state(active: bool, day: int, next_phase: int, departure_allowed: bool) -> void:
	run_active = active
	current_day = day
	phase = next_phase
	casino_departure_allowed = departure_allowed
	run_state_changed.emit(get_snapshot())


func _is_authority() -> bool:
	return multiplayer.is_server()


func _phase_name(value: int) -> String:
	match value:
		Phase.IDLE:
			return "IDLE"
		Phase.APARTMENT:
			return "APARTMENT"
		Phase.CASINO:
			return "CASINO"
		Phase.REST_AREA:
			return "REST_AREA"
		Phase.CONTRACT_FULFILLED:
			return "CONTRACT_FULFILLED"
		Phase.CONTRACT_EXTENDED:
			return "CONTRACT_EXTENDED"
		Phase.RUN_FAILED:
			return "RUN_FAILED"
	return "UNKNOWN"


func _success(data: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"ok": true, "reason": ""}
	result.merge(data, true)
	return result


func _failure(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}


func _log(message: String) -> void:
	if is_instance_valid(_debug_hub):
		_debug_hub.call("log", &"run", message)
