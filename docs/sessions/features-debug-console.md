# Session memory: features/debug-console

Branch: features/debug-console
Goal: Establish the verified D0 foundation and the first playable M0 slice.
Status: IN PROGRESS
Last updated: 2026-11-15
Base docs: PROJECT_OVERVIEW.md, PROJECT_STATE.md

## Current state

- The active branch is features/debug-console.
- PROJECT_STATE.md now records the existing foundation scripts and project settings.
- PROJECT_OVERVIEW.md remains the active technical authority.
- PROJECT_GAMEPLAY_OVERVIEW.md is background/provisional design material.
- The active debug reference is docs/DEBUG.md.
- The development unlock phrase remains `ilovedebugging`; it is explicitly not a security secret.
- D0 headless checks pass with Godot 4.7.2.
- D0 provides tuning, collision constants, network bootstrap, DebugHub, and a headless test runner.
- The editor-built arena, player capsule, local movement, camera, and debug console are working in manual playtest.

## Exact next step

Implement and verify M0 network startup plus host/client player spawn and despawn, while retaining D0 checks for every later slice.

## Waiting on the user

- Verify whether the user wants the existing pre-branch worktree changes included in a later commit.
- Run the next host/client network playtest after spawn/despawn is implemented.

## Decisions made

| Decision | Why |
|---|---|
| PROJECT_GAMEPLAY_OVERVIEW.md is background material | The current technical scope postpones the casino/economy layer. |
| Use repository-relative project paths | Absolute paths were stale and machine-specific. |
| Use a feature branch for the D0/M0 slice | Keeps the documentation and foundation work isolated from unrelated branches. |
| Keep `ilovedebugging` as the development unlock phrase | This matches the existing tuning value; documentation now states that it is not secret and must be consumed by the console input layer. |
| D0 is the first implementation slice | Every later gameplay slice depends on visible, local, testable diagnostics. |
| The debug console is editor-built and local | The unlock detector lives in DebugHub; the UI is a scene instance in the test arena. |

## Open questions

- Skeleton authoring method.
- Dangling carried limbs.
- Punches against limp bodies.
- Impact/wall-slam feedback.
- Final lobby, nickname, and color flow.
- Per-bone masses.
- Whether and when to rebuild the casino/economy layer.

## Known bugs and gotchas

- D0 is verified by `fowl-play/tests/run_checks.ps1`; local movement and console behavior are manually verified.
- The current worktree had changes before this branch was created; do not discard them.

## Files touched

- `fowl-play/core/tuning.gd` — shared constants and debug limits.
- `fowl-play/core/layers.gd` — collision layers and correctly 1-based masks.
- `fowl-play/core/debug_hub.gd` — local logs, watches, commands, and category switches.
- `fowl-play/core/network.gd` — ENet bootstrap and RPC validation helper.
- `fowl-play/tests/d0_debug_hub_test.gd` — headless D0 registration and log test.
- `fowl-play/tests/run_checks.ps1` — Godot test runner.
- `fowl-play/player/player.gd` — local capsule movement and camera input.
- `fowl-play/player/player.tscn` — editor-built player capsule scene.
- `fowl-play/ui/debug_console.gd` — local console controller.
- `fowl-play/ui/debug_console.tscn` — editor-built console UI scene.
- `fowl-play/arena/test_arena.tscn` — editor-built test arena with player and console instances.
