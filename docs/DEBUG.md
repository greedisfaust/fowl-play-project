# Fowl Play — Debug Console Reference

**Open:** type the development unlock phrase `ilovedebugging` (the
`DEBUG_CONSOLE_WORD` value). It is local-only development tooling, not a
security secret.

## Categories

| Category | Owner script | What it logs |
|---|---|---|
| net | core/network.gd | network startup, shutdown, rejected RPCs |
| combat | combat/combat_controller.gd, combat/combat_hit_detector.gd, combat/combat_presentation.gd and core/network.gd | Jab and charged-punch input, host validation, lunge hit detection, action locks, recoil and limp-body impulse |
| limp | core/limp.gd | limp start/end, recovery, phase changes |
| carry | core/carry.gd | pickup, carry, throw, drop, state |
| hands | core/hands.gd | reach, hover, guard, shake, color changes |
| legs | ragdoll/player_rig.gd and ragdoll/procedural_leg_controller.gd | Local gait phase, procedural leg pose activation, and ragdoll ownership gating |
| props | core/props.gd | spawn, grab, throw, interact, state |
| ragdoll | ragdoll/player_ragdoll_test.gd | isolated physical-bone test start/stop |
| interact | player/focus.gd and interaction/interactable.gd | focus changes, accepted/rejected interaction requests |
| screen | ui/screen_text.gd | world-screen terminal initialization and text-content diagnostics |
| player | player/player.gd | movement state and local camera input |

## Watches

| Name | Source | Meaning |
|---|---|---|
| `player/<name>/speed_mps` | player/player.gd | Current capsule velocity magnitude. |
| `player/<name>/on_floor` | player/player.gd | Whether the capsule is grounded. |
| `player/<name>/jump_coyote_s` | player/player.gd | Remaining ledge-grace time before a jump is no longer accepted. |
| `player/<name>/jump_buffer_s` | player/player.gd | Remaining buffered jump-input time before it expires. |
| `net/status` | core/network.gd | offline, hosting, connecting, connected, disconnected, or failed. |
| `net/peers` | core/network.gd | Locally known connected peer IDs, including local ID once connected. |
| `net/player_count` | arena/test_arena.gd | Spawned players in this arena instance. |
| `net/hand_poke_sent` | core/network.gd | Host count of accepted cosmetic hand-poke broadcasts sent. |
| `net/hand_poke_received` | core/network.gd | Count of remote world-hand pokes played on this instance. |
| `interact/focused/<name>` | player/focus.gd | Prompt text for the local player's focused target, or blank. |
| `screen/<node-path>/lines` | ui/screen_text.gd | Current rendered line count in a world-screen terminal. |
| `interact/device/<name>/active` | interaction/debug_use_device.gd | Toggle state of the M1 test USE device. |
| `props/<name>/pickup_allowed` | props/prop.gd | Whether the prop's assigned profile allows pickup. |
| `hands/<name>/state` | hands/hand.gd | World mode, hover, guard, carry, limp, and speed state. |
| `rig/<name>/legs_active` | ragdoll/player_rig.gd | Whether the local procedural gait is currently blended in. |
| Carry pose | hands/hand.gd | While carrying, the palm's local +Y normal smoothly turns toward the carried prop; finger curl is still the shared carry pose. |
| `ragdoll_test.simulating` | ragdoll/player_ragdoll_test.gd | Whether the isolated PhysicalBoneSimulator3D is simulating. |
| `player/<name>/wall_clearance` | player/player.gd | Whether recovery placement had to move away from a wall/prop during limp recovery. |
| `player/<name>/carrying` | player/player.gd | Whether this player currently holds a carried item (prop or limp body). |
| `player/<name>/limp_interactable_enabled` | player/player.gd | Whether this limp player's grab-target Interactable is enabled. |
| `net/combat_rejected` | core/network.gd | Rejected combat input requests. |
| `net/combat_jabs` | core/network.gd | Host-accepted jab count, including misses. |
| `net/combat_hits` | core/network.gd | Host-confirmed jab hits. |
| `net/combat_charged_punches` | core/network.gd | Host-fired charged punches. |
| `net/combat_lunge_hits` | core/network.gd | Host-confirmed charged-lunge knockdowns. |
| `net/combat_lunges_active` | core/network.gd | Number of active host-tracked lunges. |

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
| `identity_status` | none | no | no | Lists the current authoritative/replicated player identity records. |
| `identity_set` | nickname, optional palette index 0-9 | no | no | Requests a nickname and color for the local peer; the host sanitizes the nickname, suffixes duplicates, and falls forward to the next free color. |
| `net_disconnect` | none | no | no | Disconnects this instance and clears its players. On the host, ends the session for clients. Use net_host/net_join afterward. |
| `interact_use_<name>` | none | no | no | Submits the local player's focused interaction to the host. Remote-player commands reject locally. Submission is not acceptance; see interact logs. |
| `hand_status_<name>` | none | no | no | Reports this hand's cosmetic state. |
| `leg_status_<player>` | none | no | no | Reports procedural gait activation, current phase, and each foot's stance/swing state plus swing progress. |
| `leg_ground_<player>` | none | no | no | Reports each foot's ground hit, IK active state/blend weight, locked world-space anchor, current target, and surface normal. |
| `arm_ik_status_<player>` | none | no | no | Reports the Viewmodel-right arm IK target, active state, and mapped Rig bone chain. |
| `arm_ik_status_left_<player>` | none | no | no | Reports the Viewmodel-left arm IK target, active state, and mapped Rig bone chain. |
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
| M8 | 1 | Walk forward and strafe while grounded: `rig/<name>/legs_active=true`; `leg_status_<player>` reports the current gait phase and each foot's stance/swing phase. During swing, the knee flexes and the foot pitches for angular clearance; during stance, knee flexion stays restrained with a small toe-roll arc. `procedural_foot_plant.gd` provides world-space stance anchors and lifted swing targets. `PlayerRig` probes beneath both feet during physics ticks, excluding the owning Player body and filtering steep surfaces; `leg_ground_<player>` reports the latest hit, locked anchor, target, and normal. A swing captures its landing point once rather than chasing a moving probe, and the foot bone blends toward the detected surface normal while planted. The shared two-bone solver bends each thigh/shin chain toward its planted or interpolated swing target. When movement stops mid-swing, the gait now advances gently to the shared double-stance phase so neither foot remains suspended. While airborne or standing still, the gait blends toward neutral; during ragdoll/recovery, procedural legs yield to the rig lifecycle. |
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
- With the console open or the registration nickname editor active, player movement and jump input are blocked while gravity and collision movement continue. The terminal lock is released by Enter, Escape, session close, range disconnect, or terminal teardown. USER VERIFIED: movement/jump blocked and speed increases while falling off the arena with the console open. Landing with the console open remains untested.
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

