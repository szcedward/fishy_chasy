# Session log

---

## 2026-06-09 — v0.1: 食物 + 护盾

**Goal**: 地图食物拾取 → 玩家护盾（最多 4 层）；挡大鱼攻击；脱离威胁后扣层；AI 不吃食物。

**Done**:

- **`docs/REQUIREMENTS.md` v3.1**: 新增 §10.3 食物与护盾规则；更新 core loop、§12 已定项。
- **`docs/ARCHITECTURE.md`**: 重写为当前真实 `src/` 布局；补充 OBB 碰撞、护盾状态机、Slice I。
- **`src/shared/Config.luau`**: `Config.Shield`（MaxLayers=4, LayersAttr, BlockedEncounterAttr）、`Config.Food`（RespawnSeconds=20, PickupRadius, 生成区域）。
- **`src/shared/FishCollision.luau`** (new): 从 Predation 抽出 OBB/SAT 碰撞工具，供 Predation 与 ShieldService 共用。
- **`src/server/ShieldService.luau`** (new): 护盾层数、`blockingEncounter` 遭遇状态；`tickEncounters` 在脱离更大鱼碰撞范围后扣 1 层；死亡 / session 失败清零；过关保留。
- **`src/server/FoodService.luau`** (new): `Playing` 阶段每 20s 无食物则生成一个；玩家拾取 +1 层；满 4 层不拾取；被吃后 20s 再刷。
- **`src/server/Predation.luau`**: 接入护盾拦截（有盾不死、攻击者无奖励）；改用 `FishCollision`；每 tick 末尾 `ShieldService.tickEncounters`。
- **`src/server/LevelService.luau`**: `resetPlayerSession` 清护盾；`failLevel` 调用 `FoodService.resetForSession`。
- **`src/server/Fish.luau`**: 玩家 ForceField 护盾气泡，随层数/格挡状态变化。
- **`src/client/Hud.luau`**: 右下角 `SHIELD xN` / `BLOCKING` 面板。
- **`src/client/Sounds.luau`**: `FoodPickup`、`ShieldBreak` 音效。

**Design notes**:

- 护盾消耗采用用户指定方案：**脱离** 所有更大威胁的 OBB 范围后才扣 1 层，避免 60Hz 连续 overlap 一帧吃光多层。
- 一次遭遇（含多条大鱼同时压住）只扣 1 层。
- 食物不给 size/bonus；与 §5.4 frozen/bonus 路径完全独立。

**State at end**: v0 功能冻结后的首个玩法扩展已落地。v0 本体含 Slice A–H、鱼模型、MapSetup、OBB 碰撞、Roblox 发布流程（用户侧进行中）。

**Pending / next session**: 地图障碍物/小迷宫（用户已记录为后续）；playtest 护盾手感与食物刷新节奏；可选更新 REQUIREMENTS 中 v0 抛光项（鱼 mesh 资产、Publish 文档）。

---

## 2026-05-16 — Slice H polish + spawn protection hotfix

**Goal**: Slice H (number formatting, tier labels, sounds) + a spawn-protection fix reported by user.

**Done**:

- **Spawn protection hotfix** (`src/server/Predation.luau`, `src/shared/Config.luau`): `CharacterAdded` now writes `SpawnProtectedUntil = now() + 3` on the Player. `resolveAIBite` skips the kill while the attribute is active. Player can still eat smaller AI during protection. Config: `Config.Predation.SpawnProtectionSeconds = 3`, `SpawnProtectedUntilAttr = "SpawnProtectedUntil"`.
- **`src/shared/Format.luau`** (new): `Format.number(n)` → K/M/B/T with 1 decimal for values < 10 in that unit (e.g. 1234 → "1.2K", 12345 → "12K", 1500000 → "1.5M").
- **`src/server/Fish.luau`**: BillboardGui size 80×24 → 110×44; head labels now show `"小鱼级\n1.2K"` (tier name + formatted number, two lines). Players show `"❄ 42\n小鱼级"` when frozen. Uses `Format.number`.
- **`src/client/Hud.luau`**: All size/target/bonus numbers use `Format.number`. Top panel text properly uses K/M/B for large values.
- **`src/client/Sounds.luau`** (new): `Sounds.mount()` creates Sound instances under SoundService; listens to `Size` attribute (eat), `BoostActiveUntil` (boost), workspace `Phase` (level cleared/failed), `Humanoid.Died` (death). Sound IDs are placeholders — can be swapped in the `IDS` table at top of file.
- **`src/client/Main.client.luau`**: Added `Sounds.mount()`.

**Sound IDs (placeholders — replace as needed)**:
- Eat: `rbxassetid://9117502460`
- Die: `rbxassetid://131070166`
- LevelCleared: `rbxassetid://3051417649`
- LevelFailed: `rbxassetid://445596489`
- Boost: `rbxassetid://154965962`

**State at end**: All MVP slices A–H complete. Game is functionally complete per PRD. Remaining work is playtesting, balancing, and optional future features (DataStore, skins, Robux).

**Pending / next session**: Playtest balance tuning (AI speed, level timer, target multiplier). Optional: publish to Roblox, DataStore for persistent scores, fish mesh swap.

---

## 2026-05-14 — Slices D–G completed

