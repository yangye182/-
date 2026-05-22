## Autoload：转发到 GameLocale，供场景脚本使用
extends Node

var use_chinese: bool:
	get:
		return GameLocale.use_chinese
	set(value):
		GameLocale.use_chinese = value


func t(en: String, zh: String) -> String:
	return GameLocale.t(en, zh)


func pick_field(data: Dictionary, key_en: String, key_zh: String = "") -> String:
	return GameLocale.pick_field(data, key_en, key_zh)
