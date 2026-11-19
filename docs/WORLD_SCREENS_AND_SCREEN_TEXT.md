# World Screens & Screen Text Guide

This guide is the practical reference for creating, configuring, and using reusable in-world screens in Fowl Play. It covers the shared display component, its text renderer, the FAT/SLIM physical housings, dynamic content APIs, rendering settings, and verification.

## 1. System overview

The screen system is deliberately split into two layers:

1. **WorldScreen** owns the reusable display surface, viewport resolution, responsive font sizing, transparent text overlay, HDR emission, and LED-pixel shader settings.
2. **FAT / SLIM housing scenes** provide the physical hardware around that display. Their controllers resize authored chassis details and glass around the shared WorldScreen.

**ScreenText** owns the actual text content and typography. It is a `RichTextLabel` subclass, not a physical 3D label. It renders inside a `SubViewport`, whose texture is displayed on the 3D screen.

This separation means one content API can serve a FAT tabletop monitor, a SLIM wall terminal, or a future custom housing.

## 2. Scene structure

### Shared WorldScreen scene

The reusable scene is `res://environment/kit/world_screen.tscn`. Its expected structure is:

```text
WorldScreen (Node3D) [world_screen.gd]
├── Display (MeshInstance3D)
├── TextDisplay (MeshInstance3D)
└── SubViewport (SubViewport)
    └── ScreenText (RichTextLabel) [screen_text.gd]
```

- **Display** is the opaque physical screen plane and supplies the dark backing.
- **TextDisplay** is a separate, slightly offset transparent plane. It displays only the text viewport and routes that texture through emission.
- **SubViewport** renders the 2D text at a resolution appropriate to the physical display dimensions.
- **ScreenText** is the content and typography controller.

Keep `TextDisplay` separate from `Display`. Combining the text emission with the opaque backing can make the entire panel bloom; the separate transparent overlay isolates glow to the letters.

### FAT and SLIM housing scenes

Each housing root uses direct children with these exact names:

```text
FatWorldScreen (Node3D) [fat_world_screen.gd]
├── WorldScreen
├── Chassis
└── Glass
```

```text
SlimWorldScreen (Node3D) [slim_world_screen.gd]
├── WorldScreen
├── Chassis
└── Glass
```

The controllers expect those three direct-child paths. Preserve the names and hierarchy. The detailed contents beneath `Chassis` are housing-specific and are authored in the Godot editor; consult the relevant controller and its scene for the current named detail groups.

The housing controller does not replace the scene or create the authored model from scratch. It resizes/repositions known authored parts from the exported `WorldScreen.display_size` and keeps the glass aligned.

## 3. Creating a new screen instance

1. Instance `world_screen.tscn` directly if you only need a plain screen, or instance `fat_world_screen.tscn` / `slim_world_screen.tscn` for a physical housing.
2. For a housing, retain the direct children `WorldScreen`, `Chassis`, and `Glass`.
3. Confirm the matching controller script is attached to the housing root: `fat_world_screen.gd` for FAT or `slim_world_screen.gd` for SLIM.
4. Select the child `WorldScreen` and configure its `display_size` and text/rendering exports.
5. Position and rotate the complete housing root in the world. Do not use root scaling as the normal resizing method.

**Important:** the controller resizes the display by changing `display_size`, not by scaling the root Node3D. This keeps the screen dimensions, viewport resolution, font size, chassis details, and glass calculations coordinated.

## 4. WorldScreen configuration

Script: `fowl-play/environment/kit/world_screen.gd`

### Display Size

| Export | Purpose | Current default |
|---|---|---:|
| `display_size` | Physical width and height in 3D units | `(2.0, 1.125)` |
| `pixels_per_unit` | Target viewport density | `1024` |
| `max_viewport_dimension` | Maximum width or height of the viewport | `4096` |

Set `display_size` to the desired aspect ratio and physical dimensions. For example, `Vector2(3.0, 1.6875)` keeps the same 16:9 ratio as the default while making the display 1.5 times larger.

The viewport dimensions are calculated from physical size multiplied by pixels-per-unit, then uniformly reduced if either dimension would exceed the configured maximum. Each dimension has a minimum of 256 pixels.

