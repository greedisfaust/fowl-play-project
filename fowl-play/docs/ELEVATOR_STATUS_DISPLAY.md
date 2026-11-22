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

## Display behavior

- Shows the number of players currently inside versus the current session roster.
- Updates when elevator occupancy changes.
- Updates when the Network roster changes (players join or leave).
- Shows whether every connected player is inside.
- Shows early-departure eligibility as `CHECKING` until the run/quota coordinator supplies
  an authoritative result. This avoids falsely claiming the team is eligible or ineligible
  before quota logic exists.
- Shows `READY TO DEPART` only when all players are inside and the quota coordinator has
  marked early departure eligible.

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

1. Run with one player and enter/leave the elevator. Confirm `INSIDE` changes between
   `1 / 1` and `0 / 1`.
2. Host a session and join with another player. Confirm the total roster count updates.
3. Have each player enter and leave. Confirm the count follows the occupants.
4. Before the daily quota system is connected, confirm the screen says `CHECKING` and
   `QUOTA STATUS PENDING`, not a fabricated eligibility result.

The controller has not been live-tested in Godot as part of this code change.
