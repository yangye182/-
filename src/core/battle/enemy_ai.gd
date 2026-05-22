## 敌人 AI：基于意图模式（类似杀戮尖塔）
class_name EnemyAI
extends RefCounted

static func plan_intent(enemy: Combatant, pattern: Array, turn_index: int) -> void:
	if pattern.is_empty():
		enemy.intent_type = "attack"
		enemy.intent_value = 6
		enemy.intent_desc = GameLocale.t("Attack 6", "攻击 6")
		enemy.intent_changed.emit()
		return
	var step = pattern[turn_index % pattern.size()]
	if step is Dictionary:
		enemy.intent_type = step.get("type", "attack")
		enemy.intent_value = int(step.get("value", 0))
		enemy.intent_desc = GameLocale.t(
			str(step.get("desc", enemy.intent_type)),
			str(step.get("desc_zh", step.get("desc", enemy.intent_type)))
		)
	else:
		enemy.intent_type = "attack"
		enemy.intent_value = int(step)
		enemy.intent_desc = GameLocale.t("Attack %d" % enemy.intent_value, "攻击 %d" % enemy.intent_value)
	enemy.intent_changed.emit()


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
