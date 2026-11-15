# Fowl Play — Debug Console Reference

**Open:** type the secret word `ilovedebugging` (DEBUG_CONSOLE_WORD in tuning file). Local only. **THE SECRET WORD IS: ilovedebugging**

## Categories

| Category | Owner script | What it logs |
|---|---|---|
| net | core/network.gd | connect, disconnect, rejected RPCs |
| combat | core/combat.gd | punch, parry, lunge, hit, limb events |
| limp | core/limp.gd | limp start/end, recovery, phase changes |
| carry | core/carry.gd | pickup, carry, throw, drop, state |
| hands | core/hands.gd | reach, hover, guard, shake, color changes |
| legs | core/legs.gd | step, land, settle, air movement |
| props | core/props.gd | spawn, grab, throw, interact, state |
| net | core/network.gd | connect, disconnect, rejected RPCs |

## Watches

| Name | Source | Meaning |
|---|---|---|
| (empty for now) | | |

## Commands

| Name | Args | Host only | Cheat | What it does |
|---|---|---|---|---|
| (empty for now) | | | | |

## Playtest "what you should see" log

| Slice | Step | Expected console output |
|---|---|---|
| M0 | 1 | `net: connect from peer 1` |
| M0 | 2 | `net: player 1 spawned` |
| M0 | 3 | `combat: jab request from peer 1 accepted` |
| M0 | 4 | `combat: hit applied to peer 2` |
| M0 | 5 | `limp: started on peer 2` |
| M0 | 6 | `limp: recovery started on peer 2` |
| M0 | 7 | `limp: recovery finished on peer 2` |

## Notes

- The console is local only and never networked.
- The secret word `ilovedebugging` must not contain letters used by gameplay actions (W, A, S, D, E, Q, F), so typing it never moves, punches or parries.
- The console is built by the user in the editor. Claude Code gives an **EDITOR TASK** for it and never builds the node tree in script.
- New systems register with `DebugHub` and the console picks them up automatically.
- No logging in hot paths. No raw `print()`.
- All commands must go through the same host-validated intent path as real input.