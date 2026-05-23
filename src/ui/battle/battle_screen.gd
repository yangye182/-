## 战斗 UI：全代码构建，容器布局
extends Control

const CardWidgetScene := preload("res://src/ui/card/card_widget.gd")
const PileViewOverlayScene := preload("res://src/ui/battle/pile_view_overlay.gd")

enum TargetMode { IDLE, SELECTING_TARGET }

# 核心引用
var battle_manager: BattleManager

# 状态
var _target_mode: int = TargetMode.IDLE
var _selected_card_index: int = -1
var _rift_rule: String = ""
var _last_victory: bool = false

# --- UI 构件 ---
var _hp_bar: ProgressBar
var _hp_label: Label
var _block_label: Label
var _block_icon: ColorRect
var _energy_label: Label
var _red_energy_container: HBoxContainer
var _blue_energy_container: HBoxContainer
var _draw_pile_btn: Button
var _discard_pile_btn: Button
var _exhaust_pile_btn: Button
var _pile_overlay: PileViewOverlay

var _enemy_container: HBoxContainer
var _enemy_widgets: Array[Panel] = []

var _log_label: Label

var _hand_scroll: ScrollContainer
var _hand_container: HBoxContainer
var _end_turn_btn: Button

var _victory_dim: ColorRect
var _victory_panel: Panel
var _victory_label: Label
var _continue_btn: Button


func _ready() -> void:
	_build_ui()
	_connect_signals()


func _connect_signals() -> void:
	battle_manager.battle_started.connect(_refresh_all)
	battle_manager.player_turn_started.connect(_refresh_all)
	battle_manager.energy_updated.connect(_refresh_energy_and_hand)
	battle_manager.enemies_updated.connect(_refresh_enemies)
	battle_manager.deck.hand_changed.connect(_refresh_hand)
	battle_manager.deck.piles_changed.connect(_on_piles_changed)
	battle_manager.log_message.connect(func(msg): _log_label.text = msg)
	battle_manager.battle_ended.connect(_on_battle_ended)
	battle_manager.player.hp_changed.connect(_update_player)
	battle_manager.player.block_changed.connect(_update_player)


func _refresh_energy_and_hand() -> void:
	_rebuild_energy_display()
	_update_deck_info()
	_refresh_hand()


func _build_ui() -> void:
	battle_manager = $BattleManager
	mouse_filter = Control.MOUSE_FILTER_STOP

	# 背景
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.06, 0.09)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(main_vbox)

	_build_top_bar(main_vbox)
	_build_middle_area(main_vbox)
	_build_bottom_bar(main_vbox)
	_build_victory_overlay()
	_build_pile_overlay()


