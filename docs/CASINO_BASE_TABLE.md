# BaseTable Controller

Status: first generic lifecycle controller implemented; Godot execution pending.
Branch: `environment/world-building-and-gameplay-loop`

## Responsibility

`casino/base_table.gd` is a script-only controller intended to be attached to an editor-authored table scene. It does not create meshes, collision shapes, node hierarchies, nameplate geometry, or game-specific rules.

It owns the generic table lifecycle and calls the existing `CasinoWallet` autoload for financial operations. The host remains authoritative.

## Lifecycle

- `IDLE`: ready for a new round.
- `OPEN`: wagers may be placed, edited, or withdrawn.
- `RUNNING`: wagers are locked; game rules are active.
- `RESOLVING`: game outcome is being finalized.
- `CLOSED`: reserved for a future explicit table shutdown path.

The controller creates a unique round ID for each round opened on that table.

## Integration API

- `enter_proximity(peer_id)` / `exit_proximity(peer_id)`: host-side proximity adapter hooks.
- `open_round(peer_id)`: any nearby player may open a round; opening does not automatically make them a participant.
- `join_table(peer_id)`: adds a nearby participant, subject to `max_participants`.
- `place_wager(peer_id, amount, payload)`: reserves a wager for a joined participant.
- `update_wager(peer_id, wager_id, amount, payload)` / `withdraw_wager(peer_id, wager_id)`: enforce bettor ownership at the table boundary.
- `start_round(peer_id)`: any nearby player may start, including a non-participant; the wallet rejects rounds without active wagers.
- `begin_resolution()` / `settle_round(payouts)`: game implementation reports the authoritative outcome and gross returns.
- `cancel_open_round(peer_id)`: cancels only an unstarted round and refunds its reserved wagers.

## Departure behavior

- Leaving proximity during `OPEN` refunds that player's reserved wagers and removes their participant record.
- Leaving during `RUNNING` or `RESOLVING` preserves the locked wager, marks the participant as `left_after_start`, and emits `participant_left_after_start`. The game-specific controller must respond with its agreed auto-play/auto-resolution behavior.
- This does not decide timer-expiry behavior or early-departure refunds for already-started rounds.

## Deliberately deferred

- The 45-second inactivity timeout's activity definition and cancellation policy remain open.
- Day-end force-refund scope for already-started rounds remains open.
- Network RPC wrappers and client replication are not added yet. Future RPCs must validate sender identity, table proximity, and game state on the host before calling this API.
- Physical Area3D wiring, nameplate visuals, and game-specific presentation remain editor/game implementation work.
