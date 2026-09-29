class_name Catalog
extends RefCounted

const PROTOCOL = 3
const CONTENT = "0.2.0"
const SAVE_VERSION = 2
static var content: Dictionary = {}
static var progression: Dictionary = {}

static func load_data() -> void:
	if content.is_empty():
		content = JSON.parse_string(FileAccess.get_file_as_string("res://data/content.json"))
		progression = JSON.parse_string(FileAccess.get_file_as_string("res://data/progression.json"))

static func table(kind: String) -> Dictionary:
	load_data()
	return content[kind]

static func stats(record: Dictionary) -> Dictionary:
	load_data()
	var s: Dictionary = progression.stats[record.job][clampi(int(record.level), 1, 10) - 1].duplicate()
	s.physical_attack = 6
	s.magic_attack = 6
	s.defense = 2
	for id in record.equipment.values():
		var bonus = GearRules.stats(record.gear[id])
		for key in bonus: s[key] = s.get(key, 0) + bonus[key]
	return s

static func required_exp(level: int) -> int:
	load_data()
	return int(progression.experience_to_next[clampi(level, 1, 10) - 1])

static func new_character(id: String, display_name: String, job: String) -> Dictionary:
	var weapon = GearRules.create("iron_sword" if job == "JS" else "wood_staff")
	var armor = GearRules.create("cloth")
	return {"id": id, "name": display_name, "job": job, "level": 1, "xp": 0,
		"money": 100, "map": "bajun", "inventory": {"potion": 8, "ether": 5},
		"gear": {weapon.id:weapon, armor.id:armor}, "equipment": {"weapon":weapon.id, "armor":armor.id},
		"quests": {}, "kills": {}, "revision": 0}

static func gain_exp(record: Dictionary, amount: int) -> bool:
	var leveled = false
	if int(record.level) == 10:
		return false
	record.xp += maxi(0, amount)
	while record.level < 10 and record.xp >= required_exp(record.level):
		record.xp -= required_exp(record.level)
		record.level += 1
		leveled = true
	if record.level == 10:
		record.xp = 0
	return leveled
