## 中英文静态工具类（class_name 脚本可安全调用，不依赖 Autoload）
class_name GameLocale
extends RefCounted

static var use_chinese: bool = true


static func t(en: String, zh: String) -> String:
	return zh if use_chinese else en


static func pick_field(data: Dictionary, key_en: String, key_zh: String = "") -> String:
	if key_zh == "":
		key_zh = key_en + "_zh"
	var en_val: String = str(data.get(key_en, ""))
	var zh_val: String = str(data.get(key_zh, en_val))
	return zh_val if use_chinese else en_val
