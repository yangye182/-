## 选人界面：角色列表由 characters.json 驱动，解锁状态由 CharacterProgress 管理
extends Control

signal run_confirmed(character_id: String)
signal back_pressed

var _roster_row: HBoxContainer
var _name_label: Label
var _desc_label: Label
var _stats_label: Label
var _deck_label: Label
var _relic_label: Label
var _lock_label: Label
var _confirm_btn: Button
var _back_btn: Button

var _selected_id: String = ""
var _slot_buttons: Dictionary = {}  # id -> Button


func _ready() -> void:
	_bind_nodes()
	_back_btn.pressed.connect(func(): back_pressed.emit())
	_confirm_btn.pressed.connect(_on_confirm)
	_apply_locale()
	open_select()


func _bind_nodes() -> void:
	var root: VBoxContainer = $Panel/VBox
	_roster_row = root.get_node("Body/RosterScroll/RosterRow")
	_name_label = root.get_node("Body/DetailPanel/DetailVBox/NameLabel")
	_desc_label = root.get_node("Body/DetailPanel/DetailVBox/DescLabel")
	_stats_label = root.get_node("Body/DetailPanel/DetailVBox/StatsLabel")
	_deck_label = root.get_node("Body/DetailPanel/DetailVBox/DeckLabel")
	_relic_label = root.get_node("Body/DetailPanel/DetailVBox/RelicLabel")
	_lock_label = root.get_node("Body/DetailPanel/DetailVBox/LockLabel")
	_confirm_btn = root.get_node("Actions/ConfirmButton")
	_back_btn = root.get_node("Actions/BackButton")


func _apply_locale() -> void:
	$Panel/VBox/Title.text = GameLocale.t("Choose Your Character", "选择角色")
	_back_btn.text = GameLocale.t("Back", "返回")
	_confirm_btn.text = GameLocale.t("Start Climb", "开始爬塔")
	UiFonts.apply_font_to($Panel/VBox/Title, 24)
	UiFonts.apply_font_to(_back_btn, 16)
	UiFonts.apply_font_to(_confirm_btn, 18)
	UiFonts.apply_font_to(_name_label, 22)
	UiFonts.apply_font_to(_desc_label, 14)
	UiFonts.apply_font_to(_stats_label, 14)
	UiFonts.apply_font_to(_deck_label, 13)
	UiFonts.apply_font_to(_relic_label, 13)
	UiFonts.apply_font_to(_lock_label, 14)


## 打开界面时重建角色槽（新角色加入 JSON 后会自动出现）
func open_select() -> void:
	_build_roster_slots()
	var roster := CharacterRoster.get_sorted_roster()
	if roster.is_empty():
		return
	var first_playable := ""
	for cfg in roster:
		var cid: String = cfg.get("id", "")
		if CharacterRoster.is_playable(cid):
			first_playable = cid
			break
	if first_playable != "":
		_select_character(first_playable)
	elif roster.size() > 0:
		_select_character(roster[0].get("id", ""))


func _build_roster_slots() -> void:
	for c in _roster_row.get_children():
		c.queue_free()
	_slot_buttons.clear()
	for cfg in CharacterRoster.get_sorted_roster():
		var cid: String = cfg.get("id", "")
		var slot := _make_slot_button(cfg)
		_roster_row.add_child(slot)
		_slot_buttons[cid] = slot


func _make_slot_button(cfg: Dictionary) -> Button:
	var cid: String = cfg.get("id", "")
	var unlocked := CharacterRoster.is_playable(cid)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(160, 200)
	btn.toggle_mode = true
	btn.focus_mode = Control.FOCUS_NONE

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 8
	box.offset_top = 8
	box.offset_right = -8
	box.offset_bottom = -8
	box.add_theme_constant_override("separation", 8)
	btn.add_child(box)

	var name_lbl := Label.new()
	name_lbl.text = GameLocale.pick_field(cfg, "name", "name_zh")
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFonts.apply_font_to(name_lbl, 16)
	box.add_child(name_lbl)

	var role_lbl := Label.new()
	role_lbl.text = GameLocale.t("HP %d" % int(cfg.get("max_hp", 0)), "生命 %d" % int(cfg.get("max_hp", 0)))
	role_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFonts.apply_font_to(role_lbl, 13)
	box.add_child(role_lbl)

	if not unlocked:
		var lock_lbl := Label.new()
		lock_lbl.text = GameLocale.t("LOCKED", "未解锁")
		lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_lbl.modulate = Color(1.0, 0.45, 0.45)
		UiFonts.apply_font_to(lock_lbl, 14)
		box.add_child(lock_lbl)
		btn.disabled = false  # 仍可点击查看解锁说明
	else:
		var ok_lbl := Label.new()
		ok_lbl.text = GameLocale.t("Ready", "可选")
		ok_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ok_lbl.modulate = Color(0.6, 0.95, 0.7)
		UiFonts.apply_font_to(ok_lbl, 12)
		box.add_child(ok_lbl)

	var pick_id := cid
	btn.pressed.connect(func(): _select_character(pick_id))
	return btn


func _select_character(character_id: String) -> void:
	_selected_id = character_id
	for cid in _slot_buttons:
		var btn: Button = _slot_buttons[cid]
		btn.button_pressed = (cid == character_id)
	_refresh_detail()


func _refresh_detail() -> void:
	var cfg := GameDB.get_character(_selected_id)
	if cfg.is_empty():
		return
	var unlocked := CharacterRoster.is_playable(_selected_id)

	_name_label.text = GameLocale.pick_field(cfg, "name", "name_zh")
	_desc_label.text = GameLocale.pick_field(cfg, "description", "description_zh")
	_stats_label.text = CharacterRoster.format_stats_line(cfg)
	_deck_label.text = GameLocale.t(
		"Starting deck: %s" % CharacterRoster.format_deck_summary(cfg),
		"初始牌组：%s" % CharacterRoster.format_deck_summary(cfg)
	)

	var relic_names: PackedStringArray = []
	for rid in CharacterRoster.get_starting_relics(cfg):
		var r := GameDB.get_relic(rid)
		relic_names.append(GameLocale.pick_field(r, "name", "name_zh"))
	if relic_names.is_empty():
		_relic_label.text = GameLocale.t("Starting relic: none", "初始遗物：无")
	else:
		_relic_label.text = GameLocale.t(
			"Starting relic: %s" % ", ".join(relic_names),
			"初始遗物：%s" % ", ".join(relic_names)
		)

	if unlocked:
		_lock_label.text = ""
		_lock_label.visible = false
		_confirm_btn.disabled = false
	else:
		_lock_label.visible = true
		_lock_label.text = GameLocale.pick_field(
			cfg, "unlock_hint_en", "unlock_hint_zh"
		)
		if _lock_label.text == "":
			_lock_label.text = GameLocale.t("This character is locked.", "该角色尚未解锁。")
		_confirm_btn.disabled = true


func _on_confirm() -> void:
	if _selected_id == "" or not CharacterRoster.is_playable(_selected_id):
		return
	run_confirmed.emit(_selected_id)
