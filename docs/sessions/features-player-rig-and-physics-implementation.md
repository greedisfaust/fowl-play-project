# Session memory: features/player-rig-and-physics-implementation

Branch: features/player-rig-and-physics-implementation
Goal: Build and measure a Godot-native player ragdoll and recover to standing (M4–M5).
Status: IN PROGRESS - M4 automated gate passed; M5 recovery is partial
Base docs: [overview](../PROJECT_OVERVIEW.md), [project state](../PROJECT_STATE.md)

## Current state

- VERIFIED: M4 host/client pose replication, late join, head camera, settled pose, and 15/30/60 Hz checks pass. The user approved the head camera and ±75° look limit. Visual smoothness at 40 ms and weak-laptop cost remain unverified.
- VERIFIED HEADLESS: M5 host-owned 3.5 s settled / 6 s hard-cap recovery, floor placement under final hips, cleanup, and reliable host/client end pass focused tests.
- USER VERIFIED: automatic recovery and final placement look correct in game.
- VERIFIED HEADLESS: 10 selective non-neighboring forearm/thigh/shin-to-torso contact pairs replace the all-exempt baseline; focused exception-map, M4 paired, and four-ragdoll 7-second profile checks pass. Visual clipping and jitter still need a playtest.
- VERIFIED HEADLESS: a 0.5 s host/client pose blend and owner-camera blend now run after reliable limp end; movement remains locked until the blend completes.
- REVERTED AFTER USER FEEDBACK: the owner limp camera must continue following the simulated head orientation for the intended simulated-FPS view; stabilizing the camera alone made the head feel stationary. Head stability must be fixed in the physical bone/joint tuning instead.
- USER VERIFIED: physical head tuning removed the rapid left-right head oscillation while preserving the simulated-FPS camera following the head.
- PARTIAL: wall-clearance search and the full G8 forced-exit audit remain. Visual smoothness, selective self-contact, and weak-laptop cost still need user review.
- USER DECISION: use two authored recovery variants, `get_up_face_up` and `get_up_face_down`; side recovery is deferred.
- VERIFIED SAVED SCENE: `RecoveryAnimationPlayer` contains `RESET`, `get_up_face_up`, and `get_up_face_down` animation resources.
- USER VERIFIED: runtime selects and reliably replicates the face-up/face-down clip, blends the authoritative final pose into the clip opening, locks recovery through the authored clip, seeks frame 0 without a T-pose flicker, resets startup pose overrides, and falls back procedurally when needed.
- REVERTED AFTER PLAYTEST: enabling the 11 remote physical-bone collision shapes made remote bodies behave like heavy local rigid obstacles and produced inconsistent speed-dependent phasing. Remote peers now render replicated bones without local ragdoll collision; symmetric contact requires a host-authoritative design.
- AGENT NEXT: design host-authoritative ragdoll contact, then audit G8 forced exits.

## Exact next step

USER: when continuing, verify recovery remains stable after the remote collision rollback. AGENT: design the host-authoritative ragdoll contact approach before implementing another collision experiment.

## Historical rig authoring checkpoints

- VERIFIED: branch starts at 31b5395, with multiplayer implementation 0533d52 and verification notes 773e42c in recent history. Working tree was clean at start.
- USER VERIFIED: host/client interaction works; client device active state returns to true after reconnect.
- VERIFIED: user created res://ragdoll/player_rig.tscn with Rig > Skeleton3D and identity transforms. User ran the approved helpers and saved the eleven-bone torso/head/arm skeleton. No physics yet. Agent has not edited the scene.
- M2 integration/polish and remaining M3 cosmetics/gameplay-dependent checks remain deferred, not complete.
- Previous branch context: [multiplayer session](features-multiplayer.md). Its descriptions of uncommitted work are historical; this branch includes the committed work.

### Earlier next steps (superseded by the M5 checkpoint above)

USER VERIFIED: visible Spine bend moves abdomen and chest while pelvis stays fixed. VERIFIED saved scene has restored identity bone rotations and correct independent torso meshes/bindings. Torso attachment checkpoint passed.

User explicitly approved extending bone-add helpers to the remaining planned skeleton, in small groups. Modeling and physics remain manual. No more permission questions needed for these staged bone additions.

VERIFIED: user ran add_neck_head.gd and saved. Neck index 3 parent 2 local Y=0.19; Head index 4 parent 3 local Y=0.06; matching rest/pose, identity rotations, unit scales. Five-bone chain is correct. Interactive Undo was not separately reported.

VERIFIED: NeckAttachment/HeadAttachment bind to Neck/Head and mesh local Y offsets are 0.03/0.125. Screenshot shows expected neck/head blockout.

