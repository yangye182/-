## 战斗核心逻辑：回合、出牌、敌人行动
class_name BattleManager
extends Node

signal battle_started
signal battle_ended(victory: bool)
signal player_turn_started
signal player_turn_ended
signal card_played(card: CardInstance, target_index: int)
signal log_message(text: String)
signal energy_updated
signal enemies_updated

enum Phase { PLAYER, ENEMY, END }

var phase: Phase = Phase.PLAYER
var player: Combatant = Combatant.new()
var enemies: Array[Combatant] = []
var energy: DualEnergy = DualEnergy.new()
var deck: DeckManager = DeckManager.new()

var turn_number: int = 0
var enemy_turn_indices: Array[int] = []
var rust_pending: bool = false  # 锈蚀 debuff
var rift_rule: String = ""  # 当前虚空裂隙规则
var hp_scale: float = 1.0  # 楼层 HP 缩放系数

## 战斗中累计符文镶嵌数（刻印改造流用）
var rune_count: int = 0
## Power 效果追踪
var extra_draw_per_turn: int = 0
var hand_limit_mod: int = 0
## 本回合蓝费折扣
var blue_discount: int = 0

## 角色配置（虚空骑士默认）
var character_id: String = "void_knight"


func start_battle(enemy_ids: Array[String], run_deck: Array[CardInstance], rift: String = "", scale: float = 1.0) -> void:
	character_id = RunState.character_id
	rift_rule = rift
	hp_scale = scale
	_setup_player()
	_setup_enemies(enemy_ids)
	deck.setup_deck(run_deck)
	rune_count = 0
	extra_draw_per_turn = 0
	hand_limit_mod = 0
	blue_discount = 0
	turn_number = 0
	enemy_turn_indices.clear()
	for _e in enemies:
		enemy_turn_indices.append(0)
	_begin_player_turn()
	battle_started.emit()


func _setup_player() -> void:
	player = Combatant.new()
	player.is_player = true
	player.id = "player"
	var cfg := GameDB.get_character(character_id)
	player.display_name = GameLocale.pick_field(cfg, "name", "name_zh")
	player.max_hp = int(cfg.get("max_hp", 70))
	player.hp = RunState.current_hp if RunState.current_hp > 0 else player.max_hp
	energy.reset_for_battle(
		int(cfg.get("red_per_turn", 3)),
		int(cfg.get("blue_max", 4)),
		int(cfg.get("blue_gain", 1))
	)


func _setup_enemies(enemy_ids: Array[String]) -> void:
	enemies.clear()
	for eid in enemy_ids:
		var data := GameDB.get_enemy(eid)
		var c := Combatant.new()
		c.setup_from_enemy_data(data)
		# 楼层 HP 缩放
		if hp_scale != 1.0:
			c.max_hp = maxi(1, int(c.max_hp * hp_scale))
			c.hp = c.max_hp
		enemies.append(c)
		EnemyAI.plan_intent(c, data, 0)
	enemies_updated.emit()


func _begin_player_turn() -> void:
	phase = Phase.PLAYER
	turn_number += 1
	player.clear_block_turn_end()
	for e in enemies:
		if not e.is_dead:
			e.clear_block_turn_end()
	energy.on_player_turn_start()
	if extra_draw_per_turn > 0:
		deck.draw_cards(extra_draw_per_turn)
	deck.draw_cards(5)
	# 混沌裂隙：回合开始时随机交换手牌和牌库顶
	if rift_rule == "chaos" and deck.hand.size() > 0 and deck.draw_pile.size() > 0:
		var swap_count := mini(deck.hand.size(), deck.draw_pile.size())
		for _s in range(swap_count):
			var hi := randi() % deck.hand.size()
			var di := randi() % deck.draw_pile.size()
			var tmp := deck.hand[hi]
			deck.hand[hi] = deck.draw_pile[di]
			deck.draw_pile[di] = tmp
		log_message.emit(GameLocale.t(
			"[Chaos Rift] Hand and deck swapped!",
			"【混沌裂隙】手牌与牌库被交换了！"
		))
		deck.hand_changed.emit()
		deck.piles_changed.emit()
	# 骑士誓言：首回合 +2 护甲
	if turn_number == 1 and RunState.has_relic("knight_oath"):
		player.gain_block(2)
		log_message.emit(GameLocale.t("Relic [Knight's Oath]: +2 Block", "遗物【骑士誓言】：获得 2 点护甲"))
	energy_updated.emit()
	player_turn_started.emit()


func can_play_card(hand_index: int) -> bool:
	if phase != Phase.PLAYER:
		return false
	if hand_index < 0 or hand_index >= deck.hand.size():
		return false
	var inst := deck.hand[hand_index]
	var data := inst.get_data()
	if data == null:
		return false
	var red := data.cost_red
	var blue := data.cost_blue
	# 逆反裂隙：红蓝费互换
	if rift_rule == "reverse":
		var tmp := red
		red = blue
		blue = tmp
	if rust_pending and deck.hand.size() > 0 and hand_index == 0:
		red += 1  # 锈蚀：第一张牌红费+1
	# 符文折扣
	for eff in data.effects:
		var p := eff.split(":")
		if p[0] == "rune_discount" and p.size() > 1:
			red = maxi(red - rune_count * int(p[1]), 0)
			break
	return energy.can_pay(red, blue)