### Text Scaling

| Export | Purpose | Current default |
|---|---|---:|
| `auto_scale_font_size` | Automatically size the text from viewport height | `true` |
| `font_size_ratio` | Proportion of viewport height used for font size | `0.0764` |
| `text_scale` | Additional per-screen multiplier | `1.0` |

The font calculation is approximately:

```gdscript
font_size = round(viewport_height * font_size_ratio * text_scale)
```

The result is clamped to 8–512 pixels. At the default 1152-pixel viewport height, the default ratio produces an 88-pixel font. Use `text_scale` for a local adjustment without changing the global ratio.

If `auto_scale_font_size` is disabled, set `ScreenText.terminal_font_size` manually.

### Text Glow

| Export | Purpose | Current default |
|---|---|---:|
| `text_glow_enabled` | Enables the HDR boost on text | `true` |
| `text_glow_boost` | HDR emission boost | `2.2` |

The text is rendered in an HDR-enabled SubViewport. The transparent TextDisplay material uses that viewport texture as both albedo and emission. The WorldScreen script boosts the text shader output; the containing scene's `WorldEnvironment` must also have Glow enabled for visible bloom.

Glow is a two-part setup:
- WorldScreen controls the text overlay's emission strength.
- WorldEnvironment controls the final bloom response for the 3D scene.

Tune both together. Increasing the screen's boost alone does not replace enabling Glow in the environment.

### LED Matrix

| Export | Purpose | Current default |
|---|---|---:|
| `led_matrix_enabled` | Applies the dot-matrix character treatment | `true` |
| `led_dot_size` | LED dot size | `3.0` |
| `led_gap` | Spacing between dots | `0.28` |
| `led_softness` | Softness of each dot edge | `0.08` |

The LED treatment is applied by `world_screen_text.gdshader` to the text overlay, not to the opaque panel. A useful starting point for the project's current terminal look is the Classic LED range: dot size 4, gap 0.25, softness 0.06. Finer or softer results can be tuned per screen.

## 5. ScreenText configuration

Script: `fowl-play/ui/screen_text.gd`

`ScreenText` extends `RichTextLabel`. The shared scene currently uses `JetBrainsMonoNL-Regular.ttf` and a terminal font size of 88 at the default viewport size.

| Export / property | Purpose | Current default |
|---|---|---|
| `terminal_font` | Font resource used for all text styles | Scene assigns JetBrains Mono NL |
| `terminal_font_size` | Font size in viewport pixels | `22` script default; WorldScreen auto-sizes it to `88` in the shared scene |
| `content_padding_ratio` | Text inset relative to font size | `0.45` |
| `background_color` | Backing ColorRect color, when present | Near-black blue |
| `header_color` | Default header color | Gold |
| `body_color` | Default paragraph color | Bright white |
| `prompt_color` | Default prompt color | Gold |

The shared scene's ScreenText is configured for left alignment, top alignment, left-to-right direction, word wrapping, and scrolling. Keep the ScreenText background transparent: the opaque Display plane owns the panel backing, while TextDisplay owns text emission.

## 6. Writing content from scripts

You can call the API on either the `WorldScreen` node or its `ScreenText` child. Prefer calling the WorldScreen wrapper from gameplay or terminal logic; it keeps callers independent of the SubViewport's internal node path.

### Append content

```gdscript
@onready var screen: WorldScreen = $WorldScreen

func show_status() -> void:
    screen.clear_screen()
    screen.append_header("SYSTEM STATUS")
    screen.append_paragraph("All systems operational.")
    screen.append_prompt("PRESS USE TO CONTINUE")
```

Available methods:
- `append_header(value: String)` — appends a bold line using the configured header color.
- `append_paragraph(value: String)` — appends a body line.
- `append_prompt(value: String)` — appends a prompt line.
- `clear_screen()` — clears all current text.

Appending does not replace earlier text. Call `clear_screen()` first when you want a fresh display.

### Replace the complete display

```gdscript
screen.set_content(
    "REGISTRATION SYSTEM",
    "Welcome to Fowl Play.\nChoose your identity to continue.",
    "PRESS USE"
)
```