### M2 advanced finger contact — first solver slice

- `Hand._get_carry_fingertip_world(finger_index)` resolves each distal tip from its third finger joint and the authored fingertip offset.
- `Hand._get_carry_finger_contact_world(finger_index)` currently solves nearest surface points for `BoxShape3D` collision children, including collision-node translation, rotation, and non-uniform scale. Compound props choose the nearest box candidate.
- Points outside a box clamp to its surface; points inside are moved to the nearest face using scaled world distances. Other shape types intentionally retain the current grip behavior until their own contact solvers are added.
- This slice calculates and tests contact targets only; it does not yet drive visible finger IK. Next: use the target to bend one finger smoothly, then generalize to the remaining fingers and sphere/capsule surfaces.
- `tests/m2_hands_test.gd` checks outside/inside box points and a transformed, non-uniformly scaled collision shape.

### M2/M3 replicated hand cosmetics

- The local first-person right hand points at the focused interactable. The host relays the hover state and world target to remote world hands; the left hand remains relaxed.
- `net/hand_hover_sent` counts host relays and `net/hand_hover_received` counts hover states applied to remote world hands on clients. These are cosmetic pose updates, not gameplay authority.
- On an accepted interaction, `net/hand_poke_sent` counts host poke broadcasts and `net/hand_poke_received` counts world-hand poke animations accepted on clients. Rejected interactions do not produce a remote poke.
- USER VERIFIED: host/client hover pointing and accepted-interaction poke synchronization were fixed and confirmed working in-game. The counters and checks below remain useful regression diagnostics.
- Regression check: aim at an Interactable without clicking; the other instance should see that player's right hand point at it. Move aim away and confirm it returns to idle, then click and confirm the remote poke and smooth return.
- If a regression occurs, inspect `net/roster` and `interact` logs first. If sent rises but received stays zero, inspect the client RPC/owner lookup. If received rises but the pose is invisible, inspect remote Player Rig visibility and the world-hand attachment.

### M4 live rig preparation

Once `res://ragdoll/player_rig.gd` is attached to the visual Rig root, `rig/<player-id>/physical_bones` reports the number of physical bones prepared for that Player. The new `rig/<player-id>/right_arm_ik` watch reports whether standing right-arm IK is currently active. Expect 11, with `Rig <player-id> prepared 11 dormant physical bones; 10 selective self-contact pairs.` in the ragdoll log. A different count emits a warning. The component stops simulation and clears physical-bone collision layers/masks while standing. During limp, 10 non-neighboring forearm/thigh/shin-to-torso pairs may contact; connected joints and remaining same-ragdoll pairs stay exempt. The isolated `ragdoll_test_*` commands use the same policy. Run `tests/run_ragdoll_collision_checks.ps1 -GodotExecutable <path>` to check the exception map; visual clipping and jitter still need an in-game drop test.

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

The hand controller resolves one pose state, then drives the same authored finger hierarchy and `PoseRoot`. Hover pointing now moves the whole hand a small amount toward the target and rotates the wrist/hand toward it within an exported angular limit; the index finger supplies the remaining fine aim. Target tracking uses exponential pose blending, so target changes do not restart an animation or allocate per-frame objects. Pokes are deliberately retriggerable during extension, contact, or recovery: each new poke starts from the current reach blend and eases toward the new target, with no animation cooldown or snap. When clicks stop, the current action finishes its short contact/recovery and the hand blends back to hover pointing or idle. This visual spam does not bypass host interaction validation or its gameplay request throttle.

A local interaction starts an `EXTENDING → CONTACT` action immediately. The authoritative host result (accepted or rejected) confirms the action result; the hand completes its extension/contact phase before entering `RETURNING`; a failed submission also requests recovery locally. Remote players' camera-attached Viewmodel right hands receive replicated hover pointing and only play host-approved pokes. The ragdoll Rig hands remain reserved for the physical/ragdoll representation and carry grip; ordinary pointing/poking does not target them. If no result arrives, the short built-in lifecycle still returns the hand automatically. Guard, carry, and limp cancel the cosmetic action and keep their existing priority.

- `hand_status_<name>` now reports the resolved pose, action phase, hover, guard, carry, limp, and reach blend.
- `hands/<name>/state` reports the same live state through the watch.
- `hand_pose_<name> idle|point|guard|limp|reach` previews the procedural poses; reach preview starts after one second.
- M2 checks cover mid-animation retriggering without snapping, rejected-action recovery, and rest-state completion. M3 checks cover accepted local interaction results and repeated remote world-hand pokes.

The action controller is cosmetic only. Host interaction validation remains responsible for acceptance/rejection, and no hand pose can authorize an interaction. Godot tests and rendered two-instance visual checks must be run by the user; they have not been executed by the assistant.


### M2 surface-directed index carry bend

The first visible contact-response slice now uses the index fingertip's nearest BoxShape3D surface target to add a restrained directional correction to its three bend joints. The correction is weighted and clamped by `carry_contact_bend_weight` and `carry_contact_bend_limit_degrees`, then uses the existing exponential pose blend; the other fingers keep their established size/edge curl until this technique is visually approved. CollisionShape3D children are cached when the carried item changes, rather than rediscovered during the frame loop. This is a directional bend assist, not full inverse kinematics or guaranteed physical contact. M2 checks that a transformed box produces a non-zero, bounded index correction. Godot execution and visual confirmation remain user-run.


### M2 all-finger surface-directed carry bend

The box-surface contact bend is now applied to all four fingers (index, middle, ring, pinky), each using its own current fingertip and nearest BoxShape3D contact target. The per-finger correction remains weighted and angularly clamped, with the existing exponential joint blend preserving smooth transitions. Sphere and capsule surface solvers are not included in this slice. M2 checks finite, bounded corrections and confirms at least one finger responds to a transformed box. Godot execution and visual confirmation remain user-run.


### Hand rig multiplayer milestone

See [HAND_RIG_MULTIPLAYER_MILESTONE.md](HAND_RIG_MULTIPLAYER_MILESTONE.md) for the complete host/client verification matrix and implementation order. The current hand diagnostics are listed there, including `hand_status_<name>`, `hands/<name>/state`, `net/hand_poke_sent`, and `net/hand_poke_received`.

Important: these counters and automated receive-handler tests are diagnostic support, not proof of live RPC delivery. Verify each action with two running instances and test both host-as-actor and client-as-actor. Record sender, relay/authority, receiver, and rendered-hand results separately. Do not mark the hand rig multiplayer-ready until the full matrix passes.


