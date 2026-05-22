## 场景流转：主菜单 → 地图 → 战斗/事件
extends Control

## true = 中文 + 内嵌 Noto 字体；false = 英文 + Godot 默认字体
const USE_CHINESE := true

enum Scene { MENU, MAP, BATTLE, SHOP }

var current_scene: Scene = Scene.MENU
var pending_enemies: Array[String] = []
var pending_rift_rule: String = ""

@onready var menu_layer: Control = $MenuLayer
@onready var map_layer: Control = $MapLayer
@onready var battle_layer: Control = $BattleLayer
@onready var shop_layer: Control = $ShopLayer


func _ready() -> void:
	_apply_ui_font()
	shop_layer.shop_finished.connect(_on_shop_finished)
	_show_menu()


func _apply_ui_font() -> void:
	GameLocale.use_chinese = USE_CHINESE
	UiFonts.apply_root_theme(USE_CHINESE)


func _show_menu() -> void:
	current_scene = Scene.MENU
	menu_layer.visible = true
	map_layer.visible = false
	battle_layer.visible = false
	shop_layer.visible = false


func start_new_run() -> void:
	RunState.start_new_run()
	RunState.map_nodes = MapGenerator.generate()
	RunState.current_node_id = 0
	_open_map()


func _open_map() -> void:
	current_scene = Scene.MAP
	menu_layer.visible = false
	map_layer.visible = true
	battle_layer.visible = false
	shop_layer.visible = false
	map_layer.refresh()


func _open_shop() -> void:
	current_scene = Scene.SHOP
	menu_layer.visible = false
	map_layer.visible = false
	battle_layer.visible = false
	shop_layer.visible = true
	shop_layer.open_shop()


func _on_shop_finished() -> void:
	var n: MapNodeData = RunState.map_nodes[RunState.current_node_id]
	MapProgress.advance_from(n, RunState.map_nodes)
	_open_map()


func enter_node(node_id: int) -> void:
	var nodes: Array = RunState.map_nodes
	if node_id < 0 or node_id >= nodes.size():
		return
	var n: MapNodeData = nodes[node_id]
	if not MapProgress.can_enter(n):
		return
	n.visited = true
	RunState.current_node_id = node_id
	match n.type:
		MapNodeData.NodeType.START:
			MapProgress.advance_from(n, nodes)
			_open_map()
		MapNodeData.NodeType.COMBAT:
			MapProgress.lock_all(nodes)
			pending_enemies = _make_enemy_ids("rust_sentinel")
			pending_rift_rule = ""
			_start_battle()
		MapNodeData.NodeType.ELITE:
			MapProgress.lock_all(nodes)
			pending_enemies = _make_enemy_ids("rust_sentinel_elite")
			pending_rift_rule = ""
			_start_battle()
		MapNodeData.NodeType.VOID_RIFT:
			MapProgress.lock_all(nodes)
			pending_enemies = _make_enemy_ids("stone_golem")
			pending_rift_rule = n.rift_rule
			_start_battle()
		MapNodeData.NodeType.BOSS:
			MapProgress.lock_all(nodes)
			pending_enemies = _make_enemy_ids("rust_colossus")
			pending_rift_rule = ""
			_start_battle()
		MapNodeData.NodeType.REST:
			RunState.heal_percent(0.3)
			MapProgress.advance_from(n, nodes)
			_open_map()
		MapNodeData.NodeType.SHOP:
			MapProgress.lock_all(nodes)
			_open_shop()
		MapNodeData.NodeType.EVENT:
			RunState.gold += 20
			MapProgress.advance_from(n, nodes)
			_open_map()
		MapNodeData.NodeType.RUNE_FORGE, MapNodeData.NodeType.SAGE_ALTAR:
			MapProgress.advance_from(n, nodes)
			_open_map()
		_:
			MapProgress.advance_from(n, nodes)
			_open_map()


func _make_enemy_ids(enemy_id: String) -> Array[String]:
	var ids: Array[String] = []
	ids.append(enemy_id)
	return ids


func _start_battle() -> void:
	current_scene = Scene.BATTLE
	menu_layer.visible = false
	map_layer.visible = false
	shop_layer.visible = false
	battle_layer.visible = true
	battle_layer.start_battle(pending_enemies, pending_rift_rule)


func on_battle_finished(victory: bool) -> void:
	if victory:
		var n: MapNodeData = RunState.map_nodes[RunState.current_node_id]
		if n.type == MapNodeData.NodeType.BOSS:
			# 通关回到主菜单
			_show_menu()
			return
		MapProgress.unlock_children_from(n, RunState.map_nodes)
		_open_map()
	else:
		_show_menu()
