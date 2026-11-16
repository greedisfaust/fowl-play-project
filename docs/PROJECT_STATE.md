# Fowl Play — Project State

**Status:** D0, M0, and M1 interaction/prop slices verified. Console overflow fix user-playtested. M2 hands has started with the scene-backed hand API.

## Last verified (2026-11-16)

- Current branch: `features/multiplayer`.
- Godot 4.7 project: `fowl-play/`, using Jolt Physics, Forward+, and D3D12.
- `fowl-play/project.godot` contains the project settings, input actions, and four autoload entries.
- Foundation scripts exist in `fowl-play/core/`: `layers.gd`, `tuning.gd`, `network.gd`, and `debug_hub.gd`.
- Debug-console work is committed as `762c00f`; M0 is committed as `017f1cb`.
- D0, M1, M2 hand checks, and M0 network checks pass with Godot 4.7.2. Prop/profile and hand scripts import cleanly.
- Console command arguments are implemented and user-playtested. Player watch/command cleanup is headless verified, including network disconnects; manual disconnect checks are user-verified.
- Latest D0 rerun passes cleanly after removing an unused missing-script InputSetup autoload and fixing Windows process waiting/output capture in the test runner. Input actions remain defined in the project Input Map.
- USER VERIFIED: console hosting/joining works, remote capsules appear, and player counts are visible. Default and explicit loopback connections plus both disconnect directions pass separate-process tests; manual disconnect cleanup is user-verified.
- The arena, player capsule, local movement, mouse look, jump, mouse capture, and debug console have been manually playtested.

## Milestone progress

| Milestone | Goal | Status |
|---|---|---|
| D0 Debug infrastructure | DebugHub, tuning debug values, local log buffer, watches, commands, D0 headless check | Verified: `fowl-play/tests/run_checks.ps1` passes |
| M0 Foundation | Project settings, layers, tuning, input map, networking autoload, test runner, arena, capsule movement, camera, spawn/despawn | Verified: automated tests and user host/join/disconnect/rejoin playtests; console scrolling fix confirmed; committed as `017f1cb` |
| M1 Interaction + one prop | Interactable component, focus/highlight, one USE device, one GRAB prop | Verified: host/offline focus/use/grab playtest; reusable prop scene/profile saved |
| M2 Hands | Scene-backed hand + finger scenes, first-person + world modes | In progress: hand/finger scenes and pose preview verified; player first-person/world integration pending; visual proposal in HAND_DESIGN.md |
| M3 Networking slice 1 | Movement authority gate, roster, remote smoothing, intent RPC, validation helper | Gate approved; first standing movement snapshot/validation/interpolation slice implemented. Two-process movement tests pass; user verified movement works and looks smooth in two instances. Remaining M3 work deferred to subsequent slices. |
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

- Automated M0 checks use the saved arena directly and verify offline spawn, host/client spawn and local camera/input selection, client departure, and host departure with debug cleanup. Saved-scene handoff/offline launch and rendered host/join are user-verified; manual disconnect checks are user-verified.
- M3 movement and roster/reconnect are automated- and user-verified. Interaction intents and device state replication are automated-verified; manual device playtest is pending. Actual timeout/refused-connection behavior and four-player capacity are not verified.
- Console scroll/resize fix is user-verified. Landing with the console open has no explicit playtest result; falling gravity and input blocking were verified.
- The root and `docs/` debug references were previously inconsistent; `docs/DEBUG.md` is now the active reference.
- The gameplay loop overview is background design material, not the current technical authority.

## Next action

USER VERIFIED: two-instance movement works and looks smooth. Host-published roster and three-process late-join/reconnect checks now pass. USER VERIFIED: roster/late-join/disconnect/rejoin checklist works. Next: manually verify client and host device use, matching active watches, and device state after client reconnect. Reliable host-validated interaction intents now pass automation, including action/state/reach/obstruction/cooldown rejection and late-join state. See sessions/features-multiplayer.md. Movement rejection-counter and falling-with-console checks were not separately confirmed. Movement authority was approved. M2 was committed as d722c96; remaining hand integration/polish is deferred. Current checkout is features/multiplayer, recovered from the M2 baseline with user authorization; older branches remain intact. First M3 movement changes are uncommitted. Keep carry/throw deferred to M6.
