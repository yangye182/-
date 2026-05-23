## 16 层杀戮尖塔式地图（参考 TapTap 竖向网状地图心得）
## https://www.taptap.cn/moment/784818959550517021
## 生成：层数 → 类型硬约束 → 连线 A~E（比例映射 / 额外边 / 去交叉 / 保底出入边）
class_name MapGenerator
extends RefCounted

const LAYERS := 16
const MAP_COLS := 5
const MAP_CENTER_COL := 2
const MAX_COLUMN_SPAN := 1
const MAX_EDGES_PER_NODE := 3
const COLUMN_JITTER := 1

const LAYER_COUNT_MIN := 2
const LAYER_COUNT_MAX := 4
const FIRST_BRANCH_MIN := 3
const FIRST_BRANCH_MAX := 4

const TYPE_WEIGHTS_EARLY := {
	MapNodeData.NodeType.COMBAT: 43,
	MapNodeData.NodeType.ELITE: 0,
	MapNodeData.NodeType.REST: 13,
	MapNodeData.NodeType.SHOP: 6,
	MapNodeData.NodeType.EVENT: 27,
	MapNodeData.NodeType.VOID_RIFT: 0,
	MapNodeData.NodeType.SAGE_ALTAR: 0,
	MapNodeData.NodeType.RUNE_FORGE: 0,
}
const TYPE_WEIGHTS_MID := {
	MapNodeData.NodeType.COMBAT: 35,
	MapNodeData.NodeType.ELITE: 11,
	MapNodeData.NodeType.REST: 13,
	MapNodeData.NodeType.SHOP: 6,
	MapNodeData.NodeType.EVENT: 20,
	MapNodeData.NodeType.VOID_RIFT: 8,
	MapNodeData.NodeType.SAGE_ALTAR: 4,
	MapNodeData.NodeType.RUNE_FORGE: 3,
}
const TYPE_WEIGHTS_LATE := {
	MapNodeData.NodeType.COMBAT: 30,
	MapNodeData.NodeType.ELITE: 16,
	MapNodeData.NodeType.REST: 14,
	MapNodeData.NodeType.SHOP: 5,
	MapNodeData.NodeType.EVENT: 18,
	MapNodeData.NodeType.VOID_RIFT: 10,
	MapNodeData.NodeType.SAGE_ALTAR: 4,
	MapNodeData.NodeType.RUNE_FORGE: 3,
}

static var _last_shop_layer: int = -99


static func generate() -> Array:
	_last_shop_layer = -99
	var all_nodes: Array = []
	var node_id := 0
	var floor_cols: Array = []

	var start := MapNodeData.new()
	start.id = node_id
	start.layer_index = 0
	start.column_index = MAP_CENTER_COL
	start.type = MapNodeData.NodeType.START
	start.available = true
	all_nodes.append(start)
	floor_cols.append([{col = start.column_index, id = node_id}])
	node_id += 1

	var prev_count := 1
	for layer in range(1, LAYERS - 1):
		var count := _pick_layer_node_count(layer)
		# Boss 前休息层：数量不超过上一层，与分支一一对应（避免一点双出边都连休息）
		if layer == LAYERS - 2:
			count = prev_count
		var cols := _spread_column_indices(count)
		var types := _assign_layer_types(layer, count)
		var row: Array = []
		for i in count:
			var n := MapNodeData.new()
			n.id = node_id
			n.layer_index = layer
			n.column_index = cols[i]
			n.type = types[i] as MapNodeData.NodeType
			if n.type == MapNodeData.NodeType.VOID_RIFT:
				n.rift_rule = ["reverse", "silent", "mirror", "deplete", "chaos"].pick_random()
			all_nodes.append(n)
			row.append({col = cols[i], id = node_id})
			node_id += 1
		floor_cols.append(row)
		prev_count = count

	var boss := MapNodeData.new()
	boss.id = node_id
	boss.layer_index = LAYERS - 1
	boss.column_index = MAP_CENTER_COL
	boss.type = MapNodeData.NodeType.BOSS
	all_nodes.append(boss)
	floor_cols.append([{col = boss.column_index, id = node_id}])

	_connect_all_floors_sts(all_nodes, floor_cols)
	_ensure_graph_connectivity(all_nodes, floor_cols)
	return all_nodes


