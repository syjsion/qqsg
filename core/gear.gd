class_name GearRules
extends RefCounted

static func create(item: String, stable_id: String = "") -> Dictionary:
	return {"id": stable_id if stable_id != "" else Crypto.new().generate_random_bytes(16).hex_encode(),
		"item": item, "enhance": 0, "failures": 0, "revision": 0}

static func stats(gear: Dictionary) -> Dictionary:
	var result: Dictionary = Catalog.table("items")[gear.item].stats.duplicate()
	for key in result:
		result[key] = int(result[key]) + int(gear.enhance) * maxi(1, ceili(float(result[key]) * 0.1))
	return result

static func label(gear: Dictionary) -> String:
	return "%s +%d [%s]" % [Catalog.table("items")[gear.item].name, gear.enhance, gear.id.left(6)]

static func quote(gear: Dictionary) -> Dictionary:
	var recipes: Array = Catalog.table("enhancement").levels
	if int(gear.enhance) >= recipes.size(): return {}
	var result: Dictionary = recipes[int(gear.enhance)].duplicate()
	result.chance = 1.0 if int(gear.failures) >= 3 else float(result.chance)
	return result

static func enhance(record: Dictionary, id: String, expected: int, rng: RandomNumberGenerator) -> Dictionary:
	if not record.gear.has(id): return {"error":"装备不存在"}
	var gear: Dictionary = record.gear[id]
	if int(gear.revision) != expected: return {"error":"装备状态已变化，请刷新后重试"}
	var cost = quote(gear)
	if cost.is_empty(): return {"error":"已达到强化上限 +6"}
	if int(record.money) < int(cost.money) or int(record.inventory.get("enhance_stone", 0)) < int(cost.stones):
		return {"error":"强化石或金钱不足"}
	InventoryRules.take(record.inventory, "enhance_stone", int(cost.stones))
	record.money -= int(cost.money)
	var success = float(cost.chance) >= 1.0 or rng.randf() < float(cost.chance)
	if success:
		gear.enhance += 1
		gear.failures = 0
	else: gear.failures += 1
	gear.revision += 1
	return {"error":"", "enhanced":success, "gear_id":id, "level":gear.enhance, "failures":gear.failures, "revision":gear.revision}
