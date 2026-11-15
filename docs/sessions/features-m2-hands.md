# Session memory: features/m2-hands

Branch: features/m2-hands
Goal: Build the scene-backed hand and finger components for first-person and world modes.
Status: IN PROGRESS
Last updated: 2026-11-16
Base docs: PROJECT_OVERVIEW.md, PROJECT_STATE.md

## Current state

- D0, M0, and M1 are verified.
- M1 created the interaction contract and reusable prop scene/profile.
- M2 has not yet added hand scenes or scripts.
- Hand geometry, finger hierarchy, and materials remain editor-owned.
- Networking of hand cosmetics remains deferred to M3.

## Exact next step

Create the typed hand controller API, then give the user one editor task for `finger.tscn` and the first `hand.tscn`.

## Waiting on the user

- M1 commit remains user-owned.
- After the hand scripts exist, build the hand/finger scene hierarchy in the Godot editor.

## Open questions

- Exact visual proportions and materials are editor choices within the API contract.
- First-person/world hand placement values should be tuned during the editor playtest.

## Contracts to not break

- Hands are scene-backed and never generated in code.
- Local first-person hands live on the camera; world hands live on the player head.
- Cosmetic replication is deferred to M3.

## Resume prompt

> Read CLAUDE.md, SESSION_MEMORY_RULES.md, docs/PROJECT_OVERVIEW.md, docs/PROJECT_STATE.md, docs/DEBUG.md, and this session file. Verify the branch and worktree. Implement the typed hand API without generating scene geometry in code.

## Session log

### Session 1 — 2026-11-16

- Did: closed M1 as user-verified and prepared the M2 hand slice.
- Stopped at: hand controller API and editor-owned scenes.
