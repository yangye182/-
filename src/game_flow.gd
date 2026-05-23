## 场景流转：主菜单 → 选人 → 地图 → 战斗/事件
extends Control

## true = 中文 + 内嵌 Noto 字体；false = 英文 + Godot 默认字体
const USE_CHINESE := true

## 楼层敌人池配置
const FLOOR_POOLS := [
	null,  # index 0 unused
	# floor 1-3
	{ "combat": ["rust_sentinel", "shadow_acolyte", "void_crawler"], "elite": ["rust_sentinel_elite"], "hp_scale": 1.0 },
	# floor 4-6
	{ "combat": ["shadow_acolyte", "void_crawler", "crystal_spike"], "elite": ["shadow_priest", "void_behemoth"], "hp_scale": 1.3 },
	# floor 7-8
	{ "combat": ["void_crawler", "crystal_spike"], "elite": ["void_behemoth", "crystal_warden"], "hp_scale": 1.6 },
]

const BOSS_POOL := ["rust_colossus", "shadow_lord", "void_dragon"]


static func _get_floor_config(layer_index: int) -> Dictionary:
	# 16 层地图：前期 1~5、中期 6~11、后期 12~14
	if layer_index <= 5:
		return FLOOR_POOLS[1]
	elif layer_index <= 11:
		return FLOOR_POOLS[2]
	else:
		return FLOOR_POOLS[3]


static func _pick_from_pool(pool: Array) -> String:
	return pool[randi() % pool.size()]


static func _make_combat_enemies(layer_index: int) -> Array[String]:
	var cfg := _get_floor_config(layer_index)
	var pool: Array = cfg["combat"]
	var ids: Array[String] = []
	ids.append(_pick_from_pool(pool))
	ids.append(_pick_from_pool(pool))
	return ids


static func _make_elite_enemies(layer_index: int) -> Array[String]:
	var cfg := _get_floor_config(layer_index)
	var pool: Array = cfg["elite"]
	return [_pick_from_pool(pool)]


static func _make_boss_enemies() -> Array[String]:
	return [BOSS_POOL[randi() % BOSS_POOL.size()]]


static func _get_hp_scale(layer_index: int) -> float:
	var cfg := _get_floor_config(layer_index)
	return float(cfg.get("hp_scale", 1.0))


enum Scene { MENU, CHARACTER_SELECT, MAP, BATTLE, SHOP, SAGE_ALTAR }

var current_scene: Scene = Scene.MENU
var pending_enemies: Array[String] = []
var pending_rift_rule: String = ""
var pending_hp_scale: float = 1.0

@onready var menu_layer: Control = $MenuLayer
@onready var character_select_layer: Control = $CharacterSelectLayer
@onready var map_layer: Control = $MapLayer
@onready var battle_layer: Control = $BattleLayer
@onready var shop_layer: Control = $ShopLayer
@onready var event_layer: Control = $EventLayer
@onready var backpack_layer: Control = $BackpackLayer
@onready var sage_layer: Control = $SageAltarLayer
@onready var reward_layer: Control = $RewardLayer


func _ready() -> void:
	_apply_ui_font()
	character_select_layer.run_confirmed.connect(_on_character_confirmed)
	character_select_layer.back_pressed.connect(_show_menu)
	shop_layer.shop_finished.connect(_on_shop_finished)
	event_layer.event_finished.connect(_on_event_finished)
	sage_layer.sage_finished.connect(_on_sage_finished)
	backpack_layer.backpack_closed.connect(_on_backpack_closed)
	map_layer.back_to_menu_pressed.connect(_show_menu)
	reward_layer.reward_finished.connect(_on_reward_finished)
	_show_menu()


func _apply_ui_font() -> void:
	GameLocale.use_chinese = USE_CHINESE
	UiFonts.apply_root_theme(USE_CHINESE)


func _hide_all_layers() -> void:
	menu_layer.visible = false
	character_select_layer.visible = false
	map_layer.visible = false
	battle_layer.visible = false
	shop_layer.visible = false
	event_layer.visible = false
	sage_layer.visible = false
	backpack_layer.visible = false
	reward_layer.visible = false


func _show_menu() -> void:
	current_scene = Scene.MENU
	_hide_all_layers()
	menu_layer.visible = true


func open_character_select() -> void:
	current_scene = Scene.CHARACTER_SELECT
	_hide_all_layers()
	character_select_layer.visible = true
	character_select_layer.open_select()


func _on_character_confirmed(character_id: String) -> void:
	start_run_with_character(character_id)


