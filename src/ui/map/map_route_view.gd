## 爬塔路线图：按层布局节点 + 连线（自下而上，内容居中）
class_name MapRouteView
extends Control

signal node_pressed(node_id: int)

const NODE_W := 108.0
const NODE_H := 52.0
const FLOOR_GAP := 110.0
const COL_GAP := 24.0
const MARGIN_X := 56.0
const MARGIN_Y := 40.0
const FLOOR_LABEL_W := 44.0

var _nodes: Array = []
var _positions: Dictionary = {}
var _content_size: Vector2 = Vector2(700, 500)


func build(nodes: Array) -> void:
	_nodes = nodes
	_positions.clear()
	for c in get_children():
		c.queue_free()
	if _nodes.is_empty():
		return
	_compute_layout()
	_create_node_buttons()
	custom_minimum_size = _content_size
	size = _content_size
	queue_redraw()


func _compute_layout() -> void:
	var by_floor: Dictionary = {}
	var max_floor := 0
	for n in _nodes:
		var nd: MapNodeData = n
		max_floor = maxi(max_floor, nd.floor)
		if not by_floor.has(nd.floor):
			by_floor[nd.floor] = []
		by_floor[nd.floor].append(nd)
	var floors: Array[int] = []
	for key in by_floor.keys():
		floors.append(int(key))
	floors.sort()
	var content_w: float = 0.0
	for f in floors:
		var row_nodes: Array = by_floor[f]
		var count: int = row_nodes.size()
		var row_w: float = float(count) * NODE_W + float(maxi(0, count - 1)) * COL_GAP
		content_w = maxf(content_w, row_w)
	content_w += MARGIN_X * 2.0 + FLOOR_LABEL_W
	var total_h: float = MARGIN_Y * 2.0 + float(max_floor + 1) * FLOOR_GAP
	_content_size = Vector2(content_w, total_h)
	for f in floors:
		var row: Array = by_floor[f]
		row.sort_custom(func(a, b): return (a as MapNodeData).id < (b as MapNodeData).id)
		var count: int = row.size()
		var row_w: float = float(count) * NODE_W + float(maxi(0, count - 1)) * COL_GAP
		var start_x: float = FLOOR_LABEL_W + MARGIN_X + (content_w - FLOOR_LABEL_W - MARGIN_X * 2.0 - row_w) * 0.5
		var floor_i: int = int(f)
		var y: float = total_h - MARGIN_Y - float(floor_i) * FLOOR_GAP - NODE_H * 0.5
		for i in range(count):
			var nd: MapNodeData = row[i] as MapNodeData
			var cx: float = start_x + float(i) * (NODE_W + COL_GAP) + NODE_W * 0.5
			_positions[nd.id] = Vector2(cx, y)


func _create_node_buttons() -> void:
	for n in _nodes:
		var nd: MapNodeData = n
		if not _positions.has(nd.id):
			continue
		var center: Vector2 = _positions[nd.id]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(NODE_W, NODE_H)
		btn.position = center - Vector2(NODE_W, NODE_H) * 0.5
		btn.text = _node_label(nd)
		btn.disabled = not nd.available or nd.visited
		UiFonts.apply_font_to(btn, 13)
		_style_node_button(btn, nd)
		var nid: int = nd.id
		btn.pressed.connect(func(): node_pressed.emit(nid))
		add_child(btn)


func _node_label(nd: MapNodeData) -> String:
	var name_text := MapNodeData.type_name(nd.type)
	if nd.rift_rule != "":
		return name_text + "\n" + nd.rift_rule
	return name_text


func _style_node_button(btn: Button, nd: MapNodeData) -> void:
	if nd.visited:
		btn.modulate = Color(0.5, 0.5, 0.55, 1.0)
	elif nd.available:
		btn.modulate = Color(1.0, 1.0, 0.85, 1.0)
	else:
		btn.modulate = Color(0.65, 0.65, 0.7, 1.0)
	var fc := Color(0.92, 0.92, 0.95)
	match nd.type:
		MapNodeData.NodeType.START:
			fc = Color(0.45, 1.0, 0.55)
		MapNodeData.NodeType.BOSS:
			fc = Color(1.0, 0.4, 0.4)
		MapNodeData.NodeType.ELITE:
			fc = Color(1.0, 0.65, 0.25)
		MapNodeData.NodeType.VOID_RIFT:
			fc = Color(0.8, 0.55, 1.0)
		MapNodeData.NodeType.REST:
			fc = Color(0.55, 0.85, 1.0)
	btn.add_theme_color_override("font_color", fc)


func _find_node(node_id: int) -> MapNodeData:
	for n in _nodes:
		var nd: MapNodeData = n
		if nd.id == node_id:
			return nd
	return null


func _draw() -> void:
	var draw_size: Vector2 = size
	if draw_size.x < 10.0:
		draw_size = _content_size
	draw_rect(Rect2(Vector2.ZERO, draw_size), Color(0.07, 0.08, 0.12, 1.0))
	for n in _nodes:
		var nd: MapNodeData = n
		if not _positions.has(nd.id):
			continue
		var from_pos: Vector2 = _positions[nd.id]
		for cid in nd.connections:
			if not _positions.has(cid):
				continue
			var child := _find_node(cid)
			if child == null:
				continue
			var to_pos: Vector2 = _positions[cid]
			var line_color := Color(0.4, 0.45, 0.58, 0.85)
			if nd.visited and child.available:
				line_color = Color(1.0, 0.82, 0.2, 1.0)
			elif nd.visited and child.visited:
				line_color = Color(0.3, 0.65, 0.45, 0.9)
			draw_line(from_pos, to_pos, line_color, 4.0, true)
	var by_floor: Dictionary = {}
	for n in _nodes:
		var nd: MapNodeData = n
		if not by_floor.has(nd.floor):
			by_floor[nd.floor] = nd
	var floors: Array[int] = []
	for key in by_floor.keys():
		floors.append(int(key))
	floors.sort()
	var font := UiFonts.get_ui_font()
	for f in floors:
		var nd: MapNodeData = by_floor[f] as MapNodeData
		if _positions.has(nd.id):
			var pos: Vector2 = _positions[nd.id]
			var label: String = GameLocale.t("F%d" % (f + 1), "第%d层" % (f + 1))
			draw_string(font, Vector2(10, pos.y + 8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.65, 0.7, 0.8))