USER VERIFIED FROM GODOT SCREENSHOT: add_arm_bones.gd was run with player_rig.tscn active and the horizontal arm T-pose is visible. The Skeleton3D tree contains UpperArm_L -> Forearm_L -> Hand_L and the matching right chain. The four arm attachments and capsule meshes are visible in the scene tree; exact Inspector dimensions and Override Pose settings still need a focused check.

Arm helper appends UpperArm_L/Forearm_L/Hand_L and R counterparts to the existing five-bone chain (11 total), preserving existing data, with Undo snapshot. Local offsets: shoulders (+/-0.21,0.13,0) under Chest; forearms (+/-0.28,0,0); hands (+/-0.25,0,0). Character-left is +X. Identity rest bases; joint axes will be configured explicitly during physics.

Then user manually adds four BoneAttachment3D children of Skeleton3D named UpperArmAttachment_L/R and ForearmAttachment_L/R, bound to corresponding bone names (Override Pose off). Each contains a MeshInstance3D with its own NEW CapsuleMesh. All mesh child Z rotations 90 degrees, scale one. Upper-arm radius 0.065, height 0.30, local position (+/-0.14,0,0); forearm radius 0.05, height 0.27, local position (+/-0.125,0,0). Positive X for L, negative for R. No hand visuals yet. The screenshot shows the expected horizontal T-pose; exact property verification and bend tests remain.

Arm helper verification: installed 4.7.2 syntax check exit 0, Problems clear; temporary adapted headless logic test on disposable scene copy passed parent/wrist-position, preservation, Undo/Redo checks. Interactive run and saved scene are now user-verified from the screenshot. Exact arm attachment properties and interactive Undo behavior remain unverified.

USER VERIFIED: arm attachment properties and controlled left/right forearm bend tests work. `Hand_L` and `Hand_R` are skeletal wrist/hand endpoint bones only; they have no visible mesh or physical body. The existing scene-backed hand model remains a separate later integration task and must not be duplicated as a forearm attachment.

USER CLARIFIED: the visible left hand intentionally mirrors the existing hand scene so the thumb faces the character's correct side. The mirrored transform is limited to the cosmetic hand instance; the Skeleton3D, bone attachments, mounts, and future physics bodies keep positive scale. This is intentional for the current hand blockout, not a rig error.

Leg helper created at res://tools/add_leg_bones.gd. It appends Thigh_L -> Shin_L -> Foot_L and the matching right chain to the verified eleven-bone skeleton, using hip-socket offsets (+/-0.10,-0.04,0), shin offsets (0,-0.42,-0.02), and ankle Foot offsets (0,-0.42,0.02). It preserves existing bone data and scene attachments through an Undo snapshot.

USER VERIFIED: add_leg_bones.gd ran successfully and the Skeleton3D now contains all 17 planned bones. Leg meshes and physics bodies have not been added.

BUG FOUND FROM SAVED SCENE: the first leg helper version used zero-offset Foot bones, leaving FootAttachment_L/R at the knee pivot (Y=0.52) instead of the ankle (Y=0.10). The helper is corrected and repair_leg_foot_bones.gd now moves both existing Foot bones to the ankle offsets while preserving Undo. Current leg mesh placement must not be accepted until the repair runs and the foot is rechecked.

SAVED-SCENE CHECK: Foot_L is now at the ankle (Y=0.10), and the left thigh, shin, and foot attachments are bound to the correct bones with the planned mesh sizes. The left foot mesh remains at local Z=-0.10, matching the project's -Z forward convention. Right leg visual attachments are still pending.

SAVED-SCENE CHECK: both right-leg attachments and both cosmetic knee caps now exist with the planned mesh dimensions and correct bone bindings. The KneeCap_L/R nodes currently use their default local position (0,0,0); the planned front offset Z=-0.035 is optional visual polish, not a rig or physics error. Both leg chains are ready for controlled pose tests.

USER VERIFIED: the complete 17-bone visual rig follows pose edits correctly, including the hand instances, both leg chains, feet, and cosmetic knee caps. The reference pose was restored after testing. Visual blockout is complete; physics setup has not started.

USER VERIFIED: `player_ragdoll_test.tscn` was created as a separate physics-test copy of the visual rig. The source visual scene remains separate; no physical bodies or joints have been configured yet.

