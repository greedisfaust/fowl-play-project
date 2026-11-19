# Registration Terminal

## Purpose

The Registration Terminal connects the reusable WorldScreen and ScreenMenu to the existing physical USE button and host-authoritative PlayerIdentity service. It does not create scene nodes, meshes, collision shapes, or InputMap actions.

## Editor setup

Create a controller Node3D under the editor-authored terminal root and attach res://ui/registration_terminal.gd.

Assign:
- screen: the terminal's WorldScreen controller.
- use_interactable: the physical USE button's Interactable node.

Assign that same Interactable node to the PhysicalUseButton script's interactable export. Assign its moving cap to cap as usual. Keep the screen and button geometry/hierarchy authored in the editor.

## Controls and flow

- Interact with the physical USE button to open the registration menu.
- Arrow Up/Down navigate; Enter or the physical USE button confirms.
- Escape closes the terminal.
- Nickname editing accepts printable keyboard characters, Backspace, Enter, and Escape; maximum length is 16.
- Select one of the ten palette colors, then confirm registration.
- The host remains authoritative for nickname normalization, duplicate suffixes, and color availability. The terminal displays the host-assigned identity after the roster update.

The local player is never movement-locked by the registration terminal. The screen/menu state is local to the requesting player's process; other players do not share that local menu state.

## Authority boundary

Focus emits Interactable.interaction_requested locally after submitting the existing Network interaction request. This signal exists only to open/control local presentation immediately. It is not an approval and must not be used for gameplay authority. Network still validates actor, range, target, and action, and the authoritative Interactable.interacted signal remains host-side. Physical button animation continues to use the existing host-approved presentation RPC.

## Verification

Run:
godot --headless --path fowl-play --script res://tests/m3_registration_terminal_test.gd

Then wire the editor-authored terminal and verify locally and with two instances: nickname entry, duplicate nickname suffixing, occupied-color fallback, host/client roster agreement, and movement lock/unlock. Automated checks do not replace rendered or multiplayer verification.
