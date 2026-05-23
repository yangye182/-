## 战斗内查看抽牌堆 / 弃牌堆 / 移除堆（只读）
class_name PileViewOverlay
extends Control

const CardWidgetScene := preload("res://src/ui/card/card_widget.gd")

enum PileTab { DRAW, DISCARD, EXHAUST }

signal overlay_closed

var _deck: DeckManager
var _tabs: TabContainer
var _draw_grid: GridContainer
var _discard_grid: GridContainer
var _exhaust_grid: GridContainer


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 50
	_build_ui()


func open(deck: DeckManager, tab: int = PileTab.DRAW) -> void:
	_deck = deck
	visible = true
	_refresh_all()
	_tabs.current_tab = tab


func close() -> void:
	if not visible:
		return
	visible = false
	overlay_closed.emit()


func refresh() -> void:
	if visible:
		_refresh_all()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			close()
	)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 540)
	center.add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)

	var title := Label.new()
	title.text = GameLocale.t("Card Piles", "牌堆一览")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFonts.apply_font_to(title, 22)
	root.add_child(title)

	_tabs = TabContainer.new()
	_tabs.custom_minimum_size = Vector2(720, 420)
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.tab_changed.connect(func(_t: int): _refresh_all())
	root.add_child(_tabs)

	_draw_grid = _add_pile_page(
		GameLocale.t("Draw Pile", "抽牌堆"),
		GameLocale.t("Left = next draw (top of deck)", "左侧 = 即将抽到的牌（牌库顶）")
	)
	_discard_grid = _add_pile_page(
		GameLocale.t("Discard Pile", "弃牌堆"),
		GameLocale.t("Left = most recently discarded", "左侧 = 最近弃置的牌")
	)
	_exhaust_grid = _add_pile_page(
		GameLocale.t("Exhaust", "移除堆"),
		GameLocale.t("Cards removed for this combat", "本战已移出牌组的牌")
	)

	var close_btn := Button.new()
	close_btn.text = GameLocale.t("Close", "关闭")
	close_btn.custom_minimum_size = Vector2(120, 36)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(close)
	UiFonts.apply_font_to(close_btn, 15)
	root.add_child(close_btn)


func _add_pile_page(tab_name: String, hint_base: String) -> GridContainer:
	var page := ScrollContainer.new()
	page.name = tab_name
	page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(page)

	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(outer)

	var hint := Label.new()
	hint.text = hint_base
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color(0.65, 0.68, 0.75))
	UiFonts.apply_font_to(hint, 12)
	outer.add_child(hint)

	var grid_wrap := CenterContainer.new()
	grid_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(grid_wrap)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid_wrap.add_child(grid)
	grid.set_meta("hint_label", hint)
	grid.set_meta("hint_base", hint_base)
	return grid


func _refresh_all() -> void:
	if _deck == null:
		return
	_fill_grid(_draw_grid, _deck.draw_pile, true)
	_fill_grid(_discard_grid, _deck.discard_pile, true)
	_fill_grid(_exhaust_grid, _deck.exhaust_pile, false)


func _fill_grid(grid: GridContainer, pile: Array, top_first: bool) -> void:
	if grid == null:
		return
	var hint: Label = grid.get_meta("hint_label") as Label
	var hint_base: String = str(grid.get_meta("hint_base", ""))

	for c in grid.get_children():
		c.queue_free()

	if hint:
		if pile.is_empty():
			hint.text = hint_base + "  ·  " + GameLocale.t("(empty)", "（空）")
		else:
			hint.text = hint_base + "  ·  " + GameLocale.t(
				"%d cards" % pile.size(),
				"共 %d 张" % pile.size()
			)

	var ordered: Array = []
	if top_first:
		for i in range(pile.size() - 1, -1, -1):
			ordered.append(pile[i])
	else:
		for c in pile:
			ordered.append(c)

	if ordered.is_empty():
		var empty_l := Label.new()
		empty_l.text = GameLocale.t("No cards in this pile.", "此牌堆暂无卡牌。")
		UiFonts.apply_font_to(empty_l, 14)
		grid.add_child(empty_l)
		return

	for inst in ordered:
		var card_inst: CardInstance = inst as CardInstance
		if card_inst == null:
			continue
		var data := card_inst.get_data()
		if data == null:
			continue
		var card_ui := CardWidgetScene.new()
		card_ui.setup(data, true)
		card_ui.scale = Vector2(0.82, 0.82)
		card_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(card_ui)
