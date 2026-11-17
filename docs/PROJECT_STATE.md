# Fowl Play — Project State

**Status:** D0, M0, and M1 interaction/prop slices verified. Console overflow fix user-playtested. M2 hands has started with the scene-backed hand API.

## Last verified (2026-11-17)

- Current branch: `features/player-rig-and-physics-implementation` (M4 preparation). Multiplayer implementation and verification are committed in its history: 0533d52, 773e42c; starting HEAD 31b5395.
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
| M4 Ragdoll spike | Skeleton, 11 physical bones, Jolt joints, sync measurements at 15/30/60 Hz | User verified both peers see the ragdoll and approved the head camera/look limit. Two-process checks pass for host/client targets, mid-limp and already-settled late joins, reliable settled pose, and latest-snapshot hips error <0.25 m with 40 ms interpolation. One-client host ENet send rates at 15/30/60 Hz were roughly 4–7/8–12/21–22 KB/s across runs (natural settling and other game traffic affect totals). A new 10-pair selective self-contact policy passes exception-map, multiplayer, and four-ragdoll 7-second headless checks; remote peers render replicated bones without local collision shapes. Symmetric ragdoll contact remains a host-authoritative design task; the attempted remote-bone collision experiment was rolled back after inconsistent hard-obstacle/phasing behavior. 30 Hz remains the default. |
| M5 Limp lifecycle | Knockdown → ground → recovery (G1–G3, G8) | PARTIAL: host timer recovers after 3.5 s plus slow bones or at 6 s hard cap. Host plants capsule under final hips and reliably sends both standing position, final ragdoll pose, and the selected face-up/face-down recovery variant to clients. The 0.5 s host/client pose handoff and authored recovery playback pass the user's host/client visual playtest; startup pose reset prevents saved editor pose overrides from spawning players on the floor, and authored playback avoids a T-pose flicker. Wall-clearance search and forced-exit cleanup audit remain. |
| M6 Carry and throw | Props and limp bodies, auto-fire throw, dangling limbs | Not started |
| M7 Combat | Jab/recoil, charged punch, lunge, parry outcomes | Not started |
| M8 Procedural legs | Cosmetic legs, zero network traffic | Not started |
| M9 Camera + owner view | Camera follow target, owner legs visibility | Limp camera follows the simulated head position and orientation; the owner's head geometry is hidden and body visible. Head rotational stability is user-verified after physical head tuning; visual comfort, wall avoidance and final camera transitions remain. |
| M10 Hardening | Cleanup matrix, weak-laptop budget, 4-player soak | Not started |

## Open decisions (from PROJECT_OVERVIEW.md §24)

1. Skeleton authoring resolved: manual Godot editor authoring, with humanoid legs.
2. Dangling limbs while carried.
3. Whether punches affect already-limp bodies.
4. Whether to include impact/wall-slam feedback.
5. Final lobby, nickname, and color flow.
6. Per-bone ragdoll masses (M4 spike).
7. Rebuilding the casino/economy layer, and when.

Late join is decided: allowed during the rest of a day, not during casino/elevator gameplay. Throw power is decided: fixed full power with auto-fire at one second.

## Known limitations

- Automated M0 checks use the saved arena directly and verify offline spawn, host/client spawn and local camera/input selection, client departure, and host departure with debug cleanup. Saved-scene handoff/offline launch and rendered host/join are user-verified; manual disconnect checks are user-verified.
- M3 movement and roster/reconnect are automated- and user-verified. Interaction intents and device state replication are automated-verified; user confirms host/client interaction works. User also confirmed the client device active watch remains true after disconnect/reconnect. Actual timeout/refused-connection behavior and four-player capacity are not verified.
- Console scroll/resize fix is user-verified. Landing with the console open has no explicit playtest result; falling gravity and input blocking were verified.
- The root and `docs/` debug references were previously inconsistent; `docs/DEBUG.md` is now the active reference.
- Ragdoll contact is asymmetric by design of the current authority model: the host simulates real physical-bone contact, while clients render remote ragdolls without local ragdoll collision. Do not re-enable remote PhysicalBone3D collision as a shortcut; the attempted 11-body experiment produced hard-obstacle and speed-dependent phasing behavior.
- The gameplay loop overview is background design material, not the current technical authority.

## Next action

Current: the 17-bone visual rig is mounted under Player, and the user verified standing host/client visibility and movement. The 11-body ragdoll has host-owned debug start/stop, client-rendered quantized poses, a reliable settled pose, late-join state, and a user-approved head camera. M4 automation and local 15/30/60 Hz profiling pass. M5 timer, floor placement, reliable automatic recovery, and the 0.5 s host/client get-up pose/camera blend pass focused headless checks. The owner limp camera follows head position and orientation; head rotational stability is user-verified after physical tuning. The user chose two authored recovery variants, face-up and face-down; side recovery is deferred. Runtime replicates the host-selected variant, classifies from chest forward direction with a face-up fallback for ambiguous side-on poses, blends into its authored opening pose without a T-pose frame, keeps movement locked through the authored clip, falls back to the procedural blend when the clip is unavailable, and resets saved editor pose overrides on rig startup. Host/client authored recovery playback and upright spawn behavior are user-verified. Remote ragdoll collision remains intentionally disabled after a failed 11-body local-collision experiment. Next: design host-authoritative ragdoll contact, then wall clearance and forced-exit cleanup. See [player rig design](PLAYER_RIG_DESIGN.md) and [current rig session](sessions/features-player-rig-and-physics-implementation.md). The paragraph below is a historical multiplayer handoff and is superseded by the current branch/history above.

USER VERIFIED: two-instance movement works and looks smooth. Host-published roster and three-process late-join/reconnect checks now pass. USER VERIFIED: roster/late-join/disconnect/rejoin checklist works. USER VERIFIED: host/client device use and client device state after reconnect (active=true). Next: user checkpoint of the multiplayer slice, then M4 skeleton-authoring preparation. Remaining M3 hand integration and gameplay-dependent validation stay deferred; M3 is not fully complete. Reliable host-validated interaction intents now pass automation, including action/state/reach/obstruction/cooldown rejection and late-join state. See sessions/features-multiplayer.md. Movement rejection-counter and falling-with-console checks were not separately confirmed. Movement authority was approved. M2 was committed as d722c96; remaining hand integration/polish is deferred. Current checkout is features/multiplayer, recovered from the M2 baseline with user authorization; older branches remain intact. First M3 movement changes are uncommitted. Keep carry/throw deferred to M6.
