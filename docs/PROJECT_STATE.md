# Fowl Play — Project State

**Status:** D0, M0, and M1 interaction/prop slices verified. Console overflow fix user-playtested. M2 hands has started with the scene-backed hand API. M6 limp-body carry/drop/throw is implemented on `features/carry-drop-throw` and user visual-playtested; automated and full two-instance host/client verification remain pending.

## Last verified (2026-11-17)

- Current branch: `features/carry-drop-throw` (M6 implementation). Base HEAD before this M6 change: `316b0bca` (working prop carry/drop/throw; limb-body pickup explicitly unfinished).
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
| M5 Limp lifecycle | Knockdown → ground → recovery (G1–G3, G8) | PARTIAL: host timer recovers after 3.5 s plus slow bones or at 6 s hard cap. Host plants capsule under final hips and reliably sends both standing position, final ragdoll pose, and the selected face-up/face-down recovery variant to clients. Wall-clearance search (floor + capsule overlap + spiral outward to 1.5 m) is implemented; forced-exit G8 cleanup broadcasts a reliable `_ragdoll_end` when a limp peer disconnects so remaining clients complete a get-up blend. PUNCH_HITBOX ↔ LIMP_BODIES collision is now bidirectional. |
| M6 Carry and throw | Props and limp bodies, auto-fire throw, dangling limbs | IMPLEMENTED; USER VISUAL-PLAYTESTED: host-authoritative carry/drop/throw; Chest spring/torque stabilisation at the carrier anchor; selective opposite-side limb self-collision; carried-only head/arm damping and narrower neck joint limits; smoothed head-mounted first-person camera while preserving mouse-look and dynamic FOV. Player root stays fixed, remote peers render host poses without local ragdoll collision, recovery pauses while carried, and each release resets a fresh 3.5 s countdown. Automated M6 test and full two-instance host/client verification remain pending. |
| M7 Combat | Jab/recoil, charged punch, lunge, parry outcomes | Not started |
| M8 Procedural legs | Cosmetic legs, zero network traffic | Not started |
| M9 Camera + owner view | Camera follow target, owner legs visibility | Limp camera follows the simulated head position and orientation; the owner's head geometry is hidden and body visible. Head rotational stability is user-verified after physical head tuning; visual comfort, wall avoidance and final camera transitions remain. |
| M10 Hardening | Cleanup matrix, weak-laptop budget, 4-player soak | Not started |

## Open decisions (from PROJECT_OVERVIEW.md §24)

1. Skeleton authoring resolved: manual Godot editor authoring, with humanoid legs.
2. Whether punches affect already-limp bodies.
3. Whether to include impact/wall-slam feedback.
4. Final lobby, nickname, and color flow.
5. Per-bone ragdoll masses (M4 spike).
6. Rebuilding the casino/economy layer, and when.

Late join is decided: allowed during the rest of a day, not during casino/elevator gameplay. Throw power is decided: fixed full power with auto-fire at one second.

## Known limitations

- Automated M0 checks use the saved arena directly and verify offline spawn, host/client spawn and local camera/input selection, client departure, and host departure with debug cleanup. Saved-scene handoff/offline launch and rendered host/join are user-verified; manual disconnect checks are user-verified.
- M3 movement and roster/reconnect are automated- and user-verified. Interaction intents and device state replication are automated-verified; user confirms host/client interaction works. User also confirmed the client device active watch remains true after disconnect/reconnect. Actual timeout/refused-connection behavior and four-player capacity are not verified.
- Console scroll/resize fix is user-verified. Landing with the console open has no explicit playtest result; falling gravity and input blocking were verified.
- The root and `docs/` debug references were previously inconsistent; `docs/DEBUG.md` is now the active reference.
- Ragdoll contact is asymmetric by design of the current authority model: the host simulates real physical-bone contact, while clients render remote ragdolls without local ragdoll collision. Do not re-enable remote PhysicalBone3D collision as a shortcut; the attempted 11-body experiment produced hard-obstacle and speed-dependent phasing behavior.
- The gameplay loop overview is background design material, not the current technical authority.

## Next action

M6 carry/drop/throw implementation is complete and its core carried-ragdoll presentation has been user visual-playtested. Remaining M6 validation: run `fowl-play/tests/run_checks.ps1` (including `m6_carry_test.gd`) and complete the two-instance host/client checklist in [the carry session](sessions/features-carry-drop-throw.md). Do not mark those checks passed until actually run. M5 wall-clearance and recovery visual checks also remain as previously noted.

