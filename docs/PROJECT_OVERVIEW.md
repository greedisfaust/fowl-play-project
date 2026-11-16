# Fowl Play — Project Overview (fresh start, v2)

This document defines intent, rules, numbers and decisions. The repository now contains implemented D0/M0 code: inspect it and read [PROJECT_STATE.md](PROJECT_STATE.md) and [the active session](sessions/_ACTIVE.md) before continuing. Where this document marks something **OPEN**, ask the user before building it.

**Language of this document**
- **must / must not** = hard rule, never break.
- **should** = default, deviate only with a stated reason.
- **may** = your choice.
- **DECIDED** = the user decided; do not change. **RECOMMENDED** = proposed, needs the user's approval (treat as the default until the user objects). **OPEN** = undecided, ask.

---

## 1. Vision

Fowl Play is a host-authoritative multiplayer party game (1–4 players, local network). In Fowl Play, one friend signs what he thinks is a free wings-for-life deal at a chicken-themed casino — but the contract's fine print binds anyone who eats the wings too, so sharing them with his three friends drags them all in without any of them signing a thing. Now bound to The House's endless "loyalty" contract, the four of them must gamble their way to enough winnings to void the cursed contract before The House claims them for good.

Fowl Play is a first-person party game for four players who share one bank account and one very bad contract. One of you signed what looked like a free wings-for-life deal at a chicken-themed casino called The House — except the fine print means anyone who eats the wings is bound to the contract too, so sharing them with your friends dragged all four of you in without the rest of you ever signing anything. Now you've got a handful of in-game days to gamble your way to enough winnings to void the contract before it claims you for good. The catch: every bet comes out of the same shared wallet, so when a friend starts pushing their luck too far, you can grab them, punch them into a stunned heap, or drag them bodily away from the table — at your own risk, since hitting a friend costs the entire team too. It's built for small groups who want a short, loud, chaotic multiplayer session full of betrayal, bad decisions, and yelling at your friends to stop gambling. Players are characters in shared rooms. They are able to fight with quick punches, charged lunges and parries. A player who takes a charged hit goes **limp**: the body becomes a physics ragdoll that tumbles, can be picked up and carried by another player, thrown, and after a few seconds gets back up.


**The feel (reference: Gamble With Your Friends, Half-Life 2 ragdolls):** physical and clumsy. Bodies have weight, limbs flail, carried players dangle from the carrier's grip, thrown bodies tumble freely (real rotation from the physics, never a scripted spin) until they hit something or settle. Reference only: copy nothing from those games.

**Non-negotiable:** the ragdoll must look and behave the same on the host and every client. A feature that only works on one machine is not done.

## 2. Scope of this repository

- **In scope (now):** the Player (movement, camera, body/skeleton, procedural legs, hands, ragdoll/limp, carry/throw, combat), interaction, props, devices, collision layers, networking for all of these, a small test arena, headless tests.
- **OPEN (later):** the casino/economy layer (tables, wallet, quota, day cycle, elevator rooms). It existed in an earlier prototype. Ask whether to rebuild it after the milestones below; do not build it now. Anything that depends on it (for example a wallet penalty on a charged hit) is out of scope until then.

**Non-goals (do not build unless asked):** Steam/online relay, rollback netcode, client-side prediction, skinned/deforming meshes, Blender-authored assets (editor-only rigging is preferred; Blender only after approval).

## 3. Tech stack and working environment

- **Godot 4.7 (Steam version)**, typed GDScript (explicit static types, no `:=` inference traps), **Jolt Physics**, Forward+ renderer.
- **Networking:** `ENetMultiplayerPeer`, UDP port 7777, host = peer 1, max 3 clients. Solo play uses `OfflineMultiplayerPeer`.
- **Performance target:** 4 players on weak school laptops. Budget: **≤ 70 awake rigid bodies** total (props + ragdoll bones), **≤ 15 shadow-casting lights**, hot paths allocate nothing per frame.
- **Machine:** Windows 11. Shells: Git Bash (use forward slashes) and PowerShell.
- **Paths:** the Godot project is the repository's `fowl-play/` directory (`res://`). Use repository-relative paths in documentation; the Godot executable is machine-specific and must be discovered locally.
- **Claude Code can run Godot itself** (headless tests, import, smoke runs). The user runs the real playtests and does the editor work.
- **Headless facts:** Godot output is buffered until the process exits; exit code 0 = pass; headless cannot simulate real input events (call component methods directly in tests); re-run the import step after adding scripts (`class_name` registration).

## 4. How we work (agreement)

