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
		Session.player_id = a.id
		Session.latest = sim.snapshot(a.id)
		game._connected()
		game._snapshot(Session.latest)
		if args.preview in ["bag", "team", "quests", "shop"]: game._open_panel(args.preview)
	await get_tree().create_timer(2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(args.get("output", "user://preview.png"))
	game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()
