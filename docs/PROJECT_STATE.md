# Fowl Play — Project State

**Status:** Combat & Procedural Legs (Movement) is active on `features/combat-and-procedural-movement`. The branch starts from the merged Player Identity & World Kit baseline. The read-only rig audit is complete and the first procedural gait slice is committed; Godot execution and in-game verification remain pending. Previous identity/world-kit work remains archived as implemented, with verification caveats retained below.

## Last updated (2026-11-20; two-bone procedural leg IK)

- Current branch: `features/combat-and-procedural-movement` (based on merged `main` commit `1506c03746e158c74ffcd2da5df042b20435db25`). Read-only rig audit is complete; initial procedural gait slice is committed and awaiting Godot verification.
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
| M2 Hands | Scene-backed hand + finger scenes, first-person + world modes | Integrated; host/client hover pointing and poke synchronization are USER VERIFIED fixed. Further pose/visual polish can continue with procedural animation. |
| M3 Networking slice 1 | Movement authority gate, roster, remote smoothing, intent RPC, validation helper | Gate approved; first standing movement snapshot/validation/interpolation slice implemented. Two-process movement tests pass; user verified movement works and looks smooth in two instances. Remaining M3 work deferred to subsequent slices. |
| M4 Ragdoll spike | Skeleton, 11 physical bones, Jolt joints, sync measurements at 15/30/60 Hz | User verified both peers see the ragdoll and approved the head camera/look limit. Two-process checks pass for host/client targets, mid-limp and already-settled late joins, reliable settled pose, and latest-snapshot hips error <0.25 m with 40 ms interpolation. One-client host ENet send rates at 15/30/60 Hz were roughly 4–7/8–12/21–22 KB/s across runs (natural settling and other game traffic affect totals). A new 10-pair selective self-contact policy passes exception-map, multiplayer, and four-ragdoll 7-second headless checks; remote peers render replicated bones without local collision shapes. Symmetric ragdoll contact remains a host-authoritative design task; the attempted remote-bone collision experiment was rolled back after inconsistent hard-obstacle/phasing behavior. 30 Hz remains the default. |
| M5 Limp lifecycle | Knockdown → ground → recovery (G1–G3, G8) | PARTIAL: host timer recovers after 3.5 s plus slow bones or at 6 s hard cap. Host plants capsule under final hips and reliably sends both standing position, final ragdoll pose, and the selected face-up/face-down recovery variant to clients. Wall-clearance search (floor + capsule overlap + spiral outward to 1.5 m) is implemented; forced-exit G8 cleanup broadcasts a reliable `_ragdoll_end` when a limp peer disconnects so remaining clients complete a get-up blend. PUNCH_HITBOX ↔ LIMP_BODIES collision is now bidirectional. |
| World kit — WorldScreen | Reusable size-adaptive 3D screen, CMD-style text renderer, and FAT/SLIM housings | Reusable content APIs, menus, FAT/SLIM controllers and glass treatments are implemented and documented. Automated housing checks and final rendered sizing/material verification remain unconfirmed in this archive. |
| M6 Carry and throw | Props and limp bodies, auto-fire throw, dangling limbs | IMPLEMENTED; USER VISUAL-PLAYTESTED: host-authoritative carry/drop/throw; Chest spring/torque stabilisation at the carrier anchor; selective opposite-side limb self-collision; carried-only head/arm damping and narrower neck joint limits; smoothed head-mounted first-person camera while preserving mouse-look and dynamic FOV. Player root stays fixed, remote peers render host poses without local ragdoll collision, recovery pauses while carried, and each release resets a fresh 3.5 s countdown. Automated M6 test and full two-instance host/client verification remain pending. |
| M7 Combat | Jab/recoil, charged punch, lunge, parry outcomes | Not started |
| M8 Procedural legs | Hybrid locomotion, zero network traffic | IN PROGRESS: local velocity-driven gait and grounded-state replication are implemented; filtered velocity now smooths starts, stops, and directional changes. Stance/swing foot articulation with swing-phase knee flex and toe-lift pitch is implemented locally. A world-space foot target tracker captures stance anchors and interpolates lifted swing targets. PlayerRig performs downward physics-space ground probes beneath both feet, excludes the owning Player body, filters steep surfaces, and exposes hit/target/normal diagnostics. The shared two-bone solver now drives each thigh/shin chain toward its planted stance anchor or interpolated swing target, with per-leg blend weights and IK diagnostics. Swing landing points are captured at lift-off instead of chasing a moving ground probe; landing locks to that captured point. Ground probes now predict the distance the player travels during the upcoming swing and place the next foot contact ahead of the body, correcting the trailing-foot behavior. Foot orientation blends toward the detected surface normal, and diagnostics expose each stance anchor. Turn-in-place, owner-view leg visibility, combat balance reactions, terrain adaptation, visual tuning, and Godot verification remain. |
| M9 Camera + owner view | Camera follow target, owner legs visibility | Limp camera follows the simulated head position and orientation; the owner's head geometry is hidden and body visible. Head rotational stability is user-verified after physical head tuning; visual comfort, wall avoidance and final camera transitions remain. |
| M10 Hardening | Cleanup matrix, weak-laptop budget, 4-player soak | Not started |