USER VERIFIED: two-instance movement works and looks smooth. Host-published roster and three-process late-join/reconnect checks now pass. USER VERIFIED: roster/late-join/disconnect/rejoin checklist works. USER VERIFIED: host/client device use and client device state after reconnect (active=true). Next: user checkpoint of the multiplayer slice, then M4 skeleton-authoring preparation. Remaining M3 hand integration and gameplay-dependent validation stay deferred; M3 is not fully complete. Reliable host-validated interaction intents now pass automation, including action/state/reach/obstruction/cooldown rejection and late-join state. See sessions/features-multiplayer.md. Movement rejection-counter and falling-with-console checks were not separately confirmed. Movement authority was approved. M2 was committed as d722c96; remaining hand integration/polish is deferred. Current checkout is features/multiplayer, recovered from the M2 baseline with user authorization; older branches remain intact. First M3 movement changes are uncommitted. Keep carry/throw deferred to M6.


## 2026-11-19 — replicated hover pointing

The local first-person focus now sends hover state and its world-space target to the host. The host derives client ownership from the RPC sender and relays the cosmetic state to peers; remote Player instances apply it to their attached world right hand. Hover updates use an unreliable-ordered channel and are throttled to 20 Hz with immediate state transitions. Added a headless remote world-hand hover assertion and `net/hand_hover_sent` / `net/hand_hover_received` diagnostics. Automated Godot tests and the rendered two-instance test remain unrun by the assistant.
## 2026-11-19 — reactive hands and multiplayer poke sync

On `features/new-reactive-hands-and-viewport`, the local spam-aware poke animation is in place. The accepted-interaction path now broadcasts a reliable cosmetic hand-poke event from the host; remote peers animate the actor's existing world right hand, while the owning peer avoids duplicating its first-person animation. Debug watches `net/hand_poke_sent` and `net/hand_poke_received` were added, along with a headless check in `m3_interaction_test.gd`.

Code and documentation have been committed directly to the feature branch with conventional commit messages. Godot tests and the rendered two-instance host/client visual check have **not** been run by the assistant; the user must pull the branch and verify them before this slice is marked complete.


## 2026-11-19 — procedural hand carry-state integration

Carrier `carry_started` / `carry_ended` signals now drive both hands on each peer. The local owner receives the two-handed carry pose on first-person viewmodel hands; remote observers receive it on the two world-rig hands. The M3 interaction test covers carry start/end for both presentation paths. Godot execution and rendered multiplayer verification remain user-run checks.


## 2026-11-19 — target-driven procedural grip foundation

The hand controller now derives a local PoseRoot grip target from the carried prop transform. Left and right hands approach opposite sides using their explicit side values; the stable hand attachment roots remain untouched and the existing blend response smooths the movement. Automated checks cover distinct left/right targets and opposite-side assignment on remote hands. This is the first target-driven grip foundation; palm orientation and object-specific finger wrapping remain visual tuning work. Godot tests and rendered playtesting have not been run by the assistant.


## 2026-11-19 — shape-aware procedural carry targets

Procedural carry targets now derive their side spacing from the carried prop's collision geometry instead of a fixed center offset. Enabled `CollisionShape3D` nodes contribute their debug-mesh bounds after node transforms; compound shapes are combined in prop-local space, then projected onto the prop's oriented world axes. This accounts for collision-node offsets, rotations, and scale beneath an unscaled prop root. Visible mesh bounds are a fallback when no usable collision debug mesh is available, with a small last-resort target for invisible props. The M2 hand test now checks full/half-scale boxes and sphere/capsule bounds. Godot execution and rendered visual/multiplayer verification remain user-run checks. Palm orientation and object-specific finger wrapping are not yet implemented.


## 2026-11-19 — size-adaptive procedural carry fingers

Carry finger joints now blend between exported tight and open curl presets using the carried prop's collision/mesh bounds projected along the palm normal. Smaller projected thickness produces a tighter curl; larger thickness leaves the fingers more open. The existing finger hierarchy and pose blending are preserved. The M2 hand test checks the curl response between full- and half-scale box props. This is an initial size-adaptive curl foundation, not per-finger surface contact or exact contour wrapping; thumb opposition and per-finger placement remain future work. Godot tests and rendered playtesting remain user-run checks.


## 2026-11-19 — individual procedural carry finger curls

Each of the four fingers now receives its own carry curl target. The existing projected-thickness blend remains the shared baseline; each finger's root is transformed into prop-local space and its lateral distance from the prop center is compared with the prop's lateral half-extent. Fingers nearer the lateral bounds receive a small additional edge-hook curl. The M2 test checks that outer fingers curl slightly farther than inner fingers. This is a geometry-guided pose heuristic, not per-finger contact solving or exact contour wrapping. Thumb opposition remains the next hand-grip task. Godot tests and rendered playtesting remain user-run checks.


## 2026-11-19 — procedural carry thumb opposition

During carry, the thumb root now aims its authored segment direction from the thumb mount toward the carried prop center. The two thumb joints receive a modest carry curl while idle/point/guard/limp thumb behavior remains unchanged. The M2 test checks the thumb root's aim direction toward a test prop. This is an initial opposition pose, not yet surface-contact solving or exact thumb placement around each shape. Godot tests and rendered playtesting remain user-run checks.
