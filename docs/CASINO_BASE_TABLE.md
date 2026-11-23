# BaseTable Controller

Status: implemented; shared wallet and BaseTable headless checks USER VERIFIED PASS (Godot 4.7.2).
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
- `cancel_open_round()`: host-side lifecycle operation; cancels only an unstarted round and refunds its reserved wagers. It is not a player-facing cancel permission.

## Inactivity timeout

- `open_round_inactivity_seconds` defaults to 45 seconds.
- The countdown starts when a round opens.
- Joining, confirming/editing/withdrawing a wager, or a participant leaving proximity resets it.
- Merely remaining nearby does not reset it.
- Expiry cancels the unstarted round and refunds every still-reserved wager.
- Starting the round disables the countdown.

## Day-end cleanup

- `request_day_end_cleanup(reason)` is a host-only coordinator hook for early departure and hard timer expiry.
- If the round is `OPEN`, it cancels the round and refunds reserved wagers.
- If the round is `RUNNING` or `RESOLVING`, it preserves locked wagers and emits `round_auto_resolution_requested`; the game adapter must finish automatic resolution and call `settle_round`.
- On timer expiry, the casino/day manager MUST snapshot the authoritative wallet and evaluate quota before calling cleanup. Later settlements cannot change that deadline result.
- Early departure uses the same cleanup hook after the team qualifies to leave; started rounds are resolved, not refunded.

## Departure behavior

- Leaving proximity during `OPEN` refunds that player's reserved wagers and removes their participant record.
- Leaving during `RUNNING` or `RESOLVING` preserves the locked wager, marks the participant as `left_after_start`, and emits `participant_left_after_start`. The game-specific controller must respond with its agreed auto-play/auto-resolution behavior.
- Post-start departures keep wagers locked and rely on game-specific automatic resolution.

## Deliberately deferred

- Casino/day manager orchestration and immutable quota snapshot ordering are not implemented yet.
- Game-specific automatic resolution is signaled but must be implemented by each game adapter.
- Network RPC wrappers and client replication are not added yet. Future RPCs must validate sender identity, table proximity, and game state on the host before calling this API.
- Physical Area3D wiring, nameplate visuals, and game-specific presentation remain editor/game implementation work.

## Verification

USER VERIFIED: The user ran `fowl-play/tests/run_casino_checks.bat` with Godot 4.7.2.stable.steam. Both `CASINO WALLET PASS` and `BASE TABLE PASS` printed, followed by `ALL CASINO CHECKS PASSED`. Import emitted two non-fatal Jolt warnings about unsupported cone-twist bias/softness parameters. This verifies the current headless wallet/BaseTable test coverage; it does not verify multiplayer RPC integration, physical table scenes, or game-specific behavior.