## Open decisions (from PROJECT_OVERVIEW.md §24)

1. Skeleton authoring resolved: manual Godot editor authoring, with humanoid legs.
2. Whether punches affect already-limp bodies.
3. Whether to include impact/wall-slam feedback.
4. Final lobby/connection presentation beyond the implemented Registration Terminal identity flow.
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

## Branch closeout and next feature

`features/player-identity-and-world-kit` is archived as the completed identity/world-kit implementation branch. The user confirmed these previously open items are fixed and implemented:

- Multiplayer hover-pointing and poke synchronization between host and client.
- Interactive Terminal wake/session/registration behavior and its movement/proximity fixes.
- Interactable golden focus treatment, including the animated outline and restrained glow.
- Player identity color presentation across the character rig, ragdoll, hands, and nameplate identity accent.

The user also confirmed the latest player-color implementation works in-game. This is user verification, not a claim that the assistant ran Godot tests. Existing automated test stages and any unconfirmed WorldScreen visual checks remain recorded as pending rather than being silently marked passed.

**Active feature:** Combat & Procedural Legs (Movement), branch `features/combat-and-procedural-movement`. Read-only rig audit completed; the gait controller, world-space foot target tracker, per-foot ground probes, and first two-bone IK integration are implemented. Next visually verify and tune the IK in Godot, then address owner-view leg visibility and terrain adaptation while preserving the scene hierarchy, movement stream, and ragdoll/recovery ownership. See [the active feature session](sessions/features-combat-and-procedural-movement.md).

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


## 2026-11-19 — Player Identity Core

- Added reusable `PlayerIdentity` data with stable peer ID, nickname, palette index, resolved color/name, and `Nickname (#PeerID)` display label.
- Added the ten-color lobby palette (Red, Orange, Yellow, Green, Cyan, Blue, Purple, Pink, Black, White).
- Existing `Network` remains the sole network authority. The host assigns the host's initial identity and a default identity on each peer connection; clients can submit only nickname/color intent, while the host derives ownership from the RPC sender.
- Duplicate nicknames are case-insensitive and receive numeric suffixes. Blank names become Chicken; control characters are stripped and names are limited to 16 characters.
- Requested colors are honored when free; if occupied, assignment walks forward through the palette with wraparound and takes the first free color. Peer IDs remain unchanged.
- A reliable host-published identity roster supports connected and late-joining clients; disconnect and shutdown clean identity state.
- Added `net/identities`, `identity_status`, and `identity_set` diagnostics plus focused `m3_identity_test.gd` coverage registered in `run_checks.ps1`.
- Godot tests, actual RPC replication, and two-instance authority checks have not been run by the assistant. Do not mark this slice verified until the user runs them.


## 2026-11-19 — reusable Physical USE Button (implementation pending verification)

