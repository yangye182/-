## 商店商品生成
class_name ShopGenerator
extends RefCounted

const CARD_PRICES := {
	"common": 50,
	"uncommon": 75,
	"rare": 100,
	"starter": 999,
}


static func generate_card_offers(count: int = 3) -> Array[Dictionary]:
	var pool: Array[String] = []
	for card_id in GameDB.cards.keys():
		var data: CardData = GameDB.get_card(card_id)
		if data and data.rarity != "starter":
			pool.append(card_id)
	pool.shuffle()
	var offers: Array[Dictionary] = []
	var n: int = mini(count, pool.size())
	for i in n:
		var cid: String = pool[i]
		var data := GameDB.get_card(cid)
		var price: int = CARD_PRICES.get(data.rarity, 60) if data else 60
		offers.append({"card_id": cid, "price": price, "sold": false})
	return offers


static func get_remove_card_price() -> int:
	return 75
