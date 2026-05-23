## 分层 DAG 地图：仅向前连接，BOSS 在顶层，任意路线可达 BOSS
class_name MapGenerator
extends RefCounted

## 层数：0=起点，1~(LAYERS-2)=中间层，LAYERS-1=BOSS
const LAYERS := 4
const NODES_PER_MIDDLE_LAYER := 3


static func generate() -> Array:
	var all_nodes: Array = []
	var node_id := 0

	# 第 0 层：仅起点
	var start := MapNodeData.new()
	start.id = node_id
	start.layer_index = 0
	start.type = MapNodeData.NodeType.START
	start.available = true
	all_nodes.append(start)
	node_id += 1
	var prev_layer_ids: Array[int] = [0]

	# 中间层（不含 BOSS）
	for layer in range(1, LAYERS - 1):
		var layer_ids: Array[int] = []
		for col in NODES_PER_MIDDLE_LAYER:
			var n := MapNodeData.new()
			n.id = node_id
			n.layer_index = layer
			n.type = _pick_middle_type(layer, col)
			if n.type == MapNodeData.NodeType.VOID_RIFT:
				n.rift_rule = ["reverse", "silent", "mirror", "deplete", "chaos"].pick_random()
			all_nodes.append(n)
			layer_ids.append(node_id)
			node_id += 1

		# 上一层 → 当前层（只向前，每节点连 1~2 个下层节点）
		for pid in prev_layer_ids:
			var p: MapNodeData = all_nodes[pid]
			var targets: Array[int] = layer_ids.duplicate()
			targets.shuffle()
			var link_n: int = randi_range(1, mini(2, targets.size()))
			for i in link_n:
				var tid: int = targets[i]
				if tid not in p.connections:
					p.connections.append(tid)

		# 当前层每个节点至少有一条入边（保证从上面能走到）
		for cid in layer_ids:
			var has_in := false
			for pid in prev_layer_ids:
				if cid in (all_nodes[pid] as MapNodeData).connections:
					has_in = true
					break
			if not has_in:
				var from_id: int = prev_layer_ids[randi() % prev_layer_ids.size()]
				(all_nodes[from_id] as MapNodeData).connections.append(cid)

		# 上一层每个节点至少一条出边（保证能继续往上）
		for pid in prev_layer_ids:
			var p: MapNodeData = all_nodes[pid]
			if p.connections.is_empty():
				var tid: int = layer_ids[randi() % layer_ids.size()]
				p.connections.append(tid)

		prev_layer_ids = layer_ids

	# 最后一层：仅 BOSS
	var boss := MapNodeData.new()
	boss.id = node_id
	boss.layer_index = LAYERS - 1
	boss.type = MapNodeData.NodeType.BOSS
	all_nodes.append(boss)
	var boss_id: int = node_id

	# 倒数第二层全部指向 BOSS（保证无论怎么走最终能到 BOSS）
	for pid in prev_layer_ids:
		var p: MapNodeData = all_nodes[pid]
		if boss_id not in p.connections:
			p.connections.append(boss_id)

	return all_nodes


static func _pick_middle_type(_layer: int, _col: int) -> MapNodeData.NodeType:
	var roll := randf()
	if roll < 0.42:
		return MapNodeData.NodeType.COMBAT
	if roll < 0.52:
		return MapNodeData.NodeType.REST
	if roll < 0.62:
		return MapNodeData.NodeType.SHOP
	if roll < 0.69:
		return MapNodeData.NodeType.EVENT
	if roll < 0.76:
		return MapNodeData.NodeType.RUNE_FORGE
	if roll < 0.82:
		return MapNodeData.NodeType.SAGE_ALTAR
	if roll < 0.90:
		return MapNodeData.NodeType.ELITE
	if roll < 0.96:
		return MapNodeData.NodeType.VOID_RIFT
	return MapNodeData.NodeType.COMBAT
