# Casino HUD Foundation

## Scope

The persistent CasinoHUD is a CanvasLayer child of the persistent Main scene. The HUD currently displays:

- Current day label (for example, `DAY 1`, with no maximum-day suffix).
- Available shared wallet balance.
- Daily quota.
- Casino countdown timer.
- Per-player daily contribution totals derived only from settled wager records (`net_result` grouped by `peer_id`).
- A bottom-right contextual control stack driven by the local player's movement, focus, carry, and recovery states.
- A priority-aware center-screen announcer for local table feedback, quota completion, and day results.
- A visible Blessed/Watched placeholder panel reserved for a future authoritative modifier service.

The HUD is visible only while MainController's active world is the Casino.

## Scene hierarchy

The user authors the scene in Godot; do not overwrite or generate their .tscn file.

Create `res://ui/hud/casino_hud.tscn` with this hierarchy:

```text
CasinoHUD (CanvasLayer) [attach casino_hud_controller.gd]
└── MarginContainer
    ├── TopLeft (Control)
    │   └── WalletStack (VBoxContainer)
    │       ├── DayLabel (Label)
    │       ├── WalletLabel (Label)
    │       └── QuotaLabel (Label)
    └── TopCenter (Control)
        └── TimerLabel (Label)
```

Set the MarginContainer to Full Rect. For its inner spacing, select it and open Inspector → Theme Overrides → Constants; set Margin Left/Top/Right/Bottom to 32. (These are not the Control offsets.) Anchor TopLeft to the upper-left corner and TopCenter to the top-center. Keep all text left-aligned except TimerLabel, which is centered. Use the same terminal font asset used by the existing terminal UI and assign it to the controller's `terminal_font` export.

Suggested initial sizing at 1920x1080:
- MarginContainer: Full Rect, offsets approximately 32 px on all edges.
- TopLeft: top-left anchored, width approximately 360 px.
- WalletStack: top-left aligned, separation 2–4 px.
- TopCenter: top-center anchored, width approximately 260 px.
- DayLabel: small (16 px).
- WalletLabel: 42 px.
- QuotaLabel: 30 px.
- TimerLabel: 36 px.

The controller exposes NodePaths for the four Labels. Defaults expect:
- `MarginContainer/TopLeft/WalletStack/DayLabel`
- `MarginContainer/TopLeft/WalletStack/WalletLabel`
- `MarginContainer/TopLeft/WalletStack/QuotaLabel`
- `MarginContainer/TopCenter/TimerLabel`

If you choose different node names or nesting, update the exported paths in the Inspector.

## Data ownership

- RunManager supplies the current day and phase.
- CasinoDayManager supplies active-day state, available wallet snapshot, quota, timer and quota-reached state.
- CasinoWallet supplies the current available balance and reserved total.
- The HUD is read-only. It does not own a timer, calculate quota, or mutate the wallet.

The wallet amount shown is the available shared balance, consistent with quota evaluation. Reserved wagers are not added back into the displayed available amount.

## Color behavior

- Wallet before quota: green.
- Quota before reached: red.
- Wallet and quota after reached: gold.
- Timer normally uses a light neutral color and turns warning red at 30 seconds or less.

The controller creates the contribution, modifier placeholder, contextual control stack, timer caption, and announcer at runtime. The wallet and quota retain green/red colors until quota is reached; only then do both transition to warm gold and receive a soft text shader bloom. The quota transition also plays a short glow pulse. The shader is `res://ui/hud/quota_glow.gdshader`.

## Integration

Instance the HUD as a direct child of the persistent Main scene, after the existing persistent nodes. Do not add it to a replaceable world scene. Do not edit `main.tscn` on the user's behalf; have the user instance it in Godot.

## Testing

After creating the scene and instancing it under Main, verify:
1. It is hidden in Apartment and Rest Area.
2. It appears in Casino.
3. Day label shows only the current day.
4. Wallet follows available balance changes.
5. Quota is red until reached.
6. Wallet and quota become gold when quota is reached.
7. Timer counts down and becomes red at 00:30.
8. It clears quota/timer fields outside an active casino day.