func _build_top_bar(parent: VBoxContainer) -> void:
	var top_bar := HBoxContainer.new()
	top_bar.custom_minimum_size = Vector2(0, 48)
	parent.add_child(top_bar)

	# 左侧：玩家状态
	var player_vbox := VBoxContainer.new()
	player_vbox.add_theme_constant_override("separation", 2)
	player_vbox.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	top_bar.add_child(player_vbox)

	# HP 行：血条 + 文字
	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 8)
	player_vbox.add_child(hp_row)

	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(160, 14)
	_hp_bar.max_value = 100
	_hp_bar.value = 100
	_hp_bar.show_percentage = false
	hp_row.add_child(_hp_bar)

	_hp_label = Label.new()
	UiFonts.apply_font_to(_hp_label, 14)
	hp_row.add_child(_hp_label)

	# Block 行
	var block_row := HBoxContainer.new()
	block_row.add_theme_constant_override("separation", 4)
	player_vbox.add_child(block_row)

	_block_icon = ColorRect.new()
	_block_icon.custom_minimum_size = Vector2(10, 10)
	_block_icon.color = Color(0.8, 0.8, 0.6)
	# 圆角
	var block_sb := StyleBoxFlat.new()
	block_sb.set_corner_radius_all(3)
	block_sb.bg_color = Color(0.8, 0.8, 0.6)
	_block_icon.add_theme_stylebox_override("panel", block_sb)
	block_row.add_child(_block_icon)

	_block_label = Label.new()
	UiFonts.apply_font_to(_block_label, 13)
	block_row.add_child(_block_label)

	# 能量行
	var energy_row := HBoxContainer.new()
	energy_row.add_theme_constant_override("separation", 8)
	player_vbox.add_child(energy_row)

	_red_energy_container = HBoxContainer.new()
	_red_energy_container.add_theme_constant_override("separation", 3)
	energy_row.add_child(_red_energy_container)

	_blue_energy_container = HBoxContainer.new()
	_blue_energy_container.add_theme_constant_override("separation", 3)
	energy_row.add_child(_blue_energy_container)

	_energy_label = Label.new()
	UiFonts.apply_font_to(_energy_label, 11)
	energy_row.add_child(_energy_label)

	# 中间弹性空白
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(spacer)

	# 右侧：牌库统计
	var deck_vbox := VBoxContainer.new()
	deck_vbox.add_theme_constant_override("separation", 1)
	deck_vbox.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	top_bar.add_child(deck_vbox)

	_draw_pile_btn = _make_pile_button(
		GameLocale.t("Draw: 0", "抽牌: 0"),
		Color(0.35, 0.55, 0.85)
	)
	_draw_pile_btn.pressed.connect(func(): _open_pile_view(PileViewOverlay.PileTab.DRAW))
	deck_vbox.add_child(_draw_pile_btn)

	_discard_pile_btn = _make_pile_button(
		GameLocale.t("Discard: 0", "弃牌: 0"),
		Color(0.55, 0.45, 0.35)
	)
	_discard_pile_btn.pressed.connect(func(): _open_pile_view(PileViewOverlay.PileTab.DISCARD))
	deck_vbox.add_child(_discard_pile_btn)

	_exhaust_pile_btn = _make_pile_button(
		GameLocale.t("Exhaust: 0", "移除: 0"),
		Color(0.5, 0.35, 0.55)
	)
	_exhaust_pile_btn.pressed.connect(func(): _open_pile_view(PileViewOverlay.PileTab.EXHAUST))
	deck_vbox.add_child(_exhaust_pile_btn)


func _build_middle_area(parent: VBoxContainer) -> void:
	var middle := VBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 8)
	parent.add_child(middle)

	# 敌人区：居中显示
	var enemy_center := HBoxContainer.new()
	enemy_center.alignment = BoxContainer.ALIGNMENT_CENTER
	enemy_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_child(enemy_center)

	_enemy_container = HBoxContainer.new()
	_enemy_container.add_theme_constant_override("separation", 20)
	_enemy_container.alignment = BoxContainer.ALIGNMENT_CENTER
	enemy_center.add_child(_enemy_container)

	# 日志行
	var log_row := CenterContainer.new()
	middle.add_child(log_row)

	_log_label = Label.new()
	_log_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_label.custom_minimum_size = Vector2(400, 0)
	UiFonts.apply_font_to(_log_label, 13)
	log_row.add_child(_log_label)


func _build_bottom_bar(parent: VBoxContainer) -> void:
	var bottom := HBoxContainer.new()
	bottom.custom_minimum_size = Vector2(0, 260)
	bottom.add_theme_constant_override("separation", 8)
	parent.add_child(bottom)

	# 手牌滚动区
	_hand_scroll = ScrollContainer.new()
	_hand_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bottom.add_child(_hand_scroll)

	_hand_container = HBoxContainer.new()
	_hand_container.add_theme_constant_override("separation", 8)
	_hand_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hand_scroll.add_child(_hand_container)

	# 结束回合按钮
	var btn_vbox := VBoxContainer.new()
	btn_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_vbox.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bottom.add_child(btn_vbox)

	_end_turn_btn = Button.new()
	_end_turn_btn.custom_minimum_size = Vector2(100, 42)
	_end_turn_btn.pressed.connect(_on_end_turn)
	UiFonts.apply_font_to(_end_turn_btn, 15)
	_end_turn_btn.text = GameLocale.t("End Turn", "结束回合")
	btn_vbox.add_child(_end_turn_btn)


func _make_pile_button(text: String, accent: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.flat = true
	btn.custom_minimum_size = Vector2(120, 22)
	UiFonts.apply_font_to(btn, 13)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(accent.r * 0.25, accent.g * 0.25, accent.b * 0.25, 0.9)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb.duplicate())
	btn.get_theme_stylebox("hover").bg_color = Color(accent.r * 0.4, accent.g * 0.4, accent.b * 0.4, 0.95)
	btn.add_theme_color_override("font_color", Color(0.9, 0.92, 0.96))
	btn.tooltip_text = GameLocale.t("Click to view cards", "点击查看牌面")
	return btn


