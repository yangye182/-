## 单次爬塔运行状态（局内存档）
extends Node

signal run_started

## 无 JSON 配置时的兜底初始牌组
const FALLBACK_DECK: Array[String] = [
	"strike", "strike", "strike", "strike", "strike",
	"defend", "defend", "defend", "defend",
	"ember_slash",
]

var current_hp: int = 70
var max_hp: int = 70
var gold: int = 0
var floor_index: int = 0
var deck_ids: Array[String] = []
var relic_ids: Array[String] = []
## 进化映射："strike@2" → "heavy_strike"（第2张打击进化成了重击）
var evolution_map: Dictionary = {}
var character_id: String = "void_knight"
var tower_spirit_id: String = "ash_raven"

## 地图节点（由 MapGenerator 填充）
var map_nodes: Array = []
var current_node_id: int = 0


func start_new_run(selected_character_id: String = "") -> void:
	if selected_character_id != "":
		character_id = selected_character_id
	var cfg := GameDB.get_character(character_id)
	if cfg.is_empty():
		character_id = "void_knight"
		cfg = GameDB.get_character(character_id)
	max_hp = int(cfg.get("max_hp", 70))
	current_hp = max_hp
	gold = int(cfg.get("starting_gold", 50))
	floor_index = 0
	deck_ids = _starting_deck_from_cfg(cfg)
	evolution_map.clear()
	relic_ids = CharacterRoster.get_starting_relics(cfg)
	tower_spirit_id = str(cfg.get("tower_spirit_id", "ash_raven"))
	current_node_id = 0
	run_started.emit()


func _starting_deck_from_cfg(cfg: Dictionary) -> Array[String]:
	var deck := CharacterRoster.get_starting_deck(cfg)
	if deck.is_empty():
		return FALLBACK_DECK.duplicate()
	return deck


func has_relic(id: String) -> bool:
	return id in relic_ids


func build_deck_instances() -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	var counter: Dictionary = {}
	for cid in deck_ids:
		counter[cid] = counter.get(cid, 0) + 1
		var key := "%s@%d" % [cid, counter[cid]]
		var inst := CardInstance.new(cid, GameDB)
		if evolution_map.has(key):
			inst.evolved_to_id = evolution_map[key]
			var ed := GameDB.get_card(inst.evolved_to_id)
			if ed:
				inst.data = ed
		result.append(inst)
	return result


func add_card_to_deck(card_id: String) -> void:
	deck_ids.append(card_id)


func add_relic(relic_id: String) -> void:
	if relic_id not in relic_ids:
		relic_ids.append(relic_id)


## 牌组中去重后的卡牌 id（保持首次出现顺序）
func get_unique_deck_ids() -> Array[String]:
	var seen: Dictionary = {}
	var result: Array[String] = []
	for cid in deck_ids:
		if cid in seen:
			continue
		seen[cid] = true
		result.append(cid)
	return result


func count_cards(card_id: String) -> int:
	var n := 0
	for cid in deck_ids:
		if cid == card_id:
			n += 1
	return n


## 将牌组中所有 from_id 替换为 to_id，返回替换张数
func evolve_card_type(from_id: String, to_id: String) -> int:
	var replaced := 0
	for i in deck_ids.size():
		if deck_ids[i] == from_id:
			deck_ids[i] = to_id
			replaced += 1
	return replaced


## 进化牌组中指定索引的卡牌，返回是否成功
func evolve_card_at(deck_index: int, evolved_id: String) -> bool:
	if deck_index < 0 or deck_index >= deck_ids.size():
		return false
	var cid := deck_ids[deck_index]
	var counter := 0
	for i in range(deck_index + 1):
		if deck_ids[i] == cid:
			counter += 1
	var key := "%s@%d" % [cid, counter]
	evolution_map[key] = evolved_id
	return true


func heal_percent(p: float) -> void:
	current_hp = mini(current_hp + int(max_hp * p), max_hp)
