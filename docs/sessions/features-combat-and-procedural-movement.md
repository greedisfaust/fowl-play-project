# Session plan: Combat & Procedural Legs (Movement)

Branch: `features/combat-and-procedural-movement`
Status: ACTIVE — M7.1 jab and M7.2 presentation are user-playtested; M7.3 charged-punch refinements and M7.4 parry are implemented in source and awaiting Godot verification; procedural gait refinement continues.
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
- Combat rules and open decisions remain governed by `docs/PROJECT_OVERVIEW.md` §9. The user's 2026-11-20 decisions approve limp-player physical reactions without recovery reset, hybrid slapstick presentation, two physical reaction levels (Weak/Strong), restrained impact effects and camera response, and deferred audio. Dedicated wall-slam feedback remains open.

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
- While idle, releasing Q strictly before 1.0 s performs a jab; reaching 1.0 s while still held automatically fires the charged punch. Q must be released to re-arm, and the host enforces the 2.0 s charged-punch cooldown.
- The carrier retains its separate Q timing: `TAP_MAX_SECONDS` distinguishes a quick drop from throw-charge feedback, while `THROW_AUTO_FIRE_SECONDS` controls auto-throw. Combat timing must not repurpose either carrier rule.
- Movement remains full speed during charge. The 0.5 s lunge owns movement while active; use, grab and parry remain blocked through the charged-punch recovery lock.
- A parried charged punch makes the attacker limp; a parried jab causes recoil only.
- Combat gameplay outcomes remain host-authoritative.
- A jab may physically impulse an already-limp body without resetting or extending recovery; charged lunge targets standing players only. Impact/wall-slam feedback remains open for a later decision.

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
- Releasing jump during upward travel scales the remaining vertical velocity by 0.45, producing a shorter hop; holding jump preserves the full 6.5 m/s launch. A buffered press released before landing still triggers on landing, but retains the short-hop behavior.
- Horizontal acceleration and deceleration are reduced to 55% while airborne. This preserves more horizontal momentum without removing midair steering.
- Player physics remains the owner of gravity, collision, and movement. Console/terminal locks continue blocking new jump input.
- Added local watches for remaining coyote and buffered-input time. No new RPCs, movement fields, scene edits, or Input Map changes were introduced.
- Extended the existing M3 movement test with timing, landing-buffer, jump-release, held-jump, and air-control assertions.

Verification:
- The assistant has not run Godot import or automated tests. The new M3 assertions are authored but unexecuted.
- User playtest should cover short/full hops, coyote timing, pre-landing buffered jumps, air steering, and two-instance jump replication.
- Sprint Input Map setup remains an editor task: add the `sprint` action and bind Left Shift before testing the previous walk/run slice.


## 2026-11-20 — movement feel calibration follow-up

- Added a separate turn acceleration response of 24 m/s² for sharp direction changes. The existing 14 m/s² normal acceleration and 18 m/s² deceleration remain unchanged; turn response is only selected when current velocity and input direction differ by more than the configured 0.75 dot threshold. This keeps acceleration and momentum while reducing the car-like delay when steering around or reversing.
- The same turn response is scaled by the existing air-control multiplier while airborne.
- Recalibrated procedural leg swing intensity against sprint speed (8 m/s), not walk speed (3.8 m/s). At ordinary walking speed the stride and knee bend are now less exaggerated; the full stride builds as actual speed approaches sprint. Gait cadence, foot planting, and the existing planner/replant system are retained.
- Increased jump launch speed from 6.5 to 6.9 m/s. Gravity, coyote time, jump buffer, and variable-height release remain unchanged, giving a modestly higher/full jump without altering short-hop behavior.
- Added regression assertions for faster-but-blended reversals, lower walking stride intensity, stronger sprint stride, and the revised jump tuning.
- Godot tests and in-game visual behavior have not been run by the assistant; user playtesting is still required.


## 2026-11-20 — grounded walking and energetic sprint profile

- Reworked the gait controller so walking is not merely a smaller sprint. It now has a longer cycle distance (1.6 m), shorter stance fraction (0.56), smaller 24-degree thigh swing, gentler 30-degree knee flex, and 0.09 m normal foot arc.
- Sprint blends continuously toward the established 1.4 m cycle, 0.58 stance fraction, 46-degree thigh swing, 68-degree knee flex, and 0.20 m normal foot arc. Emergency replant remains a distinct 0.30 m recovery step.
- Foot planting, moving-platform anchors, IK, strafing, and rapid-direction response remain in place. M8 now asserts separate walk/run profiles and reach-safe stance travel. No scene files changed. Godot tests and in-game verification remain pending.