static func _pick_layer_node_count(layer: int) -> int:
	if layer == 1:
		return randi_range(FIRST_BRANCH_MIN, FIRST_BRANCH_MAX)
	return randi_range(LAYER_COUNT_MIN, LAYER_COUNT_MAX)


static func _spread_column_indices(count: int) -> Array[int]:
	if count <= 0:
		return [MAP_CENTER_COL]
	var cols: Array[int] = []
	var max_col := MAP_COLS - 1
	for i in count:
		var slot := float(i + 1) / float(count + 1)
		var base_col := int(round(slot * float(max_col)))
		var jitter := randi_range(-COLUMN_JITTER, COLUMN_JITTER)
		cols.append(clampi(base_col + jitter, 0, max_col))
	cols.sort()
	for i in range(1, cols.size()):
		if cols[i] <= cols[i - 1]:
			cols[i] = mini(cols[i - 1] + 1, max_col)
	for i in range(cols.size() - 2, -1, -1):
		if cols[i] >= cols[i + 1]:
			cols[i] = maxi(cols[i + 1] - 1, 0)
	return cols


static func _assign_layer_types(layer: int, count: int) -> Array:
	var types: Array = []
	types.resize(count)

	if layer >= 1 and layer <= 3:
		for i in count:
			types[i] = MapNodeData.NodeType.COMBAT
		return types
	if layer == LAYERS - 2:
		for i in count:
			types[i] = MapNodeData.NodeType.REST
		return types

	var weights: Dictionary = _get_type_weights(layer)
	if layer == 4:
		weights[MapNodeData.NodeType.COMBAT] = 0

	for i in count:
		types[i] = _weighted_random_type(layer, weights)

	if layer == 4 and count >= 3:
		_enforce_row_diversity(types, layer, weights)

	if layer <= 7:
		for i in count:
			if types[i] == MapNodeData.NodeType.ELITE:
				types[i] = MapNodeData.NodeType.COMBAT
	return types


static func _get_type_weights(layer: int) -> Dictionary:
	if layer <= 7:
		return TYPE_WEIGHTS_EARLY.duplicate()
	if layer >= 12:
		return TYPE_WEIGHTS_LATE.duplicate()
	return TYPE_WEIGHTS_MID.duplicate()


static func _shop_allowed_on_layer(layer: int) -> bool:
	return layer - _last_shop_layer >= 2


static func _weighted_random_type(layer: int, weights: Dictionary) -> int:
	var keys: Array = []
	for k in weights.keys():
		if int(weights[k]) <= 0:
			continue
		if k == MapNodeData.NodeType.SHOP and not _shop_allowed_on_layer(layer):
			continue
		keys.append(k)
	keys.sort()
	var total := 0
	for k in keys:
		total += int(weights[k])
	if total <= 0:
		return MapNodeData.NodeType.COMBAT
	var r := randi() % total
	var acc := 0
	for k in keys:
		acc += int(weights[k])
		if r < acc:
			var picked: int = k as int
			if picked == MapNodeData.NodeType.SHOP:
				_last_shop_layer = layer
			return picked
	return MapNodeData.NodeType.COMBAT


static func _enforce_row_diversity(types: Array, layer: int, weights: Dictionary) -> void:
	var first: int = types[0] as int
	var all_same := true
	for t in types:
		if t != first:
			all_same = false
			break
	if not all_same:
		return
	var alt := _weighted_random_type(layer, weights)
	if alt == first:
		alt = MapNodeData.NodeType.EVENT
	types[types.size() - 1] = alt


# ---------- 连线：TapTap A~E + 全局连通性修复 ----------

