extends Node

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://client/game.gd").new()
	add_child(game)
	var args = Session.arguments()
	if args.has("preview") and args.preview != "login":
		var sim = GameSimulation.new()
		var a = sim.join("", "云间客", "JS")
		var b = sim.join("", "青萝", "XS")
		if args.get("job", "JS") == "XS":
			var swap = a; a = b; b = swap
		for id in [a.id, b.id]:
			sim.records[id].map = args.get("map", "west")
			sim.records[id].level = 6
			sim.records[id].x = 620 if id == a.id else 770
			sim.records[id].hp = Catalog.stats(sim.records[id]).hp
			sim.records[id].mp = Catalog.stats(sim.records[id]).mp
			sim.records[id].party = a.id
			sim.records[id].quests.snakes = {"state":"active", "progress":3}
		if args.preview in ["bag", "shop", "enhance", "quests", "menu"]:
			sim.records[a.id].inventory.herb = 14
			sim.records[a.id].inventory.seal = 3
			sim.records[a.id].inventory.enhance_stone = 40
			for item in ["camp_sword", "jade_pattern_staff", "fine_armor", "leather", "bronze_sword", "jade_staff"]:
				var gear = GearRules.create(item)
				if item == "camp_sword": gear.enhance = 3
				sim.records[a.id].gear[gear.id] = gear
			if args.get("full", "false") == "true":
				while InventoryRules.used_slots(sim.records[a.id]) < 24:
					var gear = GearRules.create("iron_sword"); sim.records[a.id].gear[gear.id] = gear
		if args.preview in ["shop", "enhance"] and args.get("map", "west") == "bajun":
			sim.records[a.id].x = 780
		if args.preview == "quests" and args.get("map", "west") == "bajun": sim.records[a.id].x = 380
		if args.get("empty","false") == "true":
			sim.records[a.id].inventory.clear()
			for gid in sim.records[a.id].gear.keys():
				if gid not in sim.records[a.id].equipment.values(): sim.records[a.id].gear.erase(gid)
		if args.get("long","false") == "true": sim.records[a.id].name = "巴郡城里与你共同游历山河的旅人"
		if args.preview == "combat":
			sim.clock = 10
			sim.records[a.id].anim_started = 10
			sim.records[a.id].anim_until = 10.4
			sim.records[a.id].cast_skill = "wind"
			sim.records[b.id].hurt_until = 10.5
			for m in sim.monsters.values():
				if m.kind == "boss":
					m.x = 980
					m.windup_started = 9.5
					m.windup = 10.5
				else:
					m.dead = true
					m.death_started = 9.4
		if args.preview == "enhance":
			sim.records[a.id].inventory.enhance_stone = 40
			sim.records[a.id].money = 1200
			var gear: Dictionary = sim.records[a.id].gear[sim.records[a.id].equipment.weapon]
			gear.enhance = 5
			gear.failures = 3
			game.enhance_selected = gear.id
		if args.preview in ["companions","companion-world"]:
			var p: Dictionary = sim.records[a.id]
			p.x = 380 if args.get("map", "west") == "bajun" else 650
			p.inventory.recruit_token = 3
			var number = 12 if args.get("full","false") == "true" else 3
			if args.get("empty","false") == "true": number = 0
			for i in range(number):
				var c = CompanionRules.create(["zhaoyun","huangzhong","huatuo"][i%3])
				c.level = 3; c.hp = CompanionRules.stats(c).hp
				p.companions[c.id] = c
				if i == 0: p.active_companion = c.id
			if p.active_companion != "":
				var c: Dictionary = p.companions[p.active_companion]
				if args.get("down","false") == "true": c.hp = 0; c.recovery_remaining = 13.5
				sim._tick_companion_body(p,0.016)
				for i in range(2):
					var owner: Dictionary = sim.records[b.id] if i == 0 else sim.records[sim.join("","岚山客","JS").id]
					owner.map = p.map; owner.x = p.x+150+i*130; owner.y = p.y
					var other = CompanionRules.create(["huangzhong","huatuo"][i]); owner.companions[other.id] = other; owner.active_companion = other.id
					sim._tick_companion_body(owner,0.016)
		if args.has("motion"):
			for body in sim.companion_bodies.values():
				if args.motion == "attack": body.anim_started = 0.0; body.anim_until = 0.4
				elif args.motion == "hurt": body.hurt_until = 0.5
				elif args.motion == "run": body.moving = true
		Session.player_id = a.id
		Session.latest = sim.snapshot(a.id)
		game._connected()
		game._snapshot(Session.latest)
		if args.preview in ["bag", "team", "quests", "shop", "enhance", "settings", "menu", "companions"]:
			if args.get("sell","false") == "true": game.interface.shop_mode = "sell"
			game._open_panel("bag" if args.preview == "menu" else args.preview)
			if args.preview in ["bag", "shop"] and not game.interface.entries.is_empty(): game.interface.select_entry(game.interface.entries[0].key)
		if args.preview == "companions" and not game.interface.entries.is_empty(): game.interface.select_entry(Session.latest.self.active_companion)
		if args.get("release","false") == "true":
			for entry in game.interface.entries:
				if entry.key != Session.latest.self.active_companion: game.interface._confirm_release(entry.key); break
		if args.preview == "death":
			Session.latest.self.dead = true; game._update_hud(Session.latest)
		if args.preview == "drops":
			game.world.state.drops = [{"id":"preview_drop","item":"enhance_stone","count":3,"owner":a.id,"x":680,"y":600}, {"id":"preview_gear","item":"camp_sword","count":1,"owner":a.id,"x":745,"y":600,"gear":{"enhance":2}}]
		if args.get("confirm","false") == "true":
			for gid in sim.records[a.id].gear:
				if sim.records[a.id].gear[gid].enhance > 0: game._sell_gear(gid); break
		if args.has("width"):
			get_window().size = Vector2i(int(args.width),int(args.get("height","800")))
	await get_tree().create_timer(2).timeout
	if args.get("preview","") == "menu" and not game.interface.entries.is_empty():
		game.interface.context_entry(game.interface.entries[0].key)
		await get_tree().create_timer(0.1).timeout
	if args.get("motion", "") == "attack":
		for actor in Session.latest.get("companions",[]): game.world.effect({"target":actor.id,"kind":"cast","amount":0,"text":actor.kind})
	if args.get("preview", "") == "combat":
		game.world.effect({"target":Session.player_id,"kind":"cast","amount":0,"text":"wind"})
		await get_tree().create_timer(0.15).timeout
	if args.get("preview", "") == "reconnect": game._reconnecting("连接中断，2 秒后重连（2/5）")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(args.get("output", "user://preview.png"))
	game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	# Let the audio mixer release stopped Ogg playback before engine shutdown.
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()
