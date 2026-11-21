# Betting Keypad Workflow

The physical keypad now drives the shared pending wager and submits confirmed bets through the existing host-authoritative `BaseTable` and `CasinoWallet` workflow. The display also reports live terminal proximity occupancy, colors confirmed player rows using each player's identity color, and supports 64-bit wager amounts.

## Implementation

- `fowl-play/casino/terminals/components/terminal_button.gd` emits `button_activated(button_id, peer_id)` on the authority. The peer ID comes from the interacting player, not from the button caller's choice.
- `fowl-play/casino/terminals/components/betting_keypad_controller.gd` owns the shared pending amount, digit editing, confirmation validation, and multiplayer snapshot replication.
- `fowl-play/casino/terminals/display/betting_terminal_display.gd` can render the host-published participant, wager, and wallet snapshot on clients.
- `fowl-play/casino/tables/chicken_cross/chicken_cross_table.gd` adds the controller beneath the existing `BettingKeypad` instance at runtime. The editor-authored keypad scene and its meshes/collisions are not modified.

## Button IDs

Set each physical TerminalButton's **Button Id** in the Inspector to one of these values:

| Key | Button Id |
|---|---|
| Number keys | `0` through `9` |
| Confirm | `CONFIRM` |
| Clear | `CLEAR` |
| Backspace | `BACKSPACE` |

If **Button Id** is blank, the controller uses the physical button's **Display Text** as its ID. It also accepts common aliases such as `ENTER`, `OK`, `CLR`, `RESET`, `C`, `DELETE`, and `BKSP`. Numeric prefixes such as `DIGIT_1`, `NUM_1`, `NUMPAD_1`, `NUMBER_1`, and `KEY_1` are accepted too.

## Player workflow

1. Any nearby player may press number keys. Every digit edits the same host-owned pending amount and the amount is broadcast to all clients.
2. CLEAR resets the pending amount to zero. BACKSPACE removes its final digit.
3. Any nearby player may press CONFIRM. The host validates the configured minimum/maximum and current available shared-wallet funds.
4. If the table is idle, the first successful confirmation opens its round. The confirmer is joined as a participant and becomes the bettor recorded by `BaseTable.place_wager(peer_id, amount)`.
5. A successful confirmation reserves funds through BaseTable's existing wallet workflow and resets the shared pending amount to zero. A rejected confirmation leaves the pending amount intact.
6. For Chicken Cross, one active wager per player is enforced because `ChickenCrossTable.start_round()` requires exactly one active wager for each bettor. The controller option is configurable for other games.

The keypad does not call `CasinoWallet.reserve_wager()` directly. It does not start the game round; the existing game start interaction remains responsible for that.

## Multiplayer authority and readout replication

- The host is the only peer that processes physical button actions and changes the pending amount.
- The actor's peer ID is captured from the server-side interaction actor. A client cannot submit a wager on behalf of another peer.
- The host broadcasts a revisioned snapshot containing the pending amount, table participants, current-round wagers, available shared-wallet balance, and the peer IDs currently inside terminal proximity.
- The terminal occupancy line reports `nearby players / terminal capacity` and updates as players enter or leave the terminal's proximity. This is distinct from the participant list, which tracks players who have joined the active round.
- Each confirmed player's wager row uses that player's `PlayerIdentity` color from the network identity roster.
- Clients render that snapshot through `BettingTerminalDisplay.set_network_snapshot()`; clients do not mutate their local wallet or table ledger.
- A newly initialized client requests the current snapshot from the host.
- The existing table proximity check still applies. A player must be registered inside the table's proximity area to open/join/confirm.

## Debug watches

The controller registers these DebugHub watches under `casino_keypad/<table_id>/`:

- `pending_amount`
- `snapshot_revision`
- `connected_buttons`
- `last_confirmation`

Existing wallet commands remain available:

- `casino_wallet_status`
- `casino_wallet_wagers`
- `net_status`

## Verification

Headless test:

```powershell
godot --headless --path fowl-play --script res://tests/betting_keypad_test.gd
```

The test covers digit composition, backspace, clear, below-minimum/above-maximum/insufficient-funds rejection, automatic round opening, bettor attribution, successful reservation/reset, a second player's confirmation, duplicate-wager rejection, live proximity occupancy, and values through the signed 64-bit limit. Display formatting includes B (billion), T (trillion), Qa (quadrillion), and Qi (quintillion).

### Two-instance multiplayer checklist

- [ ] Start one host and one client.
- [ ] Move both players into the Chicken Cross table's proximity.
- [ ] Host presses `1`; client sees the pending amount change.
- [ ] Client presses `0`; both screens show `10`.
- [ ] Client presses CLEAR, then enters a valid amount.
- [ ] Client presses CONFIRM; the wager is attributed to the client peer ID on the host.
- [ ] Both screens show the same player count, confirmed wager row, total reserved, and available-funds validity.
- [ ] Host edits the shared pending amount; client sees it immediately.
- [ ] Host confirms a second player's wager; both clients see the new row.
- [ ] The successful confirmation resets the pending amount to zero on every peer.
- [ ] Attempt a second active Chicken Cross wager from the same player; it is rejected without reserving more funds.
- [ ] Confirm a player outside proximity cannot open/join/confirm the table.

Godot runtime and multi-instance network verification have not been run from the assistant environment. The project owner should run the headless test and the two-instance checklist in the local Godot build.