## M7.1 — Jab foundation

Implemented on `features/combat-and-procedural-movement`:

- Added `fowl-play/combat/combat_controller.gd` for local Q press/release routing and `combat/combat_hit_detector.gd` for host-side obstruction-aware ray detection. `combat/combat_presentation.gd` coordinates the first-person/remote Viewmodel fist pose.
- Q is routed to combat only when the player is not carrying. Carrier drop/throw remains unchanged.
- The host owns the press timestamp, 0.25 s tap window, 0.35 s jab cooldown, camera direction, 2.5 m ray and 0.1 s active window.
- Standing targets receive a weak movement recoil. Limp targets receive a host-only physical-bone velocity impulse; the limp lifecycle and recovery timer are not touched.
- Added a curled-fist pose to `Hand` with the existing hand pose-priority system. Carry, guard and limp continue to override it.
- Added `m7_jab_test.gd` and the `m7-jab` stage to `tests/run_checks.ps1`; added combat counters and M7.1 diagnostics to `docs/DEBUG.md`.
- No `.tscn` or user-authored scene hierarchy changes.
- Tests have not been run in Godot in this environment. Host/client and rendered pose behavior remain for user playtest.

### M7.2 — procedural jab animation and weak reaction

Implemented:
- `CombatPresentation` now owns a short fist pullback and anticipation → extension/follow-through → return pose curve for the Chest bone, plus a brief weak target recoil pose.
- The right hand stays curled through the extension/return, then releases to its ordinary pose. Its offset eases continuously from the wind-up pullback through extension and back to its authored rest position; the existing action lifecycle still drives the wrist target.
- `Player._process` advances combat presentation before procedural leg and arm IK. `PlayerRig.set_combat_body_pose()` applies the Chest pose; the following arm IK pass then solves from the rotated shoulder.
- The existing host-approved wind-up/jab events are used for remote presentation. The pose is evaluated locally; no per-joint network stream is introduced.
- Added deterministic jab/recoil pose-curve assertions to `m7_jab_test.gd` and kept the focused `m7-jab` test stage.
- Carry, limp, ragdoll and recovery remain higher priority. No scene hierarchy changes.

Not included yet: charged punch, lunge, parry, strong stumble/collapse, camera response, feathers, impact VFX and audio.

Verification: source and assertions are committed but have not been run in Godot here. The user should verify first-person fist timing, remote torso motion, movement blending, and pose cleanup on carry/limp transitions.


### M7.2 follow-up — boxer-like jab timing

- Shortened the procedural body/hand jab pose to 0.34 s: 0.11 s fast extension, 0.035 s brief contact hold, then smooth retraction.
- Made anticipation and torso follow-through more compact, with the fist reaching extension quickly and returning to its authored rest offset.
- Gameplay timing, host validation, hit detection, cooldown, and weak reactions are unchanged. No scenes changed.
- Added a regression assertion for the compact jab timing. Run `./tests/run_checks.ps1 -OnlyStage m7-jab` (PowerShell: `.\tests\run_checks.ps1 -OnlyStage m7-jab`). Godot execution and visual playtest are pending.


### M7.2 follow-up — boxer jab timing and torso spring recoil

Implemented:
- Shortened the jab pose from 0.30 s to 0.21 s (about 43% faster), with a 0.058 s extension and 0.018 s contact hold.
- The fist and torso use a decisive ease-out extension into contact, followed by a smooth recovery to the authored resting pose.
- Replaced standing-player knockback with a visual-only upper-torso spring response: an immediate chest snap, controlled overshoot, and progressively damped bounces over 0.48 s. A Weak jab no longer changes player-root movement or locomotion velocity.
- Kept the host-authoritative impact multiplier (1.0×–1.35×) to scale the torso response. Limp targets still receive the existing physical-bone impulse; their recovery lifecycle is unchanged.
- Updated M7 jab regression checks to verify the spring overshoot, faster timing, and absence of player-root displacement. No scene hierarchy changes.

Verification:
- Added assertions for the faster jab timing, clear recoil, bounded impact scaling, and directional velocity projection.
- Godot tests and rendered host/client playtest have not been run by the assistant. Run ` .\tests\run_checks.ps1 -OnlyStage m7-jab` from `fowl-play/`, then test stationary, forward-moving, sideways-moving, and retreating jabs in two instances.


## M7.3 — charged punch and lunge (initial implementation)

