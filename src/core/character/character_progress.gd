## 角色解锁进度（user:// 持久化，便于后续 BOSS 通关解锁等）
extends Node

const SAVE_PATH := "user://void_tower_unlocks.json"

var _unlocked_ids: Array[String] = []


func _ready() -> void:
	_load()


func is_unlocked(character_id: String) -> bool:
	var cfg := GameDB.get_character(character_id)
	if cfg.is_empty():
		return false
	if cfg.get("unlocked_by_default", false):
		return true
	return character_id in _unlocked_ids


func unlock(character_id: String) -> void:
	if character_id in _unlocked_ids:
		return
	_unlocked_ids.append(character_id)
	_save()


func _load() -> void:
	_unlocked_ids.clear()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if parsed is Dictionary:
		var arr: Array = parsed.get("unlocked", [])
		for id in arr:
			_unlocked_ids.append(str(id))


func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"unlocked": _unlocked_ids}))
