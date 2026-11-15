# Fowl Play — Debug Console Reference

**Open:** type the development unlock phrase `ilovedebugging` (the
`DEBUG_CONSOLE_WORD` value). It is local-only development tooling, not a
security secret.

## Categories

| Category | Owner script | What it logs |
|---|---|---|
| net | core/network.gd | network startup, shutdown, rejected RPCs |
| combat | core/combat.gd | punch, parry, lunge, hit, limb events |
| limp | core/limp.gd | limp start/end, recovery, phase changes |
| carry | core/carry.gd | pickup, carry, throw, drop, state |
| hands | core/hands.gd | reach, hover, guard, shake, color changes |
| legs | core/legs.gd | step, land, settle, air movement |
| props | core/props.gd | spawn, grab, throw, interact, state |
| interact | player/focus.gd and interaction/interactable.gd | focus changes, accepted/rejected interaction requests |
| player | player/player.gd | movement state and local camera input |

## Watches

| Name | Source | Meaning |
|---|---|---|
| `player/<name>/speed_mps` | player/player.gd | Current capsule velocity magnitude. |
| `player/<name>/on_floor` | player/player.gd | Whether the capsule is grounded. |
| `net/status` | core/network.gd | offline, hosting, connecting, connected, disconnected, or failed. |
| `net/peers` | core/network.gd | Locally known connected peer IDs, including local ID once connected. |
| `net/player_count` | arena/test_arena.gd | Spawned players in this arena instance. |
| `interact/focused/<name>` | player/focus.gd | Prompt text for the local player's focused target, or blank. |
| `interact/device/<name>/active` | interaction/debug_use_device.gd | Toggle state of the M1 test USE device. |
| `props/<name>/pickup_allowed` | props/prop.gd | Whether the prop's assigned profile allows pickup. |

## Commands

Enter a command plus whitespace-separated arguments in the command bar, then press Enter or Run. For example: `debug_disable net`, followed by `debug_enable net`. Quoted arguments are not supported yet.

Results appear below the bar even when `net` logging is disabled. Unknown commands display an error; empty input displays a prompt. Existing command buttons also display results and copy their command name into the input field so arguments can be added.

Automated checks cover Enter/Run signal wiring, category toggles, feedback with logging disabled, whitespace, missing arguments, and unknown/empty commands. USER VERIFIED: command entry works in-game after the Enter/Run playtest handoff.

| Name | Args | Host only | Cheat | What it does |
|---|---|---|---|---|
| `debug_categories` | none | no | no | Lists registered categories and enabled state. |
| `debug_enable` | category | no | no | Enables a local debug category. |
| `debug_disable` | category | no | no | Disables a local debug category. |
| `debug_watches` | none | no | no | Lists registered watches and current values. |
| `player_status_<name>` | none | no | no | Reports one player's position, velocity, and grounded state. |
| `net_status` | none | no | no | Reports connection status, port, and known peers. |
| `net_host` | none | no | no | Starts hosting from offline/disconnected state. Removes the offline player before spawning the host. |
| `net_join` | optional IP | no | no | Joins an IP; defaults to 127.0.0.1. Example: `net_join 192.168.1.20`. |
| `net_disconnect` | none | no | no | Disconnects this instance and clears its players. On the host, ends the session for clients. Use net_host/net_join afterward. |
| `interact_use_<name>` | none | yes | no | Uses the local player's currently focused target through the normal validation path. |

## Playtest "what you should see" log

| Slice | Step | Expected console output |
|---|---|---|
| D0 | 1 | Headless check registers the built-in commands and a temporary watch. |
| D0 | 2 | Headless check records `net: D0 verification log` in the local ring buffer. |
| M0 | 1 | After arena script handoff, `player_status_1` reports the host/offline player's state. Client commands use their peer ID. |
| M0 | 2 | The console opens after typing `ilovedebugging`; mouse input is released. |
| M0 | 3 | Escape closes the console and mouse capture returns. |
| M0 | 4 | Host: `Host started on port 7777`; client: `Connected as peer <id>`. |
| M0 | 5 | Both: `Spawning player <id> in slot <slot>`; player count becomes 2. |
| M0 | 6 | Client leaves: host logs `Despawning player <id>`; player count becomes 1. |
| M0 | 7 | Host leaves: client logs `Host disconnected`; player count becomes 0. |
| M1 | 1 | Aim at the editor-authored device: `interact: Focused <prompt>` and the device receives a highlight overlay. |
| M1 | 2 | Press E or run `interact_use_<name>`: `interact: Interaction accepted: <prompt> action=use`, then `<device> active=true/false`. |
| M1 | 3 | Aim at the GRAB prop: `props/<name>/pickup_allowed=true`; press E and see `props: <name> grab accepted; carry is deferred to M6`. |

M0 launch arguments go after Godot's `--` separator: `--host` or `--join=127.0.0.1`; optional `--port=7777`. No arguments starts offline. Movement is local-only at this milestone; remote capsules remain at their spawn positions until M3.

Alternatively, start two ordinary game instances and enter `net_host` in the first console, then `net_join` in the second. Both should report net/player_count=2. To join another LAN computer, supply its IP. Commands reject invalid IPs without leaving the current session and reject host/join while already connected or connecting (use net_disconnect first). Startup is deferred until old player cleanup finishes; watch net/status for the actual outcome. Headless separate-process checks cover console-driven default/explicit loopback joins and disconnects; rendered console hosting/joining and visible capsules/counts are user-verified; manual disconnect cleanup is user-verified.

## Notes

- Command buttons live under `Window/Layout/Tabs/Commands/CommandList`, inside an editor-authored ScrollContainer (vertical auto scrolling, horizontal disabled, follow focus enabled). Old buttons detach before replacement so repeated registry refreshes do not temporarily inflate layout height. USER VERIFIED: overflow fix works after the resize/scroll playtest handoff.
- Players unregister their two watches and status command on scene-tree exit, using their original registration names even if renamed. Other systems can remove commands with `DebugHub.unregister_command(name)` and watches with `DebugHub.unwatch(name)`. Registry changes refresh the console automatically.
- D0 checks verify queued player deletion with the console present, another player's continued watch/command access, and registration of a replacement using the departed player's name. Network disconnect testing remains part of M0.
- With the console open, player movement and jump input are blocked while gravity and collision movement continue. USER VERIFIED: movement/jump blocked and speed increases while falling off the arena with the console open. Landing with the console open remains untested.
- Keep the unlock phrase and Escape controls; the user declined an F3 toggle.
- The console is local only and never networked.
- The unlock phrase overlaps gameplay letters; the console input layer must consume those keystrokes while recognizing the phrase.
- The console is built by the user in the editor. Claude Code gives an **EDITOR TASK** for it and never builds the node tree in script.
- New systems register with `DebugHub` and the console picks them up automatically.
- No logging in hot paths. No raw `print()`.
- All commands must go through the same host-validated intent path as real input.
