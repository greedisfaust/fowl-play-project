# Session: features/carry-drop-throw

## Goal

Implement M6 limp-player carry and throw without changing the working prop carry/drop/throw path or merging into `main`.

## Baseline

- Branch: `features/carry-drop-throw`
- Base commit: `316b0bca7a151b2f4c66936c9d87bb52ae28cd4c`
- Existing prop carry/drop/throw was confirmed working by the user.
- The baseline branch explicitly noted that limp bodies were not yet pickable.

## Implementation

- The Player scene's grab component is named `Interactable`; it is enabled only while limp and its availability predicate allows only a free limp player.
- The host applies a spring-damper force to the carried ragdoll's hips PhysicalBone3D toward the carrier's wall-adjusted carry anchor. The Player root is never moved or reparented; limbs remain simulated under gravity and joint constraints.
- Host collision on the carried ragdoll is disabled while held and restored on release. Remote peers continue rendering host pose snapshots and do not enable local ragdoll collisions.
- Remote clients receive a lightweight query-only StaticBody3D at the replicated hips so focus rays can target remote limp players without enabling remote PhysicalBone3D collision.
- Interaction validation and release placement use the ragdoll hips world position rather than the stale Player root position.
- The host suspends limp recovery while carried. Every drop or throw resets the recovery timer to a fresh 3.5 seconds, clears settled-pose state, and applies release velocity to the physical hips.
- The local owner's limp camera continues following the simulated head; mouse-look remains unchanged.

## Verification status

- Added `tests/m6_carry_test.gd` for offline pickup, no-root-teleport, support activation, collision toggling, timer suspension/reset, throw velocity, repeated pickup, and remote interaction proxy setup.
- Added the M6 test to `tests/run_checks.ps1`.
- This editing environment does not have Godot 4.7 installed, so the automated test has **not** been executed here. Do not mark M6 verified until the user runs the checks and performs the two-instance playtest.

## Required playtest

1. Host knocks down client; host grabs client with E; client sees body carried and can look around; limbs dangle.
2. Host taps Q to drop; client lands and remains limp for a fresh 3.5 seconds (subject to existing settled/hard-cap rules).
3. Host grabs the same client again before recovery, then holds Q to throw; the client sees the throw and recovery countdown restarts fresh.
4. Client knocks down host; client grabs host; host sees body carried and can look around; limbs dangle.
5. Client drops and re-grabs the host, then throws; both peers remain synchronized.
6. Confirm props still pick up, drop, and throw as before.

## Safety

- Do not merge into `main` without the user's explicit request.
- Preserve the existing authored get-up animation and host-authoritative ragdoll pose stream.
- Never enable local PhysicalBone3D collision on remote peers.
