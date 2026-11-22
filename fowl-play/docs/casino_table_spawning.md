# Casino Table Spawn System

## Purpose

The casino table spawn system provides editor-visible placement footprints and a reusable scene spawner. It does not modify the casino floor, floor-detail builder, or existing environment geometry.

## Scene setup

Under `Casino/Architecture`, create this hierarchy:

```text
Architecture
└── TableSpawners (Node3D) [casino_table_spawner.gd]
    ├── SpawnPoints (Node3D)
    │   ├── TableSlot_A (Marker3D) [casino_table_spawn_point.gd]
    │   ├── TableSlot_B (Marker3D) [casino_table_spawn_point.gd]
    │   └── ...
    └── SpawnedTables (Node3D)
```

Attach `casino_table_spawner.gd` to `TableSpawners`. Attach `casino_table_spawn_point.gd` to each Marker3D under SpawnPoints. Do not attach either script to FloorDetails.

## Spawn point configuration

Each Marker3D exposes:
- `table_id`: unique stable ID for this physical table location, e.g. `chicken_cross_01`.
- `game_id`: registered casino game ID expected by the table scene, e.g. `chicken_cross`.
- `table_scene`: optional PackedScene. Leave empty while the table scene is not ready; the editor footprint still marks the future location.
- `enabled`: whether the slot is eligible for spawning.
- `footprint_size`: preview width/depth in metres. Default is 3.2 x 2.4.
- `show_indicator`: toggles the editor footprint.

The footprint is centered on the Marker3D origin. Rotate the Marker3D to control the future table's facing direction. Move the Marker3D to position the footprint. The indicator is editor-only and is hidden in game.

## Spawner behavior

When the casino scene loads, the spawner instantiates every enabled slot with a non-null table scene and non-empty table/game IDs. Instances are parented under SpawnedTables and receive the marker's global transform.

The spawner sets `casino_table_id` and `casino_game_id` metadata on every spawned root. If the instantiated root is a `BaseTable`, it also assigns its `table_id` and `game_id` before adding it to the scene tree.

The casino scene is loaded locally by each peer, so each peer creates the same static world table instances locally. This is not a network spawn event. Gameplay remains host-authoritative through `BaseTable`; do not use this local spawner for runtime-created network entities.

Calling `spawn_tables()` again does not duplicate a table ID already spawned by this spawner.

## Placement workflow

1. Add the TableSpawners hierarchy under Architecture.
2. Add one Marker3D per intended table location and attach the spawn-point script.
3. Set the footprint to roughly match the table's expected overall footprint, including enough clearance for players.
4. Move and rotate each marker in the 3D viewport until the arrangement looks right.
5. Leave table_scene empty until the corresponding table scene exists.
6. Later, assign the table PackedScene and fill in table_id/game_id.

The spawn-point footprint is only a planning indicator; it does not create collision or reserve floor space.

## Checks

Run `tests/run_casino_table_spawner_checks.bat` from Windows. The test covers enabled/disabled slots, instantiation, transform placement, metadata, and duplicate prevention.

## Verification

### Automated

Run `tests/run_casino_table_spawner_checks.bat`. It checks enabled and disabled slots, Node3D scene instantiation, marker transform placement, table metadata, and duplicate prevention. The spawner also exposes the DebugHub watch `casino/table_spawner/active_tables`.

### Two-instance multiplayer checklist

Once at least one table scene is assigned:

1. Start a host and join a client.
2. Enter the Casino on both instances.
3. Confirm each instance displays one table at every enabled configured slot, with matching position and facing.
4. Confirm no duplicate table appears after leaving and re-entering the Casino.
5. Have the host interact with a table and confirm the existing BaseTable host-authoritative behavior remains intact.
6. Confirm a disabled slot does not spawn on either instance.

The local table placement check does not replace a multiplayer gameplay test. Record visual placement and host/client gameplay results separately.