Implemented in source on `features/combat-and-procedural-movement`:
- Replaced the old 0.25 s jab cutoff: Q release strictly before 1.0 s produces a jab; at 1.0 s while still held the host auto-fires the charged punch. The charged press is consumed; Q release re-arms the next press.
- The host owns the hold timer, charged cooldown, action lock, hit query and knockdown result. The owning player drives the lunge at 12 m/s for 0.5 s and steers toward camera look at no more than 3 rad/s.
- The host re-queries a 0.55 m radius capsule along the attacker's current aim each physics tick, with world/prop obstruction filtering. Every distinct standing player inside the unobstructed capsule volume enters the existing host-owned limp lifecycle; a miss expires harmlessly.
- Use/grab are rejected while Q is held and during the 2.0 s charged-punch recovery lock. `can_start_parry()` exposes the same gate for the future parry implementation; parry itself is not part of this slice.
- Added a separate charged-lunge hand/torso presentation and regression assertions for charge timing, auto-fire while held, re-arm behavior, lunge steering and action locks.
- Existing Q carry/drop/throw routing is preserved; no scenes or user-authored hierarchy were changed.

Verification:
- The assistant has not run Godot import, headless checks or in-game tests in this environment. Run `.\tests\run_checks.ps1 -OnlyStage m7-jab` from `fowl-play/`.
- Playtest idle releases at 0.99 s and exactly 1.00 s, charge while moving, lunge hit/miss/obstruction, steering, recovery lock, carry Q drop/throw, and two-instance host/client replication.
- Important first-playtest question: the initial lunge hit volume uses a 3.5 m capsule length and 0.55 m radius. Tune its reach/shape only after seeing the actual feel; do not add more input mechanics yet.


## 2026-11-20 — charged punch anticipation and release presentation refinement

Implemented:
- Reworked the existing host-approved Q wind-up into a progressive one-second charge pose instead of a short exponential lean that plateaued early.
- The torso now gradually leans farther back, twists into the loaded shoulder, and adds a restrained directional roll as the hold approaches the charged-punch threshold.
- The fist progressively draws inward and back while lifting, with a small tension accent through the middle of the charge.
- The charged lunge now begins from the fully loaded torso and fist pose, then drives forward into its existing follow-through. This avoids snapping back toward a neutral pose at release.
- The existing early-release jab still transitions into its established jab animation. Gameplay timing, lunge movement, hit detection, cooldowns, action locks, and networking are unchanged.
- Added deterministic pose-curve assertions for progressive torso loading, fist retraction, and continuous loaded-pose-to-lunge transition.
- No scene files, rig hierarchy, meshes, or collision shapes changed.

Verification:
- Source and regression assertions are committed, but Godot import/headless checks and rendered first-person/remote visual playtesting have not been run by the assistant. Run ` .\tests\run_checks.ps1 -OnlyStage m7-jab` from `fowl-play/`, then inspect the full one-second wind-up, early-release jab, charge-to-lunge transition, and remote player presentation in two instances.


## M7.3 refinement — charged-punch wind-up and launch direction

- Strengthened the existing one-second anticipation pose: the torso now builds a deeper backward lean, more pronounced twist and counter-roll while the fist draws farther back and lifts. The release transitions directly from that loaded pose into a more committed forward follow-through.
- Charged-lunge hits now derive their launch direction from the actual attacker-to-impact vector instead of a fixed forward vector. The horizontal launch follows the side/front angle of contact; elevation responds modestly to strike pitch and relative impact height.
- Added bounded launch tuning at 10.5 m/s with a capped elevation component. The host starts the target's existing limp lifecycle first, then applies the impulse to the newly simulating physical rig so the handoff's initial velocity reset cannot erase the hit.
- Added regression assertions for stronger full-charge pose progression, fist draw-back, side-angle launch direction, pitch-sensitive elevation, and the launch elevation cap.
- Godot headless checks and in-game/multiplayer verification remain pending; this commit has not been run in the Godot runtime by the assistant.


## M7.4 — host-authoritative parry and cylindrical barrier

