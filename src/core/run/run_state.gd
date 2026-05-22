## 单次爬塔运行状态（局内存档）
extends Node

signal run_started
signal floor_changed

const STARTING_DECK: Array[String] = [
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
var character_id: String = "void_knight"
var tower_spirit_id: String = "ash_raven"

## 地图节点（由 MapGenerator 填充）
var map_nodes: Array = []
var current_node_id: int = 0


func start_new_run() -> void:
	var cfg := GameDB.get_character(character_id)
	max_hp = int(cfg.get("max_hp", 70))
	current_hp = max_hp
	gold = 50
	floor_index = 0
	deck_ids = STARTING_DECK.duplicate()
	relic_ids.clear()
	relic_ids.append("knight_oath")
	current_node_id = 0
	run_started.emit()


func has_relic(id: String) -> bool:
	return id in relic_ids


func build_deck_instances() -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	for cid in deck_ids:
		result.append(CardInstance.new(cid, GameDB))
	return result


func add_card_to_deck(card_id: String) -> void:
	deck_ids.append(card_id)


func heal_percent(p: float) -> void:
	current_hp = mini(current_hp + int(max_hp * p), max_hp)
