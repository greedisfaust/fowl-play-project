# Fowl Play — Project State

**Status:** D0, M0, and M1 interaction/prop slices verified. M2 hand integration and M6 carry/drop/throw are implemented; M6 is user visual-playtested, with automated and full two-instance host/client verification pending. The highlight/accessibility branch adds the gameplay cursor and animated interactable focus presentation; its automated checks and runtime verification remain pending.

## Last updated (2026-11-19; highlight/accessibility runtime verification pending)

- Current branch: `features/highlight-and-accessibility` (gameplay cursor and interactable focus presentation).
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

On `features/highlight-and-accessibility`, run `fowl-play/tests/run_checks.ps1` (including the M1 interaction and cursor checks), then complete the in-game cursor/focus visual check and a two-instance host/client check. These checks have not been run by the assistant; do not mark them passed until verified. The M6 carry/drop/throw automated and two-instance checks remain pending on its branch.

## Historical verification notes

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


## 2026-11-19 — size-adaptive carry thumb

The carry thumb joints now blend between tight and open curl presets using the same projected prop-thickness measurement as the fingers. Larger props leave the thumb more extended, avoiding the previous inward curl; smaller props retain the tighter opposition pose. The M2 test checks that a smaller box produces a tighter thumb curl than a larger box. Godot execution and rendered playtesting remain user-run checks.


## 2026-11-19 — redesigned target-driven hand actions

The previous one-off reach timer has been replaced by a small action lifecycle: `EXTENDING → CONTACT → RETURNING → NONE`. Hover pointing now adds a restrained target-directed PoseRoot offset and rotates the whole hand toward the hover point within an angular limit; the index aim handles fine correction. The same action API is used by local interaction pokes and replicated world-hand pokes. Local hands begin immediately for responsiveness, then the host's accepted/rejected interaction result confirms the action; the hand completes its extension/contact phase before recovery; failed submissions also recover. Guard, carry, and limp cancel the action and retain priority. The attachment root is never moved. M2/M3 tests were extended for action recovery, seamless mid-animation retriggering, repeated remote world-hand pokes, and interaction-result routing. This is the first redesign slice; tuning and visual verification remain. Godot tests and rendered two-instance checks have not been run by the assistant.


## 2026-11-19 — spam-friendly hand pokes

Removed the action-phase gate from procedural poke starts. A new poke can now retrigger during extension, contact, or recovery, taking its starting blend amount from the current reach amount and easing toward the new target. This keeps rapid clicks responsive without snapping to rest or stacking competing animation timers. When input stops, the normal contact/recovery lifecycle blends the hand back to hover pointing or idle. Gameplay interaction validation and host-side request throttling remain unchanged; only the cosmetic animation is freely retriggerable. M2 and M3 assertions cover local and remote repeated pokes. Godot tests and two-instance visual checks remain user-run.


## 2026-11-19 — Advanced finger contact foundation

- Added a distal fingertip position helper based on the third finger joint and the authored fingertip offset.
- Added the first surface-contact solver for `BoxShape3D`: outside points clamp to the box surface, inside points select the nearest face, and transformed/scaled collision children are evaluated in their own local space. Compound props select the nearest box contact candidate.
- Added M2 checks for outside/inside surface projection and a translated, rotated, non-uniformly scaled box collision shape.
- This is a tested-by-code foundation only: contact targets are not yet driving visible finger bends. Next implementation slice will connect a contact target to one finger's smooth procedural bend before expanding shape support.


## 2026-11-19 — first visible surface-contact response

- Connected the first BoxShape3D contact target to a restrained, target-directed bend correction on the index finger's three joints.
- Added exported weight and angular-limit controls; existing pose blending keeps the correction smooth.
- Cached the carried item's CollisionShape3D children when the item changes, avoiding a tree search during each frame's contact update.
- Added an M2 assertion for a non-zero, bounded index-finger correction toward a transformed box surface.
- This is the first visible response slice, not full finger IK. The remaining fingers and sphere/capsule surface solvers stay queued until this index-finger behavior is visually approved. Godot tests and in-game verification have not been run by the assistant.


## 2026-11-19 — all-finger box contact bend

- Extended the surface-directed carry bend from the index finger to all four fingers, each using its own fingertip and nearest box-surface target.
- Kept the correction weighted, angularly limited, and integrated with existing smooth joint blending.
- Expanded M2 coverage for finite/bounded per-finger corrections and a non-zero contact response.
- Sphere and capsule surface solvers remain the next shape-coverage step. Godot tests and visual verification have not been run by the assistant.


## 2026-11-19 — hand rig multiplayer milestone bundle

