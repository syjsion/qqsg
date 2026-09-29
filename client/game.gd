extends Control

const GOLD = Color("e6c58a")
const CREAM = Color("f1ebdb")
var world: WorldView
var canvas: Control
var hud: Control
var lobby: PanelContainer
var modal: PanelContainer
var modal_body: VBoxContainer
var modal_kind = ""
var status: Label
var title: Label
var vitals: Label
var hp: ProgressBar
var mp: ProgressBar
var xp: ProgressBar
var track: Label
var chat_log: RichTextLabel
var chat_input: LineEdit
var server_input: LineEdit
var port_input: SpinBox
var name_input: LineEdit
var profile_input: LineEdit
var class_input: OptionButton
var connect_button: Button
var skill_buttons: Array[Button] = []
var target_label: Label
var notice: Label
var dead_button: Button
var cancel_retry: Button
var bgm: AudioStreamPlayer
var sfx: AudioStreamPlayer
var selected = ""
var predicted: Dictionary = {}
var pending_inputs: Array[Dictionary] = []
var keys: Dictionary = {"left": KEY_LEFT, "right": KEY_RIGHT, "up": KEY_UP, "down": KEY_DOWN,
	"jump": KEY_SPACE, "attack": KEY_A, "skill1": KEY_S, "skill2": KEY_D, "pickup": KEY_C,
	"target": KEY_TAB, "bag": KEY_B, "quests": KEY_Q, "team": KEY_T, "interact": KEY_E}
var rebinding = ""
var modal_revision = -1
var shot_timer = 0.0
var portal_delay = 0.0
var team_signature = ""

func _ready() -> void:
	Catalog.load_data()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_load_settings()
	_theme()
	canvas = Control.new()
	canvas.position = Vector2(0, 84)
	canvas.size = Vector2(1280, 584)
	canvas.clip_contents = true
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(canvas)
	world = WorldView.new()
	canvas.add_child(world)
	canvas.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			world.click(event.position))
	world.entity_clicked.connect(func(id): selected = id; world.selected = id)
	world.npc_clicked.connect(func(id): _open_panel("quests" if id == "guide" else "shop"))
	_build_hud()
	_build_lobby()
	Session.reconnecting.connect(_reconnecting)
	Session.connected.connect(_connected)
	Session.failed.connect(_failed)
	Session.snapshot_received.connect(_snapshot)
	Session.result_received.connect(_result)
	Session.event_received.connect(_event)
	Session.chat_received.connect(func(who, message): chat_log.add_text("%s：%s\n" % [who, message]))
	bgm = AudioStreamPlayer.new()
	bgm.stream = load(world.art.music)
	bgm.volume_db = -22
	bgm.finished.connect(func(): bgm.play())
	add_child(bgm)
	if DisplayServer.get_name() != "headless": bgm.play()
	sfx = AudioStreamPlayer.new()
	sfx.volume_db = -15
	add_child(sfx)
	var args = Session.arguments()
	if args.has("profile"): profile_input.text = args.profile
	if args.has("name"): name_input.text = args.name
	if args.get("job", "JS") == "XS": class_input.select(1)
	if args.has("connect"):
		server_input.text = args.connect
		port_input.value = int(args.get("port", "24567"))
		_connect()

