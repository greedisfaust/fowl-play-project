# Session plan: Combat & Procedural Legs (Movement)

Branch: `features/combat-and-procedural-movement`
Status: ACTIVE — rig audit and first gait slice completed; hybrid locomotion refinement underway; Godot execution and visual verification pending.
Created: 2026-11-20
Previous baseline: `features/player-identity-and-world-kit`

## Goal

Develop the next physical gameplay layer for Fowl Play: combat actions and expressive procedural leg movement. Combat owns gameplay outcomes; procedural animation communicates intent and locomotion. Preserve the existing player rig, hand system, carry/drop/throw behavior, multiplayer authority, and ragdoll/recovery lifecycle.

## First task — read-only rig audit

Before changing code or asking the user to modify scenes, inspect the current branch and document:

- Player scene and rig hierarchy, including Skeleton3D bones, BoneAttachment3D nodes, visual meshes, world hands, and first-person Viewmodel hands.
- Existing movement component, velocity/grounded data, camera pitch/yaw, and player state interfaces.
- PhysicalBone3D/ragdoll setup, collision policy, recovery blend, and the exact point at which standing animation may resume.
- Existing hand pose API and priority rules.
- Current combat-related scripts, InputMap actions, tuning values, tests, and debug watches.

Do not edit user-authored scenes or construct nodes in code. Confirm scene-open status before any scene handoff. The first audit should be read-only and should identify integration seams and risks before implementation begins.



## Read-only rig audit — 2026-11-20

Branch baseline: `features/combat-and-procedural-movement` initially matched `main` at merge commit `1506c03746e158c74ffcd2da5df042b20435db25`.

### Confirmed scene and skeleton contracts

- Player root: `CharacterBody3D`; camera path: `Head/Camera3D`; rig path: `Rig`; skeleton path: `Rig/Skeleton3D`.
- Player scene contains two camera-attached Viewmodel hands at `Head/Camera3D/ViewmodelHands/LeftHand` and `RightHand`. World hands are attached beneath `Rig/Skeleton3D/HandAttachment_L/HandMount_L/Hand` and the corresponding right-side path.
- Skeleton has 17 bones: Hips, Spine, Chest, Neck, Head, paired UpperArm/Forearm/Hand chains, and paired Thigh/Shin/Foot chains.
- Leg attachments already exist: `ThighAttachment_L/R`, `ShinAttachment_L/R`, and `FootAttachment_L/R`, with corresponding mesh/CSG visuals. No new leg skeleton or mesh construction is needed for the first procedural pass.
- Leg rest-chain offsets in the saved rig are approximately 0.42 m from thigh to shin and 0.42 m from shin to foot. Hips is the parent of both thigh chains.
- The rig has 11 PhysicalBone3D bodies: Hips, Chest, Head, paired UpperArm, Forearm, Thigh, and Shin. Feet and hands are non-physical skeleton bones. The PhysicalBoneSimulator is stopped and all physical-bone collision is disabled in the standing state.

### Movement and presentation integration

- Owner movement runs in `Player._physics_process`; horizontal movement is driven by `velocity`, `is_on_floor()`, and the existing Player transform basis. Current nominal speed is 5 m/s; jump speed 6.5 m/s; gravity 20 m/s².
- Mouse yaw rotates the Player root. Pitch is stored in `_pitch_radians` and applied to `Head.rotation.x`, clamped to ±85 degrees.
- Existing movement snapshots are sent at 20 Hz and contain position, velocity, yaw, and pitch. Remote Players apply interpolated position/velocity/yaw/pitch in `_process`. Grounded state is not currently included in the snapshot; if remote leg animation needs an exact grounded flag, add it to this existing movement message rather than creating a separate animation stream.
- The local owner's entire world Rig is hidden in normal first-person play (`rig.visible = false`); it becomes visible for limp/ragdoll. Therefore owner-view legs require selective visibility of existing lower-body visuals. Showing the whole Rig would reveal the upper body and hands and risk camera clipping.
- The rig's existing `_process` is responsible for remote ragdoll interpolation and recovery animation. Standing leg pose evaluation must not run during either mode.

### Ragdoll and recovery ownership