- Added [HAND_RIG_MULTIPLAYER_MILESTONE.md](HAND_RIG_MULTIPLAYER_MILESTONE.md) as the consolidated hand-rig handoff and next verification plan.
- The bundle records implemented procedural poses, carry grip, box surface-directed all-finger bend, and spam-friendly poke behavior, while explicitly distinguishing code paths from real two-instance verification.
- Next milestone: audit ownership/RPC paths, then verify hover/point, host-approved poke, carry/drop/throw, and pose priority in both host-to-client and client-to-host directions.
- Current status remains **not multiplayer-ready**. Hover relay, poke broadcast, and carry-pose integration have code/test coverage, but rendered two-instance delivery has not been confirmed.
- Latest all-finger box-contact extension and spam-friendly poke retrigger still require user visual confirmation in the current build. Godot execution and runtime verification have not been performed by the assistant.


## 2026-11-19 — multiplayer hand hover diagnostics

- The host-side hover relay now increments `hand_hover_received` only when the corresponding remote world hand actually accepts and applies the hover state.
- The existing client-side relay receiver uses the same applied-to-world-hand meaning; the owning peer's hidden world-hand copy is intentionally not counted because its first-person viewmodel is the visible hand.
- M3 interaction coverage now asserts the host-side remote world-hand application counter.
- This improves diagnosis of client-to-host hover delivery but does not prove live RPC delivery. Real two-instance host/client visual verification remains required. Godot tests have not been run by the assistant.


### Hand replication investigation diagnostics
- Added `player_hands_<peer_id>` to report all four hand references on a player separately, including instance IDs, world mode, and live pose/hover state. This supports isolating world-hand hover application without changing the RPC path.


## 2026-11-19 — route replicated pointing to remote Viewmodel hands

- Corrected the replicated hover and host-approved poke targets: remote players now animate their camera-attached `ViewmodelHands/RightHand`, not the ragdoll `Rig/Skeleton3D/.../Hand`.
- The local owner's Viewmodel remains driven directly by `Focus`; remote peers drive the same Viewmodel hand through the existing host-authoritative hover/poke relay.
- Kept ragdoll Rig hands dedicated to ragdoll/physical presentation and existing carry grip behavior.
- Updated M3 checks to assert that remote Viewmodel pointing/poking works while the Rig hand remains untouched; remote carry still targets the Rig hands.
- Godot tests and rendered two-instance host/client verification have not been run by the assistant and must be checked in the user's local project.


## 2026-11-19 — longer pokes and moving limp-player grip targets

- Increased procedural poke travel to 0.28 world-space metres (previously 0.20 hand-local units), converting through each hand's transform so scaled Viewmodel hands and unscaled world hands move the same visible distance. Extension, contact, and return timing remain unchanged.
- Added a special carry target path for limp players: cosmetic grip placement now follows the live Chest PhysicalBone3D position and orientation, matching the existing chest carry-support anchor rather than the hips or stationary CharacterBody3D root.
- Added separate Player/Rig accessors for the chest hand target; the existing hips-based gameplay interaction/recovery position remains unchanged.
- Carrier signals now drive the camera-attached Viewmodel hands on both the owner and remote observers. Remote carry no longer animates the ragdoll Rig hands; prop collision-bound grip behavior is unchanged.
- M2 coverage follows a moving chest target; M3 coverage asserts remote carry activates both Viewmodel hands and leaves both Rig hands untouched.
- Godot tests and two-instance visual verification have not been run by the assistant.


## 2026-11-19 — first procedural arm integration

- Added a small two-bone IK position solver with fixed-length geometry and a reachable-distance clamp.
- Connected the remote-visible Rig positive-X UpperArm_L/Forearm_L chain to the camera-attached Viewmodel right hand PoseRoot wrist target. The existing Viewmodel hand remains the pose owner.
- The Player calls the solver only in its standing update path. The Rig yields while ragdoll physics, remote ragdoll playback, or recovery blending owns the skeleton.
- Added rig/<player-id>/right_arm_ik and headless test coverage for bone lengths, reach clamping, wrist movement, and physics ownership. Tests are registered in run_checks.ps1 but have not been run by the assistant.
- Scope is intentionally one arm only. Left arm, wrist orientation, and visual tuning are next after user verification.

- Side mapping note: the Viewmodel right hand is on positive X, while the current Rig names its positive-X chain with the `_L` suffix. The solver intentionally maps by spatial side rather than matching suffixes.


### M2 procedural right-arm visual connection — first cleanup slice

The positive-X Rig hand scene (`HandAttachment_L/HandMount_L/Hand`) is now hidden during standing presentation so the camera-attached Viewmodel right hand remains the single visible hand. The Rig hand scene is restored for host ragdoll simulation and remote ragdoll pose playback, then hidden again when physics ends and recovery owns the skeleton. The attachment, skeleton bone, and physical-bone bodies are not removed or disabled. The positive-X forearm render capsule is lengthened to 0.34 m and centered at 0.14 m to overlap the Viewmodel wrist/forearm silhouette; its PhysicalBone collision shape is unchanged. `rig/<player-id>/right_rig_hand_visible` reports visibility. Automated checks assert the visual handoff; Godot execution and rendered seam confirmation remain user-run.

