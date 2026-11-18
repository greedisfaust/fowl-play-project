# Session memory: features/multiplayer

Branch: features/multiplayer
Status: IN PROGRESS — M3 interaction intents automated-verified; host/client interaction user-verified
Last updated: 2026-11-16

## Recovery

User explicitly authorized recovery after switching to M0 and reapplying M3 edits caused conflicts. Created this branch from features/m2-hands at d722c96, preserving M1/M2 history. Reapplied M3 work, resolved four conflicts using the preserved latest versions, and left changes unstaged/uncommitted. Old branches are unchanged. Recovery stash is retained (message: Recovery: preserve M3 changes before returning to M2 baseline). Do not reapply it; its changes are already present.

File and index backups are in the OS temporary directory under fowl-play-recovery-approved-20261116-142149 (inside vscode-agent-codex-sandbox-QCPKNa). The stray untracked hand preview differed only in UID metadata; committed scene retained, stray file backed up separately. No user pose changes were lost in that comparison.

## Current work

M3 standing movement authority approved: owners drive local movement, host validates and relays, remote copies interpolate. movement_stream.gd handles sequence/finite checks, bounded displacement budgets and 100 ms receive-time interpolation. player.gd sends at 20 Hz. Network routes by actual RPC sender and corrects rejected positions. No scene hierarchy changes.

M2 hands committed at d722c96, with remaining integration/polish deferred at user request. See features-m2-hands.md for hand details and earlier M3 implementation notes; its old checkout descriptions are historical.

## Verification and next action

DONE: recovery, movement and roster slices passed automation and user playtests. Interaction-intent slice passes automation; user confirms host/client interaction works. User also confirmed the client device state returns to true after disconnect/reconnect. Next: user checkpoint, then M4 skeleton-authoring preparation; remaining M3 integration stays deferred. Host net/movement_rejected should stay zero for ordinary movement.

## Limitations

Coarse plausibility checks do not validate collision paths. No sanctioned teleport API, limp authority suspension, lunge validation, four-player/WAN validation, or remote hand cosmetics yet. Remote display uses receive timestamps and holds the last sample on packet loss. M3 is not complete. No commit or push performed during recovery.

Recovery verification complete: full run_checks.ps1 passed (exit 0), including import, D0/M1/M2/M3 and all separate-process network scenarios. Editor Problems reports no errors. User subsequently verified two-instance movement works and looks smooth. Other checklist details were not individually confirmed.

## M3 roster and reconnect slice

- Added host-published reliable roster with roster_changed signal and net/roster watch, distinct from transport-local net/peers. Host updates on membership changes; clients accept only host RPCs; shutdown clears the roster.
- Existing periodic movement snapshots bring late joiners to current positions. No scene or synchronizer changes needed for this slice.
- Added tests/m3_roster_test.gd and run_m3_roster_checks.ps1 to the main runner: host moves before joining; first and later clients verify moved position; first client reconnects; all processes compare sorted roster with spawned players and movement registry, and host checks old identity removal.
- Preserved existing user changes to project.godot. No Git history changes.
- USER VERIFIED: host movement before joining, roster/player count comparison and client disconnect/rejoin checklist passed. Three-process behavior is automated-verified; no separate manual three-player claim.
- Full M3 remains incomplete: gameplay-phase late-join restrictions, broader gameplay intent validation, roster profile fields and hand cosmetics are deferred. This slice lists peer IDs only.

Roster verification: full run_checks.ps1 passed (exit 0), including all three roster processes. Initial test caught a roster log formatting error; corrected and rerun cleanly. Editor diagnostics are clear. USER VERIFIED: requested roster/late-join/disconnect/rejoin checklist works. Next: inspect existing M1 interaction intents and shared host validation before selecting the next M3 implementation slice.

## M3 interaction intent slice

- Focus now submits to Network instead of blocking clients. The same host validator handles offline/host input, client RPCs, and debug commands; remote-player focus commands cannot act locally.
- Host chooses actor by actual RPC sender, validates target/action/enabled state/pickup permission, checks reach and occlusion, and applies a 0.15 s request interval. Remote origin uses accepted_position, not delayed display position. Reach uses the collision surface along the camera-to-target-center ray (center fallback for targets without collision), matching the existing test device's focus reach.
- Reliable host responses log acceptance/rejection on the requester. New host watches: net/interaction_accepted and net/interaction_rejected. Existing interact/device/TestUseDevice/active replicates, including late join/reconnect, and resets on session end.
- Interactable has enabled and an optional availability_check predicate; Prop supplies its pickup permission check before the interaction signal. Actual carry/throw and prop physics replication remain M6.
- No scene edits. User project.godot edit preserved. No commit/push.
- Verification: full run_checks.ps1 passed after fixing surface-versus-center reach mismatch found by the late-join test. Includes D0/M1/M2, movement, saved-scene interaction/focus/occlusion tests, separate-process client intent/rejection tests, and three-process device late-join/reconnect checks.
- USER VERIFIED: host and client interactions work. User recalls asymmetric console interaction messages but is unsure which direction. Code confirms expected behavior: host logs every validation; requester gets its own result; every client receives device state changes. USER VERIFIED: client disconnected and reconnected; its device active watch was still true. Reconnect-state playtest passes alongside automated coverage. Device has no visual state animation yet.
- M3 is still incomplete: player gameplay state gates (limp etc.), gameplay-phase join restrictions, profile fields, hand cosmetics, and broader gameplay intents remain pending. Current host validation checks reach/occlusion but does not enforce view angle; future large/offset targets may need authored interaction anchors.


## M2/M3 replicated hand poke slice (2026-11-19)

- The local first-person poke remains immediate and cosmetic.
- After the host accepts an interaction, it broadcasts a reliable `_hand_poke` event containing the actor peer ID and the target body's world position. The host plays remote-player world hands locally; every client accepts the event only from peer 1.
- Each Player resolves its existing `Rig/Skeleton3D/HandAttachment_R/HandMount_R/Hand` and animates the remote world right hand. The owning peer skips its world hand because its first-person viewmodel already played the gesture.
- Pokes are not sent for rejected interactions; the host still owns interaction validation and gameplay effects. Limp, recovering, and carrying actors are excluded from cosmetic playback.
- Added `net/hand_poke_sent` and `net/hand_poke_received` watches, reset with the network session. No scene edits.
- Added a headless check for remote world-hand poke playback and suppression of duplicate local-owner world-hand playback. Full ENet two-instance visual playtest is still required; assistant cannot run Godot here.
