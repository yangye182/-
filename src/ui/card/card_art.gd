## 卡牌美术资源路径（Kenney CC0，见 assets/cards/CREDITS.txt）
class_name CardArt
extends RefCounted

const FRAME_ATTACK := "res://assets/cards/frames/attack.png"
const FRAME_SKILL := "res://assets/cards/frames/skill.png"
const FRAME_POWER := "res://assets/cards/frames/power.png"
const CARD_BG := "res://assets/cards/frames/card_bg.png"
const ICON_ATTACK := "res://assets/cards/icons/attack.png"
const ICON_SKILL := "res://assets/cards/icons/skill.png"
const ICON_POWER := "res://assets/cards/icons/power.png"

static var _cache: Dictionary = {}


static func get_frame_texture(card_type: CardData.CardType) -> Texture2D:
	var path := FRAME_ATTACK
	match card_type:
		CardData.CardType.ATTACK:
			path = FRAME_ATTACK
		CardData.CardType.SKILL:
			path = FRAME_SKILL
		CardData.CardType.POWER:
			path = FRAME_POWER
	return _load(path)


static func get_icon_texture(card_type: CardData.CardType) -> Texture2D:
	var path := ICON_ATTACK
	match card_type:
		CardData.CardType.ATTACK:
			path = ICON_ATTACK
		CardData.CardType.SKILL:
			path = ICON_SKILL
		CardData.CardType.POWER:
			path = ICON_POWER
	return _load(path)


static func get_card_bg_texture() -> Texture2D:
	return _load(CARD_BG)


static func _load(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path] as Texture2D
	if not ResourceLoader.exists(path):
		push_warning("Card art missing: %s" % path)
		return null
	var tex := load(path) as Texture2D
	_cache[path] = tex
	return tex
