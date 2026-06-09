# my-first-game — Architecture (MVP)

> **Companion**: `docs/REQUIREMENTS.md` (Draft v3.1) is authoritative for gameplay rules.  
> **Sync**: Rojo — `src/server` → `ServerScriptService.Server`, `src/client` → `StarterPlayerScripts.Client`, `src/shared` → `ReplicatedStorage.Shared`.

---

## 1. Authority model

| Domain | Owner |
|--------|--------|
| `size`, `bonus`, `frozen`, `lane` (Rostered/CatchUp), predation debuff timestamps | **Server** 写入；客户端只展示 |
| `ShieldLayers`, `ShieldBlocking` | **Server** 写入；客户端 HUD / 气泡 VFX |
| Boost 是否在 CD / 是否进入 5s 效果 | **Server** 决定 |
| AI 位置、AI Boost 随机 | **Server** |
| 关卡阶段、`LevelParticipants` 快照、`target`、`timer` | **Server** |
| 食物生成、拾取、护盾层数增减 | **Server**（`FoodService` / `ShieldService`） |
| 相机、本地 UI、输入采样、音效 | **Client** |

所有吃鱼判定、奖励增减、护盾消耗、通关/失败 **必须在 server 结算**。

---

## 2. Current `src/` layout（截至 v0.1）

```
src/shared/
  Config.luau              -- 全局常量：移速、Boost、Predation、Level、Shield、Food、Tier
  Tier.luau                -- tier / scale / color / name
  Format.luau              -- K/M/B/T 数字格式化
  FishCollision.luau       -- 2D OBB（SAT）碰撞：玩家/AI 鱼身矩形 overlap
  Remotes.luau             -- RequestBoost RemoteEvent

src/server/
  Main.server.luau         -- 入口：启动各 Service
  LevelService.luau        -- 关卡状态机、Rostered/CatchUp、frozen/bonus、AI 生命周期
  LevelGenerator.luau      -- 可解 AI 列表生成
  Fish.luau                -- AI/玩家鱼模型、Billboard 标签、护盾气泡
  Predation.luau           -- 捕食 tick（OBB）、§5.5 debuff、spawn 保护、护盾拦截
  Boost.luau               -- 玩家 Boost 服务端校验
  AIService.luau           -- boid 移动 + AI Boost + AI-vs-AI
  ShieldService.luau       -- 护盾层数、遭遇状态、脱离后扣层
  FoodService.luau         -- 单食物刷新与玩家拾取
  MapSetup.server.luau     -- 水下光照、装饰、边界柱（独立 Script）

src/client/
  Main.client.luau
  Boost.luau               -- ContextActionService：F / R2 / 触屏 BOOST
  Hud.luau                 -- Level、Timer、Lane、Boost、Debuff、Shield
  Sounds.luau              -- 本地音效（吃、死、Boost、食物、护盾破碎等）
```

> **Rojo 映射**：`src/server/*.server.luau` 为顶层 `Script`；其余 `*.luau` 为 `ModuleScript`。`Main.server.luau` 为薄入口，require 各 Module 并 `start()`。

---

## 3. Session / level 状态机

```
Idle / WaitingPlayers
    → Playing(level=N, timer)
        → LevelCleared   -- 短暂：展示小榜、晋升 CatchUp → rostered（护盾保留）
        → Playing(level=N+1)
    → Failed             -- 结算 → reset（含护盾清零）→ Level 1
```

`Playing` 内维护：`rosterSnapshot`、`catchUpUserIds`、`aiSpawnList`、`serverTimeLevelEndsAt`；`FoodService` 仅在 `Phase == Playing` 时刷新食物。

---

## 4. 数据挂载约定

| 数据 | 挂载点 |
|------|--------|
| `Size`, `Bonus`, `Frozen`, `Lane` | `Player` Attributes |
| `NoPredationRewardUntil`, `SpawnProtectedUntil` | `Player` Attributes（Unix 时间） |
| `ShieldLayers` (0–4), `ShieldBlocking` (bool) | `Player` Attributes |
| `BoostActiveUntil`, `BoostReadyAt` | `Player` Attributes |
| AI `Size` | AI `BasePart` Attribute |
| `Phase`, `LevelNumber`, `LevelTarget`, `LevelEndsAt` | `workspace` Attributes |
| AI Boost / boid 内部状态 | `AIService` module 内表 |
| 护盾「遭遇中」服务端状态 | `ShieldService` module 内 `blockingEncounter` 表 |
| 当前食物 Part | `FoodService` module 内 `activeFood` |

客户端 HUD / `Sounds` / 鱼身气泡 **监听 Player Attribute** 即可，无需额外 Remote。

---

## 5. Remotes

| 名称 | 方向 | 用途 |
|------|------|------|
| `RequestBoost` | Client → Server | 玩家请求开 Boost |

食物与护盾 **无 Remote**；Authority 全在 server Attribute 复制。

---

## 6. 碰撞与捕食

- **玩家 vs AI / 玩家 vs 玩家**：`FishCollision.fishTouching` — 2D **OBB + SAT**（有朝向矩形），与 `Fish.luau` 鱼身半长/半宽一致，随 tier 缩放。
- **Predation tick**：`Config.Predation.TickHz = 60`（每 Heartbeat 帧）。
- **食物拾取**：玩家 HRP 与食物 Part 的 **球形距离** `< PickupRadius`（默认 5 studs）；与 AI 无检测。

### 护盾状态机（`ShieldService.tickEncounters`，每捕食 tick 末尾）

```
每帧检测：是否有严格更大的 AI/玩家与本人 OBB 重叠？
  ├─ 重叠 且 ShieldLayers > 0 → ShieldBlocking = true；Predation 不杀、不给攻击者奖励
  ├─ 上帧 Blocking 且 本帧已脱离所有威胁 → ShieldLayers -= 1；Blocking = false
  └─ ShieldLayers == 0 且被咬 → 正常死亡
```

**注意**：扣层发生在 **脱离** 威胁范围时，避免 60Hz 连续 overlap 在一帧内耗尽多层护盾。

---

## 7. MVP 实现切片

| Slice | 内容 | 状态 |
|-------|------|------|
| A | 基础移速 | ✅ |
| B | 吃 AI、tier 视觉缩放 | ✅ |
| C | Boost | ✅ |
| D | 捕食 debuff §5.5 | ✅ |
| E | 关卡 / Rostered / CatchUp / PvP | ✅ |
| F | LevelGenerator | ✅ |
| G | AI boid + AI Boost | ✅ |
| H | Format、tier 标签、音效、spawn 保护 | ✅ |
| **I** | **食物 + 护盾 §10.3** | ✅ |
| — | 鱼模型（椭球+鳍）、MapSetup 海底场景、OBB 碰撞 | ✅（v0 抛光，未单独编号） |

每片完成后 Studio **Connect + Play** 验收。

---

## 8. Studio-only 资产

海洋 Baseplate、部分装饰可与 `MapSetup.server.luau` 共存；脚本生成的 `MapDecor` / `ShieldFood` 在运行时创建。发布前确认 Studio 内 **Stop Play** 再 **Publish**。

---

## 9. 测试与运营注意

- **多人**：私密 server 测 `CatchUp`、护盾层数、食物争抢（满层不拾取时食物仍留场）。
- **性能**：捕食 60Hz × (玩家×AI + 玩家×玩家) + 食物 Heartbeat 拾取检测；当前 AI 数量下可忽略。
- **iPad**：Boost 触屏按钮由 `ContextActionService` 自动创建（`createTouchButton = true`）。
