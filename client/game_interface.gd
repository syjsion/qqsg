class_name GameInterface
extends Control

var g
var choices: Dictionary = {}
var entries: Array[Dictionary] = []
var slots: Array[ItemSlot] = []
var detail: VBoxContainer
var popup: PopupMenu
var context_key = ""
var shop_mode = "buy"
var pending = 0
var request_sender: Callable
var scroll: ScrollContainer
var member_bars: Dictionary = {}
var portrait: TextureRect
var target_portrait: TextureRect
var target_hp: ProgressBar
var target_panel: PanelContainer
var potions: Array[ItemSlot] = []
var tracker_icon: TextureRect
var proximity_actions: Array[Dictionary] = []
var lobby_preview: TextureRect
var lobby_cards: Array[Button] = []
var movement_hint: Label
var window_scroll = 0
var companion_health: ProgressBar
var companion_hud_label: Label
var companion_hud_icon: TextureRect
var companion_tool_label: Label
var companion_detail_status: Label
var companion_actions: Array[Dictionary] = []
var confirmation: Control

func setup(game: Control) -> void:
	g = game
	get_viewport().gui_embed_subwindows = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	request_sender = func(action, payload): return Session.request(action, payload)
	popup = PopupMenu.new()
	popup.id_pressed.connect(_context_action)
	add_child(popup)

func label(text: String, px: int = 16, color: Color = Color("f6ebca")) -> Label:
	return g._label(text, px, color)

func button(text: String, callback: Callable, icon: String = "", minimum: Vector2 = Vector2(0,36)) -> Button:
	var node: Button = g._button(text, callback, minimum)
	if icon != "":
		node.icon = UIArt.texture("symbols", icon)
		node.expand_icon = true
		node.add_theme_constant_override("icon_max_width",24)
		node.custom_minimum_size.x = maxf(minimum.x,node.get_theme_font("font").get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x + 58)
	return node

func panel(rect: Rect2, parent: Node = null) -> PanelContainer:
	return g._panel(rect, g if parent == null else parent)

func column(parent: Node, width: float = 0) -> VBoxContainer:
	var node = VBoxContainer.new()
	node.custom_minimum_size.x = width
	node.add_theme_constant_override("separation",8)
	parent.add_child(node)
	return node

func row(parent: Node) -> HBoxContainer:
	var node = HBoxContainer.new()
	node.add_theme_constant_override("separation",10)
	parent.add_child(node)
	return node

func bar(parent: Node, color: Color, width: float = 200) -> ProgressBar:
	var node: ProgressBar = g._bar(color)
	node.custom_minimum_size = Vector2(width,19)
	parent.add_child(node)
	return node

func text_block(parent: Node, text: String, width: float, px: int = 15) -> Label:
	var node = label(text,px)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.custom_minimum_size.x = width
	parent.add_child(node)
	return node

func header(parent: Node, title: String, icon: String) -> void:
	var line = row(parent)
	line.add_child(UIArt.image("symbols",icon,Vector2(30,30)))
	line.add_child(label(title,20,Color("ffe29d")))

func money(parent: Node, amount: int, caption: String = "三国币") -> void:
	var line = row(parent)
	line.add_child(UIArt.image("items","money",Vector2(27,27)))
	line.add_child(label("%s  %d" % [caption,amount],16,Color("ffe29d")))