func start_run_with_character(character_id: String) -> void:
	RunState.start_new_run(character_id)
	RunState.map_nodes = MapGenerator.generate()
	RunState.current_node_id = 0
	_open_map()


func _open_map() -> void:
	current_scene = Scene.MAP
	_hide_all_layers()
	map_layer.visible = true
	map_layer.refresh()


func _open_shop() -> void:
	current_scene = Scene.SHOP
	_hide_all_layers()
	shop_layer.visible = true
	shop_layer.open_shop()


func _open_event() -> void:
	current_scene = Scene.MAP
	_hide_all_layers()
	event_layer.visible = true
	event_layer.open_event()


func open_backpack() -> void:
	if current_scene != Scene.MAP:
		return
	backpack_layer.visible = true
	backpack_layer.refresh()


func _on_backpack_closed() -> void:
	backpack_layer.visible = false
	if current_scene == Scene.MAP:
		map_layer.refresh()


func _open_sage_altar() -> void:
	current_scene = Scene.SAGE_ALTAR
	_hide_all_layers()
	sage_layer.visible = true
	sage_layer.open_altar()


func _on_sage_finished() -> void:
	var n: MapNodeData = RunState.map_nodes[RunState.current_node_id]
	MapProgress.advance_from(n, RunState.map_nodes)
	_open_map()


func _on_shop_finished() -> void:
	var n: MapNodeData = RunState.map_nodes[RunState.current_node_id]
	MapProgress.advance_from(n, RunState.map_nodes)
	_open_map()


func _on_event_finished() -> void:
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
			pending_enemies = _make_combat_enemies(n.layer_index)
			pending_rift_rule = ""
			pending_hp_scale = _get_hp_scale(n.layer_index)
			_start_battle()
		MapNodeData.NodeType.ELITE:
			MapProgress.lock_all(nodes)
			pending_enemies = _make_elite_enemies(n.layer_index)
			pending_rift_rule = ""
			pending_hp_scale = _get_hp_scale(n.layer_index)
			_start_battle()
		MapNodeData.NodeType.VOID_RIFT:
			MapProgress.lock_all(nodes)
			pending_enemies = _make_combat_enemies(n.layer_index)
			pending_rift_rule = n.rift_rule
			pending_hp_scale = _get_hp_scale(n.layer_index)
			_start_battle()
		MapNodeData.NodeType.BOSS:
			MapProgress.lock_all(nodes)
			pending_enemies = _make_boss_enemies()
			pending_rift_rule = ""
			pending_hp_scale = 1.0
			_start_battle()
		MapNodeData.NodeType.REST:
			RunState.heal_percent(0.3)
			MapProgress.advance_from(n, nodes)
			_open_map()
		MapNodeData.NodeType.SHOP:
			MapProgress.lock_all(nodes)
			_open_shop()
		MapNodeData.NodeType.EVENT:
			MapProgress.lock_all(nodes)
			_open_event()
		MapNodeData.NodeType.RUNE_FORGE:
			MapProgress.lock_all(nodes)
			_open_rune_forge()
		MapNodeData.NodeType.SAGE_ALTAR:
			MapProgress.lock_all(nodes)
			_open_sage_altar()
		_:
			MapProgress.advance_from(n, nodes)
			_open_map()


func _open_card_reward() -> void:
	battle_layer.visible = false
	reward_layer.visible = true
	reward_layer.open_reward()


func _open_rune_forge() -> void:
	map_layer.visible = false
	reward_layer.visible = true
	reward_layer.open_reward(2)


func _on_reward_finished() -> void:
	var n: MapNodeData = RunState.map_nodes[RunState.current_node_id]
	if n.type == MapNodeData.NodeType.RUNE_FORGE:
		MapProgress.advance_from(n, RunState.map_nodes)
	else:
		MapProgress.unlock_children_from(n, RunState.map_nodes)
	_open_map()




func _start_battle() -> void:
	current_scene = Scene.BATTLE
	_hide_all_layers()
	battle_layer.visible = true
	battle_layer.start_battle(pending_enemies, pending_rift_rule, pending_hp_scale)


func on_battle_finished(victory: bool) -> void:
	if victory:
		var n: MapNodeData = RunState.map_nodes[RunState.current_node_id]
		if n.type == MapNodeData.NodeType.BOSS:
			CharacterProgress.unlock("soul_pyromancer")
			if RunState.character_id == "void_knight":
				CharacterProgress.unlock("blade_assassin")
			_show_menu()
			return
		_open_card_reward()
	else:
		_show_menu()
