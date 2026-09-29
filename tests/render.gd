extends Node

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://client/game.gd").new()
	add_child(game)
	var args = Session.arguments()
	if args.has("preview"):
		var sim = GameSimulation.new()
		var a = sim.join("", "云间客", "JS")
		var b = sim.join("", "青萝", "XS")
		for id in [a.id, b.id]:
			sim.records[id].map = args.get("map", "west")
			sim.records[id].level = 6
			sim.records[id].x = 620 if id == a.id else 770
			sim.records[id].hp = Catalog.stats(sim.records[id]).hp
			sim.records[id].mp = Catalog.stats(sim.records[id]).mp
			sim.records[id].party = a.id
			sim.records[id].quests.snakes = {"state":"active", "progress":3}
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
		Session.player_id = a.id
		Session.latest = sim.snapshot(a.id)
		game._connected()
		game._snapshot(Session.latest)
		if args.preview in ["bag", "team", "quests", "shop"]: game._open_panel(args.preview)
	await get_tree().create_timer(2).timeout
	if args.get("preview", "") == "combat":
		game.world.effect({"target":Session.player_id,"kind":"cast","amount":0,"text":"wind"})
		await get_tree().create_timer(0.15).timeout
	if args.get("preview", "") == "reconnect": game._reconnecting("连接中断，2 秒后重连（2/5）")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(args.get("output", "user://preview.png"))
	game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()
