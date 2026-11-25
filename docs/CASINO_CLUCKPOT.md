# Cluckpot

Cluckpot is a four-cabinet slot-machine bank presented as one selectable casino game. The arcade scene contains four independent `BaseTable` machines with unique wallet table IDs, separate proximity, wager selection, spin state, and keypad controllers. The daily casino spawner still consumes one game slot for Cluckpot, but all four cabinets appear together when selected.

## Cabinet and interaction

- Each cabinet uses a cool cast-silver body, deep burgundy enamel, restrained champagne-metal trim, walnut foot, an enlarged head-mounted WorldScreen, physical side lever, and collision. Decorative labels and marquee text are intentionally omitted.
- A high-resolution standard `WorldScreen` replaces the former Golden 7 medallion, enlarged to 1.55 × 0.58 and positioned just above the reel bezel without covering the symbol window. Its oversized centered readout shows the day's minimum and maximum, current keypad draft, and spin result. Invalid or empty wagers are red; valid wagers are green. It is not a terminal screen or a Slim/Fat terminal housing.
- Each reel is a horizontal-axis cylinder with ten symbol faces wrapped around its circumference, a recessed ivory core smaller than the symbol ring so it cannot occlude the wrapped artwork, and machined brass end caps. Supplied transparent PNG artwork in `assets/images/cluckpot/` is rendered on curved-facing `Sprite3D` tiles; no symbol-name text or procedural animal/food meshes are used.
- The seven-symbol pool is Golden 7, Golden Chicken (wild), normal chicken, baby chick, egg, corn, and chicken wings. Cherries, lemons, and feathers are not part of the game.
- Chicken wings are a regular lower-value payout symbol. Golden Chicken substitutes for other symbols on winning lines; three Golden Chickens pay the wild line value.
- The visual builder is an editor tool. Generated cabinet meshes, textured reel symbols, and collision are owned by the authored scene so they can be inspected and adjusted in Godot.
- Each cabinet instantiates the existing shared `BettingKeypad` and `BettingKeypadController` in selection-only mode. Confirming a valid wager immediately reserves the stake and starts the spin. There is no extra spin button.
- All three cylindrical drums rotate around their horizontal axles for a 4–6 second spin, accelerating into a sustained rotation before decelerating and stopping left-to-right. The host outcome is installed into the actual symbol rings before motion. A shared visual seed keeps filler symbols and starting phases identical across clients; each reel finishes at a precise whole-revolution alignment, so the visible final symbols cannot be swapped after the stop. The physical side lever pulls and the cabinet gives a small mechanical kick during the spin.
- Each machine is independent. A spin locks only that cabinet while its reels animate, so the other three remain available.
- The host validates proximity and the selected wager, reserves the stake in `CasinoWallet`, rolls the outcome, and settles the individual spin. Clients receive the authoritative reel result and play the same staged stop animation.
- In-flight spins settle using their precomputed payout during casino day-end cleanup.

## Symbols and paylines

The reels display three rows each, but only the center row directly facing the player is an active 1 × 3 payline. Matching symbols on the top, bottom, or diagonals do not pay. The Golden Chicken is wild and substitutes for the matching symbol. This keeps the win condition visually obvious: match the three symbols in the front row.

| Symbol | Gross line multiplier |
| --- | ---: |
| Golden 7 | 126× |
| Golden Chicken (wild) | 63× |
| Normal chicken | 31.5× |
| Baby chick | 14.4× |
| Egg | 9.9× |
| Corn | 5.85× |
| Chicken wings | 3.6× |

The single-line multipliers are 4.5× the former per-line values to make the one visible payline feel rewarding without simply multiplying the old paytable by five. With the current symbol weights and wild substitution, the theoretical gross return is approximately 91.7% before integer payout rounding; playtesting should still validate the feel and economy.

## Files

- `casino/tables/cluckpot/cluckpot_arcade.tscn` — four-machine bank, arranged as two opposing pairs.
- `casino/tables/cluckpot/cluckpot_machine.tscn` — one independent cabinet scene.
- `cluckpot_machine.gd` — host-authoritative spin, wallet, wager, proximity, and presentation logic.
- `cluckpot_visual_builder.gd` — editor-time cabinet construction and uploaded PNG reel artwork.
- `cluckpot_rules.gd` — symbol weighting, paylines, and payout calculation.
- `cluckpot_profile.tres` — shared keypad wager profile.
- `cluckpot_wager_display.gd` — adapter that puts live keypad draft values on the cabinet WorldScreen.

## Checks

Run `tests/run_cluckpot_checks.bat` after setting `FOWL_PLAY_GODOT`. The checks cover Golden 7 and wild payouts, all thirty wrapped symbol faces, non-occluding cylindrical drum cores and end caps, exact final-symbol alignment with the host outcome, the enlarged WorldScreen placement, four independent machines, WorldScreen/keypad integration, and host-side wallet settlement.


## Repeat-spin convenience

After a player confirms their first wager, Cluckpot retains that player's selected amount for the rest of the casino day. The keypad's numeric draft clears as usual, but pressing CONFIRM again with an empty draft immediately starts another spin at the retained amount. Every repeat is a new independently reserved and settled wager; the current shared-wallet balance and daily wager limits are still validated for each spin. Entering a new amount and confirming replaces the retained selection.
