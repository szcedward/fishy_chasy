# my-first-game — Architecture (MVP)

> **Companion**: `docs/REQUIREMENTS.md` (Draft v3) is authoritative for gameplay rules.  
> **Sync**: Rojo — `src/server` → `ServerScriptService.Server`, `src/client` → `StarterPlayerScripts.Client`, `src/shared` → `ReplicatedStorage.Shared`.

---

## 1. Authority model

| Domain | Owner |
|--------|--------|
| `size`, `bonus`, `frozen`, `lane` (Rostered/CatchUp), predation debuff timestamps | **Server** 写入；客户端只展示与预测（可选） |
| Boost 是否在 CD / 是否进入 5s 效果 | **Server** 决定 |
| AI 位置、AI Boost 随机 | **Server** |
| 关卡阶段、`LevelParticipants` 快照、`target`、`timer` | **Server** |
| 相机、本地 UI、输入采样 | **Client** → RemoteFunction/Event 请求 |

所有吃鱼判定、奖励增减、通关/失败 **必须在 server 结算**。

---

## 2. Suggested `src/` layout（可随实现微调）

```
src/shared/
  Config.luau              -- 常量：基础移速、Boost 时长/CD、debuff 秒数、生成公式参数
  Types.luau               -- 若采用严格类型：PlayerLane、SessionPhase 等
  Remotes.luau             -- 集中创建 / 引用 RemoteEvent（或拆模块）

src/server/
  init.server.luau         -- 薄入口：require 子系统并 Start()
  Session/
    SessionService.luau    -- session 生命周期、play-until-fail、reset
    LevelService.luau      -- level 切换、快照 LevelParticipants、CatchUp 晋升
    LevelGenerator.luau    -- target/timer/quota/AI 表；可解性链
  Fish/
    FishRegistry.luau      -- character ↔ fish 状态绑定
    PredationService.luau  -- 碰撞或 overlap 触发吃/被吃、§5.5 debuff、奖励分支
    BoostService.luau      -- 玩家请求 + AI 心跳随机策略
  AI/
    AIService.luau         -- boid / 移动意图 → 应用到 AI model

src/client/
  init.client.luau
  UI/
    Hud.luau               -- Level、Timer、Target、Bonus、CatchUp 标签、Boost 冷却环
  Input/
    BoostInput.luau        -- PC/触屏 → 调 Remote
```

> **Rojo 注意**：当前仓库仍是 `Hello.*` 占位；新增 `init.server.luau` 时，若放在 `src/server/init.server.luau`，Rojo 会把 **整个 Server 文件夹** 映射为一个 **Script**（单入口），其下子文件夹需以 **ModuleScript**（`*.luau`）形式存在。若希望多 Script，需调整 `default.project.json` 或改用多个 `.server.luau` 顶层文件。首版 MVP 推荐 **单 `init.server.luau` + 大量 ModuleScript 子模块**。

---

## 3. Session / level 状态机（建议）

```
Idle / WaitingPlayers
    → Playing(level=N, timer)
        → LevelCleared   -- 短暂：展示小榜、晋升 CatchUp → rostered
        → Playing(level=N+1)
    → Failed             -- 结算大屏 → reset → WaitingPlayers
```

`Playing` 内维护：`rosterSnapshot`、`catchUpUserIds`、`aiSpawnList`、`serverTimeLevelEndsAt`。

---

## 4. 数据挂载约定

| 数据 | 建议挂载点 |
|------|------------|
| `size`, `bonus` | `Player` Attributes 或 `leaderstats`（若需排行榜式展示） |
| `frozen`, `lane` | `Player` Attributes |
| `NoPredationRewardUntil` (UnixTime) | `Player` Attribute 或 module 内表 |
| AI 的 `size` | AI `Model` Attribute 或 Value 对象 |
| Boost CD 结束时间 | `Player` / AI 内部表 |

客户端 HUD 监听 `Player` Attribute 变化即可刷新。

---

## 5. Remotes（初稿）

| 名称 | 方向 | 用途 |
|------|------|------|
| `RequestBoost` | Client → Server | 玩家请求开 Boost |
| `LevelStateSync` | Server → Client | 可选：阶段、剩余时间、target（也可用 Attribute + 每分钟拉一次） |
| `FishStateSync` | Server → Client | 若不用 Attribute 广播复杂状态 |

MVP 可极简：**仅 `RequestBoost`**，其余用 `ReplicatedStorage` 里只读文件夹放配置 + Attribute 复制。

---

## 6. MVP 实现切片（建议顺序）

1. **Slice A — 单机鱼**：Workspace 放简单海洋盒；玩家 character 换鱼模型；**仅移速常量** + WASD/触屏移动；无吃鱼。  
2. **Slice B — 吃 AI**：生成静态 AI 若干；**server** 判定 overlap → 严格大吃小；AI 1:1 respawn；玩家 `size` 涨；**无关卡、无 timer**。  
3. **Slice C — Boost**：§10.2 规则 + UI 冷却环。  
4. **Slice D — debuff**：§5.5，仅玩家受害者。  
5. **Slice E — 关卡**：`LevelParticipants` / `CatchUp`、timer、`target`、`frozen`/`bonus`、通关/失败/reset。  
6. **Slice F — 生成器**：§6.6 链 + 对数填充；与 `S_min` 挂钩。  
7. **Slice G — AI boid + AI Boost**：§4.2、§10.2 AI 段。  
8. **Slice H — 抛光**：音效、tier 称号、HUD、`CatchUp` 文案。

每片完成后在 Studio 用 Rojo **Connect + Play** 验收。

---

## 7. Studio-only 资产

海洋几何、装饰、部分 `Sound` / `Terrain` 可保留在 Studio 中 **不被 Rojo 覆盖**（取决于 `default.project.json` 是否映射整个 Workspace）。MVP 若只映射脚本，**关卡几何在 Studio 手摆** 即可；生成器只刷 AI `Model`。

---

## 8. 测试与运营注意

- **多人**：本地 Studio 多客户端有限；上线前用 Roblox 私密 server / 邀请好友测 `CatchUp` 与断线剔除。  
- **性能**：AI 数量 × 玩家数 × Overlap 频率 → 需要节流（如吃鱼检测 10 Hz 或事件驱动）。