- F submits a parry intent through the same host-authoritative input path used by combat. The host validates the active player, action locks, carrying/carried state, limp/recovery state, terminal movement lock, and parry cooldown.
- The active parry window is 1.25 seconds. If no punch arrives, the state expires and starts a 1.5-second cooldown. A successful reflection also starts the 1.5-second cooldown immediately.
- Both quick jabs and charged lunges are reflected. The defender remains standing; the attacker enters the existing host-simulated limp lifecycle and receives a bounded impulse away from the defender. Charged punches do not overpower parry.
- Parry blocks starting another punch and blocks interactions while its active window is open. It cannot start during a held/charged punch, charged recovery, active jab, carry, carried state, limp, recovery, terminal movement lock, or parry cooldown.
- The procedural parry stance raises both existing Viewmodel hands through their Guard pose and adds a restrained defensive torso lean. No scene hierarchy or authored animation assets are required.
- Added a runtime-generated, full-height transparent cylinder barrier (2.12 m tall, 0.82 m radius) with animated scan/rib patterns, top/bottom energy rings, an expanding activation, a localized contact ripple, and a short dissolve. It is cosmetic only; host combat logic, not the visual mesh, decides whether a punch is reflected.
- Host-approved start, hit and end events replicate the stance and barrier to remote players. net/combat_parries, net/combat_parry_rejected, and net/combat_parries_active expose host-side diagnostics.
- m7_jab_test.gd now checks the 1.25/1.5-second timing, full-height barrier dimensions, defensive pose, successful jab reflection, defender protection, attacker limp handoff, and failed-window cooldown.
- Godot headless checks and rendered host/client playtesting remain pending. The assistant has not run Godot for this implementation.


### 2026-11-20 — parry barrier color, energy material, and boxer guard polish

- The runtime cylindrical barrier now receives the player identity color from the same network-backed `PlayerIdentity` used by the rig, hands, cursor, and nameplate. Its emissive tint is brightened toward white to keep dark palette entries readable without changing the identity color.
- Refined the translucent shell with denser animated scan lines, narrow vertical energy streams, a moving weave, a stronger view-angle rim, and a brighter localized impact response. The two light rings are thinner, and the upper ring sweeps from the bottom to the top during the 0.18 s activation.
- Preserved the existing closed-fist guard curl and smooth pose blending. Both Viewmodel fists now rise farther and move inward toward the centerline, with the wrist rotated farther forward so the back/knuckle side faces an opponent approaching from the front.
- Parry timing, cooldown, host-authoritative hit/reflection rules, replication, and barrier dimensions are unchanged. No scene files or user-authored hierarchy were edited.
- Verification: source changes and existing regression checks are committed, but Godot import/headless checks and rendered host/client visuals have not been run by the assistant. The user should inspect fist orientation from first-person and opponent views, especially the mirrored left hand, and confirm whether project WorldEnvironment glow is enabled for bloom.


### 2026-11-20 — charged punch reach/knockback and parry visual calibration

- Increased charged-punch ragdoll launch velocity from 10.5 to 31.5 m/s (3×), leaving the existing angle-aware launch direction and parry-reflection velocity unchanged.
- Tightened the charged-lunge hit capsule from 3.5 m reach / 0.55 m radius to 1.75 m reach / 0.22 m radius. Lunge movement remains 12 m/s for 0.5 s; only the hit query volume was reduced.
- Corrected the guard wrist pose by rotating the hand around its local length axis to flip the visible hand face without reversing the finger direction. The earlier extreme pitch was removed. Both mirrored hands retain the same guard pose values.
- Reduced the barrier shader brightness and alpha, slowed the internal energy pattern, lowered the ring emission/opacity, and reduced the white blend in the selected player color. The intent is a stylized colored energy shell with defined details rather than a blown-out light source. It remains a translucent cylinder with moving energy rings and a localized impact ripple.
- Regression checks now cover the new launch/reach/radius tuning, restrained ring settings, and corrected guard-axis rotation. No scene files or authored hierarchy changed.
- Verification: source and tests are committed, but Godot checks and in-game visuals have not been run by the assistant. Confirm the knuckle face from the opponent view, actual punch contact distance, ragdoll launch stability, and barrier brightness in the arena.


## M9 — multiplayer lifecycle hardening

- Late join synchronization now has two explicit paths: active limp players receive the existing ragdoll begin/final-pose stream; non-limp players receive a reliable standing capsule baseline containing position, velocity, yaw, pitch, and grounded state. The baseline uses the latest known movement sequence so a delayed reliable snapshot cannot rewind a newer unreliable movement update.
- Recovery intentionally synchronizes as a stable standing baseline at the host-approved recovery position. A late joiner does not replay a get-up animation from its midpoint, but it no longer sees the player at the spawn marker. Ordinary movement replication resumes when the host finishes recovery.
- Player-state baselines that arrive before the corresponding MultiplayerSpawner Player has completed _ready() are cached and applied after registration. Pending ragdoll state is applied first and retains ownership priority.
- Disconnect cleanup now clears the departing peer's combat wind-up, active jab/lunge/parry, cooldown, action-lock, and carry-action timing state. Host-owned active presentation is cancelled before those records are erased.
- Added m9-lifecycle focused checks for initial and deferred player-state application, invalid snapshots, and combat-state cleanup. Added a separate two-process late-join-during-recovery runner and registered it in the full test suite.
- Debug watches net/player_state_sync_sent and net/player_state_sync_received expose baseline delivery counts.
- Godot execution and rendered multiplayer verification have not been run by the assistant. Run tests/run_checks.ps1 -OnlyStage m9-lifecycle, then the full suite; the full suite includes tests/run_m9_late_join_checks.ps1.
### Charged-punch and parry vertical launch polish