- Added `fowl-play/interaction/physical_use_button.gd`, a scene-backed component that references an editor-authored moving cap and existing `Interactable` node. It listens only for accepted `use` interactions; no parallel input, focus, or validation path was added.
- The cap's rest position is captured at `_ready()`. Press travel uses a configurable local-space axis/depth, followed by a spring transition back to the exact rest position. A retrigger kills the active tween and starts from the cap's current position to avoid snapping or accumulated offsets.
- The host/offline authority plays the local presentation and, for ENet sessions, sends a reliable presentation-only RPC. Clients validate that the sender is host before animating. Gameplay acceptance remains owned by Network/Interactable.
- Added `fowl-play/tests/m3_physical_use_button_test.gd` and registered the `physical-button` stage in `fowl-play/tests/run_checks.ps1`. Added `interact/button/<node-path>/press_count` debug watch documentation.
- No scene, mesh, or collision shape was authored by script. The first physical button fixture remains an editor task. Godot test execution and rendered host/client animation verification are UNTESTED.


## 2026-11-19 — isolated WorldScreen text overlay and LED matrix (verification pending)

- Reworked the reusable WorldScreen rendering path so the opaque physical panel and glowing text are separate 3D layers.
- The editor-authored scene hierarchy now requires sibling `Display`, `TextDisplay`, and `SubViewport` nodes under WorldScreen, with `ScreenText` inside SubViewport. The TextDisplay plane must match Display's dimensions/orientation and sit slightly in front of it.
- The SubViewport uses transparent background and HDR 2D. It contains only ScreenText; no full-screen background ColorRect is used.
- WorldScreen creates a transparent, unshaded StandardMaterial3D for TextDisplay and routes the SubViewport texture to albedo and emission. The physical Display remains dark and non-emissive.
- WorldScreen assigns the CanvasItem HDR/LED shader to ScreenText. The shader boosts glyph RGB and applies the LED dot mask to glyph alpha; the panel is not included in the viewport texture.
- Both display planes resize together through `display_size`. Responsive viewport/font sizing, content helpers, and per-instance shader settings remain supported.
- Updated the WorldScreen contract test and debug documentation for the two-layer setup. The test tolerates the committed scene while the editor-authored TextDisplay node is still local/uncommitted; overlay-specific assertions run once that node is present.
- Godot tests and rendered visual verification have NOT been run by the assistant. The user must verify text visibility, panel darkness, dot size/readability, and bloom in the editor/game before this slice is considered complete.


## 2026-11-19 — SLIM WorldScreen housing foundation

- Added the `SlimWorldScreen` controller and dedicated glass shader without modifying the editor-authored SLIM scene.
- The controller resizes the WorldScreen content surface, backing housing, four bezel pieces, and protective glass from one display-size property. Bezel thickness and housing depth are separately adjustable.
- Corrected the authored geometry orientation in the controller to match WorldScreen's existing XZ display plane: housing and bezel group rotate 90 degrees around X, and the glass is aligned to the same plane.
- Added restrained cool-tinted glass with PBR specular/clearcoat response, a grazing-angle Fresnel sheen, and a near-camera fade. This is not a real reflection capture; reflection probes and scene lighting determine environmental reflections.
- Added a headless contract test and registered the `slim-world-screen` stage. Godot tests and rendered visual verification have not been run by the assistant.

- Follow-up correction: Glass is a PlaneMesh and stays at zero rotation to match WorldScreen's default XZ-facing display plane; only the BoxMesh housing and bezel group rotate 90 degrees around X.


## 2026-11-19 — FAT industrial WorldScreen controller

- Added a responsive `FatWorldScreen` controller for the editor-authored industrial CRT assembly without modifying or generating its scene file.
- The controller places the CSG shell front face just behind the display (Depth mode extrudes toward negative Z), then lays out the clipped outer CSG shell, four inner armor polygons, four corner plates, side vent groups, lower control strip, identification plate, fasteners, WorldScreen content, and glass from one `display_size` value.
- Existing authored materials and TextMesh lettering resources are preserved; the script updates geometry dimensions and transforms only. The same restrained glass shader/settings used by SLIM are reused.
- Added a headless contract test and registered the `fat-world-screen` stage. Godot execution and rendered visual verification have not been run by the assistant and remain required in the local editor.