func build_hud() -> void:
	var top = row(panel(Rect2(0,0,1280,84)))
	top.add_child(UIArt.image("symbols","combat",Vector2(48,48)))
	var brand = column(top,215)
	brand.add_child(label("三国 · 同游",25,Color("ffe29d")))
	brand.add_child(label("局域网篇章  0.3.0",12))
	g.title = label("巴郡 · 故人相聚",20)
	g.title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(g.title)
	top.add_child(button("设置",func(): g._open_panel("settings"),"settings"))
	top.add_child(button("返回",func(): Session.disconnect_game(); g._failed("已退出，可重新启程。"),"door"))
	var footer = row(panel(Rect2(0,668,1280,132)))
	var hint = column(footer,260)
	header(hint,"巴郡同游","party")
	movement_hint = label(_hint_text(),13); hint.add_child(movement_hint)
	for i in range(3):
		var col = column(footer)
		var slot = ItemSlot.new()
		slot.custom_minimum_size = Vector2(66,66)
		slot.icon_group = "skills"
		slot.chosen.connect(func(_key): g._cast(i))
		col.add_child(slot)
		g.skill_buttons.append(slot)
		var caption = label("技能",12)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(caption)
	for id in ["potion","ether"]:
		var col = column(footer)
		var slot = ItemSlot.new()
		slot.custom_minimum_size = Vector2(66,66)
		slot.icon_id = id
		slot.key_hint = "1" if id == "potion" else "2"
		slot.chosen.connect(func(_key): send("use",{"item":id}))
		col.add_child(slot)
		col.add_child(label(Catalog.table("items")[id].name,12))
		potions.append(slot)
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	for entry in [["行囊 B","bag"],["任务 Q","quests"],["队伍 T","team"],["商店","shop"],["副将 G","companions"]]:
		var col = column(footer)
		var slot = ItemSlot.new()
		slot.icon_group = "symbols"
		slot.icon_id = entry[1]
		slot.tooltip_text = entry[0]
		slot.chosen.connect(func(_key): g._open_panel(entry[1]))
		col.add_child(slot)
		var tool_label = label(entry[0],12); col.add_child(tool_label)
		if entry[1] == "companions": companion_tool_label = tool_label
	g.hud = Control.new()
	g.hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	g.hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.add_child(g.hud)
	var stats = row(panel(Rect2(16,98,337,125),g.hud))
	portrait = UIArt.image("portraits","JS",Vector2(65,76))
	stats.add_child(portrait)
	var stats_col = column(stats,225)
	g.vitals = label("",14,Color("ffe29d")); stats_col.add_child(g.vitals)
	g.vitals.clip_text = true; g.vitals.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	g.hp = bar(stats_col,Color("c95b46"),225)
	g.mp = bar(stats_col,Color("428dab"),225)
	g.xp = bar(stats_col,Color("b7a348"),225)
	target_panel = panel(Rect2(424,98,290,100),g.hud)
	var target = row(target_panel)
	target_portrait = UIArt.image("portraits","snake",Vector2(56,56)); target.add_child(target_portrait)
	var tc = column(target,185)
	g.target_label = label("选择目标",14); tc.add_child(g.target_label)
	g.target_label.clip_text = true; g.target_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	target_hp = bar(tc,Color("c95b46"),185)
	target_panel.hide()
	var companion_card = row(panel(Rect2(724,98,254,125),g.hud))
	companion_hud_icon = UIArt.image("portraits","zhaoyun",Vector2(52,65)); companion_card.add_child(companion_hud_icon)
	var cc = column(companion_card,155)
	companion_hud_label = label("副将 · 尚未出战",13); cc.add_child(companion_hud_label)
	companion_health = bar(cc,Color("83ae6c"),155)
	cc.add_child(button("副将",func(): g._open_panel("companions"),"companions",Vector2(0,32)))
	var tracker = column(panel(Rect2(994,98,270,160),g.hud))
	var title_row = row(tracker)
	tracker_icon = UIArt.image("symbols","quests",Vector2(28,28)); title_row.add_child(tracker_icon)
	title_row.add_child(label("旅途任务",17,Color("ffe29d")))
	g.track = text_block(tracker,"",225,14)
	var chat = column(panel(Rect2(16,502,350,152),g.hud))
	g.chat_log = RichTextLabel.new()
	g.chat_log.custom_minimum_size.y = 70
	g.chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	g.chat_log.scroll_following = true
	g.chat_log.add_theme_font_size_override("normal_font_size",13)
	chat.add_child(g.chat_log)
	var input_row = row(chat)
	input_row.add_child(UIArt.image("symbols","party",Vector2(24,24)))
	g.chat_input = LineEdit.new()
	g.chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.chat_input.placeholder_text = "Enter 聊天 · 最多 160 字"
	g.chat_input.max_length = 160
	input_row.add_child(g.chat_input)
	g.chat_input.text_submitted.connect(func(text): Session.send_chat(text); g.chat_input.clear(); g.chat_input.release_focus())
	g.dead_button = button("已倒下 · 回巴郡复活",func(): send("respawn",{}),"return",Vector2(270,56))
	g.dead_button.position = Vector2(505,410); g.hud.add_child(g.dead_button); g.dead_button.hide()
	var toast = panel(Rect2(386,602,570,52),g.hud)
	toast.name = "NoticePanel"
	g.notice = label("",15,Color("ffe29d")); toast.add_child(g.notice); toast.hide()
	g.hud.hide()

func build_lobby() -> void:
	g.lobby = panel(Rect2(770,152,488,485))
	var col = column(g.lobby)
	header(col,"与室友，再入三国","door")
	var cards = row(col)
	for job in ["JS","XS"]:
		var card = button(Catalog.table("classes")[job].name,func(): _choose_job(job),"",Vector2(216,74))
		card.icon = UIArt.texture("portraits",job)
		card.expand_icon = true; card.add_theme_constant_override("icon_max_width",60)
		card.toggle_mode = true
		cards.add_child(card); lobby_cards.append(card)
	g.class_input = OptionButton.new()
	g.class_input.add_item("剑侍"); g.class_input.add_item("仙术士")
	col.add_child(g.class_input); g.class_input.hide()
	_choose_job("JS")
	var addr = row(col)
	addr.add_child(UIArt.image("symbols","shop",Vector2(26,26)))
	g.server_input = LineEdit.new(); g.server_input.text = "127.0.0.1"; g.server_input.placeholder_text = "服务器 IP"
	g.server_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL; addr.add_child(g.server_input)
	g.port_input = SpinBox.new(); g.port_input.min_value = 1024; g.port_input.max_value = 65535; g.port_input.value = 24567
	g.port_input.custom_minimum_size.x = 106; addr.add_child(g.port_input)
	col.add_child(label("初次角色名",13))
	g.name_input = LineEdit.new(); g.name_input.text = "蜀地旅人"; g.name_input.max_length = 16; col.add_child(g.name_input)
	col.add_child(label("本地档案（恢复已有角色）",13))
	g.profile_input = LineEdit.new(); g.profile_input.text = "default"; col.add_child(g.profile_input)
	g.connect_button = button("启 程",g._connect,"door",Vector2(430,44)); col.add_child(g.connect_button)
	g.cancel_retry = button("取消重连",func(): Session.disconnect_game(); g._failed("已取消重连，可重新连接。"),"cancel")
	col.add_child(g.cancel_retry); g.cancel_retry.hide()
	g.status = text_block(col,"同一局域网连接；已有角色自动恢复。\n进度保存在服务器，本机保存登录凭据。",430,13)

func _choose_job(job: String) -> void:
	g.class_input.select(0 if job == "JS" else 1)
	for i in range(lobby_cards.size()): lobby_cards[i].set_pressed_no_signal(i == g.class_input.selected)
	if g.lobby.visible:
		for i in range(3):
			var skill: String = Catalog.table("classes")[job].skills[i]
			var slot: ItemSlot = g.skill_buttons[i]
			slot.icon_id = skill; slot.disabled = true
			slot.get_parent().get_child(1).text = Catalog.table("skills")[skill].name
			slot.queue_redraw()

