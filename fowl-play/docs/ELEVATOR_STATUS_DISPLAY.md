# Elevator Status Display

The slim display in the elevator reuses the existing `WorldScreen` and `ScreenText`
components. It does not create another UI renderer or interactable.

## Attach the controller

1. Open `res://world/elevator/elevator.tscn`.
2. Select the `Elevator` root and add a plain `Node` child named `StatusController`.
3. Attach `res://world/elevator/elevator_status_display.gd` to that new node.
4. Leave the exported paths at their defaults:
   - World Screen: `../InteriorDetails/SlimWorldScreen`
   - Occupancy: `../ElevatorArea`
5. Save the scene.

Do not replace the script on `SlimWorldScreen`; it must keep its existing WorldScreen controller.
Do not add another screen, viewport, or occupancy Area3D.

## Compact display behavior

The display intentionally stays to three visual elements:

- Top row: `ELEVATOR STATUS` on the left and `TEAM SIZE [count]` spaced toward the right edge.
- Main row: `INSIDE [count] / [total]` stays left-aligned at the normal terminal font size.
  - Green count when every rostered player is inside.
  - Red count when one or more players are missing.
- Bottom row: the current state message is the large, centered text. Its default size is 1.75 times the terminal font size.
- Bottom row: one concise state message, such as `WAITING FOR PLAYERS`,
  `WAITING FOR QUOTA`, `READY TO DEPART`, or `QUOTA NOT MET`.

The count refreshes when elevator occupancy changes or the Network roster changes.
Text sizing is applied per line so the state message is substantially larger than the header
and inside count.

Until the run/quota coordinator supplies an authoritative result, the state message is
`WAITING FOR QUOTA` when everyone is inside. The display does not claim eligibility early.

## Run/quota integration API

The future host-authoritative run coordinator can call:

```gdscript
status_display.set_early_departure_status(true, "DAILY QUOTA MET")
status_display.set_early_departure_status(false, "DAILY QUOTA NOT MET")
status_display.clear_early_departure_status()
```

This API only updates the screen. The eventual departure interaction must independently
validate the quota and all-player occupancy on the host. Never trust display state as
permission to transition worlds.

## Verification

In TestArena with the elevator instanced:

1. Run with one player and enter/leave the elevator. Confirm the count changes between
   `INSIDE 1 / 1` and `INSIDE 0 / 1`.
2. Host a session and join with another player. Confirm the team count updates.
3. Have each player enter and leave. Confirm the count follows the occupants.
4. Confirm the inside count is green only when everyone is inside and red otherwise.
5. Confirm only one concise state message appears below the count.

The compact layout has not been live-tested in Godot as part of this code change.
