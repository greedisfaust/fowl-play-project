# Fowl Play — Debug Console Reference

**Open:** type the development unlock phrase `ilovedebugging` (the
`DEBUG_CONSOLE_WORD` value). It is local-only development tooling, not a
security secret.

## Categories

| Category | Owner script | What it logs |
|---|---|---|
| net | core/network.gd | network startup, shutdown, rejected RPCs |
| combat | core/combat.gd | punch, parry, lunge, hit, limb events |
| limp | core/limp.gd | limp start/end, recovery, phase changes |
| carry | core/carry.gd | pickup, carry, throw, drop, state |
| hands | core/hands.gd | reach, hover, guard, shake, color changes |
| legs | core/legs.gd | step, land, settle, air movement |
| props | core/props.gd | spawn, grab, throw, interact, state |
| ragdoll | ragdoll/player_ragdoll_test.gd | isolated physical-bone test start/stop |
| interact | player/focus.gd and interaction/interactable.gd | focus changes, accepted/rejected interaction requests |
| player | player/player.gd | movement state and local camera input |

## Watches

| Name | Source | Meaning |
|---|---|---|
| `player/<name>/speed_mps` | player/player.gd | Current capsule velocity magnitude. |
| `player/<name>/on_floor` | player/player.gd | Whether the capsule is grounded. |
| `net/status` | core/network.gd | offline, hosting, connecting, connected, disconnected, or failed. |
| `net/peers` | core/network.gd | Locally known connected peer IDs, including local ID once connected. |
| `net/player_count` | arena/test_arena.gd | Spawned players in this arena instance. |
| `net/hand_poke_sent` | core/network.gd | Host count of accepted cosmetic hand-poke broadcasts sent. |
| `net/hand_poke_received` | core/network.gd | Count of remote world-hand pokes played on this instance. |
| `interact/focused/<name>` | player/focus.gd | Prompt text for the local player's focused target, or blank. |
| `interact/device/<name>/active` | interaction/debug_use_device.gd | Toggle state of the M1 test USE device. |
| `props/<name>/pickup_allowed` | props/prop.gd | Whether the prop's assigned profile allows pickup. |
| `hands/<name>/state` | hands/hand.gd | World mode, hover, guard, carry, limp, and speed state. |
| Carry pose | hands/hand.gd | While carrying, the palm's local +Y normal smoothly turns toward the carried prop; finger curl is still the shared carry pose. |
| `ragdoll_test.simulating` | ragdoll/player_ragdoll_test.gd | Whether the isolated PhysicalBoneSimulator3D is simulating. |
| `player/<name>/wall_clearance` | player/player.gd | Whether recovery placement had to move away from a wall/prop during limp recovery. |
| `player/<name>/carrying` | player/player.gd | Whether this player currently holds a carried item (prop or limp body). |
| `player/<name>/limp_interactable_enabled` | player/player.gd | Whether this limp player's grab-target Interactable is enabled. |

## Commands

Enter a command plus whitespace-separated arguments in the command bar, then press Enter or Run. For example: `debug_disable net`, followed by `debug_enable net`. Quoted arguments are not supported yet.

Results appear below the bar even when `net` logging is disabled. Unknown commands display an error; empty input displays a prompt. Existing command buttons also display results and copy their command name into the input field so arguments can be added.

Automated checks cover Enter/Run signal wiring, category toggles, feedback with logging disabled, whitespace, missing arguments, and unknown/empty commands. USER VERIFIED: command entry works in-game after the Enter/Run playtest handoff.

| Name | Args | Host only | Cheat | What it does |
|---|---|---|---|---|
| `debug_categories` | none | no | no | Lists registered categories and enabled state. |
| `debug_enable` | category | no | no | Enables a local debug category. |
| `debug_disable` | category | no | no | Disables a local debug category. |
| `debug_watches` | none | no | no | Lists registered watches and current values. |
| `player_status_<name>` | none | no | no | Reports one player's position, velocity, and grounded state. |
| `carry_drop_<name>` | none | no | no | Requests a drop of the carried item by this player. |
| `carry_throw_<name>` | none | no | no | Requests a throw of the carried item by this player. |
| `net_status` | none | no | no | Reports connection status, port, and known peers. |
| `net_host` | none | no | no | Starts hosting from offline/disconnected state. Removes the offline player before spawning the host. |
| `net_join` | optional IP | no | no | Joins an IP; defaults to 127.0.0.1. Example: `net_join 192.168.1.20`. |
| `net_disconnect` | none | no | no | Disconnects this instance and clears its players. On the host, ends the session for clients. Use net_host/net_join afterward. |
| `interact_use_<name>` | none | no | no | Submits the local player's focused interaction to the host. Remote-player commands reject locally. Submission is not acceptance; see interact logs. |
| `hand_status_<name>` | none | no | no | Reports this hand's cosmetic state. |
| `ragdoll_test_start` | none | no | yes | Starts the isolated player ragdoll simulation. |
| `ragdoll_test_stop` | none | no | yes | Stops the isolated player ragdoll simulation. |
| `ragdoll_test_reset` | none | no | yes | Stops the isolated simulation and restores the skeleton rest pose. |
| `hand_pose_<name>` | idle / point / guard / limp | no | no | Local cosmetic pose preview; idle and point have separate adjustable thumb poses. Guard blends finger curl, thumb closure and PoseRoot lift/rotation. Idle restores relaxed offsets; limp overrides guard. Requires a running scripted hand instance. |

