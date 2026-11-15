## Debug Console rule (applies to every slice, no exceptions)

Purpose: the user must be able to open an in-game console and SEE that what we
just built is actually running.

### Infrastructure (build once as slice D0, then never bypass it)
- core/debug_hub.gd: autoload named DebugHub, no class_name, no UI dependency,
  works headless. It does nothing in release builds (active only when
  OS.is_debug_build() or the --debug-tools argument is present).
- API: DebugHub.log(category, message), DebugHub.warn(category, message),
  DebugHub.watch(name, getter: Callable), DebugHub.command(name, callable,
  help, host_only, cheat). Ring buffer of the last 500 lines. Per-category
  on/off. The log also echoes to the Output panel.
- Console UI is a scene built by the USER in the editor (give an EDITOR TASK
  card; never build the node tree in script). Its script builds its tabs only
  from the hub's registries: Log (category filter, clear, copy), Watch (live
  values), Commands (one button per registered command, with arguments).
  Adding a feature must never require editing the console.
- Opened by typing the word in DEBUG_CONSOLE_WORD (tuning file) with no visible
  hint: rolling key buffer, reset after 1 s idle, ignored while any text field
  has focus. Opening frees the mouse and locks player input; the game keeps
  running. Local only, never networked.

### Definition of Done for every slice
A slice is not done until all of these exist:
1. LOG every decision point of the new code, in the shape: request received
   (who, what), validated or rejected WITH the reason, state change applied,
   replicated event received on each client. Use a fixed category per system
   (net, combat, limp, carry, hands, interact, ...). New systems add a category
   to docs/DEBUG.md.
2. WATCH every piece of state the slice owns (timers, phase, holder id, etc).
3. COMMAND to trigger each new feature by hand (for example limp.knock <peer>).
   A command that changes game state must go through the same host-validated
   intent path as the real input. It must never mutate state locally. Mark
   host_only and cheat correctly.
4. Hot paths (per frame, per physics tick) never log. Use a watch instead. Do
   not build strings unless the category is on.
5. No raw print() in game code. Everything goes through DebugHub.
6. Debug code never changes gameplay: no side effects inside log arguments,
   and no logic may depend on the console.
7. The slice report lists the categories, watches and commands added, plus a
   "what you should see in the console" line per playtest step (for example:
   "tap Q: combat shows jab req accepted, then hit applied").
8. docs/DEBUG.md is updated.

Future cheats (end day, add money, knock players) plug in through
DebugHub.command only. Do not build economy cheats until the economy layer
exists.