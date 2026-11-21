# Hand Rig Milestone Bundle — Multiplayer Readiness

**Branch:** `features/new-reactive-hands-and-viewport`  
**Status:** Procedural hand foundations are implemented; latest all-finger box-contact extension and spam-friendly poke behavior still need the user's current-build visual confirmation. Multiplayer hand behavior is **not yet verified**.

This document gathers the hand-rig work into one handoff and defines the next implementation/verification milestone. It does not replace the existing M2/M3 tests or claim that a headless test proves rendered multiplayer behavior.

## 1. Included hand-rig work

### Procedural hand foundation
- Reusable procedural hand/finger hierarchy and pose preview tooling.
- Idle, point/reach, guard, limp, and carry pose paths.
- Smooth pose blending while preserving the stable hand attachment root.
- Existing hand hierarchy and higher-priority guard/carry/limp behavior are retained.

### Carry grip
- Left/right hands approach opposite sides of a carried prop.
- Grip spacing uses collision geometry, including transformed collision children and compound bounds, with mesh/fallback bounds where needed.
- Palm orientation was corrected and visually confirmed by the user.
- Per-finger curl adapts to prop thickness; individual fingers receive lateral edge-hook adjustments.
- Thumb opposition and size-adaptive thumb curl are implemented.
- Box surface-directed bend is applied independently to index, middle, ring, and pinky. The correction is weighted and angle-limited.

**Shape limitation:** the surface-directed contact target solver currently handles `BoxShape3D`. Sphere/capsule/other-shape contact solving and exact fingertip IK are not included. Existing size-adaptive grip bounds support more shape types, but that is not the same as surface-directed finger contact for those shapes.

### Pointing and poke
- Hover pointing turns and offsets the whole hand toward the target within configured limits; the index finger provides fine aim.
- Pokes use a small extending/contact/returning lifecycle.
- A new poke can retrigger during extension, contact, or recovery, starting from the current reach blend instead of snapping or stacking animation timers.
- Local feedback is immediate; the authoritative interaction result remains separate from cosmetic animation.
- Host-approved poke events are broadcast for remote world-hand presentation.
- Cosmetic poke spam does not bypass host-side interaction validation or gameplay throttling.

## 2. Implemented versus verified

| Area | Current status |
|---|---|
| Procedural hand poses and finger hierarchy | Implemented; prior local visual checks completed |
| Shape-aware carry placement | Implemented; user visually tested boxes and a capsule |
| Palm orientation | Implemented and visually confirmed |
| Size-adaptive fingers and thumb | Implemented; user visually confirmed |
| Surface-directed bend on all four fingers for boxes | Implemented; latest extension still needs user visual confirmation |
| Spam-friendly poke retrigger | Implemented; latest fix still needs user visual confirmation |
| Local point/poke behavior | Implemented; local visual checks previously reported working |
| Hover target relay host ↔ client | Code path implemented; actual two-instance visual delivery not verified |
| Host-approved remote poke broadcast | Code path implemented; actual two-instance visual delivery not verified |
| Carry pose on local and remote hand presentations | Signal integration implemented; full two-instance visual verification pending |
| Complete hand-rig multiplayer readiness | **Not verified — do not mark complete yet** |

Automated M2/M3 assertions exercise important pose and receive-handler paths, but direct calls in a test do not prove that real host/client RPC delivery, authority checks, timing, or rendered world-hand updates work.

## 3. Multiplayer verification goals

The next milestone is to establish reliable, correctly owned hand presentation in both directions.

1. **Ownership and baseline**
   - Identify the local first-person/Viewmodel hands and the remote player's camera-attached Viewmodel hands; keep ragdoll Rig hands dedicated to physical/ragdoll presentation.
   - Confirm each peer controls only its own hand input/state.
   - Confirm remote presentation does not duplicate the owner's first-person animation.

2. **Hover and pointing**
   - Host points at a target; client sees the host's camera-attached Viewmodel hand point.
   - Client points at a target; host sees the client's camera-attached Viewmodel hand point.
   - Move the target continuously and check that updates are smooth, bounded, and do not cause visible jitter or excessive traffic.

3. **Poke**
   - Host pokes; client sees the host's world-hand poke.
   - Client pokes; host sees the client's world-hand poke.
   - Rapidly retrigger pokes and verify remote presentation follows without snapping, sticking, or accumulating delayed animations.
   - Verify only host-approved interaction events are broadcast to remote observers; cosmetic animation never grants interaction authority.