#### Hover replication counter semantics

`net/hand_hover_sent` counts host broadcasts of hover state. `net/hand_hover_received` counts successful applications to a remote player's Viewmodel right hand on the instance doing the application. This includes the host applying a connected client's hover to that client's camera-attached Viewmodel hand; it intentionally does not count the owning peer's local Viewmodel copy, because Focus drives that hand directly. A received counter should therefore be interpreted alongside the local role and which player's remote rig is visible.


### Per-player hand instance diagnostics
- Run `player_hands_<peer_id>` to print FPS-left, FPS-right, world-left, and world-right hand instances for one player.
- Each entry reports its node name, instance ID, `world_mode`, and current cosmetic state. Use this before comparing hand commands so the FPS and world instances cannot be confused.


### Longer pokes and moving ragdoll carry grips

The procedural poke reach distance is now 0.28 world-space metres (previously 0.20 hand-local units). The controller converts that distance through each hand's transform, so scaled first-person Viewmodel hands and unscaled world hands travel the same visible distance. Extension, contact, and return timings are unchanged, including the existing 0.18-second return.

Carry pose events now drive the camera-attached Viewmodel left/right hands on both the owning peer and remote observers. Remote carry presentation therefore uses the same Viewmodel instances as pointing and poking; the ragdoll Rig hands remain untouched by ordinary carry poses.

When the carried target is a limp player, cosmetic hand grips use the live Chest PhysicalBone3D position and orientation, matching the existing chest spring-damper carry anchor instead of the stationary CharacterBody3D root or hips. The two hands approach opposite sides of the chest, use a relaxed carry curl, and skip static-box fingertip contact correction. The existing hips target remains unchanged for gameplay interaction/recovery. Ordinary props retain their existing collision-bound grip solver. M2 checks verify the grip follows a moving chest target and the longer poke distance; M3 checks verify remote carry drives Viewmodel hands and leaves Rig hands untouched. Godot execution and in-game visual confirmation remain user-run.



### M2 procedural hand visual handoff

- Both camera-attached Viewmodel hands are the standing presentation owners. The duplicate positive-X and negative-X Rig hand meshes are hidden while standing; their skeleton attachments and physical-bone setup remain intact.
- Both Rig hand scenes become visible when host physical ragdoll simulation or remote ragdoll pose playback begins, then hide again when simulation ends and recovery owns the skeleton. `rig/<player-id>/right_rig_hand_visible` and `rig/<player-id>/left_rig_hand_visible` report the visual states.
- Both Rig forearm render capsules are extended from 0.27 m to 0.34 m and centered at mirrored ±0.14 m positions. This is render geometry only; PhysicalBone collision capsules and bone lengths are unchanged.
- The `Forearm` MeshInstance3D inside each Rig-attached Hand scene (`Hand/PoseRoot/Forearm`) is hidden on both world hands by `player_rig.tscn` instance overrides. The camera Viewmodel Hand scenes are untouched.

### M2 procedural two-arm IK — first integration slice

- The camera-attached Viewmodel right hand targets the positive-X Rig chain `UpperArm_L/Forearm_L/Hand_L`; the Viewmodel left hand targets the negative-X Rig chain `UpperArm_R/Forearm_R/Hand_R`. Mapping is spatial: Viewmodel side names do not match the Rig's suffixes.
- Both chains use the shared two-bone position solver with their authored bone lengths, reachable-distance clamping, a downward/forward elbow pole, and exponential blending. Each wrist target comes from its own Viewmodel hand's `PoseRoot` at local `(0, 0, 0.32)`.
- Both duplicate Rig hand meshes are hidden during standing presentation so the Viewmodel hands remain the visible hands. Both Rig hand meshes are restored for host ragdoll simulation and remote ragdoll pose playback, then hidden when simulation ends and recovery owns the skeleton. Their skeleton attachments and physical bones remain intact.
- Both Rig hand-scene `Forearm` MeshInstance3D children are hidden through `player_rig.tscn` instance overrides and explicitly excluded from the hand-visibility toggles, so they stay hidden even during ragdoll. The FPS Viewmodel hand scenes are untouched. Both Rig forearm render capsules now bridge toward their wrist targets with mirrored 0.34 m mesh geometry. PhysicalBone collision shapes and bone lengths are unchanged.
- IK runs only in the Player standing update path. PlayerRig refuses to write either arm while PhysicalBoneSimulator3D, remote ragdoll pose playback, or recovery blending owns the skeleton.
- `Head/Camera3D/ViewmodelHands` is hidden on host and remote Player instances when ragdoll begins, then restored only after recovery blending completes. The Rig's physical hands remain the ragdoll presentation.
- Standing arm IK permits up to 12% visual bone-axis extension when a wrist target exceeds normal combined reach. It returns to authored scale as the target comes back into range and resets to unit scale before ragdoll/recovery ownership; PhysicalBone collision shapes and ragdoll simulation are unchanged.
- Debug watches: `rig/<player-id>/right_arm_ik`, `rig/<player-id>/left_arm_ik`, `rig/<player-id>/right_rig_hand_visible`, and `rig/<player-id>/left_rig_hand_visible`. Commands: `arm_ik_status_<player>` and `arm_ik_status_left_<player>`.
- `tests/m2_procedural_arm_test.gd` checks both wrist targets, the Viewmodel visibility toggle, hidden world-hand forearm meshes, the 12% stretch cap, and ragdoll ownership. Run `tests/run_checks.ps1`; Godot execution and rendered two-instance verification remain user-run.


### Interactable silhouette outline

Every `Interactable` component automatically adds an inverted-hull silhouette overlay to all descendant `GeometryInstance3D` nodes of its owning target. It preserves each mesh's previous `material_overlay` and restores it when the component leaves the scene tree.

- Idle: thin near-black outline, no glow.
- Focused: smoothly transitions to a wider warm-gold outline with restrained emission.
- Focus is still owned by `player/focus.gd`; the outline does not perform raycasts or change interaction authority.
- `interact/highlight/<node-path>/state` reports `idle` or `focused`.
- The `interact` log reports focus-driven highlight state changes.
- `tests/m1_interaction_test.gd` checks automatic idle outlines, no outline on a sibling mesh without an Interactable, gold/glow focus state, return to idle, and restoration of the original overlay.

The test arena has an editor-authored `WorldEnvironment` with restrained Glow enabled. USER VERIFIED: the animated golden outline/highlight treatment is implemented and working. Glow is scene-wide as a rendering pass, but only bright pixels (including focused outline emission) should contribute significantly. The environment is currently attached to `test_arena.tscn`; when a shared production world/environment is introduced, move or reuse these settings there rather than duplicating per-level environments. The outline remains an inverted-hull shader and does not depend on custom post-process code.