### M2 procedural two-arm IK integration — implementation ready for visual verification

The shared two-bone solver now drives both arms from their matching camera-attached Viewmodel hand wrist targets. Viewmodel right maps to positive-X Rig bones `UpperArm_L/Forearm_L/Hand_L`; Viewmodel left maps to negative-X Rig bones `UpperArm_R/Forearm_R/Hand_R`. Both target each Viewmodel `PoseRoot` at local `(0, 0, 0.32)` and use the existing reach clamp, elbow pole, and smoothing. Both duplicate Rig hand meshes are hidden while standing and restored for host/remote ragdoll ownership. The hand-scene Forearm meshes remain hidden only on the two world Rig hand instances; FPS Viewmodel hands are unchanged. The negative-X Rig forearm render capsule is mirrored to the same 0.34 m bridge geometry as the positive-X side; physical collision geometry and bone lengths are unchanged. Added left-arm debug watch/command and tests for both wrist targets, both hand visibility handoffs, hidden world-hand forearms, and ragdoll IK yielding. Godot tests and two-instance visual verification have not been run by the assistant.

The Rig hand visibility collectors explicitly exclude the `Forearm` MeshInstance3D child, preventing the ragdoll hand-restore step from overriding its hidden state. The automated test now checks that both world-hand forearm meshes remain hidden while the Rig hands themselves become visible for ragdoll.


### M2 ragdoll Viewmodel visibility and limited arm reach

- Hide the camera-attached `Head/Camera3D/ViewmodelHands` group as soon as host ragdoll simulation or remote ragdoll playback begins. Restore it after the recovery pose blend finishes; this applies to both the local owner and remote Player copies.
- Add reach-aware visual arm extension to both standing IK chains. Each upper-arm and forearm bone scales only along its child-chain axis, with a hard 12% maximum extension. The scale eases back to one as the target returns to normal reach and is reset when IK yields to ragdoll/recovery. The existing two-bone solver still clamps beyond the extended limit.
- No PhysicalBone collision shape, physical bone body, or ragdoll simulation setting is changed. Automated M2 checks cover the stretch cap and existing IK handoff; Godot tests and rendered host/client verification remain user-run.


## 2026-11-19 — automatic interactable silhouette outline

- Replaced the focus-only flat material overlay with an inverted-hull silhouette shader owned by the existing `Interactable` component.
- Every descendant `GeometryInstance3D` under an interactable target receives a subtle near-black idle outline automatically; unrelated meshes remain untouched.
- Focus transitions the same outline smoothly to warm gold, widens it, and adds restrained emission. Clearing focus returns it to the idle state without removing the outline.
- Each mesh receives its own ShaderMaterial instance so per-target focus transitions cannot leak to another interactable.
- The original material overlay is preserved and restored when the Interactable leaves the scene tree.
- Focus detection, interaction validation, and networking remain unchanged. The outline is presentation-only.
- Added an M1 headless assertion for idle/focused visuals, non-interactable exclusion, and original-overlay restoration. Godot execution and in-game visual verification remain pending user testing.


The test arena now includes a WorldEnvironment with restrained Godot Glow post-processing. Focused interactable outlines emit HDR gold (increased focused emission) so the engine can bloom those pixels into a soft halo. The setup is intentionally local to test_arena.tscn until a shared production world/environment is established. Godot import/runtime checks and visual tuning remain user-verified.


## 2026-11-19 — center-screen gameplay cursor

- Added a reusable cursor scene under `fowl-play/ui/` and instanced it from the Player scene. It is visible only for the local player and only while the mouse is captured.
- Idle state is a white circle with a thin dark outline. Existing Focus now emits `focus_target_changed`; the cursor smoothly widens and blends toward its configurable identity accent when an Interactable is focused.
- Added a subtle 1.8-second breathing pulse while hovering. The pulse stops when focus clears; no additional cursor shapes or raycasts were introduced.
- The default accent is temporary until the player identity/color foundation supplies a per-player color. Added a headless cursor check to `tests/run_checks.ps1`.
- Godot execution and in-game visual verification remain user-run.


## 2026-11-19 — cursor and interactable glow polish

- Restored the earlier cursor's more expressive visual language: a translucent white center, dark outline, smooth radius growth on focus, player-accent color blend, and three soft translucent glow rings.
- Kept the 1.8-second cursor breathing pulse. The accent remains a temporary exported fallback and a public set_identity_color(Color) integration point for the future lobby identity system; no Network.player_color() dependency was added.
- Added a separate 2-second breathing pulse to focused Interactable outlines. The gold silhouette width remains stable; only HDR emission intensity pulses, feeding the existing WorldEnvironment Glow.
- Updated cursor checks and debug documentation. Godot headless checks and in-game visual verification have not been run by the assistant.
