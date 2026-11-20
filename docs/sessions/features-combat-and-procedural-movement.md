# Session plan: Combat & Procedural Legs (Movement)

Branch: `features/combat-and-procedural-movement`
Status: PLANNED — next feature approved by the user; implementation has not started.
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
