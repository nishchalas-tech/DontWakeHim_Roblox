# DON'T WAKE HIM — Final Delivery Report
**Date:** 2026-10-06 · **Repo:** `DontWakeHim_Roblox` · **Backup:** `[local backup folder]`
**Place:** `DontWakeHim.rbxlx` — rebuilt this session from `build_place.py` and verified.

> **Verification honesty statement:** No Roblox Studio MCP was available in this session, so **nothing was executed inside Roblox runtime**. Every result below is either *static* (file/XML analysis, `run_tests.py`) or explicitly marked **NOT RUNTIME VERIFIED**. `run_tests.py` passing is static string evidence, not runtime evidence.

---

## 1. Executive summary

All 14 planned phases are complete: bootstrap, sync/build, round+objectives, noise, monster AI,
hiding/death/spectator, audio, UI/mobile, rewards/DataStore/shop, security, performance, test
matrix, polish. The place was rebuilt and statically verified end-to-end (all 19 embedded
scripts byte-match `src/`). `python run_tests.py` → **24/24 PASS, exit 0** (including TEST 18,
which failed at session start). The 26 runtime play-tests in the matrix remain **NOT RUNTIME
VERIFIED** pending a Studio session (manual steps in §10).

## 2. Phase 1 audit — what was broken (root causes)

| # | Finding | Severity |
|---|---------|----------|
| 1 | `ClientController` required `Controllers.Controllers` (nil) → **client boot crashed** | Critical |
| 2 | Empty placeholder ScreenGuis (RoundUI/ShopUI/StatsUI/SettingsUI) — shop/stats/settings buttons **did nothing** | High |
| 3 | `MonetizationService` never wired to any remote | High |
| 4 | `Players.MaxPlayers` never saved (engine cap = 100, spec requires 3) | High |
| 5 | `InteractionEvent` RemoteEvent existed but had **no server handler** (client fire-and-forget) | High |
| 6 | Sleeping Man was 11 **anchored, disconnected** parts — no joints, no animation, not a character | High |
| 7 | Hiding spots were **solid blocks** — player teleported inside solid geometry | High |
| 8 | Server Init signatures mismatched actual service modules (silent nil errors) | Critical |
| 9 | Round analytics call sites missing (`RoundTimedOut` etc.) → TEST 18 failed | Medium |
| 10 | Noise accepted client-claimed values, ungated outside ACTIVE rounds | High (security) |
| 11 | Door open/close had no server tween, no door sound broadcast | Medium |
| 12 | No rate limiting on any remote; `data.Position` trusted from client | High (security) |
| 13 | Audio table incomplete; no load-failure detection | Medium |
| 14 | Clue/Warning/UIClick sound slots missing | Medium |
| 15 | `AGENTS.md` claimed GUIs live in `build_place.py` only | Low |

## 3. Phase-by-phase changes (Phases 1–14)

| Phase | Files | What changed |
|-------|-------|--------------|
| 1 Audit + backup | — | Read-only audit; full `robocopy` backup |
| 2 Bootstrap | `ClientController.luau` | Sibling-require fix; `UIController.Init(remotes, Audio, Camera)` |
| 3 Build/world | `build_place.py` | Jointed rig, hollow wardrobes, `MaxPlayers=3`, lobby barriers+sign, `SprintButton`, removed 4 empty shells |
| 4 Round/objectives | `RoundService.luau`, `ObjectiveService.luau` | `RoundTimedOut` + 9 analytics events, `GetPlayerState`, results `RoundTime`/`KeysCollected`, `ResetDoors`+`ResetHidingStates` on reset, server-validated collect/escape |
| 5 Noise | `NoiseService.luau` | Rate limiter, ACTIVE-round gate, **server-derived** amounts (client `Position` ignored) |
| 6 Monster AI | `MonsterService.luau` | 5-state machine, `AI_TICK=0.2s` throttle, PathfindingService + fallback, LOS raycasts, procedural joint animation, pose transitions |
| 7 Hiding/death/spectator | `InteractionService.luau`, `UIController.luau` | Hollow-wardrobe prompts (recursive lookup, `RequiresLineOfSight=false`), `ClearHidingState`, CatchDistance discovery bypass, jumpscare→overlay→spectator pipeline |
| 8 Audio | `AudioController.luau` | 12-slot `AudioAssets` (all real 5338-series IDs), runtime load validation `[AUDIO] FAILED TO LOAD`, `PlaySoundAt`, `SetVolumes`, chase/snoring/jumpscare hooks |
| 9 UI/mobile | `UIController.luau`, `build_place.py` | Runtime-built menu/Shop/Stats/Settings wired to real server data; persisted settings; `ReducedEffects` gates shake |
| 10 Rewards/shop | `MonetizationService.luau`, `DataService` | `Init(remotes, data, analytics)` + `ShopEvent` OpenShop/Buy server-validated (coins-only, no Robux) |
| 11 Security | `Constants.luau`, all services | Dead `InteractionEvent` removed; 6 remotes with documented directions; per-action validation + rate limits |
| 12 Performance | `MonsterService.luau` | AI/path throttles, distance-gated raycasts (mobile) |
| 13 Test/verify | `run_tests.py` (read), verifiers | 24/24 static suite; custom structural place verifier; Luau bracket/keyword checker; cross-module API resolution check |
| 14 Polish | `AGENTS.md`, rig/lobby details | Docs updated; eyes WeldConstraint'd; invisible lobby barriers; sign instructions |