Run the existing RunManager and Casino Day test runners after integration.

## Live contribution and interaction behavior

- `CasinoWallet.wager_changed` is observed, but only the `settled` status is counted. The controller reads the settled wager record and adds its `net_result` to the total for that wager's `peer_id`. Reserved, locked, withdrawn, and refunded wagers are not counted. A wager ID is counted once only.
- Player nicknames and row colors come from the existing Network identity roster. If an identity is not available, the row falls back to `PLAYER <peer_id>`.
- Contribution totals reset when a new run begins or the casino day number changes.
- The bottom-right contextual control stack listens to the local Player's existing `Focus.focus_target_changed` signal, Carrier signals, and movement/recovery state. It shows Interact only when the focused Interactable accepts M1 or E; carrying replaces combat actions with Drop/Throw. All entries use bright terminal-white, right-aligned, with no indentation.
- Quota-reached and day-result announcements are derived from CasinoDayManager's synchronized state, so every peer sees the same result. BaseTable exposes a host-authoritative `global_announcement` RPC for shared gameplay events; Chicken Cross uses it for round start and successful cash-out. Peer-targeted table feedback remains private to its intended player. The announcer is an unboxed floating feed: up to three notices stack newest-first, fade after a short lifetime, suppress duplicates, and allow critical notices to clear lower-priority entries. It never changes progression state.
- Blessed/Watched currently has no authoritative modifier service to read. The panel is a visible placeholder with empty values. `set_modifier_status(blessed_player, watched_player)` remains the future integration point; only call it with real authoritative assignments.

## Updated playtest checklist

1. Start a new run and enter Casino. Confirm the HUD is visible; leave for Apartment/Rest Area and confirm it hides.
2. Confirm the day, available wallet, quota, and timer match the live managers. Reserved wagers should reduce available wallet immediately.
3. Settle a wager for a player with a positive net result. Their contribution row should increase by that net amount and use their assigned nickname/color.
4. Settle a losing wager. The same player's total should decrease by the net loss.
5. Withdraw an unstarted wager or cancel an unstarted round. Confirm the contribution total does not change.
6. Settle more than one wager for one player. Confirm the row accumulates the net results and does not double-count.
7. Reach quota. Confirm every peer sees the announcement and wallet/quota transition to a smooth champagne-gold gradient with a soft bloom and one brief shimmer.
8. Focus a USE target and a GRAB target. Confirm M1/E hints match the Interactable's accepted inputs and prompt text. Look away and confirm the target prompt clears.
9. Stand still and confirm the movement baseline sits at the bottom-right. Move and confirm Sprint/Jump appear above it; focus an interactable and confirm Interact appears; carry an item and confirm Drop/Throw replace combat actions.
10. Finish a casino day and confirm every peer sees the day-result announcement with the actual final wallet and quota.
11. Start a fresh run and confirm prior contribution rows are cleared.
12. Confirm the Blessed/Watched placeholder remains visible without invented player assignments; calling `set_modifier_status` should only happen with real authoritative values.
13. Confirm the unboxed announcer stacks up to three notices newest-first, fades them out, suppresses duplicates, and lets critical quota/day-result notices override lower-priority notices.
14. Confirm wallet and quota have no gold treatment before quota, then transition to a clean champagne gradient, restrained bloom, and one brief shimmer when quota is reached.
15. Confirm the contextual controls sit bottom-right, remain right-aligned and terminal-white, and update for movement, focus, carrying, and recovery.

The current branch has no dedicated automated CasinoHUD test stage yet. Run the existing `tests/run_run_manager_checks.bat` and `tests/run_casino_day_checks.bat` checks, plus `tests/run_checks.ps1 -OnlyStage casino-wallet` from `fowl-play/`. The user must perform the rendered HUD and two-instance multiplayer checks above. The assistant has not run Godot in this environment.
