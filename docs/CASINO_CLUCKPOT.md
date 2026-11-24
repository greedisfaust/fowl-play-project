# Cluckpot

Cluckpot is a four-cabinet slot-machine bank presented as one selectable casino game. The arcade scene contains four independent `BaseTable` machines with unique wallet table IDs, separate proximity, wager selection, spin state, and keypad controllers. The daily casino spawner still consumes one game slot for Cluckpot, but all four cabinets appear together when selected.

## Cabinet and interaction

- Each cabinet uses a cool cast-silver body, deep burgundy enamel, restrained champagne-metal trim, walnut foot, a single Golden 7 crown medallion, physical side lever, and collision. Decorative labels and marquee text are intentionally omitted.
- A larger, high-resolution standard `WorldScreen` is mounted above the reel window. Its large centered readout shows the day's minimum and maximum, current keypad draft, and spin result. Invalid or empty wagers are red; valid wagers are green. It is not a terminal screen or a Slim/Fat terminal housing.
- Each reel symbol is rendered from the supplied transparent PNG artwork in `assets/images/cluckpot/`, using a `Sprite3D` on an ivory reel tile. No symbol-name text or procedural animal/food meshes are used.
- The seven-symbol pool is Golden 7, Golden Chicken (wild), normal chicken, baby chick, egg, corn, and chicken wings. Cherries, lemons, and feathers are not part of the game.
- Chicken wings are a regular lower-value payout symbol. Golden Chicken substitutes for other symbols on winning lines; three Golden Chickens pay the wild line value.
- The visual builder is an editor tool. Generated cabinet meshes, textured reel symbols, and collision are owned by the authored scene so they can be inspected and adjusted in Godot.
- Each cabinet instantiates the existing shared `BettingKeypad` and `BettingKeypadController` in selection-only mode. Confirming a valid wager immediately reserves the stake and starts the spin. There is no extra spin button.
- Reels use smooth vertical symbol scrolling with a slower ramp, longer anticipation, and staggered deceleration/stops. The physical side lever pulls and the cabinet gives a small mechanical kick during the spin.
- Each machine is independent. A spin locks only that cabinet while its reels animate, so the other three remain available.
- The host validates proximity and the selected wager, reserves the stake in `CasinoWallet`, rolls the outcome, and settles the individual spin. Clients receive the authoritative reel result and play the same staged stop animation.
- In-flight spins settle using their precomputed payout during casino day-end cleanup.

## Symbols and paylines

The reels display three rows each. Five paylines are evaluated: center, top, bottom, descending diagonal, and ascending diagonal. The Golden Chicken is wild and substitutes for the matching symbol. Payouts from all winning lines are added together.

| Symbol | Gross line multiplier |
| --- | ---: |
| Golden 7 | 28× |
| Golden Chicken (wild) | 14× |
| Normal chicken | 7× |
| Baby chick | 3.2× |
| Egg | 2.2× |
| Corn | 1.3× |
| Chicken wings | 0.8× |

These are initial paytable values and should be balanced with playtesting before release.

## Files

- `casino/tables/cluckpot/cluckpot_arcade.tscn` — four-machine bank, arranged as two opposing pairs.
- `casino/tables/cluckpot/cluckpot_machine.tscn` — one independent cabinet scene.
- `cluckpot_machine.gd` — host-authoritative spin, wallet, wager, proximity, and presentation logic.
- `cluckpot_visual_builder.gd` — editor-time cabinet construction and uploaded PNG reel artwork.
- `cluckpot_rules.gd` — symbol weighting, paylines, and payout calculation.
- `cluckpot_profile.tres` — shared keypad wager profile.
- `cluckpot_wager_display.gd` — adapter that puts live keypad draft values on the cabinet WorldScreen.

## Checks

Run `tests/run_cluckpot_checks.bat` after setting `FOWL_PLAY_GODOT`. The checks cover Golden 7 and wild payouts, the seven uploaded symbol assets, four independent machines, WorldScreen/keypad integration, and host-side wallet settlement.
