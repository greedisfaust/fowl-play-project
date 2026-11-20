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
