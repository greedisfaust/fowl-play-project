# RunManager — Persistent Run and Day State

`RunManager` is a project Autoload at `/root/RunManager`. It survives world swaps and stores the host-authoritative outer-loop state. It does not load worlds, own player instances, or mutate the shared wallet.

## Ownership boundaries

- `Network`: multiplayer session, peer roster, player identity and player synchronization.
- `MainController`: persistent players, world scenes, fades and world transitions.
- `RunManager`: active run, current day, current progression phase, and departure destination rules.
- `CasinoWallet`: shared funds and wager ledger.
- `CasinoDayManager`: per-day starting-wallet snapshot, dynamic quota, five-minute timer, and day-end result.
- `CasinoManager`: registers selectable game definitions and synchronizes the six-game daily draw.

## State model

Phases currently defined:

- `IDLE`: no run has started.
- `APARTMENT`: new run, Day 1.
- `CASINO`: active casino day.
- `REST`: between casino days, reusing the Apartment world.
- `CONTRACT_FULFILLED`, `CONTRACT_EXTENDED`, `RUN_FAILED`: reserved terminal outcomes for later progression slices.

The maximum run length is ten days.

## API

- `begin_new_run() -> Dictionary`: host-only; starts Day 1 in the Apartment. Rejects a second start while a run is active.
- `get_departure_destination(current_world: int) -> int`: returns the permitted destination, or `-1` when departure is not currently allowed.
- `bind_main_controller(controller: Node) -> void`: connects the persistent MainController `world_changed` signal to the progression commit handler.
- `complete_world_transition(previous_world: int, destination_world: int) -> bool`: host-only; commits progression after MainController installs the destination world.
- `set_casino_departure_allowed(allowed: bool) -> bool`: host-only quota/deadline integration point. Casino departure is locked until this is enabled.
- `get_snapshot() -> Dictionary`: returns a read-only copy of the current state.

World IDs match `MainController.World`: Apartment=0, Casino=1. The Rest phase uses the Apartment world ID.

State changes are broadcast by a reliable authority RPC. Offline sessions apply the state locally. The `run_state_changed(snapshot)` signal is emitted on every peer after state application.

## Dynamic daily quota formula

The quota is recalculated at the beginning of every casino day from the **actual shared wallet carried into that day**. It is not a fixed amount and it is not based on the original Day 1 wallet after Day 1.

**Formula:** daily quota = W + (W × 0.50) + (W × M) = W × (1.50 + M)

- W is the shared wallet at the beginning of the current day.
- 0.50 adds half of that day's starting wallet.
- M is the additional multiplier for the current day.
- The result is rounded up to the next whole wallet unit.
- The quota is a threshold, not a cap. The team may continue earning after reaching it; the full final wallet carries forward.
- On a successful day, the wallet at departure becomes the next day's W. The next day's quota is recalculated from that new amount.
- Do not reset the wallet to the original starting amount after a successful day.

### Initial day multiplier schedule

| Day | Additional multiplier |
|---:|---:|
| 1 | 0.25 |
| 2 | 0.28 |
| 3 | 0.32 |
| 4 | 0.36 |
| 5 | 0.40 |
| 6 | 0.45 |
| 7 | 0.50 |
| 8 | 0.55 |
| 9 | 0.62 |
| 10 | 0.70 |

### Worked example

- Day 1 starts with a shared wallet of 1,000.
- Day 1 multiplier is 0.25, so quota = 1,000 + 500 + 250 = **1,750**.
- The team earns up to 2,000. Since 2,000 is above 1,750, quota is met. The team may keep playing and finish with more.
- If the team departs with 2,000, Day 2 starts with 2,000.
- Day 2 multiplier is 0.28, so quota = 2,000 + 1,000 + 560 = **3,560**.

This formula and carry-forward behavior are the intended progression rules.

## Casino day initialization

RunManager.begin_new_run() asks CasinoWallet to initialize the shared wallet ledger to 1,000 once for a fresh run. RunManager only commits the run as active if CasinoWallet confirms initialization succeeded; CasinoWallet remains the sole owner of balance mutations. On arrival in the Casino, CasinoDayManager snapshots the actual carried-forward wallet, calculates the dynamic quota, and starts the five-minute timer. Reaching quota unlocks early departure but does not stop the timer or prevent further play. At deadline, wallet/quota success is recorded before table cleanup. See CASINO_DAY_MANAGER.md for the formula, multiplier schedule, deadline order, and implementation details.

## Day flow implemented in this slice

1. Begin a run: Day 1, Apartment.
2. Apartment departure: Casino, still Day 1.
3. Casino departure: blocked until quota/deadline logic unlocks it.
4. Once unlocked, Casino departure: Apartment (Rest phase).
5. Apartment Rest-phase departure: next Casino day; the day number increments on arrival.

The existing ElevatorDepartureController now asks RunManager for the permitted destination. On the first valid Apartment departure, it starts a new run automatically. It then calls the existing accepted-departure sequence. MainController notifies RunManager through its persistent `world_changed` signal, so progression is committed after arrival even though the source elevator scene is unloaded during the transition. Day 10 terminal outcomes and loan handling remain for subsequent slices. CasinoDayManager owns quota/timer behavior; CasinoManager owns daily game selection (the production catalog remains incomplete until the other eleven games are defined).

## DebugHub watches

- `run/active`
- `run/day`
- `run/phase`
- `run/casino_departure_allowed`

## Tests

Run `tests/run_run_manager_checks.bat`. It checks Day 1 initialization, MainController world-arrival signal binding, valid world progression, the Casino departure gate, Day 2 increment, and rejection of overwriting an active run.