## Playtest "what you should see" log

| Slice | Step | Expected console output |
|---|---|---|
| D0 | 1 | Headless check registers the built-in commands and a temporary watch. |
| D0 | 2 | Headless check records `net: D0 verification log` in the local ring buffer. |
| M0 | 1 | After arena script handoff, `player_status_1` reports the host/offline player's state. Client commands use their peer ID. |
| M0 | 2 | The console opens after typing `ilovedebugging`; mouse input is released. |
| M0 | 3 | Escape closes the console and mouse capture returns. |
| M0 | 4 | Host: `Host started on port 7777`; client: `Connected as peer <id>`. |
| M0 | 5 | Both: `Spawning player <id> in slot <slot>`; player count becomes 2. |
| M0 | 6 | Client leaves: host logs `Despawning player <id>`; player count becomes 1. |
| M0 | 7 | Host leaves: client logs `Host disconnected`; player count becomes 0. |
| M1 | 1 | Aim at the editor-authored device: `interact: Focused <prompt>` and the device receives a highlight overlay. |
| M1/M3 | 2 | Press E or run `interact_use_<name>`: `interact: Interaction accepted peer=<id> action=use`; host logs `<device> active=true/false`, clients log `<device> replicated active=true/false`. |
| M1 | 3 | Aim at the GRAB prop: `props/<name>/pickup_allowed=true`; press E and see `props: <name> grab accepted; carry is deferred to M6`. |
| M2 | 1 | Hand registration shows `hands/<name>/state`; `hand_status_<name>` reports world/hover/guard/carry/limp state. |
| M2/M3 | 1 | On an accepted USE/GRAB interaction, the initiating player sees the immediate first-person poke; other peers see that player's world right hand poke toward the target. `net/hand_poke_sent` increases on host; `net/hand_poke_received` increases on peers that animate a remote hand. Rejected interactions do not broadcast a poke. |
| M6 | 1 | Aim at a free prop or limp body: `props/<name>/pickup_allowed=true` or `player/<name>/limp_interactable_enabled=true`; press interact → `carry: Player <name> picked up <item>` on host and `carry/<name>/holding=<item>` watch appears. |
| M6 | 2 | Press punch once and release quickly: `carry: Player <name> released <item>` and `props/<name> set carried=false`. |
| M6 | 3 | Hold punch past auto-fire: `carry: Player <name> released <item>`; prop/body flies at `THROW_SPEED_MPS` (props) or `THROW_SPEED_LIMP_MPS` (limp bodies). |
| M6 | 4 | While carrying: `player/<name>/carrying=true`; interaction requests reject with `actor is carrying`; punch is routed to the Carrier (no combat punch). |
| M6 | 5 | Carrier enters limp: forced drop log `Carry forced drop peer=<id> (entered limp)`; item falls with inherited velocity. |
| M6 | 6 | Late join: `Carry begin mirrored peer=<id> item=<path>` on joining client; carried item follows new carrier's anchor. |

M0 launch arguments go after Godot's `--` separator: `--host` or `--join=127.0.0.1`; optional `--port=7777`. No arguments starts offline. Movement is local-only at this milestone; remote capsules remain at their spawn positions until M3.

Alternatively, start two ordinary game instances and enter `net_host` in the first console, then `net_join` in the second. Both should report net/player_count=2. To join another LAN computer, supply its IP. Commands reject invalid IPs without leaving the current session and reject host/join while already connected or connecting (use net_disconnect first). Startup is deferred until old player cleanup finishes; watch net/status for the actual outcome. Headless separate-process checks cover console-driven default/explicit loopback joins and disconnects; rendered console hosting/joining and visible capsules/counts are user-verified; manual disconnect cleanup is user-verified.

## Notes

