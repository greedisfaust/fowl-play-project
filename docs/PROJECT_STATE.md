# Fowl Play — Project State

**Status:** Foundation in place; no game code written yet.

## Last verified (2026-11-15)

- Godot 4.7 project initialized at `res://` (`fowl-play/`), Jolt Physics engine, Forward+ renderer, Windows target.
- `project.godot` configured: `config/name="fowl-play"`, features `4.7` + `Forward Plus`, Jolt 3D physics, D3D12 renderer.
- Git: clean on `main`, up to date with `origin/main`.
- Documentation: `CLAUDE.md`, `docs/PROJECT_OVERVIEW.md`, `docs/PROJECT_STATE.md` (this file), `docs/DEBUG.md`, `docs/GDSCRIPT_ONLY_RULES.md`, `docs/SESSION_MEMORY_RULES.md` all present.

## Milestone progress

| Milestone | Goal | Status |
|---|---|---|
| M0 Foundation | Project settings, layers, tuning, input map, networking autoload, test runner, arena, capsule movement, camera, spawn/despawn | Not started |
| M1 Interaction + one prop | Interactable component, focus/highlight, one USE device, one GRAB prop | Not started |
| M2 Hands | Scene-backed hand + finger scenes, first-person + world modes | Not started |
| M3 Networking slice 1 | Movement authority gate, roster, remote smoothing, intent RPC, validation helper | Not started |
| M4 Ragdoll spike | Skeleton, 11 physical bones, Jolt joints, sync approach (15/30/60 Hz measurement) | Not started |
| M5 Limp lifecycle | Knockdown → ground → recovery (G1–G3, G8) | Not started |
| M6 Carry and throw | Props and limp bodies, auto-fire throw, dangling limbs | Not started |
| M7 Combat | Jab/recoil, charged punch, lunge, parry outcomes | Not started |
| M8 Procedural legs | Cosmetic legs, zero network traffic | Not started |
| M9 Camera + owner view | Camera follow target, owner legs visibility | Not started |
| M10 Hardening | Cleanup matrix, weak-laptop budget, 4-player soak | Not started |

## Open decisions (from PROJECT_OVERVIEW.md §24)

1. Skeleton authoring: inspector vs one-time tool script.
2. Dangling limbs while carried (confirm).
3. Whether punches affect already-limp bodies.
4. Whether to include impact/wall-slam feedback.
5. Late join during play — DECIDED: allowed during rest of day only, not mid-casino.
6. Final lobby, nickname and color flow.
7. Fixed throw power vs variable-power option later.
8. Per-bone ragdoll masses (spike).
9. Rebuilding the casino/economy layer, and when.

## Known limitations

- `docs/PROJECT_STATE.md` was previously empty; this file establishes the baseline.
- No scenes, scripts, or autoloads exist yet in the Godot project.
- No headless tests exist yet.
- No debug console UI exists yet.

## Next action

Confirm the new vision/lore text for PROJECT_OVERVIEW.md §1, then begin M0 Foundation (tuning constants, layer constants, networking autoload, input map).