# Session memory: features/player-identity-and-world-kit

Branch: features/player-identity-and-world-kit
Base commit: abb3643d4f9326f0c32a31bfe2ba9b9b46c00b83
Goal: Establish host-authoritative player identities and reusable physical world interaction/display components, then integrate identity presentation into gameplay.
Status: IN PROGRESS — Player Identity Core, Physical USE Button, reusable WorldScreen content, FAT/SLIM housing controllers, ScreenMenu, and RegistrationTerminal code are implemented; terminal editor fixture and Godot/multiplayer verification pending.
Last updated: 2026-11-19 by GPT-6 (session #1)
Base docs: CLAUDE.md, docs/PROJECT_OVERVIEW.md, docs/PROJECT_STATE.md

## Current state
- This branch starts from the merged Highlight and Accessibility work.
- Player Identity Core code, focused tests, test-runner registration, and documentation are now prepared on this branch.
- No scenes or node trees were changed.
- Player Identity Core and Physical USE Button code are present; user has editor-authored and playtested the physical button fixture. The saved viewport texture Local to Scene fix still needs confirmation in the pushed scene file.
- Reusable ScreenText is implemented as a RichTextLabel subclass for SubViewport-based world displays.
- Latest pushed FAT and SLIM scenes both place WorldScreen, Chassis, and Glass as direct children of their housing roots. The housing controllers now target those direct-child paths.
- Added `slim_world_screen.gd`, revised `fat_world_screen.gd`, and shared `world_screen_glass.gdshader`. Both controllers resize the display/glass and authored chassis details from `display_size`; the shader adds subtle smoked tint, view-angle Fresnel, diagonal sheen, and edge glints.
- The two housing `.tscn` root nodes currently do NOT have their controller scripts attached. User must attach `slim_world_screen.gd` to SlimWorldScreen and `fat_world_screen.gd` to FatWorldScreen in the Inspector. Scene files were intentionally left untouched because scene-open status was not confirmed.
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
| 9 | If a requested color is occupied, assign the next free palette color in wraparound order. | Keeps registration smooth while guaranteeing lobby color uniqueness. | Rejecting registration and forcing another manual selection. |

## In progress
- [x] Player Identity Core — implementation added; Godot and two-instance host/client verification pending.
- [x] Reusable Physical USE Button — reusable presentation script and automated test added; editor-authored scene fixture and runtime verification remain.
- [x] Reusable World Screen Housing — FAT/SLIM responsive controllers and shared optical glass shader added; attach scripts to scene roots and verify in Godot.
- [x] Dynamic Screen Content — ScreenText script and focused test added; Godot execution pending.
- [x] Registration Terminal controller and local menu/input flow added; editor-authored fixture and Godot/host-client verification pending.
- [ ] Gameplay Integration — not started.

## Exact next step
Pull the Registration Terminal implementation. In the editor, create the terminal controller node under the authored terminal root (do not rebuild the screen or button), attach ui/registration_terminal.gd, assign its screen and use_interactable exports, and ensure the same button Interactable is assigned to PhysicalUseButton. Then run the registration-terminal test stage and verify local menu behavior plus host/client identity assignment. No Godot execution or terminal scene verification has been performed by the assistant.

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
- fowl-play/ui/screen_text.gd — reusable CMD-style RichTextLabel component, configurable font/size/colors, styled append/clear API, and line-count watch.
- fowl-play/tests/m3_screen_text_test.gd — focused layout/default/content/clear contract checks.
- `fowl-play/core/player_identity.gd` — reusable identity data and palette.
- `fowl-play/core/network.gd` — host assignment, validation, identity roster replication, lifecycle cleanup, and diagnostics.
- `fowl-play/tests/m3_identity_test.gd` — focused identity-core checks.
- `fowl-play/tests/run_checks.ps1` — registers the identity test stage.
- `docs/DEBUG.md` — identity watches/commands and verification notes.
- `docs/PROJECT_STATE.md` — current branch state and implementation record.
- `docs/sessions/features-player-identity-and-world-kit.md` — progress, decisions, and handoff.

## Resume prompt
> Read CLAUDE.md, docs/PROJECT_OVERVIEW.md, docs/PROJECT_STATE.md, docs/sessions/_ACTIVE.md, and docs/sessions/features-player-identity-and-world-kit.md. Verify the current branch, status, log, and diff read-only. Recap in at most 8 lines, then wait for my explicit go before editing.

## Session log
### Session 1 — 2026-11-19 — GPT-6
- Did: recorded the approved Player Identity & World Kit scope, initial identity decisions, implementation order, verification requirements, and scene/workflow constraints; pointed the active-session index to this branch.
- Changed: documentation only (`docs/sessions/_ACTIVE.md` and this session file).
- Not done: no game code, scenes, tests, or Project State changes; no Godot checks or multiplayer verification.

### Session 2 — 2026-11-19 — GPT-6
- Did: implemented the first Player Identity Core slice using the existing Network autoload; added the reusable identity type, host-authoritative identity requests/assignment, duplicate-name suffixing, unique palette fallback, reliable identity roster replication, cleanup, diagnostics, and focused tests.
- Changed: `fowl-play/core/player_identity.gd`, `fowl-play/core/network.gd`, `fowl-play/tests/m3_identity_test.gd`, `fowl-play/tests/run_checks.ps1`, `docs/DEBUG.md`, `docs/PROJECT_STATE.md`, and this session file.
- Not done: no scenes or node trees changed; Godot test execution and two-instance multiplayer verification remain pending.


### Session 3 — 2026-11-19 — GPT-6
- Did: added `PhysicalUseButton`, a reusable presentation component that listens to the existing `Interactable.interacted` signal, plays a local-space cap press/spring return, safely retriggers from the current position, and relays the visual event from host to clients through a reliable presentation RPC. Added a focused test and debug watch documentation.
- Changed: `fowl-play/interaction/physical_use_button.gd`, `fowl-play/tests/m3_physical_use_button_test.gd`, `fowl-play/tests/run_checks.ps1`, `docs/DEBUG.md`, and this session file.
- Not done: no scene/node tree authored; Godot execution and rendered host/client verification remain pending. The user must create the first button fixture in the editor.


### Session 4 — 2026-11-19 — GPT-6
- Did: added ScreenText, a reusable CMD-style RichTextLabel subclass for world-screen SubViewports. Defaults are a near-black blue backing, gold bold headers, bright-white body text, left alignment, and LTR direction. Font resource, font size, and colors are Inspector-configurable; methods append headers/paragraphs/prompts or clear the display.
- Added focused m3_screen_text_test.gd, registered the screen-text test stage, and added the screen DebugHub category plus a rendered-line-count watch.
- Documented the separation between crisp text rendering and actual bloom: the later 3D screen material must use the SubViewport texture as emission, and the containing WorldEnvironment must enable Glow.
- Not done: Godot tests/import have not been run; no scenes, SubViewport nodes, meshes, materials, or WorldEnvironment settings were authored. FAT/SLIM housing remains.


### Session 5 — 2026-11-19 — GPT-6
- Did: fetched and reviewed the user's latest pushed FAT/SLIM scenes at commit `61409bf`. Confirmed both scenes now have direct-child `WorldScreen`, `Chassis`, and `Glass` nodes. Found the FAT controller's old nested-chassis paths, a missing referenced shader file, no SLIM controller file, and stale tests.
- Added the responsive SLIM controller, rewrote the FAT controller for the corrected hierarchy, and introduced a shared optical glass shader with smoked tint, view-angle Fresnel, a soft diagonal reflection band, and subtle edge glints. Updated the FAT/SLIM contract tests to instantiate the real authored scenes.
- Changed: `fowl-play/environment/kit/slim_world_screen.gd`, `fat_world_screen.gd`, `world_screen_glass.gdshader`, both housing tests, and this session file.
- Not changed: no `.tscn` files or authored node trees were edited because scene-open status was not confirmed. Both housing root nodes still need their matching controller scripts attached in the Inspector.
- Not done: Godot import, headless tests, and rendered visual checks have not been run by the assistant.


### Session 7 — 2026-11-20 — GPT-6
- Did: corrected the content API commit chain by restoring `set_content` on top of the actual latest branch tree, then added reusable named text presentation presets: standard, welcome, information, warning, success, and confirmation.
- Presets apply per-call colors without mutating exported default colors. Existing append/clear methods and the screen's visual/rendering settings are preserved.
- Added replacement and preset assertions to the ScreenText and WorldScreen tests; updated debugging and project-state documentation.
- Not done: no scenes changed; Godot tests and rendered in-game verification have not been run by the assistant.


### Session 8 — 2026-11-20 — GPT-6
- Did: added the reusable World Screens & ScreenText guide covering scene hierarchy, architecture boundaries, FAT/SLIM housing usage, display sizing, viewport/font scaling, text styling APIs, named presentation presets, HDR/LED rendering, per-instance resource isolation, troubleshooting, and verification.
- Updated the project-state and debug references to point to the guide and describe the current screen diagnostics/API.
- Changed: `docs/WORLD_SCREENS_AND_SCREEN_TEXT.md`, `docs/PROJECT_STATE.md`, `docs/DEBUG.md`, and this session file.
- Not changed: no game scripts, tests, or scenes changed. Godot tests and rendered verification were not run for this documentation-only update.


### Session 9 — 2026-11-20 — GPT-6
- Added the first reusable interactive menu foundation. `ScreenMenu` validates menu options, supports disabled rows, wrap navigation, semantic action routing, selection/confirmation/cancellation signals, and close behavior.
- Added menu rendering to ScreenText and the WorldScreen forwarding API. Selected rows use a cyan marker; disabled rows are dimmed.
- Added `m3_screen_menu_test.gd`, registered `screen-menu` in the runner, and documented the menu contract and future input integration boundary.
- Changed: `fowl-play/ui/screen_menu.gd`, `fowl-play/ui/screen_text.gd`, `fowl-play/environment/kit/world_screen.gd`, `fowl-play/tests/m3_screen_menu_test.gd`, `fowl-play/tests/run_checks.ps1`, `docs/WORLD_SCREENS_AND_SCREEN_TEXT.md`, `docs/PROJECT_STATE.md`, `docs/DEBUG.md`, and this session file.
- No scenes or global InputMap actions changed. Actual keyboard/gamepad/physical USE routing and Godot/rendered verification remain for Registration Terminal integration.


### Session 10 — 2026-11-20 — GPT-6
- Added the RegistrationTerminal local controller: nickname editing, ten-color selection, registration submission, success display, arrow-key navigation, Enter/Escape handling, physical USE/M1 confirmation. Players remain free to move; the local session resets when they exceed the configurable horizontal proximity cutoff (default 3 m).
- Added a presentation-only local interaction-request signal to Interactable and emitted it from Focus after submitting the existing Network interaction request. Host validation and the authoritative Interactable.interacted path remain intact.
- Added the focused registration-terminal test stage and a dedicated editor/setup guide; updated project state and debug documentation.
- No scenes, meshes, collision shapes, or InputMap entries were changed. Editor wiring, Godot execution, and two-instance verification remain pending.


### Session 11 — 2026-11-20 — GPT-6
- Removed the registration terminal movement lock. Players can move freely, and the local session closes with a warning after exceeding the configurable horizontal proximity threshold (default 3 m). A registration request already submitted to the host is allowed to finish because it cannot be recalled locally.
- Exposed WorldScreen.content_padding_ratio (default 0.70) as a screen-level inner safe margin that scales with font size.
- Corrected FAT responsive detail layout: generated corner armor no longer receives a second parent/child offset, and both five-vent banks scale vertical spacing and vent height with display height.
- M1 was already supported by Focus/Interactable: primary maps to use, and the terminal treats that local interaction as confirmation of the highlighted option. Direct clicking of individual screen text rows remains a separate future feature.
- Added focused checks for proximity reset and responsive FAT vent scaling. Updated Registration Terminal, WorldScreen, debug, and project-state documentation.
- No scenes were edited. Godot execution and rendered/multiplayer verification have not been run by the assistant.


### Session 12 — 2026-11-20 — GPT-6
- Added direct mouse selection for rendered WorldScreen menu rows. RegistrationTerminal projects the local camera ray onto the 3D screen plane, converts the hit into SubViewport pixels, and resolves the clicked rendered option line. Clicking an option selects and confirms it in one click; clicks outside option rows are ignored.
- Registration opens the mouse cursor and restores its previous mode when the session closes or completes/rejects. Arrow-key navigation, Enter, and physical USE/M1 confirmation remain intact.
- Added ScreenText row hit testing and focused test coverage for row lookup and cursor-mode restoration. Updated registration, screen, debug, project-state, and session documentation.
- No scenes or InputMap actions changed. Godot execution and in-world mouse click verification remain pending.
