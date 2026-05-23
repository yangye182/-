## 战斗后卡牌奖励：选牌 或 免费进化一张已有卡牌
extends Control

signal reward_finished

enum Mode { CARD_SELECT, EVOLVE_PICK, EVOLVE_BRANCH }

var _mode: Mode = Mode.CARD_SELECT
var _card_offers: Array[String] = []
var _chosen: bool = false
var _can_evolve: bool = false
var _evolvable_instances: Array[Dictionary] = []
var _selected_deck_index: int = -1

var _title_label: Label
var _hint_label: Label
var _card_row: HBoxContainer
var _evolve_btn: Button
var _back_btn: Button
var _skip_btn: Button


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(660, 460)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	_title_label = Label.new()
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFonts.apply_font_to(_title_label, 22)
	vbox.add_child(_title_label)

	_hint_label = Label.new()
	_hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFonts.apply_font_to(_hint_label, 14)
	vbox.add_child(_hint_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_card_row = HBoxContainer.new()
	_card_row.add_theme_constant_override("separation", 20)
	_card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_card_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_card_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_card_row)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	_evolve_btn = Button.new()
	_evolve_btn.pressed.connect(_on_evolve_click)
	UiFonts.apply_font_to(_evolve_btn, 16)
	btn_row.add_child(_evolve_btn)

	_back_btn = Button.new()
	_back_btn.pressed.connect(_on_mode_back)
	UiFonts.apply_font_to(_back_btn, 16)
	btn_row.add_child(_back_btn)

	_skip_btn = Button.new()
	_skip_btn.pressed.connect(_on_skip)
	UiFonts.apply_font_to(_skip_btn, 16)
	btn_row.add_child(_skip_btn)


func open_reward(count: int = 3) -> void:
	_chosen = false
	_mode = Mode.CARD_SELECT
	_card_offers = _generate_offers(count)
	_build_evolvable()
	_can_evolve = _is_combat_reward() and not _evolvable_instances.is_empty()
	_refresh_display()


## 只有战斗类节点才展示"进化"选项（RUNE_FORGE 不展示）
func _is_combat_reward() -> bool:
	if RunState.map_nodes.is_empty():
		return false
	var n: MapNodeData = RunState.map_nodes[RunState.current_node_id]
	return n.type in [
		MapNodeData.NodeType.COMBAT,
		MapNodeData.NodeType.ELITE,
		MapNodeData.NodeType.VOID_RIFT,
		MapNodeData.NodeType.BOSS
	]


## 扫描牌组，收集可进化的卡牌（移植自 sage_altar_screen）
func _build_evolvable() -> void:
	_evolvable_instances.clear()
	var counter: Dictionary = {}
	for i in RunState.deck_ids.size():
		var cid := RunState.deck_ids[i]
		counter[cid] = counter.get(cid, 0) + 1
		var key := "%s@%d" % [cid, counter[cid]]
		if RunState.evolution_map.has(key):
			continue
		var data := GameDB.get_card(cid)
		if data and not data.evolves_to.is_empty():
			_evolvable_instances.append({
				"deck_index": i,
				"card_id": cid,
				"data": data,
				"key": key,
			})


func _refresh_display() -> void:
	for c in _card_row.get_children():
		c.queue_free()

	match _mode:
		Mode.CARD_SELECT:
			_show_card_select()
		Mode.EVOLVE_PICK:
			_show_evolve_pick()
		Mode.EVOLVE_BRANCH:
			_show_evolve_branches()

	_evolve_btn.visible = _mode == Mode.CARD_SELECT and _can_evolve
	_back_btn.visible = _mode != Mode.CARD_SELECT
	_skip_btn.visible = _mode == Mode.CARD_SELECT
	if _mode == Mode.CARD_SELECT:
		_evolve_btn.text = GameLocale.t("Evolve a card", "进化一张卡牌")


func _show_card_select() -> void:
	_title_label.text = GameLocale.t("Choose a Card", "选择一张卡牌")
	_hint_label.text = GameLocale.t(
		"Pick one card to add to your deck.",
		"挑选一张卡牌加入牌组。"
	)

	for cid in _card_offers:
		var data := GameDB.get_card(cid)
		if data == null:
			continue
		var card_widget := preload("res://src/ui/card/card_widget.gd").new()
		card_widget.setup(data, false)
		var cap_cid := cid
		card_widget.card_pressed.connect(func(): _on_pick_card(cap_cid))
		_card_row.add_child(card_widget)


