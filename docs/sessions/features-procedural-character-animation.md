# Session memory: Procedural Character Animation

Branch: `features/new-reactive-hands-and-viewport`
Status: REFERENCE / PARTIALLY COMPLETE — hand pose-priority and target-driven hand foundations are retained; multiplayer hover/poke synchronization was subsequently fixed and user-verified. Remaining hand polish is not a blocker for the next feature.
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

The earlier host/client hover-pointing and poke visibility issue described above has since been fixed. The user explicitly confirmed that both multiplayer hand synchronization and the in-game behavior now work. Keep the existing diagnostics and tests as regression tools; do not reopen the old networking issue unless it regresses.

Remaining hand work is visual/pose polish rather than the old RPC delivery blocker. The next feature continues the broader procedural-character direction with combat presentation and procedural leg movement, while preserving the hand foundation and ragdoll ownership rules.

## Ownership and constraints

- Never animate the physical skeleton while ragdoll simulation or recovery owns it.
- Keep first-person viewmodel and remote world-hand adapters distinct where their coordinate spaces differ.
- Carry/guard/combat states must suppress hover; limp must suppress all standing hand animation.
- Do not transmit per-joint transforms for ordinary procedural poses.
- No scene tree or mesh changes in this first slice.
- Assistant cannot run Godot here; do not claim runtime tests passed until the user runs them.
