# Elevator DEPART Button — Request and Occupancy Validation

The existing physical `TerminalButton` (display text `DEPART`) submits a host-authoritative
request. The controller validates occupancy, asks the persistent RunManager for the permitted
destination, and runs the existing synchronized elevator departure choreography.

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

A valid press emits `departure_requested(actor_peer_id)`. The controller's own progression
handler forwards the request to `/root/RunManager`; no extra scene node or manual signal connection
is required.

- First valid departure from the Apartment starts a new run on Day 1 and targets the Casino.
- Casino departure is rejected until RunManager's quota/deadline gate is unlocked.
- An unlocked Casino departure returns to the Apartment for the Rest phase.
- Apartment departure during the Rest phase targets the Casino and increments the day on arrival.
- MainController's persistent `world_changed` signal is bound to RunManager, so the progression
  state commits after the destination world is installed, even though the old elevator scene unloads.

The elevator still owns occupancy, door closure, carry/ragdoll preparation, and the physical
transition request. RunManager owns phase validation and destination choice.

## Debug watches

- `run/active`, `run/day`, `run/phase`, `run/casino_departure_allowed` (RunManager)
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

Destination IDs are Apartment=0 and Casino=1. The Rest phase reuses Apartment=0. The elevator does not decide quota/day rules. The sequence locks the proximity opener so it cannot reopen the doors while the team is preparing to leave.

After approval, the controller closes the existing four-panel doors, force-drops carried props/players
through Network, starts the existing synchronized ragdoll recovery for limp players, and waits for
everyone to finish recovering. Only then does it call persistent MainController.transition_to().
If preparation fails, it clears the pending state and reopens the doors. The MainController's
existing fade and world swap performs the actual transition.

No scene edits are needed. Run progression is now connected. The first Apartment departure starts Day 1; later departures follow the RunManager phase and quota gate.