USER VERIFIED / SAVED-SCENE CHECK: After deleting and rerunning Create Physical Skeleton, Godot generated the approved 11 PhysicalBone3D bodies: Hips, Chest, Head, both upper arms, both forearms, both thighs, and both shins. Spine, Neck, Hand, and Foot remain nonphysical skeletal bones. The Head node is bound to the `Head` bone and has a generated collision child. No physical-body pruning is needed; shape sizing, joint tuning, and simulation tests remain.

USER VERIFIED: after regenerating the physical skeleton, the generated Spine and Neck bodies were removed, the replacement node was named `Physical Bone Head`, and its Inspector Bone Name was corrected to `Head`. The saved scene now contains the approved 11 physical bodies: Hips, Chest, Head, both upper arms, both forearms, both thighs, and both shins. Collision shapes and joint limits remain generated defaults and are not yet tuned.

USER VERIFIED: `Physical Bone Shin_L` is configured as a Hinge joint with Angular Limit enabled, lower limit 0 degrees and upper limit approximately 140 degrees. The remaining joints still use generated defaults. Collision-shape sizing has not started.

SAVED-SCENE CHECK: both `Physical Bone Shin_L` and `Physical Bone Shin_R` are now Hinge joints with Angular Limit enabled, lower limit 0 degrees and upper limit approximately 140 degrees. Elbow, shoulder, torso, and hip joints remain generated defaults.

SAVED-SCENE CHECK: both forearm physical bones are Hinge joints with Angular Limit enabled, lower limit 0 degrees and upper limit approximately 145 degrees. Knee hinges remain configured at approximately 0-140 degrees. Shoulder, torso, hip, and head joints remain generated defaults.

SAVED-SCENE CHECK: both upper-arm physical bones are Cone joints with approximately 100-degree swing spans and 40-degree twist spans. Knees and elbows retain their configured hinge limits. Torso, hip, and head joints remain generated defaults.

SAVED-SCENE CHECK: both thigh physical bones are Cone joints with approximately 80-degree swing spans and 30-degree twist spans. Shoulders, elbows, and knees retain their configured limits. Torso and head joints remain generated defaults.

SAVED-SCENE CHECK: `Physical Bone Chest` is a Cone joint with approximately 25-degree swing and 20-degree twist spans, providing the waist connection from Hips to Chest. The head joint remains generated default.

SAVED-SCENE CHECK: `Physical Bone Head` is a Cone joint with approximately 45-degree swing and 40-degree twist spans. All planned initial joint types and limits are now configured: knees and elbows use hinges; hips, shoulders, waist, and head use cones. Collision shapes remain generated defaults.

USER VERIFIED: the Hips collision shape was resized and saved as a CapsuleShape3D with radius 0.11 m and height 0.22 m. Joint configuration remains unchanged; remaining collision shapes are still generated defaults.

USER VERIFIED: all remaining physical collision shapes were resized and saved. Head is radius 0.09/height 0.25; upper arms 0.06/0.30; forearms 0.045/0.27; thighs 0.075/0.42; shins 0.06/0.42. All collider transforms remain generated values. The 11-body joint and shape blockout is complete; runtime simulation has not been tested.

IMPLEMENTED: added `ragdoll/player_ragdoll_test.gd`, an isolated test controller that registers `ragdoll_test_start` and `ragdoll_test_stop` cheat commands plus the `ragdoll_test.simulating` watch through DebugHub. It can start simulation on scene ready through the `start_on_ready` export and does not integrate with player networking. Updated `docs/DEBUG.md`; editor attachment and runtime drop test remain user verification steps.

BUG FIXED: the first test-controller version incorrectly referenced `DebugHub` as a typed global identifier. This project exposes it as an autoload node but existing scripts access it through `/root/DebugHub`; the controller now follows that pattern via a typed Node reference. Added the `ragdoll` category to `core/debug_hub.gd`.

IMPLEMENTED: extended `ragdoll/player_ragdoll_test.gd` with `ragdoll_test_reset`, which stops the simulator and calls `Skeleton3D.reset_bone_poses()`. The existing `ragdoll_test.simulating` watch remains available, and `docs/DEBUG.md` documents the reset command. Godot editor parsing and user runtime reset verification are pending.

DECISION: user approved a provisional M4 physics-test mass profile. Proposed values are Hips 4.0, Chest 5.0, Head 2.0, each upper arm 1.0, each forearm 0.7, each thigh 2.0, and each shin 1.2. These are test values only and are not final gameplay tuning.

SAVED-SCENE CHECK: non-default provisional masses are saved for Hips 4.0, Chest 5.0, Head 2.0, forearms 0.7, thighs 2.0, and shins 1.2. Upper-arm mass properties are omitted because their requested value 1.0 equals Godot's default. User reports the mass-profile test works; repeated post-tuning stability results remain to be recorded.

