# CasinoDayManager — Daily Wallet, Quota, and Timer

CasinoDayManager is an Autoload at /root/CasinoDayManager. It persists across world swaps and coordinates one casino day at a time. RunManager still owns the run/day progression phase; CasinoWallet still owns all money mutations.

## Ownership

- RunManager: starts a run, tracks the day/phase, and gates the Casino → Rest Area departure.
- CasinoWallet: authoritative shared wallet and wager ledger.
- CasinoDayManager: starting-wallet snapshot, dynamic quota, five-minute timer, early quota unlock, deadline result snapshot, and table cleanup request.
- BaseTable: owns each table's open/started round lifecycle and responds to day-end cleanup.
- ElevatorDepartureController: asks the day manager to complete an early casino departure after the physical elevator preparation sequence.

## Starting a run

RunManager.begin_new_run() initializes CasinoWallet to the starting run wallet of **1,000**. This happens once at the start of a fresh run, not at the beginning of every day.

When RunManager commits arrival into the Casino, CasinoDayManager reads the actual available shared wallet and starts that day. The full remaining wallet carries forward; the wallet is never reset to 1,000 between successful days.

## Dynamic quota formula

Let W be the shared wallet at the beginning of the current casino day and M be that day's additional multiplier:

    daily_quota = W + (W * 0.50) + (W * M)

Equivalent: W * (1.50 + M). The result is rounded up to a whole wallet unit.

| Day | Additional multiplier |
|---:|---:|
| 1 | 0.25 |
| 2 | 0.28 |
| 3 | 0.32 |
| 4 | 0.36 |
| 5 | 0.40 |
| 6 | 0.45 |
| 7 | 0.50 |
| 8 | 0.55 |
| 9 | 0.62 |
| 10 | 0.70 |

Example:

- Day 1 begins at 1,000: 1000 + 500 + 250 = **1,750**.
- The team finishes at 2,000. The whole 2,000 carries into Day 2.
- Day 2 begins at 2,000: 2000 + 1000 + 560 = **3,560**.

The quota is a threshold, not a cap. Reaching it unlocks early departure, but does not automatically end the casino day. The team may continue playing and earn more.

## Timer and deadline rules

- Each casino day starts with **300 seconds (five minutes)**.
- The host advances the timer and publishes its state to clients.
- When the available wallet first reaches the quota, the quota flag becomes true and RunManager unlocks Casino departure. The timer continues.
- At the hard deadline, the manager snapshots the available wallet and determines success/failure **before** asking tables to clean up.
- Reserved/locked wagers are excluded from available_balance. Therefore a locked unresolved wager can leave the team below quota at the deadline.
- After the snapshot, BaseTable.request_day_end_cleanup("casino_deadline") cancels/refunds unstarted rounds and asks started rounds to auto-resolve. Later settlements cannot change the already-recorded result.
- Early departure is accepted only after quota was reached. The elevator sequence calls finish_early_departure() once players are prepared; it requests table cleanup, snapshots the final wallet, records the result, and stops the timer.

A failed day still unlocks departure to the Rest Area so the next progression slice can apply the one-time House continuation/loan rules. The loan and run-ending policy are not implemented by this slice.

## BaseTable integration

BaseTable adds itself to the casino_tables group. The day manager uses that group for deadline and early-departure cleanup. No table scene hierarchy changes are required.

## DebugHub watches

- casino_day/active
- casino_day/day
- casino_day/starting_wallet
- casino_day/quota
- casino_day/wallet
- casino_day/seconds_remaining
- casino_day/quota_reached

## Tests

Run tests/run_casino_day_checks.bat. It checks the Day 1 and Day 2 examples, schedule bounds, early quota unlock without automatic day end, early departure result capture, and deadline failure at one unit below quota.

## Not included yet

- The six-of-twelve game selector. The repository currently implements Chicken Cross only; the full twelve-game catalog and its exact IDs must be registered before a real daily selection can be made.
- One-time House continuation/loan and terminal run outcomes.
- Casino screen/status UI displaying timer, wallet, quota, and selected games.
- End-to-end multiplayer verification of wallet replication and full casino-day gameplay.