func _show_evolve_pick() -> void:
	_title_label.text = GameLocale.t("Evolve a Card", "进化卡牌")
	_hint_label.text = GameLocale.t(
		"Select a card to evolve it for free.",
		"选择一张卡牌免费进化。"
	)

	if _evolvable_instances.is_empty():
		var msg := Label.new()
		msg.text = GameLocale.t("No cards can be evolved.", "没有可以进化的卡牌。")
		msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_card_row.add_child(msg)
		return


	var pick_count := mini(_evolvable_instances.size(), 3)
	var pool := _evolvable_instances.duplicate()
	pool.shuffle()
	var offers := pool.slice(0, pick_count)

	for ev in offers:
		var data: CardData = ev["data"]
		var idx: int = ev["deck_index"]
		var cap_idx := idx
		var card_widget := preload("res://src/ui/card/card_widget.gd").new()
		card_widget.setup(data, false)
		card_widget.card_pressed.connect(func(): _on_evo_pick_card(cap_idx))
		_card_row.add_child(card_widget)


func _show_evolve_branches() -> void:
	var ev: Dictionary
	var found := false
	for e in _evolvable_instances:
		if e["deck_index"] == _selected_deck_index:
			ev = e
			found = true
			break
	if not found:
		_selected_deck_index = -1
		_mode = Mode.EVOLVE_PICK
		_refresh_display()
		return

	var data: CardData = ev["data"]
	_title_label.text = GameLocale.t(
		"Choose Evolution Path",
		"选择进化路径"
	)
	_hint_label.text = GameLocale.t(
		"Evolving [%s]..." % data.get_display_name(),
		"进化【%s】..." % data.get_display_name()
	)

	for branch in data.evolves_to:
		var branch_data: Dictionary = branch as Dictionary
		var target_id: String = branch_data.get("id", "")
		var desc_en: String = branch_data.get("desc_en", "")
		var desc_zh: String = branch_data.get("desc_zh", "")
		var target_data := GameDB.get_card(target_id)

		var path_box := VBoxContainer.new()
		path_box.add_theme_constant_override("separation", 6)

		var name_lbl := Label.new()
		name_lbl.text = target_data.get_display_name() if target_data else target_id
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UiFonts.apply_font_to(name_lbl, 15)
		path_box.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = GameLocale.t(desc_en, desc_zh)
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.custom_minimum_size = Vector2(150, 0)
		UiFonts.apply_font_to(desc_lbl, 12)
		path_box.add_child(desc_lbl)

		var evolve_btn := Button.new()
		evolve_btn.text = GameLocale.t("Evolve (Free)", "进化（免费）")
		UiFonts.apply_font_to(evolve_btn, 14)
		var cap_tid := target_id
		evolve_btn.pressed.connect(func(): _on_evo_pick_branch(cap_tid))
		path_box.add_child(evolve_btn)

		_card_row.add_child(path_box)


func _on_evolve_click() -> void:
	_mode = Mode.EVOLVE_PICK
	_selected_deck_index = -1
	_refresh_display()


func _on_evo_pick_card(deck_index: int) -> void:
	_selected_deck_index = deck_index
	_mode = Mode.EVOLVE_BRANCH
	_refresh_display()


func _on_evo_pick_branch(target_id: String) -> void:
	if _selected_deck_index < 0 or _chosen:
		return
	_chosen = true
	RunState.evolve_card_at(_selected_deck_index, target_id)
	_finish()


func _on_mode_back() -> void:
	match _mode:
		Mode.EVOLVE_PICK:
			_mode = Mode.CARD_SELECT
		Mode.EVOLVE_BRANCH:
			_mode = Mode.EVOLVE_PICK
	_refresh_display()


func _generate_offers(count: int) -> Array[String]:
	var commons: Array[String] = []
	var uncommons: Array[String] = []
	var rares: Array[String] = []
	for cid in GameDB.cards.keys():
		var data := GameDB.get_card(cid)
		if data == null or data.rarity == "starter":
			continue
		match data.rarity:
			"common": commons.append(cid)
			"uncommon": uncommons.append(cid)
			"rare": rares.append(cid)

	var result: Array[String] = []
	var pool_weights := [
		[commons, 0.5],
		[uncommons, 0.35],
		[rares, 0.15],
	]
	for i in range(count):
		if _all_empty([commons, uncommons, rares]):
			break
		var chosen_pool: Array[String] = []
		var roll := randf()
		var cumulative := 0.0
		for pw in pool_weights:
			var pool: Array[String] = pw[0]
			var weight: float = pw[1]
			if pool.is_empty():
				continue
			cumulative += weight
			if roll <= cumulative:
				chosen_pool = pool
				break
		if chosen_pool.is_empty():
			chosen_pool = commons if not commons.is_empty() else (uncommons if not uncommons.is_empty() else rares)
		if chosen_pool.is_empty():
			break
		var idx := randi() % chosen_pool.size()
		result.append(chosen_pool[idx])
		chosen_pool.remove_at(idx)

	return result


static func _all_empty(arrays: Array) -> bool:
	for a in arrays:
		if not a.is_empty():
			return false
	return true


func _on_pick_card(card_id: String) -> void:
	if _chosen:
		return
	_chosen = true
	RunState.add_card_to_deck(card_id)
	_finish()


func _on_skip() -> void:
	_finish()


func _finish() -> void:
	visible = false
	reward_finished.emit()
