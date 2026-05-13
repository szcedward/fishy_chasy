# my-first-game — Game Requirements

> **Status**: Draft v3 — 2026-05-12  
> **Target audience**: 小学 1–5 年级（约 6–11 岁）  
> **Supersedes**: Draft v2 (2026-05-10). 本版合并 SESSION_LOG 中所有待定设计（中途加入、`CatchUp`、捕食冷却、移速/Boost、AI Boost 策略等）。

---

## 0. Design audit (v3 merge)

在落文档前对当前设计做了一轮一致性检查。**结论：可以进入编码**，但下列项在实现 / playtest 中必须显式验证（已在正文标出）。

| 主题 | 结论 |
|------|------|
| 通关 vs 中途加入 | 已用 `LevelParticipants`（关卡开始时登记）+ `CatchUp`（关内加入可玩但不计入通关、不涨 bonus）消除「关尾加入拖死全服」的矛盾。 |
| `S_min` / `target` 公式 | `S_min_N` **仅取自本关 `LevelParticipants` 在关卡开始时的入场 size**，不包含 `CatchUp`，避免目标被稀释或算错。 |
| 全开 PvP + `CatchUp` | 已接受：先在场可刷迟到小号、`CatchUp` 可干扰竞速；MVP 仅用 HUD 文案缓解误解，不做机制硬拦。 |
| 互喂 exploit | **已处理**：玩家受害者 **10s 捕食无收益**（见 §5.5）；AI 无此 debuff。 |
| 移速 vs 体型 | 基础**线速度**不随 `size`；Boost 为全员相同倍率，避免大雪球。 |
| AI Boost | 随机为主 + 禁止「必被抓才开」为主策略；需调参以免 AI 过强或过弱。 |
| Roblox 实例生命周期 | 无人连接时 server 会被回收；设计以「至少一名真人参与 session」为前提（§8.3）。 |

---

## 1. Vision

一款 Roblox 街机向合作 + PvP 鱼类游戏：玩家吃鱼成长、躲避大鱼，在 **server 全局关卡** 与倒计时内，**登记在册的玩家**需全部达到目标体型后进入下一关；全服在某关失败则 session 结束、展示结算并回到 Level 1。面向低龄玩家，数字与称号双重可读。

---

## 2. Design principles

| # | Principle | 说明 |
|---|-------------|------|
| P1 | 数字明确 | 头顶显示可读的 size + 称号 tier。 |
| P2 | 死亡零体型惩罚 | Respawn 后 **size = 死亡瞬间的 size**（仅损失时间）。 |
| P3 | 玩家略优于 AI | 玩家 vs AI **同体型**：玩家可吃 AI，AI不能吃玩家。 |
| P4 | 大数可读 | 英文 K/M/B/T + 中文 tier 称号（§9）。 |
| P5 | MVP 无付费 | 无 Robux；未来路线见 §11。 |
| P6 | 合作通关边界清晰 | 仅 **`LevelParticipants`** 必须达 `target`；**`CatchUp`** 可玩但不计入通关、本关 **bonus 恒为 0**。 |
| P7 | 线速度不绑定体型 | 基础平移速度不随 `size` 缩放；体型差异体现在碰撞/嘴部判定与视觉缩放等。 |
| P8 | Boost 人人相同规则 | 相同时长的 ×2 线速与相同 CD；AI 仅决策逻辑不同。 |

---

## 3. Core gameplay loop

```
看数字 / 称号 → 判断追谁躲谁 →（可选）开 Boost 抢位或逃生
        ↓
撞小鱼 → 吃 → size 涨（rostered）或仅 size 涨（CatchUp，无 bonus）
        ↓
rostered 达 target → frozen → 再吃只涨 bonus
        ↓
全体 rostered 均 frozen → 通关 → 下一关（含原 CatchUp 升为 rostered）
        ↓
超时仍有 rostered 未 frozen → SESSION END → 结算 → Level 1 重置
```

---

## 4. Entities & participation

### 4.1 Player fish（通用）

| Property | Spec |
|----------|------|
| `size` | 非负整数；吃法见 §5。 |
| `bonus` | 仅 **rostered** 且在 **frozen** 后吃鱼才累加；**CatchUp** 在本关 `bonus` 不增加（保持 0）。 |
| `frozen` | **仅 rostered**：某次吃鱼后 `size ≥ target_N` → 锁定为该次吃后的值（**允许 overshoot**），之后吃鱼只涨 `bonus`。 |
| Death | 被 **严格大于** 自己的玩家或 AI 吃掉。 |
| Respawn | **size 不变**；位置：安全区内随机，距任意 **更大** 的玩家/AI ≥ 50 studs（数值可调）。 |
| `lane` | `Rostered` \| `CatchUp`（见 §4.3）。 |

