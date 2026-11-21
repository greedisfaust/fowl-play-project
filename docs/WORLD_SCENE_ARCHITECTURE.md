# Main Scene and World Architecture

Status: W1 foundation — controller and scene contract added. The editor-authored Main scene and physical world scenes are intentionally not created by code.

## Why this exists

The current project main scene is `res://arena/test_arena.tscn`. That is a development/test arena, not the production application root. It currently owns its player container, MultiplayerSpawner, spawn points, DebugConsole, and test props. Keep it intact as a test scene.

The production architecture introduces a persistent `Main` root. Network session state and shared services remain in autoloads. Apartment, Casino, and Rest Area are replaceable world scenes under a persistent `WorldRoot`.

## Main scene hierarchy contract

Create this hierarchy in the Godot editor:

```text
Main (Node3D)                          [attach res://world/main_controller.gd]
├── WorldRoot (Node3D)                 [controller's replaceable world container]
├── Players (Node3D)                   [persistent multiplayer player container]
├── PlayerSpawner (MultiplayerSpawner) [persistent; spawn_path = ../Players]
└── DebugConsole                       [instance existing ui/debug/debug_console.tscn]
```

The transition overlay is created by MainController at runtime; do not add a second fade overlay.

The persistent `Players` and `PlayerSpawner` nodes are part of the intended architecture, but player spawning has not yet been migrated out of TestArena. Until the dedicated spawn-controller slice is complete, leave the current TestArena spawning script and scene unchanged. Do not try to run the new Main scene as the project's startup scene before the player-spawning migration and an initial world scene are ready.

## World scene contract

Each world is a separate `Node3D`-rooted PackedScene. World scenes contain their environment and world-specific interactables, but must not own the persistent network session or the persistent player container.

Recommended world roots and responsibilities:

- **Apartment** — starting lobby, player gathering, introduction, and Day 10 return destination.
- **Casino** — The House gameplay floor, casino tables, and casino-specific props.
- **RestArea** — optional social/recreation space and Daily Report destination.

Each world will expose a `SpawnPoints` Node3D containing editor-authored Marker3D children. The persistent spawn controller will use the active world's markers when spawning/repositioning players. Marker names and count will be standardized in the player-spawning migration slice.

## MainController API

File: `fowl-play/world/main_controller.gd`

Inspector assignments:
- `Initial World`: choose the first world scene once it exists.
- `Apartment Scene`, `Casino Scene`, `Rest Area Scene`: assign the corresponding PackedScenes.
- `World Root Path`: leave as `WorldRoot` unless the hierarchy changes.
- `Fade Duration Seconds`: defaults to 0.35 seconds.

The host calls `transition_to(MainController.World.CASINO)` (or the corresponding enum value). The host broadcasts only the small world ID; each peer loads its local PackedScene. This avoids trying to send scene resources over RPC. The RPC is reliable and authority-restricted. Offline play uses the same transition path locally.

Signals:
- `world_changed(previous_world, current_world)` — emitted after the new world instance is added.

World scenes must be present in each peer's build and all peers must have matching scene assignments. The controller rejects invalid IDs, missing scene assignments, and non-Node3D world roots.

## Transition responsibilities

MainController currently supplies a simple fade-to-black / fade-from-black scene swap. The elevator will later request transitions through this API. Elevator occupancy, carried-player handling, ragdoll reset, day announcements, Daily Report presentation, and transition voting are deliberately not implemented in W1; they belong to the elevator/day-flow slice.

## Important boundaries

- `Network` remains the only owner of ENet session creation/shutdown.
- `CasinoWallet` remains an autoload and survives world changes.
- `DebugHub` remains an autoload; the production DebugConsole belongs to persistent Main.
- The player container and MultiplayerSpawner must survive world changes.
- World scenes must not create a second Network, wallet, or player-spawning authority.
- Do not replace or repurpose `test_arena.tscn` as the production Main scene.
- The user's scene hierarchy, meshes, collision shapes, spawn markers, and environment art are editor-authored.

## W1 completion boundary

This slice adds the MainController script and this architecture contract only. It does not:
- create or modify any `.tscn` files;
- change `project.godot`'s `run/main_scene`;
- migrate player spawning out of TestArena;
- create the Apartment, Casino, or Rest Area scenes;
- implement the elevator or the run/day state machine.

Those are intentional follow-up slices, not missing test claims.
