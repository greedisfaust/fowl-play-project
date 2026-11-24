# Cluckpot

Cluckpot is a four-cabinet slot-machine bank presented as one selectable casino game. The arcade scene contains four independent `BaseTable` machines with unique wallet table IDs, separate proximity, wager selection, spin state, and keypad controllers. The daily casino spawner still consumes one game slot for Cluckpot, but all four cabinets appear together when selected.

## Cabinet and interaction

- Each cabinet is a classic mechanical slot machine with a cast-metal housing, burgundy enamel face, polished brass bezel, walnut foot, physical side lever, and collision.
- A standard `WorldScreen` is mounted above the reel window. It shows the live keypad draft plus the day's minimum and maximum wager, selected amount, and spin result. It is not a terminal screen or a Slim/Fat terminal housing.
- The reels use modeled 3D symbol meshes: Golden 7, rooster, Golden Chicken wild, chick, egg, corn, feather, cherries, and lemon. Reel faces never display symbol-name text.
- The visual builder is an editor tool. Generated cabinet meshes, symbols, and collision are owned by the authored scene so they can be inspected and adjusted in Godot.
- Each cabinet instantiates the existing shared `BettingKeypad` and `BettingKeypadController` in selection-only mode. Confirming a valid wager immediately reserves the stake and starts the spin. There is no extra spin button.
- Reels ramp up, cycle at speed, then decelerate and stop one at a time. The physical side lever pulls and the cabinet gives a small mechanical kick during the spin.
- Each machine is independent. A spin locks only that cabinet while its reels animate, so the other three remain available.
- The host validates proximity and the selected wager, reserves the stake in `CasinoWallet`, rolls the outcome, and settles the individual spin. Clients receive the authoritative reel result and play the same staged stop animation.
- In-flight spins settle using their precomputed payout during casino day-end cleanup.

## Symbols and paylines

The reels display three rows each. Five paylines are evaluated: center, top, bottom, descending diagonal, and ascending diagonal. The Golden Chicken is wild and substitutes for the matching symbol. Payouts from all winning lines are added together.

| Symbol | Gross line multiplier |
| --- | ---: |
| Golden 7 | 28× |
| Golden Chicken (wild) | 14× |
| Rooster | 7× |
| Chick | 3.2× |
| Egg | 2.2× |
| Corn | 1.3× |
| Cherry | 1.1× |
| Lemon | 0.8× |
| Feather | 0.5× |

These are initial paytable values and should be balanced with playtesting before release.

## Files

- `casino/tables/cluckpot/cluckpot_arcade.tscn` — four-machine bank, arranged as two opposing pairs.
- `casino/tables/cluckpot/cluckpot_machine.tscn` — one independent cabinet scene.
- `cluckpot_machine.gd` — host-authoritative spin, wallet, wager, proximity, and presentation logic.
- `cluckpot_visual_builder.gd` — editor-time mechanical cabinet and 3D symbol construction.
- `cluckpot_rules.gd` — symbol weighting, paylines, and payout calculation.
- `cluckpot_profile.tres` — shared keypad wager profile.
- `cluckpot_wager_display.gd` — adapter that puts live keypad draft values on the cabinet WorldScreen.

## Checks

Run `tests/run_cluckpot_checks.bat` after setting `FOWL_PLAY_GODOT`. The checks cover Golden 7 and wild payouts, four independent machine instances, WorldScreen/keypad integration, modeled symbol nodes, and host-side wallet settlement.
