extends Control

@onready var route_view: MapRouteView = $Scroll/MapCenter/MapRouteView
@onready var info_label: Label = $MapHeader/HeaderBox/InfoLabel
@onready var stats_label: Label = $MapHeader/HeaderBox/StatsLabel


func _ready() -> void:
	route_view.node_pressed.connect(_on_node_pressed)


func refresh() -> void:
	route_view.build(RunState.map_nodes)
	UiFonts.apply_font_to(stats_label, 16)
	UiFonts.apply_font_to(info_label, 16)
	stats_label.text = GameLocale.t(
		"HP %d/%d  Gold %d  Deck %d cards" % [
			RunState.current_hp, RunState.max_hp, RunState.gold, RunState.deck_ids.size()
		],
		"HP %d/%d  金币 %d  牌组 %d 张" % [
			RunState.current_hp, RunState.max_hp, RunState.gold, RunState.deck_ids.size()
		]
	)
	info_label.text = GameLocale.t(
		"One path up — gold lines lead to the BOSS at top",
		"每层只能走一次，沿金色路线向上，顶层为 BOSS"
	)


func _on_node_pressed(node_id: int) -> void:
	get_parent().enter_node(node_id)
