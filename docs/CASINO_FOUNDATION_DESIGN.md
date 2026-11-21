# Casino Foundation Design

Status: APPROVED FOUNDATION CONTRACT — shared wallet and BaseTable controller implemented; the initial wallet/BaseTable checks were user-verified PASS before the latest policy additions.
Branch: `environment/world-building-and-gameplay-loop`
Last updated: 2026-11-21
Base commit: `75675cc31456c3b0d7b5bb365ec82fd81ced9a72`

## 1. Purpose

Build a reusable, host-authoritative casino framework for Fowl Play. The framework must let the project owner and groupmates create independent physical casino games without reimplementing wallet, wager attribution, multiplayer validation, round lifecycle, or reporting integration for every game.

The first complete game is Chicken Cross. It is the reference implementation used to validate the framework before the table-development guide is distributed.

This is a Godot 4.7 / typed GDScript project. The user and groupmates author physical scene hierarchies, meshes, collision shapes, and table layouts in the Godot editor. Shared scripts, tests, and documentation must follow repository conventions.

## 2. Audited project foundations

Verified in the current branch tree and source:

- Godot project: `fowl-play/`; engine configuration declares Godot 4.7, Forward+, and Jolt Physics.
- Baseline autoloads: `Layers`, `Tuning`, `Network`, and `DebugHub`. The casino foundation adds `CasinoWallet` as a fifth autoload.
- `Network` owns ENet peer/session state, host/client flags, player roster, player identities, RPC validation, and current gameplay network diagnostics.
- `PlayerIdentity` is a reusable peer-ID/nickname/color data model.
- `Interactable` is the existing interaction contract. It exposes availability checks and interaction signals; casino devices must use it rather than inventing a second focus/interaction system.
- `PhysicalUseButton` is a reusable physical button presentation component.
- `DebugHub` provides logs, watches, commands, and category toggles. New casino systems must integrate with it.
- Existing player nameplate/identity presentation exists; casino table nameplates may be separate world-space displays, but should use existing identity data.
- Existing tests use GDScript SceneTree test scripts and PowerShell runners. New tests should follow those patterns.
- No casino wallet, table, wager, progression, or roster service was found in the inspected project tree.

## 3. Core architecture principles

1. **One financial authority.** The host owns the shared wallet and all wager transactions.
2. **Intent, validation, result.** Clients request interactions or wager actions. The host validates sender, player identity, table state, proximity, capacity, available funds, and wager rules before changing authoritative state.
3. **Common backend, game-specific physical input.** All games use the same wallet/wager/settlement services, but they are not forced to use one physical terminal design.
4. **BaseTable is generic.** It manages shared table lifecycle and participant coordination; it does not implement Chicken Cross, Blackjack, Roulette, or any other game's rules.
5. **Game implementation owns its rules and presentation.** Each game supplies its gameplay logic, physical board, game-specific input adapter(s), and visual feedback.
6. **Editor-authored scenes.** Do not generate physical table hierarchies, meshes, collision, or nameplate geometry in code.
7. **Debuggable and testable.** Every new system adds DebugHub watches/commands/logging and automated tests for its contracts.
8. **No premature global singleton sprawl.** Start with small services with clear ownership; add autoloads only when lifetime and access needs justify them.

## 4. Proposed system boundaries

### CasinoManager (later phase)

Responsibilities:
- Hold the registered game definitions/resources.
- Validate game IDs and registration.
- Select exactly six unique game types from the twelve-game roster each casino day.
- Give every registered game equal selection probability.
- Permit the same game to appear on consecutive days.
- Ensure no game type is selected twice on the same day.
- Keep all twelve games eligible from Day 1.

CasinoManager does not own wager settlement or individual game rules.

### BaseTable

