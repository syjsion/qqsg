extends Control

const GOLD = Color("e6c58a")
const CREAM = Color("f1ebdb")
var interface: GameInterface
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
var enhance_selected = ""
var enhance_pending = 0
var enhance_message = ""
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
	interface = GameInterface.new()
	add_child(interface)
	interface.setup(self)
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
	if args.get("job", "JS") == "XS": interface._choose_job("XS")
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
	t.set_stylebox("panel", "PanelContainer", UIArt.frame())
	t.set_stylebox("panel", "PopupMenu", UIArt.frame(12))
	t.set_stylebox("normal", "Button", UIArt.button_style())
	t.set_stylebox("hover", "Button", UIArt.button_style(Color("c6e5a4")))
	t.set_stylebox("pressed", "Button", UIArt.button_style(Color("99b7a0")))
	t.set_stylebox("disabled", "Button", UIArt.button_style(Color("6d7975")))
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
	interface.build_hud()

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
	interface.build_lobby()

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
	enhance_pending = 0
	interface.pending = 0
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
	if modal and modal_kind in ["bag", "quests", "shop", "team", "enhance"] and (int(state.self.revision) != modal_revision or (modal_kind == "team" and team_signature != signature)):
		_refresh_panel()
	team_signature = signature

func _update_hud(state: Dictionary) -> void:
	var p: Dictionary = state.self
	var map: Dictionary = Catalog.table("maps")[state.map]
	title.text = "%s   ·   %s" % [map.name, map.subtitle]
	vitals.text = "%s  ·  %s  Lv.%d" % [p.name, Catalog.table("classes")[p.job].name, p.level]
	vitals.tooltip_text = vitals.text
	hp.max_value = p.stats.hp; hp.value = p.hp; hp.tooltip_text = "生命 %d / %d" % [p.hp, p.stats.hp]
	mp.max_value = p.stats.mp; mp.value = p.mp; mp.tooltip_text = "体力 %d / %d" % [p.mp, p.stats.mp]
	xp.max_value = p.next_xp; xp.value = p.xp; xp.tooltip_text = "经验 %d / %d" % [p.xp, p.next_xp]
	for bar in [hp, mp, xp]: bar.get_child(0).text = bar.tooltip_text
	track.text = ""
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
	interface.update_hud(state)

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
	elif key == KEY_1: interface.send("use", {"item": "potion"})
	elif key == KEY_2: interface.send("use", {"item": "ether"})
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
	if enhance_pending > 0 and int(result.get("seq", 0)) == enhance_pending:
		enhance_pending = 0
		if result.ok and not result.get("enhancement", {}).is_empty():
			var outcome: Dictionary = result.enhancement
			enhance_message = "强化成功！当前 +%d" % outcome.level if outcome.enhanced else "强化未成功，等级不变。连续失败 %d/3，材料和金钱已消耗。" % outcome.failures
		else: enhance_message = str(result.get("message", "强化失败"))
	interface.result_received(result)
	if not result.ok: _toast(result.message)

func _event(event: Dictionary) -> void:
	world.effect(event)
	if event.kind == "notice": _toast(event.text)
	if event.kind == "cast":
		sfx.stream = load(world.art.cast if event.text in ["heal", "renew"] else world.art.hit)
		sfx.play()

func _toast(message: String) -> void:
	notice.text = message
	hud.get_node("NoticePanel").show()
	get_tree().create_timer(3).timeout.connect(func():
		if notice.text == message:
			notice.text = ""
			hud.get_node("NoticePanel").hide())

func _open_panel(kind: String) -> void:
	if kind != "settings" and Session.latest.is_empty(): return
	if modal != null and modal_kind == kind:
		_close_panel()
		return
	_close_panel()
	interface.open(kind)

func _close_panel() -> void:
	interface.close()
	if modal:
		modal.queue_free()
		modal = null
	modal_kind = ""
	rebinding = ""



func _refresh_panel() -> void:
	interface.refresh()

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
	if bgm:
		bgm.stop()
		bgm.stream = null
	if sfx:
		sfx.stop()
		sfx.stream = null

func _gear_description(gear: Dictionary) -> String:
	var item: Dictionary = Catalog.table("items")[gear.item]
	return "%s · %s · Lv.%d" % [GearRules.label(gear), "精良" if item.get("quality", "common") == "fine" else "普通", item.get("level",1)]

func _sell_gear(gid: String) -> void:
	interface.confirm_sell(gid)

func _gear_attributes(gear: Dictionary) -> String:
	var names = {"physical_attack":"物攻", "magic_attack":"法攻", "defense":"防御", "hp":"生命上限"}
	var parts: PackedStringArray = []
	var values = GearRules.stats(gear)
	for key in values: parts.append("%s +%d" % [names.get(key,key),values[key]])
	return " · ".join(parts)
