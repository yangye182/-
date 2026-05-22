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

## 角色配置（虚空骑士默认）
var character_id: String = "void_knight"


func start_battle(enemy_ids: Array[String], run_deck: Array[CardInstance]) -> void:
	_setup_player()
	_setup_enemies(enemy_ids)
	deck.setup_deck(run_deck)
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
		enemies.append(c)
		EnemyAI.plan_intent(c, data.get("pattern", []), 0)
	enemies_updated.emit()


func _begin_player_turn() -> void:
	phase = Phase.PLAYER
	turn_number += 1
	player.clear_block_turn_end()
	for e in enemies:
		if not e.is_dead:
			e.clear_block_turn_end()
	energy.on_player_turn_start()
	deck.draw_cards(5)
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
	if rust_pending and deck.hand.size() > 0 and hand_index == 0:
		red += 1  # 锈蚀：第一张牌红费+1
	return energy.can_pay(red, blue)


func play_card(hand_index: int, target_enemy_index: int = 0) -> bool:
	if not can_play_card(hand_index):
		return false
	var inst := deck.hand[hand_index]
	var data := inst.get_data()
	var red := data.cost_red
	var blue := data.cost_blue
	if rust_pending and hand_index == 0:
		red += 1
		rust_pending = false
	if not energy.pay(red, blue):
		return false
	var card := deck.play_from_hand(hand_index)
	_resolve_card(card, data, target_enemy_index)
	card_played.emit(card, target_enemy_index)
	energy_updated.emit()
	if _all_enemies_dead():
		_end_battle(true)
	return true


func _resolve_card(card: CardInstance, data: CardData, target_idx: int) -> void:
	log_message.emit(GameLocale.t("Played [%s]" % data.get_display_name(), "打出【%s】" % data.get_display_name()))
	# 伤害
	if data.damage > 0:
		match data.target:
			CardData.TargetType.ALL_ENEMIES:
				for e in enemies:
					if not e.is_dead:
						e.take_damage(data.damage)
			CardData.TargetType.ENEMY:
				if target_idx >= 0 and target_idx < enemies.size():
					var t := enemies[target_idx]
					if not t.is_dead:
						t.take_damage(data.damage)
			_:
				pass
	if data.block > 0:
		player.gain_block(data.block)
	if data.heal > 0:
		player.heal(data.heal)
	if data.draw > 0:
		deck.draw_cards(data.draw)
	for eff in data.effects:
		if eff.begins_with("hit_twice"):
			var times := int(eff.split(":")[1]) if ":" in eff else 2
			for _t in times - 1:
				match data.target:
					CardData.TargetType.ENEMY:
						if target_idx >= 0 and target_idx < enemies.size() and not enemies[target_idx].is_dead:
							enemies[target_idx].take_damage(data.damage)
					CardData.TargetType.ALL_ENEMIES:
						for e in enemies:
							if not e.is_dead:
								e.take_damage(data.damage)
		elif eff.begins_with("self_damage"):
			var sd := int(eff.split(":")[1]) if ":" in eff else 0
			player.take_damage(sd, true)
		else:
			_apply_effect_string(eff, target_idx)
	if _all_enemies_dead():
		return


func _apply_effect_string(eff: String, target_idx: int) -> void:
	var parts := eff.split(":")
	var key := parts[0]
	var val := int(parts[1]) if parts.size() > 1 else 0
	match key:
		"apply_vulnerable":
			if target_idx < enemies.size():
				enemies[target_idx].add_status("vulnerable", val)
		"apply_weak":
			if target_idx < enemies.size():
				enemies[target_idx].add_status("weak", val)
		"gain_blue":
			energy.add_blue(val)
		"enemy_steal_blue":
			energy.drain_blue(val)
			log_message.emit(GameLocale.t("Enemy stole %d Blue energy!" % val, "敌人偷取了 %d 点精神力！" % val))
		_:
			pass
	enemies_updated.emit()


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
		if e.intent_type == "steal_blue":
			energy.drain_blue(e.intent_value)
			log_message.emit(GameLocale.t(
				"%s stole %d Blue" % [e.display_name, e.intent_value],
				"%s 偷取了 %d 精神力" % [e.display_name, e.intent_value]
			))
		else:
			EnemyAI.execute_intent(e, player)
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
		EnemyAI.plan_intent(e, data.get("pattern", []), enemy_turn_indices[i])
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
