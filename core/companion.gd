class_name CompanionRules
extends RefCounted

const CAPACITY = 12

static func create(kind: String) -> Dictionary:
	var result = {"id":"comp_" + Crypto.new().generate_random_bytes(16).hex_encode(),"kind":kind,
		"level":1,"xp":0,"hp":int(Catalog.table("companions")[kind].hp),
		"recovery_remaining":20.0,"skill_cooldown_remaining":0.0}
	return result

static func stats(c: Dictionary) -> Dictionary:
	var d: Dictionary = Catalog.table("companions")[c.kind]
	var growth = int(c.level) - 1
	return {"hp":int(d.hp) + growth * int(d.hp_growth),
		"defense":int(d.defense) + floori(float(growth) / float(d.defense_step)),
		"power":int(d.power) + growth * int(d.power_growth)}

static func required_exp(level: int) -> int:
	return 40 * level * level

static func gain_exp(c: Dictionary, xp: int, owner_level: int) -> void:
	var cap = mini(10,owner_level)
	if int(c.level) >= cap: c.xp = 0; return
	c.xp += maxi(0,xp)
	while c.level < cap and c.xp >= required_exp(c.level):
		c.xp -= required_exp(c.level)
		c.level += 1
		# Growth adds capacity without reviving an unconscious companion.
		if c.hp > 0: c.hp += int(Catalog.table("companions")[c.kind].hp_growth)
	if c.level == cap: c.xp = 0

static func valid(c, id: String, owner_level: int) -> bool:
	if not c is Dictionary or c.get("id","") != id or not id.begins_with("comp_"): return false
	if not Catalog.table("companions").has(c.get("kind","")): return false
	for key in ["level","xp","hp"]:
		if not SaveStore._integer(c.get(key)): return false
	if c.level < 1 or c.level > mini(10,owner_level) or c.hp > stats(c).hp: return false
	if c.xp >= required_exp(c.level) or (c.level == mini(10,owner_level) and c.xp != 0): return false
	for key in ["recovery_remaining","skill_cooldown_remaining"]:
		var value = c.get(key)
		if not (value is float or value is int) or not is_finite(float(value)) or value < 0: return false
	return c.recovery_remaining <= 20 and c.skill_cooldown_remaining <= float(Catalog.table("companions")[c.kind].cooldown)
