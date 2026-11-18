# M2 hand design proposal — Fowl Play

Status: PROPOSED visual direction, 2026-11-16. Existing contracts in [PROJECT_OVERVIEW.md §16](PROJECT_OVERVIEW.md#16-hands) remain authoritative. Dimensions and pose timings below are starting points for editor playtesting, not permanent decisions.

## Direction

Latest user checkpoint: the authored study thumb is verified in both pointing and guard, and pointing's folded fingers now use full guard-equivalent curl. User requested moving away from hand work for now. Keep these poses; remaining model polish and M2 integration are deferred, not complete.

Chunky cartoon mascot hands: broad knuckles, a narrow wrist, short substantial fingers, an outward thumb, and a readable fist. Think soft molded rubber with simple faceted surfaces. They should look capable of poking a button, fumbling a prop, and throwing an exaggerated punch. Keep four fingers plus a thumb, as specified; avoid feathers/claws obscuring the pointing silhouette.

Use the player's color over the whole hand, with a darker wrist/cuff value for orientation. No nails, tiny creases, reflective metal, glow, or transparent finger surfaces. A short flared cuff can suggest a casino mascot costume without putting lettering or decorative props into the view.

The relaxed hand must already look alive: a little curl, slight finger spread, thumb away from the palm. Do not start from a perfectly flat five-pronged fork.

## Proportions (authoring units)

Build at this convenient local size, then apply the approximately 0.3 viewmodel scale on a parent rig. World scale is tuned separately against the player capsule; these are not assumed real-world metres.

| Part | Starting dimensions / placement |
|---|---|
| Palm | 0.42 wide × 0.14 thick × 0.40 long; user chose the slimmer 0.14 thickness during blockout |
| Wrist | About 0.26 wide; soft transition into the palm |
| Middle finger | Length 0.36, width about 0.09, thickness about 0.09 |
| Index | 0.92 × middle length |
| Ring | 0.94 × middle length |
| Little | 0.72 × middle length, slightly narrower |
| Finger segments | Length fractions 0.47 / 0.29 / 0.24 |
| Thumb | Revised blockout: about 0.29 total length, root Y rotation 45 degrees; user preferred the longer silhouette. Segment mesh lengths 0.18/0.135, second joint Z=-0.16 |
| Cuff | About 0.31 wide; restrained flare, not a large bracelet |

Use overlapping rounded/faceted segments so bending does not reveal black gaps. Avoid visible spherical knuckles that make the hand read as a robot. Start with simple editor-authored primitives; refine the tapered palm silhouette in the editor after articulation works. Do not add a modeling pipeline or generate geometry in scripts.

## Coordinate and rig convention

Proposed local convention: fingers extend along -Z; palm thickness is Y; finger spread is X; palm side faces -Y. Curl around local X toward the palm (negative X rotation with this convention). Keep joint nodes at rotation pivots; offset meshes, not the pivots, to the centres of their segments.

The existing finger scene needs a serial joint chain:

```text
Finger
└── Joint1
    ├── Segment1
    └── Joint2
        ├── Segment2
        └── Joint3
            └── Segment3
```

For a 0.36-long middle finger, segment lengths are approximately 0.169 / 0.104 / 0.086. Segment1 centre sits at Z=-0.0845 relative to Joint1; Joint2 sits at Z=-0.169 relative to Joint1. Segment2 centre sits at Z=-0.052 relative to Joint2; Joint3 sits at Z=-0.104 relative to Joint2. Segment3 centre sits at Z=-0.043 relative to Joint3. Give segments a little visual overlap without changing those joint spacings.

Proposed hand hierarchy (names below the hand root are a design proposal, not yet a saved scene):

```text
Hand                  [existing Hand script]
└── PoseRoot           [whole-hand animation offset]
    ├── Forearm
    ├── Cuff
    ├── Palm
    ├── IndexAim       [aim pivot at index knuckle]
    │   └── Index      [finger scene instance]
    ├── Middle         [finger scene instance]
    ├── Ring           [finger scene instance]
    ├── Little         [finger scene instance]
    └── ThumbRoot      [dedicated thumb articulation]
```

Set Hand's exported aim path to PoseRoot/IndexAim and pose-root path to PoseRoot. IndexAim rotates around the index knuckle, not the palm centre. Keep the hand root as the stable attachment transform. Start with one right hand, then author the left with thumb placement/spread mirrored; avoid relying on negative scale for the full rig.

## Materials and readability

Latest editor follow-up: user chose to stay in Godot and adjusted the tapered CSG palm to depth 0.11, centered at Y=-0.055, with a custom outline. The older 0.14 value describes the original blockout. Finger curl -75/-85/-45 degrees produced a usable fist silhouette in screenshots; thumb closure is still pending. Finger-pose blending now exists in the controller and has scene-backed headless checks, but in-game appearance remains unverified.

Editor progress: user approved capsule finger lengths 0.22/0.17/0.14 and thumb lengths 0.21/0.16 after increasing overlap. Saved radii are 0.048/0.045/0.04 (fingers) and 0.053/0.048 (thumb). Joint spacing is unchanged. Palm/wrist/cuff/forearm remain blockout boxes; final taper and whole-hand fist fit are still pending.

- Opaque StandardMaterial3D, metallic 0, roughness approximately 0.75–0.85, normal depth testing.
- Same player hue throughout, darker cuff, simple lighting and restrained highlights. No transparency overlay for the final rubber appearance.
- Current set_color uses a translucent overlay on all geometry: replace/refine this only during the material implementation slice, preserving per-instance materials and the existing API. Do not silently treat the current tint as final art.
- Check against dark and bright backgrounds and from first-person plus a few metres away. Pose silhouette must carry meaning without depending solely on color.

## Poses and motion

| State | Visual target |
|---|---|
| Idle | Relaxed half-open hand, slight asymmetry; hands low enough to leave the centre clear |
| Hover | Index straightens toward target; remaining fingers curl; thumb stays readable |
| Reach/poke | Short deliberate extension and softer return; index leads, hand moves toward centre |
| Guard | Broad fists rise beside view, thumb outside folded fingers; centre remains visible |
| Carry hook | Open C-shaped grip around the future item; no full M6 carrying implementation |
| Limp hook | Loose fingers and lowered wrist; no active pointing/guard pose |

Suggested initial transitions: pointing 0.12–0.18 seconds, guard raise around 0.16 seconds, reach extension around 0.10 seconds and return around 0.18 seconds. Tune visually; avoid finger snapping. Only the intended dominant pose should control joints at a time. Camera sway must be bounded and return to rest, not accumulate rotations forever. Bob should be subtle enough to keep the fingertip readable; test stationary first.

## Build order and acceptance

1. Repair and size one finger in the editor; rotating Joint1 must move the entire chain, Joint2 the last two segments, and Joint3 only the tip.
2. Build one right-hand silhouette and check idle, point, and fist poses manually before writing animation.
3. Implement visible pose transitions through the existing API; keep geometry editor-owned. Current API tests are state tests, not proof of animated hands.
4. Place first-person and world instances, author the left hand, then test clipping, scale, silhouette, tint independence, and debug cleanup.
5. Retain no-depth-test workarounds as forbidden. Hand networking belongs to M3; combat effects and carrying mechanics remain later milestones.

Success: the user can immediately distinguish relaxed, pointing, and guarding silhouettes; all fingers bend around correct pivots; the centre of the view stays usable; and no transparent rings or disjointed segments appear.
