# Chicken Cross – Gameplay and Multiplayer Verification

## Current implementation

- Host-authoritative per-player tile advancement and cash-out.
- One locked wager per participant.
- Each player receives an independent risk roll on each tile.
- Safe progress, current tile, failure, and cash-out are presented locally on that player's table lane.
- The terminal screen shows the local player's tile, next-tile risk, cash-out multiplier, estimated gross return, and final result.
- Leaving table proximity or disconnecting after the round starts automatically resolves that player's wager.
- Day-end cleanup automatically resolves all active players and settles the round.

## Automated checks

Run `tests\\run_chicken_cross_checks.bat` from Windows Explorer or PowerShell.

The runner imports the project, then executes:
1. `chicken_cross_rules_test.gd`
2. `chicken_cross_table_test.gd`

The table test uses a random first-tile roll. Either a first-tile loss or a safe first tile followed by day-end auto-cash-out is an expected pass.

## In-game verification

Use two game instances (host and client) for the multiplayer pass.

1. Start a session and place both players inside the Chicken Cross proximity area.
2. Open a round, join with both players, and reserve one wager for each.
3. Start the round. Confirm both wagers lock and each player's screen shows the locked state.
4. On the host, cross once. Confirm the host's local tile lane and terminal display update.
5. On the client, cross once. Confirm the client's local tile lane and terminal display update independently.
6. Cash out one player. Confirm their display shows the final multiplier and payout while the other player remains active.
7. Advance the remaining player until they fail or cash out.
8. Confirm the round settles once, both wager records are settled, and the table returns to IDLE.
9. Repeat and have one player leave the proximity area after the round starts. Confirm that player's wager auto-resolves at their current safe tile (or loses if they have not reached tile 1).
10. Repeat and disconnect one client during a running round. Confirm host auto-resolution and settlement.

## Expected presentation

- Untouched tiles remain dark.
- Previously reached safe tiles glow green.
- The current safe tile glows warm gold.
- A failed tile glows red.
- A cashed-out tile glows gold.
- Each client sees their own progress on their local table, not another player's progress.
- The display uses the existing terminal screen component and terminal typography.

## Important scope notes

- Tile feedback is a local presentation of authoritative state; it does not affect risk rolls or payouts.
- The table's existing `player_state_changed` signal remains the authoritative gameplay observation hook.
- This environment cannot run the user's Windows Steam Godot executable. Automated checks must be run locally before considering the slice verified.