`set_content(header, body, prompt = "")` clears the old display, then writes the supplied header, body, and optional prompt using the configured standard colors. The body can contain newline characters.

### Use a presentation preset

```gdscript
screen.show_layout(
    ScreenText.LAYOUT_WARNING,
    "IDENTITY UNAVAILABLE",
    "That color is already assigned.",
    "SELECT ANOTHER COLOR"
)
```

Available constants:

| Constant | String value | Intended use |
|---|---|---|
| `LAYOUT_STANDARD` | `standard` | Configured default colors |
| `LAYOUT_WELCOME` | `welcome` | Welcome / onboarding message |
| `LAYOUT_INFORMATION` | `information` | Informational message |
| `LAYOUT_WARNING` | `warning` | Warning / attention message |
| `LAYOUT_SUCCESS` | `success` | Successful completion |
| `LAYOUT_CONFIRMATION` | `confirmation` | Confirmation or next-step prompt |

`show_layout(layout, header, body, prompt = "")` replaces the display just like `set_content`, but selects per-call colors for the chosen preset. It does not change the exported default colors or any font, geometry, alignment, glow, or LED settings. An unknown layout warns and falls back to standard colors.

The constants are declared on `ScreenText`; use `ScreenText.LAYOUT_SUCCESS`, etc. when calling through a WorldScreen.

## 7. Multiple instances and resource isolation

Multiple WorldScreen instances are intended to be independently configurable. The controller duplicates mutable mesh and material resources for each instance before changing them. The FAT/SLIM controllers also localize their chassis/glass resources before applying their responsive layout.

Practical rules:
- Change the `display_size` on the intended instance's WorldScreen child.
- Use that instance's `set_content` / `show_layout` methods to change only its own text.
- Do not edit a shared source material expecting every placed instance to change together; per-instance copies are intentional.
- If a new mutable resource is added to the controller, consider whether it must be duplicated per instance too.

## 8. Visual troubleshooting

| Symptom | Check |
|---|---|
| Entire panel blooms | Confirm Display is the opaque backing and TextDisplay is a separate transparent overlay. Check that the overlay is the only material receiving the text viewport emission. |
| Text is crisp but has no bloom | Check SubViewport HDR, TextDisplay emission, and Glow in the containing WorldEnvironment. |
| Text looks too large / too small | Check `auto_scale_font_size`, `font_size_ratio`, `text_scale`, and viewport height. |
| Text looks soft / pixelated | Check viewport resolution, `pixels_per_unit`, max dimension, and the font resource. |
| Text is clipped | Check content padding, font size, line count, and whether the body is longer than the available display area. |
| LED dots look too coarse | Reduce dot size and/or gap; adjust softness gently. |
| LED effect is absent | Check `led_matrix_enabled` and the text shader on ScreenText. |
| Housing details float or detach after resizing | Check that the correct FAT/SLIM controller is attached, exact child names are preserved, and resizing is done through `WorldScreen.display_size`. Inspect authored offsets in the editor before changing controller math. |
| Changing one screen changes another | Check that the current controller localizes mutable meshes/materials; add a regression assertion when introducing new mutable resources. |

Do not fix a visual problem by blindly scaling the housing root. First inspect the relevant display size, controller, authored transforms, and viewport settings.

## 9. Tests and verification

Focused tests:
- `fowl-play/tests/m3_screen_text_test.gd`
- `fowl-play/tests/m3_world_screen_test.gd`
- `fowl-play/tests/m3_fat_world_screen_test.gd`
- `fowl-play/tests/m3_slim_world_screen_test.gd`

Run the full project checks from PowerShell:

```powershell
.owl-play\tests\run_checks.ps1
```

Or run an individual screen test from the project root with Godot 4:

```powershell
godot --headless --path fowl-play --script res://tests/m3_screen_text_test.gd
godot --headless --path fowl-play --script res://tests/m3_world_screen_test.gd
godot --headless --path fowl-play --script res://tests/m3_fat_world_screen_test.gd
godot --headless --path fowl-play --script res://tests/m3_slim_world_screen_test.gd
```

The focused tests check the text API, preset forwarding, responsive viewport/font sizing, overlay configuration, and instance isolation. They do not replace visual inspection in the running game.

