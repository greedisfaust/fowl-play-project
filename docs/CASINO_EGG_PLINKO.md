# Egg Plinko

Egg Plinko is a shared multiplayer casino table. Every egg is an independent wager and wallet settlement, allowing new launches while earlier eggs are still moving.

## Player flow

1. A player enters the table's proximity area.
2. The shared terminal keypad is used to choose an amount and press CONFIRM.
3. Confirming stores that player's selected amount; it does not reserve or spend money.
4. Pressing the physical PLINKO button launches one egg and reserves the full selected amount.
5. The host resolves the egg's peg path, landing slot and gross return.
6. The egg's independent wallet round settles when its animation reaches the pocket.

Changing the selected amount never edits an egg already in flight. Every PLINKO press is a new, full-stake wager.

## Shared-wallet safety

The table reads the live CasinoDayManager daily quota and the current available CasinoWallet balance. The quota gap is:

    quota_remaining = max(daily_quota - available_balance, 0)

The configurable safety hold is:

    safety_reserve = ceil(quota_remaining * quota_safety_bias)

The maximum launch amount is capped by both the terminal profile maximum and:

    available_balance - safety_reserve

The minimum wager reduces with the remaining quota gap, but never exceeds the current maximum. The default safety bias is 15% and can be tuned on the EggPlinkoTable inspector. Launches are revalidated on the host, so an earlier egg's stake or another player's rapid launch cannot bypass the live limit.

The board also caps concurrent airborne eggs at 32 by default. This is a presentation/performance guard, not a per-player click cooldown.

## Multiplayer authority

- The host alone chooses the path, slot and multiplier.
- Each egg opens a unique wallet round, reserves one complete stake, and locks it immediately.
- The unique wager record retains the originating peer ID and egg metadata.
- All peers receive the same path and player color.
- The host settles the wager once the egg reaches its destination.
- Clients never submit a payout or landing slot.

The path is replicated rather than independently simulated by each peer. This keeps the visual landing and authoritative payout in agreement.

## Board presentation

The board, peg rows, rails, multiplier pockets, and table body are generated procedurally by egg_plinko_visual_builder.gd. Eggs are visual-only synchronized path followers; the host wallet ledger remains the source of truth.

The terminal reuses the Chicken Cross Slim World Screen, BettingKeypad, BettingTerminalDisplay and BettingTerminalProfile systems. The keypad controller's selection-only mode is opt-in, so Chicken Cross keeps its existing one-wager-per-player flow.

## Verification

Run tests/run_egg_plinko_checks.bat on Windows with FOWL_PLAY_GODOT set to the Godot executable. The headless rules check covers deterministic paths, slot ranges and gross payout calculations. Full editor/physics/multiplayer validation still needs to be performed in Godot.