**Goal**: implement Slice D (predation debuff), Slice E (level system + PvP), Slice F (level generator), Slice G (AI movement + AI Boost), plus bite-radius scaling fix and banner shrink.

**Done**:

- **Slice D** (`src/server/Predation.luau` new, `src/shared/Config.luau` extended): `NoPredationRewardUntil` Player Attribute set 10 s after respawn; `Predation.isPlayerInDebuff()` API exported. HUD shows red `NO REWARD Xs` panel.
- **Slice E** (`src/server/LevelService.luau` new, `src/client/Hud.luau` rewritten, `src/server/Fish.luau` updated):
  - State machine `Waiting → Playing → Cleared | Failed → …` via `workspace` Attributes (`Phase`, `LevelNumber`, `LevelTarget`, `LevelEndsAt`).
  - `LevelParticipants` (Rostered) snapshot at level start; `CatchUp` lane for mid-level joiners.
  - `target = S_min × 5`, `timer = 90 + level × 15 s`; `Frozen` + `Bonus` per PRD §5.4.
  - `§5.5` debuff fully wired: eater gets no reward if victim is in NPRU window (but victim still dies).
  - PvP: player-vs-player contact resolved in `Predation.luau`; same-size = no eat.
  - Head label shows `❄` prefix when Frozen.
  - HUD: top-center level/target/timer/size/bonus; top-right Lane badge (`ROSTERED`/`CATCH-UP`/`WAITING`); thin banner for Cleared/Failed (replaced oversized modal).
  - Predation gated on `Phase == Playing` so no kills during Cleared/Failed transitions.
- **Bite-radius scaling fix**: `Predation.luau` now computes per-entity half-radius as `ContactRadius × 0.5 × Tier.scaleOf(size)`; two fish touching uses sum of both half-radii. Fixes "big fish has same hitbox as tiny fish" bug.
- **Slice F** (`src/server/LevelGenerator.luau` new): greedy chain construction guarantees a solvable path from `S_min` to `target`; log-uniform random AI fill to `quota_N`; `Config.AI.MaxAISizeRatio = 0.8`, `QuotaMultiplier = 1.5`, `MinQuota = 8`. `LevelService` owns AI lifecycle (destroy old / spawn new on each `startLevel`). `Config.AI.InitialSizes` removed.
- **Slice G** (`src/server/AIService.luau` new): boid movement (flee > chase > wander, boundary steering), smooth direction lerp (turn rate ~4 rad/s), per-AI independent boost roll timer (1–2 s staggered), low-skill AI boost (`BoostBaseProbability = 0.05` + `BoostPanicProbability = 0.15` when larger player within 35 studs), reaction delay 0.2–0.8 s. AI-vs-AI predation at 10 Hz (larger relocates smaller, no size gain). `AIService.start(aiFishes)` holds shared table reference — survives `LevelService.rebuildAIForLevel` automatically. `Config.AI.Speed = 16` (slower than player 22; fish feel catchable but not trivial).

**State at end**:

- All MVP slices A–G complete. Only Slice H (polish: K/M/B numbers, tier name in HUD, sounds) remains.
- Server files: `Main`, `Boost`, `Fish`, `LevelService`, `LevelGenerator`, `Predation`, `AIService`.
- Shared files: `Config`, `Tier`, `Remotes`.
- Client files: `Main.client`, `Boost`, `Hud`.

**Pending / next session**:

- Slice H: K/M/B number formatting in head labels + HUD; tier name shown in HUD or above-head label; sound effects (eat, die, level clear, boost); optional: CatchUp HUD copy polish.

---

Append-only history of what each Cursor agent session accomplished. **Newest entry on top.**

Format: a dated section per session with `Goal`, `Done`, `State at end`, `Pending / next session`.

---

## 2026-05-12 (later 5) — Slice C: Boost sprint

**Goal**: per `docs/ARCHITECTURE.md` §6 Slice C + PRD §10.2 — server-authoritative 5s ×2 speed Boost with 10s cooldown starting from effect end, plus client input (PC/mobile/gamepad) and a simple HUD readout. AI Boost remains deferred to Slice G.

**Done**:

- `src/shared/Config.luau`: extended `Config.Boost` with `ActiveUntilAttr = "BoostActiveUntil"` and `ReadyAtAttr = "BoostReadyAt"` so server and client share attribute names.
- `src/shared/Remotes.luau` (new): centralized remote folder + lazy creation. `Remotes.RequestBoost` is a `RemoteEvent` under `ReplicatedStorage.Remotes`. Handles both server-create and client-WaitForChild flows.
- `src/server/Boost.luau` (new): `Boost.start()` connects the `RequestBoost` server event and runs a `Heartbeat` that walks all players and writes `Humanoid.WalkSpeed` to `BaseWalkSpeed` or `BaseWalkSpeed × Multiplier` based on the `BoostActiveUntil` attribute. `tryStartBoost(player)` rejects requests while `BoostReadyAt > now`; on accept it sets `BoostActiveUntil = now + 5` and `BoostReadyAt = now + 15` (so cooldown is effectively `Duration + Cooldown` from press, == 10s after effect ends).
- `src/server/Main.server.luau`: requires `Boost` and calls `Boost.start()` before the player-handler loop so `OnServerEvent` is connected before any player can fire it.
- `src/client/Main.client.luau` (new, LocalScript): tiny entry — requires `Boost` and `Hud` and starts them.
- `src/client/Boost.luau` (new): binds a `ContextActionService` action `FishBoost` to `KeyCode.F`, `KeyCode.ButtonR2`, and an auto-created mobile touch button (titled `"BOOST"`). Fires `RequestBoost` on `UserInputState.Begin`.
- `src/client/Hud.luau` (new): mounts a `ScreenGui` (`ResetOnSpawn = false`) with a single status frame at bottom-right reading from the two Boost attributes via `workspace:GetServerTimeNow()` on every Heartbeat: shows `BOOST READY (F)` / `BOOST 4.2s` (green) / `CD 7.1s` (gray).

