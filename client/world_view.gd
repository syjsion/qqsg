class_name WorldView
extends Node2D

signal entity_clicked(id: String)
signal npc_clicked(id: String)

var art: Dictionary
var textures: Dictionary = {}
var sheet: Texture2D
var font: Font
var state: Dictionary = {}
var predicted: Dictionary = {}
var selected = ""
var camera_x = 0.0
var camera_y = 80.0
var age = 0.0
var effects: Array[Dictionary] = []
var smooth: Dictionary = {}
var preview = true

var snapshot_age = 0.0

func _ready() -> void:
	art = JSON.parse_string(FileAccess.get_file_as_string("res://data/art.json"))
	font = load(art.font)
	sheet = load("res://assets/generated/healer-sheet.png")
	set_process(true)

func texture(path: String) -> Texture2D:
	if not textures.has(path): textures[path] = load(path)
	return textures[path]

func _process(dt: float) -> void:
	age += dt
	for e in effects: e.life -= dt
	effects = effects.filter(func(e): return e.life > 0)
	if not predicted.is_empty():
		var map: Dictionary = Catalog.table("maps")[state.get("map", "bajun")]
		camera_x = lerpf(camera_x, clampf(float(predicted.x) - 620, 0, float(map.width) - 1280), minf(1, dt * 8))
		camera_y = lerpf(camera_y, clampf(float(predicted.y) - 470, -10, 110), minf(1, dt * 6))
	queue_redraw()

func effect(e: Dictionary) -> void:
	var position = Vector2.ZERO
	for actor in state.get("players", []) + state.get("monsters", []):
		if actor.id == e.target: position = Vector2(float(actor.x), float(actor.y))
	if e.kind in ["damage", "critical", "heal", "level", "cast"]:
		effects.append({"position": position, "life": 1.0, "kind": e.kind, "amount": e.amount, "skill": e.get("text", "")})

func point(x: float, y: float) -> Vector2:
	return Vector2(x - camera_x, y - camera_y)

func _scenery(id: String, x: float, y: float, factor: float = 1.0, anchored: bool = true) -> void:
	if not art.scenery.has(id): return
	var tex = texture(art.scenery[id])
	var size = tex.get_size() * factor
	var p = point(x, y)
	if anchored: p -= Vector2(size.x * 0.5, size.y)
	if p.x > 1380 or p.x + size.x < -100: return
	draw_texture_rect(tex, Rect2(p, size), false)