- **Teaching Mode.** The user is learning Godot rigging, physics and networking. Editor work is given as numbered **EDITOR TASK cards** (exact menu paths, expected result, "if you see X instead", values with reasons, "done when"). Scripts are given as **SCRIPT HANDOFF cards**. Explain each concept the first time it appears. Hand over one card (or a short group) at a time and wait.
- **The user builds scenes in the editor.** Node hierarchies, meshes, skeletons, physical bones, collision shapes and layer settings are made in the editor by the user, following cards. **Claude Code must not generate meshes or node trees in script** (the first attempt did this and it had to be thrown away). Any exception (see §7, skeleton authoring) needs explicit approval first.
- **Scene ownership protocol.** Never edit a scene the user has open (Godot can overwrite or fork it). Announce handoffs ("I'm editing X, stay out" / "all yours"). Never invent `uid://` values. Small mechanical `.tscn` text edits are allowed only on scenes the user has closed, and only after saying so.
- **Ask whenever something is unclear.** Use short **Question Cards** (options, a recommendation, what it blocks).
- **Debug Console:** every slice must satisfy the Debug Console rule in `CLAUDE.md` (logs, watches and commands for everything it adds) before it counts as done.
- **Git:** work on a feature branch. The user performs commits and pushes, as specified in [CLAUDE.md](../CLAUDE.md). Review the diff, report validation, and suggest a commit message. Do not commit/push, reset, discard changes, clean, or delete `.godot` without explicit authorization. Do not attribute work to an assistant that did not perform it.
- **Decision gates:** stop and ask before: the movement authority approach and first networking slice (M3), the ragdoll sync approach (after the spike, M4), skeleton authoring method (M4), any Blender use, bird vs humanoid legs (**before M4**, because it shapes the skeleton), the camera approach (M9). After a gate, proceed slice by slice without asking for each change.
- **Docs stay in sync with code** every slice. Single tuning source (see §15).
- **No silent work:** say what you changed and why.

## 5. Glossary

| Term | Meaning |
|---|---|
| **Limp** | The state where a player cannot act and their body is a ragdoll. One concept (knockdown = ragdoll = limp), regardless of cause. |
| **Recoil** | A short visual flinch/jiggle from a jab. Not limp, not incapacitating, never combined with limp (limp wins). |
| **Ragdoll** | The physics simulation of the skeleton's physical bones. |
| **Capsule** | The player's standing collider (`CharacterBody3D`). Dormant while limp. |
| **Recovery / get-up** | Ending limp: ragdoll stops, capsule is re-placed at the hips' ground position, pose blends to standing. |
| **Handback** | The moment control of position passes from the ragdoll back to the capsule. |
| **Host / Client** | Peer 1 / any other peer. The host is authoritative for everything except the owner's own movement (see §6). |
| **Intent** | A request a client sends ("I pressed grab"). The host validates and applies it. |
| **Settled** | A body whose speed is below the settle threshold. |
| **Forced termination** | A hold, charge or limp ended by an event (disconnect, teleport/room change, run reset, host leaves), not by the player. |

## 6. Who owns what (authority at a glance)

| Thing | Truth lives on | Everyone else |
|---|---|---|
| Player movement and look | **The owner** (DECIDED at M3; the host sanity-checks speed and rejects teleports it did not order) | Interpolate (`MOVE_INTERP_DELAY_S`) |
| Hit judgment (punch, parry, lunge hit) | Host (uses its latest copy of positions, with `MAX_PUNCH_POS_ERROR_M` tolerance) | Receive replicated results and cosmetic events |
| Limp / ragdoll simulation | Host | Render interpolated bone poses; run no bone physics |
| Carry, throw, pickup | Host (clients send intent) | Mirror state |
| Props and other bodies | Host | Interpolate snapshots |
| All timers (limp, parry, charge auto-fire, cooldowns) | Host | Report press/release only |
| Hands cosmetics | Local on the owner; replicated cosmetic events for others | |
| Procedural legs | Local, derived on every peer (no traffic) | |

**Movement authority (DECIDED at the M3 gate):** on a LAN, owner-authoritative movement feels instant and needs no prediction. The host still decides everything that matters (combat, ragdoll, carry, throw). While limp, the owner's movement authority is **suspended**: the host-simulated hips body is the single truth. During a lunge the owner drives the movement and the host judges the hit from its own copy.

## 7. Player body and skeleton

**Skeleton (RECOMMENDED humanoid; change only with a reason, and see the legs gate in §4):**

```
Hips (root)
├─ Spine ─ Chest ─ Neck ─ Head        (a beak/bird-head is an optional rigid attachment on Head)
│            ├─ UpperArm_L ─ Forearm_L ─ Hand_L
│            └─ UpperArm_R ─ Forearm_R ─ Hand_R
├─ Thigh_L ─ Shin_L ─ Foot_L          (knee = the joint between Thigh and Shin)
└─ Thigh_R ─ Shin_R ─ Foot_R          (ankle = the joint between Shin and Foot)
```

- **Physical bones (11):** Hips, Chest, Head, UpperArm_L/R, Forearm_L/R, Thigh_L/R, Shin_L/R. Spine, Neck, Hands and Feet are not separate physical bodies: hands follow the forearms and feet follow the shins rigidly while ragdolling. Verify in the spike whether one torso body (Chest) looks good enough or a second physical spine bone is needed (12–13 bones). Tip: in the editor, Skeleton3D > Create Physical Skeleton generates a physical bone for every bone; delete the ones not wanted.
- **Joints (starting values, tuned and verified under Jolt in the spike):**

| Joint | Between | Type | Starting limits |
|---|---|---|---|
| Knee | Thigh → Shin | Hinge | 0° to ~140° flexion, no hyperextension |
| Elbow | UpperArm → Forearm | Hinge | 0° to ~145° flexion, no hyperextension |
| Hip | Hips → Thigh | Cone (swing/twist) | ~80° swing, ~30° twist |
| Shoulder | Chest → UpperArm | Cone | ~100° swing, ~40° twist |
| Neck | Chest → Head | Cone | ~45° swing, ~40° twist |
| Waist | Hips → Chest | Cone | ~25° swing, ~20° twist |