### Gameplay cursor and focus animation

- The center-screen cursor is a CanvasLayer under Player, and only the local player's instance is enabled while the mouse is captured.
- Idle: a small translucent white circle with a thin dark outline.
- Focused: it smoothly grows, blends toward its configurable identity accent, and gains three soft translucent glow rings. A gentle 1.8-second breathing pulse scales the cursor while focused.
- `GameplayCursor.set_identity_color(color)` receives the host-assigned identity color. Its configured accent is used as a fallback when identity data is unavailable (offline/startup/shutdown).
- The focused Interactable outline has a separate, slower 2-second breathing glow. Only emission intensity pulses; outline width and silhouette stay stable. The existing test-arena WorldEnvironment Glow creates the soft bloom.
- Focused regression checks: `tests/run_checks.ps1` for the cursor contract and `tests/m1_interaction_test.gd` for the Interactable outline. User has confirmed the in-game golden highlight works; the assistant has not independently rerun Godot here.


### Player identity core

- `net/identities` lists identity records sorted by peer ID. Each record contains `peer_id`, `nickname`, and `color_index`; `PlayerIdentity` resolves the stable palette name and `Color`.
- `identity_status` prints the current identity roster.
- `identity_set <nickname> [color_index]` requests a local identity. Palette indexes are Red 0, Orange 1, Yellow 2, Green 3, Cyan 4, Blue 5, Purple 6, Pink 7, Black 8, White 9.
- The host derives the requesting peer from the RPC sender, strips control characters/outer whitespace, limits nicknames to 16 characters, defaults blank names to Chicken, and suffixes case-insensitive duplicates (`Chicken 2`, `Chicken 3`, ...).
- If a requested color is occupied, the host checks subsequent palette entries in wraparound order and assigns the first free color. A peer's existing color is excluded when that peer changes its own selection.
- A reliable host-published identity roster carries the authoritative records. Disconnect and shutdown remove identity records.
- `tests/m3_identity_test.gd` checks peer IDs, display labels, nickname suffixing, blank-name fallback, palette size, color uniqueness, next-color fallback, and invalid requests. It is registered as the `identity` stage in `tests/run_checks.ps1`.
- USER VERIFIED: the identity registration/color flow and host/client presentation work in-game. The focused identity test remains available for regression checks; the assistant did not independently rerun Godot for this archive.


### Physical USE button

- `interact/button/<node-path>/press_count` counts accepted USE events presented by a reusable physical button component.
- The component listens to the existing `Interactable.interacted` signal. Only the authoritative host/offline instance starts the animation and sends a reliable presentation RPC to clients; clients validate the host sender before playing it.
- `interact_use_<player>` remains the debug command for exercising the real focus and host-validation path. Aim at the button and press E to see the cap press.
- Expected: `interact: <button> physical button pressed (<count>)` when the interact category is enabled. Repeated presses restart from the cap's current position and settle at its saved rest position.
- `tests/m3_physical_use_button_test.gd` checks USE-only activation, retrigger continuity, and return to rest. It is registered as `physical-button` in `tests/run_checks.ps1`. Godot execution and rendered multiplayer verification remain pending.


### WorldScreen — reusable size-adaptive display and isolated text glow

- Scene: `res://environment/kit/world_screen.tscn`; root controller: `world_screen.gd`; text control: `SubViewport/ScreenText`.
- Required direct children of WorldScreen: `Display` (opaque physical panel), `TextDisplay` (transparent text overlay), and `SubViewport`. Keep ScreenText inside SubViewport.
- `Display` uses a dark, non-emissive material with no ViewportTexture. `TextDisplay` matches the Display PlaneMesh size/orientation and sits slightly in front of it; its material is configured by WorldScreen at runtime.
- SubViewport must use Transparent Bg and HDR 2D. It contains only ScreenText; do not add a full-screen Background ColorRect. ScreenText's normal StyleBox remains transparent.
- WorldScreen routes the SubViewport texture to TextDisplay's albedo and emission. Because the viewport background is transparent, only rendered glyphs contribute to the overlay; the physical panel is not part of the emission texture.
- The CanvasItem shader is assigned to ScreenText by WorldScreen. It boosts glyph RGB into HDR and applies a circular dot mask to glyph alpha. It does not modify Display.
- Text Glow exports: `text_glow_enabled`, `text_glow_boost` (default 2.2). LED Matrix exports: `led_matrix_enabled`, `led_dot_size`, `led_gap`, and `led_softness`. Dot size is measured in SubViewport pixels; smaller values create a finer matrix. A starting range of 3–5 px is recommended for the 2048 × 1152 default viewport.
- The TextDisplay overlay uses alpha transparency, unshaded rendering, and an emission texture. The existing WorldEnvironment must have Glow enabled for HDR glyphs to bloom.
- Resize through root `display_size`, not root Transform Scale. The controller updates both PlaneMeshes, SubViewport resolution, and responsive font size.
- Run `tests/run_checks.ps1` to include the WorldScreen stage. Isolated: `godot --headless --path fowl-play --script res://tests/m3_world_screen_test.gd`. The test checks sizing, transparent HDR viewport, text shader settings, overlay material when the editor-authored TextDisplay exists, per-instance isolation, and independent content. Godot execution and rendered visual verification remain user-run.


## SLIM WorldScreen kit

- The editor-authored `slim_world_screen.tscn` hierarchy is `SlimWorldScreen/WorldScreen`, `Housing`, `Bezel/{Top,Bottom,Left,Right}`, and `Glass`.
- Attach `res://environment/kit/slim_world_screen.gd` to the `SlimWorldScreen` root. Its exported `display_size`, `bezel_thickness`, and `housing_depth` properties resize the WorldScreen, backing plate, four bezel pieces, and glass together.
- The controller aligns the backing plate, bezel, and glass to the existing WorldScreen's XZ-facing display plane. Keep the authored child names stable.
- Glass uses `slim_world_screen_glass.gdshader`: a faint cool tint, physically lit clearcoat/specular response, angle-based Fresnel sheen, and a restrained near-camera fade. This is a stylized sheen, not a captured real-world reflection; visible environment reflections depend on scene lighting/reflection probes.
- `glass_base_opacity`, `glass_sheen_strength`, `glass_sheen_near_distance`, and `glass_sheen_far_distance` tune the effect. The default keeps the screen readable and the glass understated.
- Run `tests/run_checks.ps1` stage `slim-world-screen` for the headless geometry/resizing contract. Godot execution and rendered visual tuning remain user-run.