Rendered verification checklist:
- [ ] Text appears on the physical screen and is left-aligned.
- [ ] Only the text blooms; the opaque panel does not.
- [ ] LED pixels remain readable at the intended viewing distance.
- [ ] Text stays legible at the smallest and largest intended display sizes.
- [ ] FAT and SLIM chassis details remain attached while resizing.
- [ ] Changing one placed screen does not resize or recolor another.
- [ ] Host/client instances show the same intended content when gameplay/network logic updates both.

**Verification status:** this guide documents the current code contract. It does not claim that the listed Godot tests or every rendered configuration have been run.

## 10. Extension rules

When extending the system:

1. Keep content and physical housing separate.
2. Add content-facing convenience methods to WorldScreen and forward them to ScreenText.
3. Keep typography, line styling, and content replacement behavior inside ScreenText.
4. Keep physical size, viewport resolution, text scale, LED, and emission behavior inside WorldScreen.
5. Keep FAT/SLIM physical layout behavior inside their respective housing controllers.
6. Add focused tests for every new public API and for multiple-instance isolation where mutable resources are involved.
7. Update this guide, `docs/DEBUG.md`, `docs/PROJECT_STATE.md`, and the active session notes whenever the implementation contract changes.
8. Do not modify user-authored scene hierarchies or meshes without confirming the scene is closed and the user has explicitly handed off that work.


## 11. Interactive menu foundation

The reusable menu model is `res://ui/screen_menu.gd` (`ScreenMenu`). It is input-independent: it does not capture keyboard/gamepad input, depend on a player, or know whether a display is FAT or SLIM. An active terminal/input owner forwards semantic actions to it.

Each option is a Dictionary with a unique non-empty `id`, a non-empty `label`, and optional `enabled` (defaults to true). Disabled options remain visible but are skipped.

```gdscript
const ScreenMenuScript = preload("res://ui/screen_menu.gd")
var menu: ScreenMenu = ScreenMenuScript.new()

func open_menu(screen: WorldScreen) -> void:
    menu.option_confirmed.connect(_on_option_confirmed)
    menu.open(screen, "MAIN MENU", "Choose an operation.", [
        {"id": &"register", "label": "REGISTER"},
        {"id": &"settings", "label": "SETTINGS"},
        {"id": &"leave", "label": "LEAVE SESSION", "enabled": false}
    ])

func _on_option_confirmed(option_id: StringName, _label: String) -> void:
    if option_id == &"register":
        # Transition to the registration page.
        pass
```

Public API: `open(screen, header, description, options, prompt)`, `move_selection(direction)` (positive down, negative up), `select_index(index)`, `confirm()`, `cancel()`, `close()`, `handle_action(action)`, `get_selected_index()`, `get_selected_option_id()`, and `get_options()`. Confirmation emits `option_confirmed(id, label)` and intentionally leaves the menu open so the owner can choose the next page. Cancellation emits `cancelled`, then closes and clears the display.

Semantic actions: `ACTION_UP` (`menu_up`), `ACTION_DOWN` (`menu_down`), `ACTION_CONFIRM` (`menu_confirm`), and `ACTION_CANCEL` (`menu_cancel`). Navigation wraps by default; set `menu.wrap_navigation = false` to stop at the ends. Signals: `opened`, `selection_changed(index, id)`, `option_confirmed(id, label)`, `cancelled`, and `closed`.

Rendering is handled by `WorldScreen.show_menu` and `ScreenText.show_menu`. The selected row uses a cyan `> ` marker, disabled rows are subdued gray, and existing terminal typography/LED/glow remain active.

This first foundation deliberately adds no global InputMap actions and captures no input. That prevents inactive screens from stealing movement or interaction controls. Registration Terminal integration will route keyboard/gamepad and physical USE actions only while the local player is actively controlling the terminal.

Focused test: `fowl-play/tests/m3_screen_menu_test.gd`; runner stage: `screen-menu`. It covers validation, rendering, disabled-option skipping, wrap behavior, semantic routing, confirmation, and cancellation. Actual input-device and in-world verification remain a later integration task.
