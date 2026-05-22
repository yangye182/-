extends Control

## 显式 preload，避免 class_name 未被分析器识别
const CardWidgetScene := preload("res://src/ui/card/card_widget.gd")

@onready var battle_manager: BattleManager = $BattleManager
@onready var hand_container: HBoxContainer = $BottomPanel/HandContainer
@onready var enemy_container: HBoxContainer = $EnemyPanel/EnemyContainer
@onready var hp_label: Label = $PlayerPanel/HPLabel
@onready var block_label: Label = $PlayerPanel/BlockLabel
@onready var energy_label: Label = $PlayerPanel/EnergyLabel
@onready var log_label: Label = $LogPanel/LogLabel
@onready var end_turn_btn: Button = $BottomPanel/EndTurnButton
@onready var victory_panel: Panel = $VictoryPanel
@onready var victory_label: Label = $VictoryPanel/VictoryLabel
@onready var continue_btn: Button = $VictoryPanel/ContinueButton

var selected_target: int = 0
var rift_rule: String = ""
var _last_victory: bool = false


func _ready() -> void:
	_apply_static_locale()
	victory_panel.visible = false
	end_turn_btn.pressed.connect(_on_end_turn)
	continue_btn.pressed.connect(_on_continue)
	battle_manager.battle_started.connect(_refresh_all)
	battle_manager.player_turn_started.connect(_refresh_all)
	battle_manager.energy_updated.connect(_update_energy)
	battle_manager.enemies_updated.connect(_refresh_enemies)
	battle_manager.deck.hand_changed.connect(_refresh_hand)
	battle_manager.log_message.connect(func(t): log_label.text = t)
	battle_manager.battle_ended.connect(_on_battle_ended)
	battle_manager.player.hp_changed.connect(_update_player)
	battle_manager.player.block_changed.connect(_update_player)


func _apply_static_locale() -> void:
	end_turn_btn.text = GameLocale.t("End Turn", "结束回合")
	UiFonts.apply_font_to(end_turn_btn, 16)
	UiFonts.apply_font_to(hp_label, 16)
	UiFonts.apply_font_to(block_label, 16)
	UiFonts.apply_font_to(energy_label, 16)
	UiFonts.apply_font_to(log_label, 14)


func start_battle(enemy_ids: Array[String], rift: String) -> void:
	rift_rule = rift
	victory_panel.visible = false
	selected_target = 0
	battle_manager.start_battle(enemy_ids, RunState.build_deck_instances())
	if rift != "":
		log_label.text = GameLocale.t("Void Rift rule: %s" % rift, "虚空裂隙规则：%s" % rift)
	_refresh_all()


func _refresh_all() -> void:
	_update_player()
	_update_energy()
	_refresh_enemies()
	_refresh_hand()


func _update_player() -> void:
	var p := battle_manager.player
	hp_label.text = GameLocale.t("HP %d / %d" % [p.hp, p.max_hp], "生命 %d / %d" % [p.hp, p.max_hp])
	block_label.text = GameLocale.t("Block %d" % p.block, "护甲 %d" % p.block)


func _update_energy() -> void:
	var e := battle_manager.energy
	energy_label.text = GameLocale.t(
		"Red %d/%d  |  Blue %d/%d" % [e.current_red, e.max_red, e.current_blue, e.max_blue],
		"体力(红) %d/%d  |  精神力(蓝) %d/%d" % [e.current_red, e.max_red, e.current_blue, e.max_blue]
	)


func _refresh_enemies() -> void:
	for c in enemy_container.get_children():
		c.queue_free()
	var idx := 0
	for enemy in battle_manager.enemies:
		var box := VBoxContainer.new()
		var name_l := Label.new()
		name_l.text = enemy.display_name + (GameLocale.t(" (dead)", " (死亡)") if enemy.is_dead else "")
		UiFonts.apply_font_to(name_l, 14)
		var hp_l := Label.new()
		hp_l.text = GameLocale.t(
			"HP %d/%d  Block %d" % [enemy.hp, enemy.max_hp, enemy.block],
			"HP %d/%d  护甲%d" % [enemy.hp, enemy.max_hp, enemy.block]
		)
		UiFonts.apply_font_to(hp_l, 14)
		var intent_l := Label.new()
		intent_l.text = GameLocale.t("Intent: %s" % enemy.intent_desc, "意图: %s" % enemy.intent_desc)
		UiFonts.apply_font_to(intent_l, 14)
		box.add_child(name_l)
		box.add_child(hp_l)
		box.add_child(intent_l)
		var tbtn := Button.new()
		tbtn.text = GameLocale.t("Target", "选中目标")
		UiFonts.apply_font_to(tbtn, 14)
		var ti := idx
		tbtn.pressed.connect(func(): selected_target = ti)
		box.add_child(tbtn)
		enemy_container.add_child(box)
		idx += 1


func _refresh_hand() -> void:
	for c in hand_container.get_children():
		c.queue_free()
	for i in battle_manager.deck.hand.size():
		var inst: CardInstance = battle_manager.deck.hand[i]
		var data := inst.get_data()
		if data == null:
			continue
		var card_ui = CardWidgetScene.new()
		var playable := battle_manager.can_play_card(i)
		card_ui.setup(data, not playable)
		var hi := i
		card_ui.card_pressed.connect(func(): _play_card(hi))
		hand_container.add_child(card_ui)


func _play_card(index: int) -> void:
	battle_manager.play_card(index, selected_target)
	_refresh_hand()
	_refresh_enemies()
	_update_player()


func _on_end_turn() -> void:
	battle_manager.end_player_turn()


func _on_battle_ended(victory: bool) -> void:
	_last_victory = victory
	victory_panel.visible = true
	victory_label.text = GameLocale.t("Victory!", "胜利！") if victory else GameLocale.t("Defeat...", "战败...")
	continue_btn.text = GameLocale.t("Continue", "继续") if victory else GameLocale.t("Main Menu", "返回主菜单")


func _on_continue() -> void:
	get_parent().on_battle_finished(_last_victory)
