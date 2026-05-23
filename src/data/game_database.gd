## 全局数据加载：卡牌、敌人、角色、遗物
extends Node

var cards: Dictionary = {}
var enemies: Dictionary = {}
var characters: Dictionary = {}
var relics: Dictionary = {}


func _ready() -> void:
	_load_json_dir("res://src/data/cards/cards.json", cards, "id", CardData.from_dict)
	_load_json_enemies("res://src/data/enemies/enemies.json")
	_load_json_dir("res://src/data/characters/characters.json", characters, "id")
	_load_json_dir("res://src/data/relics/relics.json", relics, "id")


func _load_json_dir(path: String, target: Dictionary, key_field: String, factory: Callable = Callable()) -> void:
	if not FileAccess.file_exists(path):
		push_warning("数据文件不存在: %s" % path)
		return
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if parsed == null:
		push_error("JSON 解析失败: %s" % path)
		return
	var arr: Array = parsed if parsed is Array else parsed.get("items", [])
	for item in arr:
		if not item is Dictionary:
			continue
		var key: String = item.get(key_field, "")
		if factory.is_valid():
			target[key] = factory.call(item)
		else:
			target[key] = item


func _load_json_enemies(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if parsed == null:
		return
	for item in parsed:
		if item is Dictionary:
			enemies[item.get("id", "")] = item


func get_card(id: String) -> CardData:
	return cards.get(id, null) as CardData


func get_enemy(id: String) -> Dictionary:
	return enemies.get(id, {})


func get_character(id: String) -> Dictionary:
	return characters.get(id, {})


func get_relic(id: String) -> Dictionary:
	return relics.get(id, {})