## 2026-11-19 — FAT WorldScreen scene hierarchy compatibility correction

- Audited the user's pushed editor-authored FAT scene. Its `Chassis` is correctly nested under `WorldScreen`, not directly under the `FatWorldScreen` root; the controller's original lookup and lettering-capture paths did not match that hierarchy.
- Updated the controller to resolve `WorldScreen/Chassis` and the engraved TextMesh through that same path. Updated fastener lookup to support the authored `*Fastener` node names while retaining the shorter fixture names.
- Updated the FAT contract test to mirror the real nested chassis and authored fastener names. This correction is code-reviewed but Godot tests and editor visuals have not been executed by the assistant.


- Follow-up geometry alignment: the authored `InnerArmor` group had a local Z offset while the controller also applies the plate Z offset. The controller now normalizes the group to zero before laying out the plates, preventing the offset from being applied twice; the contract fixture now starts with the authored offset and asserts the normalized result.


- SLIM Precision Cyber Industrial foundation: extended the existing controller to populate optional authored detail groups with generated machined trim, emissive perimeter/corner lighting, status indicators, side vent inserts, an identification plate, and micro-fasteners. Added adjustable trim/light widths, cyan/amber colors, and emissive energy. The existing WorldScreen, glass orientation, and core housing nodes remain unchanged. Contract checks and editor verification are pending.


## 2026-11-19 — FAT/SLIM housing and optical glass controller update

The latest user-authored FAT and SLIM scenes were inspected at commit `61409bf`. Both now use direct-child `WorldScreen`, `Chassis`, and `Glass` nodes. Added a responsive SLIM controller, corrected the FAT controller to use the direct-child hierarchy, and created a shared smoked-glass shader with view-angle Fresnel, a subtle diagonal sheen, and edge glints. Updated both housing tests to instantiate the actual authored scenes. The controller scripts have not yet been attached to the scene roots in the editor; the scene files were intentionally not modified because open-scene status was not confirmed. Godot tests/import and visual verification remain unrun.


### Dynamic WorldScreen content API — 2026-11-20

- Added `WorldScreen.set_content(header, body, prompt = "")` as the primary full-replacement API. It forwards to the instance's `ScreenText`, clears previous text, then adds a gold header, newline-capable body, and optional prompt. Empty sections are omitted.
- Existing `append_header`, `append_paragraph`, `append_prompt`, and `clear_screen` APIs remain available. Content remains instance-local; housing geometry, screen sizing, font, LED matrix, glow, and sibling screens are unaffected.
- Added replacement and multi-line body assertions to `m3_screen_text_test.gd` and per-instance replacement assertions to `m3_world_screen_test.gd`. Registered stages remain `screen-text` and `world-screen`.
- No scenes or node trees changed. Godot execution and rendered FAT/SLIM verification have not been performed by the assistant.


### Reusable screen presentation presets — 2026-11-20

- Restored the complete-content replacement API: `WorldScreen.set_content(header, body, prompt = "")` and `ScreenText.set_content(...)`.
- Added named presentation presets through `show_layout(layout, header, body, prompt = "")`. Supported preset names: `standard`, `welcome`, `information`, `warning`, `success`, and `confirmation`. Presets apply per-call text colors without mutating exported default colors or changing alignment, font, LED matrix, glow, housing, or screen size.
- Existing append and clear methods remain available. Added focused replacement/preset tests to the ScreenText and WorldScreen stages.
- No scene files or editor-authored node trees changed. Godot test execution and rendered visual verification remain unperformed by the assistant.


## 2026-11-20 — World Screens & ScreenText guide

