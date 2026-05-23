## 贤者祭坛：花费金币为牌组中选型卡牌选择进化分支
extends Control

const CardWidgetScene := preload("res://src/ui/card/card_widget.gd")

signal sage_finished

var _built: bool = false
var _gold_label: Label
var _msg_label: Label
var _hint_label: Label
var _pick_scroll: ScrollContainer
var _pick_row: HBoxContainer
var _paths_row: HBoxContainer
var _back_btn: Button
var _leave_btn: Button

var _selected_base: String = ""


func _ready() -> void:
	_build_ui()
	_apply_locale()


func _build_ui() -> void:
	if _built:
		return
	_built = true

	var panel := $Panel
	var root: VBoxContainer = panel.get_node("VBox")

	_gold_label = root.get_node("Header/GoldLabel")
	_hint_label = root.get_node("HintLabel")
	_msg_label = root.get_node("MsgLabel")
	_pick_scroll = root.get_node("PickScroll")
	_pick_row = _pick_scroll.get_node("PickRow")
	_paths_row = root.get_node("PathsRow")
	_back_btn = root.get_node("Actions/BackButton")
	_leave_btn = root.get_node("Actions/LeaveButton")

	_back_btn.pressed.connect(_on_back)
	_leave_btn.pressed.connect(_on_leave)


func _apply_locale() -> void:
	$Panel/VBox/Title.text = GameLocale.t("Sage Altar", "贤者祭坛")
	_hint_label.text = GameLocale.t(
		"Spend gold to evolve a card type (all copies upgrade).",
		"花费金币选择进化分支（该牌型全部张数一并升级）。"
	)
	_back_btn.text = GameLocale.t("Back", "返回")
	_leave_btn.text = GameLocale.t("Leave Altar", "离开祭坛")
	UiFonts.apply_font_to($Panel/VBox/Title, 22)
	UiFonts.apply_font_to(_gold_label, 18)
	UiFonts.apply_font_to(_hint_label, 13)
	UiFonts.apply_font_to(_msg_label, 14)
	UiFonts.apply_font_to(_back_btn, 14)
	UiFonts.apply_font_to(_leave_btn, 16)


func open_altar() -> void:
	_selected_base = ""
	_refresh()


func _refresh() -> void:
	_gold_label.text = GameLocale.t("Gold: %d" % RunState.gold, "金币: %d" % RunState.gold)
	_back_btn.visible = _selected_base != ""
	_paths_row.visible = _selected_base != ""
	_pick_scroll.visible = _selected_base == ""

	if _selected_base == "":
		_show_pick_cards()
	else:
		_show_paths()


func _show_pick_cards() -> void:
	for c in _pick_row.get_children():
		c.queue_free()
	for c in _paths_row.get_children():
		c.queue_free()

	var ids := SageAltarService.get_evolveable_ids()
	if ids.is_empty():
		_msg_label.text = GameLocale.t(
			"No cards here can evolve. Leave to continue.",
			"当前牌组没有可进化的卡牌，请离开祭坛。"
		)
		return

	_msg_label.text = GameLocale.t("Choose a card to evolve", "选择要进化的卡牌")
	for base_id in ids:
		var data := GameDB.get_card(base_id)
		if data == null:
			continue
		var cost := GameDB.get_evolution_cost(base_id)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		var card_ui = CardWidgetScene.new()
		var cnt := RunState.count_cards(base_id)
		card_ui.setup(data, false)
		box.add_child(card_ui)
		var info := Label.new()
		info.text = GameLocale.t(
			"x%d  |  %d gold" % [cnt, cost],
			"×%d  |  %d 金币" % [cnt, cost]
		)
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UiFonts.apply_font_to(info, 12)
		box.add_child(info)
		var pick_btn := Button.new()
		pick_btn.text = GameLocale.t("Select", "选择")
		pick_btn.disabled = not SageAltarService.can_afford(base_id)
		UiFonts.apply_font_to(pick_btn, 13)
		var bid := base_id
		pick_btn.pressed.connect(func(): _on_pick_card(bid))
		box.add_child(pick_btn)
		_pick_row.add_child(box)


func _on_pick_card(base_id: String) -> void:
	if not SageAltarService.can_afford(base_id):
		_msg_label.text = GameLocale.t("Not enough gold!", "金币不足！")
		return
	_selected_base = base_id
	_refresh()


func _show_paths() -> void:
	for c in _paths_row.get_children():
		c.queue_free()

	var base_data := GameDB.get_card(_selected_base)
	var cost := GameDB.get_evolution_cost(_selected_base)
	_msg_label.text = GameLocale.t(
		"Evolve [%s] — %d gold (all copies)" % [base_data.get_display_name() if base_data else _selected_base, cost],
		"进化【%s】— 消耗 %d 金币（全部张数）" % [base_data.get_display_name() if base_data else _selected_base, cost]
	)

	# 当前卡预览
	if base_data:
		var cur_box := VBoxContainer.new()
		cur_box.add_theme_constant_override("separation", 4)
		var cur_lbl := Label.new()
		cur_lbl.text = GameLocale.t("Current", "当前")
		cur_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UiFonts.apply_font_to(cur_lbl, 12)
		cur_box.add_child(cur_lbl)
		var cur_card = CardWidgetScene.new()
		cur_card.setup(base_data, false)
		cur_box.add_child(cur_card)
		_paths_row.add_child(cur_box)

	var arrow := Label.new()
	arrow.text = "→"
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiFonts.apply_font_to(arrow, 24)
	_paths_row.add_child(arrow)

	for path in GameDB.get_evolution_paths(_selected_base):
		var to_id: String = path.get("to_id", "")
		var to_data := GameDB.get_card(to_id)
		if to_data == null:
			continue
		var path_box := VBoxContainer.new()
		path_box.add_theme_constant_override("separation", 8)
		var card_ui = CardWidgetScene.new()
		card_ui.setup(to_data, false)
		path_box.add_child(card_ui)
		var evolve_btn := Button.new()
		evolve_btn.text = GameLocale.t("Evolve", "进化")
		evolve_btn.disabled = not SageAltarService.can_afford(_selected_base)
		UiFonts.apply_font_to(evolve_btn, 14)
		var tid := to_id
		evolve_btn.pressed.connect(func(): _on_evolve(tid))
		path_box.add_child(evolve_btn)
		_paths_row.add_child(path_box)


func _on_evolve(to_id: String) -> void:
	if SageAltarService.evolve(_selected_base, to_id):
		var data := GameDB.get_card(to_id)
		var name_str := data.get_display_name() if data else to_id
		_msg_label.text = GameLocale.t("Evolved to [%s]!" % name_str, "已进化为【%s】！" % name_str)
		sage_finished.emit()
	else:
		_msg_label.text = GameLocale.t("Evolution failed.", "进化失败。")


func _on_back() -> void:
	_selected_base = ""
	_refresh()


func _on_leave() -> void:
	sage_finished.emit()
