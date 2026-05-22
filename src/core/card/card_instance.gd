## 牌库中的一张卡实例（可升级、可刻印）
class_name CardInstance
extends RefCounted

var base_id: String = ""
var data: CardData = null
var upgraded: bool = false
## 刻印槽（原型先留接口）
var rune_slots: Array[String] = ["", ""]


func _init(card_id: String, db: Node) -> void:
	base_id = card_id
	data = db.get_card(card_id)
	if data and data.upgrade_id != "":
		# 预留升级链
		pass


func get_display_name() -> String:
	if data == null:
		return base_id
	return data.get_display_name() + ("+" if upgraded else "")


func get_data() -> CardData:
	if upgraded and data and data.upgrade_id != "":
		return data  # 升级后应切换 id，由 battle 处理
	return data