IMPLEMENTED: the isolated test controller now applies the existing `Layers` contract at runtime: physical bones use `LIMP_BODIES`, the ground uses `WORLD_STATIC`, and pairwise collision exceptions prevent bodies in the same ragdoll from colliding. Separate ragdolls can still collide through the shared layer. Godot parse/runtime verification of this filtering change is pending.

USER VERIFIED: runtime output reported `Configured 11 physical bodies for world collision without self-collision` followed by `Starting isolated physical-bone simulation`, and the user confirmed the ragdoll still works. A separate Unicode parsing warning reported an unexpected NUL character; targeted and repository-wide scans found no NUL bytes in project text files, so its source remains unidentified and should not be treated as a ragdoll failure.

USER VERIFIED: repeated post-filtering drop tests remained stable. The provisional mass profile and same-ragdoll collision exceptions produce no explosions, joint separation, floor failures, or visible instability. Local physics stability is verified; reset command verification and network replication remain incomplete.

NEXT SLICE DECISION: user chose playable-build integration before visual polish. Proceed in bounded layers: mount the verified visual rig into the existing Player while preserving the Player root, capsule collider, camera, and movement paths; then create the reusable ragdoll component and implement the host-owned limp lifecycle before quantized multiplayer pose synchronization. Do not edit network paths or reparent the Player root.

USER VERIFIED: after enabling and saving `start_on_ready` on the test scene root, the isolated ragdoll started successfully in an F6 run. The body fell from the T-pose onto the saved ground test surface. This is the first verified runtime ragdoll result; stability tuning, reset behavior, collision policy, masses, and network replication remain incomplete.

USER VERIFIED: five repeated F6 drop tests passed. Each run started, limbs stayed connected, knees and elbows behaved within their limits, the body settled on the ground, the head remained attached, and no explosion or instability was observed. Reset behavior, mass tuning, collision policy, and network replication remain incomplete.

FUTURE POLISH NOTE: visual mesh changes can be developed separately when the 17-bone names, hierarchy, rest transforms, and BoneAttachment bindings remain stable. The current `player_ragdoll_test.tscn` is a copied test scene, not a live instance of `player_rig.tscn`, so visual changes to the source scene will not automatically propagate to this test copy. CSGMesh or other visual replacement should not affect physics by itself, but changed bone positions, hierarchy, attachment offsets, or proportions require collider and joint retesting.

Helper syntax check passed on installed 4.7.2; editor diagnostics clear. Disposable-scene logic test (EditorInterface removed and EditorUndoRedoManager calls adapted to standalone UndoRedo) verified append, unchanged torso data/mesh resource, metadata preservation, Undo, and Redo. User execution and saved five-bone data are now verified. No live scene modified by agent.

Verification: Godot 4.7.2 --headless --script res://tools/create_starter_torso.gd --check-only exited 0 with no errors; editor diagnostics clear. Earlier check with --editor also parsed but reported shutdown RID leaks; non-editor check-only was clean. User execution and scene save now verified from screenshot and saved scene; Undo behavior has not been manually tested. Rig scene untouched by agent.

## Scope and contracts

- Overview sections 4, 7 and 17 require leg structure and skeleton-authoring choices before building.
- Recommended humanoid layout has 17 skeletal bones and 11 physical bodies: Hips, Chest, Head, paired upper arms, forearms, thighs and shins. Humanoid layout is approved; proposed dimensions remain adjustable during blockout.
- Rigid primitive visuals attach to bones; final art polish is later. No Blender requested.
- User authors scene hierarchies. One-time bone generation requires explicit selection/approval; no runtime mesh or rig generation shortcut.
- Host simulates ragdolls; clients render synchronized poses. M4 measures stability/CPU/bandwidth at 15/30/60 Hz before final tuning.
- Same-ragdoll self-collision policy and masses must be tested. Do not reparent network Player nodes.
- M5 implements the standing/limp/recovery lifecycle; it is not included in the initial rig task.

## Open questions

- RESOLVED: humanoid legs; manual Godot editor authoring. Exception now approved: one-time starter torso helper only. Remaining modeling/rig adjustments stay manual; no Blender.
- Eye-height integration: current camera 1.55 m versus proposed visual eyes around 1.65?1.70 m; do not change gameplay camera during isolated M4.
- Hand mounting must avoid duplicate forearms and preserve approved finger poses.
- Per-bone masses and final joint tuning (during physics spike).

## Files touched

- This session, session index, and project state only. No new runtime tests needed for documentation preparation.

## Planning checkpoint