## 4. World & content (built by `build_place.py`)

- **House (6 rooms, unchanged layout):** bedroom, hallway, living room, kitchen, bathroom, front exit — all furniture, doors with prompts, `ExitDoor` + `LockLed`.
- **Sleeping Man:** proper **jointed R6 rig** (HumanoidRootPart/Torso/Head+SpecialMesh/arms/legs, 6 Motor6Ds, Humanoid `PlatformStand`, neon eyes welded) lying face-up on the bed; server PivotTo-glues it and animates breathing/walk/head-stir procedurally. Names `SleepingMan`, `Head`, `Eye1`, `BedFrame` preserved (tests depend on them).
- **3 hiding spots:** `HidingWardrobe_Bedroom`, `HidingCloset_LivingRoom`, `HidingCloset_Bathroom` rebuilt as **hollow panel boxes** (18 `Panel_*` parts) with `ExitMarker` inside, prompts `Hide Inside` / `RequiresLineOfSight=false`.
- **Objectives:** 3 keys per round randomized from **6 `KeySpawn_` points**; 4 `ClueSpawn_` points; key progress broadcast.
- **Lobby:** floor, 5 spawns, title `LobbySign` with **SurfaceGui how-to-play text**, 4 invisible barrier walls, warm lamp.
- **Cap:** `Players.MaxPlayers = 3` service property (engine-enforced 1–3 co-op).
- **GUI shells:** RoundUI/ShopUI/StatsUI/SettingsUI removed; `MainHUD` (noise bar, timer, KEYS n/3, status, `MobileControlsFrame` + `SprintButton`) and `ResultUI` kept.

## 5. Server architecture

**Boot order** (`MainServer.server.luau`): create 6 remotes from `Constants.RemoteNames` →
`DataService.Init` → `NoiseService.Init` → `ObjectiveService.Init(remotes, RoundService, Analytics)` →
`MonsterService.Init(remotes, rig, noise, interaction, round, analytics)` → `InteractionService.Init(remotes, noise, objective, round, data)` →
`MonetizationService.Init(remotes, data, analytics)` → `RoundService.Init(remotes, houseSpawns, lobbySpawns, services)` →
`NoiseService.SetRoundService(RoundService)` (ACTIVE-round gate).

**Round lifecycle:** `LOBBY → COUNTDOWN → STARTING → ACTIVE → (ESCAPE|DEATH|TIMEOUT) → ENDING → RESULTS → RESETTING → LOBBY`, repeatable; timer broadcast throttled to 1/s; results carry per-player `CoinsEarned`, `RoundTime`, `KeysCollected`; 9 analytics events wired (RoundStarted/Completed/TimedOut/Escaped/Caught/MonsterWoke/ChaseStarted/ObjectiveCollected/PlayerLeftDuringRound).

**Remotes (6, all wired, direction-documented in `Constants.luau`):**
`RoundEvent` S→C · `ObjectiveEvent` S→C · `NoiseEvent` C↔S · `MonsterEvent` S→C · `UIEvent` C↔S · `ShopEvent` C↔S. Dead `InteractionEvent` **removed**; all world interactions go through server-wired ProximityPrompts.

**Validation:** every handler checks `type(data)`, `Utility.IsPlayerAlive`, round `ACTIVE` + player `PLAYING` state, and rate limits (ActionNoise, UIEvent, ShopEvent). Objective/escape/clue/door/hiding all server-validated. Doors tweened server-side (0.35 s Quad from stored home pose) with sound broadcast to all clients.

## 6. Client architecture

`MainClient.client.luau → ClientController` (sibling requires — boot crash fixed) → `AudioController.Init` → `CameraController.Init` → `InteractionController.Init` → `UIController.Init`.

