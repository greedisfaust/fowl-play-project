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
| player | player/player.gd | movement state and local camera input |

## Watches

| Name | Source | Meaning |
|---|---|---|
| `player/<name>/speed_mps` | player/player.gd | Current capsule velocity magnitude. |
| `player/<name>/on_floor` | player/player.gd | Whether the capsule is grounded. |

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

## Playtest "what you should see" log

| Slice | Step | Expected console output |
|---|---|---|
| D0 | 1 | Headless check registers the built-in commands and a temporary watch. |
| D0 | 2 | Headless check records `net: D0 verification log` in the local ring buffer. |
| M0 | 1 | `player_status_Player` reports position, velocity, and grounded state. |
| M0 | 2 | The console opens after typing `ilovedebugging`; mouse input is released. |
| M0 | 3 | Escape closes the console and mouse capture returns. |
| M0 | 4 | `net: connect from peer 1` |
| M0 | 5 | `net: player 1 spawned` |
| M0 | 6 | `combat: jab request from peer 1 accepted` |
| M0 | 7 | `combat: hit applied to peer 2` |

## Notes

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