- Command buttons live under `Window/Layout/Tabs/Commands/CommandList`, inside an editor-authored ScrollContainer (vertical auto scrolling, horizontal disabled, follow focus enabled). Old buttons detach before replacement so repeated registry refreshes do not temporarily inflate layout height. USER VERIFIED: overflow fix works after the resize/scroll playtest handoff.
- Players unregister their two watches and status command on scene-tree exit, using their original registration names even if renamed. Other systems can remove commands with `DebugHub.unregister_command(name)` and watches with `DebugHub.unwatch(name)`. Registry changes refresh the console automatically.
- D0 checks verify queued player deletion with the console present, another player's continued watch/command access, and registration of a replacement using the departed player's name. Network disconnect testing remains part of M0.
- With the console open, player movement and jump input are blocked while gravity and collision movement continue. USER VERIFIED: movement/jump blocked and speed increases while falling off the arena with the console open. Landing with the console open remains untested.
- Keep the unlock phrase and Escape controls; the user declined an F3 toggle.
- The console is local only and never networked.
- The unlock phrase overlaps gameplay letters; the console input layer must consume those keystrokes while recognizing the phrase.
- The console is built by the user in the editor. Claude Code gives an **EDITOR TASK** for it and never builds the node tree in script.
- New systems register with `DebugHub` and the console picks them up automatically.
- No logging in hot paths. No raw `print()`.
- All commands must go through the same host-validated intent path as real input.

M2 hand names: the first instance retains its node-name command/watch suffix. Colliding names receive an instance-ID suffix; use the Commands list to find each instance. Removing one hand preserves the other registrations. Index aim now blends within a configurable 35-degree cone. Player tint uses independent opaque material overrides and retains cuff brightness contrast.

## M3 movement preview

- `net/movement_rejected`: host count of rejected movement submissions, reset on session shutdown. Normal walking/jumping should leave it at zero.
- Existing `player_status_<id>` and `player/<id>/speed_mps` report replicated remote movement as well as local movement.
- Host receives owner movement at 20 Hz, checks sequence/finite data/speed/displacement, and relays accepted samples. Invalid client movement is corrected to the last accepted position (log: `Movement corrected for player <id>`).
- Test: two arena instances, `net_host` and `net_join 127.0.0.1`; close consoles, move and jump in each. Remote capsules should move with a small interpolation delay. Disconnect/rejoin should not leave stale movement registrations.
- Automated `run_checks.ps1` includes M3 validator/interpolation checks and separate-process movement/rejection cases in the existing network runner. No new editor nodes are needed.

### M3 roster

`net/roster` is the sorted host-published list of session peer IDs (including host 1); `net/peers` remains the transport-local list. Reliable roster updates log `Roster updated` on host and `Roster received` on clients. During join/despawn, roster and `net/player_count` may briefly differ; they should converge. Shutdown clears the roster. Rejoining should replace the departed peer ID without duplicate players. Three-process late-join/reconnect checks run through `run_checks.ps1`.

### M3 interaction intents

- Client input and `interact_use_<local-id>` send reliable requests; the host chooses the actor using the actual sender ID. Host/offline inputs use the same validator.
- `net/interaction_accepted` and `net/interaction_rejected` are host counters, reset on shutdown. The host checks an existing actor/target, supported action, enabled state, prop pickup permission, 3.2 m camera-to-target-surface reach, obstruction, and a 0.15 s per-player request interval. Remote checks use the latest accepted position rather than the interpolated visual position.
- `interact` logs the host's acceptance or rejection reason on both host and requesting client. Requests inside the interval are rejected; they do not extend the interval.
- `interact/device/TestUseDevice/active` now replicates from the host, including late join and reconnect. Session shutdown resets it. There is no device color animation yet; use the watch to compare state.
- Playtest: host and join, walk the client near TestUseDevice, aim at it, and press E. Both watches should switch together; the client log should say `Interaction accepted peer=<id> action=use`. Toggle again from the host and compare. Leave the device on, disconnect/rejoin the client, and confirm its watch returns to true.
- A wall blocks focus and host validation. Disabled targets and pickup-disabled props reject before emitting interaction. GRAB still only logs acceptance; physical carry and prop physics replication remain deferred.
- Tests cover the saved-scene focus command, state/action/reach/occlusion rejection, separate-process client requests and reliable results, and current device state on late join/reconnect.

### M2/M3 replicated hand cosmetics

