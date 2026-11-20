# Procedural gait cadence refinement — 2026-11-20

## User playtest feedback

The predictive foot-landing adjustment produced visible movement, but the legs still appeared to drag or lag behind the moving character. This indicates that ground targeting alone was not enough; the visible gait needed a more decisive stride.

## Changes

- Reduced `LEG_STEP_CYCLE_DISTANCE_M` from 2.5 m to 1.8 m. At the nominal 5 m/s movement speed, this increases the cadence from 2.0 to about 2.78 step cycles per second.
- Increased maximum thigh swing from 24° to 32° so each step has more visible forward/backward travel.
- Increased maximum knee bend from 36° to 48° to make the swing phase clearer and improve foot clearance.
- Changed the stance fraction from 0.62 to 0.58, giving the swing phase a little more time to move the foot forward.
- The existing predictive ground-probe lead automatically recalculates from the updated stride distance and swing fraction (1.8 × 0.42 = 0.756 m).

## Regression coverage

- M8 now checks that the gait phase advances using the configured stride distance and rejects a stride distance of 2.0 m or longer.
- Existing alternating-leg, stance/swing, stop-settling, foot-anchor, IK, and ragdoll-ownership checks remain in place.

## Verification status

Source and test assertions are committed. The assistant did not execute Godot tests or in-game verification. The user should check walking, backward movement, strafing, circles, and quick starts/stops after pulling. If the legs now overreach or look too fast, tune cadence and swing amplitude separately rather than changing ground detection again.
