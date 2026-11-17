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
| `interact/focused/<name>` | player/focus.gd | Prompt text for the local player's focused target, or blank. |
| `interact/device/<name>/active` | interaction/debug_use_device.gd | Toggle state of the M1 test USE device. |
| `props/<name>/pickup_allowed` | props/prop.gd | Whether the prop's assigned profile allows pickup. |
| `hands/<name>/state` | hands/hand.gd | World mode, hover, guard, carry, limp, and speed state. |
| `ragdoll_test.simulating` | ragdoll/player_ragdoll_test.gd | Whether the isolated PhysicalBoneSimulator3D is simulating. |

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

### M4 live rig preparation

Once `res://ragdoll/player_rig.gd` is attached to the visual Rig root, `rig/<player-id>/physical_bones` reports the number of physical bones prepared for that Player. Expect 11, with `Rig <player-id> prepared 11 dormant physical bones; 10 selective self-contact pairs.` in the ragdoll log. A different count emits a warning. The component stops simulation and clears physical-bone collision layers/masks while standing. During limp, 10 non-neighboring forearm/thigh/shin-to-torso pairs may contact; connected joints and remaining same-ragdoll pairs stay exempt. The isolated `ragdoll_test_*` commands use the same policy. Run `tests/run_ragdoll_collision_checks.ps1 -GodotExecutable <path>` to check the exception map; visual clipping and jitter still need an in-game drop test.

`player/<player-id>/limp` reports the handoff state. The host-only `begin_host_limp()` and `stop_host_limp()` methods are exercised by `tests/m4_limp_handoff_test.gd`. `limp` logs the two transitions. During the handoff test, the Player root remains fixed while the rig simulates as a top-level node; capsule collisions are off. Stopping restores standing collisions and the rest pose at the final hips position on walkable ground.

### M4 replicated ragdoll spike

The host can use `ragdoll_spike_start <peer_id>` and `ragdoll_spike_stop <peer_id>` as temporary cheat commands. They enter/leave the same host-owned handoff as the internal test, send reliable begin/end events, and stream quantized physical-bone poses at `RAGDOLL_SEND_HZ` while active. The owner cannot issue these commands from a client. `player/<peer_id>/limp` changes on both peers; `rig/<peer_id>/physical_bones` stays at 11. The start and end appear in `limp` and `net` logs. The two-process check in `tests/run_m4_ragdoll_checks.ps1` exercises both host-owned and client-owned targets and confirms that a client receives changing bone poses.

`net/ragdoll_pose_sent` counts streamed pose packets on the host and `net/ragdoll_pose_received` counts accepted snapshots on each client. They reset when a network session shuts down. These are packet counts, not bandwidth or quality measurements.

Playtest with two windows: host in one, join from the other, then on the **host** enter `ragdoll_spike_start 1`. The client should see the host body fall, while the host's camera sits at its head and rotates with it; mouse look still works but stops at ±75° yaw and pitch relative to the head. The owner should see the body but not the inside of the head or face. The host now recovers automatically after at least 3.5 s when every bone is slow, or by 6 s regardless; `ragdoll_spike_stop 1` forces the same recovery early. Repeat with the client ID shown by `net/roster`. `player/<peer_id>/camera_following_ragdoll` is true only on the limp owner's machine; `player/<peer_id>/limp_elapsed_s` reports the host timer. The host sends a reliable final pose after all 11 bodies remain slow for 0.35 s; `net/ragdoll_settled_sent/received` count those events. `net/ragdoll_pose_data_bytes_sent` excludes RPC and ENet overhead. The capsule returns at the final hips position on the floor, and the reliable end event gives clients that position. The ~0.5 s get-up pose/camera blend, wall-clearance search, and combat trigger are still pending; recovery currently snaps to the standing pose.

`tests/run_m4_ragdoll_checks.ps1` now covers host/client targets, a mid-limp late join, a reliable settled pose, G2 latest-snapshot hips error, and wire rates at 15/30/60 Hz. `tests/run_m4_ragdoll_profile.ps1` runs four host ragdolls at those rates plus a standing baseline and reports application pose data, Godot physics timing, and process CPU. Its host-only payload count is a lower-bound estimate of network use; the two-process `host_wire_Bps` output uses Godot ENet's total-sent-data statistic and includes background game traffic.

### M5 recovery checkpoint

Run `tests/run_m5_recovery_checks.ps1 -GodotExecutable <path>` for the host timer, floor placement, cleanup, and two-process automatic end event. The `limp` log says `Player <id> recovered at <position>`; the `net` log says `Ragdoll spike stopped for peer <id> (settled|hard cap|manual)`. If no walkable static/elevator floor is found within 2.5 m below the hips, a `limp` warning reports fallback to the previous standing height.
