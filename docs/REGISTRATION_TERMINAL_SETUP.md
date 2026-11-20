# Registration Terminal Setup Guide

The Registration Terminal uses the reusable `InteractiveTerminal` lifecycle and the shared `WorldScreen` / `ScreenMenu` presentation system. The terminal wakes from local-player proximity, but it does not begin registration until the player explicitly uses the screen.

## Runtime behavior

1. The terminal starts asleep with a blank display.
2. A local player entering its proximity sensor wakes the screen and displays its idle prompt.
3. Pressing **E** or **M1** while focused on the screen begins the registration session. Proximity alone never opens the menu.
4. The mouse cursor becomes visible while the menu is active. Left-clicking a rendered option selects and confirms it, while the local right hand performs its existing poke animation toward the clicked screen position.
5. Arrow Up/Down and Enter navigate and confirm. Escape closes the session.
6. Player movement is locked only while the nickname editor is open. Enter confirms the nickname and restores movement; Escape cancels editing and also restores movement.
7. The session ends when the player moves beyond the interaction distance or leaves the sensor; ending the session always releases any nickname-edit movement lock.
8. Registration requests are still validated and assigned by the host through the existing Network identity API.

## Editing terminal wording in the Inspector

Select the **RegistrationTerminal** root in the scene tree and expand its **Registration Copy** export group. You can customize the main menu title and description format, option labels, prompts, color menu wording, nickname editor wording, connection/network feedback, and registration success/failure messages.

- The main menu description format uses two `%s` placeholders: requested nickname, then selected color name.
- The nickname editor instruction format uses one `%d` placeholder for the maximum nickname length.
- The success body format uses two `%s` placeholders: assigned display name, then assigned color.
- Idle/wake wording is separate: edit **Idle Header**, **Idle Description**, and **Idle Prompt** on the inherited InteractiveTerminal properties.
- These are presentation-only settings; identity validation, palette assignment, network authority, and menu behavior are unchanged.

## Required scene structure

Preserve the existing authored terminal root and its FAT/SLIM housing. Do not rebuild the screen or housing.

Add the proximity sensor as a child of the terminal root:

```text
RegistrationTerminal (Node3D) [registration_terminal.gd]
├── ScreenHousing (FAT or SLIM, existing authored scene)
│   └── WorldScreen
├── ScreenInteractable (Node) [interactable.gd]
└── ProximityArea (Area3D)
    └── CollisionShape3D
```

- Attach `registration_terminal.gd` to the existing terminal root. It now inherits from `InteractiveTerminal`.
- Assign the nested `WorldScreen` to the inherited **Screen** export.
- Assign `ScreenInteractable` to the inherited **Screen Interactable** export.
- Assign `ProximityArea` to the inherited **Proximity Area** export.
- The screen's physical interaction target must be the parent object of `ScreenInteractable` (the object Focus raycasts). Use the existing authored screen collision/body; do not create a parallel interaction path.
- Set the sensor CollisionShape3D to cover the exported **Wake Distance** (default 5 m). The **Interaction Distance** default is 3 m and is checked at runtime.
- The screen Interactable must be configured as USE or BOTH.
- The old physical USE button reference is no longer required. Keep the button only if it is useful as optional world hardware; it is not connected to registration.

The `InteractiveTerminal` proximity sensor tracks bodies whose `is_local_player` property is true. Keep the sensor's collision mask/layers configured to detect the local player body.

## Controls

| Input | Behavior |
|---|---|
| E / M1 while focused on screen | Begin registration, or confirm the highlighted row while a session is active |
| Arrow Up / Down | Move selection |
| Enter | Confirm selection |
| Escape | Close registration / cancel nickname editing |
| Backspace | Erase nickname characters |
| Printable keys | Type nickname, up to 16 characters |
| Left mouse click | Select and confirm a rendered option row |

## Verification

Run:

```powershell
godot --headless --path fowl-play --script res://tests/m3_interactive_terminal_test.gd
godot --headless --path fowl-play --script res://tests/m3_registration_terminal_test.gd
```

Then verify in the editor/game:
- The terminal is blank while no local player is nearby.
- Entering the sensor shows the idle prompt, but does not open the menu.
- E/M1 focused on the screen opens registration.
- Mouse, arrow-key, Enter, nickname, and color interactions work.
- Entering nickname editing prevents walking and jumping while preserving mouse look; Enter or Escape restores movement.
- Closing the session or leaving range always releases the movement lock.
- Moving beyond 3 m closes the session and displays a warning while still in the wake sensor.
- Leaving the sensor sleeps the display.
- Host and client both receive the host-assigned nickname/color identity.

No scene file is generated by these scripts; the terminal root, sensor, collision shape, and screen interaction target remain editor-authored.


## Mouse interaction presentation

Clicking a valid rendered menu option calls the local player's existing `Hand.begin_action()` at the ray-plane hit position and immediately reports the local presentation result with `finish_action(true)`. This mirrors the hand poke used by Focus-driven interactions without routing UI clicks through a second interaction or networking system. Clicks outside an enabled option row do not trigger the poke.
