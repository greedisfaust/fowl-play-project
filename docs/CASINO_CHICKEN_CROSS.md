# Chicken Cross — Rules and Round-State Contract

Status: Rules/model checks user-verified PASS. Host-authoritative table adapter implemented; local Godot verification pending.

## Approved game rules

- Up to four joined players participate in one round.
- Every participant has one chicken on the same shared twelve-tile lane.
- Progress is individual: one player's movement never advances another chicken.
- A Cross action attempts exactly the next tile for the requesting player.
- The host rolls a fresh independent random value for each player's tile attempt.
- The tile's failure chance is checked on entry. A failed chicken is finished and its wager returns zero.
- A player may cash out after reaching tile 1 or later. Cash Out affects only that player's chicken.
- The round completes when every wagered participant is cashed out or failed.
- Surviving tile 12 automatically cashes out at the final 90x multiplier.
- Payouts are gross returns (stake included), matching CasinoWallet.settle_round.
- Integer wallet returns round down when a multiplier produces a fractional amount.

## Approved tuning

| Tile | Failure chance | Cash-out multiplier |
|---:|---:|---:|
| 1 | 3% | 1.5x |
| 2 | 5% | 2.2x |
| 3 | 8% | 3.2x |
| 4 | 12% | 4.7x |
| 5 | 17% | 6.8x |
| 6 | 23% | 9.8x |
| 7 | 30% | 14x |
| 8 | 39% | 20x |
| 9 | 49% | 29x |
| 10 | 60% | 42x |
| 11 | 72% | 61x |
| 12 | 85% | 90x |

These values are approved as the initial balancing curve. Keep them in chicken_cross_rules.gd, not duplicated in scene scripts.

## Host-authoritative table adapter

- chicken_cross_table.gd inherits BaseTable; it does not duplicate wallet/table lifecycle logic.
- start_round validates one reserved wager per bettor, delegates locking to BaseTable, then initializes one model chicken per locked wager.
- request_cross() and request_cash_out() are the intended shared-button entry points.
- Client requests contain no peer ID, tile, roll, or payout. The host derives the sender with multiplayer.get_remote_sender_id().
- The host validates running state and proximity before processing each action. It generates the random roll itself after validation.
- player_state_changed publishes authoritative per-player state for presentation listeners; clients accept host state only.
- round_finished reports the final payout map and wallet settlement result.
- The adapter settles only when every wagered participant has finished, using one gross return per locked wager ID.

## Departure and day-end policy

- A player leaving proximity after start is automatically resolved by the adapter.
- A disconnected player is detected from the host's updated Network roster and automatically resolved.
- If the player has reached Tile 1 or beyond, automatic resolution cashes out at their current tile multiplier.
- If the player has not reached Tile 1, their return is zero.
- Already failed or cashed-out players retain their existing result.
- Day-end cleanup uses the same automatic-resolution policy for every still-active chicken.
- The day coordinator must snapshot/check wallet quota before requesting timer-expiry cleanup.

## Physical presentation and remaining integration

- The physical lane, chicken visuals, button nodes and spawn markers remain editor-authored by the user.
- Wire the shared Cross button to request_cross() and shared Cash Out button to request_cash_out() through the existing Interactable/Focus framework.
- Client/server RPC behavior, replicated chicken transforms/animations, physical button wiring, and in-game visual verification remain follow-up work. This adapter currently replicates authoritative player-state data, not scene presentation.
