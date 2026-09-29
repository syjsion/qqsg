class_name LootRules
extends RefCounted

static func rounds(multiplier: float, rng: RandomNumberGenerator) -> int:
	return floori(multiplier) + (1 if rng.randf() < fmod(multiplier, 1.0) else 0)

static func boss(job: String, rng: RandomNumberGenerator) -> Array:
	var table = Catalog.table("boss_loot")
	var result: Array = []
	for item in table.guaranteed: result.append({"item":item,"count":int(table.guaranteed[item])})
	var roll = rng.randi_range(0, 99)
	for entry in table.equipment:
		roll -= int(entry.weight)
		if roll < 0:
			result.append({"item":entry[job],"count":1})
			break
	return result

static func monster(kind: String, rng: RandomNumberGenerator) -> Array:
	var def: Dictionary = Catalog.table("monsters")[kind]
	var result: Array = [{"item":def.loot[rng.randi_range(0, def.loot.size()-1)],"count":1}]
	if float(def.get("stone_chance", 0)) >= 1.0 or rng.randf() < float(def.get("stone_chance", 0)): result.append({"item":"enhance_stone","count":1})
	return result
