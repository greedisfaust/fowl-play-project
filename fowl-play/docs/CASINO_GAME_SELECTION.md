# CasinoManager — Game Catalog and Daily Selection

CasinoManager is an Autoload at /root/CasinoManager. It owns the selectable game catalog and the daily game draw. It does not own game rules, table round state, wagers, or wallet settlement.

## Approved selection rules

- The complete production roster contains exactly 12 game types.
- Exactly 6 unique game types are selected for each casino day.
- Every registered game has equal inclusion probability.
- A game may appear on consecutive days; yesterday's selection does not affect today's odds.
- A game type cannot appear twice in the same day's selection.
- All 12 game types are eligible from Day 1; there are no progressive unlocks.
- The host performs the draw and sends the selected IDs to every client using a reliable authority RPC.
- A day's selection is stable and cannot be rerolled by requesting selection again.
- Starting a fresh run clears the previous run's selection.

## Current catalog status

Only **Chicken Cross** currently has an implemented table scene and is registered by the production manager. The other eleven game names and IDs have not been finalized. CasinoManager deliberately refuses to draw from a partial catalog. It does not create placeholder game IDs or pretend the roster is complete.

Once all twelve production definitions are registered, the manager automatically selects six when RunManager reports arrival in the Casino. If the catalog is still incomplete, the Casino day and quota systems continue to work, but no daily game selection is published.

## Game definition contract

CasinoGameDefinition is a Resource with:

- game_id: StringName — stable, unique machine-readable identifier.
- display_name: String — player-facing game name.
- table_scene: PackedScene — instantiable scene for the game/table.

Register definitions with CasinoManager.register_game(definition).

Registration rejects empty IDs/names, missing or non-instantiable scenes, and duplicate IDs. Every peer must load the same production catalog before the host selection RPC arrives.

## Selection algorithm

CasinoManager sorts the registered IDs to provide a stable input roster, then performs a partial Fisher-Yates shuffle for the first six positions. Each draw step chooses uniformly from the remaining unselected entries. This yields a uniform six-item subset without replacement.

The host selects on the RunManager transition into CASINO. The selection is sent to peers with a reliable authority RPC. Clients validate the day number, exact selection count, registration of every ID, and uniqueness before applying it.

The same day cannot be rerolled. Consecutive days are independent draws, so repeats are naturally possible.

## Autoload and integration

- CasinoGameDefinition: Resource contract, not an Autoload.
- CasinoManager: catalog, draw, and selection synchronization.
- RunManager: supplies current run/day/phase and signals Casino arrival.
- CasinoDayManager: independent quota and timer lifecycle.

No physical casino scene changes are required by this selector slice. Mapping the six selected game definitions to the six editor-authored casino table locations is a later integration step; this manager only provides the selected definitions/IDs.

## DebugHub watches

- casino/games/registered_count
- casino/games/roster_complete
- casino/games/selected_day
- casino/games/selected_count
- casino/games/selected_ids

Logs use the casino_games category.

## Tests

Run tests/run_casino_manager_checks.bat. It tests the current Chicken Cross registration, incomplete-roster rejection, twelve unique registrations, duplicate-ID rejection, exactly six unique selections, stable same-day selection, fresh-run reset, seeded draw eligibility, and invalid draw inputs.