**Design fidelity notes**:

- PRD §10.2 cooldown semantics — “从效果结束开始算” → `ReadyAt = pressTime + Duration + Cooldown`. Server is sole truth.
- PRD §10.2 “no stacking”: while `ReadyAt > now`, repeat requests are silently rejected.
- PRD §P7 (speed not tied to size): respected; multiplier applies to `BaseWalkSpeed` only, no interaction with `Size`/Tier.
- Roblox `workspace:GetServerTimeNow()` is the shared clock — synchronized between client and server, eliminates time-base drift for the HUD countdown.
- Boost survives respawn: because the per-frame `applyWalkSpeedTo` reads attributes (lifecycle-independent) and writes to whichever Humanoid is currently in `player.Character`, a respawn mid-boost auto-reapplies the multiplier on the new character. Cooldown continues regardless.

**Keybind choice**:

- PC: `F` (PRD §10.2 suggested `LeftShift / Q` but `LeftShift` collides with Roblox default ShiftLock toggle; `F` is unbound by default and matches common action-key conventions). Easy to flip in `src/client/Boost.luau` if user prefers another key.
- Mobile: auto touch button via `ContextActionService` (label `"BOOST"`).
- Gamepad: `ButtonR2` (right trigger).

**State at end**:

- Files: added `Remotes.luau` (shared), `Boost.luau` (server), `Main.client.luau`/`Boost.luau`/`Hud.luau` (client). `src/client/` is no longer empty.
- Runtime instances: `ReplicatedStorage.Remotes.RequestBoost` (RemoteEvent), `Players.LocalPlayer.PlayerGui.FishHud.BoostStatus` (ScreenGui frame).
- No structural changes to `Fish`/predation.

**Testing checklist (user)**:

1. `rojo serve` running; reconnect from Studio.
2. Press Play.
3. Bottom-right of screen should show `BOOST READY (F)` (white).
4. Press **F** (or click the on-screen `BOOST` button if you’re testing mobile mode).
   - HUD changes to `BOOST 5.0s` (counting down, green).
   - Character speed visibly doubles for 5 seconds.
   - When 5s expires, HUD switches to `CD 10.0s` (gray) and counts down.
   - During cooldown, pressing F has no effect (silently rejected).
   - At `CD 0.0s`, HUD returns to `BOOST READY (F)`.
5. Press F again at the moment of contact with a small AI — you should see size go up *and* still travel at boosted speed.
6. Trigger Boost, then run into the 50 AI: die mid-boost. After respawning, if any seconds remain on `BoostActiveUntil` you should still be moving fast for the leftover time. Cooldown continues independently.

**Pending / next session**:

- Slice D: predation cooldown debuff (PRD §5.5) — 10s no-reward window for the eater after a player respawns; AI fish exempt.
- Then Slice E: server-wide level system (level number, `LevelParticipants` snapshot, `target`, `time_limit`, `frozen` + `bonus`, `CatchUp` lane, fail → reset to Level 1).

---

## 2026-05-12 (later 4) — Slice B: eat-the-AI prototype

**Goal**: per `docs/ARCHITECTURE.md` §6 Slice B — server spawns static AI fish; heartbeat overlap check between players and AI; strict-greater-eats-smaller (ties favor player per PRD §4.4); eaten AI relocates 1:1 to a new random spot; player gains `Size`; head labels show numbers. No level system, no PvP, no Boost, no debuff.

**Done**:

- Extended `src/shared/Config.luau`: added `Player.InitialSize = 10`, `AI` (8 initial sizes `{4,6,8,9,12,18,30,50}`, part dimensions, ring-shaped spawn area with `MinDistanceFromOrigin = 20` to keep the SpawnLocation safe), `Predation` (10 Hz tick, 4-stud contact radius).
- Added `src/server/Fish.luau` (ModuleScript): exports `SIZE_ATTRIBUTE`, `createAI`, `relocateAI`, `attachPlayerLabel`. Uses BillboardGui above each fish with white AI text / yellow player text. Player label cleans up its attribute-changed connection when the character is destroyed.
- Rewrote `src/server/Main.server.luau`: spawns AI under `Workspace.AIFish`; on `PlayerAdded` sets `Size = 10` Attribute; on `CharacterAdded` re-applies walk speed and re-attaches head label; runs a single `Heartbeat` predation loop throttled to 10 Hz that walks (player × AI) pairs, on overlap calls `resolveBite`.
- `resolveBite`: ties favor player (`playerSize >= aiSize`); player eats → `Size += aiSize`, AI calls `relocateAI`. Otherwise → set `Humanoid.Health = 0`; Roblox auto-respawns at the SpawnLocation. Outer loop breaks for the player after they die so a single tick can't trigger two kills.