- Glass uses a default-orientation PlaneMesh (XZ plane); do not rotate it 90 degrees. The backing BoxMesh and bezel boxes are rotated 90 degrees around X because their broad faces are authored in XY.


### FAT WorldScreen kit

- Editor-authored scene: `res://environment/kit/fat_world_screen.tscn`. Attach `res://environment/kit/fat_world_screen.gd` to the `FatWorldScreen` root. The controller does not create or replace scene nodes.
- Required root children: `WorldScreen`, `Chassis`, and `Glass`. Chassis groups: `OuterShell`, `InnerArmor/{TopArmor,BottomArmor,LeftArmor,RightArmor}`, `CornerArmor/{TopLeft,TopRight,BottomLeft,BottomRight}`, `SideDetails/{LeftVent,RightVent}`, `ControlPanel/{PanelBody,IndicatorGroup,IdentificationPlate}`, and `Fasteners/{TopLeft,TopRight,BottomLeft,BottomRight}`.
- The controller repositions/regenerates the named CSG silhouettes, vent bars, control strip, plate, fasteners, and glass from `display_size`. It preserves authored materials and the TextMesh resource; keep the node names stable.
- `display_size` resizes WorldScreen, the clipped eight-point chassis, inner armor, corner plates, vent spacing, lower control strip, identification plate, fasteners, and glass. Chassis depth, armor thickness, corner cut, and glass finish remain adjustable in the Inspector.
- Godot's CSGPolygon3D Depth mode extrudes toward negative Z, so the outer shell's front face is positioned just behind the display at Z = -0.005 and its body extends backward. The inner armor, control panel, TextMesh lettering, fasteners, and glass are layered toward the front (+Z). Glass reuses the same shader and defaults as SLIM.
- Prefer `MeshInstance3D` with a `TextMesh` resource for crisp physical in-world lettering rather than small `Label3D` textures.
- Run `tests/run_checks.ps1` stage `fat-world-screen`, or `godot --headless --path fowl-play --script res://tests/m3_fat_world_screen_test.gd`. Godot execution and rendered visual verification remain user-run; this implementation has not been run in Godot.


### FAT WorldScreen

- The FAT housing controller reads its chassis at `WorldScreen/Chassis`, matching the authored scene hierarchy. The four authored fasteners use the `TopLeftFastener` / `TopRightFastener` / `BottomLeftFastener` / `BottomRightFastener` names and are repositioned by the controller.
- In the editor, changing `FatWorldScreen.display_size` should resize the WorldScreen content, CSG chassis plates, vents, control strip, identification plate/text, fasteners, and glass together. Run the `fat-world-screen` headless contract stage after pulling controller updates; visual alignment still needs editor verification.


### SLIM WorldScreen — Precision Cyber Industrial pass

- SlimWorldScreen now supports optional FrontTrim, LightingSystem, SideDetails, Identification, and MechanicalDetails groups. The controller creates generated child containers beneath each group and rebuilds only those generated children when dimensions or finish settings change; authored nodes outside the generated containers are preserved.
- New exported finish controls: trim width, light width, cyan/amber light colors, and emissive energy. The controller lays out machined trim rails, perimeter/corner light channels, status indicators, side vent inserts, a model plate, and micro-fasteners relative to display_size.
- Verify in the editor by adjusting display_size and confirming the new details follow the housing. For a headless contract check, run godot --headless --path fowl-play --script res://tests/m3_slim_world_screen_test.gd. Godot tests and rendered visual verification have not been executed by the assistant.


### Reusable WorldScreen presentation presets
- `WorldScreen.show_layout(layout, header, body, prompt = "")` replaces the selected screen's content using a named color treatment. Supported names: `standard`, `welcome`, `information`, `warning`, `success`, and `confirmation`.
- `WorldScreen.set_content(header, body, prompt = "")` is the standard-color replacement shortcut. Existing append and clear methods remain available. Presets affect only text colors; they do not alter screen geometry, font, LED/glow settings, or alignment.


## WorldScreen / ScreenText

- Category: `screen` — registered by `ui/screen_text.gd`; logs terminal initialization when enabled.
- Watch: `screen/<node-path>/lines` — current RichTextLabel line count for that ScreenText instance.
- Screen content APIs are documented in [WORLD_SCREENS_AND_SCREEN_TEXT.md](WORLD_SCREENS_AND_SCREEN_TEXT.md): append methods, replacement via `set_content`, and named presets via `show_layout`, and inner safe margins via `WorldScreen.content_padding_ratio` (default 0.70).
- The screen's visual pipeline is split: opaque `Display` backing, transparent emissive `TextDisplay`, and `SubViewport/ScreenText`. If the whole panel blooms, inspect that split before adjusting WorldEnvironment Glow.
- No dedicated screen commands currently exist. Screen changes are driven through the WorldScreen / ScreenText script APIs.


## Interactive screen menus

- `ScreenMenu` (`ui/screen_menu.gd`) is an input-independent menu model rendered through WorldScreen/ScreenText.
- Semantic actions: `menu_up`, `menu_down`, `menu_confirm`, and `menu_cancel`, forwarded through `ScreenMenu.handle_action()`. It does not capture global input or add InputMap actions.
- Signals: `opened`, `selection_changed`, `option_confirmed`, `cancelled`, and `closed`.
- Focused test: `screen-menu` stage / `tests/m3_screen_menu_test.gd`.
- Keyboard/gamepad and physical USE routing are deferred to Registration Terminal integration to prevent inactive screens stealing player controls.


## Registration Terminal

- USER VERIFIED: the terminal interaction/registration flow and the fixes to its wake/session/proximity behavior are working. Keep the checks below as regression guidance.
- Attach `ui/registration_terminal.gd` to the existing terminal root; it inherits InteractiveTerminal.
- Assign inherited `screen`, `screen_interactable` (on the physical screen target), and `proximity_area` references in the Inspector. The sensor CollisionShape3D should match the 5 m wake distance.
- Arrow Up/Down navigate, Enter confirms, Escape closes; E/M1 on the screen Interactable begins the session or confirms the selected menu item. Players can move freely; the base ends the session outside interaction_distance (default 3 m, horizontal distance). Nickname entry supports printable keys, Backspace, Enter, and Escape.
- The local interaction-request signal is only a local presentation/input hook. Host-side range, actor, and Interactable validation remain in Network.
- Focused check: godot --headless --path fowl-play --script res://tests/m3_registration_terminal_test.gd.
- Multiplayer verification: open the terminal from a client and host, submit duplicate nicknames and occupied colors, and confirm the displayed identity matches the host's net/identities roster.


- Registration menu: while active, mouse cursor is visible. Left-click an option row on the WorldScreen to select and confirm; click elsewhere to do nothing. Keyboard arrows/Enter and E/M1 on the screen Interactable remain active. Closing/completing/rejecting registration restores the prior mouse mode.