static func _connect_all_floors_sts(all_nodes: Array, floor_cols: Array) -> void:
	for f in range(floor_cols.size() - 1):
		var lower: Array = _sorted_by_col(floor_cols[f])
		var upper: Array = _sorted_by_col(floor_cols[f + 1])
		if f == 0:
			# 起点层：连到第一层全部分支（不受 MAX_EDGES 限制）
			for u in upper:
				_add_edge(all_nodes, lower[0], u, 2, true)
			continue
		if _is_pre_boss_rest_floor(all_nodes, upper):
			_connect_pre_boss_rest_pair(all_nodes, lower, upper)
			continue
		_connect_floor_pair(all_nodes, lower, upper)


static func _is_pre_boss_rest_floor(all_nodes: Array, upper: Array) -> bool:
	if upper.is_empty():
		return false
	var nd: MapNodeData = all_nodes[upper[0].id]
	return nd.layer_index == LAYERS - 2 and nd.type == MapNodeData.NodeType.REST


## Boss 前休息层：与上一层等数量，每点最多 1 条出边连休息、每个休息最多 1 个上层父节点
static func _connect_pre_boss_rest_pair(all_nodes: Array, lower: Array, upper: Array) -> void:
	if lower.is_empty() or upper.is_empty():
		return
	lower = _sorted_by_col(lower)
	upper = _sorted_by_col(upper)
	var upper_ids := _ids_set(upper)

	# 清除下层→休息层 的旧连线，避免与通用逻辑叠出多边
	for e in lower:
		var from_id: int = e.id
		var kept: Array[int] = []
		for cid in all_nodes[from_id].connections:
			if not upper_ids.has(cid):
				kept.append(cid)
		all_nodes[from_id].connections = kept

	# 与上一层等数量：按列序 1:1 对应，每点仅 1 条边
	if lower.size() == upper.size():
		for li in lower.size():
			_add_edge(all_nodes, lower[li], upper[li], 2)
	else:
		for li in lower.size():
			if _outgoing_to_upper(lower[li].id, upper, all_nodes) > 0:
				continue
			var ti := _proportional_target_index(li, lower.size(), upper.size())
			_add_edge(all_nodes, lower[li], upper[ti], 2)

	# 保底连通（仍遵守：每个下层最多 1 条出边到休息层）
	for u in upper:
		if _incoming_from_lower(u.id, lower, all_nodes) > 0:
			continue
		for e in _sorted_by_col_distance(lower, int(u.col)):
			if _outgoing_to_upper(e.id, upper, all_nodes) > 0:
				continue
			if _add_edge(all_nodes, e, u, 2):
				break

	for e in lower:
		if _outgoing_to_upper(e.id, upper, all_nodes) > 0:
			continue
		for u in _sorted_by_col_distance(upper, int(e.col)):
			if _add_edge(all_nodes, e, u, 2):
				break

	_trim_extra_edges_to_upper(all_nodes, lower, upper_ids)


## 若通用逻辑叠了多条「下层→休息」，只保留第一条
static func _trim_extra_edges_to_upper(all_nodes: Array, lower: Array, upper_ids: Dictionary) -> void:
	for e in lower:
		var from_id: int = e.id
		var rest_out: Array[int] = []
		var other: Array[int] = []
		for cid in all_nodes[from_id].connections:
			if upper_ids.has(cid):
				rest_out.append(cid)
			else:
				other.append(cid)
		if rest_out.size() > 1:
			other.append(rest_out[0])
			all_nodes[from_id].connections = other


static func _ids_set(row: Array) -> Dictionary:
	var d: Dictionary = {}
	for e in row:
		d[int(e.id)] = true
	return d


static func _sorted_by_col_distance(row: Array, pivot_col: int) -> Array:
	var copy: Array = row.duplicate()
	copy.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return abs(int(a.col) - pivot_col) < abs(int(b.col) - pivot_col)
	)
	return copy


