# Local Multiplayer Verification (Godot 4.7.2)

This is a manual, real-ENet smoke test using separate game processes on one computer. It validates the current host-authoritative player lifecycle before synchronized run startup is attempted.

## Start the test instances

1. Pull the latest `environment/world-building-and-gameplay-loop` branch in GitHub Desktop.
2. Close any running Fowl Play game windows.
3. Run `fowl-play/tests/run_multiplayer_local_checks.bat`.
4. Enter `2` for the first host/client pass. You can rerun it later with `3`, `4`, or `5` windows for capacity testing.
5. In the first game window, use the Apartment's Lobby Host / Join terminal and choose **HOST**.
6. In the other window(s), choose **JOIN** and enter `127.0.0.1`.

The project starts at the Main scene. Apartment player markers are under `LobbySpawnPoints`; Casino player markers are under `PlayerSpawnPoints`. The host listens on UDP port `7777`. MainController now selects the populated player-marker container and ignores empty placeholder nodes named `SpawnPoints`.

## Test A — host and one client

- [ ] No `World Apartment has no populated player spawn container` warning appears.
- [ ] Host remains in Apartment and sees one player before a client joins.
- [ ] Client joins successfully.
- [ ] Host sees two players.
- [ ] Client sees two players (including the already-existing host player).
- [ ] Move around on the host; client sees the host move.
- [ ] Move around on the client; host sees the client move.
- [ ] Both instances show the correct player identities/colors.

**Important:** The client seeing the host's already-existing player is the late-join snapshot check. Godot 4.7's MultiplayerSpawner tracks active spawned nodes and sends them to newly connected peers; the actual ENet run must confirm the project integration behaves as expected.

## Test B — late join and four-player capacity

Open three or four windows with the launcher. Host from the first and join from the others, one at a time.

- [ ] Third instance joins; all three instances see three players.
- [ ] Fourth instance joins; all four instances see four players.
- [ ] No duplicate player models appear.
- [ ] All four players can move and see one another moving.
- [ ] If using five windows, the fifth connection is rejected because the host allows three clients plus itself.
- [ ] A rejected fifth client returns to local offline Apartment play rather than remaining without a player.

## Test C — disconnect and rejoin

- [ ] Close one client window.
- [ ] Remaining connected instances see that player's model disappear.
- [ ] Host's peer/identity roster no longer includes the disconnected player.
- [ ] Start a fresh client instance and join `127.0.0.1`.
- [ ] All connected instances see the new player exactly once.
- [ ] The new connection receives a fresh peer ID; identity/color assignment remains valid.

## Test D — host departure

- [ ] Close the host window while at least one client remains connected.
- [ ] Each remaining client detects the host departure.
- [ ] Each client returns to offline Apartment play with exactly one local player.
- [ ] No client remains stuck in a connecting/connected state.

## Useful diagnostics

If the DebugConsole is available, run:

- `net_status` — connection status and connected peer IDs.
- `identity_status` — host-authoritative identity roster.
- `net_disconnect` — intentionally leave a session.

Visual player counts and movement are the primary checks. Do not treat the test as passed based only on the host reporting connected peers; each window must visibly contain the same player set.

## Report results

Send the checklist results and any relevant console errors/warnings. Note which window (host/client/late joiner) produced the issue. Jolt cone-twist bias/softness warnings are separate from ENet verification and are not, by themselves, a multiplayer failure.
