# CLAUDE.md — Fowl Play

## 1. Project Identity

Fowl Play is a host-authoritative, 1–4 player multiplayer physics party game built with **Godot 4.7**, typed GDScript, Jolt Physics, and ENet.

Fowl Play is a first-person party game for four players who share one bank account and one very bad contract. One of you signed what looked like a free wings-for-life deal at a chicken-themed casino called The House — except the fine print means anyone who eats the wings is bound to the contract too, so sharing them with your friends dragged all four of you in without the rest of you ever signing anything. Now you've got a handful of in-game days to gamble your way to enough winnings to void the contract before it claims you for good. The catch: every bet comes out of the same shared wallet, so when a friend starts pushing their luck too far, you can grab them, punch them into a stunned heap, or drag them bodily away from the table — at your own risk, since hitting a friend costs the entire team too. It's built for small groups who want a short, loud, chaotic multiplayer session full of betrayal, bad decisions, and yelling at your friends to stop gambling. Players are characters in shared rooms. They are able to fight with quick punches, charged lunges and parries. A player who takes a charged hit goes **limp**: the body becomes a physics ragdoll that tumbles, can be picked up and carried by another player, thrown, and after a few seconds gets back up.

**Core objective:** Build a responsive multiplayer physics game where gameplay and ragdoll behavior remain consistent across the host and all connected clients.

The authoritative project specification is:

- `docs/PROJECT_OVERVIEW.md`

If this file and the project overview disagree, follow the overview unless the user explicitly changes the decision.

---

## 2. Rules of Authority

Follow these rules when working on the project.

### Decision classifications

The project overview uses three classifications:

- **DECIDED:** The user has approved this. Do not change it without permission.
- **RECOMMENDED:** The proposed default. Follow it unless there is a reason to reconsider.
- **OPEN:** Not decided. Ask the user before implementing it.

Never silently turn an OPEN question into a permanent design decision.

If a decision affects architecture, networking, physics, or existing contracts, explain the consequences and ask before proceeding.

### Source of truth

When information conflicts, use this priority:

1. The user's latest explicit instruction.
2. Existing project code and verified behavior.
3. `docs/PROJECT_OVERVIEW.md`.
4. `docs/PROJECT_STATE.md`.
5. Active branch session documentation.
6. Your own assumptions.

Never invent previous decisions or claim something works without verification.

---

## 3. Development Environment and Code Standards

- Engine: Godot 4.7.
- Language: GDScript only.
- Physics: Jolt Physics.
- Networking: ENet Multiplayer API.
- Rendering: Forward+.
- Target platform: Windows.
- Target hardware: Weak school laptops.

### GDScript rules

- Use explicit static types for variables, parameters, return values, and important intermediate values.
- Avoid unnecessary `:=` inference, especially when the inferred type may be ambiguous.
- Prefer readable, maintainable code over clever shortcuts.
- Use `@export` for appropriate editor-configurable properties.
- Use `@onready` for node references that require the scene tree.
- Avoid unnecessary node lookups in frequently executed code.
- Use signals for appropriate component communication.
- Avoid tightly coupling unrelated systems.
- Do not use raw keycodes for gameplay input. Use InputMap actions.
- Do not use `print()` in game code. Use `DebugHub`.

### Performance

Keep the project's performance targets in mind:

- Up to 4 players.
- Up to 70 awake rigid bodies.
- No unnecessary per-frame allocations.
- Avoid expensive operations in `_process()` and `_physics_process()`.
- Measure performance before introducing complicated optimizations.

Do not optimize based on assumptions. Profile or test first.

---

## 4. Architecture and Multiplayer Rules

The game is host-authoritative.

The host is responsible for validating and applying important gameplay decisions, including:

- Combat and hit detection.
- Limp and ragdoll simulation.
- Carrying and throwing.
- Props and their authoritative physics.
- Gameplay timers and cooldowns.