**Design fidelity notes**:

- PRD §P2 (zero-penalty respawn): the `Size` attribute lives on the `Player`, not the character, so respawn does not reset it — confirmed in code.
- PRD §5.5 predation cooldown: deliberately deferred to Slice D; left a `Boost` and `PredationDebuffSeconds` constant in `Config` so adding it later is a one-touch change.
- PRD §P7 (speed not tied to size): respected — `WalkSpeed = Config.BaseWalkSpeed` is reapplied on respawn regardless of `Size`.

**State at end**:

- Files: `src/shared/Config.luau`, `src/server/Main.server.luau`, `src/server/Fish.luau`. `src/client/` still empty. No new RemoteEvents (Slice C will likely add `RequestBoost`).
- Workspace at runtime: `Workspace.AIFish` Folder with 8 anchored Parts (collision off, touch off — overlap is purely spatial). Each AI Part has `Size` attribute and a BillboardGui showing the number.
- Performance: 8 AI × 1 player × 10 Hz = 80 distance checks/sec. Negligible.

**Testing checklist (user)**:

1. `rojo serve` running.
2. Studio Connect; press Play.
3. Output: `[Server] Spawned 8 AI fish.` and `[Server] Slice B ready. Players start at size 10.`.
4. 8 green flat-ish cubes appear in a ring around spawn, each with a number (4, 6, 8, 9, 12, 18, 30, 50). Player head shows yellow `10`.
5. Walk into the `4` fish: head label changes to `14`; the `4` fish teleports somewhere else, still labeled `4`.
6. Walk into the `9` fish (tie within tolerance after eating earlier? do it first while you are still 10): head goes to `19` (player favored on ties).
7. Walk into the `50` fish: player ragdolls and respawns at SpawnLocation, head still shows the size you had before death (zero-penalty respawn).

**Pending / next session**:

- Slice C: `BoostService` — RemoteEvent `RequestBoost`, server-validated 5s ×2 with 10s CD-from-end; client input + HUD cooldown ring. Per PRD §10.2 + AI Boost is part of Slice G (with boid).
- Subsequent: Slice D (predation debuff), then Slice E (level system).

**Post-test tweak (same day)**: user reported detection felt laggy ("撞上50之后还往前跑一下才死"). Cause: `Predation.TickHz = 10` meant up to 100ms detection gap, ~2.2 studs of player movement vs 4-stud AI hitbox — player could clearly enter the AI before being judged. Raised `Predation.TickHz` from 10 to 60 (one check per Heartbeat). Performance budget at our scale is negligible (8 AI × 1 player × 60 Hz ≈ 480 distance checks/sec); the polling approach will need revisiting only when level generators push AI counts into the hundreds (Slice F+), at which point grid hashing or `workspace:GetPartBoundsInRadius` are the planned escalation paths. Note: some residual "slide before ragdoll" is Roblox death animation + HRP linear velocity, not detection lag — optional hard-stop (`hrp.AssemblyLinearVelocity = Vector3.zero`) deferred unless 60 Hz still feels off.

**Pulled forward from Slice H — tier-based visual scaling (PRD §9.5 + §9.1)**: user noticed no visible model growth after eating fish. Per PRD §9.5 visuals are *tier-based discrete* (not continuous), so within a tier there is intentionally no scaling. To make this visible in dev testing — and because it's pure forward work (no rework risk) — implemented the tier system now:

- New `src/shared/Tier.luau` exposing `tierOf(size)`, `scaleOf(size)`, `colorOf(size)`, `nameOf(size)`; tier table sourced from `Config.Tiers` (Bounds, Names, Colors, ScalePerStep=0.5).
- `Fish.luau`: AI fish now sized by `Config.AI.PartSize * Tier.scaleOf(size)` and colored by `Tier.colorOf(size)`. Renamed `attachPlayerLabel` → `attachPlayerVisuals`; on every `Size` attribute change it now also calls `applyHumanoidScale(humanoid, Tier.scaleOf(size))` writing the four body scale NumberValues (`BodyHeightScale`/`BodyWidthScale`/`BodyDepthScale`/`HeadScale`).
- Effect in Slice B: 7 of 8 AI are 小鱼级 (scale 1.0, light green), the `50` AI is 中鱼级 (scale 1.5, green). Player visibly grows when crossing into 中鱼级 (`Size ≥ 50`).

Tier name display (above-head label showing "小鱼级"/"中鱼级") still deferred to Slice H — just numbers + color + scale for now.

---

## 2026-05-12 (later 3) — Slice A: base movement skeleton

**Goal**: per `docs/ARCHITECTURE.md` §6 Slice A — replace env-verification `Hello.*` placeholders with the first real modules: a base `WalkSpeed` applied to every player on spawn. No fish mesh, no AI, no level system, no UI yet.

**Done**:

- Created `src/shared/Config.luau` — central constants module. Defines `BaseWalkSpeed = 22` (decoupled from `size` per PRD §P7) plus forward placeholders for `Boost` (Slice C) and `PredationDebuffSeconds` (Slice D); kept in `ReplicatedStorage.Shared` so both server and client (later) can read it.
- Created `src/server/Main.server.luau` — entry Script: on `PlayerAdded`/`CharacterAdded` set `Humanoid.WalkSpeed = Config.BaseWalkSpeed`. Also handles the case where a player is already in-game when the server script first runs. Prints a readiness line on boot.
- Deleted env-verification placeholders: `src/server/Hello.server.luau` (also clears the `". hahhahaha"` live-edit residue), `src/client/Hello.client.luau`, `src/shared/Greeter.luau`.

**State at end**:

- Rojo mapping unchanged. After next Rojo sync, Explorer should show only `ServerScriptService.Server.Main` and `ReplicatedStorage.Shared.Config`; `Hello`, `Greeter` should be gone.
- `src/client/` is empty; that is acceptable for Slice A (no client logic yet).
- Slice A is server-only: relies on the Studio Baseplate world for geometry and the default character rig for visuals. No fish mesh swap yet (deferred to a polish slice).

**Testing checklist (user)**:

1. Confirm `rojo serve` is still running (or restart it).
2. In Studio, Connect via the Rojo plugin. Explorer should now show `Main` (not `Hello`) under `ServerScriptService.Server`, and `Config` (not `Greeter`) under `ReplicatedStorage.Shared`.
3. Press Play. Output should print `[Server] Slice A ready. BaseWalkSpeed = 22`.
4. Walk with WASD; movement should feel brisk and uniform. (Default Roblox WalkSpeed is 16, so 22 should feel noticeably faster.)

**Pending / next session**:

- Slice B: server-side overlap detection between players and a small set of static AI fish models; strict-greater-eats-smaller; 1:1 AI respawn; introduce the `size` Attribute on players.

---

## 2026-05-12 (later) — REQUIREMENTS v3 + ARCHITECTURE published

**Goal**: design review of all SESSION_LOG queued rules; merge into a single authoritative PRD; prepare for implementation.

**Done**:

- **Design audit**: Confirmed `LevelParticipants` + `CatchUp` resolves late-join vs win condition; `S_min` for formulas taken from rostered-only at level start; predation debuff addresses feed exploit; movement/boost rules consistent with no size-scaled base speed; noted accepted PvP/CatchUp grief risks and disconnect denominator abuse as known issues.
- Wrote **`docs/REQUIREMENTS.md` Draft v3** (replaces v2 in full): §0 audit, participation lanes, joiner sizing + historical fallback, §5.5 debuff, mobility §10, AI boost policy, session/level rules, UI notes, §14 playtest backlog.
- Wrote **`docs/ARCHITECTURE.md`**: authority model, suggested `src/` module tree, state machine, data on Attributes, Remote sketch, MVP slices A–H, Rojo note on `init.server.luau` vs folder mapping.

**State at end**:

- `docs/REQUIREMENTS.md` = **v3** on disk. Prior **2026-05-12 — Pending PRD revision** block in this log is **superseded** by the published doc (log block kept for history).
- Implementation can start at **Architecture §6 Slice A** unless user reprioritizes.

**Pending / next session**:

1. Optional: `git init` + commit `docs/*` + `SESSION_LOG` + any code from Slice A onward.
2. Implement Slice A in `src/` per ARCHITECTURE; verify Rojo mapping if switching to `init.server.luau`.
3. Fine-tune open knobs: `LevelParticipants` snapshot frame; PC boost keybind; CatchUp “pseudo-frozen” UI.

---

## 2026-05-12 — Pending PRD revision (no doc release yet)

**Goal**: capture a rules change before rewriting `docs/REQUIREMENTS.md`; user will batch more edits then publish one new doc version.

**Change queued (supersedes v2 §4.3 / N1 joiner sizing)**:

- **Joiner size**: when a player joins mid-session, their **numeric size** should equal **the smallest size among players currently on the field** (exact scope TBD when writing the doc: include spectators or only “active” fish; tie-break; moment of snapshot).
- **Explicit request**: do **not** update `docs/REQUIREMENTS.md` until the user finishes listing all desired edits; then produce a single revised PRD.

**Fallback when “min among players currently on the field” is undefined** (user 2026-05-12):

- Use **`min` over all players who have ever been in the current level** of each person’s **level-start size for this level** (the size they had when this level began for them). User asserts no other edge case remains.
- Example: first player enters Level 3, server records their Level-3 start size, then they disconnect — second joiner has no “live” peers; fallback uses that recorded Level-3 start size (the departed player still counts as “曾经在该 level 在场过”).
- **Implementation note for the future PRD**: server must persist a per-level table or append-only log `{ userId, levelNumber, levelStartSize }` (or equivalent) at the instant a player becomes a participant for that level; disconnected players remain in history for fallback math only.

**Predation cooldown — anti PvP-feed exploit (user 2026-05-12, clarified same thread)**:

- Applies only to **human players** as **victim** after a **player** death. **AI fish do not use this system** (no debuff on AI respawn; eating AI always uses normal reward rules — user: “AI鱼可以没有冷却时间”).
- After a player is eaten and **respawn completes**, they carry a **10-second “no reward for eating me”** debuff. **Timer starts at respawn complete** (user confirmed: not from death instant).
- If this player is **eaten again** while the debuff is active, the **eater** (AI or player) gains **nothing**: no `size` increase, no `bonus` increase (frozen players’ bonus path included).
- **Not invulnerability**: during the debuff the player **can still be eaten**; death + respawn behave as today. Only the **eater’s reward** is suppressed (user confirmed).
- **Cooldown refresh**: each respawn-after-death starts a **new** 10s window from that respawn’s complete moment.
- **Victim can still eat others** during debuff (unchanged unless user revises).
- **v2 doc impact**: supersedes **§5.4 N7** (“MVP 不防互喂”) — new PRD should remove “ignore exploit” and reference this rule instead.

**Joiner vs cooperative win condition (revised per user 2026-05-12 — playable catch-up lane)**:

- **Problem (unchanged)**: If every connected player must hit `target` for level clear, a tiny late joiner can grief the timer.
- **User decision — supersedes prior “spectate only” recommendation**: Mid-level joiners should **be able to play immediately** (not dry-wait), especially on long levels. They may **eat AI fish and grow** (user: 可以吃鱼，涨分 — interpret as **normal eat → `size` increases** for satisfying gameplay unless user later splits a separate “score” stat).
- **Win / bonus separation**:
  - Players who join **after** level L has started are **`CatchUp` (non-rostered)** for that level: their **`size` does not count toward the cooperative level-clear condition** (they are **not** in `LevelParticipants` for L), and they **do not earn `bonus`** on L (bonus stays 0 / no increments while `CatchUp` on L).
  - **Rostered** players = `LevelParticipants` snapshotted at **level L start** (exact moment in PRD). Only rostered players must reach `target` within the timer for L to clear.
- **Next level promotion**: When L clears and L+1 begins, players who were `CatchUp` on L should **promote to rostered** for L+1 (same rule as before: their L+1 entry size uses field-min + historical fallback — already queued above). **Confirm in PRD pass.**
- **Open design — PvP while `CatchUp` (user decision 2026-05-12)**: **Full PvP** — no restriction between `CatchUp` ↔ rostered (or among any players). All predation / reward rules that apply to rostered PvP **also apply** to `CatchUp` participants (subject to existing **predation cooldown** and normal size/bonus rules for rostered; `CatchUp` still **no bonus** on level L per user spec — need PRD to state whether eating a rostered player as `CatchUp` grants **`size`** to the catcher; default **yes** if PvP is symmetric unless user revises).
- **Accepted risks (document in PRD “known issues / playtest”)**: rostered players may **farm** `CatchUp` joiners for `size`; `CatchUp` may **grief** rostered near timer; `CatchUp` hitting `target` still does not clear the level but might create confusing “I’m huge but we didn’t win” UX — mitigate via HUD copy only.
- **Disconnect (rostered)**: prior recommendation unchanged — **remove disconnected rostered players from L’s denominator** unless user wants hardcore fail-on-leave.
- **Optional belt**: join cutoff time window still available if user wants extra safety.

**Movement speed — decoupled from `size` (user 2026-05-12)**:

- **Principle**: **Linear movement speed must not scale with fish `size`.** If bigger fish were also faster, **snowball** worsens: large players harder to chase down and harder to escape, compounding the numeric advantage.
- **PRD direction**: all human-controlled fish (and likely **AI fish** for fairness unless user wants “dumber but same speed” only) share the **same base swim / walk speed** (or a small set of archetypes **not** tied to level/size tier). Balance passes adjust **one global constant** (or per-level ambient tweak), not per-player derived from mass.
- **Still separate from speed** (allowed to differ by size without violating user rule): **collision radius / mouth hitbox**, **visual mesh scale**, **turn responsiveness** (user said “速度” — interpret as **translational speed**; if they also want identical turn rate, say so in PRD). Larger hitboxes = easier to be eaten / easier to eat — that is intentional trade space.
- **Future hooks** (non-MVP): other mobility perks / slows — **not** auto from `size`.

**Boost sprint — universal ability (user 2026-05-12)**:

- **Scope (“每条鱼”)**: **Every fish entity** (each **player** + each **AI fish**) has the same **numeric** boost rules (5s ×2 speed, 10s CD from effect end). **AI decision logic** is deliberately **dumb / random** — see below.
- **Input**: one **Boost** action per player (PC key TBD e.g. `LeftShift` / `Q`; **mobile**: dedicated on-screen button; **gamepad**: TBD). AI does **not** “press a key”; server runs an AI boost policy.
- **Effect**: while active, **translational swim / walk speed ×2** (**+100%** line speed) for **5 seconds** (from effect start).
- **Cooldown**: **10 seconds**, counted **from when the 5s effect ends** → next boost earliest **15s after** pressing boost (5s active + 10s CD), i.e. **10s after** boost ends.
- **Design alignment**: base speed still **not** from `size`; boost is **same multiplier for everyone** — adds **timing / commitment** without compounding size snowball via speed.
- **AI boost — user intent (anti “perfect escape”)**:
  - AI **may** use boost, but behavior must be **random / low-skill**, **not** omniscient: **forbidden as primary rule** is “whenever a larger fish is about to catch me, instantly boost” — that makes AI **uncatchable** and unfair vs humans (humans lack 360° awareness, have reaction delay, may not see pursuers from behind).
  - **PRD direction (MVP)**:
    - **Baseline**: while off CD, small **random chance per heartbeat** (e.g. every 1–2s) to start boost — most of the time AI boosts for **no tactical reason** (wastes CD, feels alive, exploitable by players).
    - **Optional weak “panic” nudge**: if a strictly larger fish is within radius R, **slightly** raise boost probability — but keep cap so **most** threats still **do not** trigger boost; **never** 100% on imminent catch.
    - **Humanization**: if a roll decides to panic-boost, apply **random reaction delay** (e.g. 0.2–0.8s) before effect starts — avoids frame-perfect escapes.
  - **Playtest knobs**: global p, R, max panic contribution % — tune until AI is catchable most of the time skilled players commit boost.
