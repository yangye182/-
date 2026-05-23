## 10 层地图
## - 网格列布局（共 MAP_COLS 列），每层随机占 3~5 列
## - 随机连接 + 连通性保证：除起点外所有节点有入边，除 BOSS 外所有节点有出边
class_name MapGenerator
extends RefCounted

const LAYERS := 10
const MAP_COLS := 5
const MIN_NODES := 3
const MAX_NODES := 5


static func generate() -> Array:
	var all_nodes: Array = []
	var node_id := 0

	# floor_cols[f] = [{col, id}, ...]
	var floor_cols: Array = []

	# 第 0 层：起点
	var start := MapNodeData.new()
	start.id = node_id
	start.layer_index = 0
	start.column_index = MAP_COLS / 2
	start.type = MapNodeData.NodeType.START
	start.available = true
	all_nodes.append(start)
	floor_cols.append([{col = start.column_index, id = node_id}])
	node_id += 1

	# 第 1 ~ 8 层
	for layer in range(1, LAYERS - 1):
		var count := randi_range(MIN_NODES, MAX_NODES)
		var cols := _pick_columns(count)
		var row: Array = []
		for col in cols:
			var n := MapNodeData.new()
			n.id = node_id
			n.layer_index = layer
			n.column_index = col
			n.type = _pick_middle_type(layer, col) as MapNodeData.NodeType
			if n.type == MapNodeData.NodeType.VOID_RIFT:
				n.rift_rule = ["reverse", "silent", "mirror", "deplete", "chaos"].pick_random()
			all_nodes.append(n)
			row.append({col = col, id = node_id})
			node_id += 1
		floor_cols.append(row)

	# 第 9 层：BOSS
	var boss := MapNodeData.new()
	boss.id = node_id
	boss.layer_index = LAYERS - 1
	boss.column_index = MAP_COLS / 2
	boss.type = MapNodeData.NodeType.BOSS
	all_nodes.append(boss)
	floor_cols.append([{col = boss.column_index, id = node_id}])

	# 相邻层随机连接（附带连通性保证）
	for f in range(floor_cols.size() - 2):  # 0→1, 1→2, ..., 7→8
		_connect_floors(all_nodes, floor_cols[f], floor_cols[f + 1])

	# 末层全部指向 BOSS
	var second_last: Array = floor_cols[floor_cols.size() - 2]
	for entry in second_last:
		all_nodes[entry.id as int].connections.append(node_id)

	return all_nodes


## 相邻列（±1）随机连接，保证：
## - 下层每个节点有 1~2 条出边，入边 ≤ 2
## - 上层每个节点有 1~2 条入边，出边 ≤ 2
## - 所有节点（除起点）有入边，所有节点（除 BOSS）有出边
static func _connect_floors(all_nodes: Array, lower: Array, upper: Array) -> void:
	var out_count: Dictionary = {}
	var in_count: Dictionary = {}

	# 第 1 步：每个下层节点随机连接 1~2 个相邻列的上层节点
	for entry in lower:
		var pid: int = entry.id
		var adjacent = _adjacent_entries(entry, upper)
		adjacent.shuffle()
		var count := randi_range(1, mini(2, adjacent.size()))
		for i in range(count):
			var target = adjacent[i]
			all_nodes[pid].connections.append(target.id)
			out_count[pid] = out_count.get(pid, 0) + 1
			in_count[target.id] = in_count.get(target.id, 0) + 1

	# 第 2 步：补下层节点出边——给仍未获得出边的节点安排一条边
	for entry in lower:
		var pid: int = entry.id
		if out_count.get(pid, 0) == 0:
			var adjacent = _adjacent_entries(entry, upper)
			if adjacent.is_empty():
				adjacent = _nearest_entries(entry, upper)
			adjacent.shuffle()
			var selected = adjacent[0]
			all_nodes[pid].connections.append(selected.id)
			out_count[pid] = 1
			in_count[selected.id] = in_count.get(selected.id, 0) + 1

	# 第 3 步：补上层节点入边——给仍未获得入边的节点安排一条边
	for entry in upper:
		var cid: int = entry.id
		if in_count.get(cid, 0) == 0:
			var adjacent = _adjacent_entries(entry, lower)
			if adjacent.is_empty():
				adjacent = _nearest_entries(entry, lower)
			adjacent.shuffle()
			var selected = adjacent[0]
			if cid not in all_nodes[selected.id].connections:
				all_nodes[selected.id].connections.append(cid)
				out_count[selected.id] = out_count.get(selected.id, 0) + 1
				in_count[cid] = 1


## 返回 targets 中与 source 列差 ≤ 1 的条目
static func _adjacent_entries(source: Dictionary, targets: Array) -> Array:
	var result: Array = []
	var scol: int = source.col
	for t in targets:
		if abs(scol - t.col as int) <= 1:
			result.append(t)
	return result


## 返回 targets 中与 source 列差最近的条目（按列距升序）
static func _nearest_entries(source: Dictionary, targets: Array) -> Array:
	var sorted := targets.duplicate()
	sorted.sort_custom(func(a, b): return abs(a.col - source.col) < abs(b.col - source.col))
	return sorted


## 从 MAP_COLS 列中随机选 count 列（结果升序排列）
static func _pick_columns(count: int) -> Array[int]:
	var all: Array[int] = []
	for i in range(MAP_COLS):
		all.append(i)
	all.shuffle()
	var picked := all.slice(0, count)
	picked.sort()
	return picked


static func _pick_middle_type(layer: int, _col: int) -> int:
	# 第 1-2 层：高概率战斗
	if layer <= 2:
		var pool := [MapNodeData.NodeType.COMBAT, MapNodeData.NodeType.COMBAT, MapNodeData.NodeType.COMBAT,
			MapNodeData.NodeType.REST, MapNodeData.NodeType.SHOP, MapNodeData.NodeType.EVENT]
		return pool[randi() % pool.size()]
	# 第 6-8 层：出现精英和虚空裂隙
	var r := randi() % 100
	if layer >= 6:
		if r < 40: return MapNodeData.NodeType.COMBAT
		elif r < 55: return MapNodeData.NodeType.ELITE
		elif r < 70: return MapNodeData.NodeType.VOID_RIFT
		elif r < 80: return MapNodeData.NodeType.REST
		elif r < 90: return MapNodeData.NodeType.SHOP
		elif r < 95: return MapNodeData.NodeType.EVENT
		else: return MapNodeData.NodeType.SAGE_ALTAR
	# 第 3-5 层：均衡
	if r < 45: return MapNodeData.NodeType.COMBAT
	elif r < 55: return MapNodeData.NodeType.ELITE
	elif r < 65: return MapNodeData.NodeType.VOID_RIFT
	elif r < 75: return MapNodeData.NodeType.REST
	elif r < 85: return MapNodeData.NodeType.SHOP
	elif r < 95: return MapNodeData.NodeType.EVENT
	else: return MapNodeData.NodeType.RUNE_FORGE