func _draw() -> void:
	if art == null or art.is_empty(): return
	var map_id: String = state.get("map", "bajun")
	var map: Dictionary = Catalog.table("maps")[map_id]
	var sky = texture(art.scenery["14271-1" if map_id == "camp" else "8985-1"])
	draw_texture_rect(sky, Rect2(0, 0, 1280, 610), false, Color(0.86, 0.9, 0.92) if map_id == "camp" else Color.WHITE)
	# Painted background layers use a slower camera, preserving the classic parallax feel.
	var old_camera = camera_x
	camera_x *= 0.25
	for x in range(-200, 3500, 1000):
		_scenery("9024-1", x + 200, 220, 0.7)
		_scenery("9009-1", x, 620, 1.1)
		_scenery("9011-1", x + 520, 620, 1.0)
	camera_x = old_camera
	if map_id == "bajun":
		for x in [330, 930, 1550]:
			_scenery("13321-1", x, 600, 0.92)
		_scenery("14475-1", 1920, 600, 1.0)
		_scenery("13318-1", 80, 600, 0.85)
		_scenery("18325-1", 750, 600, 0.85)
		_scenery("18326-1", 1150, 600, 0.85)
		_scenery("18308-1", 1350, 600, 0.8)
	else:
		for x in range(100, int(map.width), 380):
			_scenery("19178-1", x, 600, 0.85)
		if map_id == "camp":
			for x in [500, 950, 1450, 2000, 2400]:
				_scenery("15073-1", x, 600, 0.75)
				_scenery("15070-1", x + 90, 600, 1.1)
			_scenery("15062-1", 2380, 600, 1.0)
	for platform in map.platforms:
		var ground = float(platform[2]) == 600
		var tile: String = "14478-1" if map_id == "bajun" and ground else "16862-1" if map_id == "bajun" else "18644-1"
		var tex = texture(art.scenery[tile])
		var width = 180.0 if map_id == "bajun" else 200.0
		var xx = float(platform[0])
		if ground:
			draw_rect(Rect2(point(xx, 603), Vector2(float(platform[1]) - xx, 200)), Color("777465") if map_id == "bajun" else Color("666950"))
		while xx < float(platform[1]):
			var w = minf(width, float(platform[1]) - xx)
			draw_texture_rect_region(tex, Rect2(point(xx, float(platform[2]) - 8), Vector2(w, 34)), Rect2(0, 0, tex.get_width() * w / width, tex.get_height()))
			if ground:
				var soil = texture(art.scenery["16864-1" if map_id == "bajun" else "18645-1"])
				draw_texture_rect(soil, Rect2(point(xx, 625), Vector2(w, 160)), false)
			xx += width
	for ladder in map.ladders:
		var tex = texture(art.scenery["16883-1"])
		draw_texture_rect(tex, Rect2(point(float(ladder[0]) - 20, float(ladder[1])), Vector2(40, float(ladder[2]) - float(ladder[1]))), false)
	for portal in map.portals:
		var p = point(float(portal.x), float(portal.y))
		for radius in [32, 39, 46]:
			draw_arc(p - Vector2(0, 40), float(radius), age * 0.8, age * 0.8 + TAU * 0.88, 50, Color(0.43, 0.9, 0.86, 0.35), 3)
		_text(Catalog.table("maps")[portal.to].name, p - Vector2(0, 105), Color("e1faff"), 18)
		_text("↑  前往", p - Vector2(0, 80), Color("fff2ce"), 14)
	for npc in map.npcs:
		var p = point(float(npc.x), float(npc.y))
		var path: String = art.npc.get(npc.id, "")
		if path != "":
			var tex = texture(path)
			draw_texture_rect(tex, Rect2(p - Vector2(35, 95), Vector2(70, 95)), false)
		_text(npc.name, p - Vector2(0, 115), Color("f9dfa1"), 18)
		_text(npc.role, p - Vector2(0, 95), Color("fff4dc"), 13)
	for drop in state.get("drops", []):
		var p = point(float(drop.x), float(drop.y)) - Vector2(0, 12 + sin(age * 3) * 3)
		var mine = drop.owner == Session.player_id
		draw_circle(p, 8, Color("f4ce77") if mine else Color("809e9e"))
		draw_circle(p, 14, Color(1, 0.8, 0.4, 0.15))
		_text(Catalog.table("items")[drop.item].name, p - Vector2(0, 20), Color("fff0ae") if mine else Color("bccccc"), 13)
	var actors: Array = state.get("players", []) + state.get("monsters", [])
	if preview:
		actors = [{"id": "preview_js", "job": "JS", "name": "剑侍", "x": 410.0, "y": 600.0, "facing": 1, "hp": 1, "max_hp": 1},
			{"id": "preview_xs", "job": "XS", "name": "仙术士", "x": 520.0, "y": 600.0, "facing": -1, "hp": 1, "max_hp": 1}]
	for actor in actors:
		_draw_actor(actor)
	for effect_data in effects:
		if effect_data.kind == "cast":
			_draw_cast(effect_data)
			continue
		var pos: Vector2 = point(effect_data.position.x, effect_data.position.y - 100) - Vector2(0, (1.0 - float(effect_data.life)) * 65)
		var color = Color("94ffd0") if effect_data.kind == "heal" else Color("ffde8b") if effect_data.kind == "critical" else Color.WHITE
		color.a = minf(1, float(effect_data.life) * 2)
		var text = "+%s" % effect_data.amount if effect_data.kind == "heal" else str(effect_data.amount)
		if effect_data.kind == "level": text = "升级！ Lv.%s" % effect_data.amount
		_text(text, pos, color, 24 if effect_data.kind == "critical" else 19)

