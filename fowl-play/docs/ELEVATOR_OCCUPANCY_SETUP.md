# Elevator Occupancy Setup

The elevator occupancy component tracks which networked player characters are physically
inside the existing elevator trigger. It does not change the authored elevator scene.

## Attach the occupancy script

1. Open `res://world/elevator/elevator.tscn`.
2. Select the existing `ElevatorArea` node (the Area3D).
3. Attach `res://world/elevator/elevator_occupancy.gd`.
4. Save the scene.

Do not add another Area3D or CollisionShape3D. The existing `ElevatorArea/CollisionShape3D`
is reused. The script enables monitoring and configures the area to detect the project's
healthy-player and limp-body collision layers.

## What it tracks

- A player is counted once, using the stable `input_peer_id` assigned by MainController.
- The player's normal CharacterBody3D and limp interaction proxy resolve to the same player.
  One body exiting does not remove the player while another body belonging to them remains inside.
- A player is removed when all of their tracked bodies leave the area.
- A player despawning while inside is removed automatically.
- Occupant peer IDs are returned in sorted order.

The script exposes:
- `occupant_entered(peer_id, player)`
- `occupant_exited(peer_id, player)`
- `occupants_changed(peer_ids)`
- `get_occupant_count()`
- `get_occupant_peer_ids()`
- `is_player_inside(peer_id)`
- `get_occupant(peer_id)`

Each peer tracks the player bodies it currently sees. The host's local occupancy list will
be the authority source for the later group-departure interaction. This slice does not yet
open the doors automatically, add a call button, or trigger a world transition.

## Test it in TestArena

The elevator can remain instanced in TestArena for this test.

1. Make sure the occupancy script is attached to `ElevatorArea` in the elevator scene.
2. Run TestArena.
3. Walk fully into the elevator cabin. The occupant count should become 1.
4. Walk fully back out. The occupant count should return to 0.
5. For multiplayer, have another player enter while you remain inside. The count should
   become 2, then decrease as each player leaves.

The component registers DebugHub watches named:
- `elevator/occupant_count`
- `elevator/occupant_peer_ids`

## Automated checks

Run `tests/run_elevator_occupancy_checks.bat` from the project folder. It imports the
project resources and runs `tests/elevator_occupancy_test.gd`.

The test covers player entry, duplicate body protection, exit tracking, and cleanup when
a player is despawned. It does not simulate real physics overlap or a live multiplayer session;
those remain in-editor playtest checks.