func play_card(hand_index: int, target_enemy_index: int = 0) -> bool:
	if not can_play_card(hand_index):
		return false
	var inst := deck.hand[hand_index]
	var data := inst.get_data()
	var red := data.cost_red
	var blue := data.cost_blue
	# 逆反裂隙：红蓝费互换
	if rift_rule == "reverse":
		var tmp := red
		red = blue
		blue = tmp
	if rust_pending and hand_index == 0:
		red += 1
		rust_pending = false
	# 符文折扣
	for eff in data.effects:
		var p := eff.split(":")
		if p[0] == "rune_discount" and p.size() > 1:
			red = maxi(red - rune_count * int(p[1]), 0)
			break
	if not energy.pay(red, blue):
		return false
	var card := deck.play_from_hand(hand_index)
	_resolve_card(card, data, target_enemy_index)
	card_played.emit(card, target_enemy_index)
	energy_updated.emit()
	# 静默裂隙：打出牌后弃牌库顶 1 张
	if rift_rule == "silent" and not deck.draw_pile.is_empty():
		var discarded: CardInstance = deck.draw_pile.pop_back()
		deck.discard_pile.append(discarded)
		deck.piles_changed.emit()
		log_message.emit(GameLocale.t(
			"[Silent Rift] 1 card discarded from draw pile.",
			"【静默裂隙】从牌库顶弃置 1 张牌。"
		))
	# 消耗裂隙：打出牌后移除（不进入弃牌堆）
	if rift_rule == "deplete":
		deck.move_last_discarded_to_exhaust()
		log_message.emit(GameLocale.t(
			"[Deplete Rift] Card was exhausted.",
			"【消耗裂隙】卡牌已被移除。"
		))
	if _all_enemies_dead():
		_end_battle(true)
	return true


func _resolve_card(_card: CardInstance, data: CardData, target_idx: int) -> void:
	log_message.emit(GameLocale.t("Played [%s]" % data.get_display_name(), "打出【%s】" % data.get_display_name()))

	# 1. 计算基础值 + 预处理修饰（内联避免传值问题）
	var dmg := data.damage
	var blk := data.block
	for eff in data.effects:
		var parts := eff.split(":")
		var key := parts[0]
		var val := int(parts[1]) if parts.size() > 1 else 0
		match key:
			"block_bonus":
				if player.block > 0:
					dmg += val
			"scaled_by_blue":
				dmg += energy.current_blue * val
			"blue_to_damage":
				var consumed := energy.current_blue
				energy.current_blue = 0
				dmg += consumed * val
			"rune_count_damage":
				dmg += rune_count * val

	# 2. 应用伤害
	if dmg > 0:
		match data.target:
			CardData.TargetType.ALL_ENEMIES:
				for e in enemies:
					if not e.is_dead:
						e.take_damage(dmg)
			CardData.TargetType.ENEMY:
				if target_idx >= 0 and target_idx < enemies.size():
					var t := enemies[target_idx]
					if not t.is_dead:
						t.take_damage(dmg)
			_:
				pass

	# 3. 护甲
	if blk > 0:
		player.gain_block(blk)

	# 4. 基础回复/抽牌
	if data.heal > 0:
		player.heal(data.heal)
	if data.draw > 0:
		deck.draw_cards(data.draw)

	# 5. 后处理效果
	var twin_hit_count := 0
	for eff in data.effects:
		var parts := eff.split(":")
		var key := parts[0]
		var val := int(parts[1]) if parts.size() > 1 else 0
		match key:
			"hit_twice":
				for _t in val - 1:
					match data.target:
						CardData.TargetType.ENEMY:
							if target_idx >= 0 and target_idx < enemies.size() and not enemies[target_idx].is_dead:
								enemies[target_idx].take_damage(dmg)
								twin_hit_count += 1
						CardData.TargetType.ALL_ENEMIES:
							for e in enemies:
								if not e.is_dead:
									e.take_damage(dmg)
			"twin_hit_bonus":
				if twin_hit_count >= 1 and target_idx >= 0 and target_idx < enemies.size() and not enemies[target_idx].is_dead:
					enemies[target_idx].take_damage(val)
			"self_damage":
				player.take_damage(val, true)
			"gain_red":
				energy.add_red(val)
			"gain_blue":
				energy.add_blue(val)
			"apply_vulnerable":
				if target_idx < enemies.size():
					enemies[target_idx].add_status("vulnerable", val)
			"apply_weak":
				if target_idx < enemies.size():
					enemies[target_idx].add_status("weak", val)
			"enemy_steal_blue":
				energy.drain_blue(val)
				log_message.emit(GameLocale.t("Enemy stole %d Blue energy!" % val, "敌人偷取了 %d 点精神力！" % val))
			"retaliate":
				player.retaliate += val
			"blue_max_up":
				energy.max_blue += val
			"extra_red":
				energy.max_red += val
			"damage_barrier":
				player.damage_barrier += val
			"blue_discount":
				blue_discount = val
			"max_hp_down":
				player.max_hp = maxi(player.max_hp - val, 10)
				if player.hp > player.max_hp:
					player.hp = player.max_hp
			"extra_draw":
				extra_draw_per_turn += val
			"hand_limit":
				hand_limit_mod += val
			"discard_to_block":
				var discard_cnt := deck.hand.size()
				deck.discard_hand()
				player.gain_block(discard_cnt * val)
				log_message.emit(GameLocale.t(
					"Discarded %d cards, gained %d Block." % [discard_cnt, discard_cnt * val],
					"弃置了 %d 张牌，获得 %d 护甲。" % [discard_cnt, discard_cnt * val]
				))
			"cycle":
				var filter_str := parts[1] if parts.size() > 1 else ""
				if deck.hand.size() > 0:
					var last_idx := deck.hand.size() - 1
					var discarded := deck.play_from_hand(last_idx)
					var discarded_data := discarded.get_data()
					var matches := false
					if filter_str == "attack" and discarded_data and discarded_data.card_type == CardData.CardType.ATTACK:
						matches = true
					elif filter_str == "skill" and discarded_data and discarded_data.card_type == CardData.CardType.SKILL:
						matches = true
					elif filter_str == "":
						matches = true
					if matches:
						deck.draw_cards(1)

	# 镜像裂隙：受到造成伤害 50% 的反馈
	if rift_rule == "mirror" and dmg > 0:
		var feedback := int(ceil(dmg * 0.5))
		player.take_damage(feedback)
		log_message.emit(GameLocale.t(
			"[Mirror Rift] Took %d feedback damage!" % feedback,
			"【镜像裂隙】受到 %d 点反馈伤害！" % feedback
		))
	enemies_updated.emit()
	if _all_enemies_dead():
		return


