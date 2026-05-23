## 贤者祭坛：可进化卡牌筛选与执行
class_name SageAltarService
extends RefCounted


## 当前牌组里、且配置了进化树的 base_id 列表
static func get_evolveable_ids() -> Array[String]:
	var result: Array[String] = []
	for cid in RunState.get_unique_deck_ids():
		if GameDB.has_evolution(cid):
			result.append(cid)
	return result


static func can_afford(base_id: String) -> bool:
	return RunState.gold >= GameDB.get_evolution_cost(base_id)


static func evolve(base_id: String, to_id: String) -> bool:
	var cost := GameDB.get_evolution_cost(base_id)
	if RunState.gold < cost:
		return false
	if GameDB.get_card(to_id) == null:
		return false
	var n := RunState.evolve_card_type(base_id, to_id)
	if n <= 0:
		return false
	RunState.gold -= cost
	return true
