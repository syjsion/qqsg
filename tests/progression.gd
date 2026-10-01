extends RefCounted

class BrokenStore extends SaveStore:
	func write(_state: Dictionary) -> bool:
		error = "injected failure"
		return false

static func run(check: Callable) -> void:
	var sim = GameSimulation.new()
	var login = sim.join("", "强化测试", "JS")
	var id: String = login.id
	var p: Dictionary = sim.records[id]
	p.x = 780
	p.money = 10000
	p.inventory.enhance_stone = 1000
	var gid: String = p.equipment.weapon
	InventoryRules.add_item(p, "iron_sword")
	var other = ""
	for key in p.gear:
		if key not in p.equipment.values(): other = key
	var hp = p.hp
	var first = sim.command(id,"enhance",{"gear_id":gid,"expected_revision":0})
	check.call(first.ok and first.enhancement.enhanced, "+1 guaranteed")
	check.call(p.money == 9980 and p.inventory.enhance_stone == 999, "enhance exact cost")
	check.call(p.gear[gid].enhance == 1 and p.gear[other].enhance == 0, "same template independent gear")
	check.call(GearRules.stats(p.gear[gid]).physical_attack == 5 and p.hp == hp, "bonus ceil and no healing")
	var before = p.duplicate(true)
	check.call(not sim.command(id,"enhance",{"gear_id":gid,"expected_revision":0}).ok, "stale revision rejected")
	p = sim.records[id]
	check.call(p.money == before.money and p.gear == before.gear, "duplicate attempt no cost")
	check.call(sim.command(id,"equip",{"gear_id":other}).ok and sim.records[id].gear[gid].enhance == 1, "swap preserves enhancement")
	check.call(not sim.command(id,"sell_gear",{"gear_id":other}).ok, "equipped gear cannot sell")
	p = sim.records[id]
	p.gear[gid].enhance = 5
	p.gear[gid].revision = 5
	var seed_found = false
	for seed_value in range(10000):
		sim.rng.seed = seed_value
		if sim.rng.randf() >= 0.4 and sim.rng.randf() >= 0.4 and sim.rng.randf() >= 0.4:
			sim.rng.seed = seed_value
			seed_found = true
			break
	check.call(seed_found, "deterministic failure fixture")
	var money_before = p.money
	for attempt in range(3):
		var result = sim.command(id,"enhance",{"gear_id":gid,"expected_revision":5+attempt})
		check.call(result.ok and not result.enhancement.enhanced and p.gear[gid].failures == attempt+1 and p.gear[gid].enhance == 5, "failure consumes without downgrade %d" % attempt)
	check.call(GearRules.quote(p.gear[gid]).chance == 1.0, "three failures guarantees next")
	check.call(sim.command(id,"enhance",{"gear_id":gid,"expected_revision":8}).enhancement.enhanced, "pity succeeds")
	check.call(p.gear[gid].enhance == 6 and p.gear[gid].failures == 0 and p.money == money_before-1040, "pity reset and four attempts charged")
	check.call(not sim.command(id,"enhance",{"gear_id":gid,"expected_revision":9}).ok, "cap rejected")
	p = sim.records[id]
	p.x = 0
	check.call(not sim.command(id,"enhance",{"gear_id":other,"expected_revision":0}).ok, "enhancement merchant proximity")
	p = sim.records[id]; p.x = 780; p.money = 0
	check.call(not sim.command(id,"enhance",{"gear_id":other,"expected_revision":0}).ok, "insufficient money rejected")
	p = sim.records[id]; p.money = 10000; p.inventory.enhance_stone = 0
	check.call(not sim.command(id,"enhance",{"gear_id":other,"expected_revision":0}).ok, "insufficient stone rejected")
	p = sim.records[id]; p.inventory.enhance_stone = 100
	check.call(not sim.command(id,"enhance",{"gear_id":"foreign","expected_revision":0}).ok, "unowned instance rejected")
	check.call(not sim.command(id,"buy",{"item":"enhance_stone"}).ok and not sim.command(id,"buy",{"item":"camp_sword"}).ok, "new drops unavailable in shop")
	p = sim.records[id]
	before = p.duplicate(true)
	var random_before = sim.rng.state
	sim.store = BrokenStore.new()
	check.call(not sim.command(id,"enhance",{"gear_id":other,"expected_revision":0}).ok, "save failure rejects enhancement")
	check.call(sim.records[id] == before and sim.rng.state == random_before, "save failure rolls back gear resources pity RNG")
	sim.store = null
	var p2 = sim.join("", "另一人", "XS")
	check.call(not sim.command(p2.id,"equip",{"gear_id":gid}).ok, "cannot equip another player's instance")
	p = sim.records[id]
	InventoryRules.add_item(p, "jade_pattern_staff")
	var foreign_job = ""
	for key in p.gear:
		if p.gear[key].item == "jade_pattern_staff": foreign_job = key
	check.call(not sim.command(id,"equip",{"gear_id":foreign_job}).ok, "equipment level requirement")
	sim.records[id].level = 10
	check.call(not sim.command(id,"equip",{"gear_id":foreign_job}).ok, "equipment class requirement")
	_drop_tests(check)
	_migration_tests(check)

