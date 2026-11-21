# Chicken Cross — Rules and Round-State Contract

Status: Initial rules/model slice implemented; Godot execution pending.

## Approved game rules

- Up to four joined players participate in one round.
- Every participant has one chicken on the same shared twelve-tile lane.
- Progress is individual: one player's movement never advances another chicken.
- A Cross action attempts exactly the next tile for the requesting player.
- The host rolls a fresh independent random value for each player's tile attempt.
- The tile's failure chance is checked on entry. A failed chicken is finished and its wager returns zero.
- A player may cash out after reaching tile 1 or later. Cash Out affects only that player's chicken.
- The round completes when every participant is either cashed_out or failed.
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

These values are approved by the user as the initial balancing curve. Keep them in chicken_cross_rules.gd, not duplicated in scene scripts.

## Folder layout

- `fowl-play/casino/` contains shared casino infrastructure such as `base_table.gd` and `shared_wallet.gd`.
- `fowl-play/casino/tables/chicken_cross/` contains Chicken Cross-specific rules, round state, future table adapter/configuration, and its local README.
- `fowl-play/tests/` contains automated tests, including the Chicken Cross rules test.

## Code responsibilities

- casino/tables/chicken_cross/chicken_cross_rules.gd: pure tuning lookup, failure evaluation and gross-return calculation.
- casino/tables/chicken_cross/chicken_cross_round.gd: scene/network-independent per-player progress and outcome state.
- tests/chicken_cross_rules_test.gd: deterministic tests using supplied rolls; production host code must generate a new random roll for every accepted player action.

The model accepts a roll as an argument so tests can be deterministic. It does not generate randomness itself and does not trust client-supplied rolls.

## Integration constraints

- The future table adapter must inherit/use the existing BaseTable lifecycle rather than duplicate it.
- Cross and Cash Out RPCs must derive the acting peer from multiplayer.get_remote_sender_id(); never accept a client-provided peer ID as authority.
- The host generates the random roll after validating the action and participant state.
- The adapter calls BaseTable.settle_round only after every participant is finished, passing one gross return per locked wager ID.
- The physical lane, chicken visuals, button nodes and spawn markers remain editor-authored by the user.

## Still to implement

- Networked Chicken Cross table adapter and per-player chicken presentation.
- Physical Cross/Cash Out button integration through the existing interaction framework.
- Departure/disconnect auto-resolution policy for a started Chicken Cross participant.
- Host/client multiplayer tests and in-game visual verification.