func _theme() -> void:
	var t = Theme.new()
	var art = JSON.parse_string(FileAccess.get_file_as_string("res://data/art.json"))
	t.default_font = load(art.font)
	t.default_font_size = 16
	t.set_color("font_color", "Label", CREAM)
	t.set_color("font_color", "Button", CREAM)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color("7f8b86"))
	t.set_stylebox("normal", "Button", _box(Color("253b3b"), Color("64715c"), 5))
	t.set_stylebox("hover", "Button", _box(Color("355953"), GOLD, 5))
	t.set_stylebox("pressed", "Button", _box(Color("182e2c"), GOLD, 5))
	t.set_stylebox("disabled", "Button", _box(Color("23302e"), Color("3f5047"), 5))
	t.set_stylebox("focus", "Button", _box(Color(0,0,0,0), GOLD, 5))
	t.set_stylebox("normal", "LineEdit", _box(Color("112825"), Color("5b705f"), 4))
	t.set_color("font_color", "LineEdit", CREAM)
	t.set_color("font_placeholder_color", "LineEdit", Color("8eaaa0"))
	t.set_stylebox("panel", "PanelContainer", _box(Color("182e2e"), Color("8f8968"), 7))
	t.set_stylebox("background", "ProgressBar", _box(Color("101d1e"), Color("47534a"), 2))
	t.set_stylebox("fill", "ProgressBar", _box(Color("6aa389"), Color("86b29a"), 2))
	t.set_constant("separation", "VBoxContainer", 10)
	t.set_constant("separation", "HBoxContainer", 10)
	theme = t

func _box(color: Color, border: Color, radius: int) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box

func _label(text: String, size_px: int = 16, color: Color = CREAM) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	return l

func _button(text: String, callback: Callable, minimum: Vector2 = Vector2(0, 38)) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = minimum
	b.pressed.connect(callback)
	b.focus_mode = Control.FOCUS_NONE
	return b

func _panel(rect: Rect2, parent: Node = self) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.position = rect.position
	panel.size = rect.size
	parent.add_child(panel)
	return panel