static func _drop_tests(check: Callable) -> void:
	var sim = GameSimulation.new()
	var ids: Array = []
	var boss: Dictionary = {}
	for m in sim.monsters.values():
		if m.kind == "boss": boss = m
	for i in range(4):
		var login = sim.join("", "掉落%d" % i, "JS" if i % 2 == 0 else "XS")
		ids.append(login.id)
		var p: Dictionary = sim.records[login.id]
		p.map = boss.map; p.x = boss.x; p.y = boss.y; p.party = ids[0]
	sim._kill(sim.records[ids[0]],boss)
	check.call(sim.drops.size() >= 12 and sim.drops.size() <= 16, "four eligible players each get three boss stacks")
	for id in ids:
		var owned: Array = sim.drops.values().filter(func(d): return d.owner == id)
		check.call(owned.size() in [3,4] and owned.any(func(d): return d.item == "enhance_stone" and d.count == 2), "personal guaranteed stones")
		for d in owned:
			if d.has("gear"):
				check.call(Catalog.table("items")[d.item].get("job", "") in ["",sim.records[id].job], "boss weapon matches recipient job")
	var d: Dictionary = sim.drops.values().filter(func(value): return value.has("gear"))[0]
	var owner: String = d.owner
	var gid: String = d.gear.id
	check.call(sim.command(owner,"pickup",{"drop":d.id}).ok and sim.records[owner].gear.has(gid), "pickup transfers same equipment ID")
	check.call(not sim.command(owner,"pickup",{"drop":d.id}).ok, "equipment pickup cannot duplicate")
	var unclaimed: Dictionary = sim.drops.values().filter(func(value): return value.has("gear"))[0]
	sim.records[unclaimed.owner].inventory = {"potion":24*99}
	check.call(not sim.command(unclaimed.owner,"pickup",{"drop":unclaimed.id}).ok and sim.drops.has(unclaimed.id), "full bag preserves exact ground gear")
	check.call(not sim.records[unclaimed.owner].gear.has(unclaimed.gear.id), "failed pickup does not transfer instance")
	sim.records[unclaimed.owner].inventory = {}
	boss = sim.monsters[boss.id]; boss.dead = false
	sim.drops.clear()
	sim.records[ids[1]].dead = true
	sim.records[ids[2]].map = "bajun"
	sim.records[ids[3]].x = boss.x+901
	sim._kill(sim.records[ids[0]],boss)
	check.call(sim.drops.size() in [3,4] and sim.drops.values().all(func(value): return value.owner == ids[0]), "dead distant and cross-map excluded")
	sim.records[ids[1]].dead = false
	sim.disconnect_player(ids[1])
	sim.drops.clear(); boss.dead = false
	sim._kill(sim.records[ids[0]],boss)
	check.call(sim.drops.size() in [3,4] and sim.drops.values().all(func(value): return value.owner == ids[0]), "offline member excluded")
	sim.drops.clear(); boss.dead = false; sim.config.drop_multiplier = 0
	sim._kill(sim.records[ids[0]],boss)
	check.call(sim.drops.is_empty(), "zero multiplier suppresses guaranteed loot")
	boss.dead = false; sim.config.drop_multiplier = 2
	sim._kill(sim.records[ids[0]],boss)
	check.call(sim.drops.size() in [6,7,8], "integer multiplier repeats full boss bundle")
	var rng = RandomNumberGenerator.new(); rng.seed = 7
	var one = false; var two = false; var bounded = true
	for i in range(100):
		var n = LootRules.rounds(1.5,rng)
		one = one or n == 1; two = two or n == 2
		bounded = bounded and n in [1,2]
	check.call(one and two and bounded, "fractional multiplier bounds and both outcomes")
	var def: Dictionary = Catalog.table("monsters").snake
	var old_chance = def.stone_chance
	def.stone_chance = 0
	check.call(LootRules.monster("snake",rng).size() == 1, "zero stone probability")
	def.stone_chance = 1
	check.call(LootRules.monster("snake",rng).size() == 2, "guaranteed stone probability")
	def.stone_chance = old_chance