- **PRD / implementation notes for later**:
  - **No stacking** during active + CD (recommend **ignore** extra presses).
  - **UI**: icon + cooldown ring / bar (important for kids).
  - **Server-authoritative**: client requests, server validates timestamps and applies multiplier.
  - Default: **no special interaction** with predation cooldown or `CatchUp` unless user revises.

**Still to nail in the PRD pass** (minor):

- Whether **AI** participate in “field min” (**no**, per prior intent).
- Exact moment of snapshot (“level start” = first frame after transition when player is non-spectator, etc.).
- **`CatchUp` HUD**: how to show `target` / progress (e.g. greyed “练习模式” vs hidden); whether `CatchUp` can visually hit “frozen” state with **no** server effect.
- **`CatchUp` ↔ rostered PvP** — **user chose full PvP** (no lane restriction). PRD: spell out reward symmetry + `CatchUp` no-bonus-on-L + optional HUD mitigations for confusion/farming.

**State at end**:

- `docs/REQUIREMENTS.md` remains **v2 unchanged** on disk.
- This log entry is the source of truth for the joiner rule until the batched PRD update.

---

## 2026-05-10 (later 2) — Requirements v2: multiplayer model rewritten

**Goal**: incorporate user's significant rework of the win/respawn/multiplayer rules.

**Done**:

- User rewrote the multiplayer model to elegantly resolve OQ-4:
  - Win = reach `target size` (not "eat all fish").
  - Server-wide cooperative race: everyone must reach target to advance.
  - First to reach target → size frozen; further eating goes to `bonus`.
  - Death = respawn at current size (zero penalty).
  - Failure = time runs out before everyone reaches target.
- Probed for derivative open questions; user decided:
  - **Joiner (N1)**: spectate during current level; enter next level at `min(freeze_size)` of completers.
  - **Fail scope (N2)**: server-wide.
  - **Session (N3)**: play-until-fail. Failure ends session, leaderboard, server resets to Level 1.
- Wrote `docs/REQUIREMENTS.md` v2 (13 sections).
- **Flagged social/UX concern**: server-wide fail with kid audience may invite toxic behavior toward slow players. §13 laid out 5 possible mitigations. **User chose to accept the risk and adopt none of them for MVP**; doc updated to record decision. The 5 mitigations remain documented for future activation if real-world data shows a problem.

**State at end** (user paused session here):

- `docs/REQUIREMENTS.md` v2 exists; §13 social risk **acknowledged and accepted by user, no mitigations adopted for MVP**.
- All major architectural decisions resolved (multiplayer model, win/respawn/session lifecycle).
- No game code written yet.

**Pending confirmation from user (still unresolved at pause)**:

These were presented in v2 with recommended defaults; user paused before explicitly confirming. Next session should ask for a single "all OK?" confirmation or pick out the ones to change:

| ID | Recommended default in v2 |
|---|---|
| OQ-1 | 玩家 vs 玩家同大小不互吃 |
| OQ-2 | AI 行为：简单 boid（追小逃大，否则随机）|
| OQ-5 | PvP 击杀的 size 转移给吃方，按 frozen 状态决定走 size 还是 bonus |
| OQ-7 | Tier 称号保持原汉字，未来再考虑加注音 |
| Overshoot interpretation | 跨过 target 的那一吃 → freeze size = 实际吃后值（含超出），不严格 cap 在 target |
| Server capacity | 6-8 人/server (待 playtest 调) |
| §10.1 跳关功能 | 改写为"立即把自己 size 拉到 target"，但这在 server-wide 模型下退化为利他行为，不再是 P2W；需用户决定保留 / 删除 / 改设计 |

**Pending / next session**:

1. **First action**: ask user to confirm or override the 7 pending defaults above (single round, light touch).
2. (Optional) `git init` + initial commit to lock env + v2 PRD checkpoint. User has deferred this twice; ask once more then drop unless they bring it up.
3. Then write `docs/ARCHITECTURE.md` — module breakdown, server/client split, RemoteEvent design, level generator pseudo-code, server lifecycle state machine.
4. Then start MVP implementation — slice 1 candidate: single fixed level, player can move + see a few static AI fish + collide-to-eat (smaller dies) with size mutation; no level system, no PvP, no AI behavior, no UI polish, no spectator. Smallest possible vertical slice.

