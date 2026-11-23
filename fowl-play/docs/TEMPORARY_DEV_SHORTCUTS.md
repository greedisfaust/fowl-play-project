# Temporary Development Shortcuts

> [!WARNING]
> TEMPORARY DEVELOPMENT-ONLY INPUT. REMOVE BEFORE RELEASE.

The Network autoload currently provides two keyboard shortcuts for quickly starting a local
multiplayer test session:

| Key | Action |
|---|---|
| H | Start hosting on the configured ENet port |
| J | Join `127.0.0.1` on the configured ENet port |

These shortcuts are handled by `Network._unhandled_key_input()`. They only run while no
network peer is active and no session switch is already in progress. They ignore key echoes
and modifier-key combinations, and only receive unhandled keyboard input so focused UI fields
can consume normal typing first.

## Local multiplayer test

1. Launch the game once and press **H**.
2. Launch a second game instance and press **J**.
3. The second instance joins the host through loopback (`127.0.0.1`).
4. Use the Debug Console command `net_status` or DebugHub watches `net/status` and
   `net/peers` to inspect the connection.
5. To start another test session, use `net_disconnect` or close the game instance.

The shortcuts reuse the existing `Network.start_host()`, `Network.join_server()`, and
session-switch workflow. They do not create a second networking implementation.

## Required cleanup before release

- [ ] Remove the temporary `H` / `J` key handler from `core/network.gd`.
- [ ] Remove this temporary-shortcuts document.
- [ ] Verify the production multiplayer menu is the only supported way to host or join.
- [ ] Search the project for `TEMPORARY DEVELOPMENT SHORTCUTS` and confirm no temporary
      session hotkeys remain.

**Do not forget this cleanup.** This item is intentionally recorded as a release task and
must be revisited when Fowl Play is considered feature-complete.
