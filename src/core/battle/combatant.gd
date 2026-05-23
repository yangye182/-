## 战斗单位（玩家或敌人）
class_name Combatant
extends RefCounted

signal hp_changed
signal block_changed
signal intent_changed

var id: String = ""
var display_name: String = ""
var max_hp: int = 50
var hp: int = 50
var block: int = 0
var is_player: bool = false
var is_dead: bool = false

## 敌人意图（下回合预告）
var intent_type: String = "attack"
var intent_value: int = 0
var intent_desc: String = ""

## 反击值：被攻击时对攻击者造成等量伤害
var retaliate: int = 0
## 减伤屏障：每次受到伤害减 N 点（下限 0）
var damage_barrier: int = 0


func set_intent(type: String, value: int, desc: String) -> void:
	intent_type = type
	intent_value = value
	intent_desc = desc
	intent_changed.emit()


## 状态：vulnerable, weak, rust 等 -> 层数
var statuses: Dictionary = {}


func setup_from_enemy_data(data: Dictionary) -> void:
	id = data.get("id", "enemy")
	display_name = GameLocale.pick_field(data, "name", "name_zh")
	max_hp = int(data.get("hp", 40))
	hp = max_hp
	is_player = false


func take_damage(amount: int, _ignore_block: bool = false) -> int:
	if is_dead:
		return 0
	var dmg := amount
	# 玩家减伤屏障
	if is_player and damage_barrier > 0 and not _ignore_block:
		dmg = maxi(dmg - damage_barrier, 0)
	if not _ignore_block and block > 0:
		var absorbed := mini(block, dmg)
		block -= absorbed
		dmg -= absorbed
		block_changed.emit()
	if dmg > 0:
		# 易伤：受到伤害 +50%
		if statuses.get("vulnerable", 0) > 0:
			dmg = int(ceil(dmg * 1.5))
		hp -= dmg
		hp = maxi(hp, 0)
		if hp <= 0:
			is_dead = true
		hp_changed.emit()
	return dmg


func gain_block(amount: int) -> void:
	block += amount
	block_changed.emit()


func heal(amount: int) -> void:
	if is_dead:
		return
	hp = mini(hp + amount, max_hp)
	hp_changed.emit()


func add_status(name: String, stacks: int) -> void:
	statuses[name] = statuses.get(name, 0) + stacks


func tick_statuses_end_of_turn() -> void:
	# 回合末衰减部分状态
	if statuses.get("vulnerable", 0) > 0:
		statuses["vulnerable"] -= 1
		if statuses["vulnerable"] <= 0:
			statuses.erase("vulnerable")
	if statuses.get("weak", 0) > 0:
		statuses["weak"] -= 1
		if statuses["weak"] <= 0:
			statuses.erase("weak")


func clear_block_turn_end() -> void:
	block = 0
	block_changed.emit()
