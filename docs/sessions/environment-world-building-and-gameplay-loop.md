# Session memory: environment/world-building-and-gameplay-loop

Branch: `environment/world-building-and-gameplay-loop`
Goal: Establish the casino/world gameplay foundation and a reusable table framework, beginning with Chicken Cross as the reference game.
Status: IN PROGRESS
Last updated: 2026-11-21 by GPT-6 (session 1)
Base: merged main commit `75675cc31456c3b0d7b5bb365ec82fd81ced9a72`
Base docs: `CLAUDE.md`, `SESSION_MEMORY_RULES.md`, `docs/PROJECT_OVERVIEW.md`, `docs/PROJECT_STATE.md`

## Current state (rewrite every session)

- The branch exists and was verified at `75675cc31456c3b0d7b5bb365ec82fd81ced9a72`, matching the merged main baseline at the time of audit.
- The shared wallet/wager ledger has been added; no BaseTable, game rules, or casino physical scenes have been added yet.
- The project is Godot 4.7, typed GDScript, Jolt, ENet, max four players; `fowl-play/` is the Godot project.
- Existing reusable foundations include `Interactable` / `Focus`, `Network`, `PlayerIdentity`, `DebugHub`, and the current player/nameplate presentation.
- The user's editor-authored scenes remain user-owned. Do not generate scene trees, meshes, collision shapes, or physical table art in code.
- Phase 0 repository audit and architecture specification are complete. The first shared financial service slice is implemented; BaseTable/game implementation is not started.

## Done (this branch)

- [DONE] Verified branch existence and base commit against GitHub ref API — branch head `75675cc31456c3b0d7b5bb365ec82fd81ced9a72`.
- [DONE] Read project instructions, session-memory rules, project overview/state, gameplay overview, active session index, GDScript rules, and relevant interaction/network/debug scripts.
- [DONE] Confirmed existing interaction contract: `fowl-play/interaction/interactable.gd`; physical button presentation: `fowl-play/interaction/physical_use_button.gd`.
- [DONE] Audited baseline autoloads `Layers`, `Tuning`, `Network`, and `DebugHub`; added `CasinoWallet` as the fifth autoload for the first casino service slice.
- [DONE] Captured user-approved casino design decisions below.

## In progress

- [DONE] Casino architecture specification — `docs/CASINO_FOUNDATION_DESIGN.md` records audited project seams, shared-service boundaries, BaseTable responsibilities, game-specific betting adapters, daily rules, and implementation sequence.
- [DONE] Wallet transaction policy gate — user approved immediate reservation on confirmation, editable/refundable while open, locked at round start, gross-return settlement, and no timer-expiry refund.
- [DONE] Shared wallet implementation — host-authoritative `CasinoWallet` autoload, per-wager attribution, round open/edit/withdraw/lock/cancel/settle lifecycle, DebugHub watches/commands, and headless test script added.
- [DONE] Authoritative project overview updated to include the approved casino foundation scope and wallet rules.
- [PARTIAL] Wallet test execution — test and runner stage are authored; Godot execution still needs to be run in the user's local environment.

## Exact next step

Pull the latest branch commit, then run both casino checks. Use `tests/run_casino_checks.bat` if PowerShell is unavailable. Report both results. If they pass, proceed to the Chicken Cross reference-game contract after reviewing any test failures or engine warnings.

## Waiting on the user

- No editor task currently. The user creates physical table scenes and node hierarchies in Godot.
- Ask only when a genuinely blocking design ambiguity is reached; otherwise use the approved decisions and mark proposals as recommendations.

## Decisions made (with why)

