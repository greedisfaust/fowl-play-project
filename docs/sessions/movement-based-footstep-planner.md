# Movement-based footstep planner — 2026-11-20

## Motivation

The user confirmed that ground contact was working, but the legs still appeared to trail behind the moving body. The previous probe predicted from the current foot position. That reference point was the problem: the foot can already be far behind the hips during stance, so adding a forward probe offset still does not define a useful landing position relative to the moving body.

## Design

Added `procedural_footstep_planner.gd`, a small mathematical planner rather than a physics `Area3D`.

- Reads the rig's smoothed local movement direction.
- Transforms that direction into world space using the rig basis.
- Places left/right targets on opposite sides of the movement direction, preserving foot separation while strafing and moving diagonally.
- Predicts how far the hips will travel during the swing interval using the existing distance-based gait values.
- Produces hip-relative landing points; PlayerRig projects those points vertically onto the ground with the existing raycast.
- The existing foot-plant tracker captures the target at swing lift-off and locks it in world space through stance.
- Existing two-bone IK and stance-only surface-normal alignment remain responsible for leg articulation and ground contact.

## Integration

PlayerRig now computes each landing point from its corresponding thigh/hip position after updating the gait controller. It sets the probe height from the current sole while taking horizontal placement from the hip-relative planner. The old foot-origin predictive probe in `_physics_process` was removed to avoid duplicate/stale ground queries.

The planner uses a forward placement of 0 m plus predicted swing travel:
`LEG_STEP_CYCLE_DISTANCE_M * (1 - LEG_STANCE_FRACTION)`.
This aims for a landing point near the hips' future position, rather than a point that ends up behind the hips by the time swing completes.

## Regression coverage

M8 now checks forward, backward, strafing, left/right separation, and rotated rig orientation for the planner, alongside existing gait, foot-plant, IK, and ragdoll-ownership checks.

## Verification status

Code and regression assertions are committed. Godot tests and in-game verification have NOT been run by the assistant. The user should test forward/backward walking, strafing both directions, diagonals, circles, and quick start/stop transitions. If the legs reach too far or the feet overstep, tune the predicted travel and lateral placement independently.


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


## Distance-triggered recovery and anatomical landing lanes — 2026-11-20

### Problem addressed

A world-space stance anchor correctly prevents foot sliding, but it can remain locked while the moving hip travels beyond a comfortable leg extension. The gait phase may not yet have requested a normal swing, leaving the foot visibly suspended or the leg overextended.

### Implementation

- Each leg derives its comfortable reach from the authored thigh-to-shin and shin-to-foot rest-bone lengths, multiplied by `LEG_REPLANT_MAX_REACH_RATIO` (0.82).
- While a foot is in stance, PlayerRig checks hip-to-anchor distance every procedural update. Reaching the threshold requests a recovery step immediately, without waiting for the gait phase.
- The emergency step captures a new hip-relative landing point, probes it against the same world-ground mask, and follows a short 0.18 s lifted trajectory. It then locks the new world-space anchor.
- When both feet are overstretched, the controller recovers only the leg with the larger normalized stretch ratio. This prevents simultaneous emergency steps.
- Normal and emergency landing targets pass through an anatomical side clamp: left remains at least 0.20 m on the rig's left side, right remains at least 0.20 m on its right side.
- Debug ground status exposes emergency recovery state and normalized stretch ratios.

### Regression coverage and verification

M8 assertions now cover stretch-trigger detection, the lifted emergency trajectory, completion/anchor capture, and left/right centerline constraints. Godot tests and rendered in-game behavior have not been run by the assistant; user verification is still required. The side clamp constrains IK targets and is not a physical collision solver for overlapping leg meshes.