func end_player_turn() -> void:
	if phase != Phase.PLAYER:
		return
	phase = Phase.ENEMY
	deck.discard_hand()
	energy.on_player_turn_end()
	player.tick_statuses_end_of_turn()
	player_turn_ended.emit()
	energy_updated.emit()
	await get_tree().create_timer(0.4).timeout
	_execute_enemy_turn()


func _execute_enemy_turn() -> void:
	for i in enemies.size():
		var e := enemies[i]
		if e.is_dead:
			continue
		# 处理各种意图类型
		match e.intent_type:
			"steal_blue":
				energy.drain_blue(e.intent_value)
				log_message.emit(GameLocale.t(
					"%s stole %d Blue" % [e.display_name, e.intent_value],
					"%s 偷取了 %d 精神力" % [e.display_name, e.intent_value]
				))
			"summon":
				# 召唤一个随从敌人
				var minion_id := "shadow_acolyte"
				var minion_data := GameDB.get_enemy(minion_id)
				if not minion_data.is_empty():
					var minion := Combatant.new()
					minion.setup_from_enemy_data(minion_data)
					enemies.append(minion)
					enemy_turn_indices.append(0)
					EnemyAI.plan_intent(minion, minion_data, 0)
					log_message.emit(GameLocale.t(
						"%s summoned a minion!" % e.display_name,
						"%s 召唤了一个随从！" % e.display_name
					))
				enemies_updated.emit()
			"attack_all":
				EnemyAI.execute_intent(e, player)
				log_message.emit(GameLocale.t(
					"%s deals %d AOE damage!" % [e.display_name, e.intent_value],
					"%s 造成 %d 点 AOE 伤害！" % [e.display_name, e.intent_value]
				))
			_:
				EnemyAI.execute_intent(e, player)
		# 反击
		if player.retaliate > 0 and e.hp > 0 and e.intent_type not in ["summon"]:
			e.take_damage(player.retaliate)
			if e.is_dead:
				continue
		if player.is_dead:
			_end_battle(false)
			return
		# 锈蚀标记
		if player.statuses.get("rust_next", 0) > 0:
			rust_pending = true
			player.statuses.erase("rust_next")
			log_message.emit(GameLocale.t(
				"[Rust] First card next turn costs +1 Red",
				"【锈蚀】下回合首张牌费用+1"
			))
		enemy_turn_indices[i] += 1
		var data := GameDB.get_enemy(e.id)
		EnemyAI.plan_intent(e, data, enemy_turn_indices[i])
	if player.is_dead:
		_end_battle(false)
		return
	enemies_updated.emit()
	await get_tree().create_timer(0.3).timeout
	_begin_player_turn()


func _all_enemies_dead() -> bool:
	for e in enemies:
		if not e.is_dead:
			return false
	return true


func _end_battle(victory: bool) -> void:
	phase = Phase.END
	RunState.current_hp = player.hp
	if victory:
		RunState.gold += 15
		log_message.emit(GameLocale.t("Victory! +15 gold", "战斗胜利！获得 15 金币"))
	battle_ended.emit(victory)
