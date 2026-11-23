# Casino Table Spawn System

## Purpose

The casino table spawn system provides editor-visible placement footprints for the six physical table locations and a reusable spawner that fills those locations with the six games selected by CasinoManager for the current day. It does not modify the casino floor, floor-detail builder, or existing environment geometry.

## Scene setup

Under `Casino/Architecture`, create this hierarchy:

```text
Architecture
└── TableSpawners (Node3D) [casino_table_spawner.gd]
    ├── SpawnPoints (Node3D)
    │   ├── TableSlot_01 (Marker3D) [casino_table_spawn_point.gd]
    │   ├── TableSlot_02 (Marker3D) [casino_table_spawn_point.gd]
    │   ├── TableSlot_03 (Marker3D) [casino_table_spawn_point.gd]
    │   ├── TableSlot_04 (Marker3D) [casino_table_spawn_point.gd]
    │   ├── TableSlot_05 (Marker3D) [casino_table_spawn_point.gd]
    │   └── TableSlot_06 (Marker3D) [casino_table_spawn_point.gd]
    └── SpawnedTables (Node3D)
```

Attach `casino_table_spawner.gd` to `TableSpawners`. Attach `casino_table_spawn_point.gd` to each Marker3D under SpawnPoints. Do not attach either script to FloorDetails.

## Spawn point configuration

Each Marker3D exposes:
- `slot_id`: unique stable ID for the physical location, e.g. `table_01`.
- `enabled`: whether the location participates in daily spawning.
- `footprint_size`: preview width/depth in metres. Default is 3.2 x 2.4.
- `show_indicator`: toggles the editor footprint.

Create six enabled slots to match CasinoManager's six-game daily selection. Keep the IDs unique. The spawner sorts enabled slots by `slot_id`, then assigns the selected games in CasinoManager's selection order. This makes the mapping deterministic across peers.

The footprint is centered on the Marker3D origin. Rotate the Marker3D to control the future table's facing direction. Move the Marker3D to position the footprint. Set its Y coordinate to the actual floor level at that location (gaming floor or bar floor). The indicator is editor-only and hidden in game.

You do not assign a game ID or table scene to a spawn point. Those are read from each selected `CasinoGameDefinition`, so physical locations are reusable when the daily selection changes.

## Spawner behavior

When the Casino scene loads, the spawner connects to `CasinoManager.daily_selection_changed` and checks the current selection. If the catalog or daily selection is not ready yet, it waits for the signal.

Once six game definitions are available, it requires the same number of enabled slots, then instantiates each definition's `table_scene` at its assigned slot. Instances are parented under SpawnedTables and receive the marker's global transform.

The spawner generates a day-scoped table ID and sets `casino_table_id` and `casino_game_id` metadata on every spawned root. If the instantiated root is a `BaseTable`, it also assigns its `table_id` and `game_id` before adding it to the scene tree.

The Casino scene is loaded locally by each peer, so each peer creates the same static world table instances locally from the replicated daily selection. This is not a network spawn event. Gameplay remains host-authoritative through `BaseTable`; do not use this local spawner for runtime-created network entities.

Calling the spawner again for the same day does not duplicate existing tables. The DebugHub watch `casino/table_spawner/active_tables` reports the number of spawned tables.

## Placement workflow

1. Add the TableSpawners hierarchy under Architecture.
2. Add six Marker3D children under SpawnPoints and attach the spawn-point script to each.
3. Give each marker a unique slot_id (table_01 through table_06).
4. Set each footprint to roughly match the expected table size, including player standing clearance.
5. Move and rotate each marker in the 3D viewport until the arrangement looks right.
6. Place each marker's origin on the appropriate floor surface. Do not move or edit FloorDetails to accommodate these markers.

The footprint is only a planning indicator; it does not create collision or reserve floor space. The actual table scenes will be supplied by the daily game definitions.

## Verification

### Automated

Run `tests/run_casino_table_spawner_checks.bat`. It checks daily game definitions, enabled and disabled slots, Node3D scene instantiation, marker transform placement, metadata, slot-count validation, and duplicate prevention.

### Two-instance multiplayer checklist

Once the game catalog has all twelve definitions:

1. Start a host and join a client.
2. Enter the Casino on both instances.
3. Confirm each instance displays six tables at the six configured slots, with matching positions and facing.
4. Confirm the game assigned to each slot is the same on host and client.
5. Confirm no duplicate table appears after leaving and re-entering the Casino.
6. Have the host interact with a table and confirm existing BaseTable host-authoritative behavior remains intact.

The local table placement check does not replace a multiplayer gameplay test. Record visual placement and host/client gameplay results separately.
