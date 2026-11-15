# Fowl Play — Project State

**Status:** D0 debug infrastructure verified; M0 foundation is next.

## Last verified (2026-11-15)

- Current branch: `docs/reconcile-project-docs`.
- Godot 4.7 project: `fowl-play/`, using Jolt Physics, Forward+, and D3D12.
- `fowl-play/project.godot` contains the project settings, input actions, and four autoload entries.
- Foundation scripts exist in `fowl-play/core/`: `layers.gd`, `tuning.gd`, `network.gd`, and `debug_hub.gd`.
- The worktree contains pre-existing modifications plus the new uncommitted D0 files; it is not clean.
- D0 headless checks pass with Godot 4.7.2; no gameplay scenes or in-game debug-console scene exist yet.

## Milestone progress

| Milestone | Goal | Status |
|---|---|---|
| D0 Debug infrastructure | DebugHub, tuning debug values, local log buffer, watches, commands, D0 headless check | Verified: `fowl-play/tests/run_checks.ps1` passes |
| M0 Foundation | Project settings, layers, tuning, input map, networking autoload, test runner, arena, capsule movement, camera, spawn/despawn | Partial: D0 and project settings verified; scenes and player systems not started |
| M1 Interaction + one prop | Interactable component, focus/highlight, one USE device, one GRAB prop | Not started |
| M2 Hands | Scene-backed hand + finger scenes, first-person + world modes | Not started |
| M3 Networking slice 1 | Movement authority gate, roster, remote smoothing, intent RPC, validation helper | Not started |
| M4 Ragdoll spike | Skeleton, 11 physical bones, Jolt joints, sync measurements at 15/30/60 Hz | Not started |
| M5 Limp lifecycle | Knockdown → ground → recovery (G1–G3, G8) | Not started |
| M6 Carry and throw | Props and limp bodies, auto-fire throw, dangling limbs | Not started |
| M7 Combat | Jab/recoil, charged punch, lunge, parry outcomes | Not started |
| M8 Procedural legs | Cosmetic legs, zero network traffic | Not started |
| M9 Camera + owner view | Camera follow target, owner legs visibility | Not started |
| M10 Hardening | Cleanup matrix, weak-laptop budget, 4-player soak | Not started |

## Open decisions (from PROJECT_OVERVIEW.md §24)

1. Skeleton authoring: inspector vs one-time tool script.
2. Dangling limbs while carried.
3. Whether punches affect already-limp bodies.
4. Whether to include impact/wall-slam feedback.
5. Final lobby, nickname, and color flow.
6. Per-bone ragdoll masses (M4 spike).
7. Rebuilding the casino/economy layer, and when.

Late join is decided: allowed during the rest of a day, not during casino/elevator gameplay. Throw power is decided: fixed full power with auto-fire at one second.

## Known limitations

- No gameplay scenes or debug-console UI have been verified.
- The root and `docs/` debug references were previously inconsistent; `docs/DEBUG.md` is now the active reference.
- The gameplay loop overview is background design material, not the current technical authority.

## Next action

Begin M0 with the editor-owned test arena and player capsule scene; keep D0 as a prerequisite for every later slice.