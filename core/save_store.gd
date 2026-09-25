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
		var state = decode(FileAccess.get_file_as_string(path))
		if not state.is_empty():
			if name.contains("backup"):
				push_warning("主存档无效，已从有效备份恢复")
			return state
	if FileAccess.file_exists(directory.path_join("world.json")) or FileAccess.file_exists(directory.path_join("world.backup.json")):
		error = "存档损坏或版本不兼容；拒绝覆盖，请检查备份"
	return {}

static func decode(text: String) -> Dictionary:
	var parser = JSON.new()
	if parser.parse(text) != OK:
		return {}
	var envelope = parser.data
	if not envelope is Dictionary or not envelope.get("payload") is String:
		return {}
	if envelope.get("sha256", "") != envelope.payload.sha256_text():
		return {}
	if parser.parse(envelope.payload) != OK:
		return {}
	var state = parser.data
	if not state is Dictionary or state.get("version", 0) != Catalog.SAVE_VERSION:
		return {}
	if not state.get("records") is Dictionary or not state.get("tokens") is Dictionary or not state.get("drops") is Dictionary:
		return {}
	for id in state.records:
		var p = state.records[id]
		if not p is Dictionary or p.get("job", "") not in ["JS", "XS"] or not p.get("inventory") is Dictionary or not p.get("equipment") is Dictionary:
			return {}
		if int(p.get("level", 0)) < 1 or int(p.level) > 10 or not Catalog.table("maps").has(p.get("map", "")):
			return {}
		for item_id in p.inventory:
			if not Catalog.table("items").has(item_id) or int(p.inventory[item_id]) < 1:
				return {}
		for item_id in p.equipment.values():
			if not Catalog.table("items").has(item_id):
				return {}
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
