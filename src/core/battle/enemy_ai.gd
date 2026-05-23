## 敌人 AI：基于意图模式（类似杀戮尖塔）
class_name EnemyAI
extends RefCounted

static func plan_intent(enemy: Combatant, pattern: Array, turn_index: int) -> void:
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
	match enemy.intent_type:
		"attack":
			var dmg := enemy.intent_value
			if enemy.statuses.get("weak", 0) > 0:
				dmg = int(floor(dmg * 0.75))
			target.take_damage(dmg)
		"block":
			enemy.gain_block(enemy.intent_value)
		"buff":
			enemy.add_status("strength", enemy.intent_value)
		"debuff_rust":
			# 锈蚀：下回合玩家第一张牌费用+1（由战斗管理器处理标记）
			target.add_status("rust_next", 1)
		"steal_blue":
			# 偷精神力在 BattleManager 中处理
			pass
		_:
			target.take_damage(enemy.intent_value)
