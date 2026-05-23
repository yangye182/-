---
noteId: "75b7a010566511f1ab806bf9dd2c7b99"
tags: []

---

# 敌人意图 BGM 提示词手册

> 《虚空塔》战斗 BGM 与敌人 **意图循环（pattern）** 一一对应。  
> 第一个 BOSS「锈蚀巨像」为 **6 拍循环 → 6 段 BGM**；后续怪物按本文 **模板** 追加即可。

---

## 使用说明

1. **一段意图 = 一条 BGM 提示词**（可生成 15～45 秒 loop，战斗时按当前意图切换）。
2. 提示词面向 **AI 音乐生成**（Suno、Udio、Stable Audio 等）或外包作曲 brief；可按工具加后缀如 `instrumental, no vocals, seamless loop`。
3. 项目统一基调见下方 **全局风格锚点**；每条怪物提示词 = 锚点 + 该拍情绪 + 技术参数。
4. 实现时建议文件名：`res://assets/audio/bgm/enemies/{enemy_id}/beat_{01-06}.ogg`。

---

## 全局风格锚点（所有战斗 BGM 共用）

复制到每条提示词开头，或作为 Style Reference：

```
Void Tower roguelike deckbuilder battle music, dark fantasy industrial ruin,
rusted metal and ancient stone cathedral ambience, tense but readable rhythm for turn-based combat,
orchestral hybrid with low brass, distorted cellos, metallic percussion, subtle choir pads,
minor key, 90-110 BPM, clear downbeat for UI intent telegraph, no sudden drops that hide attack windup,
instrumental only, seamless loop friendly, game OST quality
```

中文简述（给国内工具）：虚空塔、锈蚀遗迹、回合制卡牌、黑暗奇幻工业废墟、管弦+金属打击、小调、可循环、无歌词。

---

## BOSS：锈蚀巨像 `rust_colossus`

| 拍序 | 意图 | 数值 | 玩家感受 | BGM 角色 |
|------|------|------|----------|----------|
| 1 | 碾压 Crush | 10 攻 | 稳压、常规威胁 | **主题建立** |
| 2 | 铁壁 Iron Wall | 15 防 | 喘息、蓄力窗口 | **压抑留白** |
| 3 | 震地 Quake | 16 攻 | 周期高峰、必须应对 | **高潮打击** |
| 4 | 锈蚀 Rust | debuff | 不安、费用被污染 | **腐蚀异化** |
| 5 | 横扫 Sweep | 12 攻 | 余波、未结束 | **追击紧迫** |
| 6 | 铁壁 Iron Wall | 15 防 | 循环将重启 | **轮回收束** |

**敌人 ID**：`rust_colossus`  
**循环长度**：6 拍（与 `enemies.json` pattern 下标 0～5 对齐）

---

### Beat 01 — 碾压 Crush（主题建立）

**情绪**：巨像苏醒、脚步逼近、铁锈摩擦。  
**用途**：战斗切入默认曲 / 循环起点。

**英文提示词（主）**

```
Void Tower rust colossus boss battle beat 1 "Crush",
heavy slow footsteps of a giant iron golem, opening motif,
low brass stabs every 2 bars, rusted chain rattles, stone hall reverb,
90 BPM, minor key E minor, medium intensity, telegraph medium attack,
orchestral industrial hybrid, instrumental, seamless 30s loop, game battle OST
```

**中文提示词（备选）**

```
虚空塔锈蚀巨像BOSS战第1拍「碾压」，巨型铁像缓慢逼近，
低音铜管每两小节重击，铁链与锈屑摩擦，石厅混响，
90 BPM E小调，中等强度，30秒无缝循环，纯音乐游戏战斗配乐
```

**关键词标签**：`golem, stomp, brass, rust, medium threat, loop`

---

### Beat 02 — 铁壁 Iron Wall（压抑留白）

**情绪**：防御姿态、风声穿过铠甲缝隙、玩家获得思考空间。  
**用途**：格挡/叠甲回合，降低紧张度但不失压迫。

