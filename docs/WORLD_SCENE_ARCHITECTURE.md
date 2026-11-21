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
├── MultiplayerSpawner                  [persistent; spawn_path is configured by MainController]
└── DebugConsole                       [instance existing ui/debug/debug_console.tscn]
```

The transition overlay is created by MainController at runtime; do not add a second fade overlay.

The persistent `Players` and `MultiplayerSpawner` nodes are part of the intended architecture. MainController configures the spawner's path and spawn function at runtime. Player creation, peer cleanup, spawn-slot assignment, and world-to-world repositioning now belong to Main. Leave the current TestArena spawning script and scene unchanged. Do not switch the project's startup scene until an initial Apartment scene is ready.

## World scene contract

Each world is a separate `Node3D`-rooted PackedScene. World scenes contain their environment and world-specific interactables, but must not own the persistent network session or the persistent player container.

Recommended world roots and responsibilities:

- **Apartment** — starting lobby, player gathering, introduction, and Day 10 return destination.
- **Casino** — The House gameplay floor, casino tables, and casino-specific props.
- **RestArea** — optional social/recreation space and Daily Report destination.

Each world will expose a `SpawnPoints` Node3D containing editor-authored Marker3D children. MainController uses the active world's Marker3D children in order as spawn slots. Every world must provide at least four Marker3D children (the current maximum player count). Keep marker order consistent between worlds so a player's slot remains stable.

## MainController API

File: `fowl-play/world/main_controller.gd`

Inspector assignments:
- `Initial World`: choose the first world scene once it exists.
- `Apartment Scene`, `Casino Scene`, `Rest Area Scene`: assign the corresponding PackedScenes.
- `World Root Path`: leave as `WorldRoot` unless the hierarchy changes.
- `Players Path`: leave as `Players`.
- `Player Spawner Path`: leave as `MultiplayerSpawner`; MainController sets its spawn path to the persistent Players node.
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
- The player container and MultiplayerSpawner must survive world changes. Main owns spawn/despawn and the Network autoload continues to own player movement registration and replication.
- World scenes must not create a second Network, wallet, or player-spawning authority.
- Do not replace or repurpose `test_arena.tscn` as the production Main scene.
- The user's scene hierarchy, meshes, collision shapes, spawn markers, and environment art are editor-authored.

## W1 player-spawn migration boundary

MainController now owns persistent player creation/removal and uses the active world's `SpawnPoints` markers. Players are children of `Main/Players`, not the replaceable world. The spawn function is installed on every peer; only the offline instance or host creates players, while MultiplayerSpawner constructs the replicated copies on clients. Disconnects remove the departing host-owned player, and session shutdown clears the persistent container.

A world swap repositions standing, uncarried players to the same numbered spawn slot in the destination world. Ragdolled, recovering, carried, or carrying players are deliberately not teleported by this generic method; the future elevator transition must normalize those states first.

This slice still does not:
- create or modify any `.tscn` files;
- change `project.godot`'s `run/main_scene`;
- modify or replace `test_arena.tscn` or its spawn script;
- create the Apartment, Casino, or Rest Area scenes;
- implement the elevator or the run/day state machine.

The Main scene should be tested with an authored world containing at least four Marker3D children under `SpawnPoints` before it becomes the startup scene.