Responsibilities:
- Expose stable table identity and game identity.
- Own table state: `IDLE`, `OPEN`, `RUNNING`, `RESOLVING`, and `CLOSED` (exact enum names may be adjusted during implementation).
- Track players in interaction/proximity range and current participants.
- Enforce per-game participant capacity (likely 2 or 4; configured per game).
- Coordinate open-round, join, withdraw, start, and resolution transitions.
- Permit any eligible player to open/start a round; the starter need not have a wager.
- Close betting and lock wagers at round start.
- Manage the agreed 45-second open-round inactivity timeout.
- Publish participant/nameplate state for all peers.
- Ask the game implementation to resolve/auto-handle participants who leave after a round starts.
- Expose lifecycle signals/API to game logic and betting adapters.

Implementation note (2026-11-21): `fowl-play/casino/base_table.gd` now provides the first script-only lifecycle controller. It delegates money operations to `CasinoWallet`, exposes host-side proximity hooks, tracks participants, enforces capacity and wager ownership, locks wagers at start, and signals post-start departures to the game layer. See `docs/CASINO_BASE_TABLE.md`. Automated tests are authored but not yet executed in Godot.

BaseTable must not:
- Know how Roulette chip positions work.
- Know Chicken Cross lane/step rules.
- Calculate game-specific odds or payouts.
- Directly mutate the wallet.
- Trust client-submitted round outcomes.

### Game implementation (per game)

Each game owns:
- Game-specific rules and state.
- Physical game board and presentation.
- Game-specific participant capacity.
- One or more betting input adapters.
- Validation of game-specific bet payloads (e.g. selected Roulette number/color/position).
- Player decision logic and auto-play behavior after start when applicable.
- Outcome generation on the host.
- A normalized settlement result sent to the shared settlement service.
- Game-specific statistics/events.

A game may use a keypad, chip placement, dedicated buttons, cards, a wheel interface, or multiple input methods. Roulette is the explicit example: placing chips on betting positions is different from entering a cash amount. Do not force it into a generic numeric keypad.

### Betting input adapter (proposed contract)

A betting adapter translates physical/game-specific input into a normalized wager request. It does not own money.

Normalized wager data must distinguish:
- player/peer ID (derived and validated by host, never trusted from client payload),
- table ID,
- round ID,
- stake amount,
- game-specific bet selection/payload,
- request sequence/idempotency key.

The host validates and records the wager. Game-specific payload validation remains with the game implementation.

### Shared wallet / wager / settlement services

Responsibilities:
- Maintain one shared team wallet for the run.
- Validate and serialize concurrent wager operations atomically on the host.
- Track every wager separately with unique wager ID, bettor peer ID, table/game ID, round ID, stake, time/sequence, selected bet payload, status, and final result.
- Support edit, withdrawal, proximity revocation, lock, refund, and settlement operations with idempotent transaction IDs.
- Record player-attributed stats for Daily Reports.
- Apply compatible Blessed/Watched modifiers through explicit, inspectable settlement inputs.

A table or game must never directly write a wallet balance. All wallet changes go through one transaction API.

## 5. Standard round lifecycle

Proposed common lifecycle:

1. `IDLE`: no open round; table available.
2. `OPEN`: any player opens a round; players may join and submit/edit/withdraw wagers.
3. `STARTING`: host validates the start request and atomically locks accepted wagers; no more joins or edits.
4. `RUNNING`: game-specific rules execute. If a participant leaves, the game applies its own agreed auto-play/auto-resolution behavior.
5. `RESOLVING`: host finalizes game outcomes and creates settlement instructions.
6. `SETTLED`: shared service applies results and records stats; table returns to `IDLE`.

The exact state set may be simplified during implementation, but every transition must be explicit and host-authoritative.

### Participation and withdrawal

- Participant limit is per game, likely two or four.
- Nameplates show identity and useful status (joined, wager pending/confirmed, withdrawn, playing, resolved); exact visual design is authored per table.
- Players may modify their wager before the round starts.
- Players may manually withdraw before the round starts.
- Leaving the table's proximity before round start revokes/refunds that player's open-round wager.
- Any player may start the round, whether or not they wagered.
- After start, a leaving/disconnecting participant must not strand an active wager. The game defines auto-play/auto-resolution behavior.