### 4.2 AI fish

| Property | Spec |
|----------|------|
| `size` | 关卡生成器写入。 |
| 吃 AI/被吃 | AI **互吃**仅当严格更大；被吃后 **同 size 立即 auto-respawn** 一条（1:1）。**MVP 默认**：AI **不因吃掉任何鱼（含玩家）而增加自身 `size`**，避免 AI 滚雪球；玩家被吃仍走 §7 惩罚与时间损失。playtest 若需要「AI 吃人变大」可再改。 |
| 行为 | MVP：**简单 boid** — 近处追更小、逃更大，否则随机游走（调参）。 |

### 4.3 `Rostered` vs `CatchUp`（中途加入）

**`LevelParticipants`（rostered）**

- 在 **关卡 L 正式开始瞬间** 已连接并完成本关参与资格的玩家集合（**精确时刻由实现定义**，建议：`LevelRunning` 状态机进入 `Playing` 的同一帧，或「倒计时开始」边界）。
- 仅 **rostered** 计入：**「在 `time_limit_L` 内全部达到 frozen」** 的通关条件。
- **断线**：rostered 玩家 **断开连接** 后，从本关 **分母中移除**（不再要求其 frozen）；文档化并接受「故意断线帮全队过关」边缘行为，MVP 不防。

**`CatchUp`**

- 在 **关卡 L 已开始之后** 才进入可玩状态的玩家，标记为 `CatchUp`（直到 L 结束边界）。
- **可立即游玩**：可吃 AI、可 PvP、**`size` 按 §5 正常变化**（含吃玩家）；**本关不参与通关判定**；**本关 `bonus` 不增加**。
- **达 target**：**不**使本关通关；可不进入与 rostered 相同的「全队胜利」frozen 语义，或仅 UI 弱化展示（实现可选）。
- **升入 L+1**：L 通关瞬间，本关所有 `CatchUp` **转为下一关的 rostered**（新关重新快照 `LevelParticipants`）。

**中途加入 — 初始 `size`**

1. **主规则**：加入并成为 `CatchUp` 时，`size =` 场上所有 **人类玩家**（含 rostered / 其他 CatchUp，**不含 AI**）当前 `size` 的 **最小值**（同一时刻快照）。  
2. **兜底**：若无其他人类玩家可比（例如曾有人闪退），则  
   `size = min { 每个「曾在本关 L 成为过 rostered 或 CatchUp」的玩家在本关 L 的 **关卡起始 size** }`  
   服务器须在玩家 **被认定进入关卡 L 的最早时刻** 写入 `{ userId, levelId, levelStartSize }`，保证闪退后仍有历史可查。  
3. **首名玩家**：session 首次进入 Level 1 的 rostered 默认 `size = 10`。

### 4.4 同体型判定

**严格大于才能吃**，例外：

- 玩家 vs AI 同 `size` → **玩家吃 AI**。  
- AI vs AI 同 `size` → 不互吃。  
- 玩家 vs 玩家同 `size` → **不互吃**。

---

## 5. Sizing, eating & anti-exploit

### 5.1 头顶展示

见 §9：数字（K/M/B…）+ tier 称号；rostered frozen 可加 `❄` 等标记。

### 5.2 碰撞结果矩阵（摘要）

| 情境 | 严格大吃小 | 同 `size` |
|------|------------|-----------|
| Player → AI | 吃（rostered：`size`/`bonus` 按 frozen；CatchUp：只涨 `size`） | 玩家吃 AI |
| AI → Player | AI吃玩家 → 玩家 respawn | 玩家不被吃 |
| AI → AI | 大吃小，被吃方 AI **respawn** 同 `size` | 无事 |
| Player → Player | 大吃小，吃方按 frozen 路径加 `size` 或 `bonus`；被吃方 **无 size 惩罚** respawn | 不互吃 |

**`CatchUp` 吃 rostered / 互吃**：**全开 PvP**，奖励规则与上表一致；**`CatchUp` 本关仍不涨 `bonus`**。

### 5.3 AI auto-respawn

同 v2：任意 AI 被吃 → 随机安全点立刻 **1:1** 同 `size` 重生；与关卡可解性论证配套。

### 5.4 Frozen / bonus（仅 rostered）

| 阶段 | 行为 |
|------|------|
| 未 frozen | 吃鱼 → `size += eaten_size`（`eaten_size` 为被吞对象当时的 `size` 或设计规定的数值） |
| 跨越 target 的那一口 | `size` 锁为该口之后的值 → `frozen = true` |
| frozen 后 | 吃鱼 → `bonus += eaten_size`，`size` 不变 |
| frozen 被吃 | 仍会发生死亡/复活；复活后 `size` 仍为 freeze 值，`frozen` 保持 |

