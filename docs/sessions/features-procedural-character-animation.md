# Session memory: Procedural Character Animation

Branch: `features/new-reactive-hands-and-viewport`
Status: IN PROGRESS — first procedural hand pose-priority refactor committed; runtime verification pending
Last updated: 2026-11-19

## Feature scope

The user approved a unified Procedural Character Animation feature with three coordinated areas:

1. Procedural hands
2. Procedural legs
3. Procedural body coordination

Combat presentation is included as a consumer of this framework: jab, charged-punch anticipation/release, guard/parry, recoil, and lunge body language. Gameplay systems remain authoritative for charge timing, hit detection, damage, movement and network validation. Animation expresses intent; it never decides whether an attack hits.

Core principle: gameplay decides what the character intends to do; procedural animation decides how the character expresses it. Prefer replicating compact intent/targets and calculating poses locally over streaming every joint transform. Existing hand meshes, finger scenes, attachment points, interaction logic, carry behavior and ragdoll lifecycle should be preserved.

## First implementation: procedural hands

The existing `fowl-play/hands/hand.gd` already animates finger and thumb Node3D transforms procedurally. Its former pose selection was spread across multiple boolean checks in `_process`, making priority and remote presentation difficult to reason about.

Committed first refactor:
- Added a `PoseState` enum: IDLE, POINT, REACH, GUARD, CARRY, LIMP.
- Centralized pose selection in `_resolve_pose_state()`.
- Explicit priority: limp > carry > guard > reach > point > idle.
- Finger curl, index aim, thumb pose, and hand-root offsets now consume the same resolved pose for each frame.
- Hand status debug output includes the resolved pose name.
- Preserved the existing public setters and boolean fields so focus, carry, guard and ragdoll integrations do not need API changes.
- Extended M2 checks for pose priority and M3 interaction checks to wait for remote world-hand pose blending and inspect finger return.

Commit: `refactor: centralize procedural hand pose priority` (2d9a99d).
Test commits: `test: cover procedural hand pose priority`, `test: assert remote pointing finger pose`, and `test: verify remote procedural hand pose playback` (see branch history).

## Current diagnosis and next steps

The user observed that hover RPC counters and remote `hover=true` state update continuously, while the remote world hand still does not visibly point reliably in either host/client direction. Both world hands are visible in idle. This points to a pose/render/attachment problem rather than missing hover messages.

The pose-priority refactor is a foundation, not yet a confirmed fix. Next:
1. User pulls and runs the Godot test suite plus two-instance visual check.
2. If remote pose state is correct but rendering still fails, inspect actual hand node transforms, attachment transforms, and world/viewmodel orientation; add focused diagnostics rather than changing networking blindly.
3. Confirm spam-click reach returns smoothly to point/idle.
4. Add explicit procedural pose targets/transitions only after the current geometry and transforms are measured.
5. Later integrate carry grip, combat hand/arm intents, body coordination, and procedural legs without letting these overwrite ragdoll ownership.

## Ownership and constraints

- Never animate the physical skeleton while ragdoll simulation or recovery owns it.
- Keep first-person viewmodel and remote world-hand adapters distinct where their coordinate spaces differ.
- Carry/guard/combat states must suppress hover; limp must suppress all standing hand animation.
- Do not transmit per-joint transforms for ordinary procedural poses.
- No scene tree or mesh changes in this first slice.
- Assistant cannot run Godot here; do not claim runtime tests passed until the user runs them.