- Added [WORLD_SCREENS_AND_SCREEN_TEXT.md](WORLD_SCREENS_AND_SCREEN_TEXT.md) as the practical reference for the shared WorldScreen scene, ScreenText renderer, FAT/SLIM housing structure, sizing, text APIs, presentation presets, LED/HDR glow pipeline, instance isolation, troubleshooting, and verification.
- Current public content APIs: `append_header`, `append_paragraph`, `append_prompt`, `clear_screen`, `set_content`, and `show_layout`. The WorldScreen wrapper forwards these to its ScreenText child.
- The guide records the required `Display` / `TextDisplay` / `SubViewport/ScreenText` split and the FAT/SLIM direct-child `WorldScreen`, `Chassis`, `Glass` contract.
- No game scripts or scenes changed in this documentation update. Godot tests and rendered checks were not run as part of this documentation update.


## 2026-11-20 — Interactive menu foundation

- Added input-independent `ScreenMenu` in `fowl-play/ui/screen_menu.gd`: validated option IDs/labels, enabled/disabled options, selection movement, optional wrap navigation, semantic action routing, and confirmation/cancellation signals.
- Added `ScreenText.show_menu` and `WorldScreen.show_menu`; selected rows use a cyan marker and disabled rows are dimmed while preserving the existing LED/glow pipeline.
- Added `fowl-play/tests/m3_screen_menu_test.gd` and registered the `screen-menu` runner stage. Updated the screen guide and debug reference.
- No scenes or global InputMap actions changed. Keyboard/gamepad/physical USE routing is deferred to the Registration Terminal input owner. Godot tests and rendered verification have not been run by the assistant.


## Registration Terminal foundation

- Added RegistrationTerminal as a reusable local controller for the existing WorldScreen, ScreenMenu, PhysicalUseButton, Interactable, and host-authoritative PlayerIdentity systems.
- Local menu flow supports nickname editing (16 characters), ten-color selection, registration submission, host-assigned success display, arrow-key navigation, Enter/Escape handling, physical USE confirmation, and a configurable horizontal proximity cutoff. Movement is locked only while nickname editing is active.
- Added a presentation-only local interaction-request signal to Interactable/Focus for immediate per-player screen input. Host validation and the authoritative interacted signal remain unchanged.
- No scene/node construction or InputMap changes were made. Focused test stage: registration-terminal. Godot execution and editor-authored scene/host-client verification remain pending.


### Direct mouse interaction for registration

- Registration sessions reveal the local mouse cursor and restore its previous mode on close/completion/rejection.
- Left-clicks are ray-projected from the local player's Camera3D onto the WorldScreen plane, mapped to SubViewport pixels, and hit-tested against ScreenText's rendered menu option lines.
- Clicking a valid option row selects and confirms it in one click. Clicks outside option rows are ignored. Arrow keys, Enter, and E/M1 on the screen Interactable continue to work.
- Focused checks cover ScreenText option-row hit testing and cursor-mode restoration. Godot execution and actual 3D click verification remain user-run.


### Registration movement-lock cleanup

Removed the obsolete session-wide `registration_terminal_active` lock. A narrow `Player.set_terminal_movement_locked()` control is now used only while the nickname editor is open; Enter, Escape, session end, range disconnect, and terminal teardown release it.


## Interactive Terminal foundation (Slice 1)

Added `ui/interactive_terminal.gd`: reusable local-player proximity wake/sleep and active-session lifecycle. It expects an editor-authored proximity Area3D and a screen Interactable, and exposes wake/interaction distances plus overridable lifecycle hooks. RegistrationTerminal now extends InteractiveTerminal. The physical USE button is optional and is not referenced by the registration controller. Godot tests and in-world verification are pending.


## InteractiveTerminal / RegistrationTerminal integration
- `RegistrationTerminal` inherits `InteractiveTerminal`; the base owns local proximity wake/sleep and session range, while registration owns menus and identity submission.
- Required inherited references: `screen`, `screen_interactable`, and `proximity_area`. The Area3D CollisionShape3D is editor-authored and should match `wake_distance` (default 5 m); interaction distance defaults to 3 m.
- Proximity wakes the screen but does not start registration. E/M1 on the screen Interactable starts the session; repeated E/M1 confirms the selected menu row.
- A physical USE button is optional and is no longer referenced by RegistrationTerminal.
- Setup: `docs/REGISTRATION_TERMINAL_SETUP.md`. Godot tests and rendered host/client verification remain pending.


