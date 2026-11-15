# Debug Console rule

> **How to use this file**
> 1. Copy everything from "Debug Console rule (applies to every slice)" down to the end of "Definition of Done" into `CLAUDE.md`.
> 2. Add one line to `PROJECT_OVERVIEW.md` §4 or §21: *"Every slice must satisfy the Debug Console rule in CLAUDE.md."*
> 3. Give Claude Code the kickoff message at the bottom of this file.

---

## Debug Console rule (applies to every slice)

**Purpose:** the user must be able to open an in-game console and SEE that what we just built is actually running. If a feature is not visible in the console, it is not finished.

This rule has no exceptions. It applies to every slice, every bug fix that touches game logic, and every new system.

### 1. Infrastructure (build once as slice D0, then never bypass it)

**The hub: `core/debug_hub.gd`**
- Autoload named `DebugHub`. No `class_name` (autoload rule).
- No UI dependency. Works in headless tests.
- Active only when `OS.is_debug_build()` is true or the `--debug-tools` argument is present. In any other build every call is a no-op.
- Typed GDScript. No magic numbers: limits and the secret word live in the tuning file.

**Public API (names are fixed so every system uses the same calls):**

| Call | Meaning |
|---|---|
| `DebugHub.log(category: StringName, message: String)` | One line in the log buffer, also echoed to the Output panel |
| `DebugHub.warn(category: StringName, message: String)` | Same, flagged as a warning |
| `DebugHub.is_on(category: StringName) -> bool` | Cheap check, use it before building a message string |
| `DebugHub.watch(name: String, getter: Callable)` | Register a live value the console polls |
| `DebugHub.command(name: String, callable: Callable, help: String, host_only: bool, cheat: bool)` | Register an action the console can run |

- Ring buffer of the last 500 log lines. Per-category on/off switches.
- Every log line carries: time, peer id, category, message.
- The hub never sends anything over the network. It is local to each running instance.

**The console window**
- The scene is built by the **user in the editor**. Claude Code gives an **EDITOR TASK card** for it and **never builds the node tree in script** (Teaching Mode rule).
- Its script builds its content **only from the hub's registries**:
  - **Log tab:** category filter, clear, copy to clipboard.
  - **Watch tab:** live values, refreshed a few times per second.
  - **Commands tab:** one button per registered command, with argument fields. Cheat commands are visually marked.
- **Adding a feature must never require editing the console.** The feature registers itself with the hub and the console picks it up.

**How it opens**
- The user types a secret word on the keyboard. There is **no key label, no on-screen hint, no console prompt**.
- The word is `DEBUG_CONSOLE_WORD` in the tuning file. Default: `cuckoo`. It must not contain letters used by gameplay actions (W, A, S, D, E, Q, F), so typing it never moves, punches or parries.
- Detection: a rolling buffer of the last N typed letters, cleared after 1 second without a key. Ignored while any text field has focus (for example the nickname terminal).
- Typing the word again, or pressing Escape while the console is open, closes it.
- While open: the mouse is released and player input is locked. **The game keeps running** (no pause).
- The console is local only and never networked.

### 2. Rules for what gets logged

Log at **decision points**, not at every step:

1. **Request received:** who sent it, what it asks for.
2. **Validated or rejected:** if rejected, always include the **reason** (for example `rejected: sender 3 does not own node 2`).
3. **State change applied:** old value to new value.
4. **Replicated event received on a client.**

Format example:

```
DebugHub.log(&"combat", "jab request from peer %d accepted" % sender)
DebugHub.log(&"combat", "charged punch rejected: still on cooldown (%.2f s left)" % remaining)
```

- Use one fixed category per system: `net`, `combat`, `limp`, `carry`, `hands`, `interact`, `legs`, `props`, and so on. A new system adds its category to `docs/DEBUG.md`.
- **Hot paths** (anything per frame or per physics tick) **never log.** Show that state with a `watch` instead.
- Do not build message strings unless the category is on. Use `DebugHub.is_on()` when the message is expensive.
- **No raw `print()` in game code.** Everything goes through `DebugHub`.
- **Debug code never changes gameplay.** No side effects inside log arguments, and no game logic may depend on the console being open or closed.

### 3. Rules for commands (and future cheats)

- Every new feature gets at least one command that triggers it by hand, for example `limp.knock <peer>`, `parry.force`, `hands.reach`.
- A command that changes game state **must go through the same host-validated intent path as real input.** It must never change state locally on a client. On a LAN the host decides, even for the console.
- Set `host_only` and `cheat` correctly:
  - `host_only`: only runs on the host (or is forwarded to the host as a request).
  - `cheat`: breaks normal game rules (end day, add money, instant limp). Cheats exist only in debug builds.
- Future cheats (end day, add money, knock players) plug in **only** through `DebugHub.command`. Do not build economy cheats until the economy layer exists (PROJECT_OVERVIEW §2).

### 4. Definition of Done: debug requirements for every slice

A slice is **not done** until all of these exist:

1. **LOG** at every decision point of the new code (section 2).
2. **WATCH** for every piece of state the slice owns: timers, phase, holder id, cooldowns, counters.
3. **COMMAND** to trigger each new feature by hand (section 3).
4. No logging in hot paths. No raw `print()`.
5. A headless test or a recorded check that the new categories, watches and commands are registered.
6. **`docs/DEBUG.md` is updated** with the new categories, watches and commands.
7. The **slice report** lists:
   - the categories, watches and commands added;
   - for each playtest step, a **"what you should see in the console"** line.

   Example: *Playtest step 3, tap Q: console shows `combat: jab request from peer 2 accepted`, then `combat: hit applied to peer 1`.*

---


## `docs/DEBUG.md` starter

```
# Debug console reference

Open: type the secret word (DEBUG_CONSOLE_WORD in the tuning file). Local only.

## Categories
| Category | Owner script | What it logs |
|---|---|---|
| net | core/network.gd | connect, disconnect, rejected RPCs |

## Watches
| Name | Source | Meaning |
|---|---|---|

## Commands
| Name | Args | Host only | Cheat | What it does |
|---|---|---|---|---|

## Playtest "what you should see" log
| Slice | Step | Expected console output |
|---|---|---|
```