static func _envelope(state: Dictionary) -> String:
	var payload = JSON.stringify(state)
	return JSON.stringify({"payload":payload,"sha256":payload.sha256_text()})

static func _migration_tests(check: Callable) -> void:
	var sim = GameSimulation.new()
	var login = sim.join("", "旧档", "JS")
	var id: String = login.id
	var old = sim.persistent_state().duplicate(true)
	old.version = 1; old.content = "0.1.1"
	old.records[id].erase("gear")
	old.records[id].equipment = {"weapon":"iron_sword","armor":"cloth"}
	old.records[id].inventory.iron_sword = 2
	old.drops.old_drop = {"id":"old_drop","owner":id,"item":"leather","count":1,"map":"west","x":500,"y":600}
	var raw = _envelope(old)
	var migrated = SaveStore.decode(raw)
	check.call(migrated.version == Catalog.SAVE_VERSION and migrated.records[id].gear.size() == 4, "v1 equipment count conserved")
	check.call(migrated == SaveStore.decode(raw), "migration deterministic and repeatable")
	check.call(migrated.records[id].inventory.potion == 8 and migrated.records[id].money == 100, "migration preserves stacks money")
	check.call(migrated.drops.old_drop.has("gear") and migrated.drops.old_drop.gear.enhance == 0, "legacy ground equipment migrated")
	var path = "user://migration-" + str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(path)
	var f = FileAccess.open(path.path_join("world.json"),FileAccess.WRITE); f.store_string(raw); f.close()
	var disk = SaveStore.new(path)
	var loaded = disk.read()
	check.call(loaded == migrated and disk.error == "", "legacy disk load")
	var backups = DirAccess.get_files_at(path)
	check.call(backups.size() == 2, "independent old archive created")
	var backup_path = ""
	for name in backups:
		if name.begins_with("world.v1."): backup_path = path.path_join(name)
	check.call(FileAccess.get_file_as_string(backup_path) == raw, "old archive exact bytes")
	var wrote = disk.write(loaded)
	var reopened = disk.read()
	var identical = not reopened.is_empty()
	if identical:
		identical = reopened.records[id].equipment == loaded.records[id].equipment and reopened.records[id].gear.size() == loaded.records[id].gear.size()
		for gid in loaded.records[id].gear:
			identical = identical and reopened.records[id].gear.has(gid)
			if identical:
				var a: Dictionary = loaded.records[id].gear[gid]
				var b: Dictionary = reopened.records[id].gear[gid]
				identical = a.item == b.item and int(a.enhance) == int(b.enhance) and int(a.failures) == int(b.failures) and int(a.revision) == int(b.revision)
	check.call(wrote and identical, "migrated save written and reopened")
	check.call(FileAccess.get_file_as_string(backup_path) == raw, "legacy archive survives new save")
	var instance: Dictionary = loaded.records[id].gear.values()[0]
	instance.enhance = 5; instance.failures = 3; instance.revision = 8
	check.call(disk.write(loaded) and disk.read().records[id].gear[instance.id].failures == 3, "pity and enhancement persist")
	var restored = GameSimulation.new(disk)
	check.call(restored.join(login.token,"旧档","JS").error == "", "migrated credentials reconnect")
	var malformed = old.duplicate(true); malformed.records[id].inventory.iron_sword = -1
	check.call(SaveStore.decode(_envelope(malformed)).is_empty(), "invalid migration fails closed")
	loaded.records[id].equipment.weapon = "missing"
	check.call(SaveStore.decode(_envelope(loaded)).is_empty(), "invalid instance reference rejected")
	f = FileAccess.open(path.path_join("world.json"),FileAccess.WRITE); f.store_string(raw); f.close()
	f = FileAccess.open(backup_path,FileAccess.WRITE); f.store_string("conflicting archive"); f.close()
	check.call(disk.read().is_empty() and disk.error != "", "migration archive conflict fails closed")
	check.call(FileAccess.get_file_as_string(path.path_join("world.json")) == raw, "failed migration preserves original")
	for name in DirAccess.get_files_at(path): DirAccess.remove_absolute(path.path_join(name))
	DirAccess.remove_absolute(path)