func open(kind: String) -> void:
	g.modal_kind = kind
	g.modal = panel(Rect2(232,126,816,522))
	var col = column(g.modal)
	var line = row(col)
	line.add_child(UIArt.image("symbols",kind,Vector2(34,34)))
	var name_label = label({"bag":"行囊与装备","shop":"巴郡商店","enhance":"装备强化","quests":"旅途任务 · 简雍","team":"同游伙伴","settings":"键位与声音","companions":"名将同行 · 副将"}[kind],22,Color("ffe29d"))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; line.add_child(name_label)
	line.add_child(button("关闭",g._close_panel,"cancel"))
	scroll = ScrollContainer.new(); scroll.custom_minimum_size = Vector2(772,419)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	g.modal_body = VBoxContainer.new(); g.modal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(g.modal_body)
	refresh()

func close() -> void:
	popup.hide()
	if is_instance_valid(confirmation): confirmation.queue_free()
	confirmation = null
	slots.clear(); member_bars.clear(); proximity_actions.clear(); companion_actions.clear(); companion_detail_status = null
	detail = null; scroll = null

func refresh() -> void:
	if not g.modal: return
	var saved_scroll = scroll.scroll_vertical
	for child in g.modal_body.get_children():
		g.modal_body.remove_child(child); child.queue_free()
	entries.clear(); slots.clear(); member_bars.clear(); proximity_actions.clear(); companion_actions.clear(); companion_detail_status = null; detail = null
	if g.modal_kind == "settings": _settings()
	elif not Session.latest.is_empty():
		var p: Dictionary = Session.latest.self
		g.modal_revision = int(p.revision)
		match g.modal_kind:
			"bag": _bag(p)
			"shop": _shop(p)
			"enhance": _enhance(p)
			"quests": _quests(p)
			"team": _team(p)
			"companions": _companions(p)
	if scroll: scroll.set_deferred("scroll_vertical",saved_scroll)
	update_dynamic()

func grid(parent: Node, values: Array[Dictionary], count: int = 24, columns: int = 6) -> GridContainer:
	var node = GridContainer.new(); node.columns = columns
	node.add_theme_constant_override("h_separation",4); node.add_theme_constant_override("v_separation",4)
	parent.add_child(node)
	for i in range(maxi(count,values.size())):
		var slot = ItemSlot.new()
		slot.custom_minimum_size = Vector2(54,54)
		if i < values.size():
			var entry: Dictionary = values[i]
			slot.entry = entry; slot.icon_id = entry.item
			slot.badge = str(entry.count) if int(entry.get("count",1)) > 1 else ""
			slot.tooltip_text = UIArt.item_text(entry,Session.latest.self)
			slot.marked = choices.get(g.modal_kind,"") == entry.key
			slot.chosen.connect(select_entry)
			slot.activated.connect(activate_entry)
			slot.context_requested.connect(context_entry)
		else: slot.disabled = true
		node.add_child(slot); slots.append(slot)
	return node

func selected_entry() -> Dictionary:
	for entry in entries:
		if entry.key == choices.get(g.modal_kind,""): return entry
	return {}

func select_entry(key: String) -> void:
	choices[g.modal_kind] = key
	for slot in slots:
		slot.marked = slot.entry.get("key","") == key; slot.queue_redraw()
	if g.modal_kind == "enhance": g.enhance_selected = key; g.enhance_message = ""
	show_detail()

func _prepare_detail(parent: Node) -> void:
	detail = column(parent,230)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if selected_entry().is_empty(): choices.erase(g.modal_kind)
	show_detail()

func _bag(p: Dictionary) -> void:
	var body = row(g.modal_body)
	var worn = column(body,155)
	header(worn,"角色装备","combat")
	worn.add_child(UIArt.image("characters",p.job,Vector2(145,154)))
	var equipment_row = row(worn)
	for slot in ["weapon","armor"]:
		var gear: Dictionary = p.gear[p.equipment[slot]]
		var entry = {"key":gear.id,"item":gear.item,"gear":gear,"count":1}
		var icon = ItemSlot.new(); icon.entry = entry; icon.icon_id = gear.item
		icon.tooltip_text = UIArt.item_text(entry,p); icon.badge = "已穿戴"
		icon.chosen.connect(func(_key): choices.bag = gear.id; show_detail())
		equipment_row.add_child(icon)
	text_block(worn,"物攻 %d  法攻 %d\n防御 %d" % [p.stats.physical_attack,p.stats.magic_attack,p.stats.defense],145,14)
	var bag = column(body,344)
	money(bag,p.money)
	bag.add_child(label("行囊 %d / 24 格" % InventoryRules.used_slots(p),14))
	entries = UIArt.bag_entries(p)
	for gear_id in p.equipment.values():
		var gear: Dictionary = p.gear[gear_id]
		# Equipped entries can be inspected but do not occupy inventory cells.
		if choices.get("bag","") == gear_id: entries.append({"key":gear_id,"item":gear.item,"gear":gear,"count":1,"worn":true})
	var bag_values: Array[Dictionary] = entries.filter(func(entry): return not entry.get("worn",false))
	grid(bag,bag_values)
	bag.add_child(label("单击详情 · 双击使用／装备 · 右键操作",12))
	_prepare_detail(body)