func _build_pile_overlay() -> void:
	_pile_overlay = PileViewOverlayScene.new()
	add_child(_pile_overlay)


func _build_victory_overlay() -> void:
	_victory_dim = ColorRect.new()
	_victory_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_victory_dim.color = Color(0, 0, 0, 0.65)
	_victory_dim.visible = false
	add_child(_victory_dim)

	_victory_panel = Panel.new()
	_victory_panel.custom_minimum_size = Vector2(300, 160)
	_victory_panel.visible = false
	_victory_panel.set_anchors_preset(Control.PRESET_CENTER)
	add_child(_victory_panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 6
	vbox.offset_top = 6
	vbox.offset_right = -6
	vbox.offset_bottom = -6
	vbox.add_theme_constant_override("separation", 20)
	_victory_panel.add_child(vbox)

	_victory_label = Label.new()
	_victory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFonts.apply_font_to(_victory_label, 22)
	vbox.add_child(_victory_label)

	_continue_btn = Button.new()
	_continue_btn.custom_minimum_size = Vector2(140, 40)
	_continue_btn.pressed.connect(_on_continue)
	UiFonts.apply_font_to(_continue_btn, 16)
	_continue_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(_continue_btn)


# ---- 公开接口 ----

func start_battle(enemy_ids: Array[String], rift: String, hp_scale: float = 1.0) -> void:
	_rift_rule = rift
	_cancel_target_mode()
	_victory_dim.visible = false
	_victory_panel.visible = false
	if _pile_overlay != null:
		_pile_overlay.close()
	battle_manager.start_battle(enemy_ids, RunState.build_deck_instances(), rift, hp_scale)


# ---- 刷新方法 ----

func _refresh_all() -> void:
	_update_player()
	_rebuild_energy_display()
	_update_deck_info()
	_refresh_enemies()
	_refresh_hand()


func _update_player() -> void:
	var p := battle_manager.player
	_hp_bar.max_value = max(p.max_hp, 1)
	_hp_bar.value = p.hp
	# 血条颜色
	var pct := float(p.hp) / float(max(p.max_hp, 1))
	if pct > 0.6:
		_hp_bar.modulate = Color(0.3, 0.8, 0.3)
	elif pct > 0.3:
		_hp_bar.modulate = Color(0.85, 0.7, 0.2)
	else:
		_hp_bar.modulate = Color(0.85, 0.2, 0.2)

	_hp_label.text = GameLocale.t(
		"HP %d/%d" % [p.hp, p.max_hp],
		"生命 %d/%d" % [p.hp, p.max_hp]
	)

	_block_label.visible = p.block > 0
	_block_icon.visible = p.block > 0
	if p.block > 0:
		_block_label.text = GameLocale.t("Block %d" % p.block, "护甲 %d" % p.block)


func _rebuild_energy_display() -> void:
	for c in _red_energy_container.get_children():
		c.queue_free()
	for c in _blue_energy_container.get_children():
		c.queue_free()

	var e := battle_manager.energy

	for i in e.max_red:
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(12, 12)
		var filled := i < e.current_red
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(6)
		if filled:
			sb.bg_color = Color(0.9, 0.25, 0.15)
		else:
			sb.bg_color = Color(0.3, 0.08, 0.05)
		dot.add_theme_stylebox_override("panel", sb)
		_red_energy_container.add_child(dot)

	var red_text := "R%d/%d" % [e.current_red, e.max_red]

	for i in e.max_blue:
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(12, 12)
		var filled := i < e.current_blue
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(6)
		if filled:
			sb.bg_color = Color(0.2, 0.45, 0.9)
		else:
			sb.bg_color = Color(0.05, 0.08, 0.3)
		dot.add_theme_stylebox_override("panel", sb)
		_blue_energy_container.add_child(dot)

	var blue_text := "B%d/%d" % [e.current_blue, e.max_blue]
	_energy_label.text = "%s  %s" % [red_text, blue_text]


func _update_deck_info() -> void:
	var d := battle_manager.deck
	_draw_pile_btn.text = GameLocale.t(
		"Draw: %d" % d.draw_pile.size(),
		"抽牌: %d" % d.draw_pile.size()
	)
	_discard_pile_btn.text = GameLocale.t(
		"Discard: %d" % d.discard_pile.size(),
		"弃牌: %d" % d.discard_pile.size()
	)
	_exhaust_pile_btn.text = GameLocale.t(
		"Exhaust: %d" % d.exhaust_pile.size(),
		"移除: %d" % d.exhaust_pile.size()
	)


func _on_piles_changed() -> void:
	_update_deck_info()
	if _pile_overlay != null and _pile_overlay.visible:
		_pile_overlay.refresh()


func _open_pile_view(tab: int) -> void:
	_cancel_target_mode()
	_pile_overlay.open(battle_manager.deck, tab)


func _refresh_enemies() -> void:
	for c in _enemy_container.get_children():
		c.queue_free()
	_enemy_widgets.clear()

	for i in battle_manager.enemies.size():
		var enemy := battle_manager.enemies[i]
		var widget := _create_enemy_widget(enemy, i)
		_enemy_container.add_child(widget)
		_enemy_widgets.append(widget)


func _create_enemy_widget(enemy: Combatant, index: int) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(200, 180)
	panel.set_meta("enemy_index", index)

	var default_style := StyleBoxFlat.new()
	default_style.bg_color = Color(0.12, 0.12, 0.16)
	default_style.set_corner_radius_all(10)
	default_style.set_border_width_all(2)
	default_style.border_color = Color(0.25, 0.25, 0.3)
	panel.add_theme_stylebox_override("panel", default_style)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 3)
	panel.add_child(vbox)

	# 名称
	var name_l := Label.new()
	name_l.text = enemy.display_name
	if enemy.is_dead:
		name_l.text += GameLocale.t(" (dead)", " (死亡)")
	UiFonts.apply_font_to(name_l, 15)
	vbox.add_child(name_l)

	# HP 血条
	var hp_bar := ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(180, 12)
	hp_bar.max_value = max(enemy.max_hp, 1)
	hp_bar.value = enemy.hp
	hp_bar.show_percentage = false
	var pct := float(enemy.hp) / float(max(enemy.max_hp, 1))
	if pct > 0.6:
		hp_bar.modulate = Color(0.3, 0.8, 0.3)
	elif pct > 0.3:
		hp_bar.modulate = Color(0.85, 0.7, 0.2)
	else:
		hp_bar.modulate = Color(0.85, 0.2, 0.2)
	vbox.add_child(hp_bar)

	# HP 文字
	var hp_text := Label.new()
	hp_text.text = "%d / %d" % [enemy.hp, enemy.max_hp]
	UiFonts.apply_font_to(hp_text, 11)
	vbox.add_child(hp_text)

	# 护甲
	if enemy.block > 0:
		var block_l := Label.new()
		block_l.text = GameLocale.t("Block %d" % enemy.block, "护甲 %d" % enemy.block)
		UiFonts.apply_font_to(block_l, 12)
		vbox.add_child(block_l)

	# 意图
	var intent_l := Label.new()
	intent_l.text = enemy.intent_desc
	UiFonts.apply_font_to(intent_l, 11)
	vbox.add_child(intent_l)

	# 状态效果
	if not enemy.statuses.is_empty():
		var parts: Array[String] = []
		for k in enemy.statuses:
			parts.append("%s:%d" % [k, enemy.statuses[k]])
		var status_l := Label.new()
		status_l.text = "  ".join(parts)
		UiFonts.apply_font_to(status_l, 10)
		status_l.add_theme_color_override("font_color", Color(0.8, 0.6, 0.3))
		vbox.add_child(status_l)

	# 交互
	if not enemy.is_dead:
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		var cap_idx := index
		panel.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_on_enemy_clicked(cap_idx)
		)
		panel.mouse_entered.connect(_on_enemy_mouse_entered.bind(panel))
		panel.mouse_exited.connect(_on_enemy_mouse_exited.bind(panel))
	else:
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.modulate = Color(0.5, 0.5, 0.5, 0.6)

	return panel