- **Meshes:** rigid primitive meshes on `BoneAttachment3D` nodes (no skin weights, no Blender). Blocky low-poly look. The head has a **beak and eyes** as a rigid attachment (DECIDED, cosmetic only; does not change the skeleton).
- **Skeleton authoring (OPEN, decide at the M4 gate):** (A) build the bones in the editor through the Skeleton3D inspector (RECOMMENDED to try first on a minimal skeleton); (B) if A is too painful, a **one-time `@tool` script** run in the editor that creates the bones, whose result is saved as a scene and the script then deleted (needs explicit approval); (C) Blender (non-goal unless approved).
- **Self-collision (RECOMMENDED, verify in the spike):** bones of the **same** ragdoll never collide with each other (collision exceptions or Jolt collision groups); bones of **different** ragdolls do.
- **Mass (OPEN):** per-bone masses are decided in the Jolt spike.
- **Node paths (stable contract):** the player scene root is named by peer id (`Players/<id>`) and exposes `Head`, `Head/Camera3D`, `Rig/Skeleton3D`, `NamePlate`, plus script properties `hands`, `head`, `state`, `combat`, `carrier`. **A Player node is never reparented** (it breaks every RPC path).
- **Owner view:** the owner's body mesh may be hidden in first person. **DECIDED:** the owner's legs are hidden when looking down (pitch below horizontal); when looking forward again they fade from hidden to visible via a smooth opacity slide (no instant snap). Default: hidden when looking down (also saves their leg compute).

## 8. Movement and camera

