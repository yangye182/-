## 角色名册：从 JSON 读取、排序、解析初始牌组/遗物（扩展新角色只需改 characters.json）
class_name CharacterRoster
extends RefCounted


static func get_sorted_roster() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for key in GameDB.characters.keys():
		var cfg: Dictionary = GameDB.characters[key]
		if not cfg.is_empty():
			list.append(cfg)
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("sort_order", 99)) < int(b.get("sort_order", 99))
	)
	return list


static func is_playable(character_id: String) -> bool:
	return CharacterProgress.is_unlocked(character_id)


static func get_starting_deck(cfg: Dictionary) -> Array[String]:
	var deck_raw: Array = cfg.get("starting_deck", [])
	var result: Array[String] = []
	if deck_raw is Array:
		for c in deck_raw:
			result.append(str(c))
	return result


static func get_starting_relics(cfg: Dictionary) -> Array[String]:
	var relic_raw: Array = cfg.get("starting_relics", [])
	var result: Array[String] = []
	if relic_raw is Array:
		for r in relic_raw:
			result.append(str(r))
	return result


static func format_stats_line(cfg: Dictionary) -> String:
	return GameLocale.t(
		"HP %d  |  Red %d/turn  |  Blue max %d (+%d/turn)" % [
			int(cfg.get("max_hp", 70)),
			int(cfg.get("red_per_turn", 3)),
			int(cfg.get("blue_max", 4)),
			int(cfg.get("blue_gain", 1)),
		],
		"生命 %d  |  体力 %d/回合  |  精神力上限 %d（每回合 +%d）" % [
			int(cfg.get("max_hp", 70)),
			int(cfg.get("red_per_turn", 3)),
			int(cfg.get("blue_max", 4)),
			int(cfg.get("blue_gain", 1)),
		]
	)


static func format_deck_summary(cfg: Dictionary) -> String:
	var deck := get_starting_deck(cfg)
	if deck.is_empty():
		return GameLocale.t("Default deck", "默认牌组")
	var names: PackedStringArray = []
	var seen: Dictionary = {}
	for cid in deck:
		if cid in seen:
			continue
		seen[cid] = true
		var card := GameDB.get_card(cid)
		if card:
			names.append(card.get_display_name())
		else:
			names.append(cid)
	return ", ".join(names)