**Optional housekeeping at next session start**:

- The live-edit test left `src/server/Hello.server.luau` containing `". hahhahaha"`. Still un-reverted. Not blocking.

---

## 2026-05-10 (later) — Game requirements drafted

**Goal**: turn the user's raw game ideas into a structured PRD; surface contradictions before any code is written.

**Done**:

- Reviewed user's raw requirements for a "fish eats fish" game targeting elementary school kids (grade 1-5).
- Identified contradictions and risks; got 4 key decisions from user:
  - **B1 AI eating**: AI 互吃但被吃后 auto-respawn 同大小，保持总质量。
  - **B3 Multiplayer**: shared-world + PvP enabled.
  - **B4 Number display**: tier 称号 + 英文 K/M/B 数字单位（同时显示）。
  - **B5 Robux**: MVP 零付费；未来要做（路线图写进文档）。
- Wrote `docs/REQUIREMENTS.md` v1 (12 sections, 7 open questions).
- **Flagged a new architectural blocker** (OQ-4): user's PvP shared-world choice conflicts with per-player level progression and per-player size carry-over. Documented 4 possible resolutions; **strongly recommended MVP fall back to single-player (方案 D)** with PvP deferred to v2.

**State at end**:

- `docs/REQUIREMENTS.md` exists, status = Draft v1.
- 7 open questions (OQ-1 through OQ-7) await user resolution. **OQ-4 is the critical blocker** — must be resolved before any implementation begins.
- No game code written yet. `src/` still holds only the env-verification Hello scripts.

**Pending / next session**:

1. **First**: user reads `docs/REQUIREMENTS.md`, especially §11 OQ-4. Decide whether MVP keeps shared-world PvP or falls back to single-player.
2. **Then**: resolve OQ-1, OQ-2, OQ-3 (already adopted), OQ-5, OQ-6 (recommendations are written; user just needs to confirm or override).
3. **Then**: optional `git init` + initial commit to lock in the env + PRD checkpoint.
4. **Then**: design technical architecture — module breakdown, server/client split, RemoteEvent design, level generator algorithm. Write to `docs/ARCHITECTURE.md`.
5. **Then**: start implementation, MVP slice 1 (probably: single-player, single fixed level, player can move + see other fish + collide-to-eat; no level system yet).

---

## 2026-05-10 — Environment setup & end-to-end sync verification

**Goal**: bootstrap Cursor + Rojo + Luau dev environment, verify the full edit-sync-playtest loop works.

**Done**:

- (Earlier session, same day) Scaffolded the project: `src/{server,client,shared}/`, `default.project.json`, `setup.ps1`, `README.md`, `.vscode/{settings,extensions}.json`, `rokit.toml`, `stylua.toml`, `.gitignore`.
- Ran `setup.ps1`:
  - Rokit 1.2.0 installed (PATH refreshed in-session via `Refresh-PathFromRegistry`, no reboot needed despite installer warning).
  - Rojo 7.6.1 + StyLua 2.4.1 installed via `rokit install`.
  - Rojo plugin copied into Roblox Studio via `rojo plugin install`.
- Installed Cursor extensions via PowerShell (`cursor --install-extension <id>`):
  - `evaera.vscode-rojo` v2.1.2
  - `JohnnyMorganz.luau-lsp`
  - `JohnnyMorganz.stylua`
  - Note: Cursor uses Open VSX by default, but `cursor --install-extension` worked for all three.
- Verified end-to-end sync chain:
  - `rojo serve` → `localhost:34872` ✅
  - `Invoke-WebRequest http://localhost:34872/api/rojo` → returned JSON with `projectName: "my-first-game"` ✅
  - Studio: New Baseplate → Plugins → Rojo → Connect → Explorer showed `ServerScriptService.Server.Hello`, `StarterPlayerScripts.Client.Hello`, `ReplicatedStorage.Shared.Greeter` ✅
  - Play → Output printed both `Hello from Cursor + Rojo! (server)` and `Hello, client!` lines ✅
  - Cursor edit to `src/server/Hello.server.luau` → saved → appeared instantly in Studio's script editor ✅

**State at end**:

- `rojo serve` may still be running in a terminal — user can `Ctrl+C` it any time.
- `src/server/Hello.server.luau` was edited during the live-edit test to include `". hahhahaha"` in the print string. Not reverted (intentional — left as evidence; harmless).
- Project is **not** initialized as a git repo. `.gitignore` exists but `git init` was offered and deferred.
- `.cursor/rules/project-context.mdc` and this `SESSION_LOG.md` were created at end of session so future agents auto-load context.

**Pending / next session**:

- Decide the actual game concept (genre, scope) and plan an MVP.
- Optional: `git init` + first commit + GitHub remote.
- Optional: revert the `Hello.server.luau` live-edit string if it bothers you (one-line change).

**Gotchas worth remembering**:

- The `vscode-rojo` panel in v2.1.2 doesn't show a file tree — Studio Explorer is the ground truth for "did sync arrive".
- `rojo serve` is silent on client connect by default. No log ≠ failure.
- Roblox Studio's ribbon may be missing the **View** tab on some layouts; `F9` toggles Output, or use the classic menu bar `View → Output`.
