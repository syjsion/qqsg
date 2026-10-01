extends Node

var failures = 0
var checks = 0
var requests: Array[Dictionary] = []
var game

func _ready() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("UI_FAIL ",message)

func click(control: Control, mouse_button: int = MOUSE_BUTTON_LEFT, double: bool = false) -> void:
	var event = InputEventMouseButton.new()
	event.button_index = mouse_button
	event.position = control.get_global_rect().get_center()
	event.global_position = event.position
	event.pressed = true
	event.double_click = double
	get_viewport().push_input(event,true)
	await get_tree().process_frame
	event = event.duplicate()
	event.pressed = false
	get_viewport().push_input(event,true)
	await get_tree().process_frame

func descendants(node: Node, type_name: String) -> Array[Node]:
	var result: Array[Node] = []
	for child in node.get_children():
		if child.is_class(type_name): result.append(child)
		result.append_array(descendants(child,type_name))
	return result

func run() -> void:
	Catalog.load_data()
	var sim = GameSimulation.new()
	var a = sim.join("","测试旅人","JS")
	var b = sim.join("","治疗伙伴","XS")
	var p: Dictionary = sim.records[a.id]
	p.level = 10; p.money = 1200; p.x = 780; p.y = 600
	p.party = a.id; sim.records[b.id].party = a.id
	p.inventory = {"potion":100,"ether":3,"herb":4,"enhance_stone":40}
	var first = GearRules.create("iron_sword")
	var second = GearRules.create("iron_sword")
	first.enhance = 2
	p.gear[first.id] = first; p.gear[second.id] = second
	var staff = GearRules.create("jade_staff"); p.gear[staff.id] = staff
	p.hp = Catalog.stats(p).hp; p.mp = Catalog.stats(p).mp
	var base = UIArt.bag_entries(p)
	check(base.size() == InventoryRules.used_slots(p),"display capacity matches authoritative capacity")
	var stacks = base.filter(func(e): return e.item == "potion")
	check(stacks.size() == 2 and stacks[0].count == 99 and stacks[1].count == 1,"stack split 99+1")
	check(base.filter(func(e): return e.item == "iron_sword").size() == 2,"duplicate gear instances remain distinct")
	check(not base.any(func(e): return e.key in p.equipment.values()),"equipped gear outside grid")
	var full = p.duplicate(true)
	while InventoryRules.used_slots(full) < 24:
		var gear = GearRules.create("cloth"); full.gear[gear.id] = gear
	check(UIArt.bag_entries(full).size() == 24,"full bag has exactly 24 cells")
	for id in Catalog.table("items"): check(UIArt.texture("items",id) != null,"item icon "+id)
	for id in Catalog.table("skills"): check(UIArt.texture("skills",id) != null,"skill icon "+id)
	game = load("res://client/game.gd").new(); add_child(game)
	Session.player_id = a.id; Session.latest = sim.snapshot(a.id)
	game._connected(); game._snapshot(Session.latest)
	game.interface.request_sender = func(action,payload):
		requests.append({"action":action,"payload":payload.duplicate(true)})
		return 100 + requests.size()
	game._open_panel("bag")
	await get_tree().process_frame; await get_tree().process_frame
	check(game.interface.slots.size() == 24,"bag renders 24 slots including empty")
	var slot: ItemSlot
	for candidate in game.interface.slots:
		if candidate.entry.get("key","") == second.id: slot = candidate
	await click(slot)
	check(game.interface.choices.get("bag","") == second.id and requests.is_empty(),"single click selects without request")
	check(game.selected == "","UI click does not select world entity")
	await click(slot,MOUSE_BUTTON_LEFT,true)
	check(requests.size() == 1 and requests[0].action == "equip" and requests[0].payload.gear_id == second.id,"double click sends selected gear instance")
	game.interface.activate_entry(second.id)
	check(requests.size() == 1,"pending blocks duplicate activation")
	check(Session.latest.self.equipment.weapon != second.id,"UI does not apply equipment before server snapshot")
	game._result({"seq":101,"ok":true})
	check(game.interface.pending == 0,"matching receipt unlocks actions")
	game.interface.select_entry(first.id)
	game._refresh_panel()
	check(game.interface.selected_entry().key == first.id,"snapshot refresh retains selection")
	game.interface.activate_entry(staff.id)
	check(requests.size() == 1,"wrong profession disabled for double-click")
	var herb = game.interface.entries.filter(func(e): return e.item == "herb")[0]
	game.interface.activate_entry(herb.key)
	check(requests.size() == 1,"material double click opens details only")
	for candidate in game.interface.slots:
		if candidate.entry.get("key","") == herb.key: slot = candidate
	await get_tree().process_frame
	await click(slot,MOUSE_BUTTON_RIGHT)
	check(game.interface.popup.item_count == 1,"material context menu has no fake use action")
	check(game.interface.popup.visible,"real right click opens embedded menu")
	check(game.interface.popup.size.y < 120,"context icons render compactly instead of atlas cell size")
	check(game.interface.popup.position.x + game.interface.popup.size.x <= get_viewport().get_visible_rect().size.x,"context menu stays within viewport")
	game.interface.popup.hide()
	game.interface.select_entry(first.id)
	Session.latest.self.gear.erase(first.id); Session.latest.self.revision += 1
	game._refresh_panel()
	check(game.interface.selected_entry().is_empty(),"removed selection invalidated")
	game._open_panel("shop"); game.interface.select_entry("iron_sword")
	check(not game.interface.proximity_actions[0].button.disabled,"near merchant can buy")
	Session.latest.self.x = 1200; game.interface.update_dynamic()
	check(game.interface.proximity_actions[0].button.disabled,"distance updates without revision")
	game.interface._trade(game.interface.selected_entry())
	check(requests.size() == 1,"context trade cannot bypass NPC distance")
	Session.latest.self.x = 780; Session.latest.self.y = 500; game.interface.update_dynamic()
	check(game.interface.proximity_actions[0].button.disabled,"NPC vertical distance checked")
	Session.latest.self.y = 600; Session.latest.self.money = 0; game._refresh_panel()
	check(game.interface.proximity_actions[0].button.disabled,"insufficient funds")
	Session.latest.self.money = 1200; game.interface.shop_mode = "sell"; game._refresh_panel()
	check(not game.interface.entries.any(func(e): return e.key in Session.latest.self.equipment.values()),"worn gear excluded from selling")
	var strengthened = GearRules.create("iron_sword"); strengthened.enhance = 2
	Session.latest.self.gear[strengthened.id] = strengthened
	game._refresh_panel(); game.interface.select_entry(strengthened.id)
	game._sell_gear(strengthened.id)
	check(is_instance_valid(game.interface.confirmation) and requests.size() == 1,"enhanced sale requires confirmation")
	game._close_panel()
	check(game.interface.confirmation == null,"close clears confirmation")
	game._open_panel("enhance"); game.interface.select_entry(strengthened.id)
	Session.latest.self.inventory.enhance_stone = 0; game._refresh_panel()
	check(game.interface.proximity_actions[0].button.disabled,"enhance material shortage")
	Session.latest.self.inventory.enhance_stone = 40
	Session.latest.self.gear[strengthened.id].enhance = 5; Session.latest.self.gear[strengthened.id].failures = 3
	game._refresh_panel()
	check(GearRules.quote(Session.latest.self.gear[strengthened.id]).chance == 1,"pity uses rules quote")
	game.interface.send("enhance",{"gear_id":strengthened.id,"expected_revision":0})
	check(game.enhance_pending == 102 and game.interface.proximity_actions[0].button.disabled,"enhance awaiting authoritative result")
	game._result({"seq":102,"ok":true,"enhancement":{"enhanced":false,"level":5,"failures":3}})
	check(game.enhance_message.contains("未成功") and game.interface.pending == 0,"failed enhancement receipt distinct")
	game.interface.send("enhance",{"gear_id":strengthened.id,"expected_revision":0})
	game._result({"seq":103,"ok":true,"enhancement":{"enhanced":true,"level":6,"failures":0}})
	check(game.enhance_message.begins_with("强化成功"),"success receipt distinct")
	Session.latest.self.gear[strengthened.id].enhance = 6; game._refresh_panel()
	check(game.interface.proximity_actions.is_empty(),"maximum enhancement has no action")
	game._open_panel("team")
	var health: ProgressBar = game.interface.member_bars[b.id].bar
	for member in Session.latest.roster:
		if member.id == b.id: member.hp = 25
	game.interface.update_dynamic()
	check(game.interface.member_bars[b.id].bar == health and health.value == 25,"team HP updates without rebuilding")
	game._open_panel("quests"); game.interface.choices.quests = "snakes"; game._refresh_panel()
	check(game.interface.proximity_actions[0].button.disabled,"quest prerequisite or progress blocks turn-in")
	game.world.state.self.quests = {}
	check(game.world._quest_marker() == "quests","available NPC marker")
	game.world.state.self.quests.arrival = {"state":"active","progress":0}
	check(game.world._quest_marker() == "confirm","ready NPC marker")
	Session.latest.self.job = "XS"; Session.latest.self.level = 1; Session.latest.self.cooldowns = {"bolt":0.5}
	game._update_hud(Session.latest)
	check(game.skill_buttons[0].icon_id == "bolt" and game.skill_buttons[0].cooldown == 0.5,"healer skill art and cooldown")
	check(game.skill_buttons[2].locked,"skill level lock")
	game.keys.interact = KEY_F; game._update_hud(Session.latest)
	check(game.world.interact_key == "F" and game.interface.movement_hint.text.contains("F 交谈"),"rebound interaction hints match actual key")
	game._reconnecting("测试重连")
	check(game.lobby.visible and game.cancel_retry.visible and game.interface.pending == 0,"reconnection clears pending and shows cancel")
	game._failed("已取消重连")
	check(not game.cancel_retry.visible and not game.connect_button.disabled,"retry cancelled lobby usable")
	game._open_panel("settings")
	check(not descendants(game.modal_body,"TextureRect").is_empty(),"settings use functional icons")
	game.queue_free(); await get_tree().process_frame; await get_tree().process_frame
	print("UI_RESULT %d checks %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
