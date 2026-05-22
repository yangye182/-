extends Control

signal event_finished

const ALL_EVENTS := [
	{ "id": 1, "name_en": "Gold Pouch", "name_zh": "钱袋", "desc_en": "Gain 30 Gold", "desc_zh": "获得30金币" },
	{ "id": 2, "name_en": "Healing Spring", "name_zh": "治愈之泉", "desc_en": "Restore 15 HP", "desc_zh": "恢复15生命值" },
	{ "id": 3, "name_en": "Mysterious Box", "name_zh": "神秘宝箱", "desc_en": "Gain a random card", "desc_zh": "获得一张随机卡牌" },
	{ "id": 4, "name_en": "Cursed Altar", "name_zh": "诅咒祭坛", "desc_en": "Lose 10 HP, gain 25 Gold", "desc_zh": "失去10生命，获得25金币" },
	{ "id": 5, "name_en": "Training Ground", "name_zh": "训练场", "desc_en": "Gain 1 Max HP", "desc_zh": "增加1点最大生命值" },
	{ "id": 6, "name_en": "Merchant Cart", "name_zh": "商队", "desc_en": "Gain 20 Gold, lose 5 HP", "desc_zh": "获得20金币，失去5生命" },
	{ "id": 7, "name_en": "Spore Clouds", "name_zh": "孢子云", "desc_en": "Lose 8 HP", "desc_zh": "失去8生命值" },
	{ "id": 8, "name_en": "Windfall", "name_zh": "横财", "desc_en": "Gain 50 Gold", "desc_zh": "获得50金币" },
	{ "id": 9, "name_en": "Dark Ritual", "name_zh": "黑暗仪式", "desc_en": "Lose 3 Max HP, gain 80 Gold", "desc_zh": "失去3最大生命，获得80金币" },
]

@onready var event_buttons: Array[Button] = [
	$Panel/VBox/EventRow1,
	$Panel/VBox/EventRow2,
	$Panel/VBox/EventRow3,
]
@onready var msg_label: Label = $Panel/VBox/MsgLabel
@onready var leave_btn: Button = $Panel/VBox/LeaveButton
@onready var title_label: Label = $Panel/VBox/Title

var _current_events: Array[Dictionary] = []


func _ready() -> void:
	leave_btn.pressed.connect(_on_leave)
	for i in 3:
		event_buttons[i].pressed.connect(_on_event_pressed.bind(i))
	_apply_locale()


func _apply_locale() -> void:
	title_label.text = GameLocale.t("Event", "事件")
	leave_btn.text = GameLocale.t("Leave", "离开")
	UiFonts.apply_font_to(title_label, 22)
	UiFonts.apply_font_to(msg_label, 14)
	UiFonts.apply_font_to(leave_btn, 16)
	for btn in event_buttons:
		UiFonts.apply_font_to(btn, 14)


func open_event() -> void:
	var pool := ALL_EVENTS.duplicate()
	pool.shuffle()
	_current_events.clear()
	for i in 3:
		_current_events.append(pool[i] as Dictionary)
	_refresh()


func _refresh() -> void:
	for i in 3:
		var btn: Button = event_buttons[i]
		var evt := _current_events[i]
		btn.text = "%s  —  %s" % [
			GameLocale.t(evt.name_en, evt.name_zh),
			GameLocale.t(evt.desc_en, evt.desc_zh)
		]
		btn.disabled = false
	msg_label.text = GameLocale.t("Choose an event to trigger", "选择一个事件触发")


func _on_event_pressed(index: int) -> void:
	var evt := _current_events[index] as Dictionary
	_apply_effect(evt)
	event_buttons[index].disabled = true
	msg_label.text = GameLocale.t("Event triggered! Click Leave to continue.", "事件已触发！点击离开继续。")


func _apply_effect(evt: Dictionary) -> void:
	match evt.id:
		1: RunState.gold += 30
		2: RunState.current_hp = mini(RunState.current_hp + 15, RunState.max_hp)
		3: _give_random_card()
		4:
			RunState.current_hp = maxi(RunState.current_hp - 10, 0)
			RunState.gold += 25
		5: RunState.max_hp += 1
		6:
			RunState.gold += 20
			RunState.current_hp = maxi(RunState.current_hp - 5, 0)
		7: RunState.current_hp = maxi(RunState.current_hp - 8, 0)
		8: RunState.gold += 50
		9:
			RunState.max_hp = maxi(RunState.max_hp - 3, 1)
			RunState.current_hp = mini(RunState.current_hp, RunState.max_hp)
			RunState.gold += 80


func _give_random_card() -> void:
	var pool := GameDB.cards.keys()
	if pool.is_empty():
		return
	RunState.add_card_to_deck(pool[randi() % pool.size()])


func _on_leave() -> void:
	event_finished.emit()