| # | Decision | Why | Alternatives rejected |
|---|---|---|---|
| 1 | Six physical casino table locations; exactly six unique game types selected daily from a 12-game roster. | Daily variety without duplicate games on one day. | Duplicate game types in a day. |
| 2 | All 12 games are available from Day 1; each has equal selection probability; consecutive-day repeats are allowed. | Simple transparent roster rotation. | Progressive unlocks or forced no-repeat rules. |
| 3 | Groupmates create their own physical table scenes. They duplicate a stable template and implement game-specific rules/presentation without editing shared framework files. | Parallel development with one shared contract. | Independent incompatible table frameworks. |
| 4 | Betting backend is shared, but physical betting interfaces are game-specific. Roulette may use chip placement and a distinct cash interface; keypad-style games may use a numeric terminal. | Preserve each game's physical interaction language while keeping money/wager rules consistent. | Force every game to use one physical terminal. |
| 5 | BaseTable owns common lifecycle, participation, proximity, round coordination, nameplate status, and inactivity. Game implementations own game rules, presentation, and betting interface. | Separate common table behavior from unique game mechanics. | A monolithic BaseTable containing every game's rules. |
| 6 | Shared wallet is host-authoritative; wagers have individual bettor attribution and unique records. Confirming a wager identifies its bettor. | Prevent client-side financial authority and preserve individual stats. | Client-trusted or anonymous aggregate bets. |
| 7 | Participants may edit wagers before round start, manually withdraw, or be removed/refunded when leaving the table's proximity before round start. | Flexible open betting without stale commitments. | Proximity-only withdrawal. |
| 8 | Any player may open/start a round; a player need not be a bettor to start it. Betting closes and accepted wagers lock at round start. | Avoid requiring a designated operator. | Automatic start on first bet or bettor-only start. |
| 9 | Game capacity is configured per game, likely two or four; nameplates visibly communicate player participation/status. | Different games need different player counts. | One global participant cap. |
| 10 | Open-round inactivity timeout target is 45 seconds. | Clear stale tables without waiting indefinitely. | Permanent stale rounds. Exact reset/refund behavior to be finalized in spec. |
| 11 | At casino timer expiry, unresolved active wagers are not refunded; quota is evaluated at the deadline, so money tied up in an unresolved wager can cause failure. | The deadline is consequential; greed can consume the team. | Automatic refund or extra time. |
| 12 | Early departure is allowed once the quota is reached (green); team can leave before five minutes. Unsettled table wagers are force-refunded when ending the day early. | Reward reaching quota while avoiding stranded rounds. | Must wait for timer after quota. |
| 13 | One player confirmation is sufficient for elevator/day transition. Carrying/ragdolling a player into the elevator counts them as present; players are reset/fixed during teleport to prevent physics bugs. | Preserve physical comedy while stabilizing transitions. | Require all four to press confirm. |
| 14 | Refusing players may be physically forced into the elevator using existing combat/carry/ragdoll mechanics. | Emergent social chaos. | Hard-lock or separate forced teleport rule. |
| 15 | First failed quota in a run consumes the one-time House continuation: loan equals 50% of that failed day's initial wallet, added to remaining wallet. Any later failed quota ends the run. | Give the team one learning/recovery opportunity. | Repeated loans or immediate first-failure Game Over. |
| 16 | Day 10 failure repeats Day 10 rather than creating Day 11, provided the one-time continuation remains unused; otherwise the run ends. | Ten-day contract has no eleventh day. | Extend the day counter past ten. |
| 17 | Daily report is a completed day summary with contribution line graph, individual stats, House commentary, and next-day information. Day 10 has a separate final report. | Make team performance legible and entertaining. | Live-updating report graph. |
| 18 | Rest Area is optional/social; no mandatory activities or hidden progression requirements. | Keep downtime relaxing. | Rest Area chores. |
| 19 | Daily Blessed and Watched roles are publicly announced during black-screen transition: Blessed first (Lady Clucktoria), then Watched (the House's gaze), before fade-out. | Shared teasing/rivalry and readable modifiers. | Secret/private effects. |
| 20 | Blessed target may repeat; selection weighting increasingly favors players not blessed recently. Watched target cannot be the previous day's Watched player. Targets must differ. | Variety and avoid consecutive-day curse targeting. | Same player cursed on consecutive days. |
| 21 | Blessings/curses are one compatible modifier per selected player per day, clear and reselect next day; effects are visible before wagers, do not secretly alter game odds, and loss penalties are capped. | Playful stakes without run-destroying or opaque manipulation. | Hidden odds manipulation or uncapped loss multipliers. |
| 22 | Apartment is host/join lobby, introduction space, and Day 10 return destination for both endings. | Circular narrative framing. | Apartment as casino gameplay room. |
| 23 | Confirming a wager immediately reserves its stake from the shared available balance; edits/withdrawals refund while open; round start locks it; settlement credits gross return; timer expiry never refunds locked stakes. | Prevent shared-wallet overspending and make the deadline meaningful. | Allow simultaneous unreserved spending or refund active bets at the deadline. |

## Open questions (do not decide alone)

- Exact scope of early-departure force-refund for already-started rounds (open rounds are refunded; locked rounds cannot use the open-round cancellation path).
- Exact settlement treatment for active rounds at timer expiry after the quota check; no refund is decided, but whether the visual game finishes after day closure is open.
- Whether early-departure force-refund includes already-started rounds or only unresolved/open wagers; user said force refund, confirm scope before implementation.
- Exact 45-second inactivity definition and whether timeout cancels/refunds all open wagers.
- Exact table interface contract and whether some games need multiple betting input adapters in one table.
- Exact max/min wager policy and whether global limits exist.
- Player disconnect during a casino day: cleanup/refund policy and whether day can continue are undecided.
- Host disconnect: current intent is session ends and everyone is kicked; exact graceful teardown is open.
- Rejoin: player spawns at elevator; prior wagers/state may not be restored. Exact identity/run continuity is open.
- AFK: rare 30-minute timeout followed by comedic explosion/kick is an idea, not yet a technical contract.
- Day 10 failure if continuation remains: repeat Day 10 with the one-time loan. If already consumed: run ends. Confirm the precise end-screen presentation later.
- Quota formula/table values are not finalized in the current conversation; old GDD numbers are historical, not approved.
- Exact game roster names/rules and game-specific participation limits remain to be designed one by one.
- Daily report screen layout, announcement count, and detailed stat schema remain open.

## Known bugs and gotchas

- Shared wallet implementation now exists; no BaseTable or casino physical scene implementation exists yet.
- Project overview now marks casino/economy foundation as active scope; do not revert it to the historical out-of-scope wording.
- Do not assume historical GDD values/rules are current.
- User owns scene construction. Never edit scenes open in the user's editor.
- Do not claim Godot tests or in-game verification unless actually run.
- User performs editor work and pulls/pushes; do not push. Follow repository authorization rules for commits.

## Files touched

- `docs/sessions/environment-world-building-and-gameplay-loop.md` — branch working memory.
- `docs/sessions/_ACTIVE.md` — active feature pointer.
- `docs/PROJECT_STATE.md` — durable active branch/status.
- `docs/CASINO_FOUNDATION_DESIGN.md` — architecture contract and implementation plan.
- `fowl-play/casino/shared_wallet.gd` — host-authoritative shared wallet and wager ledger.
- `fowl-play/tests/casino_wallet_test.gd` — headless wallet lifecycle regression test.
- `fowl-play/project.godot` — `CasinoWallet` autoload registration.
- `fowl-play/core/debug_hub.gd` — wallet diagnostics category.

## How to verify

- Verify branch head and changed paths through GitHub.
- User pulls the branch before local Godot work.
- The wallet test script and runner stage are committed, but have not been executed in this environment. User should run the `casino-wallet` stage locally before the next implementation slice.
- The committed `casino-wallet` headless test covers reservation, overspend rejection, edit, withdrawal, locking, gross-return settlement, loss settlement, open-round cancellation, and run reset. A separate multi-process host/client authority test remains required when client RPCs are introduced.

## Contracts to not break

- Host-authoritative multiplayer; clients submit intents, host validates and applies outcomes.
- Existing `Interactable` / `Focus` framework remains the only interaction system.
- Existing `Network` autoload owns ENet peer/session lifecycle.
- Existing `PlayerIdentity` is the source for player identity/nickname/color.
- `DebugHub` is the shared debug API; add watches, commands, and logs for new systems.
- Godot 4.7 typed GDScript only; no Python/C# gameplay.
- Physical scene construction remains editor-authored by the user/groupmates.

## Resume prompt

> Read `CLAUDE.md`, `SESSION_MEMORY_RULES.md`, `docs/PROJECT_OVERVIEW.md`, `docs/PROJECT_STATE.md`, and this session file. Verify the branch and files against GitHub and the local checkout. Recap in at most eight lines and wait for the user's go before implementing.

## Session log

### Session 1 update — 2026-11-21 — GPT-6
- User approved commits directly to the feature branch; no push is authorized or performed.
- User confirmed immediate wager reservation from the shared wallet; edits/withdrawals refund before round start, round start locks wagers, settlement credits gross returns, and timer expiry never refunds locked wagers.
- Added the `CasinoWallet` autoload, host-only wallet/wager ledger, DebugHub watches and commands, headless regression test, and `casino-wallet` test-runner stage.
- Updated project overview, casino design, project state, and active session documentation. Godot tests have not been executed in this environment.

### Session 1 update — 2026-11-21 — GPT-6
- User approved commits directly to the feature branch (no push).
- User confirmed immediate wager reservation from the shared wallet; edits/withdrawals refund before round start, round start locks wagers, and timer expiry never refunds locked wagers.
- Implemented `CasinoWallet` service and lifecycle test; added autoload, DebugHub diagnostics, test runner stage, and updated project/design/session docs.
- Tests are authored but not executed in this environment.

### Session 1 — 2026-11-21 — GPT-6
- Audited branch baseline, project instructions, state, interaction/network/debug foundations, and current project tree.
- Recorded current casino/world design decisions and open questions.
- Completed `docs/CASINO_FOUNDATION_DESIGN.md` and branch session/index/state documentation. No gameplay implementation yet.
- Next: confirm the wager reservation timing, update project scope authority, then build and test the wallet transaction service.
