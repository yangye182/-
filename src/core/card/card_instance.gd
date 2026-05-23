## 牌库中的一张卡实例（可进化、可刻印）
class_name CardInstance
extends RefCounted

var base_id: String = ""
var data: CardData = null
var upgraded: bool = false
## 进化后指向的卡牌 ID（为空表示未进化）
var evolved_to_id: String = ""
## 刻印槽（原型先留接口）
var rune_slots: Array[String] = ["", ""]


func _init(card_id: String, db: Node) -> void:
	base_id = card_id
	data = db.get_card(card_id)


func get_display_name() -> String:
	if data == null:
		return base_id
	return data.get_display_name() + ("+" if upgraded else "")


## 返回当前生效的 CardData（已进化则返回进化后的卡牌数据）
func get_data() -> CardData:
	if evolved_to_id != "":
		var evolved := GameDB.get_card(evolved_to_id)
		if evolved:
			return evolved
	return data


## 获取进化后的卡牌 ID，不改变 base_id（用于追踪初始牌）
func get_evolved_id() -> String:
	return evolved_to_id if evolved_to_id != "" else base_id


## 获取可选的进化分支列表（返回 [{id, cost, desc_en, desc_zh}]）
func get_evolve_options() -> Array[Dictionary]:
	if data == null:
		return []
	return data.evolves_to.duplicate()


## 是否能进化
func can_evolve() -> bool:
	return evolved_to_id == "" and data != null and not data.evolves_to.is_empty()


## 选择进化分支。branch_index 是 evolves_to 数组的索引。
## 返回 true 表示进化成功。
func evolve(branch_index: int) -> bool:
	if not can_evolve():
		return false
	if branch_index < 0 or branch_index >= data.evolves_to.size():
		return false
	var branch: Dictionary = data.evolves_to[branch_index]
	evolved_to_id = branch.get("id", "")
	if evolved_to_id == "":
		return false
	# 可选：进化后替换实际 data 引用，方便后续显示
	var evolved_data := GameDB.get_card(evolved_to_id)
	if evolved_data:
		data = evolved_data
	return true
