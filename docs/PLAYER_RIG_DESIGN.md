# M4 player rig construction plan

Status: humanoid legs and manual Godot authoring APPROVED by user. Dimensions below are proposed blockout targets, not verified final art or physics tuning.

## Goal and scope

Build a human-proportioned, readable low-poly body with coherent shoulders, pelvis, elbows, knees, wrists and ankles. Keep the existing stylized hands and the project's cosmetic beak/eyes compatible with the body. Human describes the anatomy and articulation; the existing mascot identity is not silently replaced with photorealistic human art.

Modeling makes the visible shape. Rigging places joints and defines how parts follow them. Ragdoll physics adds collision bodies, masses and joint constraints. We will verify each layer separately, then combine them.

Manual Godot construction uses rigid primitive meshes on bone attachments. This supports a stylized segmented character; it will not produce realistic soft shoulder/elbow deformation like a weighted continuous skin. Shape transitions and overlaps must therefore be deliberately designed. If a continuous skin becomes a requirement, revisit the approved workflow before building it.

## Constraints checked against the project

- [Player scene](../fowl-play/player/player.tscn): capsule is 1.8 m tall, radius 0.35 m, centered 0.9 m above root. Feet/root plane is Y=0.
- Existing Head/Camera3D is 1.55 m above root. A human-proportioned 1.8 m blockout will likely put the visual eyes higher, around 1.65–1.70 m. Preserve the gameplay camera during M4; explicitly resolve this offset at integration. Do not quietly lengthen the head downward or move the camera to conceal the mismatch.
- [Hand scene](../fowl-play/hands/hand.tscn) is authored at a larger local scale and includes palm, wrist, cuff and forearm. It cannot simply be attached at scale 1 to a metre-scale body. Its origin is not the wrist pivot.
- Existing point/guard thumb poses are user-approved. Preserve their data. World-hand integration is a later, explicit task; the body can use placeholder hand silhouettes meanwhile.
- User builds scenes; no generated rig or mesh scripts, no Blender, no changes to live player hierarchy during the isolated prototype.

## Proportions and coordinate convention

Proposed height: 1.80 m, measured from soles to crown. Root at ground between feet; +Y up; facing -Z. Character-left is +X, character-right is -X. Name sides from the character's perspective, not the viewport.

Start in a symmetric T-pose for easy measurement and joint-axis checks. This is an authoring pose, not the eventual idle. Keep scene root and Skeleton3D scale at (1,1,1). Size meshes using resource dimensions, and offset geometry relative to joint pivots. Do not use negative scale to mirror physics or the skeleton.

| Landmark | Proposed height/extent in metres | Purpose |
|---|---|---|
| Crown | Y=1.80 | Match existing standing height |
| Head base / Head pivot | Y=1.55 | Head geometry extends upward from here |
| Neck base | Y=1.49 | Short neck, shoulders separate from head |
| Shoulders | X=+/-0.21, Y=1.43 | 0.42 m between shoulder pivots |
| Elbows in T-pose | X=+/-0.49, Y=1.43 | Upper arm length 0.28 m |
| Wrists in T-pose | X=+/-0.74, Y=1.43 | Forearm length 0.25 m |
| Fingertips in T-pose | Approximately X=+/-0.92 | About 1.84 m total arm span |
| Pelvis center / Hips pivot | Y=0.98 | Body root pivot near pelvis center |
| Hip sockets | X=+/-0.10, Y=0.94 | Legs attach inside pelvis, not at its outside corners |
| Knees | X=+/-0.10, Y=0.52, Z=-0.02 | Slight forward knee bias for later leg solving |
| Ankles | X=+/-0.10, Y=0.10 | Foot soles reach Y=0 |
| Foot length | Approximately 0.25 | Most of foot extends forward (-Z), short heel behind |

These are visual planning landmarks in skeleton space, NOT parent-relative Inspector values. Each editor card must give exact local rest transforms for its bones. Never paste this table directly into every bone's local Position field.

Torso starts around 0.40 m wide at the chest, 0.28 m at the waist and 0.30 m at the pelvis; depth roughly 0.20–0.24 m. Head starts around 0.16 m wide, 0.25 m tall, 0.20 m deep. Upper limbs should taper toward wrists/ankles. Tune with front and side views before freezing proportions. Capsule width is a movement envelope, not the required chest width.

## Skeleton and body ownership

