# Session log

Append-only history of what each Cursor agent session accomplished. **Newest entry on top.**

Format: a dated section per session with `Goal`, `Done`, `State at end`, `Pending / next session`.

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