static func _connect_floor_pair(all_nodes: Array, lower: Array, upper: Array) -> void:
	if lower.is_empty() or upper.is_empty():
		return

	var candidate_edges: Array = []

	# A：比例映射自然目标
	for li in lower.size():
		var ti := _proportional_target_index(li, lower.size(), upper.size())
		_try_add_candidate(candidate_edges, lower[li], upper[ti])

	# B：每点 1/2/3 条出边，仅相邻列索引
	for li in lower.size():
		var want := _roll_desired_out_count()
		var connected: Dictionary = {}
		for e in candidate_edges:
			if int(e.from_id) == int(lower[li].id):
				connected[int(e.to_id)] = true
		var ti_nat := _proportional_target_index(li, lower.size(), upper.size())
		_fill_adjacent_targets(candidate_edges, lower, upper, li, ti_nat, want, connected)

	# C：全局 to 索引单调去交叉（TapTap 第五章）
	var filtered := _decross_edges_global(candidate_edges, lower, upper)
	var upper_ids := _ids_set(upper)
	_clear_edges_between(all_nodes, lower, upper_ids)
	for e in filtered:
		var from_e: Dictionary = {id = e.from_id, col = e.from_col}
		var to_e: Dictionary = {id = e.to_id, col = e.to_col}
		_add_edge(all_nodes, from_e, to_e, 2)

	# D / E + 修剪：保底连通且不再引入交叉
	_decross_and_repair_pair(all_nodes, lower, upper)


## 全图终检：相邻层之间每个节点至少 1 入边 + 1 出边（Boss 只需入边）
static func _ensure_graph_connectivity(all_nodes: Array, floor_cols: Array) -> void:
	for f in range(1, floor_cols.size()):
		var lower: Array = floor_cols[f - 1]
		var upper: Array = floor_cols[f]
		if _is_pre_boss_rest_floor(all_nodes, upper):
			_connect_pre_boss_rest_pair(all_nodes, lower, upper)
			continue
		_decross_and_repair_pair(all_nodes, lower, upper)

	# 起点 → 第一层：再次确保全连（列距可放宽到 2）
	var layer0: Array = floor_cols[0]
	var layer1: Array = floor_cols[1]
	for u in layer1:
		_add_edge(all_nodes, layer0[0], u, 2, true)


static func _sorted_by_col(row: Array) -> Array:
	var copy: Array = row.duplicate()
	copy.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.col) < int(b.col)
	)
	return copy


static func _proportional_target_index(from_i: int, lower_n: int, upper_n: int) -> int:
	if lower_n <= 1:
		return clampi(int((upper_n - 1) / 2.0), 0, upper_n - 1)
	if upper_n <= 1:
		return 0
	var t := int(round(float(from_i) / float(lower_n - 1) * float(upper_n - 1)))
	return clampi(t, 0, upper_n - 1)


static func _roll_desired_out_count() -> int:
	var r := randf()
	if r < 0.6:
		return 1
	if r < 0.9:
		return 2
	return 3


static func _try_add_candidate(edges: Array, from_e: Dictionary, to_e: Dictionary) -> void:
	if not _cols_within_span(int(from_e.col), int(to_e.col)):
		return
	edges.append({from_id = from_e.id, to_id = to_e.id, from_col = from_e.col, to_col = to_e.col})


static func _fill_adjacent_targets(
	edges: Array,
	lower: Array,
	upper: Array,
	li: int,
	ti_center: int,
	want: int,
	connected: Dictionary
) -> void:
	var order: Array[int] = [0]
	for d in range(1, upper.size()):
		order.append(-d)
		order.append(d)
	for off in order:
		if connected.size() >= want:
			break
		var ti := ti_center + off
		if ti < 0 or ti >= upper.size():
			continue
		var to_e: Dictionary = upper[ti]
		if connected.has(int(to_e.id)):
			continue
		if not _cols_within_span(int(lower[li].col), int(to_e.col)):
			continue
		_try_add_candidate(edges, lower[li], to_e)
		connected[int(to_e.id)] = true


