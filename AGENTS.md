# AGENTS.md — DontWakeHim_Roblox

Roblox horror game "DON'T WAKE HIM". Luau game scripts live in `src/`, but the playable
place `DontWakeHim.rbxlx` is **generated** by a Python script — see the build rule below.

## Commands (run from repo root)

- `python build_place.py` — regenerates `DontWakeHim.rbxlx`. **Required after every edit to
  `src/**` or to world/GUI layout.** The place file embeds script text at build time; there is
  no live sync, so an unbuilt edit does not exist in-game.
- `python run_tests.py` — 24 QA tests, exits 0/1. Uses relative paths, so it must run from the
  repo root. There is no way to run a single test: tests share variables (`bcode`, `rcode`,
  `mcode`…) defined in earlier tests and must run in order.
- No linter, formatter, typecheck, or `rojo`/`selene`/`stylua` config exists (none are on
  PATH). Do not invent verification commands beyond the two above.

## Architecture

- Two ways scripts reach the game:
  1. **`build_place.py` is the source of truth.** It builds everything: Workspace geometry
     (6-room house, lobby, sleeping-man rig), Lighting, all StarterGui ScreenGuis with UDim2
     layouts, and embeds each `src/**.luau` file as `ProtectedString` Source.
  2. `default.project.json` is a Rojo mapping for **scripts only** — it maps no Workspace,
     StarterGui, or Lighting, so a Rojo-only sync never builds the world or UI.
- Server flow: `src/ServerScriptService/MainServer.server.luau` creates
  `ReplicatedStorage.Remotes` + RemoteEvents from `Constants.RemoteNames`, then requires each
  module in `ServerScriptService.Services` by filename. Client flow:
  `MainClient.client.luau` → `Controllers.ClientController` → the other controllers.
- **Adding/renaming a service or controller requires three edits**: the file itself, the
  `services_list` / `controllers_list` name→path map near the bottom of `build_place.py`, and
  the `require` in `MainServer.server.luau` / `ClientController.luau`. Missing the build-place
  list means the module silently never ships.
- Gameplay tuning numbers live only in `src/ReplicatedStorage/Shared/Config.luau`; remote
  names and state enums in `Constants.luau`. Prefer those over hardcoding.
- **UI is split across two places** — the fixed HUD (MainHUD: noise meter, timer, keys,
  status, mobile controls) and ResultUI are laid out in `build_place.py` in Python; the
  menu, Shop, Stats, and Settings panels are built at runtime by `src/.../Controllers/UIController.luau`
  (they were empty placeholder ScreenGuis before and were removed from the build).
  Text/layout tweaks to the HUD → `build_place.py`; behavior/content of menu panels → `UIController.luau`.
- Module requires are by name (`ReplicatedStorage.Shared.Config`, `...Controllers.UIController`),
  so folder names created in `build_place.py` must keep matching the `src/` layout.

## Testing quirks (read before refactoring)

- `run_tests.py` greps **source text as substrings** — it does not execute Luau. Exact
  fragments must survive refactors, e.g. `collectedCount = collectedCount + 1`,
  `PlaySound("Footstep"`, `table.remove(availableIndices, idx)`, `Ray.new`, `MinPlayers = 1`,
  `Constants.MonsterState.SLEEPING`, `HidingDetectionMultiplier`. Semantically equivalent
  rewrites (different spacing, renamed locals, `for i=1,n` instead of `table.remove`, …)
  will fail tests.
- It also greps `build_place.py` itself for world strings (`LobbyFloor`, `SleepingMan`,
  `ExitDoor`, `HidingWardrobe_Bedroom`, …), so deleting/renaming parts breaks tests too.
- Known current failure (verified 2026-10-06): **TEST 18 (TIMEOUT) fails** — it wants
  `RoundTimedOut` inside `src/ServerScriptService/Services/RoundService.luau`, but the string
  only exists in `Constants.luau`. The other 23 pass. Don't assume a green run.
- The checked-in `DontWakeHim.rbxlx` can be **stale relative to `src/`** (its embedded scripts
  come from the last `build_place.py` run). Rebuild before judging in-game behavior.
- `DontWakeHim.rbxlx.lock` is Roblox Studio's file lock (place open in Studio). If Studio has
  the place open, a rebuilt `DontWakeHim.rbxlx` won't be visible until the place is closed and
  reopened; don't treat the lock as source.
