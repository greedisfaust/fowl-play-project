# Moving-platform foot anchors — 2026-11-20

## Motivation

The existing foot-plant tracker locked stance targets in world space. That prevents sliding on a static floor, but a moving elevator or platform can translate or rotate away from a planted foot.

## Implementation

- The ground probe's hit collider is passed into the foot-plant tracker when it is a `Node3D`.
- On landing, the tracker stores the contact point in the support's local space as well as its world position.
- During stance, the anchor is refreshed through the support's current global transform.
- Normal swing and emergency-replant targets retain their support-local contact point so a moving platform can carry the target during the step.
- If the support is freed, the anchor safely retains its last world-space position.
- Static floors continue using the same behavior as before.

## Regression coverage

M8 checks that a planted foot follows a support through translation and rotation without losing its local contact point.

## Verification

The code and regression assertion are committed to the feature branch. Godot tests and in-game verification have NOT been run by the assistant. Verify standing and walking on a moving elevator/platform, then confirm ordinary static-floor walking and strafing remain unchanged. No scene files were modified.