func _draw_actor(actor: Dictionary) -> void:
	var position = Vector2(float(actor.x), float(actor.y))
	if actor.id == Session.player_id and not predicted.is_empty():
		position = Vector2(float(predicted.x), float(predicted.y))
	elif not preview:
		var old: Vector2 = smooth.get(actor.id, position)
		position = position if old.distance_to(position) > 300 else old.lerp(position, 0.35)
		smooth[actor.id] = position
	var p = point(position.x, position.y)
	if p.x < -150 or p.x > 1430: return
	var animation = "idle"
	var time: float = float(state.get("time", age)) + minf(age - snapshot_age, 0.25)
	if actor.get("dead", false): animation = "dead"
	elif float(actor.get("anim_until", 0)) > time: animation = "attack"
	elif float(actor.get("hurt_until", 0)) > time: animation = "hurt"
	elif actor.get("climbing", false): animation = "climb"
	elif not actor.get("grounded", true): animation = "jump"
	elif actor.get("moving", false): animation = "run"
	var kind: String = actor.get("kind", "js")
	var facing = float(actor.get("facing", 1))
	var chosen = actor.id == selected
	var monster = actor.has("kind")
	var death_age = maxf(0, time - float(actor.get("death_started", 0)))
	if monster and actor.get("dead", false) and death_age >= 1.2: return
	var tint = Color.WHITE
	if actor.get("dead", false) and monster: tint.a = clampf((1.2 - death_age) / 0.5, 0, 1)
	elif float(actor.get("hurt_until", 0)) > time: tint = Color(1.0, 0.5, 0.5)
	var phase = maxf(0, time - float(actor.get("anim_started", 0)))
	if animation == "dead": phase = death_age
	draw_set_transform(p, 0, Vector2(1, 0.3))
	draw_circle(Vector2.ZERO, 29 if kind != "boss" else 55, Color(0.05, 0.1, 0.1, 0.3))
	if chosen: draw_arc(Vector2.ZERO, 35, 0, TAU, 50, Color("f5d791"), 3)
	draw_set_transform(Vector2.ZERO)
	if actor.get("job", "") == "XS":
		var idx = mini(3, int(phase / 0.4 * 4)) if animation == "attack" else int(age * (10 if animation == "run" else 5)) % 4
		var row = 0 if animation == "idle" else 1 if animation == "run" else 2 if animation == "attack" else 3
		if row == 3: idx = {"jump": 0, "climb": 1, "hurt": 2, "dead": 3}.get(animation, 0)
		var cell = sheet.get_size() / 4.0
		draw_set_transform(p, 0, Vector2(facing, 1))
		draw_texture_rect_region(sheet, Rect2(-62, -118, 124, 124), Rect2(Vector2(idx, row) * cell, cell), tint)
	else:
		var frames: Array = art[kind].get(animation, art[kind].get("idle", []))
		if not frames.is_empty():
			var frame = int(age * 8) % frames.size()
			if animation == "attack": frame = mini(frames.size() - 1, int(phase / maxf(0.1, float(actor.anim_until) - float(actor.get("anim_started", 0))) * frames.size()))
			elif animation == "dead": frame = mini(frames.size() - 1, int(phase / 0.7 * frames.size()))
			var tex = texture(frames[frame])
			draw_set_transform(p, 0, Vector2(facing, 1))
			if kind == "js":
				draw_texture_rect(tex, Rect2(-90, -138, 180, 180), false, tint)
			else:
				var height = 140.0 if kind == "boss" else 70.0 if kind == "snake" else 85.0
				var size = tex.get_size() * (height / tex.get_height())
				draw_texture_rect(tex, Rect2(Vector2(-size.x / 2, -size.y), size), false, tint)
	draw_set_transform(Vector2.ZERO)
	var label_height = 170 if kind == "boss" else 130 if not monster else 110
	_text(actor.name, p - Vector2(0, label_height), Color("ffda99") if monster else Color("fff9df"), 17)
	var health = float(actor.get("hp", 0)) / maxf(1, float(actor.get("max_hp", 1)))
	var rect = Rect2(p - Vector2(30, label_height - 8), Vector2(60, 5))
	draw_style_box(_health_background(), rect)
	draw_rect(Rect2(rect.position, Vector2(60 * health, 5)), Color("d6664f") if monster else Color("76bd99"))
	if float(actor.get("windup", 0)) > time:
		var radius = float(actor.get("attack_range", 85))
		var progress = clampf((time - float(actor.get("windup_started", time))) / maxf(0.01, float(actor.windup) - float(actor.get("windup_started", time))), 0, 1)
		draw_rect(Rect2(p - Vector2(radius, 70), Vector2(radius * 2, 140)), Color(1, 0.25, 0.1, 0.08 + progress * 0.15))
		draw_line(p - Vector2(radius, 0), p + Vector2(radius, 0), Color(1, 0.35, 0.15), 4)
		draw_line(p - Vector2(radius, 0), p + Vector2(-radius + radius * 2 * progress, 0), Color("ffe4a0"), 6)
	if actor.get("dead", false): _text("已倒下", p - Vector2(0, 145), Color("eead9c"), 18)

func _health_background() -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = Color(0.04, 0.08, 0.08, 0.7)
	box.set_corner_radius_all(3)
	return box

func _text(text: String, pos: Vector2, color: Color, size: int) -> void:
	var width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at = pos - Vector2(width / 2, 0)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color(0.1, 0.12, 0.12, 0.8))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func click(screen: Vector2) -> void:
	var pos = screen + Vector2(camera_x, camera_y)
	for npc in Catalog.table("maps")[state.get("map", "bajun")].npcs:
		if pos.distance_to(Vector2(float(npc.x), float(npc.y) - 50)) < 65:
			npc_clicked.emit(npc.id)
			return
	for actor in state.get("players", []) + state.get("monsters", []):
		if not actor.get("dead", false) and pos.distance_to(Vector2(float(actor.x), float(actor.y) - 45)) < 70:
			entity_clicked.emit(actor.id)
			return

func _draw_cast(effect_data: Dictionary) -> void:
	var center = point(effect_data.position.x, effect_data.position.y - 55)
	var progress = 1.0 - float(effect_data.life)
	var skill: String = effect_data.skill
	var color = Color("8debc1") if skill in ["heal", "renew"] else Color("a1ddff") if skill == "bolt" else Color("ef9579") if skill == "blood" else Color("f5d791")
	color.a = float(effect_data.life)
	if skill in ["heal", "renew"]:
		draw_arc(center, 25 + progress * 55, 0, TAU, 48, color, 3)
		draw_line(center - Vector2(0, 18), center + Vector2(0, 18), color, 5)
		draw_line(center - Vector2(18, 0), center + Vector2(18, 0), color, 5)
	elif skill == "bolt":
		for i in range(3): draw_line(center + Vector2(i * 14 - 14, -65 + progress * 40), center + Vector2(i * 14 - 14, 30 + progress * 40), color, 4)
	else:
		draw_arc(center, 35 + progress * (80 if skill == "wind" else 45), -PI * 0.8 + progress, PI * 0.3 + progress, 32, color, 5)