- **UIController:** HUD handlers (noise bands, KEYS n/3, timer, state banners), clue modal (+Clue sound), results screen (+success/failure sound), runtime-built **menu/Shop/Stats/Settings** bound to real server data, death overlay → spectator refresh loop, monster-state audio hooks, `GetSettings` fetch on boot. `TouchEnabled` shows `MobileControlsFrame`.
- **AudioController:** 12 sounds (Footstep, DoorOpen, ObjectivePickup, Heartbeat=chase, Ambience, MonsterGrowl, Jumpscare, EscapeSuccess, Clue, Warning, UIClick, Snoring); runtime `Loaded` validation warns `[AUDIO] FAILED TO LOAD` after 6 s; positional `PlaySoundAt`; `SetVolumes(music, sfx)`; pitch-varied reuses for Clue/Warning/UIClick/Snoring — **no fabricated IDs anywhere**.
- **InteractionController:** WASD/shift footstep noise (client fires intent only), mobile `SprintButton` (nested path `MainHUD→MobileControlsFrame→SprintButton` verified), door/clue/exit/hide prompts.
- **CameraController:** jumpscare shake (skipped when `ReducedEffects`), spectator camera.

## 7. Security & validation

- Server-derived noise amounts; client `Position` ignored; ACTIVE-round gate; rate limiter (`Config.Security.RateLimitEventsPerSec`).
- All 6 remotes: `type()` guards, action whitelists, alive+round-state checks, rate limits (UI/Shop/Noise).
- Shop: server price lookup, server-side coin deduction, pcall-guarded data; coins **only** from gameplay (no Robux products exist — no pay-to-win by construction).
- Settings: server clamps/coerces values before persisting (no client-trusted volume/effects).
- No secret/credential handling exists; no new attack surface added (one fewer remote than before).

## 8. Performance & mobile

- Monster AI decisions every `AI_TICK=0.2 s`; pathfinding requests throttled (`PATH_MIN_INTERVAL=0.8 s`) with token guard + straight-line fallback; raycasts distance-gated (`DetectionRadius`) with per-tick budget.
- Timer/throttle broadcasts: noise 1/s, round timer 1/s; positional sounds auto-clean up.
- Mobile: UDim2 HUD, 140 px touch targets, visible-on-touch `MobileControlsFrame`, sprint button, `ReducedEffects` option, runtime panels sized 50–62% screen.

## 9. Test results — 60-test matrix

### Group A — `run_tests.py` static suite (string-grep; **not** runtime evidence)

| # | Test | Result |
|---|------|--------|
| 1 | BOOT: place + entrypoints | PASS |
| 2 | LOBBY: platform, sign, spawns, countdown flow strings | PASS |
| 3 | HOUSE: 6-room architecture strings | PASS |
| 4 | SLEEPING MAN: model + `Constants.MonsterState.SLEEPING` | PASS |
| 5 | FOOTSTEPS: `PlaySound("Footstep"` + rate control | PASS |
| 6 | NOISE: `MovementNoise`, `DecayRatePerSecond`, `SetNoise` | PASS |
| 7 | DOORS: `HandleDoor`, `OpenDoor` contributions | PASS |
| 8 | CLUES: `SetupRoundClues`, `ShowClueModal` | PASS |
| 9 | KEYS: `ObjectiveKey_`, `collectedCount = collectedCount + 1` | PASS |
| 10 | RANDOMIZATION: `table.remove(availableIndices, idx)` | PASS |
| 11 | EXIT: `exitUnlocked = true`, `LockLed` | PASS |
| 12 | NOISE→MONSTER thresholds | PASS |
| 13 | MONSTER SEARCH: `MoveToward`, path strings | PASS |
| 14 | CHASE: `Ray.new`, `ChaseSpeed` | PASS |
| 15 | HIDING: `HidingDetectionMultiplier`, `HandleHidingSpot` | PASS |
| 16 | DEATH: `CatchPlayer`, `Jumpscare` | PASS |
| 17 | ESCAPE: `TryEscape` | PASS |
| 18 | TIMEOUT: `RoundTimedOut` in RoundService (**failed at session start**) | PASS |
| 19 | MULTIPLAYER: `MinPlayers = 1`, shared-state strings | PASS |
| 20 | MOBILE: `TouchEnabled`, `MobileControlsFrame` | PASS |
| 21 | REPEATED ROUNDS: reset strings | PASS |
| 22 | PERSISTENCE: DataStore + pcall fallback | PASS |
| 23 | SHOP: `PurchaseCosmetic`, `Insufficient Coins` | PASS |
| 24 | PERFORMANCE: `Ray.new` + distance checks | PASS |
| | **Total** | **24/24 PASS (exit 0)** |