## 全局去交叉：边按下层列序排序，保留上层列索引单调不递减的边
static func _decross_edges_global(edges: Array, lower: Array, upper: Array) -> Array:
	var lower_id_to_idx: Dictionary = {}
	var upper_id_to_idx: Dictionary = {}
	for i in lower.size():
		lower_id_to_idx[int(lower[i].id)] = i
	for i in upper.size():
		upper_id_to_idx[int(upper[i].id)] = i

	var sorted_edges: Array = edges.duplicate()
	sorted_edges.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ai: int = lower_id_to_idx.get(int(a.from_id), 0)
		var bi: int = lower_id_to_idx.get(int(b.from_id), 0)
		if ai != bi:
			return ai < bi
		return upper_id_to_idx.get(int(a.to_id), 0) < upper_id_to_idx.get(int(b.to_id), 0)
	)

	var valid: Array = []
	var max_to := -1
	for e in sorted_edges:
		var ti: int = upper_id_to_idx.get(int(e.to_id), -1)
		if ti < 0:
			continue
		if ti >= max_to:
			valid.append(e)
			max_to = ti
	return valid


## 收集相邻两层之间的边（用于去交叉 / 检测）
static func _collect_floor_edges(lower: Array, upper: Array, all_nodes: Array) -> Array:
	var upper_ids := _ids_set(upper)
	var edges: Array = []
	for e in lower:
		var from_id: int = e.id
		for cid in all_nodes[from_id].connections:
			if not upper_ids.has(cid):
				continue
			for u in upper:
				if int(u.id) == cid:
					edges.append({
						from_id = from_id,
						to_id = cid,
						from_col = e.col,
						to_col = u.col,
					})
					break
	return edges


static func _edge_cols_from_edges(edges: Array) -> Array:
	var cols: Array = []
	for e in edges:
		cols.append({from_col = e.from_col, to_col = e.to_col})
	return cols


static func _edge_would_cross(from_col: int, to_col: int, edge_cols: Array) -> bool:
	for ec in edge_cols:
		var fc: int = ec.from_col
		var tc: int = ec.to_col
		if from_col < fc and to_col > tc:
			return true
		if from_col > fc and to_col < tc:
			return true
	return false


static func _clear_edges_between(all_nodes: Array, lower: Array, upper_ids: Dictionary) -> void:
	for e in lower:
		var from_id: int = e.id
		var kept: Array[int] = []
		for cid in all_nodes[from_id].connections:
			if not upper_ids.has(cid):
				kept.append(cid)
		all_nodes[from_id].connections = kept


## 去交叉 → 无交叉补边 → 再修剪（最多 2 轮）
static func _decross_and_repair_pair(all_nodes: Array, lower: Array, upper: Array) -> void:
	if _is_pre_boss_rest_floor(all_nodes, upper):
		return
	lower = _sorted_by_col(lower)
	upper = _sorted_by_col(upper)
	var upper_ids := _ids_set(upper)

	for _pass in 2:
		var edges: Array = _collect_floor_edges(lower, upper, all_nodes)
		var filtered: Array = _decross_edges_global(edges, lower, upper)
		_clear_edges_between(all_nodes, lower, upper_ids)
		for e in filtered:
			var from_e: Dictionary = {id = e.from_id, col = e.from_col}
			var to_e: Dictionary = {id = e.to_id, col = e.to_col}
			_add_edge(all_nodes, from_e, to_e, 2)
		var edge_cols: Array = _edge_cols_from_edges(_collect_floor_edges(lower, upper, all_nodes))
		_ensure_pair_outgoing_safe(all_nodes, lower, upper, edge_cols)
		_ensure_pair_incoming_safe(all_nodes, lower, upper, edge_cols)


static func _add_edge(
	all_nodes: Array,
	from_e: Dictionary,
	to_e: Dictionary,
	max_span: int,
	ignore_out_cap: bool = false
) -> bool:
	if abs(int(from_e.col) - int(to_e.col)) > max_span:
		return false
	var from_id: int = from_e.id
	var to_id: int = to_e.id
	if to_id in all_nodes[from_id].connections:
		return true
	if not ignore_out_cap and _count_outgoing(from_id, all_nodes) >= MAX_EDGES_PER_NODE:
		return false
	all_nodes[from_id].connections.append(to_id)
	return true