func _shop(p: Dictionary) -> void:
	var body = row(g.modal_body)
	var goods = column(body,344)
	var merchant = row(goods)
	merchant.add_child(UIArt.image("characters","merchant",Vector2(42,48)))
	merchant.add_child(label("装备商人 · 补给与装备",16,Color("ffe29d")))
	var tabs = row(goods)
	for mode in ["buy","sell"]:
		var tab = button("购买" if mode == "buy" else "出售",func(): shop_mode = mode; choices.erase("shop"); refresh(),"shop",Vector2(150,38))
		tab.toggle_mode = true; tab.button_pressed = shop_mode == mode; tabs.add_child(tab)
	money(goods,p.money)
	if shop_mode == "buy":
		for id in Catalog.table("items"):
			var item: Dictionary = Catalog.table("items")[id]
			if not item.get("shop_buyable",false): continue
			var entry = {"key":id,"item":id,"count":1}
			if item.has("slot"):
				entry.gear = {"id":"preview","item":id,"enhance":0,"failures":0,"revision":0}
				entry.template = true
			entries.append(entry)
	else: entries = UIArt.bag_entries(p)
	grid(goods,entries,12 if shop_mode == "buy" else 24)
	goods.add_child(button("装备强化",func(): g._open_panel("enhance"),"enhance"))
	_prepare_detail(body)

func _enhance(p: Dictionary) -> void:
	var body = row(g.modal_body)
	var equipment = column(body,344)
	header(equipment,"选择强化装备","enhance")
	money(equipment,p.money)
	var ids: Array = p.gear.keys(); ids.sort()
	for id in ids: entries.append({"key":id,"item":p.gear[id].item,"gear":p.gear[id],"count":1})
	if not choices.has("enhance") and not entries.is_empty(): choices.enhance = g.enhance_selected if p.gear.has(g.enhance_selected) else entries[0].key
	grid(equipment,entries,12)
	text_block(equipment,"已穿戴装备也可强化。\n失败不降级，不损坏装备。",320,14)
	_prepare_detail(body)

func show_detail() -> void:
	if not detail: return
	if g.modal_kind == "companions": _companion_detail(); return
	for child in detail.get_children(): detail.remove_child(child); child.queue_free()
	proximity_actions.clear()
	var entry = selected_entry()
	var p: Dictionary = Session.latest.self
	if entry.is_empty() and g.modal_kind == "bag" and p.gear.has(choices.get("bag","")):
		var gear: Dictionary = p.gear[choices.bag]
		entry = {"key":gear.id,"item":gear.item,"gear":gear,"count":1}
	if entry.is_empty():
		detail.add_child(UIArt.image("symbols",g.modal_kind,Vector2(125,125)))
		text_block(detail,"点击左侧图标查看详情",230)
		if g.modal_kind == "bag": detail.add_child(button("前往强化",func(): g._open_panel("enhance"),"enhance"))
		return
	detail.add_child(UIArt.image("items",entry.item,Vector2(84,84)))
	text_block(detail,UIArt.item_text(entry,p),230,14)
	if g.modal_kind == "enhance":
		g.enhance_selected = entry.key
		var quote = GearRules.quote(entry.gear)
		if quote.is_empty(): header(detail,"已达上限 +6","confirm")
		else:
			var next: Dictionary = entry.gear.duplicate(); next.enhance += 1
			var before = GearRules.stats(entry.gear); var after = GearRules.stats(next)
			var names = {"physical_attack":"物攻","magic_attack":"法攻","defense":"防御","hp":"生命"}
			var changes = ""
			for stat in before: changes += "%s  %d → %d\n" % [names.get(stat,stat),before[stat],after[stat]]
			text_block(detail,changes.strip_edges(),230,14)
			var recipe = row(detail)
			recipe.add_child(UIArt.image("items","enhance_stone",Vector2(32,32)))
			recipe.add_child(label("%d / %d" % [p.inventory.get("enhance_stone",0),quote.stones],14))
			recipe.add_child(UIArt.image("items","money",Vector2(26,26)))
			recipe.add_child(label("%d" % quote.money,14))
			text_block(detail,"目标 +%d · 成功率 %d%%\n保底进度 %d/3%s" % [int(entry.gear.enhance)+1,roundi(quote.chance*100),entry.gear.failures," · 下次必成" if entry.gear.failures >= 3 else ""],230,14)
			var progress = bar(detail,Color("bfa447"),230); progress.max_value = 3; progress.value = entry.gear.failures
			var action = button("等待结算…" if pending > 0 else "强化一次",func(): send("enhance",{"gear_id":entry.key,"expected_revision":entry.gear.revision}),"enhance")
			detail.add_child(action)
			proximity_actions.append({"button":action,"npc":"merchant","base":p.money < quote.money or int(p.inventory.get("enhance_stone",0)) < int(quote.stones),"reason":"金币或强化石不足"})
		if g.enhance_message != "":
			var result = row(detail); result.add_child(UIArt.image("symbols","confirm" if g.enhance_message.begins_with("强化成功") else "cancel",Vector2(28,28)))
			text_block(result,g.enhance_message,220,13)
	elif g.modal_kind == "shop":
		var item: Dictionary = Catalog.table("items")[entry.item]
		money(detail,int(item.price if shop_mode == "buy" else item.sell_price),"购买价格" if shop_mode == "buy" else "出售价格")
		var action = button("购买一件" if shop_mode == "buy" else "出售一件",func(): _trade(entry),"shop")
		detail.add_child(action)
		var full = InventoryRules.used_slots(p) >= InventoryRules.CAPACITY
		if not item.has("slot"): full = not _can_add_stack(p,entry.item)
		proximity_actions.append({"button":action,"npc":"merchant","base":shop_mode == "buy" and (p.money < item.price or full),"reason":"金币不足或背包已满"})
		text_block(detail,"每次交易一件。已穿戴装备不在出售列表。",230,13)
	else:
		var item: Dictionary = Catalog.table("items")[entry.item]
		if entry.has("gear") and entry.key not in p.equipment.values():
			var action = button("装备",func(): activate_entry(entry.key),"combat"); detail.add_child(action)
			action.disabled = pending > 0 or item.get("job","") not in ["",p.job] or int(item.get("level",1)) > int(p.level)
			action.tooltip_text = "需满足职业与等级要求"
		elif entry.item in ["potion","ether"]:
			var action = button("使用一件",func(): activate_entry(entry.key),"heal"); action.disabled = pending > 0 or p.dead; detail.add_child(action)
		if entry.item == "recruit_token": detail.add_child(button("招募副将",func(): g._open_panel("companions"),"companions"))
		detail.add_child(button("前往强化",func(): g._open_panel("enhance"),"enhance"))
	update_dynamic()

