# Session memory: features/m2-hands

Branch: features/m2-hands
Status: IN PROGRESS
Last updated: 2026-11-16

## Current state

- D0, M0 and M1 were previously verified. Current work is M2 local hands; cosmetic networking remains M3.
- User owns scene/model authoring in Godot. Godot-only workflow; geometry polish deferred until poses and presentation work.
- Saved hand.tscn has hand.gd attached, PoseRoot, four chained capsule fingers (Pinky naming), two thumb segments, and IndexAim at the index knuckle.
- Visible palm is a custom tapered CSGPolygon3D: depth 0.11, Y=-0.055. Original box Palm is hidden. Wrist, cuff and forearm remain boxes.
- Standalone tests/hand_preview.tscn exists. User screenshots show idle, point and guard; thumb poses have been accepted provisionally. Hidden-side clearance and final fist readability remain unverified.
- Controller blends finger/thumb poses and whole-hand guard offsets. Priority: limp > guard > carry > reach/hover > relaxed. Stable attachment root is preserved.
- Reach extends toward a supplied target and returns; preview command delays one second. No hold phase exists. Distance/timing are additionally smoothed by pose blending; visual tuning and body-center bias remain pending.
- Sway is bounded and decays. Shake only logs, speed only stores a value, and world_mode does not implement visibility/placement.

## Latest fixes and validation

- Debug registration retains hand_pose_Hand for an uncontested name; collisions receive an instance-ID suffix. Cleanup uses stored registration keys.
- Player tint duplicates authored BaseMaterial3D overrides, uses opaque player hue with original brightness (darker cuff), preserves shared resources and avoids cumulative darkening. Current scenes supply overrides for all hand parts. Unsupported/missing overrides are skipped.
- Index aiming blends toward a no-roll rotation limited to a configurable 35-degree cone around authored forward. Invalid/coincident targets return toward rest. Targets outside the cone intentionally cannot be pointed at exactly.
- VERIFIED: focused M2 headless tests pass on Godot 4.7.2 (exit 0). Tests cover poses, reach return, independent same-name commands/cleanup, isolated opaque tint, repeated color assignment, aim blending/limits and rest recovery. Editor diagnostics report no errors.
- The full runner passed in a previous session according to prior notes; only M2 was rerun for these fixes.
- No scene edits or Git history operations in this slice. Existing uncommitted work remains intact.

## Exact next action

User restarts the preview and compares idle/point/guard/reach. Check index transition and whether the 35-degree cone feels too restrictive. Then proceed with editor-owned player integration, with explicit local/world visibility handling and separate left-hand authoring. Do not describe M2 as complete.

## Remaining issues

- Fist readability: palm hides folded fingers from the current camera angle; inspect thumb clearance from the underside.
- Palm has sharp thickness edges; wrist/cuff/forearm still need silhouette polish in Godot.
- Reach envelope is double-smoothed; no centerward bias yet.
- Bob, shake, complete limp/carry presentation, world/first-person placement and gameplay hookups remain unfinished.
- Tint visual appearance and aiming changes still need user playtesting.

## Debug preview

Use hand_pose_Hand idle|point|guard|limp|reach for the single preview hand. With duplicate names, consult the Commands list for suffixed names. Reach preview starts after one second so the console can be closed.

## Approved guard thumb transfer
User approved hands/hand_pose_study.tscn. Captured exact root and multi-axis second-joint rotations in hand.gd; joint 1 stays identity and base position remains unchanged. Use Authored Guard Thumb defaults true and supersedes legacy preview guard offsets. Idle/point remain separate. Scene-backed test compares all three thumb rotations and positions directly with the off-tree study and checks guard release; M2 passes. No scene edits. Study still has a controller attached, so running it can alter its manually posed reference. Next: rerun hand_preview, hand_pose_Hand guard, confirm visual match. No automatic live link to future study edits.

User explicitly requested the approved study thumb for point too. Added Use Authored Point Thumb (default true); pointing and reach now use the same approved rotations as guard, respecting guard/limp/carry priority. Legacy point offsets are bypassed when enabled. M2 test compares all three point thumb rotations against the study and checks idle recovery; passes. Idle remains relaxed. No scene edits.

## Thumb scope correction
User explicitly requires the approved study thumb in BOTH pointing and guard. Implemented Use Authored Point Thumb (default true), also used during reach. Existing point-angle overrides are bypassed when enabled. Point Curl Degrees now defaults to guard-equivalent (-75,-85,-45), replacing the 75-percent curl; index stays straight. Tests compare point and guard thumbs to the study and all three folded pointing finger chains to guard curl. Focused M2 checks pass. Next: user restarts preview and checks point/guard visually. No scene edits.

## User checkpoint
USER VERIFIED: approved study thumb works in both pointing and guard; full pointing finger curl works. User explicitly asked to move away from hand work. Stop hand refinement for now. M2 remains partial: player/world/left-hand integration, bob/shake and geometry polish are outstanding. Next non-hand roadmap item is the M3 networking decision gate; do not silently mark M2 complete or implement networking before agreeing its authority approach.
