# 虚空塔 (Void Tower)

Godot 4.x 卡牌构筑 Roguelike 原型。

## 语言切换

在 `src/game_flow.gd` 顶部修改 `USE_CHINESE`。

- 中文：`UiFonts` 加载 `assets/fonts/NotoSansSC-Regular.otf` 并应用到全部 UI（含地图 `draw_string`）
- 英文：Godot 默认字体
- JSON 双语字段：`name` / `name_zh` 等

## 美术素材

卡牌 UI 使用 [Kenney](https://kenney.nl) CC0 素材（已放入 `assets/cards/`），见 `assets/cards/CREDITS.txt`。

## 运行

Godot 4.2+ 打开本目录，F5 运行 `scenes/main.tscn`。首次打开会导入 PNG，稍等片刻。

## 操作

1. 开始爬塔 → 点击 **起始** / 高亮节点
2. **商店**：购买卡牌、移除牌（75金）、离开商店继续
3. **战斗**：点击卡牌 UI 出牌，先选目标 → **结束回合**