Construction plan specifies metre-scale landmarks, 17 skeletal/11 physical bones, rigid visual attachments, staged validation, and a scaffold editor task. No scene or gameplay code changed. Exact bone-editor UI still needs verification against installed Godot; first task deliberately creates only Rig/Skeleton3D.

User-owned worktree change observed: fowl-play/hands/hand_pose_study.tscn is deleted. Left untouched; existing hand checks may depend on this reference scene. No tests run for the scene scaffold read-only verification.

Saved-scene follow-up: NeckMesh BoxMesh size was previously recorded as (0.10,0.08,0.03); planned depth is 0.10. Confirm or correct Size Z to 0.10 (not mesh position) during the next focused Inspector check. Head size is correct.

## 2026-11-17 saved-scene review

Reviewed current saved scenes without editing them. `player_rig.tscn` contains the intended 17 named bones, independent torso and limb meshes, and both instanced hands. `player_ragdoll_test.tscn` is a separate copy with the 11 physical bones, initial joint limits, colliders, provisional masses, and a test floor. Previous user reports of stable repeated drops remain the runtime evidence; no fresh rendered front/side review or reset test was performed here.

- The two world hand instances still show the hand scene's `PoseRoot/Forearm` mesh while the body rig also has separate forearm capsule meshes. `world_mode` is currently a flag only; it does not hide that geometry. In each rig scene, hide only the two instanced `Hand/PoseRoot/Forearm` visuals for the body blockout, preserving the hand scene used in first person and all finger/thumb poses. Check the wrist and cuff transitions from the front and side after doing so.
- Each Foot bone is at Y=0.10, each foot BoxMesh is 0.10 m tall, and each FootMesh child has local Y=0. Its standing sole is therefore Y=0.05, while the design target is Y=0. The isolated test ground is a 0.20 m tall centered box with top Y=0.10, which puts the reference-pose soles 0.05 m into the test ground. A visual alignment pass can set both FootMesh child local Y to -0.05 and place the isolated ground center at Y=-0.10 so its top is Y=0. Keep this as an editor-owned change and recheck drop stability if the test floor moves.
- `player.tscn` still has its collision capsule, Head, Camera3D, and Focus paths, but its visible capsule MeshInstance3D has been removed and no rig instance has replaced it. Standing players are currently invisible until the visual rig is mounted under the unchanged Player root. This is the next integration task, not a reason to rework bone rest transforms.
- The current blockout is structurally sound for a stylized human body: chest wider than waist, paired human thigh/shin/foot chains, and sensible joint locations. It is intentionally boxy and T-posed. Review relaxed arm pose, shoulder/hip transitions, head silhouette, and both thumbs in rendered front/side/bent views before permanent art changes. Keep all 17 bone names, hierarchy, and rest transforms stable; `player_ragdoll_test.tscn` is a copy and will not inherit later visual edits to `player_rig.tscn` automatically.

## Player visual integration handoff (2026-11-17)

User considers the current visual rig ready for integration and defers eye meshes. `player_rig.tscn` now has the tapered shoes/chest/head and a `FacePhoto` Sprite3D using `res://assets/placeholder.jpg`; the beak remains as authored. Per user instruction, leave the separate `player_ragdoll_test.tscn` alone for these cosmetic changes.

Implemented an optional `Rig` reference in `player/player.gd`: once the visual scene is instanced as a direct child of Player, the owner's rig is hidden to keep the first-person camera unobstructed, while remote rigs remain visible. This is a temporary M4 visibility rule; M9's owner-leg visibility treatment remains outstanding. Restored `project.godot` main scene from the isolated ragdoll test to `test_arena.tscn` for the integration playtest. Godot 4.7.2 headless import and focused M0 network checks passed. The Player scene itself has not yet been changed by the agent.

Next editor task: in `player/player.tscn`, instance `res://ragdoll/player_rig.tscn` as a direct child of Player, keep its name `Rig` and local position/rotation zero with scale one. Preserve the existing Player root, CollisionShape3D, Head/Camera3D/Focus paths, and networking paths. Save; run offline and host/client. Owner view should stay clear, each peer should see the other's standing rig, and movement/camera/interaction should behave as before. This is visual mounting only; the isolated physics scene does not become the live Player ragdoll yet.

USER VERIFIED (2026-11-17): `player_rig.tscn` is instanced under Player. The raised gameplay Head/Camera/Focus aim works, and host and client can each see the other's standing rig moving in multiplayer. This verifies visual mounting and standing movement only; the live rig still has no physical-bone simulator or limp behavior.

