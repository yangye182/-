## 敌人 AI：基于意图模式（类似杀戮尖塔）
class_name EnemyAI
extends RefCounted

static func plan_intent(enemy: Combatant, data: Dictionary, turn_index: int) -> void:
	var pattern: Array = data.get("pattern", [])
	# 双阶段 AI：半血以下切换至 pattern_low_hp
	var pattern_low_hp: Array = data.get("pattern_low_hp", [])
	if not pattern_low_hp.is_empty() and enemy.hp <= int(enemy.max_hp * 0.5):
		pattern = pattern_low_hp
	if pattern.is_empty():
		enemy.set_intent("attack", 6, GameLocale.t("Attack 6", "攻击 6"))
		return
	var step = pattern[turn_index % pattern.size()]
	if step is Dictionary:
		var itype: String = step.get("type", "attack")
		var ivalue: int = int(step.get("value", 0))
		var idesc: String = GameLocale.t(
			str(step.get("desc", itype)),
			str(step.get("desc_zh", step.get("desc", itype)))
		)
		enemy.set_intent(itype, ivalue, idesc)
	else:
		var dmg: int = int(step)
		enemy.set_intent("attack", dmg, GameLocale.t("Attack %d" % dmg, "攻击 %d" % dmg))


static func execute_intent(enemy: Combatant, target: Combatant) -> void:
	var dmg := enemy.intent_value
	# 力量加成
	var strength: int = enemy.statuses.get("strength", 0)
	dmg += strength
	# 虚弱减益
	if enemy.statuses.get("weak", 0) > 0 and enemy.intent_type in ["attack", "attack_all"]:
		dmg = int(floor(dmg * 0.75))
	dmg = maxi(dmg, 0)
	match enemy.intent_type:
		"attack":
			target.take_damage(dmg)
		"attack_all":
			# AOE：无视格挡造成直接伤害
			target.take_damage(dmg, true)
		"block":
			enemy.gain_block(enemy.intent_value)
		"buff":
			enemy.add_status("strength", enemy.intent_value)
		"buff_strength":
			enemy.add_status("strength", enemy.intent_value)
		"debuff_rust":
			# 锈蚀：下回合玩家第一张牌费用+1（由战斗管理器处理标记）
			target.add_status("rust_next", 1)
		"steal_blue":
			# 偷精神力在 BattleManager 中处理
			pass
		"heal_self":
			enemy.heal(enemy.intent_value)
		"apply_vulnerable":
			target.add_status("vulnerable", enemy.intent_value)
		"apply_weak":
			target.add_status("weak", enemy.intent_value)
		"buff_retaliate":
			enemy.retaliate += enemy.intent_value
		_:
			target.take_damage(enemy.intent_value)
