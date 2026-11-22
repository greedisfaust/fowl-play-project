# RunManager — Persistent Run and Day State

`RunManager` is a project Autoload at `/root/RunManager`. It survives world swaps and stores the host-authoritative outer-loop state. It does not load worlds, own player instances, or mutate the shared wallet.

## Ownership boundaries

- `Network`: multiplayer session, peer roster, player identity and player synchronization.
- `MainController`: persistent players, world scenes, fades and world transitions.
- `RunManager`: active run, current day, current progression phase, and departure destination rules.
- `CasinoWallet`: shared funds and wager ledger.

## State model

Phases currently defined:

- `IDLE`: no run has started.
- `APARTMENT`: new run, Day 1.
- `CASINO`: active casino day.
- `REST_AREA`: between casino days.
- `CONTRACT_FULFILLED`, `CONTRACT_EXTENDED`, `RUN_FAILED`: reserved terminal outcomes for later progression slices.

The maximum run length is ten days.

## API

- `begin_new_run() -> Dictionary`: host-only; starts Day 1 in the Apartment. Rejects a second start while a run is active.
- `get_departure_destination(current_world: int) -> int`: returns the permitted destination, or `-1` when departure is not currently allowed.
- `bind_main_controller(controller: Node) -> void`: connects the persistent MainController `world_changed` signal to the progression commit handler.
- `complete_world_transition(previous_world: int, destination_world: int) -> bool`: host-only; commits progression after MainController installs the destination world.
- `set_casino_departure_allowed(allowed: bool) -> bool`: host-only quota/deadline integration point. Casino departure is locked until this is enabled.
- `get_snapshot() -> Dictionary`: returns a read-only copy of the current state.

World IDs match `MainController.World`: Apartment=0, Casino=1, Rest Area=2.

State changes are broadcast by a reliable authority RPC. Offline sessions apply the state locally. The `run_state_changed(snapshot)` signal is emitted on every peer after state application.

## Day flow implemented in this slice

1. Begin a run: Day 1, Apartment.
2. Apartment departure: Casino, still Day 1.
3. Casino departure: blocked until quota/deadline logic unlocks it.
4. Once unlocked, Casino departure: Rest Area.
5. Rest Area departure: next Casino day; the day number increments on arrival.

The existing ElevatorDepartureController now asks RunManager for the permitted destination. On the first valid Apartment departure, it starts a new run automatically. It then calls the existing accepted-departure sequence. MainController notifies RunManager through its persistent `world_changed` signal, so progression is committed after arrival even though the source elevator scene is unloaded during the transition. Day 10 terminal outcomes, quota calculation, timer behavior, loan handling, and game selection remain for subsequent slices.

## DebugHub watches

- `run/active`
- `run/day`
- `run/phase`
- `run/casino_departure_allowed`

## Tests

Run `tests/run_run_manager_checks.bat`. It checks Day 1 initialization, MainController world-arrival signal binding, valid world progression, the Casino departure gate, Day 2 increment, and rejection of overwriting an active run.