NEXT EDITOR CHECKPOINT: copy only `Skeleton3D/PhysicalBoneSimulator3D` (including its 11 PhysicalBone3D children and their CollisionShape3D children) from the stable `player_ragdoll_test.tscn` to `player_rig.tscn` under its Skeleton3D. Do not copy the test scene root, controller script, or Ground; do not alter `player.tscn` or the isolated test. The saved visual and test skeletons have identical 17 bone names, parents, rest transforms and poses (51 matching name/parent/rest/pose entries), so the physical-bone bindings are compatible. Save the visual rig, confirm 11 bodies and no simulation at rest, then repeat host/client standing movement. The reusable host-owned simulation component and limp networking are the next code slice after this scene checkpoint.

USER REPORTED COMPLETE: the physical simulator subtree was copied into the visual rig. SAVED-SCENE CHECK: exactly one PhysicalBoneSimulator3D, 11 PhysicalBone3D children, and 11 direct collision-shape children are present. Standing host/client behavior after the copy has not separately been reported.

IMPLEMENTED: `ragdoll/player_rig.gd` prepares the live visual rig in standing mode: stop simulation, clear collision layers/masks, create same-rig collision exceptions, expose the prepared physical-bone count through DebugHub, and log/warn on the expected 11-body count. It provides collision enable/disable methods for the later host-owned limp handoff but does not activate simulation or change Player movement. Godot 4.7.2 script check and editor diagnostics pass. NEXT EDITOR TASK: attach this script to the root Rig node of `player_rig.tscn` in Godot, save, then run host/client and confirm standing movement and the 11-body watch. The isolated test scene remains untouched. After that, implement the host-owned capsule-to-ragdoll handoff and pose replication in bounded steps.

USER VERIFIED: host and client standing rigs still move after attaching `player_rig.gd`; screenshot shows `rig/1/physical_bones = 11` and `rig/<client-id>/physical_bones = 11`.

IMPLEMENTED: internal host-only handoff APIs in `player/player.gd` and `ragdoll/player_rig.gd`. Beginning limp rejects a client caller, disables the standing capsule's collisions and movement acceptance, detaches the rig transform with `top_level`, enables the 11 physical-bone collision masks, and starts simulation. Stopping reverses this setup and restores the rest pose. The Player root does not follow the body yet; stop is forced cleanup, not final recovery. No gameplay trigger, debug command, reliable limp event, camera follow, or multiplayer pose sync was added. The focused `m4_limp_handoff_test.gd` instantiates the saved Player scene, verifies the hips fall without moving the root, and checks cleanup. NEXT: add host-owned reliable begin/end events and sampled/quantized bone poses, then position the capsule from hips during handback and validate in host/client playtests. Keep the isolated ragdoll test unchanged.

IMPLEMENTED (2026-11-17): M4 network spike now has host-only `ragdoll_spike_start/stop <peer_id>` DebugHub commands, reliable begin/end events, a 30 Hz unreliable-ordered stream of quantized poses for all 11 physical bones, and client interpolation. Each sample carries an epoch, sequence, host timestamp, and seven quantized values per bone (millimetre position and normalized quaternion). A client never starts physical simulation; it applies received poses with its simulator modifier disabled. Host capture occurs in `PhysicalBoneSimulator3D.modification_processed`, because ordinary `get_bone_global_pose()` reads outside that callback returned the rest pose even while the physical body was falling. The first client pose is included in the reliable begin event. A pending start can be applied after a newly spawned Player finishes `_ready()`. This is a debug spike, not final lifecycle: stop restores the original capsule position/rest pose; camera follow, auto recovery, settled pose, G2 accuracy, late-join proof, and 15/30/60 Hz measurements remain.

VERIFIED: separate-process host/client checks pass when either the host-owned or client-owned Player is the ragdoll target. The client receives reliable start/end and changing skeletal poses, and cannot initiate host simulation. Focused local handoff and existing M0 network regressions pass. Rendered smoothness/physical feel still require the user two-window playtest. The separate `player_ragdoll_test.tscn` remains untouched.

CHECK LIMIT: `run_checks.ps1` now includes the M4 handoff and two-process ragdoll checks, but the full script currently stops at the older M2 check because the user-deleted `res://hands/hand_pose_study.tscn` is still referenced by `m2_hands_test.gd`. The M4 checks and M0 multiplayer regressions were run directly and passed. Do not silently recreate the deleted reference scene or weaken the M2 assertion as part of the ragdoll slice.

