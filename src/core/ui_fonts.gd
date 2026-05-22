## 全局 UI 字体（中文用内嵌 Noto）
extends Node

const NOTO_PATH := "res://assets/fonts/NotoSansSC-Regular.otf"
const CJK_THEME_PATH := "res://assets/theme/cjk_theme.tres"

var cjk_font: Font = null
var game_theme: Theme = null


func _ready() -> void:
	cjk_font = load(NOTO_PATH) as Font
	game_theme = load(CJK_THEME_PATH) as Theme


func apply_root_theme(use_chinese: bool) -> void:
	var root := get_tree().root
	if use_chinese and game_theme and cjk_font:
		root.theme = game_theme
	else:
		root.theme = null


func get_ui_font() -> Font:
	if GameLocale.use_chinese and cjk_font:
		return cjk_font
	return ThemeDB.fallback_font


func apply_font_to(control: Control, font_size: int = 16) -> void:
	var font := get_ui_font()
	if font:
		control.add_theme_font_override("font", font)
		control.add_theme_font_size_override("font_size", font_size)
