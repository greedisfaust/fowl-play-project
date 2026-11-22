# Elevator DEPART Button — Request and Occupancy Validation

This slice connects the existing physical `TerminalButton` (display text `DEPART`) to a
host-authoritative departure-request interface. It does not implement day progression,
quota rules, door-closing choreography, or world transitions yet.

## Scene setup

The existing scene already contains:

- `InteriorDetails/TerminalButton` — the existing TerminalButton instance.
- `ElevatorArea` — ElevatorOccupancy.
- `DoorAnimation` — ElevatorDoorController.
- `StatusController` — ElevatorStatusDisplay.

Add one plain `Node` as a direct child of the Elevator root:

1. Select the Elevator root.
2. Add Child Node → `Node`.
3. Name it `DepartureController`.
4. Attach `res://world/elevator/elevator_departure_controller.gd`.
5. Leave the default exported paths unchanged.
6. Save the elevator scene.

Do not replace or duplicate TerminalButton, Interactable, ElevatorArea, or DoorAnimation.
Do not modify the existing scene's meshes or collision shapes.

## Validation

- The actor pressing DEPART must be inside the elevator.
- Every peer in the Network roster must be inside.
- Carried players count because ElevatorOccupancy already tracks synthetic carried-player occupancy.
- The host performs the final validation when TerminalButton emits `button_activated`.
- Interactable availability uses the same occupancy rule, so the button request is rejected before its activation signal if anyone is outside.
- Empty sessions and unknown/non-occupant actors are rejected.
- Repeated requests are blocked while a departure request is pending.

## Progression boundary

A valid press emits:

```gdscript
signal departure_requested(actor_peer_id: int)
```

The future outer-loop progression coordinator will connect to this signal and decide whether
the current context permits departure (start a casino day, leave the casino after quota, or
leave the Rest Area for the next day). Quota and day-state rules intentionally do not live in
the elevator controller.

If progression rejects the request, it calls `reject_departure_request(reason)`.
After the complete group transition reaches its destination, the transition flow calls
`finish_departure_request()`.

No world transition is triggered by this slice alone.

## Debug watches

- `elevator/departure_ready`: whether all expected players are inside.
- `elevator/departure_request_pending`: whether a valid request is awaiting progression.

## Automated checks

Run `tests/run_elevator_departure_checks.bat`. It checks full-team occupancy, missing players,
empty sessions, actor membership, and the carried-player-compatible peer-ID contract.
It does not replace an in-editor multiplayer interaction test.


## Accepted departure sequence (W5-B)

The outer-loop progression coordinator approves a request with an explicit destination:

```gdscript
departure_controller.accept_departure_request(MainController.World.CASINO)
```

Destination IDs are Apartment=0, Casino=1, Rest Area=2. The elevator does not decide quota/day rules.

After approval, the controller closes the existing four-panel doors, force-drops carried props/players
through Network, starts the existing synchronized ragdoll recovery for limp players, and waits for
everyone to finish recovering. Only then does it call persistent MainController.transition_to().
If preparation fails, it clears the pending state and reopens the doors. The MainController's
existing fade and world swap performs the actual transition.

No scene edits are needed. The progression coordinator is not implemented yet, so the button still
waits for that coordinator to approve its departure_requested signal.
