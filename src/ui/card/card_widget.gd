## 卡牌 UI：Kenney 卡框 + 类型图标 + 文字
class_name CardWidget
extends PanelContainer

signal card_pressed
signal card_drag_started
signal card_drag_moved(global_pos: Vector2)
signal card_drag_ended(global_pos: Vector2)

const CARD_SIZE := Vector2(168, 228)
const DRAG_THRESHOLD := 10.0

var _data: CardData = null
var _disabled: bool = false
var _ui_built: bool = false
var _hovered: bool = false
var _selected: bool = false

var _bg_tex: TextureRect
var _icon_tex: TextureRect
var _name_label: Label
var _type_label: Label
var _cost_label: Label
var _desc_label: Label
var _stats_label: Label
var _price_label: Label

var _enable_drag: bool = false
var _drag_active: bool = false
var _press_global: Vector2 = Vector2.ZERO
var _hand_scale: float = 1.0


func setup(card_data: CardData, disabled: bool = false, price: int = -1, enable_drag: bool = false) -> void:
	_data = card_data
	_disabled = disabled
	_enable_drag = enable_drag and not disabled
	_drag_active = false
	_hovered = false
	_selected = false
	_ensure_ui()
	custom_minimum_size = CARD_SIZE
	_apply_frame_texture(card_data.card_type)
	var bg := CardArt.get_card_bg_texture()
	if bg and _bg_tex:
		_bg_tex.texture = bg
	var icon := CardArt.get_icon_texture(card_data.card_type)
	if icon and _icon_tex:
		_icon_tex.texture = icon
	_name_label.text = card_data.get_display_name()
	match card_data.card_type:
		CardData.CardType.ATTACK:
			_type_label.text = GameLocale.t("Attack", "攻击")
		CardData.CardType.SKILL:
			_type_label.text = GameLocale.t("Skill", "技能")
		CardData.CardType.POWER:
			_type_label.text = GameLocale.t("Power", "能力")
	_cost_label.text = _format_cost(card_data)
	_desc_label.text = card_data.get_display_description()
	_stats_label.text = _format_stats(card_data)
	if price >= 0:
		_price_label.visible = true
		_price_label.text = GameLocale.t("%d Gold" % price, "%d 金币" % price)
	else:
		_price_label.visible = false
	_update_visual_state()


func _ensure_ui() -> void:
	if _ui_built:
		return
	_ui_built = true
	custom_minimum_size = CARD_SIZE
	clip_contents = true
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	# 底层卡轮廓图
	_bg_tex = TextureRect.new()
	_bg_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_tex.offset_left = 4
	_bg_tex.offset_top = 4
	_bg_tex.offset_right = -4
	_bg_tex.offset_bottom = -4
	_bg_tex.stretch_mode = TextureRect.STRETCH_SCALE
	_bg_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_tex)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFonts.apply_font_to(_name_label, 14)
	vbox.add_child(_name_label)
	_icon_tex = TextureRect.new()
	_icon_tex.custom_minimum_size = Vector2(72, 72)
	_icon_tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_icon_tex)
	_type_label = Label.new()
	_type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFonts.apply_font_to(_type_label, 10)
	vbox.add_child(_type_label)
	_cost_label = Label.new()
	_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFonts.apply_font_to(_cost_label, 12)
	vbox.add_child(_cost_label)
	_desc_label = Label.new()
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.custom_minimum_size = Vector2(130, 44)
	_desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UiFonts.apply_font_to(_desc_label, 10)
	vbox.add_child(_desc_label)
	_stats_label = Label.new()
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFonts.apply_font_to(_stats_label, 11)
	vbox.add_child(_stats_label)
	_price_label = Label.new()
	_price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFonts.apply_font_to(_price_label, 13)
	_price_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(_price_label)
	_price_label.visible = false
	gui_input.connect(_on_gui_input)


func set_selected(s: bool) -> void:
	_selected = s
	_update_visual_state()


## 战斗手牌：按比例缩小卡面、图标与字号（布局占位也缩小）
func apply_hand_layout(scale_factor: float) -> void:
	_hand_scale = clampf(scale_factor, 0.4, 1.0)
	custom_minimum_size = CARD_SIZE * _hand_scale
	pivot_offset = Vector2(custom_minimum_size.x * 0.5, custom_minimum_size.y)
	_apply_compact_metrics(_hand_scale)
	_update_visual_state()


func _apply_compact_metrics(s: float) -> void:
	if not _ui_built:
		return
	var ml := int(12.0 * s)
	var mt := int(10.0 * s)
	var margin := get_child(1) as MarginContainer
	if margin:
		margin.add_theme_constant_override("margin_left", ml)
		margin.add_theme_constant_override("margin_right", ml)
		margin.add_theme_constant_override("margin_top", mt)
		margin.add_theme_constant_override("margin_bottom", mt)
	if _icon_tex:
		# 手牌区图标再缩小一档（非手牌 _hand_scale=1 时保持原尺寸）
		var icon_mul := 0.58 if _hand_scale < 0.99 else 1.0
		_icon_tex.custom_minimum_size = Vector2(72, 72) * s * icon_mul
	if _desc_label:
		_desc_label.custom_minimum_size = Vector2(130, 44) * s
	UiFonts.apply_font_to(_name_label, maxi(9, int(14.0 * s)))
	UiFonts.apply_font_to(_type_label, maxi(8, int(10.0 * s)))
	UiFonts.apply_font_to(_cost_label, maxi(8, int(12.0 * s)))
	UiFonts.apply_font_to(_desc_label, maxi(8, int(10.0 * s)))
	UiFonts.apply_font_to(_stats_label, maxi(8, int(11.0 * s)))