- Player movement no longer has a `registration_terminal_active` override. Registration terminals must not freeze player movement; use session proximity/range handling instead.


- InteractiveTerminal state can be inspected with `is_awake()`, `has_active_session()`, and `get_active_actor()`. The proximity Area3D must overlap the local player body; its CollisionShape3D should match `wake_distance`.


## Interactive terminals
- Inspect `InteractiveTerminal.is_awake()`, `has_active_session()`, and `get_active_actor()` while debugging a terminal.
- The editor-authored proximity Area3D should match `wake_distance` (default 5 m); code enforces `interaction_distance` (default 3 m, horizontal by default).
- Only local player bodies with `is_local_player == true` wake the display. Proximity alone does not begin a session.
- E/M1 on the screen Interactable begins a session; repeated E/M1 confirms the active menu. The physical USE button is optional.
- Focused tests: `interactive-terminal` and `registration-terminal` stages. Setup: `docs/REGISTRATION_TERMINAL_SETUP.md`.

- Registration Terminal wording is configured on the `RegistrationTerminal` root under the **Registration Copy** Inspector group. Idle/wake wording uses inherited `idle_header`, `idle_description`, and `idle_prompt` exports. See `docs/REGISTRATION_TERMINAL_SETUP.md` for formatting placeholders.


## Player nameplates
- Each remote player displays the assigned nickname only; networking peer IDs remain internal and are not rendered.
- The reusable NamePlate scene uses a transparent 512 × 128 SubViewport displayed on a QuadMesh. Its root faces the active local camera and fades between the exported `fade_start_distance` and `fade_end_distance` values (defaults 18 m and 28 m).
- The NamePlate scene must contain `Panel` (MeshInstance3D), `Display` (SubViewport), and `Display/UI` with `Background`, `Accent`, `Nickname`, `Divider`, and `Status`. The Player's `NamePlate` child must be a Node3D instance of that scene.
- Focused contract: `identity-presentation` stage in `tests/run_checks.ps1`; rendered readability, occlusion, and host/client appearance require in-game verification.


## Player nameplate polish
- The plate is 78% scale (22% smaller) and its nickname is horizontally centered.
- It faces the camera with the QuadMesh display side toward the viewer; mirrored text should no longer occur.
- Rest opacity is 12%; aiming the center-screen cursor at the plate (or moving a visible pointer over it) smoothly raises opacity to 100%. Distance fade still applies beyond 18–28 m.
- Player.gd attaches the plate to `Rig/Skeleton3D/HeadAttachment`, so the plate follows the actual head bone during ragdoll, remote pose playback, and recovery. If it does not follow, inspect that the Player's `NamePlate` is a direct child before runtime; the controller reparents it during Player._ready().
- Focused contract: `identity-presentation` stage. Run `tests/run_checks.ps1`; in-game visual and multiplayer checks remain required.


### Nameplate text and plate opacity
- Nickname and status labels remain fully opaque (alpha 1.0) whether or not the player is being aimed at.
- Only the decorative backing, identity accent rail, and divider use the hover opacity transition (default 12% idle, 100% aimed-at). The distance fade affects those decorative elements only.
- The runtime HeadAttachment local Y offset is 0.62 m, raised from 0.56 m to improve clearance above the head.
- The scene design is not final; the current hierarchy is a stable base for further visual polish. Add or restyle decorative elements in the user-authored scene without changing the required node names.


## Player identity body colors
- Each spawned Player resolves its host-assigned PlayerIdentity color and passes it to the world Rig, both attached Rig hands, and both camera-attached Viewmodel hands.
- The Rig duplicates its visible geometry materials before tinting, preserving source resources and per-instance independence. The temporary `FacePhoto` placeholder is excluded.
- The nameplate accent continues to use the same `PlayerIdentity.get_color()` value.
- USER VERIFIED: player identity coloring works in-game, including the character presentation, world and first-person hands, and ragdoll. The nameplate's identity accent uses the same palette color; nickname text stays white for readability. Regression check: compare different host/client colors, then knock down, carry, throw, and recover each player to confirm colors persist.


## Procedural footstep planner
- Landing targets are calculated relative to each thigh/hip using the rig's smoothed movement direction, not by projecting a long distance from the current trailing foot.
- The planner offsets left/right feet perpendicular to movement, preserving separation during forward/backward movement, strafing, and diagonals.
- Forward landing prediction uses the root travel over the swing fraction: `LEG_STEP_CYCLE_DISTANCE_M * (1 - LEG_STANCE_FRACTION)`. The planner target is then raycast vertically at the current sole height.
- `leg_ground_<player>` reports the captured world-space anchor and current planner/plant target. If the target is not where expected, inspect the rig's movement direction and hip position before changing the ground probe.
- Focused regression coverage: M8 `procedural-legs` stage. Godot execution and in-game verification remain pending.


- Follow-up refinement: hip-relative predicted targets are used only for a foot that is actively in swing. Stance feet continue probing their current sole, so standing initialization and stop-settling cannot pull a planted foot toward a forward target. Both targets are calculated from the midpoint between the hips to avoid doubling the lateral separation.


## Leg spacing, smoother planting, and earlier step timing — 2026-11-20

- Reduced `LEG_STANCE_FRACTION` from 0.58 to 0.50 so each foot enters swing sooner and spends less time trailing before requesting a new landing target.
- Foot lateral placement now always uses the rig's anatomical right axis, rather than an axis perpendicular to movement. This prevents left/right targets from swapping sides during strafing and diagonals.
- Two-bone IK pole targets now receive an outward lateral bias per leg, encouraging knees to bend in separate planes instead of converging through one another.
- Reduced procedural leg IK blend response from 14 to 8 to soften sudden thigh/knee corrections when a new planted target is acquired.
- Replaced cubic smoothstep with quintic smootherstep for the swing path, reducing abrupt velocity changes at lift-off and touchdown.
- Added planner regression assertions for anatomical left/right separation during strafing and diagonal movement.
- Godot tests and in-game verification remain pending; this is procedural pose separation, not physical collision bodies between the legs.


## Readable knee-lift walking pass — 2026-11-20

- Restored the stance fraction from 0.50 to 0.58 so each foot has a more readable planted/support phase rather than spending half the cycle in swing.
- Increased swing-foot vertical arc from 0.12 m to 0.28 m so the foot visibly clears the floor.
- Changed knee flexion to bend early, hold through most of forward swing, and extend during the final approach to landing. The two-bone IK then follows the elevated foot target, producing the intended knee-up-then-place motion.
- Reduced ground-hit foot clearance from 0.04 m to 0.015 m to reduce visible hovering. The value remains a small ankle/sole offset, not a guarantee of exact mesh contact because the foot bone origin is not necessarily the bottom of the shoe.
- Added/updated M8 assertions for visible knee bend and the larger swing arc. Godot tests and in-game verification remain pending.


