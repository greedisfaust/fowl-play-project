# Betting Terminal Display

The reusable betting display is a presentation-only layer for the casino terminal. It uses the existing `BaseTable`, `CasinoWallet`, and `ScreenText` systems; it does not create a second wager ledger or mutate wallet funds.

## Files

- `fowl-play/casino/terminals/resources/betting_terminal_profile.gd`: Inspector-editable terminal identity, copy, wager limits, colors, and text layout.
- `fowl-play/casino/terminals/display/betting_terminal_display.gd`: renders the two-column display and listens for table/wallet changes.

## Setup (editor-authored terminal scene)

1. Add a Node named `BettingTerminalDisplay` under the terminal root (or another suitable controller node).
2. Attach `betting_terminal_display.gd`.
3. Assign the table's `BaseTable` node to **Table**.
4. Assign the existing screen's `ScreenText` node to **Screen Text**. Do not replace the WorldScreen or its SubViewport.
5. Create a new resource of type `BettingTerminalProfile` and assign it to **Profile**.
6. Adjust the profile's game title, description, wording, minimum/maximum wager, currency symbol, colors, and layout values in the Inspector.
7. The shared keypad controller should call `set_pending_wager_amount(amount)` whenever the shared pending amount changes.

## Behavior

- The pending amount is shown in green only when it is positive, at least the configured minimum, no greater than the configured maximum, and no greater than the current available shared-wallet balance. Otherwise it is red; insufficient funds use the profile's dedicated message.
- The configured table maximum is always displayed as the table's maximum, independently of the current wallet balance.
- Confirmed wagers are read from `BaseTable.get_round_wagers()`; only reserved and locked wagers appear.
- Wagers are grouped by peer and summed for the display. This keeps the display to one `[PLAYER] — [CONFIRMED WAGER]` row per bettor.
- Player count uses `BaseTable.get_participants()` and the table's configured capacity.
- The total reserved amount includes only reserved/locked wagers in this table's current round.
- Names are resolved from `Network.player_identities` when available, with a peer-number fallback.
- The two columns are rendered as paired rows with fixed character budgets from the profile. Long labels, player names, and messages are shortened within their own column instead of pushing the other column off-screen.
- The renderer does not use blank rows to position one column independently of the other. The longer column determines the number of displayed rows.
- Automatic scrolling is disabled for this fixed readout so newly appended rows cannot scroll the title and headings out of view.
- `ScreenText` fits the rendered font against both the configured line width and the actual text-surface height. The Inspector font size remains the design size, so refreshes do not progressively shrink the text.

## Important integration boundary

This slice does not yet implement the shared pending amount's multiplayer authority, keypad digit/function handling, or CONFIRM submission. It only accepts the pending amount from its future keypad/controller via `set_pending_wager_amount`. The actual confirmation must call the existing host-authoritative `BaseTable.join_table()` / `BaseTable.place_wager()` workflow, using the peer ID of the player who pressed CONFIRM. Do not call `CasinoWallet.reserve_wager()` directly from the terminal.

## Verification checklist

- [ ] Assign the three exported references in the terminal scene.
- [ ] Create and assign a profile resource; edit the copy and limits to confirm they are Inspector-configurable.
- [ ] Check pending amount below minimum: red.
- [ ] Check pending amount within limits and available balance: green.
- [ ] Check pending amount above maximum: red.
- [ ] Check pending amount above available shared funds: red with insufficient-funds message.
- [ ] Confirm one wager and verify one player row plus updated total.
- [ ] Confirm multiple wagers by one peer and verify they aggregate into one row.
- [ ] Withdraw an unstarted wager and verify the row and total update.
- [ ] Start a round and verify locked wagers remain visible.
- [ ] Verify long player names and status messages remain inside their own column.
- [ ] Verify the complete display remains within the screen at the configured viewport dimensions and with the maximum player count.
- [ ] Verify the same display refreshes on every multiplayer client after the presentation replication path is connected.

Godot runtime and multiplayer tests have not been run as part of this source-only implementation.
