# Chicken Cross — Rules and Round-State Contract

Status: Chicken Cross rules and table integration checks user-verified PASS. Physical button/proximity hookups are implemented in the table script; scene references and in-game multiplayer presentation verification remain pending.

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
- request_cross() and request_cash_out() remain available for direct local UI intents. Physical USE buttons connect through the exported `cross_interactable` and `cash_out_interactable` references; the host derives the acting peer from the validated actor's `input_peer_id`.
- Client requests contain no peer ID, tile, roll, or payout. The host derives the sender with multiplayer.get_remote_sender_id().
- The host validates running state and proximity before processing each action. It generates the random roll itself after validation.
- The exported `proximity_area` connects body-entered/exited events to BaseTable proximity tracking. Assign the table's Area3D in the Inspector.
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
- Assign the Cross button's Interactable to `cross_interactable`, the Cash Out button's Interactable to `cash_out_interactable`, and the lane/table proximity Area3D to `proximity_area` in the Inspector. Each button must be configured as USE or BOTH. Keep the existing Interactable/Focus/Network path; do not call the table from `interaction_requested`.
- Client/server RPC behavior, replicated chicken transforms/animations, and in-game visual verification remain follow-up work. This adapter currently replicates authoritative player-state data, not scene presentation.
