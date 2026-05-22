## 地图推进：不可回头；战斗胜利后才解锁下一层
class_name MapProgress
extends RefCounted


static func can_enter(node: MapNodeData) -> bool:
	return node.available and not node.visited


## 进入战斗类节点：标记已访问并锁定全图（含同层其他分支）
static func lock_all(all_nodes: Array) -> void:
	for n in all_nodes:
		(n as MapNodeData).available = false


## 完成节点后解锁下一层子节点（connections 仅指向更高层）
static func unlock_children_from(current: MapNodeData, all_nodes: Array) -> void:
	lock_all(all_nodes)
	for cid in current.connections:
		if cid < 0 or cid >= all_nodes.size():
			continue
		var child: MapNodeData = all_nodes[cid]
		if not child.visited:
			child.available = true


## 非战斗节点：访问后立即解锁子节点
static func advance_from(current: MapNodeData, all_nodes: Array) -> void:
	unlock_children_from(current, all_nodes)
