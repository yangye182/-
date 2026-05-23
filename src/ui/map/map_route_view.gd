## 爬塔路线图：16 层网格布局（杀戮尖塔风格），自下而上
class_name MapRouteView
extends Control

signal node_pressed(node_id: int)

const NODE_W := 100.0
const NODE_H := 48.0
const FLOOR_GAP := 78.0
const COL_GAP := 20.0
const MAP_COLS := 5
const MARGIN_X := 24.0
const MARGIN_Y := 20.0
const FLOOR_LABEL_W := 48.0

var _nodes: Array = []
var _positions: Dictionary = {}  # node_id -> Vector2
var _edge_draw_list: Array = []  # MapEdgeRouter.EdgeDrawData


func build(nodes: Array) -> void:
	_nodes = nodes
	_positions.clear()
	for c in get_children():
		c.queue_free()
	if _nodes.is_empty():
		return
	_compute_layout()
	_build_edge_draw_list()
	_create_node_buttons()
	queue_redraw()


func _compute_layout() -> void:
	var by_floor: Dictionary = {}
	var max_floor := 0
	for n in _nodes:
		var nd: MapNodeData = n
		max_floor = maxi(max_floor, nd.layer_index)
		if not by_floor.has(nd.layer_index):
			by_floor[nd.layer_index] = []
		by_floor[nd.layer_index].append(nd)

	var floors: Array[int] = []
	for key in by_floor.keys():
		floors.append(int(key))
	floors.sort()

	# 网格总宽 = 固定列数
	var grid_w := float(MAP_COLS) * NODE_W + float(MAP_COLS - 1) * COL_GAP
	var total_w := FLOOR_LABEL_W + MARGIN_X + grid_w + MARGIN_X
	var total_h := MARGIN_Y * 2.0 + float(max_floor) * FLOOR_GAP

	custom_minimum_size = Vector2(total_w, total_h)

	var grid_left := FLOOR_LABEL_W + MARGIN_X
	# Y 从底部向上
	for f in floors:
		var row: Array = by_floor[f]
		var y := total_h - MARGIN_Y - float(f) * FLOOR_GAP - NODE_H * 0.5
		for n in row:
			var nd: MapNodeData = n
			var cx := grid_left + float(nd.column_index) * (NODE_W + COL_GAP) + NODE_W * 0.5
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
		UiFonts.apply_font_to(btn, 11)
		_style_node_button(btn, nd)
		var nid := nd.id
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
		MapNodeData.NodeType.SHOP:
			fc = Color(1.0, 0.85, 0.4)
		MapNodeData.NodeType.EVENT:
			fc = Color(0.6, 0.9, 0.9)
		MapNodeData.NodeType.RUNE_FORGE:
			fc = Color(1.0, 0.7, 0.5)
		MapNodeData.NodeType.SAGE_ALTAR:
			fc = Color(0.7, 0.6, 1.0)
	btn.add_theme_color_override("font_color", fc)


func _find_node(node_id: int) -> MapNodeData:
	for n in _nodes:
		var nd: MapNodeData = n
		if nd.id == node_id:
			return nd
	return null


func _build_edge_draw_list() -> void:
	_edge_draw_list = MapEdgeRouter.build_edges(_nodes, _positions)
	for e in _edge_draw_list:
		var edge: MapEdgeRouter.EdgeDrawData = e as MapEdgeRouter.EdgeDrawData
		var parent_nd := _find_node(edge.from_id)
		var child_nd := _find_node(edge.to_id)
		if parent_nd == null or child_nd == null:
			continue
		edge.color = Color(0.38, 0.42, 0.55, 0.75)
		edge.width = 2.5
		edge.draw_priority = 0
		if parent_nd.visited and child_nd.visited:
			edge.color = Color(0.28, 0.62, 0.48, 0.88)
			edge.width = 3.0
			edge.draw_priority = 1
		if parent_nd.visited and child_nd.available:
			edge.color = Color(1.0, 0.82, 0.2, 1.0)
			edge.width = 4.0
			edge.draw_priority = 2
	MapEdgeRouter.sort_for_draw(_edge_draw_list)


func _draw() -> void:
	var draw_size := custom_minimum_size
	if draw_size.x < 10.0:
		draw_size = Vector2(600, 800)

	draw_rect(Rect2(Vector2.ZERO, draw_size), Color(0.07, 0.08, 0.12, 1.0))

	# 连接线（车道 + 贝塞尔，按优先级绘制避免遮挡）
	for e in _edge_draw_list:
		var edge: MapEdgeRouter.EdgeDrawData = e as MapEdgeRouter.EdgeDrawData
		var pts := MapEdgeRouter.sample_polyline(edge)
		if pts.size() >= 2:
			draw_polyline(pts, edge.color, edge.width, true)

	# 层标签（取每层第一个节点位置标注）
	var by_floor: Dictionary = {}
	for n in _nodes:
		var nd: MapNodeData = n
		if not by_floor.has(nd.layer_index):
			by_floor[nd.layer_index] = nd
	var floors: Array[int] = []
	for key in by_floor.keys():
		floors.append(int(key))
	floors.sort()
	var font := UiFonts.get_ui_font()
	for f in floors:
		var nd := by_floor[f] as MapNodeData
		if _positions.has(nd.id):
			var pos: Vector2 = _positions[nd.id]
			var label := GameLocale.t("F%d" % (f + 1), "第%d层" % (f + 1))
			draw_string(font, Vector2(8, pos.y + 8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.65, 0.7, 0.8))