### 5.5 捕食奖励抑制（玩家受害者 debuff）

- **仅人类玩家**作为受害者、且为 **玩家间或 AI 吃玩家** 的链路：玩家死亡并 **respawn 完成** 后起算 **10 秒** debuff。  
- **此 10 秒内** 若该玩家 **再被吃掉**，**捕食者**（AI 或玩家）**不得**获得任何收益：**无 `size`、无 `bonus`**。  
- **非无敌**：仍可被吃、仍正常死亡与复活。  
- 每次死亡后 **重新** 起算一段 10 秒窗。  
- **AI 鱼** 无此 debuff；吃 AI 的奖励规则不受 debuff 影响。  
- **与 Boost**：默认无额外交互。

---

## 6. Level system

### 6.1 Server-wide 状态

同服共享：`level`、`target_N`、`time_limit_N` 倒计时、AI 生成列表、session 阶段机。

### 6.2 通关条件

在 `time_limit_N` 内，**每一名仍在连接中的 `LevelParticipants`（rostered）** 均达到 `frozen`（即各自 `size ≥ target_N`）。  
**`CatchUp` 不参与此判定。**

通关 UI：关卡 clearance、本关 bonus 小榜（仅 rostered 有 bonus）、过渡至 L+1。

### 6.3 失败条件

倒计时结束，**仍存在未 `frozen` 的已连接 rostered** → server-wide fail → session 结束流程（§6.5）。

### 6.4 `S_min_N` 与难度公式（rostered-only）

| 符号 | 定义 |
|------|------|
| `S_min_N` | 本关 **关卡开始时** 全体 **rostered** 入场 `size` 的 **最小值**（不含 CatchUp）。 |

| 维度 | 公式（初值，待 playtest） |
|------|---------------------------|
| `target_N` | `S_min_N × 5` |
| `time_limit_N` | `90 + level × 15` 秒 |
| `quota_N`（AI 条数） | `max(ceil(target_N / avg_AI_size × 1.5), 8)`（`avg_AI_size` 为生成器期望均值，可调） |
| `max_AI_size_N` | `target_N × 0.8` |
| AI `size` 分布 | `[1, max_AI_size_N]` 对数偏好，小鱼多、大鱼少 |

### 6.5 Session 模型（play-until-fail）

| 事件 | 行为 |
|------|------|
| 首名（批）玩家使 server 开始 session | Level 1，`rostered` 默认 `size = 10`（或设计表） |
| 关卡 L 通关 | 进入 L+1；原 `CatchUp` **全部** 变为 L+1 的 **rostered**（新快照） |
| 关卡 L 失败 | Session 结束 → 结算 UI（建议 ~30s）→ `level=1`、全员 `size`/`bonus` 等按设计重置 |
| 全员离开 server | Roblox 结束实例；无持久化则进度不保留（MVP 无 DataStore） |

### 6.6 可解性（生成器义务）

给定本关 `S_min_N`、`target_N` 及 AI 参数，生成器须保证：存在一条仅通过吃 **严格更小** 的 AI（及规则允许的 PvP）路径，使 `S_min_N` 的 rostered 能涨至 `target_N`。构造「成长链」+ 对数填充的做法同 v2 思路；AI 1:1 respawn 保持可吃质量不枯竭。

---

## 7. Death & respawn

| 触发 | 行为 |
|------|------|
| 被吃 | 立即进入死亡流程 |
| 复活延迟 | 约 1–2 s（动画 + 音效） |
| 复活后 `size` | **等于死亡瞬间的 `size`** |
| debuff | 见 §5.5（从 **respawn 完成** 起算） |

---

## 8. Multiplayer, PvP & Roblox 实例

### 8.1 架构

每个匹配 server = 一个 session；共享世界、共享关卡时钟。

### 8.2 PvP

- 玩家间 **严格大吃小**；同 `size` 不互吃。  
- **CatchUp** 与 **rostered** 间 **无 PvP 限制**（全开）。  
- 奖励：`CatchUp` **本关无 `bonus`**；`size` 变化仍按 §5（除非后续改设计）。

### 8.3 Server 生命周期（与「至少一名玩家」）

- Roblox 在 **无玩家** 时会结束该 server 进程；**不会**长期空跑。  
- 设计假设：**开始推进关卡逻辑时场上至少有一名真人**（首连玩家开 Level 1）。  
- 「只要没人失败 server 就一直在」**不成立**：全员离开即实例结束。

### 8.4 Server 人数

建议 **6–8** 人/实例（playtest 可调）。

---

## 9. UI / UX（低龄友好）

### 9.1 Tier 称号与颜色

同 v2 表（小鱼级 → … → 海怪级；≥5e7 可 TBD）。

