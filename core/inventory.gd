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

static func used_slots(record: Dictionary) -> int:
	return slots(record.inventory) + record.gear.size() - record.equipment.size()

static func add_item(record: Dictionary, item: String, count: int = 1, instance: Dictionary = {}) -> bool:
	if count < 1 or not Catalog.table("items").has(item): return false
	if Catalog.table("items")[item].has("slot"):
		if used_slots(record) + count > CAPACITY: return false
		if not instance.is_empty():
			if count != 1 or record.gear.has(instance.id) or instance.item != item: return false
			record.gear[instance.id] = instance.duplicate(true)
		else:
			for i in range(count):
				var gear = GearRules.create(item)
				record.gear[gear.id] = gear
		return true
	var bag: Dictionary = record.inventory.duplicate()
	if not add(bag, item, count): return false
	if slots(bag) + record.gear.size() - record.equipment.size() > CAPACITY: return false
	record.inventory = bag
	return true

static func equip(record: Dictionary, id: String) -> String:
	if not record.gear.has(id): return "装备不存在"
	var item: Dictionary = Catalog.table("items")[record.gear[id].item]
	if id in record.equipment.values(): return "该装备已穿戴"
	if int(item.get("level", 1)) > int(record.level): return "等级不足"
	if item.get("job", "") not in ["", record.job]: return "职业不符"
	record.equipment[item.slot] = id
	return ""
