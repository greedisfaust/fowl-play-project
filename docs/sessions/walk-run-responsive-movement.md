# Walk, run, and responsive movement — 2026-11-20

## Implementation

- Reduced normal horizontal movement speed from 5.0 m/s to 3.8 m/s.
- Added a 8.0 m/s run target while the player holds the `sprint` action and has directional movement input.
- Added a small pure `MovementController` helper so horizontal velocity uses acceleration and deceleration instead of instantly snapping to target speed. Direction reversals blend through the current velocity.
- Existing vertical gravity and jump behavior are unchanged. The local player still owns input and movement; existing movement snapshots continue replicating position and velocity.
- Procedural gait keeps the existing full walking stride amplitude and blends its cadence and stride intensity toward a distinct run as actual horizontal speed increases.
- No scene files or Project Settings were edited.

## Input Map handoff

Create an Input Map action named `sprint` and bind Left Shift. The player script reads that exact action name.

## Regression coverage

- M3 movement checks cover acceleration from rest, deceleration after release, gradual direction reversal, and reaching the requested speed.
- M8 procedural-leg checks cover walk/run speed separation and the run-gait blend.
- Godot execution and in-game playtesting have not been run by the assistant.


## Follow-up tuning

- Increased the run target to 8.0 m/s (from 7.0 m/s) at the user's request. Walking remains 3.8 m/s; acceleration and deceleration remain unchanged.


## Walking cadence follow-up — 2026-11-20

- Increased `LEG_WALK_STEP_CYCLE_DISTANCE_M` to 2.0 m to slow the walking cadence.
- Set `LEG_WALK_STANCE_FRACTION` to 0.46 rather than extending stance to 0.62. At the 2.0 m cycle, a 0.62 stance would represent 1.24 m of planted travel, exceeding the current comfortable leg reach and likely causing emergency replants. The 0.46 stance represents 0.92 m and stays within the existing reach guard.
- Sprint gait settings are unchanged. User in-game verification is pending.
