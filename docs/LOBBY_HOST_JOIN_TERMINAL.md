# Lobby Host / Join Terminal

## Scene wiring
The Apartment lobby uses `res://environment/terminals/lobby_host_join_terminal.tscn`. It reuses the placed Slim WorldScreen. The screen's `ScreenHit/Interactable` and the terminal's `ProximityArea` are wired to `LobbyHostJoinController`, which extends the existing `InteractiveTerminal` lifecycle. No separate physical buttons or alternate interaction system are used.

## Player flow
- Approach and interact with the screen to open HOST / JOIN / LEAVE.
- HOST starts the existing ENet host and displays detected LAN IPv4 addresses plus the configured port. Share an address with friends on the same reachable network.
- JOIN opens keyboard address entry. Enter confirms; Escape returns to the menu. A successful connection displays CONNECTED.
- LEAVE disconnects the local peer and returns that instance to its local Apartment. A host with connected clients receives a second confirmation because closing the host also disconnects every client. Clients independently return to their own Apartment after the host disconnects.
- A connection failure displays an error and allows returning to the menu.

## Controls
- Up / Down: select menu item.
- Enter: confirm.
- Escape: back/cancel.
- Mouse click: select a visible menu option.
- While entering an address: digits and periods, Backspace, Enter, Escape.

## Network behavior and limitations
The terminal calls the existing `Network.start_host()`, `Network.join_server(address)`, and `Network.shutdown()` APIs. It does not add a second networking layer. The host cannot migrate to another peer: if the host leaves, the session closes and connected clients are disconnected; each client then returns to its local Apartment. For internet play across different networks, the host may need router port forwarding or another network transport; the displayed LAN address is intended for reachable local networks.

## Verification
Run `tests/run_m3_lobby_host_join_checks.ps1` with the same Godot executable path used by the other M3 scripts. This headless contract test covers the menu options, JOIN address editing, cancellation, and local terminal session lifecycle. Multiplayer host/client behavior still requires a two-instance in-game check.

## Test status
The assistant environment does not have the project's Godot executable, so the headless Godot test and in-game multiplayer flow have not been executed here.
