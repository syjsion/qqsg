class_name Catalog
extends RefCounted

const PROTOCOL = 2
const CONTENT = "0.1.1"
const SAVE_VERSION = 1
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
	for item_id in record.equipment.values():
		var item: Dictionary = table("items").get(item_id, {})
		for key in item.get("stats", {}):
			s[key] = s.get(key, 0) + item.stats[key]
	return s

static func required_exp(level: int) -> int:
	load_data()
	return int(progression.experience_to_next[clampi(level, 1, 10) - 1])

static func new_character(id: String, display_name: String, job: String) -> Dictionary:
	return {"id": id, "name": display_name, "job": job, "level": 1, "xp": 0,
		"money": 100, "map": "bajun", "inventory": {"potion": 8, "ether": 5},
		"equipment": {"weapon": "iron_sword" if job == "JS" else "wood_staff", "armor": "cloth"},
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
