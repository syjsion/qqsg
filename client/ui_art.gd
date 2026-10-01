class_name UIArt
extends RefCounted

static var data: Dictionary = {}
static var cache: Dictionary = {}
static var window_texture: Texture2D

static func texture(group: String, id: String) -> Texture2D:
	if data.is_empty(): data = JSON.parse_string(FileAccess.get_file_as_string("res://data/art.json"))
	var key = group + ":" + id
	if cache.has(key): return cache[key]
	var entry = data.get(group, {}).get(id)
	if entry == null: return null
	var result: Texture2D
	if entry is String:
		result = load(entry)
	else:
		var atlas = AtlasTexture.new()
		atlas.atlas = load(entry.path)
		var r: Array = entry.region
		atlas.region = Rect2(r[0], r[1], r[2], r[3])
		atlas.filter_clip = true
		result = atlas
	cache[key] = result
	return result

static func frame(inset: int = 18) -> StyleBoxTexture:
	var style = StyleBoxTexture.new()
	if window_texture == null:
		# Runtime rendering size only; preserve the generated source bitmap.
		var image = texture("ui", "frame").get_image()
		image.resize(256,256,Image.INTERPOLATE_LANCZOS)
		window_texture = ImageTexture.create_from_image(image)
	style.texture = window_texture
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 30)
		style.set_content_margin(side, inset)
	return style

static func image(group: String, id: String, dimensions: Vector2) -> TextureRect:
	var node = TextureRect.new()
	node.texture = texture(group, id)
	node.custom_minimum_size = dimensions
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

static func button_style(tint: Color = Color.WHITE) -> StyleBoxTexture:
	var style = frame(10)
	style.modulate_color = tint
	for side in [SIDE_TOP,SIDE_BOTTOM]: style.set_content_margin(side,6)
	return style

static func bag_entries(record: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var ids: Array = record.gear.keys()
	ids.sort()
	for id in ids:
		if id not in record.equipment.values():
			result.append({"key":id, "item":record.gear[id].item, "gear":record.gear[id], "count":1})
	ids = record.inventory.keys()
	ids.sort()
	for id in ids:
		var remaining = int(record.inventory[id])
		var index = 0
		var maximum = int(Catalog.table("items")[id].stack)
		while remaining > 0:
			result.append({"key":"%s:%d" % [id, index], "item":id, "count":mini(maximum, remaining)})
			remaining -= maximum
			index += 1
	return result

static func item_text(entry: Dictionary, record: Dictionary) -> String:
	var item: Dictionary = Catalog.table("items")[entry.item]
	var text: String = item.name
	if entry.has("gear"):
		text = item.name if entry.get("template",false) else GearRules.label(entry.gear)
		text += "\n%s · 等级 %d · %s" % ["精良" if item.get("quality", "common") == "fine" else "普通", item.get("level", 1), Catalog.table("classes").get(item.get("job", ""), {}).get("name", "通用")]
		var names = {"physical_attack":"物攻", "magic_attack":"法攻", "defense":"防御", "hp":"生命上限"}
		var stats = GearRules.stats(entry.gear)
		var worn: Dictionary = record.gear.get(record.equipment.get(item.slot, ""), {})
		var current: Dictionary = GearRules.stats(worn) if not worn.is_empty() else {}
		for stat in stats:
			text += "\n%s +%d  （较已穿戴 %+d）" % [names.get(stat,stat), stats[stat], int(stats[stat])-int(current.get(stat,0))]
		if entry.gear.id in record.equipment.values(): text += "\n已穿戴"
		if not entry.get("template",false): text += "\n连续强化失败 %d/3" % entry.gear.failures
	else:
		text += "\n持有 %d · 每格上限 %d" % [record.inventory.get(entry.item,0), item.stack]
		if item.has("hp"): text += "\n恢复生命 %d" % item.hp
		elif item.has("mp"): text += "\n恢复体力 %d" % item.mp
		else: text += "\n材料／任务物品"
	return text