**英文提示词（主）**

```
Void Tower rust colossus boss battle beat 2 "Iron Wall",
defensive stance music, muted percussion, sustained low strings,
occasional metallic shield resonance, sparse melody, space for player planning,
85 BPM, same key, lower intensity than beat 1, calm before storm,
ambient industrial layer, instrumental, seamless 30s loop, turn-based combat BGM
```

**中文提示词（备选）**

```
虚空塔锈蚀巨像第2拍「铁壁」，防御姿态，
-muted 打击乐、持续低音弦、金属护盾共鸣，
稀疏旋律、给玩家思考空间，85 BPM 同调性、强度低于第1拍，
30秒循环纯音乐
```

**关键词标签**：`defense, shield, sparse, calm, planning phase`

---

### Beat 03 — 震地 Quake（高潮打击）

**情绪**：地板开裂、重锤砸地、本循环最强一击。  
**用途**：意图高峰，与 16 伤害对齐。

**英文提示词（主）**

```
Void Tower rust colossus boss battle beat 3 "Quake" climax,
massive ground impact, sub-bass drop, full orchestra hit with taiko and anvil percussion,
rising 4-bar tension then single devastating downbeat, highest intensity in 6-beat cycle,
100 BPM brief surge, E minor, cinematic boss attack moment,
instrumental, 20-35s loop with clear impact tail, game OST
```

**中文提示词（备选）**

```
虚空塔锈蚀巨像第3拍「震地」高潮，地面碎裂、重锤砸击，
低音下沉、管弦全奏+太鼓铁砧、四小节蓄力后单一毁灭重拍，
六拍循环中最高强度，100 BPM，20-35秒可循环
```

**关键词标签**：`climax, impact, quake, sub-bass, peak damage`

---

### Beat 04 — 锈蚀 Rust（腐蚀异化）

**情绪**：酸雾、齿轮卡死、旋律轻微走音/半音下滑。  
**用途**：debuff 回合，与「首张牌 +1 费」心理绑定。

**英文提示词（主）**

```
Void Tower rust colossus boss battle beat 4 "Rust" corruption,
unsettling debuff theme, detuned music box or glassy synth, acid hiss texture,
slightly dissonant intervals, slow 6/8 sway, metallic scraping rhythm,
creepy but not horror, 88 BPM, minor with flattened 5th color,
player discomfort for cost increase debuff, instrumental, seamless 30s loop
```

**中文提示词（备选）**

```
虚空塔锈蚀巨像第4拍「锈蚀」，不安的debuff曲，
走音音乐盒/玻璃合成器、酸雾嘶声、不协和半音、6/8缓慢摇摆、
金属刮擦节奏，诡异非恐怖，88 BPM，暗示费用惩罚
```

**关键词标签**：`debuff, rust, dissonance, corruption, unsettling`

---

### Beat 05 — 横扫 Sweep（追击紧迫）

**情绪**：巨臂横扫、未结束的危险、连续进攻感。  
**用途**：震地后的余波，12 伤害。

**英文提示词（主）**

```
Void Tower rust colossus boss battle beat 5 "Sweep" pursuit,
fast arpeggiated strings, driving eighth-note metallic percussion,
horizontal momentum feel like arm swipe, urgent but not full climax,
95 BPM, minor key, high-mid intensity between beat 3 and beat 1,
instrumental battle loop 25s, turn-based card game combat
```

**中文提示词（备选）**

```
虚空塔锈蚀巨像第5拍「横扫」，快速弦乐琶音、
金属八分音符驱动、横向挥扫动势、紧迫但非终极高潮，
95 BPM 25秒循环
```

**关键词标签**：`sweep, urgent, arpeggio, follow-up attack`

---

### Beat 06 — 铁壁 Iron Wall · 轮回收束（循环将重启）

**情绪**：与 Beat 02 同系但更「收束」——暗示循环回到 Beat 01。  
**用途**：第六拍结束时可 0.5 秒 crossfade 回 Beat 01。

