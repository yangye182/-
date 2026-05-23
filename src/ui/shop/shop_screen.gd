extends Control

const CardWidgetScene := preload("res://src/ui/card/card_widget.gd")

signal shop_finished

@onready var gold_label: Label = $Panel/VBox/Header/GoldLabel
@onready var cards_row: HBoxContainer = $Panel/VBox/CardsRow
@onready var remove_btn: Button = $Panel/VBox/Actions/RemoveButton
@onready var leave_btn: Button = $Panel/VBox/Actions/LeaveButton
@onready var msg_label: Label = $Panel/VBox/MsgLabel

var _offers: Array[Dictionary] = []


func _ready() -> void:
	remove_btn.pressed.connect(_on_remove_service)
	leave_btn.pressed.connect(_on_leave)
	_apply_locale()


func _apply_locale() -> void:
	$Panel/VBox/Title.text = GameLocale.t("Merchant", "商人")
	remove_btn.text = GameLocale.t("Remove a card (75g)", "移除一张牌 (75金)")
	leave_btn.text = GameLocale.t("Leave Shop", "离开商店")
	UiFonts.apply_font_to($Panel/VBox/Title, 22)
	UiFonts.apply_font_to(gold_label, 18)
	UiFonts.apply_font_to(msg_label, 14)
	UiFonts.apply_font_to(remove_btn, 14)
	UiFonts.apply_font_to(leave_btn, 16)


func open_shop() -> void:
	_offers = ShopGenerator.generate_card_offers(3)
	_refresh()


func _refresh() -> void:
	gold_label.text = GameLocale.t("Gold: %d" % RunState.gold, "金币: %d" % RunState.gold)
	for c in cards_row.get_children():
		c.queue_free()
	for offer in _offers:
		if offer.get("sold", false):
			continue
		var cid: String = offer.get("card_id", "")
		var data := GameDB.get_card(cid)
		if data == null:
			continue
		var price: int = int(offer.get("price", 50))
		var offer_box := VBoxContainer.new()
		offer_box.add_theme_constant_override("separation", 8)
		var card_ui = CardWidgetScene.new()
		var can_buy := RunState.gold >= price
		card_ui.setup(data, not can_buy, price)
		var buy_btn := Button.new()
		buy_btn.text = GameLocale.t("Buy", "购买")
		buy_btn.disabled = not can_buy
		UiFonts.apply_font_to(buy_btn, 14)
		var offer_ref := offer
		buy_btn.pressed.connect(func(): _buy_card(offer_ref))
		card_ui.card_pressed.connect(func():
			if can_buy:
				_buy_card(offer_ref)
		)
		offer_box.add_child(card_ui)
		offer_box.add_child(buy_btn)
		cards_row.add_child(offer_box)
	msg_label.text = GameLocale.t("Click a card or Buy button", "点击卡牌或购买按钮")


func _buy_card(offer: Dictionary) -> void:
	if offer.get("sold", false):
		return
	var price: int = int(offer.get("price", 0))
	if RunState.gold < price:
		msg_label.text = GameLocale.t("Not enough gold!", "金币不足！")
		return
	RunState.gold -= price
	RunState.add_card_to_deck(offer.get("card_id", ""))
	offer["sold"] = true
	msg_label.text = GameLocale.t("Purchased!", "购买成功！")
	_refresh()


func _on_remove_service() -> void:
	var price := ShopGenerator.get_remove_card_price()
	if RunState.gold < price:
		msg_label.text = GameLocale.t("Not enough gold!", "金币不足！")
		return
	if RunState.deck_ids.size() <= 5:
		msg_label.text = GameLocale.t("Deck too small!", "牌组太少了！")
		return
	RunState.gold -= price
	# 移除起始牌堆中的一张打击（简化）
	var idx := RunState.deck_ids.find("strike")
	if idx < 0:
		idx = 0
	RunState.deck_ids.remove_at(idx)
	msg_label.text = GameLocale.t("Removed a card.", "已移除一张牌。")
	_refresh()


func _on_leave() -> void:
	shop_finished.emit()
