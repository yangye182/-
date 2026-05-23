## 抽牌堆 / 弃牌堆 / 手牌管理
class_name DeckManager
extends RefCounted

signal hand_changed
signal piles_changed

var draw_pile: Array[CardInstance] = []
var discard_pile: Array[CardInstance] = []
var hand: Array[CardInstance] = []
var exhaust_pile: Array[CardInstance] = []


func setup_deck(cards: Array[CardInstance]) -> void:
	draw_pile = cards.duplicate()
	discard_pile.clear()
	hand.clear()
	exhaust_pile.clear()
	_shuffle_draw()
	piles_changed.emit()


func _shuffle_draw() -> void:
	draw_pile.shuffle()


func draw_cards(count: int) -> void:
	for _i in count:
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			# 弃牌堆洗回抽牌堆
			while not discard_pile.is_empty():
				draw_pile.append(discard_pile.pop_back())
			_shuffle_draw()
		if draw_pile.is_empty():
			break
		hand.append(draw_pile.pop_back())
	hand_changed.emit()
	piles_changed.emit()


func discard_hand() -> void:
	while not hand.is_empty():
		discard_pile.append(hand.pop_back())
	hand_changed.emit()
	piles_changed.emit()


func play_from_hand(index: int) -> CardInstance:
	if index < 0 or index >= hand.size():
		return null
	var card := hand[index]
	hand.remove_at(index)
	discard_pile.append(card)
	hand_changed.emit()
	piles_changed.emit()
	return card


func move_last_discarded_to_exhaust() -> void:
	if not discard_pile.is_empty():
		exhaust_pile.append(discard_pile.pop_back())
		piles_changed.emit()


func add_to_discard(card: CardInstance) -> void:
	discard_pile.append(card)
	piles_changed.emit()
