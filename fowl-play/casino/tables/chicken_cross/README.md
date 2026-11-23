# Chicken Cross

Chicken Cross is the reference casino game implementation. Its rules, per-player round state, host-authoritative table adapter, shared betting keypad, and editor-authored table scene are present.

## Files

- `chicken_cross_rules.gd` — approved twelve-tile failure chances and cash-out multipliers.
- `chicken_cross_round.gd` — independent player progress, cash-out/failure state, departure resolution, and gross payout map.
- `chicken_cross_table.gd` — `BaseTable` adapter, wager validation/locking, host-authoritative Cross/Cash Out actions, settlement, and player-state replication.
- `chicken_cross_visual_builder.gd` — tabletop finishes and lane feedback.
- `chicken_cross_chicken.gd` — reusable procedural 3D contestant with player-color materials, idle bob/head/feet motion, blinking, cash-out celebration, and a comedic car-hit/feather-burst failure animation.
- `chicken_cross_table.tscn` — editor-authored physical table scene.

## Boundaries

Shared casino infrastructure stays in `res://casino/` (for example `BaseTable` and `CasinoWallet`). Chicken Cross uses those systems rather than reimplementing wallet or table lifecycle behavior.

Physical board layout, spawn markers, and button nodes remain editor-authored. The contestant chicken is an intentional runtime-generated character asset: each successful wager creates one colored chicken under the existing Visuals node on every peer. The host's replicated per-player state drives its tile position and outcome animation; the visual never decides game results.

## Verification

Run `res://tests/run_chicken_cross_checks.bat` on Windows. The suite covers rules, keypad behavior, and table settlement. The expanded table checks include independent two-player outcomes and rejection/refund when one player has multiple active wagers.

The editor-authored scene's Inspector references and in-game multiplayer presentation still require local Godot verification.