static func _ensure_pair_outgoing_safe(
	all_nodes: Array,
	lower: Array,
	upper: Array,
	edge_cols: Array
) -> void:
	for entry in lower:
		if _outgoing_to_upper(entry.id, upper, all_nodes) > 0:
			continue
		if _try_connect_non_crossing(all_nodes, entry, upper, true, edge_cols, 2):
			continue
		# 保底：比例映射目标（通常不交叉）
		var li := _index_in_row(entry, lower)
		if li >= 0:
			var ti := _proportional_target_index(li, lower.size(), upper.size())
			var t: Dictionary = upper[ti]
			if not _edge_would_cross(int(entry.col), int(t.col), edge_cols):
				if _add_edge(all_nodes, entry, t, 2):
					edge_cols.append({from_col = entry.col, to_col = t.col})


static func _ensure_pair_incoming_safe(
	all_nodes: Array,
	lower: Array,
	upper: Array,
	edge_cols: Array
) -> void:
	for entry in upper:
		if _incoming_from_lower(entry.id, lower, all_nodes) > 0:
			continue
		if _try_connect_non_crossing(all_nodes, entry, lower, false, edge_cols, 2):
			continue
		var ui := _index_in_row(entry, upper)
		if ui >= 0:
			var li := _proportional_target_index(ui, upper.size(), lower.size())
			var e: Dictionary = lower[li]
			if not _edge_would_cross(int(e.col), int(entry.col), edge_cols):
				if _add_edge(all_nodes, e, entry, 2):
					edge_cols.append({from_col = e.col, to_col = entry.col})


static func _index_in_row(entry: Dictionary, row: Array) -> int:
	for i in row.size():
		if int(row[i].id) == int(entry.id):
			return i
	return -1


static func _try_connect_non_crossing(
	all_nodes: Array,
	pivot: Dictionary,
	targets: Array,
	is_outgoing: bool,
	edge_cols: Array,
	max_span: int
) -> bool:
	var pivot_col: int = pivot.col
	for t in _sorted_by_col_distance(targets, pivot_col):
		if abs(int(t.col) - pivot_col) > max_span:
			continue
		var fc: int = pivot_col if is_outgoing else int(t.col)
		var tc: int = int(t.col) if is_outgoing else pivot_col
		if _edge_would_cross(fc, tc, edge_cols):
			continue
		if is_outgoing:
			if _add_edge(all_nodes, pivot, t, max_span):
				edge_cols.append({from_col = fc, to_col = tc})
				return true
		else:
			if _add_edge(all_nodes, t, pivot, max_span):
				edge_cols.append({from_col = fc, to_col = tc})
				return true
	return false


static func _outgoing_to_upper(from_id: int, upper: Array, all_nodes: Array) -> int:
	var upper_ids: Dictionary = {}
	for u in upper:
		upper_ids[int(u.id)] = true
	var n := 0
	for cid in all_nodes[from_id].connections:
		if upper_ids.has(cid):
			n += 1
	return n


static func _incoming_from_lower(to_id: int, lower: Array, all_nodes: Array) -> int:
	var lower_ids: Dictionary = {}
	for e in lower:
		lower_ids[int(e.id)] = true
	var n := 0
	for e in lower:
		if to_id in all_nodes[e.id].connections:
			n += 1
	return n


static func _cols_within_span(col_a: int, col_b: int) -> bool:
	return abs(col_a - col_b) <= MAX_COLUMN_SPAN


static func _count_outgoing(from_id: int, all_nodes: Array) -> int:
	return all_nodes[from_id].connections.size()


static func _count_incoming(to_id: int, all_nodes: Array) -> int:
	var n := 0
	for nd in all_nodes:
		if to_id in nd.connections:
			n += 1
	return n
