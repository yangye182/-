## 地图连线布局：为每条边分配横向车道，用贝塞尔曲线减少遮挡
class_name MapEdgeRouter
extends RefCounted

const LANE_SPREAD := 34.0
const CURVE_SAMPLES := 20


## 单条边的绘制数据
class EdgeDrawData:
	var from_id: int = 0
	var to_id: int = 0
	var from_pos: Vector2 = Vector2.ZERO
	var to_pos: Vector2 = Vector2.ZERO
	var from_col: int = 0
	var to_col: int = 0
	var from_floor: int = 0
	var out_lane: float = 0.0
	var in_lane: float = 0.0
	var lane: float = 0.0
	var color: Color = Color.WHITE
	var width: float = 3.0
	var draw_priority: int = 0  # 越大越后画（在上层）


static func build_edges(nodes: Array, positions: Dictionary) -> Array:
	var raw: Array = []
	for n in nodes:
		var nd: MapNodeData = n as MapNodeData
		if nd == null or not positions.has(nd.id):
			continue
		var from_pos: Vector2 = positions[nd.id]
		for cid in nd.connections:
			if not positions.has(cid):
				continue
			var child := _find_node(nodes, cid)
			if child == null:
				continue
			var e := EdgeDrawData.new()
			e.from_id = nd.id
			e.to_id = cid
			e.from_pos = from_pos
			e.to_pos = positions[cid]
			e.from_col = nd.column_index
			e.to_col = child.column_index
			e.from_floor = nd.layer_index
			raw.append(e)

	_assign_lanes(raw)
	return raw


static func sample_polyline(edge: EdgeDrawData) -> PackedVector2Array:
	var lane_offset := edge.lane * LANE_SPREAD
	var from := edge.from_pos
	var to := edge.to_pos
	var dy := to.y - from.y
	# 竖向为主：控制点在 1/3、2/3 高度处横向展开车道
	var cp1 := Vector2(from.x + lane_offset * 0.6, from.y + dy * 0.35)
	var cp2 := Vector2(to.x + lane_offset * 0.6, from.y + dy * 0.65)
	return _sample_cubic(from, cp1, cp2, to, CURVE_SAMPLES)


static func _find_node(nodes: Array, node_id: int) -> MapNodeData:
	for n in nodes:
		var nd: MapNodeData = n as MapNodeData
		if nd != null and nd.id == node_id:
			return nd
	return null


## 同源/同目标的多条边分配左右车道（-1, 0, +1 …）
static func _assign_lanes(edges: Array) -> void:
	var by_from: Dictionary = {}
	var by_to: Dictionary = {}
	for e in edges:
		if not by_from.has(e.from_id):
			by_from[e.from_id] = []
		(by_from[e.from_id] as Array).append(e)
		if not by_to.has(e.to_id):
			by_to[e.to_id] = []
		(by_to[e.to_id] as Array).append(e)

	for group in by_from.values():
		_spread_lanes(group as Array, "out_lane")
	for group in by_to.values():
		_spread_lanes(group as Array, "in_lane")

	for e in edges:
		e.lane = (e.out_lane + e.in_lane) * 0.5


static func _spread_lanes(group: Array, lane_key: String) -> void:
	group.sort_custom(func(a, b) -> bool:
		var ea: EdgeDrawData = a as EdgeDrawData
		var eb: EdgeDrawData = b as EdgeDrawData
		if lane_key == "out_lane":
			return ea.to_col < eb.to_col
		return ea.from_col < eb.from_col
	)
	var n: int = group.size()
	for i in n:
		var lane_val: float = float(i) - (float(n - 1) * 0.5)
		var e: EdgeDrawData = group[i] as EdgeDrawData
		if lane_key == "out_lane":
			e.out_lane = lane_val
		else:
			e.in_lane = lane_val


## 绘制顺序：灰线 → 已走路径 → 可选金色路径（避免重要线被盖住）
static func sort_for_draw(edges: Array) -> void:
	edges.sort_custom(func(a: EdgeDrawData, b: EdgeDrawData) -> bool:
		if a.draw_priority != b.draw_priority:
			return a.draw_priority < b.draw_priority
		if a.from_floor != b.from_floor:
			return a.from_floor < b.from_floor
		return abs(a.lane) < abs(b.lane)
	)


static func _sample_cubic(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, samples: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(samples + 1)
	for i in samples + 1:
		var t := float(i) / float(samples)
		var u := 1.0 - t
		pts[i] = (
			u * u * u * p0
			+ 3.0 * u * u * t * p1
			+ 3.0 * u * t * t * p2
			+ t * t * t * p3
		)
	return pts
