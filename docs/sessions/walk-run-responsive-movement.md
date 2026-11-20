# Walk, run, and responsive movement — 2026-11-20

## Implementation

- Reduced normal horizontal movement speed from 5.0 m/s to 3.8 m/s.
- Added a 7.0 m/s run target while the player holds the `sprint` action and has directional movement input.
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