## Gait cadence and anatomical spacing refinement — 2026-11-20

- Added `LEG_GAIT_RATE_MULTIPLIER = 0.78` to slow the procedural step cycle independently of player movement speed. The player still moves at the same gameplay speed; only gait phase advances more deliberately.
- Increased the rig's hip-relative landing-zone lateral offset from 0.18 m to 0.24 m to keep the feet in clearer left/right lanes.
- Increased the per-leg outward knee-pole bias from 0.30 m to 0.48 m so IK solutions favor separate knee bend planes.
- Updated the gait phase regression expectation to include the cadence multiplier.
- This is a soft anatomical separation constraint, not physical leg collision. Godot tests and visual verification remain pending.


## Procedural leg recovery diagnostics

The `leg_ground_<player>` command now reports each foot's emergency-replant state and current hip-to-anchor stretch ratio, normalized against that leg's comfortable reach. A stretch ratio at or above 1.0 requests a recovery step when the foot is in stance. Only the more-stretched foot is allowed to emergency-step at a time.


## Procedural leg side and knee diagnostics

The authored rig's `Thigh_L` bone is on local +X and `Thigh_R` is on local -X. Footstep planner and IK side arguments follow that exact mapping: left = +1, right = -1. The gait controller exposes per-leg knee bend weights; the IK pole uses those weights to increase forward knee flex during swing while retaining the outward anatomical bias.


## Procedural leg reach and swing lift

- Leg IK now allows a smoothed, cosmetic reach extension up to `LEG_IK_MAX_STRETCH_RATIO` (1.14). Both thigh and shin bone scales are adjusted along their authored bone axes, so attached limb meshes stretch with the IK chain rather than leaving the visible geometry behind. Scales return to identity when IK is no longer active or when ragdoll/other pose ownership takes over.
- Swing and emergency recovery foot arcs use `LEG_REPLANT_LIFT_M` (0.30 m). Thigh swing is tuned to 46 degrees, knee flex to 68 degrees, and the IK pole adds a stronger forward bias while the knee is flexed.
- M8 checks cover the configured stretch/lift range and a farther two-bone IK target.


## Procedural gait sync and knee direction

- Gait phase now advances from the measured horizontal player velocity rather than the smoothed direction-filter velocity. Direction still blends for smooth turning, while cadence no longer waits for the velocity filter to catch up.
- Stride cycle distance is 1.4 m with a 1.0 cadence multiplier. Normal landing targets are placed 0.40 m ahead of the hip at touchdown, after accounting for predicted swing travel. At the 0.58 stance fraction, the foot ends stance about 0.412 m behind the hip; combined with the 0.84 m vertical two-bone rest reach, this is about 0.936 m, within the 0.94 m replant margin. Emergency replants also predict root travel over the 0.18 s recovery arc.
- Leg IK pole guidance now favors anatomical outward knee placement (0.95 m) with a reduced forward component (0.55 m base plus 0.35 m swing bias). Arm IK retains its independent pole tuning.
- M8 checks assert stance travel remains below the leg reach margin and that mirrored left/right IK poles place each knee outward from the centerline.


## Knee bend direction correction

- The shared two-bone IK solver interprets its pole argument as a direction relative to the hip/shoulder, not a world-space pole position. The leg controller now passes a character-facing world direction directly instead of adding the hip world position first. This prevents character translation and heading from distorting the bend plane.
- Forward pole weight is now 1.0, swing adds up to 0.45, and outward bias is a mild 0.18. The intended result is forward knee flex with a subtle outward anatomical angle at every heading.
- M8 solver checks use hip-relative pole directions and require both forward and outward bend for mirrored legs.


## Sideways gait foot lanes

## Rapid direction-change gait response

- Gait heading smoothing now uses a faster response when the incoming movement direction differs sharply from the current smoothed heading (dot product below 0.55). Normal directional changes retain the original smoother response; sharp turns use a 42 response rate.
- Filtered heading magnitude also tracks incoming speed with the faster response so repeated perpendicular/reversing inputs do not collapse the planner direction toward zero. This is intended to keep footstep targets following rapid WASD zig-zags without making ordinary walking jittery.
- M8 includes a repeated forward/right/back/left sequence at 20 updates per second and checks that the filtered heading tracks each new direction.


- Footstep planning now keeps the two foot lanes perpendicular to the current movement direction instead of forcing them to remain on fixed anatomical left/right offsets. Forward/backward movement still uses the rig-right axis; pure strafing uses the character-forward axis, giving the feet stable front/back lanes.
- The same movement-relative axis is used by landing-target separation constraints, so a leading foot is not pushed back across the hip centerline while strafing. Lane orientation remains stable for left and right strafes.
- M8 coverage now checks rightward and leftward strafing, front/back separation, and movement-relative replant constraints.


## Moving-support foot planting

- `leg_ground_<player>` reports the current world-space planted targets and anchor state. A planted foot now also stores its contact point in the supporting `Node3D`'s local space.
- When the support translates or rotates, the planted target is transformed back into world space so the foot follows the elevator/platform instead of remaining behind.
- The ground probe passes its hit collider into the foot-plant tracker. Static floors continue to work as before; if a support is freed, the anchor safely remains at its last world position.
- M8 regression coverage checks both translation and rotation of a moving support. Run the Godot M8 test and verify in-game on a moving elevator/platform; these checks have not been run by the assistant.


## Movement tuning — 2026-11-20

- Normal movement uses `PLAYER_SPEED_MPS` (3.8 m/s); holding the `sprint` input action uses `PLAYER_RUN_SPEED_MPS` (8.0 m/s).
- Horizontal velocity accelerates at `PLAYER_ACCELERATION_MPS2` and decelerates at `PLAYER_DECELERATION_MPS2`, including smooth directional changes. Sprint only changes the target speed while movement input is held.
- The procedural gait blends its stride amplitude and cadence toward a more energetic run as measured speed rises. This remains cosmetic and does not change movement authority or replication.
- Input Map handoff: create the `sprint` action and bind Left Shift. The player script intentionally does not edit project settings or scenes.


### Jump movement playtest