### Group B — structural verification of the rebuilt place (static XML/source analysis)

| # | Test | Result |
|---|------|--------|
| 25 | Place XML parses; all 19 scripts embedded | PASS |
| 26 | All 19 embedded scripts **byte-match** `src/**.luau` | PASS |
| 27 | Jointed rig: 9 named parts + Humanoid + SpecialMesh + 6 Motor6Ds + 2 WeldConstraints | PASS |
| 28 | 3 hollow wardrobes (Models, 18 panels, nested prompts, `RequiresLineOfSight=false`) | PASS |
| 29 | `Players.MaxPlayers == 3` in place | PASS |
| 30 | Lobby: 4 barrier walls + sign SurfaceGui (`Face=Back`) + instruction text | PASS |
| 31 | Dead GUI shells removed; MainHUD/ResultUI/SprintButton/MobileControlsFrame present | PASS |
| 32 | All 19 Luau files: bracket + keyword block balance (custom checker) | PASS |
| 33 | Cross-module API resolution (every server `X.Y()` call has a definition) | PASS |
| 34 | Remote inventory: 6 remotes, directions documented, `InteractionEvent` absent | PASS |
| | **Total** | **10/10 PASS (static)** |

### Group C — runtime play-tests → **NOT RUNTIME VERIFIED** (no Studio MCP this session)

| # | Test | Result |
|---|------|--------|
| 35 | Server+client boot with zero output errors | NOT RUNTIME VERIFIED |
| 36 | Full lifecycle WAITING→COUNTDOWN→STARTING→ACTIVE→ESCAPE/DEATH/TIMEOUT→RESULTS→LOBBY | NOT RUNTIME VERIFIED |
| 37 | 3 consecutive rounds, clean reset each time | NOT RUNTIME VERIFIED |
| 38 | Timeout fires `RoundTimedOut` → results → reset | NOT RUNTIME VERIFIED |
| 39 | 2nd–3rd player joins; 4th player rejected (cap=3) | NOT RUNTIME VERIFIED |
| 40 | Objectives shared across all players, server-validated | NOT RUNTIME VERIFIED |
| 41 | HUD `KEYS: 0/3 → 3/3` updates live for every client | NOT RUNTIME VERIFIED |
| 42 | Different 3-of-6 key positions each round | NOT RUNTIME VERIFIED |
| 43 | Clue prompt → modal text + audible Clue sound | NOT RUNTIME VERIFIED |
| 44 | Door server tween + positional door sound + noise +2 | NOT RUNTIME VERIFIED |
| 45 | Noise meter bands SAFE/ALERT/DANGER/WAKE (colors + level text) | NOT RUNTIME VERIFIED |
| 46 | Noise decays when standing still | NOT RUNTIME VERIFIED |
| 47 | Noise ≥40 → DISTURBED growl; ≥90 → WAKING | NOT RUNTIME VERIFIED |
| 48 | SLEEPING→DISTURBED→WAKING→SEARCHING→CHASING with LOS + return-to-bed | NOT RUNTIME VERIFIED |
| 49 | Rig visibly animated (breathing, walk swing, pose transitions, pathing) | NOT RUNTIME VERIFIED |
| 50 | Hide in wardrobe: 90% detection reduction, prompt enter/exit works | NOT RUNTIME VERIFIED |
| 51 | Hiding is **not** invulnerable (monster within CatchDistance catches) | NOT RUNTIME VERIFIED |
| 52 | Death → `MonsterEvent Jumpscare` reaches `CameraController.TriggerJumpscare` + audio | NOT RUNTIME VERIFIED |
| 53 | Spectator follows living players until round end | NOT RUNTIME VERIFIED |
| 54 | Exit locked <3/3; unlocks at 3/3 (LED green), escape + coin payout | NOT RUNTIME VERIFIED |
| 55 | All 16 required sounds audibly play; no `[AUDIO] FAILED TO LOAD` in output | NOT RUNTIME VERIFIED |
| 56 | Mobile emulation: touch move, sprint button, readable HUD, no clipped UI | NOT RUNTIME VERIFIED |
| 57 | Coins server-authoritative (escape 100 + time bonus; caught = participation) | NOT RUNTIME VERIFIED |
| 58 | DataStore load/save with pcall retry; Studio fallback; no wipes on failure | NOT RUNTIME VERIFIED |
| 59 | Shop buy deducts coins server-side; settings persist across rejoin | NOT RUNTIME VERIFIED |
| 60 | Device performance: AI/raycast throttles hold frame time on mobile emulation | NOT RUNTIME VERIFIED |
| | **Total** | **0 verified — 26 NOT RUNTIME VERIFIED** |

