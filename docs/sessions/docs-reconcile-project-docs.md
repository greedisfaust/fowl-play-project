# Session memory: docs/reconcile-project-docs

Branch: docs/reconcile-project-docs
Goal: Reconcile the Markdown documentation and establish the verified D0 foundation.
Status: IN PROGRESS
Last updated: 2026-11-15
Base docs: PROJECT_OVERVIEW.md, PROJECT_STATE.md

## Current state

- Documentation reconciliation is in progress on the feature branch.
- PROJECT_STATE.md now records the existing foundation scripts and project settings.
- PROJECT_OVERVIEW.md remains the active technical authority.
- PROJECT_GAMEPLAY_OVERVIEW.md is background/provisional design material.
- The active debug reference is docs/DEBUG.md.
- The development unlock phrase remains `ilovedebugging`; it is explicitly not a security secret.
- D0 headless checks pass with Godot 4.7.2.
- D0 provides tuning, collision constants, network bootstrap, DebugHub, and a headless test runner.

## Exact next step

Begin M0 with the editor-owned test arena and player capsule scene, while retaining D0 checks for every later slice.

## Waiting on the user

- Verify whether the user wants the existing pre-branch worktree changes included in a later commit.
- Complete the M0 editor task and report the resulting scene paths.

## Decisions made

| Decision | Why |
|---|---|
| PROJECT_GAMEPLAY_OVERVIEW.md is background material | The current technical scope postpones the casino/economy layer. |
| Use repository-relative project paths | Absolute paths were stale and machine-specific. |
| Use a feature branch for documentation reconciliation | Keeps the documentation correction isolated from the existing foundation changes. |
| Keep `ilovedebugging` as the development unlock phrase | This matches the existing tuning value; documentation now states that it is not secret and must be consumed by the console input layer. |
| D0 is the first implementation slice | Every later gameplay slice depends on visible, local, testable diagnostics. |

## Open questions

- Skeleton authoring method.
- Dangling carried limbs.
- Punches against limp bodies.
- Impact/wall-slam feedback.
- Final lobby, nickname, and color flow.
- Per-bone masses.
- Whether and when to rebuild the casino/economy layer.

## Known bugs and gotchas

- D0 is verified by `fowl-play/tests/run_checks.ps1`; gameplay scenes remain unverified.
- The current worktree had changes before this branch was created; do not discard them.

## Files touched

- `fowl-play/core/tuning.gd` — shared constants and debug limits.
- `fowl-play/core/layers.gd` — collision layers and correctly 1-based masks.
- `fowl-play/core/debug_hub.gd` — local logs, watches, commands, and category switches.
- `fowl-play/core/network.gd` — ENet bootstrap and RPC validation helper.
- `fowl-play/tests/d0_debug_hub_test.gd` — headless D0 registration and log test.
- `fowl-play/tests/run_checks.ps1` — Godot test runner.
