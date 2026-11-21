# Session: features/carry-drop-throw

## Goal

Implement M6 limp-player carry, drop and throw while preserving the working prop carry/drop/throw path. Work stays on `features/carry-drop-throw`; do not merge into `main` without the user's explicit request.

## Baseline

- Branch: `features/carry-drop-throw`
- Base commit: `316b0bca7a151b2f4c66936c9d87bb52ae28cd4c`
- Existing prop carry/drop/throw was confirmed working by the user.
- Limp bodies were not pickable at the baseline.

## Implementation

### Carry lifecycle and authority

- The Player scene's `Interactable` is enabled only while the player is limp, and its availability predicate allows only a free limp player.
- The host validates carry requests and owns carry/drop/throw state. The Player root is never moved or reparented.
- The carrier's `Carrier` component computes a wall-adjusted target from its `Head/Camera3D/CarryAnchor` and forwards the target and facing direction to the carried Player.
- The host suspends limp recovery while carried. Every drop or throw resets the recovery timer to a fresh 3.5 seconds, clears settled-pose state, and applies release velocity to the physical hips.
- The carried player's host collision mode is disabled while held and restored on release. Remote peers render host pose snapshots and do not enable local ragdoll physical-bone collision.
- Remote clients receive a query-only `StaticBody3D` at the replicated hips so focus rays can target remote limp players without enabling remote ragdoll collision.
- Interaction validation and release placement use the ragdoll hips world position rather than the stale Player root position.

### Carried ragdoll pose

- The Chest PhysicalBone3D is the carry anchor. A strong spring-damper force holds it near the carrier's target position; a damped three-axis torque controller keeps it upright and facing the carrier. It is actively stabilised, not frozen.
- The Chest target orientation accounts for the physical bone's bind-space basis so the visible torso faces correctly.
- The Hips, Head and limb bodies remain physically simulated. The Hips-to-Chest relationship and limb joints continue to provide the hanging ragdoll motion.
- Selective same-ragdoll collision exceptions are removed for opposite-side arm and leg pairs so the limbs can contact instead of passing through each other. Connected neighbours remain collision-exempt.
- Carried-only damping reduces repetitive arm/head oscillation. Head joint swing/twist limits are narrowed while carried and restored on release; original damping values are also restored.
- The carried player's local first-person camera continues to use the simulated Head eye transform. While carried, only the physics-driven camera position/rotation contribution is smoothed; mouse-look remains responsive and the existing dynamic FOV is unchanged. Smoothing is disabled again on release.

### Carry-hand and interaction reach polish

- Face-to-face limp-player carrying swaps the carrier's left/right chest grip sides; the carried player's chest local lateral axis is reversed from the carrier's view, so retaining the old signs crossed the arms.
- Limp-player grip wrist roll now aligns each thumb toward the carried Chest's local up axis. Prop grips retain their original forearm-axis roll behavior.
- Pointing hand hover reach is 4.0 m (previously 3.2 m), the visible hand advances farther toward the hover target, and the poke extension increases to 0.42 m. Host interaction distance validation uses the same shared reach constant.
- No scene hierarchy or authored scene files changed.

## Verification status

- **User visual/playtest confirmation:** the carried Chest now stays in front of the carrier and faces them; opposite-side arm/leg collisions work; carried head and arm movement is calmer; the head-mounted first-person camera is more comfortable while preserving mouse-look and dynamic FOV. The user reports the carry feature is working and considers implementation complete.
- The repository's M6 automated test is present in `tests/m6_carry_test.gd` and included by `tests/run_checks.ps1`; it has not been run in this editing environment.
- A full two-instance host/client carry/drop/throw verification has not been recorded here. Keep automated and multiplayer verification distinct from the user's visual confirmation.

## Two-instance verification checklist

1. Host knocks down client; host grabs client with E; client sees the body carried, can look around, and limbs dangle.
2. Host taps Q to drop; client lands and remains limp for a fresh 3.5 seconds (subject to existing settled/hard-cap rules).
3. Host grabs the same client again before recovery, then holds Q to throw; the client sees the throw and recovery countdown restarts fresh.
4. Client knocks down host; client grabs host; host sees the body carried and can look around.
5. Client drops and re-grabs the host, then throws; both peers remain synchronized.
6. Confirm props still pick up, drop and throw as before.

## Safety

- Do not merge into `main` without the user's explicit request.
- Preserve the authored get-up animation and host-authoritative ragdoll pose stream.
- Never enable local PhysicalBone3D collision on remote peers.