func _build_hud() -> void:
	var top = _panel(Rect2(0, 0, 1280, 84))
	var row = HBoxContainer.new()
	top.add_child(row)
	var brand = VBoxContainer.new()
	brand.custom_minimum_size.x = 260
	row.add_child(brand)
	brand.add_child(_label("三国 · 同游", 27, GOLD))
	brand.add_child(_label("局域网合作篇章  /  0.1", 12, Color("9eb8ac")))
	title = _label("巴郡  ·  故人相聚", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	row.add_child(_button("键位 / 声音", func(): _open_panel("settings")))
	row.add_child(_button("返回登录", func(): Session.disconnect_game(); lobby.show(); hud.hide(); world.preview = true; predicted.clear(); world.predicted.clear(); _close_panel()))
	var footer = _panel(Rect2(0, 668, 1280, 132))
	var frow = HBoxContainer.new()
	footer.add_child(frow)
	var hint = VBoxContainer.new()
	hint.custom_minimum_size.x = 275
	frow.add_child(hint)
	hint.add_child(_label("同行，是最好的江湖。", 20, GOLD))
	hint.add_child(_label("方向键移动 · 空格跳跃 · E 交谈\nTab 选敌 · C 拾取 · ↑ 传送", 13, Color("b2c3b5")))
	var hotbar = HBoxContainer.new()
	frow.add_child(hotbar)
	for i in range(3):
		var b = _button("%s\n技能" % ["A", "S", "D"][i], func(): _cast(i), Vector2(116, 72))
		hotbar.add_child(b)
		skill_buttons.append(b)
	hotbar.add_child(_button("1\n金疮药", func(): Session.request("use", {"item": "potion"}), Vector2(95, 72)))
	hotbar.add_child(_button("2\n清心露", func(): Session.request("use", {"item": "ether"}), Vector2(95, 72)))
	var tools = GridContainer.new()
	tools.columns = 2
	tools.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frow.add_child(tools)
	for entry in [["行囊 B", "bag"], ["任务 Q", "quests"], ["同伴 T", "team"], ["商店", "shop"]]:
		tools.add_child(_button(entry[0], _open_panel.bind(entry[1]), Vector2(100, 36)))
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	var stats_panel = _panel(Rect2(20, 100, 300, 128), hud)
	var stats_col = VBoxContainer.new()
	stats_col.add_theme_constant_override("separation", 3)
	stats_panel.add_child(stats_col)
	vitals = _label("", 16, GOLD)
	stats_col.add_child(vitals)
	hp = _bar(Color("b95e53")); stats_col.add_child(hp)
	mp = _bar(Color("527f9c")); stats_col.add_child(mp)
	xp = _bar(Color("b19b61")); stats_col.add_child(xp)
	var tracker = _panel(Rect2(984, 100, 276, 148), hud)
	track = _label("", 15)
	track.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tracker.add_child(track)
	target_label = _label("点击角色或按 Tab 选择目标", 15, GOLD)
	target_label.position = Vector2(390, 100)
	hud.add_child(target_label)
	var chat_panel = _panel(Rect2(20, 510, 350, 144), hud)
	var chat_col = VBoxContainer.new()
	chat_panel.add_child(chat_col)
	chat_log = RichTextLabel.new()
	chat_log.custom_minimum_size.y = 75
	chat_log.bbcode_enabled = false
	chat_log.scroll_following = true
	chat_log.add_theme_font_size_override("normal_font_size", 13)
	chat_col.add_child(chat_log)
	chat_input = LineEdit.new()
	chat_input.placeholder_text = "Enter 聊天，最多 160 字"
	chat_input.max_length = 160
	chat_col.add_child(chat_input)
	chat_input.text_submitted.connect(func(text): Session.send_chat(text); chat_input.clear(); chat_input.release_focus())
	dead_button = _button("已倒下 · 回巴郡复活", func(): Session.request("respawn"), Vector2(250, 50))
	dead_button.position = Vector2(515, 420)
	hud.add_child(dead_button)
	dead_button.hide()
	notice = _label("", 17, GOLD)
	notice.position = Vector2(395, 620)
	hud.add_child(notice)
	hud.hide()

func _bar(color: Color) -> ProgressBar:
	var b = ProgressBar.new()
	b.custom_minimum_size = Vector2(274, 20)
	b.show_percentage = false
	b.add_theme_stylebox_override("fill", _box(color, color.lightened(0.2), 2))
	var value_label = _label("", 13, Color.WHITE)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(value_label)
	return b

func _build_lobby() -> void:
	lobby = _panel(Rect2(850, 175, 390, 437))
	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	lobby.add_child(col)
	col.add_child(_label("与室友，再入三国", 26, GOLD))
	col.add_child(_label("连接同一局域网中的常驻服务器", 14, Color("a8bcae")))
	var row = HBoxContainer.new()
	col.add_child(row)
	server_input = LineEdit.new()
	server_input.text = "127.0.0.1"
	server_input.placeholder_text = "服务器 IP"
	server_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(server_input)
	port_input = SpinBox.new()
	port_input.min_value = 1024; port_input.max_value = 65535; port_input.value = 24567
	port_input.custom_minimum_size.x = 110
	row.add_child(port_input)
	name_input = LineEdit.new()
	name_input.placeholder_text = "初次加入：角色名（1–16 字）"
	name_input.text = "蜀地旅人"
	name_input.max_length = 16
	col.add_child(name_input)
	class_input = OptionButton.new()
	class_input.add_item("剑侍 · 近身剑术")
	class_input.add_item("仙术士 · 回春济世")
	class_input.custom_minimum_size.y = 38
	col.add_child(class_input)
	profile_input = LineEdit.new()
	profile_input.text = "default"
	profile_input.placeholder_text = "本地档案名（同一档案恢复原角色）"
	col.add_child(profile_input)
	connect_button = _button("启 程  →", _connect, Vector2(340, 48))
	col.add_child(connect_button)
	cancel_retry = _button("取消重连", func(): Session.disconnect_game(); _failed("已取消重连，可重新连接。"))
	col.add_child(cancel_retry)
	cancel_retry.hide()
	status = _label("已有角色会自动恢复。\n角色进度保存在服务器，本机保存登录凭据。", 13, Color("b1bfae"))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(status)

func _connect() -> void:
	status.text = "正在连接服务器……"
	connect_button.disabled = true
	Session.connect_game(server_input.text, int(port_input.value), name_input.text, "JS" if class_input.selected == 0 else "XS", profile_input.text.strip_edges())

func _connected() -> void:
	cancel_retry.hide()
	world.effects.clear()
	world.smooth.clear()
	lobby.hide()
	hud.show()
	world.preview = false
	connect_button.disabled = false
	pending_inputs.clear()
	selected = ""
	chat_log.add_text("已进入服务器。前往简雍处开始旅程。\n")

func _failed(message: String) -> void:
	cancel_retry.hide()
	pending_inputs.clear()
	status.text = message
	connect_button.disabled = false
	lobby.show()
	hud.hide()
	_close_panel()
	predicted.clear()
	world.predicted.clear()
	world.preview = true

func _reconnecting(message: String) -> void:
	_failed(message)
	connect_button.disabled = true
	cancel_retry.show()

func _snapshot(state: Dictionary) -> void:
	world.snapshot_age = world.age
	var changed_map = world.state.get("map", "") != state.map
	world.state = state
	predicted = state.self.duplicate(true)
	if changed_map:
		pending_inputs.clear()
		world.smooth.clear()
		selected = ""
		world.selected = ""
		_close_panel()
	pending_inputs = pending_inputs.filter(func(entry): return int(entry.seq) > int(state.ack))
	for entry in pending_inputs:
		MovementRules.step(predicted, entry.axis, entry.jump, 1.0 / 60.0, Catalog.table("maps")[state.map])
	world.predicted = predicted
	_update_hud(state)
	var signature = str(state.invite)
	for member in state.roster: signature += member.id + member.party + member.map
	if modal and modal_kind in ["bag", "quests", "shop", "team"] and (int(state.self.revision) != modal_revision or (modal_kind == "team" and team_signature != signature)):
		_refresh_panel()
	team_signature = signature

func _update_hud(state: Dictionary) -> void:
	var p: Dictionary = state.self
	var map: Dictionary = Catalog.table("maps")[state.map]
	title.text = "%s   ·   %s" % [map.name, map.subtitle]
	vitals.text = "%s  ·  %s  Lv.%d" % [p.name, Catalog.table("classes")[p.job].name, p.level]
	hp.max_value = p.stats.hp; hp.value = p.hp; hp.tooltip_text = "生命 %d / %d" % [p.hp, p.stats.hp]
	mp.max_value = p.stats.mp; mp.value = p.mp; mp.tooltip_text = "体力 %d / %d" % [p.mp, p.stats.mp]
	xp.max_value = p.next_xp; xp.value = p.xp; xp.tooltip_text = "经验 %d / %d" % [p.xp, p.next_xp]
	for bar in [hp, mp, xp]: bar.get_child(0).text = bar.tooltip_text
	var skill_ids: Array = Catalog.table("classes")[p.job].skills
	for i in range(3):
		var skill: Dictionary = Catalog.table("skills")[skill_ids[i]]
		var cooldown = float(p.cooldowns.get(skill_ids[i], 0))
		var binding: String = ["attack", "skill1", "skill2"][i]
		skill_buttons[i].text = "%s  %s\n%s" % [OS.get_keycode_string(keys[binding]), skill.name, "%.1fs" % cooldown if cooldown > 0 else "体力 %d" % skill.cost]
		skill_buttons[i].disabled = p.dead or p.level < skill.level
		skill_buttons[i].tooltip_text = "解锁等级 %d · 距离 %d · 冷却 %.1fs" % [skill.level, skill.range, skill.cooldown]
	track.text = "旅途记事\n"
	var found = false
	for id in Catalog.table("quests"):
		var q: Dictionary = Catalog.table("quests")[id]
		var progress: Dictionary = p.quests.get(id, {})
		if progress.get("state", "") == "active":
			var count = p.inventory.get(q.target, 0) if q.type == "collect" else progress.progress
			track.text += "%s  %d/%d\n%s" % [q.name, mini(count, q.count), q.count, q.description]
			found = true
			break
	if not found: track.text += "与巴郡的简雍交谈\n领取或交付旅途任务。"
	if not state.invite.is_empty(): track.text += "\n收到组队邀请，按 T 查看。"
	dead_button.visible = p.dead
	target_label.text = "目标：未选择"
	for actor in state.players + state.monsters:
		if actor.id == selected: target_label.text = "目标：%s   %s / %s" % [actor.name, int(actor.hp), actor.max_hp]

func _physics_process(dt: float) -> void:
	portal_delay = maxf(0, portal_delay - dt)
	if not Session.welcomed or predicted.is_empty(): return
	var axis = Vector2.ZERO
	var jump = false
	if not _typing() and modal == null:
		axis = Vector2(float(Input.is_physical_key_pressed(keys.right)) - float(Input.is_physical_key_pressed(keys.left)), float(Input.is_physical_key_pressed(keys.down)) - float(Input.is_physical_key_pressed(keys.up)))
		jump = Input.is_action_just_pressed("jump_local")
	var sequence = Session.send_input(axis, jump)
	pending_inputs.append({"seq": sequence, "axis": axis, "jump": jump})
	if pending_inputs.size() > 120: pending_inputs.pop_front()
	MovementRules.step(predicted, axis, jump, dt, Catalog.table("maps")[Session.latest.map])
	world.predicted = predicted
	if axis.y < 0 and portal_delay <= 0:
		for portal in Catalog.table("maps")[Session.latest.map].portals:
			if absf(float(predicted.x) - float(portal.x)) < 85 and absf(float(predicted.y) - float(portal.y)) < 60:
				Session.request("portal")
				portal_delay = 1.0
				break

func _typing() -> bool:
	return get_viewport().gui_get_focus_owner() is LineEdit

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if rebinding != "":
		if event.keycode == KEY_ESCAPE:
			rebinding = ""
		else:
			keys[rebinding] = event.physical_keycode
			rebinding = ""
			_save_settings()
			_bind_jump()
		_refresh_panel()
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_ESCAPE:
		_close_panel()
		chat_input.release_focus()
		return
	if _typing(): return
	if not Session.welcomed: return
	var key = event.physical_keycode
	if key == KEY_ENTER:
		chat_input.grab_focus()
		get_viewport().set_input_as_handled()
	elif key == keys.bag: _open_panel("bag")
	elif key == keys.quests: _open_panel("quests")
	elif key == keys.team: _open_panel("team")
	elif modal != null: return
	elif key == keys.attack: _cast(0)
	elif key == keys.skill1: _cast(1)
	elif key == keys.skill2: _cast(2)
	elif key == keys.target: _cycle_target()
	elif key == keys.pickup: _pickup()
	elif key == KEY_1: Session.request("use", {"item": "potion"})
	elif key == KEY_2: Session.request("use", {"item": "ether"})
	elif key == keys.interact:
		for npc in Catalog.table("maps")[Session.latest.map].npcs:
			if absf(float(predicted.x) - float(npc.x)) < 150:
				_open_panel("quests" if npc.id == "guide" else "shop")
				break

func _cast(index: int) -> void:
	if Session.latest.is_empty(): return
	var skill: String = Catalog.table("classes")[Session.latest.self.job].skills[index]
	var target = selected
	if Catalog.table("skills")[skill].type == "heal":
		if not Session.latest.roster.any(func(p): return p.id == target): target = Session.player_id
	elif not Session.latest.monsters.any(func(m): return m.id == target and not m.dead):
		_cycle_target()
		target = selected
	Session.request("skill", {"skill": skill, "target": target})

func _cycle_target() -> void:
	var enemies: Array = Session.latest.get("monsters", []).filter(func(m): return not m.dead)
	enemies.sort_custom(func(a, b): return absf(float(a.x) - float(predicted.x)) < absf(float(b.x) - float(predicted.x)))
	if enemies.is_empty(): return
	var index = -1
	for i in range(enemies.size()):
		if enemies[i].id == selected: index = i
	selected = enemies[(index + 1) % enemies.size()].id
	world.selected = selected

func _pickup() -> void:
	var loot: Array = Session.latest.get("drops", []).filter(func(d): return d.owner == Session.player_id)
	loot.sort_custom(func(a, b): return absf(float(a.x) - float(predicted.x)) < absf(float(b.x) - float(predicted.x)))
	if loot.is_empty(): _toast("附近没有属于你的掉落"); return
	Session.request("pickup", {"drop": loot[0].id})

func _result(result: Dictionary) -> void:
	if not result.ok: _toast(result.message)

func _event(event: Dictionary) -> void:
	world.effect(event)
	if event.kind == "notice": _toast(event.text)
	if event.kind == "cast":
		sfx.stream = load(world.art.cast if event.text in ["heal", "renew"] else world.art.hit)
		sfx.play()

func _toast(message: String) -> void:
	notice.text = message
	get_tree().create_timer(3).timeout.connect(func():
		if notice.text == message: notice.text = "")

func _open_panel(kind: String) -> void:
	if kind != "settings" and Session.latest.is_empty(): return
	if modal != null and modal_kind == kind:
		_close_panel()
		return
	_close_panel()
	modal_kind = kind
	modal = _panel(Rect2(380, 155, 520, 450))
	var col = VBoxContainer.new()
	modal.add_child(col)
	var row = HBoxContainer.new()
	col.add_child(row)
	var caption = _label({"bag":"行囊与装备", "quests":"旅途任务 · 简雍", "shop":"巴郡商店", "team":"同游伙伴", "settings":"键位与声音"}[kind], 23, GOLD)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(caption)
	row.add_child(_button("关闭 ×", _close_panel))
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(490, 365)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	modal_body = VBoxContainer.new()
	modal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(modal_body)
	_refresh_panel()

func _close_panel() -> void:
	if modal:
		modal.queue_free()
		modal = null
	modal_kind = ""
	rebinding = ""

func _row(text: String, button_text: String, action: Callable) -> HBoxContainer:
	var row = HBoxContainer.new()
	var label = _label(text, 15)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 275
	row.add_child(label)
	row.add_child(_button(button_text, action))
	modal_body.add_child(row)
	return row

func _refresh_panel() -> void:
	if not modal: return
	for child in modal_body.get_children():
		modal_body.remove_child(child)
		child.queue_free()
	if modal_kind == "settings":
		modal_body.add_child(_label("点击按键后按下新键；Esc 取消。", 14))
		for action in keys:
			var names = {"left":"向左", "right":"向右", "up":"向上 / 传送", "down":"向下", "jump":"跳跃", "attack":"普攻", "skill1":"技能一", "skill2":"技能二", "pickup":"拾取", "target":"切换目标", "bag":"背包", "quests":"任务", "team":"队伍", "interact":"交谈"}
			_row(names[action], "请按新键…" if rebinding == action else OS.get_keycode_string(keys[action]), func(): rebinding = action; _refresh_panel())
		var mute = CheckButton.new()
		mute.text = "静音"
		mute.button_pressed = AudioServer.is_bus_mute(0)
		mute.toggled.connect(func(value): AudioServer.set_bus_mute(0, value); _save_settings())
		modal_body.add_child(mute)
		return
	var p: Dictionary = Session.latest.self
	modal_revision = int(p.revision)
	match modal_kind:
		"bag":
			modal_body.add_child(_label("金钱 %d  ·  行囊 %d / 24 格" % [p.money, InventoryRules.slots(p.inventory)], 16, GOLD))
			for slot in p.equipment:
				modal_body.add_child(_label("已装备  %s" % Catalog.table("items")[p.equipment[slot]].name, 14, Color("9bd4bb")))
			modal_body.add_child(_label("物攻 %s · 法攻 %s · 防御 %s" % [p.stats.physical_attack, p.stats.magic_attack, p.stats.defense], 14))
			for id in p.inventory:
				var item: Dictionary = Catalog.table("items")[id]
				var op = "equip" if item.has("slot") else "use" if id in ["potion", "ether"] else ""
				if op != "": _row("%s × %s" % [item.name, p.inventory[id]], "装备" if op == "equip" else "使用", func(): Session.request(op, {"item": id}))
				else: modal_body.add_child(_label("%s × %s  ·  任务材料" % [item.name, p.inventory[id]], 15))
		"quests":
			modal_body.add_child(_label("领取、交付需要靠近巴郡简雍。", 14, Color("b2c3b5")))
			for id in Catalog.table("quests"):
				var q: Dictionary = Catalog.table("quests")[id]
				var s: Dictionary = p.quests.get(id, {})
				var progress = int(p.inventory.get(q.target, 0)) if q.type == "collect" else int(s.get("progress", 0))
				var label = "%s  %d/%d\n%s\n奖励 %d 经验 / %d 金钱" % [q.name, mini(progress, q.count), q.count, q.description, q.xp, q.money]
				var row = _row(label, "已完成" if s.get("state", "") == "done" else "交付" if not s.is_empty() else "领取", func(): Session.request("quest", {"quest": id}))
				row.get_child(1).disabled = s.get("state", "") == "done" or (q.previous != "" and p.quests.get(q.previous, {}).get("state", "") != "done")
		"shop":
			modal_body.add_child(_label("金钱 %d · 交易需要靠近装备商人" % p.money, 15, GOLD))
			for id in Catalog.table("items"):
				var item: Dictionary = Catalog.table("items")[id]
				if id not in ["herb", "seal"]:
					_row("%s   %s 金钱" % [item.name, item.price], "购买", func(): Session.request("buy", {"item": id}))
			modal_body.add_child(_label("出售行囊物品（每次 1 件）", 16, GOLD))
			for id in p.inventory:
				_row("%s × %s" % [Catalog.table("items")[id].name, p.inventory[id]], "出售", func(): Session.request("sell", {"item": id}))
		"team":
			modal_body.add_child(_label("同图附近队友共享击杀；掉落轮流归属。", 14))
			if not Session.latest.invite.is_empty():
				_row("收到组队邀请", "接受", func(): Session.request("accept"))
			for actor in Session.latest.roster:
				var same = actor.id == p.id or (p.party != "" and actor.party == p.party)
				var row = _row("%s  Lv.%s  %s\n生命 %s / %s · %s" % [actor.name, actor.level, Catalog.table("classes")[actor.job].name, int(actor.hp), actor.max_hp, Catalog.table("maps")[actor.map].name], "选择治疗" if same else "邀请", func():
					if same: selected = actor.id; world.selected = selected; _close_panel()
					else: Session.request("invite", {"target": actor.id}))
				row.tooltip_text = "点击选择治疗目标" if same else "邀请加入队伍"
			if p.party != "": modal_body.add_child(_button("离开队伍", func(): Session.request("leave_party")))

func _bind_jump() -> void:
	if not InputMap.has_action("jump_local"): InputMap.add_action("jump_local")
	InputMap.action_erase_events("jump_local")
	var e = InputEventKey.new()
	e.physical_keycode = int(keys.jump)
	InputMap.action_add_event("jump_local", e)

func _load_settings() -> void:
	var settings = ConfigFile.new()
	if settings.load("user://settings.cfg") == OK:
		for action in keys: keys[action] = int(settings.get_value("keys", action, keys[action]))
		AudioServer.set_bus_mute(0, bool(settings.get_value("audio", "muted", false)))
	_bind_jump()

func _save_settings() -> void:
	var settings = ConfigFile.new()
	for action in keys: settings.set_value("keys", action, keys[action])
	settings.set_value("audio", "muted", AudioServer.is_bus_mute(0))
	settings.save("user://settings.cfg")

func _exit_tree() -> void:
	if bgm: bgm.stop()
	if sfx: sfx.stop()