- Charged punches and successful parries pass a dedicated extra vertical-velocity ratio into the host ragdoll impulse.
- The extra lift is additive to the existing directional knockback, preserving the established horizontal launch response. The shared tuning ratio is 0.18 (18% of configured launch speed).
- Ordinary jab impulses retain their previous baseline behavior.
- The existing charged launch direction's angle-responsive elevation remains unchanged.
- Godot execution and in-game verification have not been run by the assistant.



## M10 camera and owner-view polish — implementation slice 1

M10.1 adds a dedicated local-only `player/camera_presentation.gd` controller. It derives walking/running bob and lateral sway from local horizontal velocity, vertical camera pitch response while airborne, a landing compression pulse scaled by peak descent speed, and decaying directional impact offset/roll. The exported Player property `camera_motion_intensity` scales these effects (0–1.5, default 1.0). Standing combat recoil feeds the local camera impulse; no camera presentation state is replicated and gameplay authority is unchanged.

The existing simulated-head limp camera and recovery transform blend remain the owners of the camera during those states. Procedural movement camera effects are suspended during limp/recovery and reset after the recovery handoff. The camera transform is composed with its captured scene-local rest transform. The first visual tuning pass was too restrained (roughly 1–2.7 cm of vertical bob), so the follow-up increased ordinary walking motion, sprint scaling, strafing roll, and added a small gait pitch/roll. After user playtesting confirmed the motion was visible but slightly too intense, the locomotion-only bob, sway, and gait rotation were reduced to 75% of that pass (25% less intense); airborne, landing, and combat-impact responses retain their existing tuning. The ViewmodelHands are children of Camera3D and inherit the camera movement without a separate hand animation. Regression checks measure perceptible walking bob/rotation, strafing roll, and the 75% tuning in `tests/m10_camera_presentation_test.gd`; the `m10-camera` stage remains the focused test.

This is still the first M10 slice, not the complete milestone. Owner lower-body visibility/fade refinement and camera wall avoidance remain. The source and regression assertions are committed but have not been executed in Godot by the assistant; the user must run the focused stage and visual checks.


## M10.2 — first-person owner body visibility

- The local owner's rig stays active, but pelvis/torso, neck, head, arms, and world-hand attachments are hidden in normal first-person standing view. Camera-attached ViewmodelHands remain visible and continue to drive remote arm IK.
- The owner's legs and feet fade in smoothly as the camera looks down: hidden at the horizon, partial through the downward transition, and fully visible when looking toward the feet. GeometryInstance3D transparency is used without replacing materials or changing the authored rig hierarchy.
- Remote players retain the complete visible rig. Limp and recovery restore the full body presentation while keeping the owner's head hidden from the camera; normal owner-view filtering returns after recovery.
- Added the `m10-owner-view` focused regression stage for horizon, partial downward fade, full downward visibility, and upward-look behavior. No `.tscn` files changed.
- Godot execution and in-game visual verification have not been run by the assistant; owner and remote multiplayer presentation still require user playtesting.



## M10.3 — first-person camera collision and wall avoidance

- The local standing camera traces from the head pivot toward its composed desired camera position, including the authored rest offset and M10.1 bob/sway.
- The trace checks world-static geometry, devices, props, and elevators while excluding the owning Player RID and ignoring areas. It does not collide with other player bodies.
- On obstruction, the camera moves inward immediately and maintains 0.14 m clearance from the hit point. Once clear, it eases back toward the authored camera position rather than snapping outward.
- Collision is limited to the normal owner first-person presentation path; the existing limp simulated-head camera and recovery blend remain untouched. Recovery resets the obstruction controller. No scene hierarchy or scene files changed.
- Added the m10-camera-collision focused test for clear path, immediate obstruction response, smooth release, and reset.
- Godot execution and in-game visual/multiplayer verification have not been run by the assistant; test wall corners, pillars, props, elevators, and recovery camera handoff in-game.

