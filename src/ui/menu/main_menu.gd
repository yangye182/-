extends Control

@onready var title_label: Label = $VBox/Title
@onready var btn_start: Button = $VBox/StartButton
@onready var btn_quit: Button = $VBox/QuitButton


func _ready() -> void:
	_apply_locale()
	btn_start.pressed.connect(_on_start)
	btn_quit.pressed.connect(func(): get_tree().quit())


func _apply_locale() -> void:
	title_label.text = GameLocale.t("Void Tower", "虚空塔")
	btn_start.text = GameLocale.t("Start Run", "开始爬塔")
	btn_quit.text = GameLocale.t("Quit", "退出")
	UiFonts.apply_font_to(title_label, 28)
	UiFonts.apply_font_to(btn_start, 18)
	UiFonts.apply_font_to(btn_quit, 18)


func _on_start() -> void:
	get_parent().open_character_select()
