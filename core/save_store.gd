class_name SaveStore
extends RefCounted

var directory: String
var error = ""

func _init(path: String = "user://server") -> void:
	directory = path

func read() -> Dictionary:
	error = ""
	for name in ["world.json", "world.backup.json"]:
		var path = directory.path_join(name)
		if not FileAccess.file_exists(path):
			continue
		var raw = FileAccess.get_file_as_string(path)
		var state = decode(raw)
		if not state.is_empty():
			if int(_payload(raw).get("version", 0)) == 1:
				var backup = directory.path_join("world.v1." + raw.sha256_text().left(16) + ".json")
				if FileAccess.file_exists(backup) and FileAccess.get_file_as_string(backup) != raw:
					error = "旧档迁移备份存在但内容不一致，拒绝覆盖"
					return {}
				if not FileAccess.file_exists(backup) and not _atomic(backup, raw): return {}
			if name.contains("backup"):
				push_warning("主存档无效，已从有效备份恢复")
			return state
	if FileAccess.file_exists(directory.path_join("world.json")) or FileAccess.file_exists(directory.path_join("world.backup.json")):
		error = "存档损坏或版本不兼容；拒绝覆盖，请检查备份"
	return {}

static func _payload(text: String) -> Dictionary:
	var parser = JSON.new()
	if parser.parse(text) != OK: return {}
	var envelope = parser.data
	if not envelope is Dictionary or not envelope.get("payload") is String: return {}
	if envelope.get("sha256", "") != envelope.payload.sha256_text(): return {}
	if parser.parse(envelope.payload) != OK or not parser.data is Dictionary: return {}
	return parser.data

static func _integer(value, minimum: int = 0) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= minimum

static func _gear_valid(g, id: String) -> bool:
	if not g is Dictionary or g.get("id", "") != id: return false
	if not Catalog.table("items").get(g.get("item", ""), {}).has("slot"): return false
	if not _integer(g.get("enhance")) or int(g.enhance) > 6: return false
	if not _integer(g.get("failures")) or int(g.failures) > 3: return false
	return _integer(g.get("revision")) and (int(g.enhance) < 6 or int(g.failures) == 0)

static func decode(text: String) -> Dictionary:
	var state = _payload(text)
	if int(state.get("version", 0)) not in [1, Catalog.SAVE_VERSION]: return {}
	var legacy = int(state.version) == 1
	for key in ["records", "tokens", "drops"]:
		if not state.get(key) is Dictionary: return {}
	var all_gear: Dictionary = {}
	for id in state.records:
		var p = state.records[id]
		if not p is Dictionary or p.get("id", "") != id or p.get("job", "") not in ["JS", "XS"]: return {}
		for key in ["inventory", "equipment", "quests", "kills"]:
			if not p.get(key) is Dictionary: return {}
		if not p.get("name") is String or not Catalog.table("maps").has(p.get("map", "")): return {}
		for key in ["level", "xp", "money", "revision", "hp", "mp"]:
			if not _integer(p.get(key)): return {}
		if int(p.level) < 1 or int(p.level) > 10: return {}
		if legacy: p.gear = {}
		if not p.get("gear") is Dictionary: return {}
		for item in p.inventory.keys():
			if not Catalog.table("items").has(item) or not _integer(p.inventory[item], 1): return {}
			if Catalog.table("items")[item].has("slot"):
				if not legacy or int(p.inventory[item]) > 24: return {}
				for i in range(int(p.inventory[item])):
					var gid = (str(id) + "/bag/" + item + "/" + str(i)).sha256_text().left(32)
					p.gear[gid] = GearRules.create(item, gid)
				p.inventory.erase(item)
		for slot in p.equipment:
			if slot not in ["weapon", "armor"]: return {}
			if legacy:
				var item = p.equipment[slot]
				if not item is String or Catalog.table("items").get(item, {}).get("slot", "") != slot: return {}
				var gid = (str(id) + "/equipped/" + slot).sha256_text().left(32)
				p.gear[gid] = GearRules.create(item, gid)
				p.equipment[slot] = gid
			var gid = p.equipment[slot]
			if not gid is String or not p.gear.has(gid) or not _gear_valid(p.gear[gid], gid): return {}
			var item = Catalog.table("items")[p.gear[gid].item]
			if item.slot != slot or item.get("job", "") not in ["", p.job] or int(item.get("level", 1)) > int(p.level): return {}
		for gid in p.gear:
			if not gid is String or all_gear.has(gid) or not _gear_valid(p.gear[gid], gid): return {}
			all_gear[gid] = true
		if InventoryRules.used_slots(p) > InventoryRules.CAPACITY: return {}
	for id in state.drops:
		var d = state.drops[id]
		if not d is Dictionary or d.get("id", "") != id or not state.records.has(d.get("owner", "")): return {}
		if not Catalog.table("maps").has(d.get("map", "")) or not Catalog.table("items").has(d.get("item", "")) or not _integer(d.get("count"), 1): return {}
		for key in ["x", "y"]:
			if not (d.get(key) is int or d.get(key) is float) or not is_finite(float(d[key])): return {}
		if Catalog.table("items")[d.item].has("slot"):
			if int(d.count) != 1: return {}
			if legacy: d.gear = GearRules.create(d.item, ("drop/" + str(id)).sha256_text().left(32))
			if not d.get("gear") is Dictionary: return {}
			var gid = d.gear.get("id", "")
			if not gid is String or all_gear.has(gid) or not _gear_valid(d.gear, gid) or d.gear.item != d.item: return {}
			all_gear[gid] = true
	for token in state.tokens:
		if not state.records.has(state.tokens[token]): return {}
	if legacy:
		state.version = Catalog.SAVE_VERSION
		state.content = Catalog.CONTENT
	return state

func write(state: Dictionary) -> bool:
	error = ""
	var payload = JSON.stringify(state)
	var text = JSON.stringify({"payload": payload, "sha256": payload.sha256_text()})
	if decode(text).is_empty():
		error = "存档状态无效"
		return false
	var result = DirAccess.make_dir_recursive_absolute(directory)
	if result != OK and result != ERR_ALREADY_EXISTS:
		error = "无法创建存档目录"
		return false
	var path = directory.path_join("world.json")
	if FileAccess.file_exists(path):
		var old = FileAccess.get_file_as_string(path)
		if not decode(old).is_empty() and not _atomic(directory.path_join("world.backup.json"), old):
			return false
	return _atomic(path, text)

func _atomic(path: String, text: String) -> bool:
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		error = "无法写入存档临时文件"
		return false
	file.store_string(text)
	file.flush()
	var failed = file.get_error() != OK
	file.close()
	if failed or DirAccess.rename_absolute(path + ".tmp", path) != OK:
		error = "原子替换存档失败"
		return false
	return true