- Ground jump: tap and hold Space separately; a tap should produce a shorter hop, while holding should reach the full jump height.
- Coyote time: run off a ledge and press jump immediately afterward; the short grace window should still allow takeoff.
- Jump buffer: while descending, press jump just before touching down; the next grounded physics tick should launch the next jump.
- Air control: steer left/right in the air and compare with grounded steering; air corrections should be weaker and preserve more momentum.
- Debug watches `player/<name>/jump_coyote_s` and `player/<name>/jump_buffer_s` show the active grace/buffer windows. These are local movement values; no new network stream is added.


### Movement feel calibration — 2026-11-20

- Ground direction changes use a dedicated 24 m/s² turn response when the requested direction differs sharply from current horizontal momentum. Ordinary acceleration remains 14 m/s² and deceleration remains 18 m/s², so starts/stops retain their original feel while turns become less car-like. Air steering applies the existing 55% multiplier to this response.
- Gait stride intensity now scales against the 8 m/s sprint speed instead of reaching full intensity at the 3.8 m/s walk speed. Walking therefore uses a softer leg swing/knee bend; sprinting builds toward the full stride.
- Jump launch speed is now 6.9 m/s (from 6.5 m/s), increasing full-height jump airtime and height modestly without changing gravity, coyote time, buffering, or short-hop release behavior.
- Playtest: compare 90-degree turns and full reversals while walking/sprinting; check walking no longer looks like repeated bunny hops; compare tap and held jump heights.


## Procedural walk/sprint gait calibration

- Walking and sprinting use separate gait profiles instead of simply scaling one oversized stride. Walking uses a longer cycle distance (2.0 m), a 0.46 stance fraction, 24-degree thigh swing, 30-degree knee flex, and a 0.09 m normal swing arc. Sprint blends toward the existing 1.4 m cycle, 0.58 stance fraction, 46-degree thigh swing, 68-degree knee flex, and a 0.20 m swing arc.
- The 0.30 m emergency replant arc remains separate so a stretched foot can still recover safely. Normal walking no longer uses that exaggerated recovery height.
- M8 checks now cover distinct walk/sprint cadence, articulation, lift tuning, and ensure the longer walking cycle does not keep a foot planted beyond comfortable leg reach. Godot execution and in-game visual verification remain user-run.


### Walking rhythm regression — 2026-11-20

- Footstep landing prediction now uses the same blended walk/run cycle distance and stance fraction as the gait controller. Previously the controller could be in the longer walking cycle while the rig predicted landing travel with sprint timing, making the planted/swing phases disagree.
- M8 now checks that ordinary walking never places both legs in swing together and that the walk cycle includes a double-support interval where both feet remain planted.
- Sprint cadence and movement tuning are unchanged. Godot execution and in-game verification remain user-run.


### Walking cadence reach adjustment — 2026-11-20

- Increased the walking cycle distance to 2.0 m to slow the forward walking rhythm. Reduced the walking stance fraction to 0.46 so the longer cycle does not make the planted foot exceed comfortable leg reach and trigger emergency replants.
- Sprint timing remains unchanged. In-game confirmation is still pending from the user.

## M7.1 — Jab

- Releasing Q strictly before `CHARGED_PUNCH_HOLD_SECONDS` (1.0 s) starts a jab. Releasing at or after the threshold cannot create a jab.
- `net/combat_jabs` counts host-accepted jabs; `net/combat_hits` counts host-confirmed player hits; `net/combat_rejected` counts rejected requests.
- Enable the `combat` category to see host wind-up, accepted jab and confirmed hit logs.
- The host owns jab press timing, jab cooldown, camera direction, raycast, obstruction and target selection. Clients submit only press/release intent.
- The jab ray includes static world, elevator, props and player layers. World geometry and props block hits; the jab cannot hit through an obstruction.
- Standing targets receive a visual-only upper-torso spring recoil; no player-root movement is added. Already-limp targets receive a host-only physical-bone velocity impulse; their limp state and recovery timer are not restarted.
- The right Viewmodel hand uses a dedicated curled-fist pose and short extension/return. Carry and limp pose priorities override combat.
- M7.2 adds a procedural Chest-bone anticipation lean, forward punch follow-through, smooth neutral return, and a brief visual-only upper-torso spring recoil on standing targets. The body pose is applied before arm IK; the existing viewmodel wrist target continues to drive the visible arm on remote rigs.

| M7.1 | 1 | Tap Q: a short fist wind-up and jab extension play; `net/combat_jabs` increases once. |
| M7.1 | 2 | Aim at another standing player within 2.5 m and tap Q: `net/combat_hits` increases and the target receives a small recoil. |
| M7.1 | 3 | Aim through a wall or prop: the jab is blocked and does not hit through it. |
| M7.1 | 4 | Jab an already-limp player: the ragdoll physically reacts, but `player/<name>/limp_elapsed_s` continues without resetting. |
| M7.1 | 5 | Release Q before 1.0 s: a jab fires on release. Reaching 1.0 s while held auto-fires the charged punch. |
| M7.1 | 6 | While carrying, tap/hold Q: existing drop/throw behavior remains unchanged. |
| M7.2 | 1 | Tap Q: the curled fist visibly pulls back, then extends and returns to its authored hand position. |
| M7.2 | 2 | Watch from a second peer: the attacker’s torso leans into the jab and returns without per-bone animation traffic. |
| M7.2 | 3 | Get jabbed while standing: the target receives a brief upper-body spring recoil without player-root knockback. |
| M7.2 | 4 | Walk and sprint while jabbing: movement gait continues and the torso/arm pose does not fight the procedural IK. |
| M7.2 | 5 | Start carrying or enter limp/recovery: combat pose clears and the higher-priority carry/limp/recovery presentation wins. |
| M7.3 | 1 | Hold Q to 1.0 s without releasing: `net/combat_charged_punches` increases once and the lunge begins. |
| M7.3 | 2 | Release Q before 1.0 s: `net/combat_jabs` increases once; no charged lunge starts. |
| M7.3 | 3 | Aim through two standing players inside the capsule with a clear line: each distinct player inside the unobstructed volume goes limp, `net/combat_lunge_hits` counts both, and the lunge stops. |
| M7.3 | 4 | Miss: lunge ends after 0.5 s without affecting a target; normal movement resumes. |
| M7.3 | 5 | During a held charge and the 2.0 s charged recovery lock, use/grab requests are rejected; parry start is denied by `can_start_parry()`. |
| M7.3 | 6 | While carrying, Q tap/hold still uses the existing drop/throw path; while limp, combat remains blocked. |

Run only the jab regression stage from the `fowl-play/` directory with `.\tests\run_checks.ps1 -OnlyStage m7-jab`. Run the full suite with `.\tests\run_checks.ps1`.

The M7.2 pose-curve assertions are included in `m7_jab_test.gd`; run them with `.\tests\run_checks.ps1 -OnlyStage m7-jab` from `fowl-play/`.
