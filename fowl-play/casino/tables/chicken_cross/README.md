# Chicken Cross

Chicken Cross is the reference casino game implementation. Its rules, per-player round state, host-authoritative table adapter, shared betting keypad, and editor-authored table scene are present.

## Files

- `chicken_cross_rules.gd` — approved twelve-tile failure chances and cash-out multipliers.
- `chicken_cross_round.gd` — independent player progress, cash-out/failure state, departure resolution, and gross payout map.
- `chicken_cross_table.gd` — `BaseTable` adapter, wager validation/locking, host-authoritative Cross/Cash Out actions, settlement, and player-state replication.
- `chicken_cross_visual_builder.gd` — tabletop finishes and lane feedback; it does not create or own the editor-authored chicken models.
- `chicken_cross_table.tscn` — editor-authored physical table scene.

## Boundaries

Shared casino infrastructure stays in `res://casino/` (for example `BaseTable` and `CasinoWallet`). Chicken Cross uses those systems rather than reimplementing wallet or table lifecycle behavior.

Physical board layout, chicken models, spawn markers, and button nodes remain editor-authored. Scripts may expose controller hooks and update assigned presentation nodes, but must not generate or replace the table scene hierarchy.

## Verification

Run `res://tests/run_chicken_cross_checks.bat` on Windows. The suite covers rules, keypad behavior, and table settlement. The expanded table checks include independent two-player outcomes and rejection/refund when one player has multiple active wagers.

The editor-authored scene's Inspector references and in-game multiplayer presentation still require local Godot verification.
