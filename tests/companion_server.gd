extends Node
var staged = false

func _ready() -> void:
	if not Session.start_server(): get_tree().quit(1); return
	var args = Session.arguments()
	Catalog.table("boss_loot").recruit_chance = 1.0 # Deterministic test fixture only.
	if Session.simulation.records.is_empty():
		var ids: Array = []
		for i in range(4):
			var identity = Session.simulation.join("","副将联网%d" % i,"JS")
			ids.append(identity.id)
			var p: Dictionary = Session.simulation.records[identity.id]
			p.level = 10; p.hp = Catalog.stats(p).hp; p.mp = Catalog.stats(p).mp
			p.x = 380; p.inventory.recruit_token = 2
			var c = CompanionRules.create(["zhaoyun","huangzhong","huatuo","zhaoyun"][i])
			p.companions[c.id] = c; p.active_companion = c.id; p.companion_mode = "follow"
			var f = FileAccess.open(str(args.work).path_join("credentials%d.json" % i),FileAccess.WRITE)
			f.store_string(JSON.stringify({"127.0.0.1:%s/companions" % args.port:identity.token})); f.close()
			Session.simulation.disconnect_player(identity.id)
		for id in ids: Session.simulation.records[id].party = ids[0]
		Session.simulation.checkpoint()
	print("COMPANION_SERVER_READY")

func _physics_process(_dt: float) -> void:
	var args = Session.arguments()
	if staged or not FileAccess.file_exists(str(args.work).path_join("boss-go")): return
	staged = true
	var sim = Session.simulation
	for m in sim.monsters.values():
		if m.kind == "boss":
			m.hp = 1; m.attack_at = sim.clock+10000
			for id in sim.online:
				var p: Dictionary = sim.records[id]
				p.map = "camp"; p.x = m.x-40; p.y = m.y; p.combat_until = 0
		else: m.dead = true; m.respawn_at = sim.clock+10000
	print("COMPANION_BOSS_STAGED")