17 skeletal bones, starting with the hierarchy already specified in the [project overview](PROJECT_OVERVIEW.md#7-player-body-and-skeleton):

```text
Hips
├── Spine
│   └── Chest
│       ├── Neck
│       │   └── Head
│       ├── UpperArm_L → Forearm_L → Hand_L
│       └── UpperArm_R → Forearm_R → Hand_R
├── Thigh_L → Shin_L → Foot_L
└── Thigh_R → Shin_R → Foot_R
```

- Initial torso rest landmarks: Hips Y=0.98; Spine Y=1.12; Chest Y=1.30; Neck Y=1.49; Head Y=1.55. Chest/upper-arm attachment offsets place shoulders above the Chest pivot.
- Bone pivots are joint centers, not mesh centers. A forearm bone starts at the elbow; its hand child starts at the wrist. Shin starts at knee; Foot starts at ankle.
- Establish and record rest bases during the minimal skeleton exercise. Parent-local translations must account for those bases. Avoid casually rotating bone rest axes after attachments and constraints exist.
- Rest transforms define the reference shape. Pose transforms are temporary animation/articulation. Resetting pose must recover the intended reference shape after save/reopen.
- The body skeleton owns shoulder/elbow/wrist placement. The existing hand controller owns finger poses. Future arm aiming may pose the body chain, but must not compete with physics for the same bones.
- Future world-hand mounting needs a positive-scale adapter with wrist alignment. Hide/remove the hand scene's decorative forearm in a world-specific variant so it does not double the rig's forearm. Preserve the first-person scene and approved poses. Create/check a proper left counterpart; do not mirror the whole physics rig with negative scale.

## Visible construction

Start with separate pelvis, abdomen, chest, neck and head shapes; add one complete arm and leg before repeating the other side. Use simple boxes/capsules/cylinders as measuring forms. Refine taper and transitions after proportions work.

Use BoneAttachment3D nodes to follow named bones, with MeshInstance3D children positioned around the bone pivot. Keep attachment override_pose off for ordinary following. These are rigid attachments, not skin weights.

Avoid a single rectangular torso slab: distinguish chest volume, narrower waist and pelvis. Avoid giant ball joints. Use small deliberate overlap around shoulders, elbows and knees so ordinary bends do not reveal open gaps. Check bent poses as well as T-pose; geometry that only fits while straight is unfinished.

Physics colliders are separate from visible geometry. They may be simpler and slightly inset; the beak, eyes, cuff and individual fingers do not need independent physics bodies. No decorative rigid bodies.

## Physics stage

Start with 11 physical bodies: Hips, Chest, Head, paired UpperArm, Forearm, Thigh and Shin. Spine, Neck, Hand and Foot remain skeletal bones without their own bodies. During ragdoll, hands follow forearms and feet follow shins with their fixed rest offsets. Finger animation must be put into its limp mode at later integration.

Use an explicit PhysicalBoneSimulator3D under Skeleton3D. Inspect generated physical skeleton output if using Godot's editor command: do not assume its automatically generated shapes, body count or joints match our design. Check physical parent relationships through nonphysical Spine/Neck bones; verify head connects to chest and chest to hips.

Elbows/knees use hinges; shoulders/hips/waist/neck use limited swing/twist joints, beginning from the overview's proposed limits. Verify local joint axes on each side separately so knees do not bend backward and a mirrored elbow does not reverse its limits. Test one joint before enabling the whole ragdoll.

Masses remain an M4 tuning decision. Select a coherent total and distribution during the first physics test; avoid extreme neighboring mass ratios. The original no-self-collision baseline passed stability tests. The current selective policy allows 10 non-neighboring forearm/thigh/shin-to-torso pairs to contact, while connected joints and other same-ragdoll pairs remain exempt; test the visual benefit and stability before expanding it. Different ragdolls must still collide. The host is the only ragdoll simulator; clients interpolate authoritative poses.

Standing-state physical bodies must be inactive with collisions disabled. The live standing capsule and ragdoll must not push each other. Keep the network Player root stable; the simulated body must never inherit a transform that is being driven back from that same body. The isolated test avoids introducing this integration feedback loop prematurely.

## Build sequence and checkpoints

| Step | Work | Must pass before advancing |
|---|---|---|
| 1 | Standalone Rig scene and a minimal Hips/Spine/Chest skeleton, manually | Bones can be created, parented, posed, reset and saved/reopened correctly |
| 2 | Torso/neck/head plus proportion reference shapes | Front/side silhouette is human-proportioned; dimensions agree; no camera changes |
| 3 | One arm and leg, then the other side; complete 17 bones | Correct joint centers and left/right names; reference pose resets reliably |
| 4 | Body primitive attachments and placeholder hand/foot shapes | Shoulder/elbow/knee test bends look connected; hands sit at wrists; soles meet ground |
| 5 | Physical bodies and constraints in a separate test scene | One-joint tests pass; complete drop settles without explosions or impossible bends |
| 6 | Local ragdoll debug controls and repeatable tests | Start/reset reliably; body count and simulation state observable through DebugHub |
| 7 | Host/client pose replication and measurements | Only host simulates; peers agree; compare 15/30/60 Hz CPU, bandwidth and visual quality |
| 8 | Integration handoff | Record unresolved limits, camera/hand adapters, measured settings, and M5 lifecycle work |

Do not author the full body, networking and gameplay state transitions in one pass. Four-player/weak-laptop performance is measured, not promised. This plan is complete enough to guide construction, but final proportions and physical stability require editor checks and playtests.

## First editor task (scene scaffold only) ? VERIFIED complete

Proposed new scene: `res://ragdoll/player_rig.tscn` (does not exist yet).

1. In Godot FileSystem, right-click `res://` and create a folder named `ragdoll` if absent.
2. Scene > New Scene; choose **3D Scene**. Rename the Node3D root to **Rig**.
3. Select Rig, use **Add Child Node** (Ctrl+A), search **Skeleton3D**, and add it. Keep its name Skeleton3D.
4. Confirm both nodes have Position (0,0,0), Rotation (0,0,0), Scale (1,1,1).
5. Save as `res://ragdoll/player_rig.tscn`.

Expected tree: Rig > Skeleton3D. Empty viewport is normal: no mesh or bones exist yet. Skeleton bones are entries inside Skeleton3D, not ordinary Node3D children. Do not add physics yet or instance this into the live player scene.

Completion: saved scene contains those two nodes with identity transforms. Next card verifies the installed Godot bone-editing UI and authors only the minimal torso chain; exact bone UI labels have not been verified against this installed editor, so no invented Add Bone menu is assumed here.

## Reference and verification notes

Reviewed existing player/hand scenes and the project overview. Official Godot documentation supports the skeleton rest/pose model, bone attachments, and explicit simulator ownership:

- [Skeleton3D](https://docs.godotengine.org/en/4.6/classes/class_skeleton3d.html)
- [BoneAttachment3D](https://docs.godotengine.org/en/stable/classes/class_boneattachment3d.html)

Online reference versions are not a substitute for the installed 4.7 editor's F1 help. Exact bone-authoring UI, physical parent behavior after body pruning, and joint frames will be verified during the corresponding small editor tasks. No code/scene changes or runtime tests were performed for this planning document.

### Bone-authoring workflow correction

The saved scaffold has been verified. Upstream Godot Skeleton3D editor source exposes existing-bone pose/rest editing but no ordinary Add Bone command. The initial assumption that a new bone chain can be authored entirely in the Inspector is not established. Inspect the user's installed UI before giving further instructions. If no creation controls exist, discuss manual scene-data entry or an explicitly approved one-time editor helper. Do not silently switch to generated bones.

### Approved starter-bone exception

User approved the one-time helper after the manual bone-creation UI limitation was explained. [create_starter_torso.gd](../fowl-play/tools/create_starter_torso.gd) adds only Hips, Spine and Chest to the empty saved rig scene, with identity rest bases and parent-local Y offsets 0.98, 0.14 and 0.18 m. It sets matching pose positions, supports Undo, rejects an existing skeleton, and requires manual saving. No meshes or physical bodies are generated. Subsequent bone expansion is outside this helper's scope.

Run in Godot with player_rig.tscn active: open helper in Script editor, File > Run (Ctrl+Shift+X), return to 3D and select Skeleton3D. Save after confirming the three-bone chain. Do not attach the EditorScript to a node. After persisted bones are verified, remove the helper through the editor. Syntax check passed; user execution is pending.

Starter torso verification: user ran the helper and saved player_rig.tscn. Hips/Spine/Chest parent indices and matching rest/pose local Y offsets 0.98/0.14/0.18 are verified, with identity rotations and unit scales. Skeleton-space heights are 0.98/1.12/1.30 m. Next is manual pose exploration; visual body shapes and physics have not been added.

### Visible torso editor task

Saved bone rotations have been verified reset. The bone-only posing exercise was inconclusive visually, so add visible reference forms before repeating it. All three BoneAttachment3D nodes are direct children of Skeleton3D, bound by Bone Name; Override Pose stays off. A separate MeshInstance3D is a child of each attachment, with its own BoxMesh resource:

| Attachment / bone | Mesh child | BoxMesh size XYZ (m) | Mesh local position XYZ (m) |
|---|---|---|---|
| PelvisAttachment / Hips | PelvisMesh | 0.30, 0.20, 0.22 | 0, 0, 0 |
| AbdomenAttachment / Spine | AbdomenMesh | 0.28, 0.20, 0.20 | 0, 0.03, 0 |
| ChestAttachment / Chest | ChestMesh | 0.40, 0.30, 0.24 | 0, 0.04, 0 |

Keep mesh rotations zero and scales one. Attachment transforms follow their bones; place geometry with the mesh child's offset, not the attachment. These dimensions deliberately overlap slightly in height, and form only the first silhouette blockout. Save and inspect front/side views before adding details or physics. Pelvis bottom is Y=0.88 and chest top Y=1.49, leaving room for legs and neck/head. Creating regular Node3D children called Hips etc. is not a replacement for binding bone attachments.

Visible torso checkpoint: saved scene verified with three independent BoxMesh resources, correct sizes, bindings and child offsets. Shared-resource sizing issue is resolved. Bone rotations are reset. Next: visible Spine pose check (abdomen and chest follow; pelvis stays), then restore pose before continuing. The current pelvis mesh name is PelvishMesh; this spelling does not affect its attachment.

Torso bend checkpoint: USER VERIFIED abdomen/chest follow Spine while pelvis stays fixed. Saved scene verified reset to identity rotations afterward. Next planned bones are Neck (Chest child, local Y=0.19) and Head (Neck child, local Y=0.06). Confirm extending the limited starter-bone helper exception before creating more bones; visible modeling remains manual.

### Approved staged bone helpers

User explicitly extended approval to remaining planned bones in small groups. No additional approval is needed for those bone additions; mesh/model construction and physics remain manual. The current helper is [add_neck_head.gd](../fowl-play/tools/add_neck_head.gd), run with player_rig.tscn active via Script editor File > Run. It appends Neck and Head only, rejects an unexpected/non-three-bone hierarchy, preserves stored torso bone data and attachments, supports Undo/Redo, and leaves saving to the user. Starter helper should not be rerun. Verify the resulting five-bone chain before teaching neck/head visual shapes.

### Neck/head checkpoint and visible-shape task

Saved Neck/Head bones verified with correct parent indices 2/3 and local rest/pose Y offsets 0.19/0.06. Under Skeleton3D create NeckAttachment -> NeckMesh and HeadAttachment -> HeadMesh. Bind Bone Name to Neck/Head; Override Pose off. Each mesh gets a separate new BoxMesh: neck size XYZ (0.10,0.08,0.10), local position (0,0.03,0); head size (0.16,0.25,0.20), local position (0,0.125,0). Rotations zero, scales one. Neck slightly overlaps chest/head; head crown is at 1.80 m. Save and inspect silhouette before arms. User requests concise instructions to conserve remaining usage; checkpoint supports resuming later.

### Arms editor task

[add_arm_bones.gd](../fowl-play/tools/add_arm_bones.gd) appends the approved left/right upper-arm, forearm and hand chains (11 bones total). Requires exactly the five-bone torso/head chain; preserves it, with Undo/Redo. No scene autosave, meshes or physics generated. Run with player_rig.tscn active and save manually.

For visible arms, add four BoneAttachment3D children directly under Skeleton3D, bound to UpperArm_L, Forearm_L, UpperArm_R, Forearm_R. Keep Override Pose off. Each gets a MeshInstance3D child with an independent CapsuleMesh. Upper-arm radius 0.065 and total height 0.30 m, child local X=+0.14 (L) or -0.14 (R). Forearm radius 0.05, total height 0.27 m, child X=+0.125 (L) or -0.125 (R). Child Y/Z positions zero, Z rotation 90 degrees, X/Y rotation zero, scale one. Capsules are symmetric: both sides can use the same positive Z rotation while positions differ. Bone/attachment bases remain unchanged. Hands are attachment bones only for now; do not duplicate the old hand forearm visuals. Expected silhouette: horizontal T-pose arms with slight overlaps. Save and verify before articulation tests.
