## 应用内嵌 Noto 字体（FontFile），中文才能稳定显示
extends Node

const THEME_PATH := "res://assets/theme/cjk_theme.tres"


func _ready() -> void:
	call_deferred("_apply")


func _apply() -> void:
	var theme: Theme = load(THEME_PATH) as Theme
	if theme == null or theme.default_font == null:
		push_error("CJK theme failed to load: %s" % THEME_PATH)
		return
	get_tree().root.theme = theme
