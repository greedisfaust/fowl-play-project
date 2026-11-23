# Elevator Physical Collision Setup

This pass adds the fixed cabin shell colliders to the existing authored elevator scene.
It does not create or modify any scene files automatically; build these nodes in the Godot editor.

## Important separation

- Keep `ElevatorArea/CollisionShape3D` as the large invisible occupancy trigger.
- Add the physical cabin colliders under `Structure/CollisionBody`.
- Do not put hand-authored colliders inside `Structure/GeneratedShell`; the visual builder replaces that generated group when rebuilding.
- The four moving door panels do not receive physical colliders in this first pass. Door-leaf collision will be a separate testable step so we can avoid pushing players or trapping them during the animation.

## Node hierarchy to create

Under the existing `Elevator/Structure` node, create:

```text
Structure
├── GeneratedShell                  (existing, leave untouched)
└── CollisionBody                   (StaticBody3D)
    ├── CabinFloor                  (CollisionShape3D)
    ├── BackWall                    (CollisionShape3D)
    ├── LeftWall                    (CollisionShape3D)
    ├── RightWall                   (CollisionShape3D)
    ├── FrontLeftPier               (CollisionShape3D)
    ├── FrontRightPier              (CollisionShape3D)
    └── FrontHeader                 (CollisionShape3D)
```

Set `CollisionBody`:
- Collision Layer: **1 only** (World Static).
- Collision Mask: **none**.
- Position: `(0, 0, 0)`.

For each CollisionShape3D, create a new `BoxShape3D` resource and set the exact size and local position below. All positions are relative to `CollisionBody`.

| Node | BoxShape3D Size (X, Y, Z) | Position (X, Y, Z) |
|---|---:|---:|
| CabinFloor | (3.52, 0.16, 3.32) | (0, -0.08, 0) |
| BackWall | (3.52, 2.8, 0.16) | (0, 1.4, 1.58) |
| LeftWall | (0.16, 2.8, 3.16) | (-1.68, 1.4, 0) |
| RightWall | (0.16, 2.8, 3.16) | (1.68, 1.4, 0) |
| FrontLeftPier | (0.56, 2.8, 0.16) | (-1.48, 1.4, -1.58) |
| FrontRightPier | (0.56, 2.8, 0.16) | (1.48, 1.4, -1.58) |
| FrontHeader | (2.4, 0.6, 0.18) | (0, 2.5, -1.58) |

These match the current visual builder's cabin shell. The entrance is on the **negative Z** side and remains 2.4 m wide by 2.2 m high.

## Test in TestArena

1. Instance the elevator in TestArena as you have been doing.
2. Run the game and walk around inside the cabin.
3. Confirm you can stand on the floor, cannot walk through the left/right/back walls, and cannot jump through the ceiling/header.
4. Confirm the front entrance remains completely open.
5. Walk through the doorway and verify the occupancy count still changes correctly.

The existing occupancy trigger overlaps the interior volume intentionally; its collision mask detects player bodies, while the new StaticBody3D provides physical world collision.

## Next collision pass

After fixed shell collision is confirmed, add moving door-leaf collision using a moving-body type and test the open/close sweep with a player standing in the doorway. Do not add door colliders until that behavior is implemented and verified.
