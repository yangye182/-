## 贤者祭坛：进化卡牌（单张独立进化）
extends Control

signal sage_finished

var _gold_label: Label
var _msg_label: Label
var _hint_label: Label
var _pick_scroll: ScrollContainer
var _pick_row: HBoxContainer
var _paths_row: HBoxContainer
var _back_btn: Button
var _leave_btn: Button

## 当前牌组中可进化的卡牌列表（带牌组索引）
var _evolvable_instances: Array[Dictionary] = []
## 当前选中的卡牌在牌组中的索引
var _selected_deck_index: int = -1


func _ready() -> void:
	_build_refs()
	_apply_locale()


func _build_refs() -> void:
	var root: VBoxContainer = $Panel/VBox
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
		"Evolve a card for free and restore 15 HP.",
		"免费进化一张卡牌，并恢复 15 点生命。"
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
	_selected_deck_index = -1
	_build_evolvable()
	_refresh()


## 扫描牌组，收集可进化的卡牌
func _build_evolvable() -> void:
	_evolvable_instances.clear()
	var counter: Dictionary = {}
	for i in RunState.deck_ids.size():
		var cid := RunState.deck_ids[i]
		counter[cid] = counter.get(cid, 0) + 1
		var key := "%s@%d" % [cid, counter[cid]]
		if RunState.evolution_map.has(key):
			continue  # 已进化
		var data := GameDB.get_card(cid)
		if data and not data.evolves_to.is_empty():
			_evolvable_instances.append({
				"deck_index": i,
				"card_id": cid,
				"data": data,
				"key": key,
			})


func _refresh() -> void:
	_gold_label.text = GameLocale.t("Gold: %d" % RunState.gold, "金币: %d" % RunState.gold)
	_back_btn.visible = _selected_deck_index >= 0
	_paths_row.visible = _selected_deck_index >= 0
	_pick_scroll.visible = _selected_deck_index < 0

	if _selected_deck_index < 0:
		_show_pick_cards()
	else:
		_show_paths()


func _show_pick_cards() -> void:
	for c in _pick_row.get_children():
		c.queue_free()
	for c in _paths_row.get_children():
		c.queue_free()

	if _evolvable_instances.is_empty():
		_msg_label.text = GameLocale.t(
			"No cards can be evolved here.",
			"没有可以进化的卡牌。"
		)
		return

	_msg_label.text = GameLocale.t("Select a card to evolve", "选择要进化的卡牌")

	for ev in _evolvable_instances:
		var data: CardData = ev["data"]
		var idx: int = ev["deck_index"]

		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(140, 48)
		btn.text = "%s #%d" % [data.get_display_name(), idx + 1]
		UiFonts.apply_font_to(btn, 13)
		var cap_idx := idx
		btn.pressed.connect(func(): _on_pick_card(cap_idx))
		box.add_child(btn)

		var info := Label.new()
		var branch_count := data.evolves_to.size()
		info.text = GameLocale.t(
			"%d options" % branch_count,
			"%d 种分支" % branch_count
		)
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UiFonts.apply_font_to(info, 12)
		box.add_child(info)

		_pick_row.add_child(box)


func _on_pick_card(deck_index: int) -> void:
	_selected_deck_index = deck_index
	_refresh()


func _show_paths() -> void:
	for c in _paths_row.get_children():
		c.queue_free()

	# 查找当前选中的卡牌数据
	var ev: Dictionary
	var found := false
	for e in _evolvable_instances:
		if e["deck_index"] == _selected_deck_index:
			ev = e
			found = true
			break
	if not found:
		_selected_deck_index = -1
		_refresh()
		return

	var data: CardData = ev["data"]
	_msg_label.text = GameLocale.t(
		"Evolve [%s] — choose a path" % data.get_display_name(),
		"进化【%s】— 选择路径" % data.get_display_name()
	)

	for branch in data.evolves_to:
		var branch_data: Dictionary = branch as Dictionary
		var target_id: String = branch_data.get("id", "")
		var desc_en: String = branch_data.get("desc_en", "")
		var desc_zh: String = branch_data.get("desc_zh", "")
		var target_data := GameDB.get_card(target_id)

		var path_box := VBoxContainer.new()
		path_box.add_theme_constant_override("separation", 8)

		var name_lbl := Label.new()
		name_lbl.text = target_data.get_display_name() if target_data else target_id
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UiFonts.apply_font_to(name_lbl, 15)
		path_box.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = GameLocale.t(desc_en, desc_zh)
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.custom_minimum_size = Vector2(160, 0)
		UiFonts.apply_font_to(desc_lbl, 12)
		path_box.add_child(desc_lbl)

		var evolve_btn := Button.new()
		evolve_btn.text = GameLocale.t(
			"Evolve (Free + Heal 15 HP)",
			"进化（免费+治疗15点）"
		)
		UiFonts.apply_font_to(evolve_btn, 14)
		var cap_idx := _selected_deck_index
		var cap_target := target_id
		evolve_btn.pressed.connect(func(): _on_evolve(cap_idx, cap_target))
		path_box.add_child(evolve_btn)

		_paths_row.add_child(path_box)


func _on_evolve(deck_index: int, target_id: String) -> void:
	RunState.evolve_card_at(deck_index, target_id)
	RunState.current_hp = mini(RunState.current_hp + 15, RunState.max_hp)
	var target_data := GameDB.get_card(target_id)
	var name_str := target_data.get_display_name() if target_data else target_id
	_msg_label.text = GameLocale.t("Evolved to [%s]!" % name_str, "已进化为【%s】！" % name_str)
	sage_finished.emit()


func _on_back() -> void:
	_selected_deck_index = -1
	_refresh()


func _on_leave() -> void:
	sage_finished.emit()