func _can_add_stack(p: Dictionary, id: String) -> bool:
	var copy = p.duplicate(true)
	return InventoryRules.add_item(copy,id)

func _trade(entry: Dictionary) -> void:
	if pending > 0 or not near("merchant") or Session.latest.self.dead: return
	if shop_mode == "buy":
		var item: Dictionary = Catalog.table("items")[entry.item]
		if Session.latest.self.money < item.price: return
		if item.has("slot") and InventoryRules.used_slots(Session.latest.self) >= 24: return
		if not item.has("slot") and not _can_add_stack(Session.latest.self,entry.item): return
	if shop_mode == "buy": send("buy",{"item":entry.item})
	elif entry.has("gear"): g._sell_gear(entry.key)
	else: send("sell",{"item":entry.item})

func activate_entry(key: String) -> void:
	select_entry(key)
	if pending > 0 or g.modal_kind != "bag": return
	var entry = selected_entry()
	if entry.is_empty(): return
	var p: Dictionary = Session.latest.self
	if p.dead: return
	if entry.has("gear"):
		var item: Dictionary = Catalog.table("items")[entry.item]
		if entry.key in p.equipment.values() or item.get("job","") not in ["",p.job] or int(item.get("level",1)) > int(p.level): return
		send("equip",{"gear_id":entry.key})
	elif entry.item in ["potion","ether"]: send("use",{"item":entry.item})
	elif entry.item == "recruit_token": g._open_panel("companions")

func context_entry(key: String) -> void:
	select_entry(key); context_key = key; popup.clear()
	var entry = selected_entry()
	if entry.is_empty(): return
	if g.modal_kind == "bag":
		if entry.has("gear"): popup.add_icon_item(UIArt.texture("symbols","combat"),"装备",0)
		elif entry.item in ["potion","ether"]: popup.add_icon_item(UIArt.texture("symbols","heal"),"使用一件",0)
		elif entry.item == "recruit_token": popup.add_icon_item(UIArt.texture("symbols","companions"),"招募副将",3)
		popup.add_icon_item(UIArt.texture("symbols","quests"),"查看详情",1)
	elif g.modal_kind == "shop": popup.add_icon_item(UIArt.texture("symbols","shop"),"购买一件" if shop_mode == "buy" else "出售一件",2)
	elif g.modal_kind == "enhance": popup.add_icon_item(UIArt.texture("symbols","quests"),"选择强化目标",1)
	for index in range(popup.item_count):
		popup.set_item_icon_max_width(index,24)
		popup.set_item_disabled(index,pending > 0)
	if g.modal_kind == "shop":
		var blocked = not near("merchant") or Session.latest.self.dead
		for action in proximity_actions: blocked = blocked or action.base
		popup.set_item_disabled(0,blocked or pending > 0)
	if g.modal_kind == "bag" and entry.has("gear"):
		var item: Dictionary = Catalog.table("items")[entry.item]
		popup.set_item_disabled(0,pending > 0 or Session.latest.self.dead or item.get("job","") not in ["",Session.latest.self.job] or int(item.get("level",1)) > int(Session.latest.self.level))
	var point = get_viewport().get_mouse_position()
	popup.position = Vector2i(point)
	popup.popup()
	var bounds = get_viewport().get_visible_rect().size
	popup.position = Vector2i(Vector2(popup.position).clamp(Vector2.ZERO,(bounds-Vector2(popup.size)).max(Vector2.ZERO)))

func _context_action(id: int) -> void:
	if pending > 0: return
	select_entry(context_key)
	if id == 0: activate_entry(context_key)
	elif id == 2 and not selected_entry().is_empty(): _trade(selected_entry())
	elif id == 3: g._open_panel("companions")

func send(action: String, payload: Dictionary) -> int:
	if pending > 0: return 0
	pending = int(request_sender.call(action,payload))
	if action == "enhance": g.enhance_pending = pending
	if g.modal: refresh()
	return pending

func result_received(result: Dictionary) -> void:
	if int(result.get("seq",0)) != pending: return
	pending = 0
	if g.modal: refresh()

func confirm_sell(gid: String) -> void:
	if pending > 0 or Session.latest.is_empty() or not Session.latest.self.gear.has(gid): return
	var gear: Dictionary = Session.latest.self.gear[gid]
	if gid in Session.latest.self.equipment.values(): return
	if int(gear.enhance) == 0:
		send("sell_gear",{"gear_id":gid})
		return
	if is_instance_valid(confirmation): return
	confirmation = Control.new()
	confirmation.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirmation.mouse_filter = Control.MOUSE_FILTER_STOP
	g.add_child(confirmation)
	var window = panel(Rect2(384,220,512,280),confirmation)
	var col = column(window)
	header(col,"出售强化装备","shop")
	var info = row(col)
	info.add_child(UIArt.image("items",gear.item,Vector2(72,72)))
	text_block(info,"确定出售 %s？\n强化等级与保底进度将一起失去。" % GearRules.label(gear),350,15)
	var actions = row(col)
	actions.add_child(button("确认出售",func(): confirmation.queue_free(); confirmation = null; send("sell_gear",{"gear_id":gid}),"confirm"))
	actions.add_child(button("保留装备",func(): confirmation.queue_free(); confirmation = null,"cancel"))

