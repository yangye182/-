## 卡牌静态数据（从 JSON 加载，支持中英双语字段）
class_name CardData
extends Resource

enum CardType { ATTACK, SKILL, POWER }
enum TargetType { NONE, ENEMY, ALL_ENEMIES, SELF }

@export var id: String = ""
@export var name_en: String = ""
@export var name_zh: String = ""
@export var description_en: String = ""
@export var description_zh: String = ""
@export var card_type: CardType = CardType.ATTACK
@export var cost_red: int = 0
@export var cost_blue: int = 0
@export var damage: int = 0
@export var block: int = 0
@export var draw: int = 0
@export var heal: int = 0
@export var target: TargetType = TargetType.ENEMY
@export var effects: PackedStringArray = []
@export var upgrade_id: String = ""
@export var rarity: String = "common"
## 进化分支：[{ "id": "card_id", "cost": 40, "desc_en": "...", "desc_zh": "..." }]
@export var evolves_to: Array[Dictionary] = []


func get_display_name() -> String:
	return name_zh if GameLocale.use_chinese else name_en


func get_display_description() -> String:
	return description_zh if GameLocale.use_chinese else description_en


static func from_dict(d: Dictionary) -> CardData:
	var c := CardData.new()
	c.id = d.get("id", "")
	c.name_en = d.get("name", "")
	c.name_zh = d.get("name_zh", c.name_en)
	c.description_en = d.get("description", "")
	c.description_zh = d.get("description_zh", c.description_en)
	c.cost_red = int(d.get("cost_red", 0))
	c.cost_blue = int(d.get("cost_blue", 0))
	c.damage = int(d.get("damage", 0))
	c.block = int(d.get("block", 0))
	c.draw = int(d.get("draw", 0))
	c.heal = int(d.get("heal", 0))
	c.upgrade_id = d.get("upgrade_id", "")
	c.rarity = d.get("rarity", "common")
	var ev = d.get("evolves_to", [])
	if ev is Array:
		for item in ev:
			c.evolves_to.append(item)
	match d.get("type", "attack"):
		"attack": c.card_type = CardType.ATTACK
		"skill": c.card_type = CardType.SKILL
		"power": c.card_type = CardType.POWER
	match d.get("target", "enemy"):
		"enemy": c.target = TargetType.ENEMY
		"all_enemies": c.target = TargetType.ALL_ENEMIES
		"self": c.target = TargetType.SELF
		_: c.target = TargetType.NONE
	var eff = d.get("effects", [])
	if eff is Array:
		for e in eff:
			c.effects.append(str(e))
	return c