- WASD move, mouse look (pitch clamped ±85°), jump. Starting values are in §15.
- Camera is on `Head`. The raycast for interaction is a child of the camera.
- Escape releases the mouse (no pause); a click recaptures it.
- While limp, the **owner's camera** follows the **smoothed hips** (owner's capsule position), smoothed, with mouse look added on top. A carried player **can still look around**. **RECOMMENDED:** limit camera roll, push the camera out of walls (short ray, mask in §13), no snapping when the head clips geometry. **DECIDED:** follow smoothed hips (owner's capsule position) rather than the head bone.

## 9. Combat

Inputs are InputMap actions only (never raw keycodes). The full action table is in §19.

| Action | Input | Behavior |
|---|---|---|
| Quick punch (jab) | tap `punch` (Q): released within `TAP_MAX_SECONDS` (0.25 s) | Fires on release. Range ~2.5 m, hitbox lives ~0.1 s, spam guard 0.35 s. **No limp.** The target recoils (visual only). |
| Charged punch | hold `punch` while holding nothing | **Wind-up animation plays to indicate the charge** (DECIDED). Auto-fires the moment the hold reaches 1.0 s, even while still held. **One fire per press:** `punch` must be released to re-arm, and `CHARGED_PUNCH_COOLDOWN_SECONDS` (2.0) must pass; the host enforces both. **No early-release fizzle:** releasing before 1.0 s simply cancels with no punch and no penalty (DECIDED). No charge meter UI: feedback is the wind-up pose and a rising sound. |
| Lunge | on auto-fire | 12 m/s for 0.5 s, direction steered toward the camera look at ≤ 3 rad/s. The hitbox is parented to the puncher and moves with them. |
| Lunge hit | hitbox overlaps a player | Target goes **limp**; the lunge stops immediately on the host and the puncher's client; hits all players inside the hitbox. |
| Lunge miss | 0.5 s passes | Nothing happens. Input resumes. |
| Parry | press `parry` (F) once | Guard (barrier) up for 1.5 s, then 1.5 s cooldown. Press-once, no hold-to-keep. A punch hitting the barrier is cancelled. **Attacker:** a parried **charged** punch makes the attacker go **limp** (`PARRY_LIMP_SECONDS`); a parried **jab** is **recoil only**. |

- **Blocked states:** cannot punch/parry while limp, carrying something, or (for punch) parrying; cannot parry while on cooldown. **During the charged-punch state (wind-up, lunge, recovery) use, grab and parry are blocked** (this avoids state bugs); becoming limp ends it at once.
- **OPEN:** movement during wind-up (full speed / slowed ~50% RECOMMENDED / rooted). **DECIDED:** full speed during charge; no slowdown.
- **Jab recoil (RECOMMENDED):** a short additive spring on Spine/Chest, visual only, triggered on all machines from the replicated hit event. It is **not** a ragdoll and not limp.
- A knockdown while lunging cancels the lunge with no hit.
- **The host judges every hit. Clients send intent only.** Requests must come from the node's owner (sender check).
- **OPEN:** whether punches affect already-limp bodies (RECOMMENDED: ignore them; dedupe hits by player root).

## 10. Limp / ragdoll lifecycle

**Rules**
- Limp begins on the host (charged hit, parried charged punch) and is replicated reliably to everyone through **one entry point**.
- **Recovery rule (RECOMMENDED):** the limp timer (`LIMP_SECONDS`, **3.5 s**, DECIDED) must have elapsed **and** the body must be settled (speed below `LIMP_SETTLED_SPEED_MPS`); a hard cap (`LIMP_MAX_SECONDS`, 6.0 s of free tumbling) forces recovery. The timer **pauses while carried** and **restarts on drop/throw**. **The host owns the one timer**; no machine runs its own.
- Input and interaction are locked while limp. A limp player can still look around.
- Exactly one cleanup path ends a ragdoll (see §14, G8).

**State table (RECOMMENDED)**

| State | Bones | Authoritative position | Camera (owner) | Exits |
|---|---|---|---|---|
| STANDING | animated (procedural legs) | capsule (owner) | first person | knockdown → GROUND |
| GROUND | simulated | hips body, host-simulated | head bone, smoothed | pickup → CARRIED, timer+settled → RECOVERY |
| CARRIED | hips pinned to carry anchor, limbs **dangle** (simulated) | carry anchor | head bone, mouse look still works | drop → GROUND, throw → THROWN, carrier forced-ends → GROUND |
| THROWN | simulated with launch impulse | hips body, host-simulated | head bone | settles → GROUND |
| RECOVERY | blend ragdoll → standing pose over ~0.5 s | capsule re-placed at hips ground position | blends back to first person | → STANDING |

- **OPEN:** dangling limbs (above) feel more like the references; confirm.
- **Forced exits** (disconnect, teleport/room change, run reset, host leaves) always route to the single cleanup path, then STANDING.
- **Authority of position while limp (RECOMMENDED):** the host-simulated hips body is the single truth. The capsule is dormant and is re-placed at handback. Clients drive the root from the interpolated hips pose. **The body drives the root, never the reverse** (see §22).

## 11. Carry and throw

- A limp player or a pickup-able prop is picked up with `interact` (E). Single slot per holder. The host validates: reach (≈ 3.2 m), line of sight, not already held, holder not limp.
- **While holding something: left click, E and F are blocked; punching is blocked.**
- **Q while holding (DECIDED):**
  - **Tap** (released within 0.25 s): **drop**.
  - **Hold past the tap window:** a throw charge builds. The throw **auto-fires the moment the hold reaches `THROW_AUTO_FIRE_SECONDS` (1.0 s)**, no release needed.
  - **Releasing before auto-fire drops the item** instead. There is no way to cancel without dropping.
  - **Consequence to be aware of:** a throw is always full power (`THROW_SPEED_MPS`; limp bodies use `THROW_SPEED_LIMP_MPS`). Direction comes from the camera, so look pitch gives the arc. If the user later wants variable power, that is a new decision.
  - The host times the charge and clamps speed; clients only send aim direction and intent.
- A throw (or charge) interrupted by a forced event ends as a **drop**, never a throw.
- Carried things collide with nothing; a short ray stops them at walls so they don't clip. Carried bodies never push or block the carrier.
- Props: physics bodies with a weight class (light / medium / heavy / immovable), pickup allowed or push-only, defined by a shared **profile resource** (§18). Non-pickup-able props are shoved by walking or punching them.

## 12. Interaction

Focus-based: a ray from the camera finds the target, the target highlights, the mapped action fires.
- **One contract** for everything actable (a component, e.g. `Interactable`, with kind USE / GRAB / BOTH, prompt text, `can_interact`, `interact`). No type-check chains.
- Left click (`primary`) presses USE devices only. `interact` (E) grabs GRAB targets and also uses devices (resolved by what is aimed at).
- Healthy players never highlight; limp players are GRAB targets.
- Static devices use the Interactable component only; only simulated things (props, limp bodies) have a physical body.
- The focus ray's mask is built from the layer table (§13), never hard-coded numbers.

## 13. Collision layers and masks (DECIDED structure, improvements welcome)

**Rule:** layers and masks are defined in **one file** (a constants script) and nothing else sets them. If a change is better, **recommend it and wait for approval.**

| # | Layer | Lives on | Collides with (mask) |
|---|---|---|---|
| 1 | WORLD_STATIC | walls, floors, roofs | 3, 5, 6 |
| 2 | DEVICES | buttons, terminals, plaques | 5, 6 |
| 3 | PROPS | loose props | 1, 3, 5, 6 |
| 4 | CARRIED | held props/bodies | nothing |
| 5 | HEALTHY_PLAYERS | standing capsules | 1, 2, 3, 6, 7 |
| 6 | LIMP_BODIES | **ragdoll physical bones** | 1, 3, 5, and **other** ragdolls' bones (not its own, see §7) |
| 7 | ELEVATOR | door panels | 5, 6 |
| 8 | PUNCH_HITBOX | punch areas | 5, 3, 9 (limp bodies: see §9, OPEN) |
| 9 | PARRY_BARRIER | parry areas | 8 |

**Ragdoll vs players (RECOMMENDED):**
- Ragdoll bones **do** collide with world, props, other ragdolls, and healthy-player capsules, so a tumbling body bounces off standing players.
- Standing players are `CharacterBody3D`s that only move via their own movement code, so they are **not shoved** by ragdolls. Ragdolls bounce; capsules hold their ground.
- Punch hitboxes must treat **all bones of one player as one target** (dedupe by player root).
- The limp player is grabbed as one target (the hips/root), never per bone.
- Two limp players colliding behave identically on host and clients by construction (host-simulated).

**Ray masks:** **FOCUS** = devices + props + limp bodies. **LOS** (pickup reach) = world + devices + props + players + limp bodies + elevator. **CAMERA** (push out of walls) = world only.

## 14. Networking

**Model:** host-authoritative ENet. Host = peer 1. The host owns all simulation (except the owner's own movement), all timers and all authoritative state. Clients send intent only.

**Rules (must):**
1. Every `any_peer` RPC validates `get_remote_sender_id()` and the relevant state before acting. Use one shared helper, not repeated inline checks. Host-only messages check the sender is the host; owner requests check the sender owns the node.
2. Never RPC to yourself: if the target peer is the local peer, call the method directly.
3. The host owns every timer (limp, parry, charge auto-fire, cooldowns). Clients report press/release only.
4. Late or stale messages must not resurrect finished state (guard every handler; make state changes idempotent).
5. Replicated visuals use **stored references**, never `get_node_or_null` path guesses on remote peers.
6. **One file knows about ENet** (the network autoload). Everything else uses `multiplayer`, so a different peer type can be dropped in later.
7. A player node's path never changes after spawn (no reparenting).

**Recommended pattern:** client sends an intent RPC → host validates and mutates state → state replicates → each machine emits its own signals from **property setters** when the value really changes. Use `MultiplayerSynchronizer` for slow discrete state (roster, limp state/phase, carry holder, game values); it also handles late join. Use custom changed-only unreliable snapshots for physics. (Verify `MultiplayerSynchronizer` behavior in the 4.7 docs with a tiny test before relying on it.)

**Ragdoll sync (DECIDED by the user): quantized bone poses.** The host simulates the ragdoll and sends each physical bone's position + rotation (quantized, with a timestamp) at `RAGDOLL_SEND_HZ` (`unreliable_ordered`) to all clients. Clients run no bone physics for remote ragdolls. Clients never fabricate launches. Limp begin/end/phase changes are reliable RPCs, plus one reliable "settled" pose when a body comes to rest.

**Smoothness requirement (must):** the ragdoll must look smooth on the host and on every client.
- The send rate is **not** the display rate. Clients render every frame and **interpolate by timestamp** between buffered snapshots, drawing the remote ragdoll slightly in the past (`RAGDOLL_INTERP_DELAY_S`, about two send intervals).
- **Default `RAGDOLL_SEND_HZ = 30`** (starting value; the spike picks the final number from 15 / 30 / 60 by measurement and by how it looks). Rough cost: 11 bones × ~10 B × 30 Hz × 3 clients ≈ 10 KB/s per limp player (estimate, measure it). Nothing is sent when no one is ragdolling or when the body is asleep.
- On a lost or late packet: briefly extrapolate from the last velocity, then ease back to the next snapshot. A late packet must never move the pose backwards (ordered delivery + timestamp check).
- The host sees the true simulation with no delay. Carried bodies stay responsive for the carrier (the carry anchor is followed locally, not waited on).
- Acceptance: no visible stutter or popping at 30 fps and 60 fps client frame rates, on a LAN, during tumble, throw and carry.
- **Verification required (spike before building out):** measure bytes/second at 15, 30 and 60 Hz, host CPU with several ragdolls, interpolation quality (smoothness as seen on the client), and late join. If the spike shows a problem, propose the alternative (a local cosmetic ragdoll anchored to a host-simulated hips body, plus a reliable settle pose) and ask.

**Bone budget policy (DECIDED limits, to be proven in the spike):** one full ragdoll is **11 physical bodies**. `MAX_FULL_RAGDOLLS = 4` (44 bodies) within `MAX_AWAKE_BODIES = 70` (leaving about 26 for props). Bodies that are asleep do not count. If the spike on a weak laptop shows this is too heavy, propose a lower number, and a cheaper fallback for extra knockdowns (capsule body + canned flop pose). The host decides and replicates which mode each ragdoll uses.

**Late join (DECIDED):** joining mid-play is allowed only during rest of day (not during casino/elevator). If late join is allowed, G6 (full state on join) is a must.

**Sync Guarantees (acceptance criteria, must hold):**
- **G1** All peers start a ragdoll from the same start transform and launch, within one round trip.
- **G2** The ragdoll's hips on every peer stay within **0.25 m** of the host's hips at all times (snap if exceeded).
- **G3** Recovery is triggered only by the host; every peer plays get-up; the final position matches the host's.
- **G4** Carried ragdolls are attached to the carrier on every peer; carry/drop/throw phase changes replicate reliably.
- **G5** Throws land in the same region on all peers.
- **G6** A client joining mid-limp receives the full state (limp active, phase, remaining time, pose, carrier id) and shows a correct ragdoll immediately (applies when late join is allowed).
- **G7** No client authority over any of it (except the owner's own movement while standing); no self-RPC; every `any_peer` RPC validated.
- **G8** One cleanup function ends a ragdoll and is called from **every** exit: recovery, any disconnect (holder, held, ragdolling player), teleport/room change, run reset, host leaving, return to solo. It never leaves a simulator running or a body in limp on any peer.

## 15. Single tuning source (starting values; one resource/file is the truth)

| Name | Start value | Notes |
|---|---|---|
| `PLAYER_SPEED_MPS` / `JUMP_SPEED_MPS` / `GRAVITY_MPS2` | 5.0 / 6.5 / 20.0 | |
| `MOUSE_SENSITIVITY` | 0.003 | |
| `MOVE_INTERP_DELAY_S` | ~0.1 | remote player smoothing |
| `MOVE_SANITY_MAX_SPEED_MPS` | 15 | host plausibility check (above lunge speed) |
| `MAX_PUNCH_POS_ERROR_M` | 6.0 | host ignores a reported punch position farther than this from its own copy |
| `TAP_MAX_SECONDS` | 0.25 | tap vs hold (jab, drop) |
| `CHARGED_PUNCH_HOLD_SECONDS` | 1.0 | auto-fire |
| `CHARGED_PUNCH_COOLDOWN_SECONDS` | 2.0 | before another can start |
| `JAB_COOLDOWN_SECONDS` | 0.35 | spam guard |
| `QUICK_PUNCH_RANGE_M` / duration | 2.5 / 0.10 s | |
| `CHARGED_PUNCH_RANGE_M` | 3.5 | |
| `LUNGE_SPEED_MPS` / duration | 12 / 0.5 s | steer ≤ 3 rad/s |
| `PARRY_GRACE_SECONDS` / `PARRY_COOLDOWN_SECONDS` | 1.5 / 1.5 | |
| `PARRY_LIMP_SECONDS` | 3.5 | attacker of a parried charged punch (tune) |
| `LIMP_SECONDS` / `LIMP_MAX_SECONDS` | **3.5** / 6.0 | one value only |
| `LIMP_SETTLED_SPEED_MPS` | 1.0 | |
| `THROW_AUTO_FIRE_SECONDS` | 1.0 | hold time at which a throw fires |
| `THROW_SPEED_MPS` / `THROW_SPEED_LIMP_MPS` | 14 / 10 | fixed power (tune in playtest) |
| `REACH_M` | 3.2 | pickup reach |
| `INTERACT_REQUEST_INTERVAL_S` | 0.15 | M3 per-player host interaction request interval; tune in playtest |
| `RAGDOLL_SEND_HZ` | 30 | bone-pose snapshots; spike picks final (15 / 30 / 60) |
| `RAGDOLL_INTERP_DELAY_S` | ~0.07 | about two send intervals |
| `BODY_SNAPSHOT_HZ` | 15 | props and other bodies (not ragdoll bones) |
| `BODY_MAX_SPEED_MPS` | 20 | speed clamp |
| `BODY_KILL_PLANE_Y_M` | −10 | return to last safe spot |
| `HIPS_SYNC_TOLERANCE_M` | 0.25 | G2 |
| `MAX_FULL_RAGDOLLS` / `MAX_AWAKE_BODIES` | 4 / 70 | the spike must prove it |
| Ragdoll bone masses | **OPEN** | decide in the Jolt spike |

No constant may be defined twice. If docs and code disagree, the tuning file wins and the docs are fixed.

## 16. Hands

A scene-backed component with real nodes (palm, forearm, 4 fingers × 3 joints, thumb, per-hand rig), **built in the editor, not in code**. Build one reusable `finger.tscn` (three joints) and instance it four times per hand. (An earlier hand was built in code; this is a rebuild.)

- **Two modes (set before adding to the tree):** first-person viewmodel on the camera (local player), world model on the head (what others see).
- **Public API (RECOMMENDED; confirm against the earlier hands before building):**
  - `world_mode: bool` (set before `add_child`)
  - `set_color(c: Color)`
  - `set_hover(on: bool, world_point: Vector3)` and `update_hover_point(world_point: Vector3)`
  - `reach(world_point: Vector3)` (poke, spam-aware)
  - `set_guard(active: bool)` (boxer guard for parry, smooth tween)
  - `shake(intensity: float)` (impact)
  - `add_sway(rel: Vector2)`, `set_speed(s: float)` (sway and walk bob)
  - **New:** `set_carrying(on: bool, item: Node3D)` (holding pose) and a limp hook (`set_limp(on: bool)`).
- **Behaviors:** hover pointing at targets, reach/poke, boxer guard, shake, bob and sway, whole hand tinted with the player's color.
- **Replicated cosmetics** (`reach`, hover, guard) use stored hand references and are triggered from host events; never trusted from clients without validation.
- **Lessons from the earlier hands (do not relearn):**
  1. Draw first-person hands as a **scaled-down node near the camera** (≈ 0.3) with **normal depth testing**. Disabling depth testing to avoid wall clipping scrambled the draw order of overlapping parts (ringed fingers, jumbled shading). Convert world points to the hand's own units when aiming.
  2. **Hover on/off must be reliable**; only the pointing-target updates may be unreliable. A timeout on unreliable heartbeats made the hand drop out.
  3. **Aim the index finger at the target**, not the palm. The pointing hand reaches out along the line to the target and pulls toward the body's center.
  4. Proportions: a trapezoid palm (wide at the knuckles), three-segment fingers (about 0.47 : 0.29 : 0.24 of finger length), a thumb rooted low on the palm angled outward, the middle finger longest. Chunky cartoon fingers, not skinny.

## 17. Procedural legs (summary; the full legs plan is a separate document, to be attached)

- Cosmetic, local, **zero network traffic**: derived from the replicated position/velocity on every peer (remote players: smoothed position delta).
- Phase clock plus world-locked planted feet, step trigger when the body outruns a foot, landing prediction, speed-scaled swing arc, ground raycast once per step, turn-in-place and settle steps, air/landing handling, instant re-plant on teleport.
- Paused while limp; on recovery blend ragdoll pose → planted feet under the final transform.
- Budget: ≤ 0.2 ms per visible player, ≤ 4 ray queries per step, LOD for remote players.
- **Gate:** bird (digitigrade) vs humanoid legs is decided **before the M4 ragdoll spike**, because it changes the skeleton and the knee/ankle joints.

## 18. Props and devices (extensibility contract)

Adding a prop "just for fun" must be: inherit the base prop scene, assign a mesh, pick a profile. Everything else is automatic.
- **Base prop scene** (built in the editor): `RigidBody3D` + `CollisionShape3D` + `Visual` + `Interactable` component + a carry-anchor marker.
- **`PropProfile` resource (`.tres`):** weight class (light / medium / heavy / immovable), pickup allowed, throwable, friction/bounce preset, size class, optional impact sound. Profiles map to the shared tuning; no per-prop magic numbers.
- **Collision:** generated from the mesh by an editor helper, with a manual override.
- **Special behaviors** (breakable, consumable, bouncy) are optional components attached to the prop scene, never forks of the base.
- **Runtime-spawned props** go through one spawn function registered with the `MultiplayerSpawner` (deterministic names, host authority). Hand-placed props are scene instances with fixed names (identical on every peer by construction).
- A bare `RigidBody3D` outside the base scene is **not** networked or carryable; the docs say so.
- **Prop lint test:** scans every prop scene, fails if a required component or profile is missing, and runs spawn → grab → throw → cleanup on each.
- **Devices** (buttons, terminals, plaques) use the Interactable component only; they are not rigid bodies.

## 19. Input, UI and feedback

**Actions (InputMap names; never raw keycodes):**

| Action | Default | Notes |
|---|---|---|
| `move_forward` / `move_left` / `move_back` / `move_right` | W / A / S / D | |
| `jump` | Space | |
| `interact` | E | grab or use, resolved by the aimed target |
| `primary` | Left mouse | presses USE devices only |
| `punch` | Q | tap = jab or drop; hold = charge (punch or throw by state) |
| `parry` | F | |
| `ui_cancel` | Escape | release the mouse (no pause) |

Right mouse is unused. There is no separate drop key.

**What each press does, by state (one resolution table in one place):**

| Input | Idle, nothing held | Holding an item or limp player | Charged-punch state | Limp |
|---|---|---|---|---|
| `primary` | press device | blocked | blocked | blocked |
| `interact` | press device, or grab | blocked | blocked | blocked |
| `punch` tap | jab | drop | n/a | blocked |
| `punch` hold | charged punch (auto-fires at 1.0 s) | throw charge (auto-fires at 1.0 s; early release drops) | n/a | blocked |
| `parry` | parry | blocked | blocked | blocked |

**Feedback and UI (RECOMMENDED, minimal at first):**
- Crosshair: a white ring that glows in the player's color on a valid target. Prompt text for the aimed target.
- Throw charge meter (kept). **No** punch charge meter; use wind-up pose and sound.
- Short notices for key events; impact feedback (camera and hand shake) scaled by impact speed, **OPEN** whether to include.
- Nameplates above remote players (name tinted with their color).

**Lobby and connection (RECOMMENDED):** at first a debug connect through command-line arguments (`--host`, `--join=<ip>`) so the test arena can be played by two instances. Nickname and color selection through a simple editor-built UI later. **OPEN:** the final lobby flow.

## 20. Project structure and conventions (RECOMMENDED)

```
res://
  core/          autoloads: network (the only ENet user), tuning (all constants), layers (all layer/mask constants)
  player/        player scene + thin player script; components: movement, combat, carrier, focus, state
  ragdoll/       skeleton, physical bones, sync
  hands/         hand + finger scenes
  interaction/   Interactable component, focus/highlight
  props/         base prop scene, profiles/
  devices/       buttons, terminals, plaques
  arena/         the small test arena
  ui/
  tests/         headless tests, ENet host+client pairs, rendered capture scripts, run_checks.ps1
  docs/
```
- Every script starts with a `##` header saying what it is and what it owns. One responsibility per script. The player script stays a thin coordinator.
- Static typing everywhere; no dead or commented-out code; no magic numbers (constants live in the tuning file).
- Signals go up, calls go down. Autoload scripts have no `class_name`. Use `preload` where consumers are parsed first.
- No abstraction without at least two real consumers today.

## 21. Testing and verification

- **Layers of tests:** (1) headless tests in the test arena with `OfflineMultiplayerPeer` (host only); (2) **ENet loopback pairs** (host process + client process on distinct UDP ports per test); (3) a manual **2-instance playtest checklist** per slice (host and join `127.0.0.1`); (4) rendered capture scripts for visuals (not headless).
- **Create `tests/run_checks.ps1` in M0:** import, then every test, failing on non-zero exit codes **and** on `ERROR:` / `SCRIPT ERROR:` in the output.
- Every sync guarantee (G1–G8) and every combat/carry rule has a test or a recorded playtest step. Test the cleanup matrix: every forced event against every holdable thing.
- Port, never delete, a check when code changes. Keep a dated result log with real measurements; do not tick boxes that were not run.
- Each slice ends with: tests passing, a playtest checklist for the user, docs updated, a commit, and `COMMIT READY: please push`.

## 22. Mistakes from the first attempts (do not repeat)

1. **Meshes generated in script** instead of built in the editor. Build node trees in the editor.
2. **Everything in flight at once** (hands, legs, ragdoll, networking). Do one slice, test, commit, then the next.
3. **Docs drifted from code** (two different limp durations, constants declared twice). One tuning source; update docs every slice.
4. **Self-RPC** errors and `any_peer` RPCs missing sender checks (teleport, parry visuals, knockdown).
5. **Stale host replies** re-activating an already-expired parry. Guard every network handler.
6. **Path-based lookups on remote peers** for replicated visuals failed silently. Keep references.
7. **`class_name` registration order**: scripts parsed before their dependencies fail with "could not find type". Use `preload` where consumers are parsed first, and re-run the import step after adding scripts.
8. **`@export` is not allowed on `RefCounted`** types.
9. **Duplicate construction** (a component created twice, the first discarded) and **lookups that don't match the real node tree** (a "Hands" node searched on a parent that never contained it). Verify node paths against the actual scene.
10. Silent git operations and silent behavior changes. Say what changed.
11. **A physics body that is a child of the node that follows it** (the body ragdolled while the player root was moved to the body each frame) created a feedback loop and flew away. The body drives the root, never the reverse, and a body that must not inherit a parent's transform is `top_level`.
12. **A healthy player's physics body left simulating** (unfrozen, overlapping the player's capsule) caused depenetration flings. Dormant means frozen with collision off.
13. **Three independent recovery timers** (host body, victim body, victim state) disagreed. The host owns the only one.
14. **The knockdown was sent only to the victim**, so the host and other clients never entered limp. Limp begins on the host and is mirrored to every machine.
15. **Reparenting a Player node while carried** broke `Players/<id>` and every RPC path.
16. **Disabling depth testing on first-person hands** scrambled their shading.

## 23. Milestones (each ends with tests, a 2-instance host/client playtest checklist, docs, and a user commit)

1. **M0 Foundation:** project settings, layer constants, tuning resource, input map, networking autoload (`--host` / `--join`), test runner, test arena, player capsule movement + camera, spawn/despawn over ENet.
2. **M1 Interaction and one prop:** the Interactable component, focus/highlight, one USE device and one GRAB-able prop (local, host-validated), the base prop scene and profile.
3. **M2 Hands (scene-backed, local):** hand and finger scenes, the API in §16, first-person and world modes.
4. **M3 Networking slice 1 — GATE:** confirm the movement-authority approach; roster, connect, remote smoothing, the intent-RPC pattern and the shared validation helper; replicated hand cosmetics.
5. **M4 Ragdoll spike — GATE:** (legs decision first.) Skeleton, 11 physical bones, joints under Jolt, self-collision policy, bandwidth and CPU measurements at 15/30/60 Hz; validate the decided quantized bone-pose sync approach and only propose an alternative if measurements fail.
6. **M5 Limp lifecycle:** knockdown → ground → recovery on host and clients (G1–G3, G8; G6 if late join is allowed).
7. **M6 Carry and throw:** props and limp bodies, auto-fire throw, dangling limbs, carried player can look around (G4, G5).
8. **M7 Combat:** jab and recoil, charged punch with auto-fire/cooldown/re-arm, lunge, parry with the attacker outcomes in §9.
9. **M8 Procedural legs.**
10. **M9 Camera and owner view — GATE:** camera follow approach, owner legs visibility.
11. **M10 Hardening:** the full cleanup matrix, the bone budget on a weak laptop, a four-player soak test.
12. **Later (OPEN):** the casino/economy layer.

## 24. Decisions log and open questions

**Decided (2026-11-15):**
- Throw: auto-fires at full charge (1.0 s); early release after the tap window drops the item; tap drops; throw power is fixed.
- Limp lasts `LIMP_SECONDS` = 3.5 s (hard cap 6.0 s).
- Budget: up to 4 full ragdolls, up to 70 awake bodies, to be proven by the spike.
- A parried charged punch makes the attacker limp; a parried jab is recoil only.
- Movement authority: owner-authoritative standing movement with host sanity checks was approved at the M3 gate (2026-11-16). Host validates and relays owner snapshots; remote peers interpolate. Gameplay outcomes remain host-authoritative.
- Owner's legs are hidden when looking down (pitch below horizontal); when looking forward again they fade from hidden to visible via a smooth opacity slide (no instant snap).
- Camera follow target while limp: **smoothed hips** (owner's capsule position) is the follow target.
- Wind-up movement: **full speed** (no slowdown) during charge; **no early-release fizzle** (releasing before 1.0 s cancels with no punch and no penalty).
- Beak and eyes are a rigid attachment on the head (cosmetic only; does not change the skeleton).
- A player node is never reparented (it breaks every RPC path).

**Open (ask before building):**
1. Skeleton authoring: inspector vs a one-time tool script.
2. Dangling limbs while carried (confirm).
3. Whether punches affect already-limp bodies.
4. Whether to include impact/wall-slam feedback.
5. Final lobby, nickname and color flow.
6. Per-bone ragdoll masses (spike).
7. Rebuilding the casino/economy layer, and when.
