# Casino HUD Foundation

## Scope

The persistent CasinoHUD is a CanvasLayer child of the persistent Main scene. This first slice displays only:

- Current day label (for example, `DAY 1`, with no maximum-day suffix).
- Available shared wallet balance.
- Daily quota.
- Casino countdown timer.

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

Set the MarginContainer to Full Rect with modest screen-edge margins. Anchor TopLeft to the upper-left corner and TopCenter to the top-center. Keep all text left-aligned except TimerLabel, which is centered. Use the same terminal font asset used by the existing terminal UI and assign it to the controller's `terminal_font` export.

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
- `MarginContainer/TopLeft/DayLabel`
- `MarginContainer/TopLeft/WalletLabel`
- `MarginContainer/TopLeft/QuotaLabel`
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

This foundation uses the terminal font assigned in the Inspector. Visual glow polish can be layered on after the first in-game layout review.

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
