# 虚空塔 (Void Tower)

Godot 4.x 卡牌构筑 Roguelike 原型。

## 语言切换

在 `src/game_flow.gd` 顶部修改 `USE_CHINESE`。

- 中文：`UiFonts` 加载 `assets/fonts/NotoSansSC-Regular.otf` 并应用到全部 UI（含地图 `draw_string`）
- 英文：Godot 默认字体
- JSON 双语字段：`name` / `name_zh` 等

## 美术素材

卡牌 UI 使用 [Kenney](https://kenney.nl) CC0 素材（已放入 `assets/cards/`），见 `assets/cards/CREDITS.txt`。

## 敌人 BGM 提示词

按意图循环为每个怪物编写 AI 作曲提示词，见 [`docs/enemy-bgm-prompts.md`](docs/enemy-bgm-prompts.md)（锈蚀巨像 6 拍完整示例 + 后续怪物模板）。

## 运行

Godot 4.2+ 打开本目录，F5 运行 `scenes/main.tscn`。首次打开会导入 PNG，稍等片刻。

## 操作

1. **开始爬塔** → **选择角色**（数据见 `src/data/characters/characters.json`）→ 确认后进入地图
2. 地图点 **起始** / 高亮节点继续

### 扩展新角色

在 `characters.json` 增加一条（`sort_order`、`starting_deck`、`starting_relics`、`unlocked_by_default` 等），重启游戏即可出现在选人界面。额外解锁写入 `user://void_tower_unlocks.json`（`CharacterProgress.unlock(id)`）。

3. **背包**（地图顶栏）：查看牌组与遗物
4. **贤者祭坛** / **商店** / **战斗**：沿地图节点进入（战斗：出牌 → **结束回合**）

**解锁**：击败 BOSS 解锁魂火术士；用虚空骑士通关解锁碎刃刺客。

进化配置见 `src/data/cards/evolutions.json`。

