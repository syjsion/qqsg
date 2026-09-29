extends SceneTree

var checks = 0
var failures = 0

class FailingStore extends SaveStore:
	var fail = false
	func write(state: Dictionary) -> bool:
		if fail:
			error = "injected disk failure"
			return false
		return super.write(state)

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)

func run() -> void:
	Catalog.load_data()
	var p = Catalog.new_character("test", "甲", "JS")
	check(Catalog.stats(p).hp == 435, "JS source level 1 HP")
	check(Catalog.required_exp(1) == 30 and Catalog.required_exp(9) == 4140, "source XP values")
	check(Catalog.gain_exp(p, 140) and p.level == 3 and p.xp == 0, "multiple levels in one reward")
	Catalog.gain_exp(p, 9999999)
	check(p.level == 10 and p.xp == 0, "level cap")
	var xs = Catalog.new_character("xs", "乙", "XS")
	check(Catalog.stats(xs).hp == 260 and Catalog.stats(xs).mp == 200, "XS source HP and MP")
	check(CombatRules.healing(Catalog.stats(xs), Catalog.table("skills").heal) == 125, "source healing formula")
	var normal = CombatRules.damage(Catalog.stats(p), 2, Catalog.table("skills").slash, 0.5)
	var critical = CombatRules.damage(Catalog.stats(p), 2, Catalog.table("skills").slash, 0.01)
	check(critical.amount >= normal.amount * 2 - 1, "critical roll")
	check(CombatRules.damage(Catalog.stats(p), 10000, Catalog.table("skills").slash, 0.5).amount == 1, "minimum damage")
	var bag = {}
	check(InventoryRules.add(bag, "potion", 99), "add full stack")
	check(InventoryRules.add(bag, "potion", 1) and InventoryRules.slots(bag) == 2, "stack rollover consumes slot")
	check(not InventoryRules.add(bag, "potion", 2400), "full bag rejects without mutation")
	check(bag.potion == 100, "overflow did not change bag")
	check(not InventoryRules.take(bag, "potion", -1), "negative consume rejected")
	var sim = GameSimulation.new()
	sim.rng.seed = 1234
	var a = sim.join("", "剑客", "JS")
	var b = sim.join("", "医者", "XS")
	check(a.error == "" and b.error == "", "create two players")
	check(sim.join(a.token, "无效重命名", "XS").error != "", "duplicate identity rejected")
	check(sim.join("invalid", "x", "JS").error != "", "invalid token rejected")
	check(sim.command(a.id, "buy", {"item":"potion"}).ok == false, "shop requires proximity")
	sim.records[a.id].x = 780
	check(sim.command(a.id, "buy", {"item":"potion"}).ok, "buy at merchant")
	check(sim.records[a.id].money == 88 and sim.records[a.id].inventory.potion == 9, "purchase settles once")
	sim.records[a.id].x = 380
	check(sim.command(a.id, "quest", {"quest":"snakes"}).ok == false, "quest prerequisite")
	check(sim.command(a.id, "quest", {"quest":"arrival"}).ok, "accept talk quest")
	check(sim.command(a.id, "quest", {"quest":"arrival"}).ok, "complete talk quest")
	var coins = sim.records[a.id].money
	check(not sim.command(a.id, "quest", {"quest":"arrival"}).ok and sim.records[a.id].money == coins, "duplicate reward denied")
	check(sim.command(a.id, "invite", {"target": b.id}).ok, "invite")
	check(sim.command(b.id, "accept", {}).ok, "accept invite")
	check(sim.records[a.id].party == sim.records[b.id].party, "party membership")
	for id in [a.id, b.id]:
		sim.records[id].map = "west"
		sim.records[id].x = 600
		sim.records[id].y = 600
	sim.records[a.id].hp = 100
	check(sim.command(b.id, "skill", {"skill":"heal", "target":a.id}).ok, "ally healing")
	check(sim.records[a.id].hp == 225, "healing applied by server")
	check(not sim.command(b.id, "skill", {"skill":"heal", "target":a.id}).ok, "cooldown authoritative")
	check(not sim.command(a.id, "skill", {"skill":"heal", "target":a.id}).ok, "wrong class skill denied")
	check(not sim.command(a.id, "skill", {"skill":"slash", "target":b.id}).ok, "no friendly damage")
	sim.monsters["west:0"].hp = 1
	check(sim.command(a.id, "skill", {"skill":"slash", "target":"west:0"}).ok, "monster death")
	check(sim.monsters["west:0"].dead and sim.drops.size() in [1,2], "one death base drop plus optional stone")
	var drop_id = sim.drops.keys()[0]
	var owner = sim.drops[drop_id].owner
	var not_owner = b.id if owner == a.id else a.id
	check(not sim.command(not_owner, "pickup", {"drop":drop_id}).ok, "loot ownership")
	check(sim.command(owner, "pickup", {"drop":drop_id}).ok, "owned loot pickup")
	check(not sim.command(owner, "pickup", {"drop":drop_id}).ok, "same loot cannot be claimed twice")
	check(sim.records[b.id].xp > 0, "party XP shared")
	sim.records[a.id].x = 2700
	check(sim.command(a.id, "portal", {}).ok and sim.records[a.id].map == "camp", "server validated map transfer")
	var snap = sim.snapshot(a.id)
	check(snap.players.size() == 1 and snap.monsters.size() == 5, "only same-map entities replicated")
	check(not JSON.stringify(snap).contains(a.token), "snapshots omit credentials")
	sim.input(a.id, 1, Vector2(1,0), false)
	var before_x: float = sim.records[a.id].x
	sim.tick(1.0/60)
	check(sim.records[a.id].x > before_x, "input movement")
	sim.input(a.id, 0, Vector2(-1,0), false)
	check(sim.inputs[a.id].axis.x == 1, "old input ignored")
	var body = {"x":740.0,"y":600.0,"vy":0.0,"grounded":true}
	MovementRules.step(body, Vector2(0,-1), false, 0.1, Catalog.table("maps").west)
	check(body.y < 600 and body.climbing, "ladder climb")
	var jumper = {"x":300.0,"y":600.0,"vy":0.0,"grounded":true}
	MovementRules.step(jumper, Vector2.ZERO, true, 1.0/60, Catalog.table("maps").west)
	check(jumper.y < 600, "jump takes off")
	for i in range(120): MovementRules.step(jumper, Vector2.ZERO, false, 1.0/60, Catalog.table("maps").west)
	check(jumper.y == 600 and jumper.grounded, "land on ground")
	_save_tests()
	_chapter_tests()
	_boundary_tests()
	_feedback_tests()
	preload("res://tests/progression.gd").run(check)
	print("UNIT_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

func _save_tests() -> void:
	var path = "user://test-" + str(Time.get_ticks_usec())
	var disk = FailingStore.new(path)
	var sim = GameSimulation.new(disk)
	var account = sim.join("", "持久角色", "JS")
	sim.records[account.id].x = 780
	check(sim.command(account.id, "buy", {"item":"potion"}).ok, "durable transaction")
	var before: Dictionary = sim.records[account.id].duplicate(true)
	disk.fail = true
	check(not sim.command(account.id, "buy", {"item":"potion"}).ok, "write failure rejects transaction")
	check(sim.records[account.id].inventory == before.inventory and sim.records[account.id].money == before.money, "write failure rolls back inventory and money")
	disk.fail = false
	var restored = GameSimulation.new(SaveStore.new(path))
	var reconnect = restored.join(account.token, "不同名字", "XS")
	check(reconnect.error == "" and restored.records[account.id].name == "持久角色", "restart credential identity")
	check(restored.records[account.id].money == 88, "confirmed purchase persisted")
	check(restored.records[account.id].inventory.potion == 9, "item persisted")
	var file = FileAccess.open(path.path_join("world.json"), FileAccess.WRITE)
	file.store_string("corrupt"); file.close()
	var recovery = GameSimulation.new(SaveStore.new(path))
	check(recovery.fatal_error == "" and recovery.records.size() == 1, "valid backup recovery")
	check(recovery.checkpoint(), "recovered state can save without backing up corrupt primary")
	for name in ["world.json", "world.backup.json"]:
		file = FileAccess.open(path.path_join(name), FileAccess.WRITE)
		file.store_string("corrupt"); file.close()
	var invalid = GameSimulation.new(SaveStore.new(path))
	check(invalid.fatal_error != "", "all corrupted saves fail closed")
	for name in ["world.json", "world.backup.json"]: DirAccess.remove_absolute(path.path_join(name))
	DirAccess.remove_absolute(path)

func _chapter_tests() -> void:
	var sim = GameSimulation.new()
	sim.rng.seed = 771
	var identity = sim.join("", "完整篇章", "JS")
	var id: String = identity.id
	for qid in Catalog.table("quests"):
		var q: Dictionary = Catalog.table("quests")[qid]
		sim.records[id].map = "bajun"
		sim.records[id].x = 380
		sim.records[id].y = 600
		check(sim.command(id, "quest", {"quest": qid}).ok, "chapter accept " + qid)
		if q.type in ["kill", "collect"]:
			var attempts = 0
			while attempts < 150:
				var p: Dictionary = sim.records[id]
				var progress = int(p.inventory.get(q.target, 0)) if q.type == "collect" else int(p.quests[qid].progress)
				if progress >= int(q.count): break
				var kind: String = "snake" if q.type == "collect" else q.target
				var monster_id = ""
				for mid in sim.monsters:
					if sim.monsters[mid].kind == kind: monster_id = mid; break
				var m: Dictionary = sim.monsters[monster_id]
				m.hp = Catalog.table("monsters")[kind].hp
				m.dead = false
				p.map = m.map
				p.x = m.x - 50
				p.y = m.y
				var attacks = 0
				while not sim.monsters[monster_id].dead and attacks < 120:
					sim.clock += 1.0
					var result = sim.command(id, "skill", {"skill":"slash", "target":monster_id})
					if not result.ok: fail_chapter(result.message); return
					attacks += 1
				for drop_id in sim.drops.keys():
					if not sim.command(id, "pickup", {"drop":drop_id}).ok: fail_chapter("loot"); return
				attempts += 1
			check(attempts < 150, "chapter objective reachable " + qid)
		sim.records[id].map = "bajun"
		sim.records[id].x = 380
		sim.records[id].y = 600
		check(sim.command(id, "quest", {"quest":qid}).ok, "chapter complete " + qid)
	check(sim.records[id].quests.size() == 6, "six quests complete through real command path")
	sim.disconnect_player(id)
	check(sim.join(identity.token, "", "JS").id == id, "finished chapter reconnect")

func fail_chapter(message: String) -> void:
	check(false, "chapter failed: " + message)

func _boundary_tests() -> void:
	var sim = GameSimulation.new()
	var ids: Array = []
	for i in range(4): ids.append(sim.join("", "边界%s" % i, "JS").id)
	check(sim.join("", "第五人", "JS").error == "服务器人数已满", "fifth player rejected")
	var id: String = ids[0]
	sim.records[id].map = "west"
	sim.records[id].x = 600
	sim.records[id].inventory = {}
	for i in range(24): InventoryRules.add_item(sim.records[id], "iron_sword")
	sim.drops["capacity"] = {"id":"capacity", "item":"herb", "owner":id, "map":"west", "x":600,"y":600,"count":1}
	check(not sim.command(id, "pickup", {"drop":"capacity"}).ok and sim.drops.has("capacity"), "full bag preserves drop")
	var hp_before = sim.monsters["west:0"].hp
	sim.records[id].mp = 0
	check(not sim.command(id, "skill", {"skill":"blood","target":"west:0"}).ok and sim.monsters["west:0"].hp == hp_before, "insufficient resource has no damage")
	sim.records[id].x = 100
	check(not sim.command(id, "skill", {"skill":"slash","target":"west:0"}).ok, "out of range")
	sim.records[id].dead = true
	sim.records[id].hp = 0
	check(not sim.command(id, "skill", {"skill":"slash","target":"west:0"}).ok, "dead player cannot attack")
	check(sim.command(id, "respawn", {}).ok and sim.records[id].map == "bajun" and not sim.records[id].dead, "death returns to town")
	check(sim.command(id, "invite", {"target":ids[1]}).ok, "invite before expiry")
	sim.clock += 31
	check(not sim.command(ids[1], "accept", {}).ok, "expired invite rejected")

func _feedback_tests() -> void:
	var sim = GameSimulation.new()
	var login = sim.join("", "反馈测试", "JS")
	var id: String = login.id
	var p: Dictionary = sim.records[id]
	p.map = "camp"
	var boss: Dictionary = {}
	for m in sim.monsters.values():
		if m.kind == "boss": boss = m
	p.x = boss.x + 30
	p.y = boss.y
	sim.clock = 10
	sim._tick_monster(boss, 0.016)
	check(boss.windup == 11 and boss.windup_started == 10, "boss telegraph duration")
	var origin: float = boss.x
	p.x += 250
	sim.clock = 10.5
	sim._tick_monster(boss, 0.016)
	check(boss.x == origin and not boss.moving, "windup stays at announced origin")
	var hp = p.hp
	sim.clock = 11
	sim._tick_monster(boss, 0.016)
	check(p.hp == hp and boss.windup == 0, "moving outside telegraph dodges")
	boss.attack_at = 0
	p.x = origin
	sim._tick_monster(boss, 0.016)
	p.y = boss.y - 71
	sim.clock += 1
	sim._tick_monster(boss, 0.016)
	check(p.hp == hp, "jump above hit height dodges")
	boss.attack_at = 0
	p.y = boss.y
	sim._tick_monster(boss, 0.016)
	p.x = origin + 170
	p.y = boss.y - 70
	sim.clock += 1
	sim._tick_monster(boss, 0.016)
	check(p.hp < hp and p.hurt_until > sim.clock, "telegraph boundary hit and hurt state")
	p.x = boss.x
	p.y = boss.y
	check(sim.command(id, "skill", {"skill":"slash", "target":boss.id}).ok, "attack accepted")
	p = sim.records[id]
	check(p.anim_started == sim.clock and p.cast_skill == "slash", "attack starts at cast time")
	var ready_at = p.cooldowns.slash
	sim.disconnect_player(id)
	sim.join(login.token, "反馈测试", "JS")
	# Existing-session reconnect must retain cooldowns; new bodies reset on server restart.
	check(sim.records[id].cooldowns.slash == ready_at, "disconnect preserves cooldown")
	check(sim.monsters[boss.id].hurt_until > sim.clock, "monster hurt feedback")
	sim._kill(p, sim.monsters[boss.id])
	var money = p.money
	var drops = sim.drops.size()
	sim._kill(p, sim.monsters[boss.id])
	check(p.money == money and sim.drops.size() == drops, "death reward once")
	check(not sim.command(id, "skill", {"skill":"slash", "target":boss.id}).ok, "dead monster cannot be attacked")
	var stored = sim.persistent_state()
	check(not stored.records[id].has("anim_started") and not stored.records[id].has("death_started"), "visual states excluded from save")
	stored.content = "0.1.0"
	var payload = JSON.stringify(stored)
	check(not SaveStore.decode(JSON.stringify({"payload":payload,"sha256":payload.sha256_text()})).is_empty(), "v1 previous content save compatible")
	p = sim.records[id]
	p.dead = true
	p.hp = 0
	p.death_started = sim.clock
	check(sim.command(id, "respawn", {}).ok, "revive after animation")
	check(sim.records[id].death_started == 0 and sim.records[id].anim_until == 0, "revive resets visual state")