- The local first-person right hand points at the focused interactable. The host relays the hover state and world target to remote world hands; the left hand remains relaxed.
- `net/hand_hover_sent` counts host relays and `net/hand_hover_received` counts hover states applied to remote world hands on clients. These are cosmetic pose updates, not gameplay authority.
- On an accepted interaction, `net/hand_poke_sent` counts host poke broadcasts and `net/hand_poke_received` counts world-hand poke animations accepted on clients. Rejected interactions do not produce a remote poke.
- Two-instance check: aim at an interactable without clicking. The other instance should see that player's right hand point at it. Move aim away and the remote hand should return to idle. Then click; the other instance should see the poke and smooth return.
- If the counters remain at zero, inspect `net/roster` and `interact` logs first. If sent rises but received stays zero, inspect the client RPC/owner lookup. If received rises but the pose is invisible, inspect the remote Player Rig visibility and the world-hand attachment.

### M4 live rig preparation

Once `res://ragdoll/player_rig.gd` is attached to the visual Rig root, `rig/<player-id>/physical_bones` reports the number of physical bones prepared for that Player. Expect 11, with `Rig <player-id> prepared 11 dormant physical bones; 10 selective self-contact pairs.` in the ragdoll log. A different count emits a warning. The component stops simulation and clears physical-bone collision layers/masks while standing. During limp, 10 non-neighboring forearm/thigh/shin-to-torso pairs may contact; connected joints and remaining same-ragdoll pairs stay exempt. The isolated `ragdoll_test_*` commands use the same policy. Run `tests/run_ragdoll_collision_checks.ps1 -GodotExecutable <path>` to check the exception map; visual clipping and jitter still need an in-game drop test.

`player/<player-id>/limp` reports the handoff state, and `player/<player-id>/recovering` reports the short get-up phase after limp ends. The host-only `begin_host_limp()` and `stop_host_limp()` methods are exercised by `tests/m4_limp_handoff_test.gd`. `limp` logs the two transitions plus `finished get-up blend`. During the handoff test, the Player root remains fixed while the rig simulates as a top-level node; capsule collisions are off. Stopping restores standing collisions and blends the saved ragdoll pose to the rest pose over `GET_UP_BLEND_SECONDS` (0.5 s) at the final hips position on walkable ground.

### M4 replicated ragdoll spike

The host can use `ragdoll_spike_start <peer_id>` and `ragdoll_spike_stop <peer_id>` as temporary cheat commands. They enter/leave the same host-owned handoff as the internal test, send reliable begin/end events, and stream quantized physical-bone poses at `RAGDOLL_SEND_HZ` while active. The owner cannot issue these commands from a client. `player/<peer_id>/limp` changes on both peers; `rig/<peer_id>/physical_bones` stays at 11. The start and end appear in `limp` and `net` logs. The two-process check in `tests/run_m4_ragdoll_checks.ps1` exercises both host-owned and client-owned targets and confirms that a client receives changing bone poses.

`net/ragdoll_pose_sent` counts streamed pose packets on the host and `net/ragdoll_pose_received` counts accepted snapshots on each client. They reset when a network session shuts down. These are packet counts, not bandwidth or quality measurements.

Playtest with two windows: host in one, join from the other, then on the **host** enter `ragdoll_spike_start 1`. The client should see the host body fall, while the owner's camera follows the simulated head position and orientation; mouse look still stops at ±75° yaw and pitch relative to the ragdoll head. The head should settle without rapid left-right oscillation. The owner should see the body but not the inside of the head or face. Remote peers render replicated ragdoll bones without enabling their physical collision shapes; the host remains authoritative for actual ragdoll contact. The host now recovers automatically after at least 3.5 s when every bone is slow, or by 6 s regardless; `ragdoll_spike_stop 1` forces the same recovery early. Repeat with the client ID shown by `net/roster`. `player/<peer_id>/camera_following_ragdoll` is true only on the limp owner's machine; `player/<peer_id>/limp_elapsed_s` reports the host timer. The host sends a reliable final pose after all 11 bodies remain slow for 0.35 s; `net/ragdoll_settled_sent/received` count those events. The reliable end event carries the host's final quantized pose and selected `get_up_face_up` or `get_up_face_down` variant; both peers blend into the authored clip without a T-pose frame and remain movement-locked until it finishes. Missing clips use the procedural fallback. `net/ragdoll_pose_data_bytes_sent` excludes RPC and ENet overhead. Wall-clearance search and combat trigger are still pending.

`tests/run_m4_ragdoll_checks.ps1` now covers host/client targets, a mid-limp late join, a reliable settled pose, G2 latest-snapshot hips error, and wire rates at 15/30/60 Hz. `tests/run_m4_ragdoll_profile.ps1` runs four host ragdolls at those rates plus a standing baseline and reports application pose data, Godot physics timing, and process CPU. Its host-only payload count is a lower-bound estimate of network use; the two-process `host_wire_Bps` output uses Godot ENet's total-sent-data statistic and includes background game traffic.

