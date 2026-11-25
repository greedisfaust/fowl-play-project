# Casino Night Environment

The production Casino scene uses a dedicated nighttime environment preset and a local exterior dressing node.

## Scene integration

- `casino_night_environment.tres` is assigned to the Casino `WorldEnvironment`.
- `casino_night_sky.tres` supplies a dark procedural midnight sky.
- `casino_night_exterior.gd` creates the visible moon, dense distant skyline, emissive building windows, and exterior rain at runtime.
- `casino_lighting_builder.gd` retains the existing warm gaming/bar practicals and adds low-energy cyan/magenta accent pools.

## Coordinate assumptions

The Casino panoramic glazing faces toward negative Z. The skyline is placed around Z = -66, the visible moon around Z = -78, and rain is emitted between the glazing and skyline (center Z = -42). The rain volume is deliberately kept outside the glass.

All exterior dressing is local visual presentation. It is not network synchronized and does not affect gameplay collision or interaction.

## Visual direction

- Midnight navy sky and cool blue ambient fill.
- Visible emissive moon.
- Dense layered building silhouettes with warm, cyan and pink emissive windows.
- Visible falling rain outside the panoramic glazing.
- Restrained environment glow and distance fog.
- Existing warm casino practical lights remain the interior foundation, complemented by balanced cyan/magenta local accents.

## Tuning

The exterior builder exposes moon position/size, building count, window density, rain amount, fall speed and opacity in the Inspector. The environment preset exposes tone mapping, ambient contribution, SSAO/SSIL, glow and fog settings.

## Validation notes

This is the first environment implementation pass. Verify the scene in Godot 4.7 Forward+ and tune composition, exposure, rain visibility and effect cost against the actual player camera. In particular, check that the skyline and moon are visible from the playable casino floor and that the rain remains outside the window façade.
