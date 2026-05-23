## 背包：查看牌组与遗物（地图等处可打开）
extends Control

const CardWidgetScene := preload("res://src/ui/card/card_widget.gd")

signal backpack_closed

var _deck_grid: GridContainer
var _relic_list: VBoxContainer
var _stats_label: Label


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 520)
	center.add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	panel.add_child(root)

	var title := Label.new()
	title.text = GameLocale.t("Backpack", "背包")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFonts.apply_font_to(title, 22)
	root.add_child(title)

	_stats_label = Label.new()
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFonts.apply_font_to(_stats_label, 14)
	root.add_child(_stats_label)

	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(680, 380)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)

	# 牌组页
	var deck_page := ScrollContainer.new()
	deck_page.name = GameLocale.t("Deck", "牌组")
	deck_page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(deck_page)
	var deck_center := CenterContainer.new()
	deck_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	deck_page.add_child(deck_center)
	_deck_grid = GridContainer.new()
	_deck_grid.columns = 4
	_deck_grid.add_theme_constant_override("h_separation", 16)
	_deck_grid.add_theme_constant_override("v_separation", 16)
	deck_center.add_child(_deck_grid)

	# 遗物页
	var relic_page := ScrollContainer.new()
	relic_page.name = GameLocale.t("Relics", "遗物")
	relic_page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(relic_page)
	_relic_list = VBoxContainer.new()
	_relic_list.add_theme_constant_override("separation", 10)
	_relic_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var relic_margin := MarginContainer.new()
	relic_margin.add_theme_constant_override("margin_left", 16)
	relic_margin.add_theme_constant_override("margin_right", 16)
	relic_margin.add_theme_constant_override("margin_top", 8)
	relic_margin.add_theme_constant_override("margin_bottom", 8)
	relic_margin.add_child(_relic_list)
	relic_page.add_child(relic_margin)

	var close_btn := Button.new()
	close_btn.text = GameLocale.t("Close", "关闭")
	UiFonts.apply_font_to(close_btn, 16)
	close_btn.pressed.connect(_on_close)
	root.add_child(close_btn)


func refresh() -> void:
	_stats_label.text = GameLocale.t(
		"HP %d/%d  |  Gold %d  |  %d cards in deck" % [
			RunState.current_hp, RunState.max_hp, RunState.gold, RunState.deck_ids.size()
		],
		"生命 %d/%d  |  金币 %d  |  牌组共 %d 张" % [
			RunState.current_hp, RunState.max_hp, RunState.gold, RunState.deck_ids.size()
		]
	)
	_refresh_deck()
	_refresh_relics()


func _refresh_deck() -> void:
	for c in _deck_grid.get_children():
		c.queue_free()
	for cid in RunState.get_unique_deck_ids():
		var data := GameDB.get_card(cid)
		if data == null:
			continue
		var cnt := RunState.count_cards(cid)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		var card_ui = CardWidgetScene.new()
		card_ui.setup(data, false)
		box.add_child(card_ui)
		var count_lbl := Label.new()
		count_lbl.text = GameLocale.t("x%d" % cnt, "×%d" % cnt)
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UiFonts.apply_font_to(count_lbl, 14)
		box.add_child(count_lbl)
		if data and not data.evolves_to.is_empty():
			var hint := Label.new()
			hint.text = GameLocale.t("Can evolve at Sage Altar", "可在贤者祭坛进化")
			hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			hint.modulate = Color(0.85, 0.75, 0.4)
			UiFonts.apply_font_to(hint, 11)
			box.add_child(hint)
		_deck_grid.add_child(box)


func _refresh_relics() -> void:
	for c in _relic_list.get_children():
		c.queue_free()
	if RunState.relic_ids.is_empty():
		var empty := Label.new()
		empty.text = GameLocale.t("No relics yet.", "暂无遗物。")
		UiFonts.apply_font_to(empty, 14)
		_relic_list.add_child(empty)
		return
	for rid in RunState.relic_ids:
		var data := GameDB.get_relic(rid)
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		var name_lbl := Label.new()
		name_lbl.text = GameLocale.pick_field(data, "name", "name_zh")
		UiFonts.apply_font_to(name_lbl, 16)
		var desc_lbl := Label.new()
		desc_lbl.text = GameLocale.pick_field(data, "description", "description_zh")
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UiFonts.apply_font_to(desc_lbl, 13)
		desc_lbl.modulate = Color(0.85, 0.85, 0.9)
		row.add_child(name_lbl)
		row.add_child(desc_lbl)
		_relic_list.add_child(row)


func _on_close() -> void:
	visible = false
	backpack_closed.emit()