### Registration Terminal copy customization

- RegistrationTerminal exposes visible menu labels, descriptions, prompts, and status messages in the Inspector under **Registration Copy**. Idle/wake wording remains on inherited InteractiveTerminal exports. Formatting placeholders are documented in `docs/REGISTRATION_TERMINAL_SETUP.md`.


## 2026-11-20 — player identity presentation integration

- Connected each Player instance to the existing `Network.identity_roster_changed` signal. The local cursor now follows the host-assigned identity palette color and restores its configured fallback when the identity is absent. Remote player nameplates update from the same replicated identity records.
- Added `player_nameplate.gd` for an editor-authored Label3D. It displays `Nickname (#PeerID)`, uses the identity tint, billboards toward the camera, and hides for the local player or when no identity is assigned.
- Added the `identity-presentation` contract test and extended `m1-cursor` to verify fallback restoration. Updated setup documentation.
- The existing Player scene did not contain a `NamePlate` node, so no scene file was modified. The user must add a direct-child Label3D named `NamePlate` and attach `res://player/player_nameplate.gd`; suggested initial local position is `(0, 2.2, 0)`. Godot tests and actual host/client verification have not been run.


## 2026-11-20 — SubViewport player nameplate presentation

- Replaced the Label3D-based player nameplate controller with a reusable Node3D presentation that renders its UI through a 512 × 128 transparent SubViewport and displays it on a 2 m × 0.5 m QuadMesh.
- The panel uses JetBrains Mono, a dark industrial backing, a player-identity-colored accent rail, a subtle divider, and secondary registration text. The panel billboards toward the active local camera and fades between configurable distances (18–28 m by default).
- Player identity remains host-authoritative and keyed by peer ID internally. The visible nameplate displays the nickname only; no peer ID is rendered. The local player's own plate remains hidden.
- Player scene integration expects a child Node3D named NamePlate (instance of res://player/player_nameplate.tscn) with Panel, Display/SubViewport, and Display/UI children Background, Accent, Nickname, Divider, and Status. The scene is editor-authored by the user; no .tscn was changed by this code slice.
- The identity-presentation contract test now constructs the expected node hierarchy and checks nickname-only text, identity accent, local-player hiding, transparent high-resolution viewport, and 3D quad material. Godot execution and in-game visual/multiplayer verification remain pending.


## 2026-11-20 — player nameplate readability and ragdoll follow-up

- Reduced the world-space nameplate to 78% of its former size (22% smaller) while preserving the authored 512 × 128 SubViewport resolution.
- Corrected the QuadMesh billboard orientation so its +Z display face points toward the active camera; this prevents the back-face/mirrored text presentation.
- Nickname text is horizontally centered across the panel.
- Added smooth opacity targeting: 12% at rest, 100% while the local view ray intersects the nameplate quad, with the existing 18–28 m distance fade still applied. With mouse capture, the test uses the center-screen gameplay cursor; with a visible cursor, it uses the actual pointer position.
- Player.gd reparents the nameplate to the existing Rig/Skeleton3D/HeadAttachment at runtime. This attachment follows the head bone during host ragdoll simulation, remote interpolated pose playback, and recovery blending. No ragdoll physics, network authority, or editor-authored scene files are changed.
- Updated the identity-presentation contract to cover scale, centered nickname alignment, and opacity defaults. Godot execution and rendered multiplayer verification remain user-run.


## 2026-11-20 — nameplate text clarity and head clearance

- Raised the runtime HeadAttachment offset from 0.38 m to 0.62 m so the plate sits more comfortably above the head.
- Split opacity treatment: the dark backing, identity accent rail, and divider fade from the resting opacity to full opacity when aimed at. Nickname and status text remain fully opaque at all times for quick player identification.
- The existing distance fade continues to apply to the decorative panel only; text remains readable independently of hover and panel opacity.
- The current visual design is a functional first pass, not a locked final design. Keep the existing scene hierarchy; future styling can replace or add authored decorative UI elements without changing identity networking or ragdoll attachment.
- Added contract coverage for separate panel/text opacity behavior. Godot execution and in-game visual verification remain user-run.


## Player color presentation
- The authoritative `PlayerIdentity.color_index` now drives the world Rig body geometry, both world-rig hands, both first-person Viewmodel hands, and the existing nameplate accent.
- Rig geometry materials are duplicated per player before tinting; the temporary `FacePhoto` placeholder is excluded.
- No scene files or authored node hierarchies were changed. The user's existing rig and nameplate scenes remain intact.
- USER VERIFIED: the player-color presentation works in-game across the character presentation, including hands and ragdoll. Automated Godot test execution was not performed by the assistant; use the focused checks as regression coverage.


## 2026-11-20 — Player Identity & World Kit closeout

- User confirmed multiplayer hand hover/poke synchronization is fixed and working.
- User confirmed the Interactive Terminal work is implemented and its issues are fixed.
- User confirmed the animated golden Interactable highlighting is implemented and fixed.
- User confirmed player identity coloring works in-game across the character presentation, including hands and ragdoll; the nameplate uses the assigned identity color as its accent while keeping nickname text legible.
- This branch is archived as the implementation baseline for identity, terminal/world-kit presentation, and interaction feedback. Do not carry the three resolved issues forward as open tasks.
- No claim is made here that the assistant ran Godot tests. Preserve explicit pending status for automated checks or visual checks that were not independently confirmed.


### Procedural leg stopping refinement — 2026-11-20

- Fixed the gait phase freezing in mid-swing when horizontal movement stopped. The controller now gently advances the remaining cycle to the shared double-stance phase while the motion blend fades, then holds a neutral standing phase.
- Added an M8 regression check that stops the controller during swing and verifies both feet settle into stance.
- This addresses the suspended-foot case visible in the user's playtest. Foot sole alignment and surface-normal orientation remain separate visual-contact refinements; Godot test execution and in-game verification are still pending.


### Movement-based procedural footstep planner — 2026-11-20
- Replaced the trailing-foot-origin predictive landing calculation with a hip-relative planner driven by smoothed movement intent.
- The planner keeps left/right targets separated perpendicular to travel, supports forward/backward/strafe/diagonal movement, and predicts root travel over the swing interval before vertical ground probing.
- Existing foot anchors, swing interpolation, two-bone IK, and ground-normal alignment remain in place.
- Added M8 planner assertions. Godot tests and in-game verification have not been run by the assistant; user visual verification is pending.


- Follow-up refinement: hip-relative predicted targets are used only for a foot that is actively in swing. Stance feet continue probing their current sole, so standing initialization and stop-settling cannot pull a planted foot toward a forward target. Both targets are calculated from the midpoint between the hips to avoid doubling the lateral separation.


## Leg spacing, smoother planting, and earlier step timing — 2026-11-20

- Reduced `LEG_STANCE_FRACTION` from 0.58 to 0.50 so each foot enters swing sooner and spends less time trailing before requesting a new landing target.
- Foot lateral placement now always uses the rig's anatomical right axis, rather than an axis perpendicular to movement. This prevents left/right targets from swapping sides during strafing and diagonals.
- Two-bone IK pole targets now receive an outward lateral bias per leg, encouraging knees to bend in separate planes instead of converging through one another.
- Reduced procedural leg IK blend response from 14 to 8 to soften sudden thigh/knee corrections when a new planted target is acquired.
- Replaced cubic smoothstep with quintic smootherstep for the swing path, reducing abrupt velocity changes at lift-off and touchdown.
- Added planner regression assertions for anatomical left/right separation during strafing and diagonal movement.
- Godot tests and in-game verification remain pending; this is procedural pose separation, not physical collision bodies between the legs.


## Readable knee-lift walking pass — 2026-11-20

- Restored the stance fraction from 0.50 to 0.58 so each foot has a more readable planted/support phase rather than spending half the cycle in swing.
- Increased swing-foot vertical arc from 0.12 m to 0.28 m so the foot visibly clears the floor.
- Changed knee flexion to bend early, hold through most of forward swing, and extend during the final approach to landing. The two-bone IK then follows the elevated foot target, producing the intended knee-up-then-place motion.
- Reduced ground-hit foot clearance from 0.04 m to 0.015 m to reduce visible hovering. The value remains a small ankle/sole offset, not a guarantee of exact mesh contact because the foot bone origin is not necessarily the bottom of the shoe.
- Added/updated M8 assertions for visible knee bend and the larger swing arc. Godot tests and in-game verification remain pending.


## Gait cadence and anatomical spacing refinement — 2026-11-20

- Added `LEG_GAIT_RATE_MULTIPLIER = 0.78` to slow the procedural step cycle independently of player movement speed. The player still moves at the same gameplay speed; only gait phase advances more deliberately.
- Increased the rig's hip-relative landing-zone lateral offset from 0.18 m to 0.24 m to keep the feet in clearer left/right lanes.
- Increased the per-leg outward knee-pole bias from 0.30 m to 0.48 m so IK solutions favor separate knee bend planes.
- Updated the gait phase regression expectation to include the cadence multiplier.
- This is a soft anatomical separation constraint, not physical leg collision. Godot tests and visual verification remain pending.


## 2026-11-20 — distance-triggered foot recovery and anatomical landing lanes

- Added per-leg comfortable-reach thresholds based on the authored thigh/shin chain lengths. A planted stance foot requests an emergency replant when its hip-to-anchor distance reaches 82% of the available two-bone chain length.
- Emergency recovery captures a fresh hip-relative ground target and performs a short 0.18 s lifted step rather than teleporting the foot or waiting for the normal gait phase.
- If both legs exceed their thresholds in the same update, only the more-stretched leg is allowed to recover first.
- Added a target-space anatomical side clamp so left landing targets remain at least 0.20 m left of the hip midpoint and right targets at least 0.20 m right, including emergency targets.
- Extended M8 checks for overreach detection, lifted recovery interpolation, completed anchor capture, and left/right centerline protection.
- Debug ground status now reports emergency-replant state and normalized hip-to-anchor stretch ratios.
- Godot execution and in-game verification have not been run by the assistant. This remains a procedural target constraint, not physical collision between the leg meshes.


## 2026-11-20 — correct authored leg sides and preserve swing knee bend

- Corrected the left/right sign mapping throughout normal footstep planning, emergency replanting, anatomical target constraints, and IK knee-pole placement. The rig's authored `Thigh_L` is at local +X; `Thigh_R` is at local -X. Previous code had these signs reversed, causing the visible leg crossing.
- Kept the side axis fixed to the rig's anatomical right axis while strafing.
- Exposed smoothed per-leg knee-bend weights from the gait controller and fed them into the IK pole. During swing, the knee receives additional forward bend while the outward side bias remains active; the weight eases in and out with the gait's existing smooth swing curve.
- Updated planner and gait regression assertions for the authored side mapping and IK knee bend handoff.
- No scene files changed. Godot tests and in-game behavior have not been executed by the assistant.


## 2026-11-20 — improve leg reach and high stepping

- Added smoothed, controlled two-bone IK stretch up to 1.14x when the planted foot approaches the natural thigh-plus-shin reach. Both bones scale along their authored chain axes, so attached limb meshes follow the extended skeleton. Stretch eases back toward neutral and resets when IK ownership ends or ragdoll/other pose ownership takes over.
- Increased swing/recovery foot arc height to 0.30 m, thigh swing to 46 degrees, knee flex to 68 degrees, and forward knee-pole guidance to make each step lift more visibly before extending toward landing.
- Added M8 assertions for stretch/lift tuning and the farther reachable IK target.
- No scene files changed. Godot tests and in-game behavior have not been executed by the assistant.
