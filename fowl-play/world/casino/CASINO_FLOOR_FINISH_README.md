# Casino Floor Finishes

Adds the Apartment's warm limestone tile finish to the Casino gaming area and warm walnut plank finish to the bar area.

## Safety and scope

- This is a **separate decorative builder**. It does not edit `casino_floor_builder.gd`, `FloorDetails`, the Casino scene, or any foundation geometry.
- Do not attach this script to `FloorDetails`. Keep the existing `FloorDetails` node and its generated content untouched.
- All generated surfaces are decorative MeshInstance3D nodes with **no collision**. Existing Casino floor collision remains responsible for player and prop support.
- The gaming finish follows the existing Casino floor footprint and leaves a clearance around the House medallion.
- The builder assumes the Casino's current floor coordinates: gaming/bar boundary X=1.5, floor Z=-28.665 to -1.665, gaming surface top Y=0.15, bar surface top Y=0.0.

## Installation

1. Open `casino.tscn` in Godot. Do not delete, rename, reparent, or edit `FloorDetails`.
2. Under the existing `Architecture` node, create a new **Node3D** sibling of `FloorDetails`.
3. Name the new node `FloorFinish`.
4. Keep its position and rotation at `(0, 0, 0)` and scale at `(1, 1, 1)`.
5. Attach `res://world/casino/casino_floor_finish_builder.gd`.
6. Let the editor generate the surfaces, then save `casino.tscn`.

Suggested structure:

```text
Casino
└── Architecture
    ├── FloorDetails       # Existing. Leave untouched.
    └── FloorFinish        # New. Attach CasinoFloorFinishBuilder here.
```

## Generated appearance

- **Gaming area:** warm greige limestone-look rectangular tiles, 1.2 m × 0.6 m by default, staggered running-bond layout, subtle tile-to-tile variation, narrow dark joints.
- **Bar area:** warm walnut planks, 2.4 m × 0.22 m by default, staggered end joints and narrow dark seams.
- The existing House medallion remains visible because tiles are omitted within the configured clearance radius.

## Inspector controls

- `Generate Gaming Stone` and `Generate Bar Walnut` independently enable either section.
- Stone and walnut colors, variation, tile/plank dimensions, grout/joint widths, and floor heights are exposed.
- `Bar Min X` controls the boundary between gaming and bar finishes. Default: `1.5`.
- `Preserve Medallion Clearance` and `Medallion Clearance Radius` protect the existing floor medallion.
- Toggle `Rebuild Floor` to regenerate after changing settings. This replaces only `_GeneratedCasinoFloorFinish` beneath the new `FloorFinish` node.

## Validation

The script has been committed but has not been parsed or visually tested in the Godot editor in this environment. Inspect the diagonal gaming-area edge and the bar transition after generation. If the existing casino floor layout has changed, adjust the exposed boundary and height values rather than modifying `FloorDetails`.