4. **Carry, drop, and throw**
   - Host picks up, carries, drops, and throws a prop; client sees the correct prop and hand state.
   - Repeat with client as the actor.
   - Confirm both hands enter/leave carry pose at the correct lifecycle points and return cleanly afterward.
   - Confirm object authority/physics behavior remains authoritative and is not replaced by hand animation.

5. **Pose priority and interruption**
   - Verify guard, carry, and limp continue to take priority over point/reach actions.
   - Verify interruption and recovery do not leave a hand stuck in a stale pose.
   - Verify ragdoll/limp ownership and recovery are not fought by procedural hand updates.

6. **Regression**
   - Run the existing project checks.
   - Re-run relevant local hand, interaction, carry, and ragdoll checks.
   - Complete the two-instance matrix below before calling the hand rig multiplayer-ready.

## 4. Two-instance test matrix

Use two separate game instances. Record which instance is host and which is client, and test each action with each peer as the actor.

| Test | Host acts → client observes | Client acts → host observes |
|---|---:|---:|
| Idle/world hand visible and correctly owned | ☐ | ☐ |
| Hover target / pointing follows target | ☐ | ☐ |
| Single poke appears once | ☐ | ☐ |
| Rapid repeated pokes remain smooth | ☐ | ☐ |
| Guard pose appears and releases | ☐ | ☐ |
| Pick up and enter carry pose | ☐ | ☐ |
| Carry movement remains synchronized | ☐ | ☐ |
| Drop exits carry pose | ☐ | ☐ |
| Throw exits carry pose and prop motion replicates | ☐ | ☐ |
| Limp/ragdoll interrupts procedural hand control safely | ☐ | ☐ |
| Recovery returns control to procedural hand rig | ☐ | ☐ |

For every failed row, record the actor, observer, action, expected result, actual result, and relevant network/debug counters. Do not infer success from the actor's local first-person view alone.

## 5. Debugging expectations

Existing hand diagnostics:
- `hand_status_<name>` — resolved pose, action phase, hover, guard, carry, limp, and reach blend.
- `hands/<name>/state` — live hand state watch.
- `hand_pose_<name> idle|point|guard|limp|reach` — pose preview.
- `net/hand_poke_sent` and `net/hand_poke_received` — poke event counters.

During the multiplayer pass, inspect these on both instances. If the visual result is wrong, first determine whether the sender generated the state/event, whether the host accepted/relayed it, whether the receiver got it, and whether the correct remote hand consumed it. Add narrowly scoped counters/logs for any missing stage rather than guessing from the final pose.

Use the existing project check instructions in [DEBUG.md](DEBUG.md), including `tests/run_checks.ps1`, for automated checks. The assistant cannot run the Godot project in this workflow; runtime and rendered two-instance verification must be performed in the editor/game.

## 6. Completion criteria

The hand rig is **not multiplayer-ready** until:
- Every applicable row in the two-instance matrix passes in both directions.
- No duplicate owner/remote animation, stale pose, or stuck recovery is observed.
- Host authority and interaction validation remain intact.
- Relevant automated checks pass in the user's environment.
- `DEBUG.md` and `PROJECT_STATE.md` record the actual results, including any known limitations.

## 7. Suggested implementation order

Work in small slices and test each one before proceeding:

1. Audit current ownership/RPC paths and add/confirm diagnostics.
2. Verify and fix hover/point replication in both directions.
3. Verify and fix host-approved poke replication, including spam retriggers.
4. Verify carry/drop/throw hand-state integration in both directions.
5. Verify guard/limp/recovery priority and complete the regression matrix.

Preserve the current feature branch history. Do not squash, force-push, merge, or reset as part of this bundle.


## 2026-11-19 correction — remote pointing presentation target

The first hover/poke relay implementation was applying remote cosmetics to the ragdoll Rig hand. The correct presentation target is the remote player's camera-attached `Head/Camera3D/ViewmodelHands/RightHand`, which remains part of that player's scene and is rendered by other peers. Local Focus continues to drive the owner's own Viewmodel hand directly. Ragdoll Rig hands remain for ragdoll/physical presentation and carry grip. M3 tests now distinguish these targets. Live two-instance rendering still needs user verification.