func get_center_global() -> Vector2:
	return get_global_rect().get_center()


func cancel_drag() -> void:
	_drag_active = false
	_update_visual_state()


func is_dragging() -> bool:
	return _drag_active


func _on_mouse_entered() -> void:
	if _disabled:
		return
	_hovered = true
	_update_visual_state()


func _on_mouse_exited() -> void:
	_hovered = false
	_update_visual_state()


func _update_visual_state() -> void:
	var bump := 1.0
	if _disabled:
		modulate = Color(0.55, 0.55, 0.6, 1.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	elif _drag_active:
		bump = 1.06
		modulate = Color(1.0, 1.0, 0.9, 1.0)
		mouse_filter = Control.MOUSE_FILTER_STOP
		z_index = 10
	elif _selected:
		bump = 1.08
		modulate = Color(1.0, 1.0, 0.85, 1.0)
		mouse_filter = Control.MOUSE_FILTER_STOP
		z_index = 2
	elif _hovered:
		bump = 1.04
		modulate = Color.WHITE
		mouse_filter = Control.MOUSE_FILTER_STOP
		z_index = 1
	else:
		modulate = Color.WHITE
		mouse_filter = Control.MOUSE_FILTER_STOP
		z_index = 0
	# 布局已按 _hand_scale 缩小，悬停/拖拽仅用轻微 scale 放大
	scale = Vector2(bump, bump)
	pivot_offset = Vector2(custom_minimum_size.x * 0.5, custom_minimum_size.y)


func _apply_frame_texture(card_type: CardData.CardType) -> void:
	var tex := CardArt.get_frame_texture(card_type)
	if tex:
		var sb := StyleBoxTexture.new()
		sb.texture = tex
		sb.texture_margin_left = 6.0
		sb.texture_margin_top = 6.0
		sb.texture_margin_right = 6.0
		sb.texture_margin_bottom = 6.0
		sb.draw_center = true
		add_theme_stylebox_override("panel", sb)
	else:
		_apply_flat_fallback(card_type)


func _apply_flat_fallback(card_type: CardData.CardType) -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(10)
	style.set_border_width_all(3)
	match card_type:
		CardData.CardType.ATTACK:
			style.bg_color = Color(0.32, 0.14, 0.14, 0.95)
			style.border_color = Color(0.85, 0.35, 0.3)
		CardData.CardType.SKILL:
			style.bg_color = Color(0.12, 0.22, 0.32, 0.95)
			style.border_color = Color(0.35, 0.65, 0.9)
		CardData.CardType.POWER:
			style.bg_color = Color(0.22, 0.16, 0.32, 0.95)
			style.border_color = Color(0.65, 0.45, 0.9)
		_:
			style.bg_color = Color(0.18, 0.18, 0.22, 0.95)
	add_theme_stylebox_override("panel", style)


func _format_cost(data: CardData) -> String:
	var parts: PackedStringArray = []
	if data.cost_red > 0:
		parts.append(GameLocale.t("R%d" % data.cost_red, "红%d" % data.cost_red))
	if data.cost_blue > 0:
		parts.append(GameLocale.t("B%d" % data.cost_blue, "蓝%d" % data.cost_blue))
	if parts.is_empty():
		return GameLocale.t("Free", "免费")
	return " · ".join(parts)


func _format_stats(data: CardData) -> String:
	var parts: PackedStringArray = []
	if data.damage > 0:
		parts.append(GameLocale.t("DMG %d" % data.damage, "伤害 %d" % data.damage))
	if data.block > 0:
		parts.append(GameLocale.t("BLK %d" % data.block, "护甲 %d" % data.block))
	if data.draw > 0:
		parts.append(GameLocale.t("Draw %d" % data.draw, "抽牌 %d" % data.draw))
	if data.heal > 0:
		parts.append(GameLocale.t("Heal %d" % data.heal, "治疗 %d" % data.heal))
	return "  ".join(parts) if not parts.is_empty() else ""


func _on_gui_input(event: InputEvent) -> void:
	if _disabled or _data == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_press_global = mb.global_position
			_drag_active = false
		else:
			if _drag_active:
				card_drag_ended.emit(mb.global_position)
				_drag_active = false
				_update_visual_state()
				accept_event()
			else:
				card_pressed.emit()
				accept_event()
	elif event is InputEventMouseMotion and _enable_drag:
		var mm := event as InputEventMouseMotion
		if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			return
		if not _drag_active:
			if _press_global.distance_to(mm.global_position) < DRAG_THRESHOLD:
				return
			_drag_active = true
			_update_visual_state()
			card_drag_started.emit()
		card_drag_moved.emit(mm.global_position)
		accept_event()