Player movement follows the recommended owner-authoritative approach, with host-side sanity checks, pending confirmation at the M3 networking gate.

### Networking requirements

- Clients send intents; they do not decide authoritative gameplay outcomes.
- Validate RPC senders and ownership.
- Validate distance, state, cooldowns, and other relevant conditions on the host.
- Never trust client-provided gameplay results.
- Replicate the results of validated actions.
- Use reliable delivery when an event must not be missed.
- Use appropriate snapshot/interpolation methods for continuous physics state.
- Do not reparent Player nodes. Their network paths must remain stable.
- Handle disconnects and forced state termination safely.

A multiplayer feature is not complete simply because it works in single-player.

Test important behavior with separate host and client instances.

---

## 5. Scene and Editor Ownership

**The user builds scene hierarchies and visual structures in the Godot editor.**

Claude Code must not generate meshes, skeletons, physical skeletons, collision structures, or complex node trees through scripts as a shortcut.

Instead, provide an **EDITOR TASK** with:

1. The exact scene or node to work on.
2. Exact editor menu paths.
3. Required properties and values.
4. The reason for those values.
5. The expected result.
6. Common mistakes and how to identify them.
7. A clear definition of when the task is complete.

For code changes, provide a **SCRIPT HANDOFF** explaining:

- Files created or modified.
- Their responsibilities.
- Important functions and properties.
- How the user can verify the result.

### Scene ownership protocol

- Never edit a scene while the user has it open in the editor.
- Announce when you need to edit a scene and wait until it is safe.
- Never invent `uid://` values.
- Small mechanical `.tscn` edits are allowed only when the user has closed the scene.
- Never overwrite editor work without permission.

Teach concepts when they first become relevant. Do not assume the user already understands every Godot feature.

Work one editor task or a small related group at a time, then wait for confirmation.

---

## 6. Debug Console Requirements

Every gameplay system must have useful debugging support.

The debug infrastructure is centralized through:

`core/debug_hub.gd`

Autoload name: `DebugHub`

Use its shared API:

- `DebugHub.log(category, message)`
- `DebugHub.warn(category, message)`
- `DebugHub.is_on(category)`
- `DebugHub.watch(name, getter)`
- `DebugHub.command(name, callable, help, host_only, cheat)`

### Logging

Log meaningful decision points:

1. A request is received.
2. A request is accepted or rejected, including the reason.
3. An authoritative state change occurs.
4. A replicated event is received.

Use consistent categories such as `net`, `combat`, `limp`, `carry`, `hands`, `interact`, and `props`.

Never log continuously inside per-frame or per-physics-tick functions. Use watches for frequently changing values.

Do not build expensive log messages unless the category is enabled.

### Watches and commands

- Add watches for important system-owned state.
- Provide useful debug commands for gameplay actions that can reasonably be tested independently.
- Do not create meaningless commands just to satisfy a checklist.
- Commands that change gameplay must use the same host-validation path as normal gameplay.
- Mark host-only and cheat commands correctly.
- Debug tools must never bypass normal gameplay authority.

The console UI is built by the user in the editor. New systems should register with `DebugHub`; they should not require modifications to the console itself.

Update `docs/DEBUG.md` whenever a system introduces or changes its debugging interface.

A completed development slice must include:
- Useful logs.
- Relevant watches.
- Appropriate test commands.
- A way to verify the system.
- Expected debug output for important playtest steps.

Debugging must not introduce gameplay side effects.

---

## 7. Testing and Verification

Do not claim that a feature works merely because the code was written.

Use the most appropriate verification method:

1. Static inspection and type checks.
2. Godot headless import and validation.
3. Automated tests.
4. Headless multiplayer tests where applicable.
5. Actual in-game testing by the user.

When testing with Godot:

- Use the project's configured Godot executable when available.
- Do not assume a particular machine-specific installation path.
- Re-run imports when new scripts or global classes are introduced.
- Check exit codes and relevant output.
- Report limitations of headless testing honestly.

