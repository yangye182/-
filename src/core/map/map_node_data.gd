## 地图节点数据
class_name MapNodeData
extends RefCounted

enum NodeType {
	START, COMBAT, ELITE, REST, SHOP, RUNE_FORGE, SAGE_ALTAR,
	VOID_RIFT, EVENT, BOSS
}

var id: int = 0
var type: NodeType = NodeType.COMBAT
var layer_index: int = 0
var column_index: int = 0
var connections: Array[int] = []
var visited: bool = false
var available: bool = false
var rift_rule: String = ""


static func type_name(t: NodeType) -> String:
	match t:
		NodeType.START:
			return GameLocale.t("Start", "起始")
		NodeType.COMBAT:
			return GameLocale.t("Fight", "战斗")
		NodeType.ELITE:
			return GameLocale.t("Elite", "精英")
		NodeType.REST:
			return GameLocale.t("Rest", "休息")
		NodeType.SHOP:
			return GameLocale.t("Shop", "商店")
		NodeType.RUNE_FORGE:
			return GameLocale.t("Rune Forge", "符文熔炉")
		NodeType.SAGE_ALTAR:
			return GameLocale.t("Sage Altar", "贤者祭坛")
		NodeType.VOID_RIFT:
			return GameLocale.t("Void Rift", "虚空裂隙")
		NodeType.EVENT:
			return GameLocale.t("?", "？")
		NodeType.BOSS:
			return GameLocale.t("BOSS", "BOSS")
	return "?"
