class_name InventoryRules
extends RefCounted

const CAPACITY = 24

static func slots(bag: Dictionary) -> int:
	var count = 0
	for id in bag:
		count += ceili(float(bag[id]) / float(Catalog.table("items")[id].stack))
	return count

static func add(bag: Dictionary, id: String, count: int = 1) -> bool:
	if count < 1 or not Catalog.table("items").has(id):
		return false
	var next = bag.duplicate()
	next[id] = int(next.get(id, 0)) + count
	if slots(next) > CAPACITY:
		return false
	bag[id] = next[id]
	return true

static func take(bag: Dictionary, id: String, count: int = 1) -> bool:
	if count < 1 or int(bag.get(id, 0)) < count:
		return false
	bag[id] -= count
	if bag[id] <= 0:
		bag.erase(id)
	return true

static func equip(record: Dictionary, id: String) -> String:
	var item: Dictionary = Catalog.table("items").get(id, {})
	if not item.has("slot") or not record.inventory.has(id):
		return "物品无法装备"
	if int(item.get("level", 1)) > int(record.level):
		return "等级不足"
	if item.get("job", "") not in ["", record.job]:
		return "职业不符"
	var bag: Dictionary = record.inventory.duplicate()
	take(bag, id)
	var previous: String = record.equipment.get(item.slot, "")
	if previous != "" and not add(bag, previous):
		return "背包已满"
	record.inventory = bag
	record.equipment[item.slot] = id
	return ""
