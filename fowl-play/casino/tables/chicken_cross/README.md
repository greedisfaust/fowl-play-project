# Chicken Cross

Game-specific implementation folder.

## Files

- `chicken_cross_rules.gd` — approved twelve-tile failure chances and cash-out multipliers.
- `chicken_cross_round.gd` — per-player round progress, cash-out/failure state, and payout map.
- `chicken_cross_table.gd` — reserved for the future BaseTable-backed multiplayer adapter.
- `chicken_cross_config.gd` — reserved for future game-specific configuration if needed.

## Boundaries

Shared casino infrastructure stays in `res://casino/` (for example `BaseTable` and `CasinoWallet`). Chicken Cross must use those systems rather than reimplementing wallet or table lifecycle behavior.

Physical board scenes, chicken visuals, spawn markers, and button nodes are editor-authored. Automated tests remain in `res://tests/`.