- `Player.begin_host_limp()` calls `Rig.begin_host_simulation()` before setting `is_limp`. The rig captures the standing skeleton pose, disables procedural arm IK, exposes world hands, becomes top-level, enables host collisions, and starts PhysicalBoneSimulator3D.
- During limp, Player movement physics is suspended. A carried limp body remains under the existing carry-support controller.
- Recovery moves the Player capsule to a host-selected clear position, calls `stop_host_simulation_with_blend()`, then sets `is_limp = false` and `is_recovering = true`.
- Rig recovery stops physical simulation, restores skeleton ownership, and blends from the final ragdoll pose into the captured standing pose or the selected authored recovery clip. `Player._process` waits until `Rig.is_pose_blending()` is false before `_finish_recovery()` clears `is_recovering`.
- Procedural standing legs may resume only after that Player-level recovery handoff has completed, not merely when physical simulation stops.

### Existing hand and animation contracts

- `Hand.set_guard(active)`, `set_limp(on)`, `set_carrying(...)`, and action APIs already exist.
- Hand pose priority is implemented as: Limp > Carry > Guard > Reach > Point > Idle. Combat must use the existing Guard API and must not bypass higher-priority limp/carry states.
- First-person Viewmodel hands and world-rig hands are separate instances with different coordinate spaces. Preserve the existing adapters and arm IK target mapping.

### Combat readiness and gaps

- InputMap already defines `punch` on Q. `parry` on F is not yet defined.
- `Tuning` already contains preliminary punch, charge, lunge, parry, and cooldown constants, but no combat implementation exists.
- No `core/combat.gd`, `core/legs.gd`, M7 combat test, or M8 procedural-leg test exists in this branch. The existing debug category names are reservations, not evidence of implemented systems.
- `Player._unhandled_input` currently leaves non-carrying Q available for the future combat handler; while carrying, Q is reserved for the existing Carrier drop/throw behavior.
- Combat rules and open decisions remain governed by `docs/PROJECT_OVERVIEW.md` §9. In particular, do not implement punches against already-limp bodies or impact/wall-slam feedback without resolving the open decisions with the user.

### Initial implementation constraints

1. Keep the Player root and all network paths stable; do not reparent Player nodes.
2. Evaluate cosmetic leg poses locally from existing movement data. If grounded state must be replicated, extend the existing 20 Hz movement snapshot.
3. Keep the procedural leg controller out of the ragdoll pose-stream/recovery ownership path; use a dedicated, testable controller and an explicit standing-state gate.
4. Preserve the current 11-body ragdoll setup and all existing collision policies.
5. Owner-view legs must be shown selectively without exposing the hidden upper body.
6. Add tests, DebugHub watches/commands, and documentation alongside each implementation slice. No tests or in-game visuals are claimed verified by this audit.



## Implementation slice 1 — velocity-driven procedural gait

Commit: this implementation slice is recorded in the feature branch history.

Implemented:
- Added a pure `RefCounted` gait controller that advances its phase from horizontal travel distance, alternates left/right leg swing, bends the knee during swing, and counter-rotates the foot.
- Gait direction is transformed into Player-local space, so the swing plane follows forward/backward and lateral movement.
- Gait weight blends in/out smoothly and freezes its step phase while airborne.
- PlayerRig applies the six target rotations to the existing Thigh/Shin/Foot bones only while standing.
- The controller resets when host or remote ragdoll ownership begins. Procedural updates are rejected during physical simulation, remote ragdoll playback, and recovery blending.
- Existing 20 Hz movement snapshots now include the owner's grounded flag. This is a small addition to the existing movement packet, not a new animation stream or extra per-frame RPC.
- Added an M8 headless test and movement-stream grounded-transition assertions; registered the new stage in `run_checks.ps1`.
- Added DebugHub watch `rig/<name>/legs_active` and command `leg_status_<player>`.
- Centralized the gait's stride distance, speed threshold, swing angles, foot counter-rotation, and blend response in `core/tuning.gd`.

Not included yet:
- Foot planting / ground raycasts and skating refinement.
- Acceleration/deceleration shaping, turn-in-place, and directional transitions.
- Owner-view selective leg visibility and fade behavior.
- Combat implementation.

Verification:
- Code and tests are authored but have **not** been run in Godot by the assistant. Import, headless tests, and in-game host/client visual checks remain pending.
- The first visual checkpoint should use two instances: each peer should see the other peer's legs animate while walking/strafe, and neither peer should see procedural leg motion during ragdoll or recovery.

## Combat scope

Planned gameplay actions:

1. Jab with readable anticipation, extension, contact/recoil, and recovery.
2. Charged punch with charge anticipation, release, lunge, cooldown, and re-arm behavior.
3. Guard and parry with clear upper-body/hand presentation and the already-decided attacker outcomes.
4. Host-authoritative hit validation and gameplay results; cosmetic pose intent is replicated/derived without streaming every joint transform.

Existing design decisions to preserve unless the user explicitly changes them:

- `punch` is Q; `parry` is F.
- A quick punch tap performs a jab; holding charges a punch and auto-fires at 1.0 s.
- Movement remains full speed during wind-up.
- Releasing before 1.0 s cancels without a punch or penalty.
- A parried charged punch makes the attacker limp; a parried jab causes recoil only.
- Combat gameplay outcomes remain host-authoritative.
- Whether punches affect already-limp bodies and whether impact/wall-slam feedback is included remain open decisions; ask before implementing either.

## Procedural legs and movement scope

Planned presentation:

- Procedural walk/run cycle driven by actual movement velocity and grounded state.
- Foot lift, swing, planting, and stance timing with smooth transitions when starting, stopping, strafing, and turning.
- Stable foot placement relative to the ground where practical; avoid visible skating and abrupt snapping.
- Owner-view leg visibility follows the existing decision: legs are hidden while looking down and fade smoothly back in when looking forward.
- Cosmetic leg pose calculation should be local and produce zero additional network traffic; replicate gameplay movement state, not every joint transform.
- Limp/ragdoll simulation owns the body during knockdown. Procedural standing legs must not fight PhysicalBone3D simulation or recovery. Resume only after the existing recovery lifecycle releases ownership.

## Shared animation principles

- Gameplay state determines intent; procedural animation expresses it.
- Preserve the existing hand pose-priority foundation: limp > carry > guard > reach > point > idle.
- Keep first-person viewmodel and world-rig presentation adapters separate where their coordinate spaces differ.
- Prefer compact intent/targets and local procedural evaluation over per-joint network replication.
- Use typed GDScript and keep the Player script as a thin coordinator.
- No scene hierarchy, mesh, or collision-shape generation by script.
- Do not replace the existing interaction, carry, networking, or ragdoll systems with parallel implementations.

## Suggested implementation order

1. Read-only rig and movement audit; record actual node paths and integration contracts.
2. Define procedural leg controller boundaries and a testable pose/grounding model.
3. Implement idle/standing and basic walk cycle locally.
4. Add start/stop, strafing, turning, and foot-plant refinement.
5. Integrate owner-view leg visibility and verify first-person clipping.
6. Implement combat gameplay slices (jab, charged punch/lunge, guard/parry) with tests and host/client validation.
7. Integrate combat hand/arm/body presentation without overriding limp, carry, or recovery priorities.
8. Run multiplayer and ragdoll regression matrix; update docs and commit each isolated slice.

The exact order between leg movement and combat implementation can be adjusted after the rig audit if one integration dependency is discovered.

## Verification requirements

- Focused headless tests for pose priority, timing/state transitions, grounding, and deterministic local procedural targets.
- Host/client tests for combat requests, sender ownership, hit validation, parry outcomes, cooldown/re-arm, and disconnect cleanup.
- Confirm procedural leg animation adds no per-frame network traffic.
- In-game checks for foot sliding, clipping, camera pitch visibility, start/stop transitions, ragdoll takeover, and recovery handoff.
- Two-instance host/client checks for jab, charged punch, lunge, guard, parry, knockdown, carry, throw, and recovery.
- Do not mark any test or visual check complete unless it was actually run or explicitly confirmed by the user.

## References

- [Project technical/design authority](../PROJECT_OVERVIEW.md)
- [Current project state](../PROJECT_STATE.md)
- [Player rig construction plan](../PLAYER_RIG_DESIGN.md)
- [Hand design reference](../HAND_DESIGN.md)
- [Procedural Character Animation session](features-procedural-character-animation.md)
- [Carry / drop / throw session](features-carry-drop-throw.md)
- [Ragdoll and physics session](features-player-rig-and-physics-implementation.md)


## Implementation slice 2 — smoothed locomotion transitions

Commits:
- `3a63c99` — smooth procedural leg movement transitions
- `012f757` — centralize leg velocity response tuning
- `b0a491c` / `1aa9976` — cover smooth start/stop and turning transitions

Implemented:
- Added a filtered horizontal velocity to the local gait controller. Sudden direction changes now blend through the previous movement direction instead of instantly rotating the swing plane.
- The gait phase and stride amplitude use the filtered speed, so starting and stopping ease into and out of movement rather than reacting to raw velocity in one frame.
- Added `LEG_VELOCITY_RESPONSE` to centralized tuning.
- Extended M8 checks for blended directional changes and gradual stopping.
- Kept all evaluation local; no additional network messages, scene changes, or new rig nodes.