func _refresh_hand() -> void:
	for c in _hand_container.get_children():
		c.queue_free()

	var hand := battle_manager.deck.hand
	for i in hand.size():
		var inst := hand[i]
		var data := inst.get_data()
		if data == null:
			continue
		var card_ui := CardWidgetScene.new()
		var playable := battle_manager.can_play_card(i)
		card_ui.setup(data, not playable)
		var cap_i := i
		card_ui.card_pressed.connect(func(): _on_card_pressed(cap_i))
		_hand_container.add_child(card_ui)


# ---- 交互逻辑 ----

func _on_card_pressed(hand_index: int) -> void:
	if not battle_manager.can_play_card(hand_index):
		return

	var inst := battle_manager.deck.hand[hand_index]
	var data := inst.get_data()
	if data == null:
		return

	_cancel_target_mode()

	match data.target:
		CardData.TargetType.ENEMY:
			_target_mode = TargetMode.SELECTING_TARGET
			_selected_card_index = hand_index
			_highlight_enemies(true)
			_highlight_card(hand_index, true)

		CardData.TargetType.ALL_ENEMIES, CardData.TargetType.SELF, CardData.TargetType.NONE:
			battle_manager.play_card(hand_index, 0)
			_refresh_all()


func _on_enemy_clicked(enemy_index: int) -> void:
	if _target_mode != TargetMode.SELECTING_TARGET:
		return
	if enemy_index < 0 or enemy_index >= battle_manager.enemies.size():
		return
	if battle_manager.enemies[enemy_index].is_dead:
		return

	battle_manager.play_card(_selected_card_index, enemy_index)
	_cancel_target_mode()
	_refresh_all()