**英文提示词（主）**

```
Void Tower rust colossus boss battle beat 6 "Cycle Close",
variant of iron wall theme, low strings fade with soft bell tone hinting loop restart,
final bar subtle riser pointing back to beat 1 motif, reflective and oppressive,
85 BPM, lowest percussion density in cycle, seamless loop into beat 1 on repeat,
instrumental game OST 30s
```

**中文提示词（备选）**

```
虚空塔锈蚀巨像第6拍「轮回收束」，铁壁变奏，
低音弦渐弱、软钟音暗示循环重启、末小节轻微上行接回第1拍动机，
压抑沉思，85 BPM，与第1拍无缝衔接
```

**关键词标签**：`cycle end, loop point, fade, return to theme`

---

### 锈蚀巨像 · 阶段/召唤（可选扩展轨）

若实现「每损失 25% HP 召唤哨兵」，**不占用 6 拍**，单独一条：

| 事件 | 文件名建议 | 说明 |
|------|------------|------|
| 召唤哨兵 | `summon_sentinel.ogg` | 短 sting 2～4 秒，不接主循环 |
| HP ≤ 50% 狂暴 | 替换为 `pattern_phase2/` 下另一套 4 拍 | 见策划 P2 |

**召唤 Sting 英文提示词**

```
Void Tower rust colossus summon sting, short 3 seconds,
forge spark burst, anvil hit, rising brass glitch, sentinel awakening cry (robotic not vocal),
transition cue not loop, game SFX-OSt hybrid
```

---

## 其他怪物填写模板（复制即用）

> 新增怪物时：先定 **N 拍 pattern** → 填下表 → 为每拍写一条「英文主 + 中文备选 + 标签」。

### 模板表

```markdown
## {敌人中文名} `{enemy_id}`

| 拍序 | 意图 type | 显示名 | 数值 | 玩家感受 | BGM 角色 |
|------|-----------|--------|------|----------|----------|
| 1 | | | | | |
| 2 | | | | | |
...

**循环长度**：N 拍  
**音频目录**：`res://assets/audio/bgm/enemies/{enemy_id}/beat_{NN}.ogg`

### Beat NN — {意图名}

**情绪**：
**用途**：

**英文提示词（主）**
\`\`\`
{全局风格锚点片段} + {本拍专属描述}
\`\`\`

**中文提示词（备选）**
\`\`\`
...
\`\`\`

**关键词标签**：`...`
```

---

## 示例：锈蚀哨兵 `rust_sentinel`（3 拍，练手）

| 拍序 | 意图 | BGM 角色 |
|------|------|----------|
| 1 | 挥砍 7 | 轻快威胁 |
| 2 | 重击 9 | 小高潮 |
| 3 | 锈蚀 | 异化 debuff |

**Beat 01 英文（简）**

```
Void Tower rust sentinel minion beat 1, quick slash motif, light brass, 100 BPM,
short 20s loop, industrial ruin, instrumental
```

**Beat 02**：重击 + 低音鼓。  
**Beat 03**：可复用巨像 Beat 04 锈蚀曲的 **短版** 或同一文件 pitch 变体。

---

## 实现备忘（Godot）

```gdscript
# 伪代码：敌人回合开始时按 pattern 下标切 BGM
var beat_idx := enemy_turn_index % pattern.size()
AudioManager.play_enemy_beat(enemy_id, beat_idx + 1)  # 1-based 对应 beat_01
```

- 切换建议 **0.3～0.8 秒 crossfade**，震地（Beat 03）可硬切强化冲击。  
- 同一敌人 6 条 loop **统一 BPM 区间**（85～100），避免听感断层。  
- `beat_06` 末小节与 `beat_01` 开头应对齐，方便无缝循环。

---

## 版本记录

| 日期 | 内容 |
|------|------|
| 2026-05-21 | 初版：锈蚀巨像 6 拍 BGM 提示词 + 通用模板 |