### Inactivity

- Target timeout: 45 seconds for an open round.
- Exact definition of meaningful activity and timeout refund/cancel details must be agreed before implementation.
- A timeout must never silently leave funds stranded.

## 6. Betting and physical interfaces

The backend is common; physical input is pluggable.

Examples:
- Chicken Cross: keypad-style numeric terminal may be suitable.
- Blackjack: keypad or game-specific betting interface, with individual hands/wagers.
- Roulette: physical chip-placement zones and a separate cash/buy-in or stake interface; multiple independent bet selections may be placed for one spin.

A game may have a primary and secondary terminal if it supports multiple participants. Terminal count and purpose are game configuration, not a hardcoded global assumption.

The existing shared terminal concept (numeric keys, MIN, ¼, ½, MAX, delete, clear, confirm) is a candidate adapter for games that use amount-entry. Roulette is not required to use it.

## 7. Financial rules and day boundary

### Shared wallet

- One shared team wallet; no per-player balances.
- Individual bettor attribution for every confirmed wager.
- Host-side atomic validation prevents concurrent confirmations from overspending the wallet.
- **DECIDED:** confirming a wager immediately reserves its stake from available funds.
- **DECIDED:** editing an open wager reserves or returns only the difference; withdrawing an open wager returns the full current stake.
- **DECIDED:** starting a round locks all reserved wagers. Locked wagers cannot be edited or withdrawn.
- **DECIDED:** settlement credits gross return (stake plus winnings); a loss returns zero.
- **DECIDED:** cancelling an unstarted round refunds all still-reserved wagers. Timer expiry does not refund locked wagers.
- Wager operations are synchronous and atomic on the host's main thread. Future RPCs must submit intents to the host; clients do not mutate an authoritative local wallet.
- Initial implementation lives in `fowl-play/casino/shared_wallet.gd` and is registered as the `CasinoWallet` autoload. Its headless test is `fowl-play/tests/casino_wallet_test.gd`.

### Casino timer expiry

User decision:
- Five-minute casino timer expiry is a hard deadline.
- Active/unresolved wagers are **not refunded** merely because the timer expires.
- Quota is checked at the deadline using the authoritative wallet state.
- Money committed to an unresolved wager can therefore leave the team below quota and cause failure, even if the wager might otherwise have won.
- The House may comment on this greed-driven failure in its announcement/report.

DECIDED: the day manager snapshots wallet/quota at the hard deadline first, then requests cleanup. Open rounds are refunded; started rounds keep locked stakes and auto-resolve/settle for clean shutdown. Post-deadline settlement cannot change the recorded quota result.

### Early departure

User decision:
- Once quota is reached (green), the team may end the day early.
- When leaving for the elevator, unresolved table wagers are force-refunded rather than allowed to strand a round.

DECIDED: only unstarted rounds are refunded. Started rounds are automatically resolved without refund before transition.

## 8. Daily roster and progression rules

- 12 game types in the roster.
- Exactly six unique game types selected each day.
- All 12 available from Day 1.
- Equal probability for every eligible game.
- Consecutive-day repeats allowed.
- No duplicate game type within a day.
- Six physical table locations in the casino.
- Day progression is ten days; old GDD numeric quota values are historical and not approved as current tuning.
- The one-time House continuation is consumed on the first failed quota of a run. The House loan equals 50% of the failed day's initial wallet and is added to the remaining wallet.
- A later failed quota ends the run.
- Day 10 failure repeats Day 10 if the one-time continuation is still unused; if already consumed, the run ends. There is no Day 11.

## 9. Blessing and Watched systems