**Matrix totals: 34 PASS (static) · 0 FAIL · 26 NOT RUNTIME VERIFIED.**

## 10. Acceptance checklist, limitations, manual steps

### Acceptance checklist

- [x] Concept/house/world preserved — nothing rebuilt from scratch; 6-room house kept
- [x] Full round lifecycle, repeatable 3 rounds, `RoundTimedOut` restored (TEST 18 fixed)
- [x] 1–3 player cap — `Players.MaxPlayers = 3` in place (static PASS); join behavior runtime-untested
- [x] 3 objectives / 6 spawn points / HUD KEYS n/3 (static PASS)
- [x] Noise 0–100 with 4 bands; server-authoritative, throttled, round-gated (static PASS)
- [x] Monster 5-state machine + LOS + jointed animated rig + pathfinding (static PASS)
- [x] Hiding spots functional and **not** permanent invulnerability (static PASS)
- [x] Death → jumpscare remote → `CameraController` → spectator → round end (static PASS)
- [x] Locked exit unlocks at 3/3; server-validated doors with sounds (static PASS)
- [x] Audio: no fabricated IDs; load-failure warnings; **partially met** — 12 slots with pitch-varied reuses rather than 16 distinct files (see limitations)
- [x] Mobile-friendly UI + touch sprint (static PASS)
- [x] Server-authoritative coins, no pay-to-win (no Robux products exist)
- [x] DataStore with pcall/retry/fallback, no wipe paths (static PASS)
- [x] Working placeholder shop + settings with **only real controls** (volumes, reduced flashing)
- [x] Dead `InteractionEvent` removed; every remaining remote wired
- [x] `run_tests.py` passes 24/24 (exit 0)
- [x] `build_place.py` run; place rebuilt; scripts byte-verified
- [ ] **Runtime verification of Group C (26 tests)** — blocked: no Studio MCP in this session

### Known limitations (honest)

1. **No runtime verification was possible** — Roblox Studio MCP unavailable; all 26 Group C tests are NOT RUNTIME VERIFIED.
2. **Audio slots:** 12 named slots; Clue/Warning/UIClick/Snoring reuse verified 5338-series assets with pitch variation; chase audio = Heartbeat loop. All IDs are real (pre-existing in project) — none fabricated — but 16 *distinct* sound files were not added (inventing IDs would have violated the spec).
3. **Studio force-closed:** five graceful close attempts (`CloseMainWindow`, `WM_CLOSE` ×3, `SC_CLOSE` ×2) were ignored by Studio; the process (PID 13200) was terminated and its orphaned lock (confirmed to contain that PID) removed. No source risk: `build_place.py`+`src/` are the source of truth and a full backup exists.
4. `run_tests.py` remains a string-grep suite (by design); its PASS ≠ runtime correctness.
5. No linter/rojo/selene/stylua available — verification limited to `run_tests.py`, custom static checkers, and XML analysis.

### Manual Studio test steps (to clear Group C)

1. Open `DontWakeHim.rbxlx` (already reopened in Studio this session) → **Test → Play**.
2. Output window must be clean; confirm `[SERVER]`/`[CLIENT]` init prints, `[AUDIO]` has no `FAILED TO LOAD`.
3. Solo: walk (footsteps), read a clue, open a door, pick keys (KEYS n/3), reach 3/3 → exit unlocks → escape → results → coins.
4. Make noise → verify bands/DISTURBED/WAKING; watch rig animation; hide in a wardrobe; get caught → jumpscare → spectator.
5. Let the timer expire → timeout results → clean reset → round 2 starts automatically.
6. **Test → Clients and Servers: 2 and 3 players** — shared keys, cap, spectator on death.
7. **Device emulation (phone)** — touch move/sprint, HUD readability.
8. Settings/Shop/Stats open and persist across rejoin.

### Publish checklist

- [ ] File → Publish to Roblox (place must be owned by the group/user)
- [ ] Game Settings → Security → **Enable Studio access to API services** (DataStore in Studio)
- [ ] Confirm max players 3 shows on the game page (from place file)
- [ ] Playtest in a real client (not only Studio) before announcing
- [ ] Regenerate after any `src/**` edit: `python build_place.py` (then `python run_tests.py`)

---
*Rollback: `robocopy` backup at `[local backup folder]`.*
