# Elevator Automatic Door Proximity

The elevator doors open automatically when a player approaches the entrance. This is an
environmental wayfinding cue and is intentionally separate from the DEPART button.

## Attach the proximity controller

The existing elevator scene contains a temporary `DoorTest` Node3D used for a timed
open/close demonstration. Replace that test script with the automatic proximity controller:

1. Open `res://world/elevator/elevator.tscn`.
2. Select the existing `DoorTest` node.
3. Rename it to `DoorProximityController`.
4. In the Inspector, replace its script with
   `res://world/elevator/elevator_door_proximity.gd`.
5. Keep it as a direct child of the Elevator root, alongside `DoorAnimation`.
6. Save the scene.

Do not add another Area3D, CollisionShape3D, or modify the elevator's authored geometry.
The controller reuses the existing four-panel `ElevatorDoorController`.

## Default behavior

- The doors begin closed.
- When any player comes within 3.25 m horizontally of the entrance center, the doors open.
- While any player remains within 4.0 m, the doors stay open.
- Once all players leave that 4.0 m range, the doors close after 1.25 seconds.
- Vertical distance is ignored, allowing nearby players on a stair or ramp to trigger the doors.
- A player carrying another player still triggers the doors through the carrier's position.
- The host evaluates player positions from Network.movement_players and broadcasts door state
  reliably to all peers. Clients do not independently make proximity decisions.

The exported settings can be adjusted on the DoorProximityController node. The larger
keep-open distance provides hysteresis, preventing rapid open/close flicker near the threshold.

## Separation from game progression

The DEPART TerminalButton is not connected to this controller. Pressing DEPART remains a
separate request for the outer-loop progression system to validate and execute. Automatic
doors never start a day, end a day, check quota, or trigger a world transition.

## Debug watches

- `elevator/door_nearby_players`: players inside the opening radius.
- `elevator/door_commanded_open`: latest host-commanded door state.

## Automated checks

Run `tests/run_elevator_door_proximity_checks.bat`. The unit check validates entrance-relative
horizontal distance, side approaches, and vertical-distance filtering. It does not simulate
live physics or a multiplayer session; those still require an in-editor multiplayer playtest.