Not included:
- This is still not final locomotion. It does not yet solve foot planting, ground contact, turn-in-place, owner-view lower-body visibility, or combat-driven balance reactions.
- Hybrid physics reactions during active combat will be integrated with the combat/knockback state later. Existing full ragdoll ownership remains unchanged.

Verification:
- The code and test assertions are committed but have **not** been executed in Godot by the assistant. Steam Godot editor import and runtime checks remain required.


## Implementation slice — settle both feet after stopping

Commits:
- `f6f5e63` — settle procedural legs into stance when stopping
- `b273e68` — cover double-stance gait settling

Implemented:
- The previous gait phase froze as soon as filtered movement fell below the walk threshold. If that happened during swing, the foot tracker could retain a halfway-through-swing target even after the character became idle.
- The controller now advances the remaining phase at a restrained settling rate toward the shared double-stance phase (`PI`). At that phase, both feet are in stance; the motion blend continues easing to neutral.
- Added a regression check that begins from mid-swing, stops the controller, and verifies both feet reach stance and the phase settles at `PI`.
- No scene, node hierarchy, collision shape, or network changes.

Verification:
- Source and regression assertions are committed. Godot execution and rendered visual verification have not been run by the assistant and remain required.

Remaining ground-contact refinements:
- Calibrate the target against the actual shoe sole/foot attachment geometry rather than assuming the foot bone origin is the ground-contact point.
- Align the foot orientation to the detected surface normal and tune the stance/swing transitions in-game.


## Implementation slice — stable foot contact refinement

Implemented:
- A swing captures its landing target once at lift-off. The target no longer drifts as the per-frame ground probe moves with the character's velocity lead.
- On landing, stance locks to that captured landing point instead of the newest probe result, preventing a final-frame foot snap.
- During stance, the foot bone blends its orientation toward the detected ground normal. During swing, the existing gait toe-lift/foot articulation remains in control rather than being flattened by the ground normal. Flat ground settles the planted foot toward level; walkable slopes tilt it with the surface.
- `leg_ground_<player>` now reports each foot's locked anchor alongside its current target, hit state, IK weight, and surface normal.
- M8 tests cover a moving ground-probe target during swing and verify that the captured landing point remains stable.

Verification:
- Source and regression assertions are committed; Godot execution and in-game visual checks have not been run by the assistant. The user should verify planted shoes, slope alignment, swing clearance, and stopping behavior after pulling.


### Predictive stepping refinement — 2026-11-20

- Replaced the fixed 0.12 m forward ground-probe lead with a predictive lead equal to the root travel over the gait's swing fraction (`LEG_STEP_CYCLE_DISTANCE_M * (1 - LEG_STANCE_FRACTION)`).
- The swing foot now probes where the character will be when that foot lands, rather than probing almost directly beneath its current trailing position. The captured landing target remains stable throughout swing and stance.
- This directly addresses the user's playtest report that planted feet appeared to trail/drag behind the moving player.
- Godot execution and in-game verification remain pending; user should check forward/backward movement, strafing, and changes of direction after pulling.


## Implementation slice — responsive jump movement

Commits:
- `5d69021` — add responsive jump movement tuning
- `88c8814` — add buffered variable-height jump controller
- `7b20973` — integrate responsive jump movement into Player
- `79a49ed` — cover coyote time, jump buffering, jump height, and air steering
- `447dae2` — document jump diagnostics and playtest
- `edadaf7` — record project state

Implemented:
- Added a dedicated pure `JumpController` that tracks a 0.10 s coyote window and a 0.12 s jump-input buffer.
- Jump input pressed shortly before landing is retained and consumed on the first grounded physics update. Input pressed just after walking off a ledge is accepted while the coyote timer remains.
- Releasing jump during upward travel scales the remaining vertical velocity by 0.45, producing a shorter hop; holding jump preserves the full 6.5 m/s launch.
- Horizontal acceleration and deceleration are reduced to 55% while airborne. This preserves more horizontal momentum without removing midair steering.
- Player physics remains the owner of gravity, collision, and movement. Console/terminal locks continue blocking new jump input.
- Added local watches for remaining coyote and buffered-input time. No new RPCs, movement fields, scene edits, or Input Map changes were introduced.
- Extended the existing M3 movement test with timing, landing-buffer, jump-release, held-jump, and air-control assertions.

Verification:
- The assistant has not run Godot import or automated tests. The new M3 assertions are authored but unexecuted.
- User playtest should cover short/full hops, coyote timing, pre-landing buffered jumps, air steering, and two-instance jump replication.
- Sprint Input Map setup remains an editor task: add the `sprint` action and bind Left Shift before testing the previous walk/run slice.