### 9.2 数字格式

0–999 原样；10³–10⁶−1 用 `K`；10⁶–10⁹−1 用 `M`；更高 `B`/`T`。与 tier 并排显示。

### 9.3 HUD（增补）

| 元素 | 说明 |
|------|------|
| `CatchUp` 标识 | 明显标签（如「练习 / 迟到加入」），避免「我已经很大为何不过关」的困惑 |
| Boost | 全玩家：能量/图标 + **冷却环**（必做，低龄需要可读反馈） |
| 其余 | Level、Target、倒计时、个人 size/进度、bonus（rostered frozen 后）、简易玩家列表 |

### 9.4 反馈与鱼模型缩放

吃鱼 / 被吃 / tier 提升 / frozen / 通关 / 失败：音效 + 轻量屏幕反馈。  
**视觉鱼模型**：按 tier **离散**缩放；**与线速度解耦**。

---

## 10. Mobility — 基础移速与 Boost

### 10.1 基础线速度

- **所有玩家与 AI** 共享同一套 **基础平移速度常量**（或极少档位，**不**随 `size` 绑定）。  
- **允许**随 `size` 变化的东西：**碰撞盒/嘴部判定**、模型缩放、（可选）转向手感 — 若需「转向也不随体型变」须单独开需求。

### 10.2 Boost（玩家输入 + AI 决策）

| 项 | 规则 |
|----|------|
| 效果 | **5 秒**内，**线速度 ×2（+100%）** |
| 冷却 | **10 秒**，从 **5 秒效果结束瞬间** 开始计时 → 两次可用之间最短 **15 秒**（自按下起算） |
| 叠层 | **不叠**；生效中或 CD 内忽略重复触发 |
| 权威 | **Server 校验时间戳** 后应用倍率 |
| 输入 | PC 键位待定（如 `LeftShift`/`Q`）；**手机** 独立按钮；手柄待定 |

**AI Boost（必须「不太聪明」）**

- **禁止**把主策略写成「即将被严格更大的鱼吃到 → **必** 开 Boost」。  
- **推荐 MVP**：CD 就绪时，每 **1–2 s** 心跳做一次 **小概率随机** 触发（多数为浪费 CD）；可选 **弱恐慌**：附近有更大鱼时 **略微** 提高概率，但 **大部分** 危险局面仍不触发，且 **禁止** 逼近即 100% 开。  
- 若随机到「恐慌开」，加 **0.2–0.8 s** 随机反应延迟再进入 5s 效果，避免帧级完美逃生。  
- 调参：`p`、感知半径 `R`、恐慌贡献上限等。

---

## 11. Future / non-MVP

### 11.1 Robux（MVP 不做；未来仍计划）

保留 v2 表格意向；**注意**：server-wide 下「个人跳关」不合理，若做付费需重新设计为装饰、金币化能力或全队共识机制。

### 11.2 其它

皮肤、DataStore 排行、任务、私人服等。

---

## 12. Resolved & remaining knobs

| 项 | 状态 |
|----|------|
| OQ-1 玩家同 `size` | 不互吃 — **已定** |
| OQ-2 AI 行为 | 简单 boid — **MVP 默认** |
| OQ-5 PvP 转移 | 给吃方；按吃方是否 frozen 走 `size` 或 `bonus` — **已定** |
| OQ-7 生僻字 tier | MVP 维持汉字；注音可后加 |
| N6 社交风险 | **用户选择接受**，无额外缓和；备选措施保留在 v2 §13 思路中供日后启用 |
| N7 互喂 | **已由 §5.5 缓解**（非完全禁止玩法，只抑制收益窗口） |
| N8 frozen 被吃 | MVP 维持简单规则 |
| N9 人数上限 | playtest |

**仍须在实现时拍板的细项（非阻塞）**：`LevelParticipants` 快照的 **精确帧**；`CatchUp` 是否在 `size ≥ target` 时显示类 frozen 纯 UI；PC Boost 默认键位。

---

## 13. Out of scope for MVP

- 任何 Robux / 真钱付费  
- DataStore 长期存档、跨服排行  
- 装饰皮肤、任务、组队、私人锦标赛服  
- Tier 注音、高级 AI Boss  
- **额外** 的 PvP 收益限制（MVP 仅有 §5.5 + Boost 规则）

---

## 14. Known issues & playtest backlog

- `CatchUp` + 全开 PvP：刷分、关尾干扰 — **接受风险**。  
- 断线剔除分母：可能被滥用 — MVP 不防。  
- AI Boost 调参：过弱则 AI 呆，过强则像作弊 — 需遥测与手感迭代。

---

*文档结束。实现分层与模块边界见 `docs/ARCHITECTURE.md`。*