- At the start of each day, select one Blessed player and a different Watched player.
- Announce both publicly during the elevator black-screen transition: Blessed first (Lady Clucktoria), then Watched (the House's gaze), before fade-out.
- Effects reset at the next day and new players/effects are selected.
- Blessed selection may repeat a previous day's target; weighting should increasingly favor players who have not been Blessed recently.
- Watched selection must exclude the previous day's Watched player.
- Effects are visible before players confirm wagers.
- Effects should be table/game compatible, never secretly manipulate underlying odds, and have capped loss penalties.
- One modifier per selected player per day; exact modifier pools and probabilities are future balancing work.

## 10. Disconnect and AFK requirements (not yet specified)

- If the host leaves, the current intent is to end the session and disconnect/kick everyone; host migration is not planned.
- If a client disconnects during a casino day, cleanup and wager handling remain undecided. This needs an explicit design gate before casino progression goes live.
- A returning player may spawn at the elevator; restoring their previous in-flight wager state is not required by the current concept, but exact rejoin/run continuity remains open.
- A rare AFK timeout around 30 minutes followed by a comedic explosion/kick is an idea only, not an approved implementation contract.

## 11. Daily report integration

The shared wager/statistics layer should emit normalized events so reports do not need to inspect individual game internals.

Expected report data includes:
- Daily financial overview and quota status.
- Per-player net contribution line graph, presented as a completed day summary.
- Individual statistics and game-specific highlights.
- House commentary addressing players individually.
- Next-day quota, wallet, and available tables.
- Separate Day 10 final report/contract resolution.

Statistics must come from actual events, not fabricated or inferred behavior.

## 12. Recommended first implementation slices

1. **Foundation integration audit** (this phase): inspect current player identity, interaction, network authority, debug, test, and scene conventions.
2. **Casino data contracts**: typed table/game definitions, round state, participant, wager, and settlement result data. No scene authoring.
3. **Wallet transaction service**: host-authoritative shared wallet with atomic reserve/commit/refund/settlement behavior and headless tests.
4. **BaseTable controller**: table lifecycle, participant/proximity, nameplate data model, timeout, and round transitions.
5. **Betting adapter API**: keypad and chip-placement interfaces feed the same normalized wager contract.
6. **Chicken Cross reference game**: first complete game and integration test.
7. **Groupmate kit**: template scene/script, `CASINO_TABLE_DEVELOPMENT_GUIDE.md`, submission checklist, and example.
8. **CasinoManager roster**: six unique games selected equally from registered game definitions.

Do not implement every service at once. Build and test a vertical slice, then extend the contract only when Chicken Cross demonstrates the need.

## 13. Non-goals for the first slice

- No implementation of all twelve games.
- No final quota tuning or old GDD table import.
- No full casino environment scene.
- No Rest Area, apartment, elevator, or Day 10 cinematic implementation.
- No forced common betting terminal.
- No hidden manipulation of game odds.
- No groupmate template distribution until Chicken Cross validates the contract.
- No scene-tree generation or procedural mesh construction in scripts.

## 14. First design gates before code

The following must be resolved or deliberately isolated behind configurable policy before their dependent code is written:

1. Wager money timing is DECIDED: confirmation immediately reserves the stake; edits reserve/return the difference; withdrawal refunds while open; start locks; settlement credits gross return.
2. Early-exit refund scope for already-started rounds.
3. Timer-expiry post-deadline handling of visual/game simulation after the quota check.
4. Exact 45-second timeout activity definition and cancellation/refund behavior.
5. Whether the initial framework supports one active round per table only (recommended) or concurrent rounds.
6. Whether multiple betting adapters can submit different bet payload types to the same round (recommended yes).
7. Whether game-specific modifiers are calculated before or after base payout; settlement ordering must be deterministic.

Recommended default for the first vertical slice: one active round per table; one normalized wager record per player per round unless a game explicitly opts into multiple distinct wagers; all balance changes through an atomic host transaction API; adapter payload is game-defined but schema-versioned. The wallet ledger currently permits multiple distinct wager records per bettor per round so games such as Roulette can add multiple selections; the game/table contract will decide whether to restrict that.