### M5 recovery checkpoint

Run `tests/run_m5_recovery_checks.ps1 -GodotExecutable <path>` for the host timer, floor placement, cleanup, and two-process automatic end event. The `limp` log says `Player <id> recovered at <position>`; the `net` log says `Ragdoll spike stopped for peer <id> (settled|hard cap|manual)`. If no walkable static/elevator floor is found within 2.5 m below the hips, a `limp` warning reports fallback to the previous standing height.

Wall-clearance search runs after floor placement: if the standing capsule overlaps world/elevator/prop/player/limp geometry, it spirals outward in 0.15 m steps (8 angles per step, up to 1.5 m radius) and sets `player/<name>/wall_clearance` true when it finds a clear spot.

**G8 forced-exit cleanup:** On the host, when a limp player disconnects, `_on_peer_disconnected` calls `stop_ragdoll_spike(peer_id, "disconnect")` before erasing the peer's ragdoll epoch. This broadcasts the reliable `_ragdoll_end` event to remaining clients so their limp bodies complete a get-up blend instead of vanishing silently. The host restores the departing player's rig locally before the arena despawns the player node.


### Procedural grip diagnostics

While carrying, run `hand_status_<name>` for each hand. The status reports `pose=carry`; the hand controller stores a side value of -1 for the left hand and +1 for the right. The palm's broad surface normal is local -Y. Grip targets are derived from the carried prop's collision geometry: every enabled `CollisionShape3D` contributes its shape debug-mesh bounds after its own local offset, rotation, and scale are applied. The combined prop-local bounds are transformed into world space and projected onto the prop's oriented axes. This supports compound props and built-in `Shape3D` types without assuming every prop is a box. If no usable collision debug mesh exists, visible `MeshInstance3D` bounds are used; a small fallback remains for invisible props. Only `PoseRoot` moves; the hand attachment root stays fixed and the existing blend smooths the result.

The M2 hand test checks full-size and half-scale box collision bounds plus sphere and capsule radii. Run the project's normal `tests/run_checks.ps1` suite to execute it. The test also checks that reducing the box size produces a tighter carry finger curl. Carry curl is blended between exported tight/open joint-angle presets using the prop's projected thickness along the palm normal. Each finger now receives its own curl target: the shared tight/open blend follows projected prop thickness, then fingers nearer the prop's lateral bounds receive a small extra edge-hook curl. M2 checks that the outer fingers bend slightly farther than inner fingers. The thumb root now aims from its authored mount toward the prop center and its two joints receive a modest carry curl, creating an opposing thumb pose. M2 checks the thumb-root aim direction. This remains a geometry-guided pose heuristic, not per-finger surface contact solving or exact contour wrapping.


### Size-adaptive carry thumb

The carry thumb's two joints now blend between exported tight and open curl presets using the carried prop's projected thickness along the palm normal. Smaller props keep the tighter opposition curl; larger props leave the thumb more extended so it does not fold inward across the object. The M2 hand test compares thumb curl on full-size and quarter-scale box collision shapes. This remains a geometry-guided pose heuristic, not exact thumb surface-contact solving.


### Procedural hand action controller

The hand controller resolves one pose state, then drives the same authored finger hierarchy and `PoseRoot`. Hover pointing now moves the whole hand a small amount toward the target and rotates the wrist/hand toward it within an exported angular limit; the index finger supplies the remaining fine aim. Target tracking uses exponential pose blending, so target changes do not restart an animation or allocate per-frame objects.

A local interaction starts an `EXTENDING → CONTACT` action immediately. The authoritative host result (accepted or rejected) transitions the local viewmodel hand into `RETURNING`; a failed submission also requests recovery locally. Remote world hands only play the host-approved poke. If no result arrives, the short built-in lifecycle still returns the hand automatically. Guard, carry, and limp cancel the cosmetic action and keep their existing priority.

- `hand_status_<name>` now reports the resolved pose, action phase, hover, guard, carry, limp, and reach blend.
- `hands/<name>/state` reports the same live state through the watch.
- `hand_pose_<name> idle|point|guard|limp|reach` previews the procedural poses; reach preview starts after one second.
- M2 checks cover rejected-action recovery and rest-state completion. M3 checks cover the accepted local interaction result entering recovery and remote host-approved poke presentation.

The action controller is cosmetic only. Host interaction validation remains responsible for acceptance/rejection, and no hand pose can authorize an interaction. Godot tests and rendered two-instance visual checks must be run by the user; they have not been executed by the assistant.
