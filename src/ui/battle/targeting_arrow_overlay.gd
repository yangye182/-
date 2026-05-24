## 拖拽出牌时的瞄准箭头（屏幕坐标绘制）
class_name TargetingArrowOverlay
extends Control

var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
var _line_color: Color = Color(1.0, 0.85, 0.2, 0.95)


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func show_arrow(from_global: Vector2, to_global: Vector2, valid_target: bool = true) -> void:
	_from = _to_local(from_global)
	_to = _to_local(to_global)
	_line_color = Color(0.35, 0.95, 0.45, 0.95) if valid_target else Color(1.0, 0.35, 0.3, 0.95)
	visible = true
	queue_redraw()


func hide_arrow() -> void:
	visible = false
	queue_redraw()


func _to_local(global_pos: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * global_pos


func _draw() -> void:
	if not visible:
		return
	draw_line(_from, _to, _line_color, 4.0, true)
	var dir := (_to - _from)
	if dir.length_squared() < 16.0:
		return
	dir = dir.normalized()
	var tip := _to
	var wing := 11.0
	var back := 16.0
	var left := tip - dir * back + Vector2(-dir.y, dir.x) * wing
	var right := tip - dir * back + Vector2(dir.y, -dir.x) * wing
	draw_colored_polygon(PackedVector2Array([tip, left, right]), _line_color)