func near(npc_id: String) -> bool:
	if Session.latest.is_empty(): return false
	for npc in Catalog.table("maps")[Session.latest.map].npcs:
		if npc.id == npc_id: return absf(float(Session.latest.self.x)-float(npc.x)) < 150 and absf(float(Session.latest.self.y)-float(npc.y)) < 70
	return false

func update_dynamic() -> void:
	if Session.latest.is_empty(): return
	var p: Dictionary = Session.latest.self
	for entry in proximity_actions:
		if not is_instance_valid(entry.button): continue
		entry.button.disabled = pending > 0 or p.dead or entry.base or not near(entry.npc)
		entry.button.tooltip_text = "等待服务端结算" if pending > 0 else "角色已倒下" if p.dead else "需要靠近对应 NPC" if not near(entry.npc) else entry.reason if entry.base else ""
	for action in companion_actions:
		if not is_instance_valid(action.button): continue
		var disabled = pending > 0 or p.dead
		if action.kind == "recruit": disabled = disabled or not near("guide") or p.companions.size() >= 12 or int(p.inventory.get("recruit_token",0)) < 1
		elif action.kind != "mode": disabled = disabled or float(Session.latest.time) < float(p.combat_until)
		if action.kind == "release": disabled = disabled or action.id == p.active_companion
		action.button.disabled = disabled
	if is_instance_valid(companion_detail_status):
		var cid = choices.get("companions","")
		if p.companions.has(cid):
			var c: Dictionary = p.companions[cid]
			companion_detail_status.text = "生命 %d / %d\n经验 %d / %d%s\n技能冷却 %.1f 秒%s" % [c.hp,CompanionRules.stats(c).hp,c.xp,CompanionRules.required_exp(c.level)," · 等级已达当前上限" if c.level >= mini(10,p.level) else "",c.skill_cooldown_remaining,"\n倒下恢复还需 %.1f 秒脱战时间" % c.recovery_remaining if c.hp == 0 else ""]
	for slot in slots:
		slot.disabled = slot.icon_id == "" or pending > 0
		slot.queue_redraw()
	for member in Session.latest.roster:
		if member_bars.has(member.id):
			var data: Dictionary = member_bars[member.id]
			data.bar.max_value = member.max_hp; data.bar.value = member.hp
			data.bar.get_child(0).text = "%d / %d" % [member.hp,member.max_hp]
			data.label.text = "%s  Lv.%d · %s" % [member.name,member.level,Catalog.table("maps")[member.map].name]

func update_hud(state: Dictionary) -> void:
	var p: Dictionary = state.self
	movement_hint.text = _hint_text()
	g.world.interact_key = OS.get_keycode_string(g.keys.interact)
	portrait.texture = UIArt.texture("portraits",p.job)
	for i in range(3):
		var id: String = Catalog.table("classes")[p.job].skills[i]
		var skill: Dictionary = Catalog.table("skills")[id]
		var slot: ItemSlot = g.skill_buttons[i]
		slot.icon_id = id; slot.key_hint = OS.get_keycode_string(g.keys[["attack","skill1","skill2"][i]])
		slot.cooldown = float(p.cooldowns.get(id,0)); slot.cooldown_max = skill.cooldown
		slot.locked = p.level < skill.level
		slot.disabled = p.dead or slot.locked or slot.cooldown > 0 or p.mp < skill.cost
		slot.get_parent().get_child(1).text = skill.name
		slot.tooltip_text = "%s\n解锁等级 %d · 体力 %d\n距离 %d · 冷却 %.1fs" % [skill.name,skill.level,skill.cost,skill.range,skill.cooldown]
		slot.queue_redraw()
	for slot in potions:
		slot.badge = str(p.inventory.get(slot.icon_id,0)); slot.disabled = p.dead or pending > 0 or int(p.inventory.get(slot.icon_id,0)) <= 0
		slot.tooltip_text = UIArt.item_text({"item":slot.icon_id},p); slot.queue_redraw()
	target_panel.hide()
	for actor in state.players + state.monsters:
		if actor.id == g.selected:
			target_panel.show(); g.target_label.text = actor.name
			target_portrait.texture = UIArt.texture("portraits",actor.get("job",actor.get("kind","snake")))
			target_hp.max_value = actor.max_hp; target_hp.value = actor.hp
			target_hp.get_child(0).text = "%d / %d" % [actor.hp,actor.max_hp]
	var active: Dictionary = p.companions.get(p.active_companion,{})
	companion_tool_label.text = "副将 " + OS.get_keycode_string(g.keys.companions)
	companion_hud_icon.texture = UIArt.texture("portraits",active.get("kind","zhaoyun"))
	companion_hud_label.text = "副将 · 尚未出战" if active.is_empty() else "%s Lv.%d · %s" % [Catalog.table("companions")[active.kind].name,active.level,"已倒下" if active.hp == 0 else "助战" if p.companion_mode == "assist" else "跟随"]
	companion_health.max_value = 1 if active.is_empty() else CompanionRules.stats(active).hp
	companion_health.value = active.get("hp",0)
	companion_health.get_child(0).text = (OS.get_keycode_string(g.keys.companions)+" 打开副将") if active.is_empty() else "%d / %d" % [active.hp,companion_health.max_value]
	g.hud.get_node("NoticePanel").visible = g.notice.text != ""
	update_dynamic()

