extends Control

signal sage_altar_finished

@onready var title_label: Label = $Panel/VBox/Title
@onready var gold_label: Label = $Panel/VBox/GoldLabel
@onready var msg_label: Label = $Panel/VBox/MsgLabel
@onready var deck_list: VBoxContainer = $Panel/VBox/DeckList
@onready var branches_container: VBoxContainer = $Panel/VBox/BranchesContainer
@onready var leave_btn: Button = $Panel/VBox/LeaveButton

## 所有可进化卡牌及其在牌组中的索引
var _evolvable_cards: Array[Dictionary] = []
## 当前选中的卡牌索引
var _selected_deck_index: int = -1
## 卡牌背景颜色
const BG_COLOR := Color(0.12, 0.14, 0.2, 1.0)
const HIGHLIGHT_COLOR := Color(0.2, 0.3, 0.4, 1.0)


func _ready() -> void:
	leave_btn.pressed.connect(_on_leave)
	_apply_locale()


func _apply_locale() -> void:
	title_label.text = GameLocale.t("Sage Altar", "贤者祭坛")
	leave_btn.text = GameLocale.t("Leave", "离开")
	UiFonts.apply_font_to(title_label, 22)
	UiFonts.apply_font_to(gold_label, 16)
	UiFonts.apply_font_to(msg_label, 14)
	UiFonts.apply_font_to(leave_btn, 16)


func open_sage_altar() -> void:
	_build_evolvable_list()
	_selected_deck_index = -1
	branches_container.hide()
	_refresh()


## 收集所有可进化的卡牌（有 evolves_to 且未进化）
func _build_evolvable_list() -> void:
	_evolvable_cards.clear()
	var counter: Dictionary = {}
	for i in RunState.deck_ids.size():
		var cid := RunState.deck_ids[i]
		counter[cid] = counter.get(cid, 0) + 1
		var key := "%s@%d" % [cid, counter[cid]]
		# 跳过已进化的
		if RunState.evolution_map.has(key):
			continue
		var data := GameDB.get_card(cid)
		if data and not data.evolves_to.is_empty():
			_evolvable_cards.append({
				"deck_index": i,
				"card_id": cid,
				"data": data,
				"key": key,
			})


func _refresh() -> void:
	gold_label.text = GameLocale.t("Gold: %d" % RunState.gold, "金币: %d" % RunState.gold)

	# 清空牌组列表
	for c in deck_list.get_children():
		c.queue_free()

	if _evolvable_cards.is_empty():
		msg_label.text = GameLocale.t("No cards can be evolved.", "没有可以进化的卡牌。")
		return

	msg_label.text = GameLocale.t("Select a card to evolve.", "选择一张卡牌进化。")

	for ev in _evolvable_cards:
		var data: CardData = ev["data"]
		var idx: int = ev["deck_index"]
		var btn := Button.new()
		btn.text = "%s  (%s)" % [
			data.get_display_name(),
			GameLocale.t("Slot %d" % (idx + 1), "第%d张" % (idx + 1))
		]
		btn.custom_minimum_size = Vector2(0, 36)
		if _selected_deck_index == idx:
			btn.modulate = Color(0.7, 0.9, 1.0, 1.0)
		UiFonts.apply_font_to(btn, 14)
		var capture_idx := idx
		btn.pressed.connect(func(): _on_card_selected(capture_idx))
		deck_list.add_child(btn)


func _on_card_selected(deck_index: int) -> void:
	_selected_deck_index = deck_index
	branches_container.show()

	# 清空分支列表
	for c in branches_container.get_children():
		c.queue_free()

	# 找到对应的 evolvable entry
	var ev: Dictionary
	var found := false
	for e in _evolvable_cards:
		if e["deck_index"] == deck_index:
			ev = e
			found = true
			break
	if not found:
		return

	var data: CardData = ev["data"]
	var label := Label.new()
	label.text = GameLocale.t("Evolve %s:" % data.get_display_name(), "进化 %s：" % data.get_display_name())
	UiFonts.apply_font_to(label, 16)
	branches_container.add_child(label)

	for branch in data.evolves_to:
		var branch_data: Dictionary = branch as Dictionary
		var target_id: String = branch_data.get("id", "")
		var cost: int = branch_data.get("cost", 50)
		var desc_en: String = branch_data.get("desc_en", "")
		var desc_zh: String = branch_data.get("desc_zh", "")
		var target_data := GameDB.get_card(target_id)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)

		var info := Label.new()
		var desc := GameLocale.t(desc_en, desc_zh)
		info.text = "%s  (%s)" % [target_data.get_display_name() if target_data else target_id, desc]
		info.size_flags_horizontal = 3
		UiFonts.apply_font_to(info, 14)
		hbox.add_child(info)

		var evolve_btn := Button.new()
		evolve_btn.text = GameLocale.t("Evolve (%dg)" % cost, "进化 (%d金)" % cost)
		evolve_btn.disabled = RunState.gold < cost
		UiFonts.apply_font_to(evolve_btn, 14)
		var capture_deck_idx := deck_index
		var capture_target := target_id
		var capture_cost := cost
		evolve_btn.pressed.connect(func(): _on_evolve(capture_deck_idx, capture_target, capture_cost))
		hbox.add_child(evolve_btn)

		branches_container.add_child(hbox)

	_refresh()


func _on_evolve(deck_index: int, target_id: String, cost: int) -> void:
	if RunState.gold < cost:
		msg_label.text = GameLocale.t("Not enough gold!", "金币不足！")
		return

	RunState.gold -= cost
	RunState.evolve_card_at(deck_index, target_id)
	msg_label.text = GameLocale.t("Evolved!", "进化成功！")
	# 从可进化列表中移除
	_evolvable_cards = _evolvable_cards.filter(func(e): return e["deck_index"] != deck_index)
	_selected_deck_index = -1
	branches_container.hide()
	_refresh()


func _on_leave() -> void:
	sage_altar_finished.emit()
