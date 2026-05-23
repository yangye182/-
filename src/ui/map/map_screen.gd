extends Control

@onready var route_view: MapRouteView = $Scroll/MapCenter/MapRouteView
@onready var info_label: Label = $MapHeader/HeaderBox/InfoLabel
@onready var stats_label: Label = $MapHeader/HeaderBox/StatsLabel
@onready var backpack_btn: Button = $MapHeader/HeaderBox/BackpackButton


func _ready() -> void:
	route_view.node_pressed.connect(_on_node_pressed)
	backpack_btn.pressed.connect(_on_backpack_pressed)
	UiFonts.apply_font_to(backpack_btn, 14)
	backpack_btn.text = GameLocale.t("Backpack", "背包")


func refresh() -> void:
	route_view.build(RunState.map_nodes)
	UiFonts.apply_font_to(stats_label, 16)
	UiFonts.apply_font_to(info_label, 16)
	var char_cfg := GameDB.get_character(RunState.character_id)
	var char_name := GameLocale.pick_field(char_cfg, "name", "name_zh")
	stats_label.text = GameLocale.t(
		"%s  |  HP %d/%d  Gold %d  Deck %d" % [
			char_name, RunState.current_hp, RunState.max_hp, RunState.gold, RunState.deck_ids.size()
		],
		"%s  |  生命 %d/%d  金币 %d  牌组 %d 张" % [
			char_name, RunState.current_hp, RunState.max_hp, RunState.gold, RunState.deck_ids.size()
		]
	)
	info_label.text = GameLocale.t(
		"One path up — gold lines lead to the BOSS at top",
		"每层只能走一次，沿金色路线向上，顶层为 BOSS"
	)


func _on_node_pressed(node_id: int) -> void:
	get_parent().enter_node(node_id)


func _on_backpack_pressed() -> void:
	get_parent().open_backpack()