Headless tests cannot replace actual gameplay verification for input, visuals, physics feel, or camera behavior.

When a feature needs user testing, provide exact steps and expected results.

---

## 8. Git Rules

The user controls repository history and remote operations.

Allowed:
- Inspect Git status, branches, history, and diffs.
- Create and edit project files.
- Run tests.
- Prepare changes for review.

Do not perform these without explicit permission:
- Push or force push.
- Reset or discard user changes.
- Delete branches.
- Run destructive cleanup commands.
- Delete the `.godot` directory.
- Overwrite uncommitted user work.
- Commit changes.

Use feature branches for development.

Before suggesting a commit:

1. Inspect the diff.
2. Check for unrelated modifications.
3. Verify the relevant tests.
4. Summarize the changes.
5. Suggest a commit message.

The user performs the commit and push.

---

## 9. Documentation Requirements

Documentation must remain consistent with the implementation.

Important project documentation:

- `docs/PROJECT_OVERVIEW.md` — vision, gameplay rules, architecture, decisions, and technical contracts.
- `docs/PROJECT_STATE.md` — current verified project status.
- `docs/DEBUG.md` — debugging categories, watches, commands, and expected output.
- `docs/sessions/_ACTIVE.md` — active development sessions.
- `docs/sessions/` — branch-specific working memory.

Update documentation after each completed development slice.

Distinguish verified behavior from assumptions and untested implementations.

Never document a feature as complete when it has only been implemented but not verified.

---

## 10. Session Continuity

Before starting development, follow the start-of-session procedure in:

[`SESSION_MEMORY_RULES.md`](SESSION_MEMORY_RULES.md)

These project instructions apply to any coding assistant, including Codex and Copilot. Start with [the active session index](docs/sessions/_ACTIVE.md); do not assume a branch from previous chat history.

At minimum:

1. Read the project instructions and relevant documentation.
2. Inspect the current Git branch and working tree.
3. Read the active session file.
4. Verify important claims against the actual code.
5. Give the user a concise recap of the current state.
6. Wait for the user's approval before continuing.

After completing a task or development slice:

- Update the relevant session file.
- Record decisions and their reasoning.
- Record bugs and known limitations.
- Record the exact next action.
- Update `PROJECT_STATE.md` when durable project status changes.

At the end of a session, leave enough information for another session or model to continue without relying on chat history.

Never store passwords, tokens, secrets, or unnecessary personal information in project documentation.

---

## 11. Development Workflow

Work incrementally.

For each development slice:

1. Identify the relevant requirements in `PROJECT_OVERVIEW.md`.
2. Inspect the existing implementation before modifying anything.
3. Identify dependencies and potential architectural consequences.
4. Ask about unresolved decisions that block implementation.
5. Explain the proposed approach.
6. Implement only the agreed scope.
7. Verify the implementation.
8. Update documentation and session memory.
9. Report what changed, what works, and what remains unverified.
10. Wait for the user's next instruction.

Do not implement several unrelated systems in one large change.

Do not introduce new frameworks, plugins, dependencies, or architectural patterns without explaining why they are necessary.

Prefer the simplest implementation that satisfies the project's actual requirements.

---

## 12. Communication

The user is actively learning Godot, physics, rigging, and multiplayer development.

Be a technical collaborator and teacher, not just a code generator.

- Explain unfamiliar concepts clearly.
- Give reasons behind important implementation choices.
- Be honest about mistakes and limitations.
- Do not hide uncertainty.
- Do not make silent architectural changes.
- Avoid unnecessary technical complexity.
- Keep explanations organized and practical.
- Give one manageable task at a time.

When something is wrong, explain what is wrong, why it happens, and how to fix it.

**The priority is a stable, understandable, maintainable Fowl Play — not simply producing code as quickly as possible.**