func _hint_text() -> String:
	return "%s/%s 移动 · %s 跳跃\n%s 交谈 · %s 拾取 · %s 传送" % [OS.get_keycode_string(g.keys.left),OS.get_keycode_string(g.keys.right),OS.get_keycode_string(g.keys.jump),OS.get_keycode_string(g.keys.interact),OS.get_keycode_string(g.keys.pickup),OS.get_keycode_string(g.keys.up)]

func _quests(p: Dictionary) -> void:
	var body = row(g.modal_body)
	var list = column(body,300)
	for id in Catalog.table("quests"):
		var q: Dictionary = Catalog.table("quests")[id]
		var state: Dictionary = p.quests.get(id,{})
		var title = q.name
		var icon = "confirm" if state.get("state","") == "done" else "quests"
		var b = button(title,func(): choices.quests = id; refresh(),icon,Vector2(300,42))
		b.toggle_mode = true; b.button_pressed = choices.get("quests","") == id; list.add_child(b)
	var info = column(body,420)
	if not choices.has("quests"): choices.quests = Catalog.table("quests").keys()[0]
	var id: String = choices.quests
	var q: Dictionary = Catalog.table("quests")[id]
	var state: Dictionary = p.quests.get(id,{})
	header(info,q.name,"quests")
	var intro = row(info)
	intro.add_child(UIArt.image("characters","guide",Vector2(75,95)))
	text_block(intro,q.description,315,16)
	var progress = int(p.inventory.get(q.target,0)) if q.type == "collect" else int(state.get("progress",0))
	var target = row(info)
	var group = "items" if q.type == "collect" else "portraits" if q.type == "kill" else "characters"
	target.add_child(UIArt.image(group,q.target,Vector2(48,48)))
	target.add_child(label("任务进度 %d / %d" % [mini(progress,q.count),q.count]))
	var meter = bar(info,Color("91b756"),400); meter.max_value = q.count; meter.value = mini(progress,q.count)
	var rewards = row(info)
	rewards.add_child(UIArt.image("items","xp",Vector2(30,30))); rewards.add_child(label("经验 %d" % q.xp))
	rewards.add_child(UIArt.image("items","money",Vector2(30,30))); rewards.add_child(label("三国币 %d" % q.money))
	if q.has("companion_reward"):
		rewards.add_child(UIArt.image("portraits",q.companion_reward,Vector2(42,42)))
		rewards.add_child(label("副将 " + Catalog.table("companions")[q.companion_reward].name))
	var done = state.get("state","") == "done"
	var blocked = q.previous != "" and p.quests.get(q.previous,{}).get("state","") != "done"
	var ready = q.type == "talk" or progress >= int(q.count)
	var b = button("已完成" if done else "交付任务" if not state.is_empty() else "领取任务",func(): send("quest",{"quest":id}),"confirm")
	info.add_child(b)
	proximity_actions.append({"button":b,"npc":"guide","base":done or blocked or (not state.is_empty() and not ready),"reason":"已完成、前置任务未完成或目标未达成"})
	text_block(info,"与巴郡简雍交谈领取、交付。",410,13)

func _team(p: Dictionary) -> void:
	if not Session.latest.invite.is_empty(): g.modal_body.add_child(button("收到邀请 · 接受组队",func(): send("accept",{}),"party"))
	for actor in Session.latest.roster:
		var card = PanelContainer.new(); g.modal_body.add_child(card)
		if actor.id == g.selected:
			var style = UIArt.frame(14); style.modulate_color = Color("ffe29d"); card.add_theme_stylebox_override("panel",style)
		var line = row(card)
		line.add_child(UIArt.image("portraits",actor.job,Vector2(64,64)))
		var info = column(line,450)
		var name_label = label("",16,Color("ffe29d")); info.add_child(name_label)
		var health = bar(info,Color("83ae6c"),420)
		member_bars[actor.id] = {"bar":health,"label":name_label}
		var same = actor.id == p.id or (p.party != "" and actor.party == p.party)
		line.add_child(button("选择治疗" if same else "邀请",func():
			if same: g.selected = actor.id; g.world.selected = actor.id; g._close_panel()
			else: send("invite",{"target":actor.id}),"heal" if same else "party"))
	if p.party != "": g.modal_body.add_child(button("离开队伍",func(): send("leave_party",{}),"door"))
	text_block(g.modal_body,"小怪掉落轮流归属；Boss 附近存活队友各自掉落。",700,14)

func _settings() -> void:
	header(g.modal_body,"点击按键后按下新键；Esc 取消","settings")
	var grid_node = GridContainer.new(); grid_node.columns = 2; grid_node.add_theme_constant_override("h_separation",24); g.modal_body.add_child(grid_node)
	var names = {"left":"向左","right":"向右","up":"向上／传送","down":"向下","jump":"跳跃","attack":"普攻","skill1":"技能一","skill2":"技能二","pickup":"拾取","target":"切换目标","bag":"背包","quests":"任务","team":"队伍","interact":"交谈","companions":"副将"}
	for action in g.keys:
		var line = row(grid_node)
		var icon: String = {"bag":"bag","quests":"quests","team":"team","interact":"shop","pickup":"bag","companions":"companions"}.get(action,"combat")
		line.add_child(UIArt.image("symbols",icon,Vector2(24,24)))
		var caption = label(names[action],14); caption.custom_minimum_size.x = 135; line.add_child(caption)
		line.add_child(button("请按新键…" if g.rebinding == action else OS.get_keycode_string(g.keys[action]),func(): g.rebinding = action; refresh(),"",Vector2(130,32)))
	var audio = row(g.modal_body); audio.add_child(UIArt.image("symbols","sound",Vector2(32,32)))
	var mute = CheckButton.new(); mute.text = "静音"; mute.button_pressed = AudioServer.is_bus_mute(0)
	mute.toggled.connect(func(value): AudioServer.set_bus_mute(0,value); g._save_settings()); audio.add_child(mute)

