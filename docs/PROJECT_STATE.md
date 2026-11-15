# Fowl Play — Project State

**Status:** D0 verified; M0 arena, player capsule, movement, and debug console are working.

## Last verified (2026-11-15)

- Current branch: `features/debug-console`.
- Godot 4.7 project: `fowl-play/`, using Jolt Physics, Forward+, and D3D12.
- `fowl-play/project.godot` contains the project settings, input actions, and four autoload entries.
- Foundation scripts exist in `fowl-play/core/`: `layers.gd`, `tuning.gd`, `network.gd`, and `debug_hub.gd`.
- The worktree contains uncommitted documentation, foundation, arena, player, and debug-console changes; it is not clean.
- D0 headless checks pass with Godot 4.7.2.
- Console command arguments are implemented and user-playtested. Player watch/command cleanup on scene-tree exit is headless verified, including rename, queued deletion, and replacement registration; network disconnect testing remains pending M0.
- Latest D0 rerun passes cleanly after removing an unused missing-script InputSetup autoload and fixing Windows process waiting/output capture in the test runner. Input actions remain defined in the project Input Map.
- The arena, player capsule, local movement, mouse look, jump, mouse capture, and debug console have been manually playtested.

## Milestone progress

| Milestone | Goal | Status |
|---|---|---|
| D0 Debug infrastructure | DebugHub, tuning debug values, local log buffer, watches, commands, D0 headless check | Verified: `fowl-play/tests/run_checks.ps1` passes |
| M0 Foundation | Project settings, layers, tuning, input map, networking autoload, test runner, arena, capsule movement, camera, spawn/despawn | Partial: arena, capsule movement, camera, and D0 verified; network spawn/despawn remains |
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

- Network roster, player spawn/despawn, and two-instance playtesting remain unverified.
- The root and `docs/` debug references were previously inconsistent; `docs/DEBUG.md` is now the active reference.
- The gameplay loop overview is background design material, not the current technical authority.

## Next action

Implement and verify M0 network startup plus host/client player spawn and despawn; keep D0 as a prerequisite for every later slice.