USER VERIFIED (2026-11-17): in a two-window playtest, host and client can each see the other's ragdoll. The owner camera currently stays at the frozen Player root during limp. Camera follow remains a later integration step: follow the smoothed host-authoritative hips position while preserving mouse look, without inheriting bone tumble. This matches the explicit camera decision in `PROJECT_OVERVIEW.md` §5; the older head-bone entries in its lifecycle table have been corrected.

IMPLEMENTED (2026-11-17, awaiting visual playtest): the owner's `Head/Camera3D` becomes top-level only during limp and smooths toward the rig's current hips position plus 0.55 m; its orientation still comes from the standing Head, so mouse look remains independent of bone tumble. The host reads the simulated physical hips; a client owner reads the interpolated Hips skeleton pose. The owner's Rig becomes visible during limp, then the camera and visibility return to the standing setup on stop. Player root remains frozen to avoid physics feedback. `player/<id>/camera_following_ragdoll` watch reports the camera mode. Focused local handoff and two-process host/client checks pass, including client-owner camera motion. Manual visual check of height, framing, wall clipping and return transition remains. M4's bandwidth/CPU/late-join work and final recovery are still pending.

USER VISUAL FEEDBACK (2026-11-17): hips-follow view showed the owner's falling head/body from behind and above. User explicitly wants a first-person ragdoll camera directly at the physical head. This supersedes the previous hips-camera decision in `PROJECT_OVERVIEW.md`.

IMPLEMENTED (2026-11-17, awaiting repeat visual playtest): `player_rig.gd` exposes the moving `HeadAttachment` eye transform at local (0, 0.17, -0.06). The owner's top-level camera takes this position and head rotation each frame, with yaw/pitch mouse-look offsets. Only the owner's `HeadAttachment` is hidden during limp, so the body remains visible and the camera should not look through the face. The standing camera and head visibility return on stop; the capsule stays still. The local handoff and two-process M4 checks pass. Next: user tests host and client owner views for correct eye position, head roll, visible body, and clear face; tune the eye offset if necessary. Final recovery and spike measurements remain.

FOLLOW-UP (2026-11-17): user confirmed the head-anchored view is good and requested a human neck-angle limit before proceeding. `player.gd` now clamps additive limp mouse look to ±75° yaw and ±75° pitch relative to the physical head, while standing look keeps its ±85° pitch. The local handoff test exercises both limits and passes; the two-process M4 check also passes. Await user visual confirmation of the stop angle, then continue the M4 spike measurements/late-join and recovery work.

USER VERIFIED (2026-11-17): the ±75° ragdoll look limit works and feels right. Head-anchored owner camera and the visual ragdoll view are accepted. Next M4 actions, in order: measure actual bone-pose bytes/s and host CPU at 15/30/60 Hz (including several ragdolls), test G2 host/client hips error, then prove late join and add a reliable settled pose. M5 begins only after the spike gate: host-owned limp timer, settled-or-hard-cap recovery, capsule placement from final hips, and a get-up transition.

M4 SPIKE CHECKPOINT (2026-11-17): 30 Hz pose streaming remains the default. Host sends one reliable settled pose after all 11 physical bones stay below 1 m/s linear and 1 rad/s angular speed for 0.35 s; a deterministic two-process test verifies receipt, while natural settling varied between 2 and 3 of 4 bodies after 7 s in separate profile runs (the Head sometimes kept spinning). Mid-limp late join receives the current pose and subsequent stream. The client tests latest-host-snapshot hips error and fails above 0.25 m. Reducing interpolation delay from 70 to 40 ms produced observed maxima 0.13–0.22 m in two-process tests; the client snaps all bones to the latest host pose if it drifts over 0.25 m. This measures newest-received-pose agreement, not instantaneous agreement with an in-flight host state. User must recheck visual smoothness at 40 ms.

M4 RATE PROFILE (2026-11-17, Godot 4.7.2 headless on this PC): one-client host ENet total sent data at 15/30/60 Hz was about 6.5/11.7/21.6 KB/s for a falling ragdoll, including background game traffic. Four simultaneous ragdolls used about 16/32/72 KB/s of raw application pose data at those rates (no recipients in this CPU profile; this is a data estimate, not wire bandwidth). Four-ragdoll process CPU was ~18/21/28% of one core, versus ~16% standing baseline; the Godot physics-frame timing was noisy. These are local measurements, not weak-laptop proof. `tests/run_m4_ragdoll_checks.ps1` runs host/client, late join, settled, G2, and 15/30/60 wire checks. `tests/run_m4_ragdoll_profile.ps1` runs the 4-body CPU/data profile. Focused handoff and M0 regression checks pass; full `run_checks.ps1` still stops at the unrelated deleted hand study scene in M2. Next: user confirms visual smoothness at 40 ms, then implement M5 recovery (host timer, settled/hard-cap decision, standing capsule placed at final hips).