func _companions(p: Dictionary) -> void:
	var body = row(g.modal_body)
	var collection = column(body,345)
	header(collection,"副将收藏 %d / 12" % p.companions.size(),"companions")
	var grid_node = GridContainer.new(); grid_node.columns = 4; collection.add_child(grid_node)
	var ids: Array = p.companions.keys(); ids.sort()
	for i in range(12):
		var slot = ItemSlot.new(); slot.custom_minimum_size = Vector2(78,78); slot.icon_group = "portraits"
		if i < ids.size():
			var c: Dictionary = p.companions[ids[i]]
			slot.entry = {"key":c.id,"item":c.kind,"companion":c}
			slot.icon_id = c.kind; slot.badge = "Lv.%d" % c.level; slot.marked = choices.get("companions","") == c.id
			slot.key_hint = "出战" if c.id == p.active_companion else ""
			slot.tooltip_text = "%s Lv.%d [%s]" % [Catalog.table("companions")[c.kind].name,c.level,c.id.right(6)]
			slot.chosen.connect(select_entry); entries.append(slot.entry)
		else: slot.disabled = true
		grid_node.add_child(slot); slots.append(slot)
	text_block(collection,"同名副将独立培养；最多出战一名。\n出战、收回和放生需要脱战。",330,13)
	var tokens = row(collection); tokens.add_child(UIArt.image("items","recruit_token",Vector2(36,36))); tokens.add_child(label("招募令 ×%d" % p.inventory.get("recruit_token",0),15))
	var recruit_row = row(collection)
	for kind in Catalog.table("companions"):
		var b = button("招募" + Catalog.table("companions")[kind].name,func(): _companion_send("companion_recruit",{"kind":kind}),"",Vector2(104,35))
		recruit_row.add_child(b); companion_actions.append({"button":b,"kind":"recruit"})
	text_block(collection,"靠近巴郡简雍，自选招募；每次消耗一枚招募令。首次副将从“名将同行”任务领取。",330,13)
	_prepare_detail(body)

func _companion_detail() -> void:
	for child in detail.get_children(): detail.remove_child(child); child.queue_free()
	companion_actions = companion_actions.filter(func(a): return a.kind == "recruit")
	companion_detail_status = null
	var entry = selected_entry()
	if entry.is_empty():
		detail.add_child(UIArt.image("symbols","companions",Vector2(120,120)))
		text_block(detail,"选择左侧副将查看能力与出战状态。",230)
		return
	var c: Dictionary = Session.latest.self.companions[entry.key]
	var def: Dictionary = Catalog.table("companions")[c.kind]
	detail.add_child(UIArt.image("characters",c.kind,Vector2(108,108)))
	text_block(detail,"%s Lv.%d [%s]\n%s · %s" % [def.name,c.level,c.id.right(6),def.role,def.skill],230,15)
	companion_detail_status = text_block(detail,"",230,13)
	var skill_row = row(detail); skill_row.add_child(UIArt.image("companion_skills",c.kind,Vector2(38,38)))
	text_block(skill_row,"%s %d · 距离 %d\n间隔 %.1f 秒 · 防御 %d" % ["治疗" if c.kind == "huatuo" else "伤害",CompanionRules.stats(c).power,def.range,def.cooldown,CompanionRules.stats(c).defense],180,13)
	var active = c.id == Session.latest.self.active_companion
	var deploy = button("收回副将" if active else "出战副将",func(): _companion_send("companion_recall" if active else "companion_deploy",{} if active else {"companion_id":c.id}),"companions")
	detail.add_child(deploy); companion_actions.append({"button":deploy,"kind":"deploy"})
	var mode = button("改为仅跟随" if Session.latest.self.companion_mode == "assist" else "改为助战",func(): _companion_send("companion_mode",{"mode":"follow" if Session.latest.self.companion_mode == "assist" else "assist"}),"combat")
	detail.add_child(mode); companion_actions.append({"button":mode,"kind":"mode"})
	var release = button("放生副将",func(): _confirm_release(c.id),"cancel")
	detail.add_child(release); companion_actions.append({"button":release,"kind":"release","id":c.id})
	update_dynamic()

func _companion_send(action: String, payload: Dictionary) -> void:
	payload.expected_revision = Session.latest.self.companion_revision
	send(action,payload)

func _confirm_release(cid: String) -> void:
	if pending > 0 or is_instance_valid(confirmation) or not Session.latest.self.companions.has(cid): return
	var c: Dictionary = Session.latest.self.companions[cid]
	var revision = int(Session.latest.self.companion_revision)
	confirmation = Control.new(); confirmation.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); confirmation.mouse_filter = Control.MOUSE_FILTER_STOP; g.add_child(confirmation)
	var col = column(panel(Rect2(384,220,512,280),confirmation))
	header(col,"确认放生副将","companions")
	var info = row(col); info.add_child(UIArt.image("portraits",c.kind,Vector2(72,72)))
	text_block(info,"放生 %s Lv.%d [%s]？\n培养进度将永久失去，无返还奖励。" % [Catalog.table("companions")[c.kind].name,c.level,c.id.right(6)],340,15)
	var actions = row(col)
	actions.add_child(button("确认放生",func(): confirmation.queue_free(); confirmation = null; send("companion_release",{"companion_id":cid,"expected_revision":revision}),"confirm"))
	actions.add_child(button("保留副将",func(): confirmation.queue_free(); confirmation = null,"cancel"))