func _cancel_target_mode() -> void:
	if _target_mode == TargetMode.SELECTING_TARGET:
		_highlight_enemies(false)
		if _selected_card_index >= 0:
			_highlight_card(_selected_card_index, false)
	_target_mode = TargetMode.IDLE
	_selected_card_index = -1


func _highlight_enemies(highlight: bool) -> void:
	var border_color := Color(0.95, 0.85, 0.25, 0.9) if highlight else Color(0.25, 0.25, 0.3)
	var bg_color := Color(0.16, 0.16, 0.22) if highlight else Color(0.12, 0.12, 0.16)
	for panel in _enemy_widgets:
		var idx: int = panel.get_meta("enemy_index", -1)
		if idx < 0 or idx >= battle_manager.enemies.size():
			continue
		if battle_manager.enemies[idx].is_dead:
			continue
		var style := StyleBoxFlat.new()
		style.bg_color = bg_color
		style.set_corner_radius_all(10)
		style.set_border_width_all(2)
		style.border_color = border_color
		panel.add_theme_stylebox_override("panel", style)


func _highlight_card(hand_index: int, highlight: bool) -> void:
	var children := _hand_container.get_children()
	if hand_index >= 0 and hand_index < children.size():
		var card := children[hand_index]
		if card is CardWidget:
			card.set_selected(highlight)


func _on_enemy_mouse_entered(panel: Panel) -> void:
	if _target_mode != TargetMode.SELECTING_TARGET:
		return
	var idx: int = panel.get_meta("enemy_index", -1)
	if idx < 0 or idx >= battle_manager.enemies.size():
		return
	if battle_manager.enemies[idx].is_dead:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.28)
	style.set_corner_radius_all(10)
	style.set_border_width_all(3)
	style.border_color = Color(1.0, 0.9, 0.3, 1.0)
	panel.add_theme_stylebox_override("panel", style)


func _on_enemy_mouse_exited(_panel: Panel) -> void:
	if _target_mode != TargetMode.SELECTING_TARGET:
		return
	# 恢复为标准高亮
	_highlight_enemies(true)


func _on_end_turn() -> void:
	_cancel_target_mode()
	battle_manager.end_player_turn()


func _on_battle_ended(victory: bool) -> void:
	_last_victory = victory
	_victory_dim.visible = true
	_victory_panel.visible = true
	if victory:
		_victory_label.text = GameLocale.t("Victory!", "胜利！")
		_continue_btn.text = GameLocale.t("Continue", "继续")
	else:
		_victory_label.text = GameLocale.t("Defeat...", "战败...")
		_continue_btn.text = GameLocale.t("Main Menu", "返回主菜单")


func _on_continue() -> void:
	get_parent().on_battle_finished(_last_victory)