M4 FINAL CHECK (2026-11-17): added late join after the host has already sent its reliable settled pose. The host sends the current begin pose followed by the settled event; the client buffers either event if its Player has not spawned yet. The two-process suite passes this case, mid-limp late join, host/client targets, and 15/30/60 Hz. Repeated wire runs varied with natural settling: about 4–7/8–12/21–22 KB/s at 15/30/60 Hz for one client; these totals include normal game traffic. M0 multiplayer regressions pass. Remaining M4 confirmation is the user's visual smoothness check with the new 40 ms delay and, when available, CPU profiling on a weak target laptop. Do not claim full G6 lifecycle state (remaining timer/carrier) until M5/M6 implement those states.

M5 FIRST RECOVERY SLICE (2026-11-17, PARTIAL): `player/player.gd` runs the sole host-owned free-tumbling timer. At 3.5 s plus all 11 bones slow, or at the 6 s cap, it calls `network.stop_ragdoll_spike()` with a logged reason. That single path captures final physical hips, raycasts down against static/elevator floors, plants the standing capsule at the hips X/Z and floor Y+0.03, stops simulation, restores collisions/camera, and sends the final position through reliable `_ragdoll_end`. If there is no walkable hit within 2.5 m below the hips, it keeps the old standing Y and warns; wall-clearance search remains. The M4 long-running network/profile tests disable automatic recovery explicitly. `tests/run_m5_recovery_checks.ps1` passes host deadline/settled/floor/cleanup checks and a two-process automatic end check; the full M4 paired suite passed after these changes. USER NEXT: playtest host and client `ragdoll_spike_start 1`, allow automatic return, inspect foot placement, walls, and camera snap. AGENT NEXT: implement ~0.5 s ragdoll-to-standing pose/camera blend, then audit G8 forced exits. M4 40 ms smoothing feel and weak-laptop cost are still unverified. No scene files changed in this slice.

M4 SELF-CONTACT POLISH (2026-11-17, PARTIAL): user reported both arms/legs can overlap the torso and approved a selective-contact trial. `ragdoll/self_collision_policy.gd` configures 10 non-neighboring limb-to-Hips/Chest pairs; `player_rig.gd` and isolated `player_ragdoll_test.gd` share it. Connected shoulder/hip/elbow/knee pairs and other same-rig pairs remain exempt. `m4_limp_handoff_test.gd` asserts a forearm/chest and shin/hips contact plus shoulder/knee exemptions. Focused check, full two-process M4 suite, and four-ragdoll 7-second 15/30/60 Hz profiles pass without script errors. Four-ragdoll CPU was about 25–27% of one core versus about 23% standing in this run; these local noisy figures do not prove a weak-laptop budget or visual improvement. USER NEXT: repeat drops in both windows and judge clipping/jitter. No scene files edited.

GET-UP BLEND (2026-11-17, VERIFIED HEADLESS): added `GET_UP_BLEND_SECONDS = 0.5` to the tuning source. `player_rig.gd` captures the final full-skeleton pose before simulation cleanup and blends every bone to the authored rest pose after host or remote end. `player.gd` keeps movement and interaction acceptance locked during `is_recovering`, blends the local camera to the standing Head transform, and exposes `player/<id>/recovering`. The M4 handoff, M5 recovery, and paired automatic-end checks pass. USER NEXT: visually confirm the transition and camera return in both windows; wall clearance and G8 forced exits remain.

RECOVERY SYNC FIX (2026-11-17, VERIFIED HEADLESS): the reliable `_ragdoll_end` event now includes the host's final quantized pose. Remote peers apply that authoritative pose as the recovery blend start instead of relying on the latest local interpolation sample. Host-target and client-target paired M4 checks both pass and require the remote `is_pose_blending` phase. The current blend remains a temporary rest-pose interpolation and is visually awkward; the recommended next animation slice is an editor-authored `AnimationPlayer` get-up clip selected by a replicated recovery variant, with procedural fallback only for unrecognized poses.

### Session 2026-11-17 — get-up blend
- Did: implemented and headless-verified the 0.5 s host/client ragdoll-to-standing pose blend and owner-camera return; added the `recovering` debug watch and updated state/debug documentation.
- Verified: `run_m5_recovery_checks.ps1` passed M5 recovery plus paired M4 automatic end; the standalone M4 handoff check exited 0 without script errors.
- Stopped at: user visual confirmation of get-up motion, selective self-contact, 40 ms interpolation feel, and wall behavior; G8 forced-exit audit is next.
