# Egg Plinko

Egg Plinko is a shared multiplayer casino table. Every egg is an independent wager and wallet settlement, allowing new launches while earlier eggs are still moving.

## Player flow

1. A player enters the table's proximity area.
2. The shared terminal keypad is used to choose an amount and press CONFIRM.
3. Confirming updates one shared team/table wager; it does not reserve or spend money. Players may maintain independent unconfirmed keypad drafts, but the latest successful confirmation becomes the wager used by every player's upcoming launch.
4. Any player pressing the physical PLINKO button launches one egg and reserves the full current team wager.
5. The host resolves the egg's peg path, landing slot and gross return.
6. The egg's independent wallet round settles when its animation reaches the pocket.

Changing the shared team wager never edits an egg already in flight. Every PLINKO press by any player is a new, full-stake wager using the current shared setting.

## Shared-wallet safety

The table reads the live CasinoDayManager daily quota and the current available CasinoWallet balance. The quota gap is:

    quota_remaining = max(daily_quota - available_balance, 0)

The configurable safety hold is:

    safety_reserve = ceil(daily_quota * quota_safety_bias)

The maximum launch amount is capped by the terminal profile maximum, the spendable balance after that hold, and the remaining quota gap while the quota is still unmet:

    maximum = min(profile_maximum, available_balance - safety_reserve, quota_remaining)

Once the quota is met, the remaining-quota cap is replaced by the spendable balance, while the protected quota buffer remains in place.

The minimum wager reduces with the remaining quota gap, and the maximum cannot exceed that gap until the quota is met. Neither limit can exceed the current safe spendable amount. The default safety bias is 15% and can be tuned on the EggPlinkoTable inspector. Launches are revalidated on the host, so an earlier egg's stake or another player's rapid launch cannot bypass the live limit.

The board also caps concurrent airborne eggs at 32 by default. This is a presentation/performance guard, not a per-player click cooldown. If the casino day ends or the team departs early, the table immediately settles every already-reserved egg using its host-resolved outcome, then clears the visuals on all peers. This prevents locked stakes from surviving a day transition.

## Payout schedule

The thirteen landing pockets use a symmetric multiplier schedule:

    24x, 12x, 3x, 1.5x, 1x, 0.8x, 0.4x,
    0.8x, 1x, 1.5x, 3x, 12x, 24x

With twelve independent 50/50 peg decisions, the theoretical gross return is approximately 98.12% of total stakes (about a 1.88% house edge before integer rounding). The outer jackpot pockets remain rare, while the center pocket is the lowest-return result.

## Multiplayer authority

- The host alone chooses the path, slot and multiplier.
- Each egg opens a unique wallet round, reserves one complete stake, and locks it immediately.
- The unique wager record retains the originating peer ID and egg metadata.
- All peers receive the same path and player color.
- The host settles the wager once the egg reaches its destination.
- Clients never submit a payout or landing slot.

The path is replicated rather than independently simulated by each peer. This keeps the visual landing and authoritative payout in agreement.

## Board presentation

The oversized freestanding arcade cabinet, triangular illuminated peg field, rails, multiplier pockets, and pedestal body are generated procedurally by egg_plinko_visual_builder.gd. Its collision body covers the lower cabinet, board backing, side columns, and control deck while leaving forward-facing controls accessible. The decorative title above the board is intentionally omitted. The shared terminal display, full keypad and launch button are mounted into the cabinet's control deck. Eggs are visual-only synchronized path followers; the host wallet ledger remains the source of truth.

The terminal reuses the Chicken Cross Slim World Screen, BettingKeypad, BettingTerminalDisplay and BettingTerminalProfile systems. The keypad controller's selection-only mode is opt-in, so Chicken Cross keeps its existing one-wager-per-player flow.

## Verification

The CasinoManager now registers Egg Plinko as the second built-in game, but the production catalog still requires twelve unique definitions before daily selection is enabled. Until the full roster is complete, the existing development fallback continues to spawn Chicken Cross. Open the Egg Plinko table scene directly to inspect it, or use the dedicated test runner.

Run tests/run_egg_plinko_checks.bat on Windows with FOWL_PLAY_GODOT set to the Godot executable. The headless rules check covers deterministic paths, slot ranges and gross payout calculations. Full editor/physics/multiplayer validation still needs to be performed in Godot.
