# Session memory: features/player-identity-and-world-kit

Branch: features/player-identity-and-world-kit
Base commit: abb3643d4f9326f0c32a31bfe2ba9b9b46c00b83
Goal: Establish host-authoritative player identities and reusable physical world interaction/display components, then integrate identity presentation into gameplay.
Status: IN PROGRESS — planning recorded; implementation not yet started.
Last updated: 2026-11-19 by GPT-6 (session #1)
Base docs: CLAUDE.md, docs/PROJECT_OVERVIEW.md, docs/PROJECT_STATE.md

## Current state
- This branch starts from the merged Highlight and Accessibility work.
- No game code, scenes, tests, or project-state documentation have been changed on this branch for this feature yet.
- The first implementation slice is Player Identity Core.
- The existing gameplay cursor exposes `GameplayCursor.set_identity_color(Color)`; identity integration must call this existing seam when the assigned color becomes available.
- `Network.player_color()` does not exist and must not be assumed or introduced without an explicit design need.
- Peer ID remains the stable networking identifier; display labels combine nickname and peer ID.

## Planned scope

### 1. Player Identity Core — first implementation slice
- Define reusable identity data containing nickname, unique assigned player color, and peer ID.
- Provide a display label in the form `Nickname (#PeerID)`.
- Host-authoritatively validate and assign identity data; clients must not be trusted to self-assign another peer's identity or color.
- Prevent duplicate lobby colors.
- Resolve duplicate nicknames by deterministic suffixing: `Chicken`, `Chicken 2`, `Chicken 3`, etc.
- Initial ten-color palette: Red, Orange, Yellow, Green, Cyan, Blue, Purple, Pink, Black, White.
- Keep the identity representation reusable for cursor accents, nameplates, indicators, and future scoreboard/UI work.
- Inspect existing Network/autoload and lobby roster contracts before choosing API shape. Do not duplicate existing authority or invent an incompatible roster path.

### 2. Reusable Physical USE Button
- A reusable physical cubic button with softly chamfered/beveled edges: not sharp-edged and not pill-shaped or fully rounded.
- Press animation moves the cap inward along its axis, then springs back.
- Animation must be spam-safe: retrigger smoothly from its current position without snapping, sticking, or accumulating offsets.
- Reuse the existing Interactable and Focus systems; do not create a second interaction framework.
- Scene node construction, mesh authoring, and collision-shape authoring remain editor/user tasks under the project's scene-ownership rules.

### 3. Reusable World Screen Housing
- Separate reusable physical housing from replaceable screen content.
- Support two housing styles:
  - FAT/retro CRT-like bulky housing for tabletop displays and future outcomes.
  - SLIM/modern housing for doorways, wall monitors, and long instructions.
- Housing should be resizable, placeable, and rotatable.
- Keep content dynamically replaceable without coupling it to a particular housing style.
- The casino/gambling loop, bets, payouts, and outcome logic are explicitly deferred; this branch only prepares reusable housing.

### 4. Registration Terminal
- Compose the reusable physical button and world screen.
- Allow a player to enter a nickname, select a color, and confirm identity.
- Host validates and assigns the final identity.
- Keep the terminal's UI/content separate from its physical housing where practical.

### 5. Gameplay Integration
- Feed the assigned identity color into the gameplay cursor through `set_identity_color(Color)`.
- Display nameplates using nickname and peer ID.
- Keep identity data available for future indicators and scoreboard work.
- Do not add casino/table outcome mechanics in this slice.

## Proposed implementation order
1. Player Identity Core.
2. Reusable Physical USE Button.
3. Reusable World Screen Housing.
4. Dynamic Screen Content.
5. Registration Terminal.
6. Gameplay Integration.

## Decisions made (with why)
| # | Decision | Why | Alternatives rejected |
|---|---|---|---|
| 1 | Host-authoritative identity validation and assignment. | Prevents clients from claiming another peer's identity or color and keeps lobby state consistent. | Trusting client-submitted final identity data. |
| 2 | Peer ID remains the networking identity; nickname is presentation data. | Nicknames can collide or change, while peer IDs identify network peers. | Using nickname as a network key. |
| 3 | Duplicate nicknames receive deterministic numeric suffixes. | Keeps labels readable without rejecting common names. | Allowing ambiguous duplicate display names. |
| 4 | Lobby colors are unique within the active lobby and selected from the ten-color palette. | Gives each player a distinct visual accent for cursor/nameplate/UI identity. | Allowing duplicate colors. |
| 5 | Cursor integration uses the existing `GameplayCursor.set_identity_color(Color)` seam. | Connects the future identity system to the already-built cursor without assuming a missing Network API. | Calling `Network.player_color()`. |
| 6 | Physical button and screen are reusable components; screen content is independent of housing. | Supports multiple world placements and both FAT/SLIM styles without duplicating UI logic. | One-off terminal-only meshes/screens. |
| 7 | Existing Interactable and Focus own physical interaction. | Preserves the project's interaction architecture and authority checks. | A parallel button interaction system. |
| 8 | Casino/gameplay outcome logic stays deferred. | This branch establishes identity and reusable presentation hardware only. | Expanding scope into betting, payouts, or table logic. |

## In progress
- [ ] Player Identity Core — not started.
- [ ] Reusable Physical USE Button — not started.
- [ ] Reusable World Screen Housing — not started.
- [ ] Dynamic Screen Content — not started.
- [ ] Registration Terminal — not started.
- [ ] Gameplay Integration — not started.

## Exact next step
Inspect the current project files and contracts for Network, lobby roster/registration, Interactable, Focus, GameplayCursor, and existing tests. Then design the smallest Player Identity Core slice that fits the existing architecture. Do not edit scenes or construct node trees; follow CLAUDE.md scene ownership rules.

## Verification requirements
- Add focused automated tests for identity data validation, host authority, unique color assignment, duplicate nickname suffixing, peer ID preservation, and display-label formatting.
- Add debug watches/logging/commands for identity assignment and rejection, following the existing DebugHub conventions.
- Run the project's configured test runner with Godot 4.7; record actual results only.
- Verify with two running instances (host and client): host assigns distinct colors, duplicate nicknames suffix correctly, clients receive the same roster identity data, and no client can overwrite another peer's identity.
- Verify cursor identity-color handoff in-game once gameplay integration exists.
- Keep documentation synchronized for every implementation slice. Automated checks do not replace rendered host/client verification.

## Scene ownership and workflow contracts
- Read and follow `SESSION_MEMORY_RULES.md` before implementation.
- Never edit a scene that the user currently has open. Announce file handoffs.
- Node trees, meshes, collision shapes, and node construction are editor-authored/user tasks; do not generate scene structures by script.
- Small mechanical text edits to a closed `.tscn` are allowed only under the documented workflow and after confirming the scene is closed.
- Use typed GDScript and avoid `:=` inference traps.
- Do not commit, push, reset, or discard changes without explicit authorization. The user normally owns commits and pushes.

## Known constraints and gotchas
- The current gameplay cursor has a temporary fallback accent; it is not a unique player identity color.
- `Network.player_color()` is not implemented; do not call it.
- Existing Focus/Interactable systems must remain the single physical interaction path.
- No scene ownership/open-scene status has yet been confirmed for any scene that may be touched.
- No automated or multiplayer verification has been performed for this branch's planned work.

## Files touched
- `docs/sessions/features-player-identity-and-world-kit.md` — this session record.
- `docs/sessions/_ACTIVE.md` — active session pointer.
- No game code or scenes changed as part of this documentation-only setup.

## Resume prompt
> Read CLAUDE.md, docs/PROJECT_OVERVIEW.md, docs/PROJECT_STATE.md, docs/sessions/_ACTIVE.md, and docs/sessions/features-player-identity-and-world-kit.md. Verify the current branch, status, log, and diff read-only. Recap in at most 8 lines, then wait for my explicit go before editing.

## Session log
### Session 1 — 2026-11-19 — GPT-6
- Did: recorded the approved Player Identity & World Kit scope, initial identity decisions, implementation order, verification requirements, and scene/workflow constraints; pointed the active-session index to this branch.
- Changed: documentation only (`docs/sessions/_ACTIVE.md` and this session file).
- Not done: no game code, scenes, tests, or Project State changes; no Godot checks or multiplayer verification.
