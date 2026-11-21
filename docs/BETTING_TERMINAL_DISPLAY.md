# Betting Terminal Display

The reusable betting display is a presentation-only layer for casino terminals. It uses the existing `BaseTable`, `CasinoWallet`, and `ScreenText` systems; it does not create a second wager ledger or mutate wallet funds.

## Files

- `fowl-play/casino/terminals/resources/betting_terminal_profile.gd`: Inspector-editable game identity, display copy, wager limits, colors, and column widths.
- `fowl-play/casino/terminals/display/betting_terminal_display.gd`: renders the display and listens for local table/wallet changes; accepts host-published snapshots on clients.
- `fowl-play/casino/terminals/components/betting_keypad_controller.gd`: shared keypad input, wager validation, confirmation, and snapshot replication.
- `fowl-play/casino/terminals/components/terminal_button.gd`: physical button presentation and authority-side actor attribution.
- `fowl-play/casino/base_table.gd`: publishes live terminal proximity occupancy.

## Scene setup

The Chicken Cross scene already contains the editor-authored `BettingTerminalDisplay`, `SlimWorldScreen`, and `BettingKeypad` nodes.

1. The `BettingTerminalDisplay` node belongs under the table root.
2. Assign its **Table** reference to the table's `BaseTable` node.
3. Assign **Screen Text** to `SlimWorldScreen/WorldScreen/SubViewport/ScreenText`.
4. Assign a `BettingTerminalProfile` resource to **Profile**.
5. Set the profile's game title, description, wording, minimum/maximum wager, currency symbol, colors, and column widths in the Inspector.
6. `ChickenCrossTable` adds `BettingKeypadController` under the existing `BettingKeypad` at runtime. No keypad scene hierarchy or mesh edits are required.

## Display behavior

- The pending amount is green only when it is positive, at least the configured minimum, no greater than the configured maximum, and no greater than the available shared-wallet balance. Otherwise it is red; insufficient funds use the profile's dedicated message.
- The configured table maximum is shown independently of the current wallet balance.
- Confirmed wagers come from the current table round and only reserved/locked wagers are displayed.
- Wagers are grouped by peer and summed to one `[PLAYER] — [CONFIRMED WAGER]` row per bettor.
- The occupancy line shows players currently inside the table's proximity area versus configured terminal capacity (for example, `2 / 4 PLAYERS`). It updates on every proximity enter/exit and includes players who have not yet confirmed a wager.
- Each confirmed player's wager row is tinted with that player's assigned `PlayerIdentity` color. The identity roster refreshes the readout when player colors or nicknames change.
- The total reserved value includes reserved/locked wagers in the current round.
- Player names use `Network.player_identities` when available, with a peer-number fallback.
- The two betting columns use native RichTextLabel table cells with separate left, divider, and right cells. The pending amount is centered and enlarged to 1.45 times the authored font size; its larger glyphs cannot push the right column out of position.
- The status and amount share one validity rule: positive, within the configured minimum/maximum, and affordable from the available shared wallet. Valid amounts are green; zero, out-of-range, and unaffordable amounts are red.
- Compact currency formatting supports the signed 64-bit integer range using K, M, B, T, Qa, and Qi denominations (thousand through quintillion). Confirmed wagers and reserved totals retain full-value formatting.
- The title is large, bold, and left-aligned in a full-width header area. The description is directly beneath it and capped at two lines. A divider separates the header from the betting columns.
- The first render is deferred until ScreenText completes its own initialization. Automatic scrolling is disabled for this fixed physical readout.

## Keypad and confirmation behavior

- Number buttons edit one shared pending amount. CLEAR resets it; BACKSPACE removes its final digit.
- Any nearby player may press CONFIRM. If the table is idle, the first successful confirmation opens the round. The confirmer is joined and becomes the bettor.
- The host validates the configured wager limits and available shared-wallet balance, then calls `BaseTable.place_wager(peer_id, amount)`.
- The host never calls `CasinoWallet.reserve_wager()` directly from the terminal. BaseTable and CasinoWallet remain the only wager-reservation path.
- A successful confirmation resets the shared pending amount to zero. Rejected confirmation preserves the amount.
- The keypad accepts up to 19 digits, with an exact guard against values above the signed 64-bit maximum. The wallet itself stores integer balances and stakes.
- Chicken Cross allows one active wager per participant; a duplicate confirmation from the same player is rejected because `ChickenCrossTable.start_round()` enforces one active wager per bettor.
- The full keypad workflow, button IDs, multiplayer snapshot behavior, and test checklist are documented in [BETTING_KEYPAD_WORKFLOW.md](BETTING_KEYPAD_WORKFLOW.md).

## Multiplayer readout

The host replicates the pending amount, table participants, current-round wagers, available wallet balance, and nearby peer IDs in a revisioned snapshot. Clients render this snapshot through `set_network_snapshot()`; they do not mutate their local table or wallet. Newly connected clients request the current snapshot from the host.

## Important integration boundary

This controller covers keypad digit entry, shared pending amount synchronization, confirmation, host-authoritative wager reservation, reset-on-success, and readout replication. Starting/locking the game round remains the responsibility of the game-specific start interaction. The controller is reusable; other game tables can add it at runtime and configure whether multiple active wagers per player are allowed.

## Verification

Run the casino checks from the project root with `tests/run_casino_checks.bat`, or run the keypad test directly:

```powershell
godot --headless --path fowl-play --script res://tests/betting_keypad_test.gd
```

The keypad regression test covers digit composition, backspace, clear, wager validity, automatic round opening, bettor attribution, reservation, successful reset, a second player's wager, duplicate-wager rejection, live proximity occupancy, identity colors, and signed 64-bit amount limits/denominations. See [BETTING_KEYPAD_WORKFLOW.md](BETTING_KEYPAD_WORKFLOW.md) for the two-instance multiplayer checklist.

Godot runtime and multiplayer tests have not been run from the assistant environment.
