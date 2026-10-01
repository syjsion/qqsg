extends RefCounted

class FailingStore extends SaveStore:
	var fail = false
	func write(state: Dictionary) -> bool:
		if fail: error = "injected companion write failure"; return false
		return super.write(state)

static func call_op(sim: GameSimulation, id: String, operation: String, payload: Dictionary = {}) -> Dictionary:
	payload.expected_revision = sim.records[id].companion_revision
	return sim.command(id,operation,payload)

static func envelope(state: Dictionary) -> String:
	var payload = JSON.stringify(state)
	return JSON.stringify({"payload":payload,"sha256":payload.sha256_text()})

static func run(check: Callable) -> void:
	var sim = GameSimulation.new()
	var login = sim.join("","副将主人","JS")
	var id: String = login.id
	var p: Dictionary = sim.records[id]
	p.x = 380
	check.call(not sim.command(id,"quest",{"quest":"companion_intro"}).ok,"companion quest requires arrival")
	sim.command(id,"quest",{"quest":"arrival"}); sim.command(id,"quest",{"quest":"arrival"})
	check.call(sim.command(id,"quest",{"quest":"companion_intro"}).ok,"accept optional companion task")
	check.call(sim.command(id,"quest",{"quest":"companion_intro"}).ok and sim.records[id].companions.size() == 1,"task directly grants Zhao Yun")
	check.call(not sim.command(id,"quest",{"quest":"companion_intro"}).ok and sim.records[id].companions.size() == 1,"task reward cannot repeat")
	p = sim.records[id]; p.inventory.recruit_token = 15
	check.call(call_op(sim,id,"companion_recruit",{"kind":"zhaoyun"}).ok,"same hero may be recruited twice")
	p = sim.records[id]
	check.call(p.companions.size() == 2 and p.companions.values()[0].id != p.companions.values()[1].id,"duplicates have distinct stable instances")
	var tokens = p.inventory.recruit_token
	check.call(not sim.command(id,"companion_recruit",{"kind":"huatuo","expected_revision":0}).ok and sim.records[id].inventory.recruit_token == tokens,"stale collection revision cannot consume token")
	p = sim.records[id]; p.y = 500
	check.call(not call_op(sim,id,"companion_recruit",{"kind":"huangzhong"}).ok,"recruit checks NPC vertical distance")
	p = sim.records[id]; p.y = 600; p.x = 900
	check.call(not call_op(sim,id,"companion_recruit",{"kind":"huangzhong"}).ok,"recruit checks horizontal distance")
	p = sim.records[id]; p.x = 380
	check.call(not call_op(sim,id,"companion_recruit",{"kind":"unknown"}).ok,"invalid hero rejected")
	call_op(sim,id,"companion_recruit",{"kind":"huatuo"}); call_op(sim,id,"companion_recruit",{"kind":"huangzhong"})
	while sim.records[id].companions.size()<12: call_op(sim,id,"companion_recruit",{"kind":"zhaoyun"})
	tokens = sim.records[id].inventory.recruit_token
	check.call(not call_op(sim,id,"companion_recruit",{"kind":"huatuo"}).ok and sim.records[id].inventory.recruit_token == tokens,"full roster leaves token untouched")
	p = sim.records[id]
	var first: Dictionary = p.companions.values()[0]
	check.call(call_op(sim,id,"companion_deploy",{"companion_id":first.id}).ok,"deploy one companion")
	sim._tick_companion_body(sim.records[id],0.016)
	check.call(sim.snapshot(id).companions.size() == 1,"only one deployed entity replicated")
	check.call(not call_op(sim,id,"companion_release",{"companion_id":first.id}).ok,"deployed hero cannot be released")
	p = sim.records[id]; p.combat_until = sim.clock+8
	check.call(not call_op(sim,id,"companion_recall").ok,"recall blocked during combat")
	check.call(call_op(sim,id,"companion_mode",{"mode":"follow"}).ok,"follow mode usable in combat")
	check.call(not call_op(sim,id,"companion_mode",{"mode":"invalid"}).ok,"unknown mode rejected")
	p = sim.records[id]; p.combat_until = 0
	check.call(call_op(sim,id,"companion_recall").ok,"recall out of combat")
	check.call(call_op(sim,id,"companion_release",{"companion_id":first.id}).ok and not sim.records[id].companions.has(first.id),"release exact inactive instance")
	p = sim.records[id]
	var survivor: Dictionary = p.companions.values()[0]
	survivor.hp = 13; survivor.skill_cooldown_remaining = 1.0
	call_op(sim,id,"companion_deploy",{"companion_id":survivor.id})
	call_op(sim,id,"companion_recall")
	call_op(sim,id,"companion_deploy",{"companion_id":survivor.id})
	check.call(sim.records[id].companions[survivor.id].hp == 13 and sim.records[id].companions[survivor.id].skill_cooldown_remaining == 1.0,"recall and redeploy never refresh HP or cooldown")
	var full_task = GameSimulation.new(); var identity = full_task.join("","满栏任务","JS"); var fp: Dictionary = full_task.records[identity.id]
	fp.x = 380; fp.quests.arrival = {"state":"done","progress":1}; fp.quests.companion_intro = {"state":"active","progress":1}
	for i in range(12):
		var entry = CompanionRules.create("zhaoyun"); fp.companions[entry.id] = entry
	check.call(not full_task.command(identity.id,"quest",{"quest":"companion_intro"}).ok and full_task.records[identity.id].quests.companion_intro.state == "active","full collection preserves unclaimed task reward")
	var missing: Dictionary = CompanionRules.create("huatuo")
	check.call(not call_op(sim,id,"companion_deploy",{"companion_id":missing.id}).ok,"unowned companion cannot deploy")
	var c = CompanionRules.create("zhaoyun")
	CompanionRules.gain_exp(c,10000,3)
	check.call(c.level == 3 and c.xp == 0 and c.hp == 270,"growth stops at owner level")
	c.hp = 0; CompanionRules.gain_exp(c,100000,10)
	check.call(c.level == 10 and c.hp == 0 and c.xp == 0,"growth never revives downed hero")
	c = CompanionRules.create("huangzhong"); CompanionRules.gain_exp(c,40,10)
	check.call(c.level == 2 and c.xp == 0 and CompanionRules.stats(c).power == 12,"exact level threshold and power growth")
	var chance = Catalog.table("boss_loot").recruit_chance
	Catalog.table("boss_loot").recruit_chance = 0.0
	check.call(not LootRules.boss("JS",sim.rng).any(func(e): return e.item == "recruit_token"),"zero recruit chance")
	Catalog.table("boss_loot").recruit_chance = 1.0
	check.call(LootRules.boss("XS",sim.rng).any(func(e): return e.item == "recruit_token" and e.count == 1),"guaranteed recruit chance")
	Catalog.table("boss_loot").recruit_chance = chance
	_combat(check)
	_persistence(check)

static func _combat(check: Callable) -> void:
	var sim = GameSimulation.new()
	var login = sim.join("","战斗主人","JS")
	var id: String = login.id
	var p: Dictionary = sim.records[id]
	p.map = "west"; p.x = 600; p.y = 600; p.level = 10
	var c = CompanionRules.create("zhaoyun"); p.companions[c.id] = c; p.active_companion = c.id
	sim._tick_companion_body(p,0.01)
	sim.clock = 1
	var body: Dictionary = sim.companion_bodies[id]; body.x = 570; body.y = 600
	var m: Dictionary = sim.monsters["west:0"]
	m.target = ""; m.x = 610; m.hp = 50
	var hp = m.hp
	sim._tick_companion_action(p)
	check.call(m.hp == hp,"companion does not attack unengaged enemy")
	p.companion_target = m.id; p.combat_until = 9
	p.companion_mode = "follow"; sim._tick_companion_action(p)
	check.call(m.hp == hp,"follow mode blocks attack")
	p.companion_mode = "assist"; sim._tick_companion_action(p)
	check.call(m.hp < hp and c.skill_cooldown_remaining == 1.8,"authoritative companion attack and cooldown")
	hp = m.hp; sim._tick_companion_action(p)
	check.call(m.hp == hp,"cooldown prevents duplicate attack")
	c.skill_cooldown_remaining = 0; m.hp = 1
	var xp = p.xp
	sim._tick_companion_action(p)
	check.call(m.dead and p.kills.snake == 1 and sim.drops.size() > 0,"companion kill uses owner rewards and drops")
	check.call(c.xp == floori(float(Catalog.table("monsters").snake.xp)*0.2),"companion receives additional twenty percent XP")
	var count = sim.drops.size(); sim._tick_companion_action(p)
	check.call(sim.drops.size() == count and p.kills.snake == 1,"dead target cannot duplicate rewards")
	var ally = sim.join("","队友","XS"); sim.records[ally.id].map = "bajun"
	check.call(sim.snapshot(ally.id).companions.is_empty(),"companions filtered by map")
	m.dead = false; m.hp = 100; m.x = body.x; m.target = c.id; m.kind = "snake"; m.attack_range = 85
	p.x = 800; c.hp = 50
	sim._resolve_monster_attack(m)
	check.call(c.hp < 50 and p.hp == Catalog.stats(Catalog.new_character("x","x","JS")).hp,"ordinary monster may target companion separately")
	c.hp = 1; sim._resolve_monster_attack(m)
	check.call(c.hp == 0 and c.recovery_remaining == 20,"companion falls and starts recovery budget")
	var boss: Dictionary = sim.monsters["camp:4"]
	p.map = "camp"; p.x = boss.x; p.y = boss.y
	sim._tick_companion_body(p,0.016); sim.companion_bodies[id].x = boss.x; c.hp = 100
	var owner_hp = p.hp
	sim._resolve_monster_attack(boss)
	check.call(p.hp < owner_hp and c.hp < 100,"boss area attack hits owner and companion independently")
	p.map = "west"; sim._tick_companion_body(p,0.016); c.hp = 0; c.recovery_remaining = 20
	var progress = c.recovery_remaining
	sim._tick_companion_body(p,2)
	check.call(c.recovery_remaining == progress,"recovery paused while owner in combat")
	p.combat_until = 0; sim._tick_companion_body(p,19)
	check.call(c.hp == 0 and c.recovery_remaining == 1,"downed hero waits full recovery duration")
	sim._tick_companion_body(p,1)
	check.call(c.hp == CompanionRules.stats(c).hp,"downed companion recovers full health")
	body = sim.companion_bodies[id]; body.x = -100; body.y = 300
	sim._tick_companion_body(p,0.5); sim._tick_companion_body(p,0.5)
	check.call(absf(float(body.x)-float(p.x))<100 and absf(float(body.y)-float(p.y))<100,"lost follower returns to owner after one second")
	p.map = "bajun"; sim._tick_companion_body(p,0.016)
	check.call(sim.companion_bodies[id].map == "bajun","portal relocates companion")
	var doctor = CompanionRules.create("huatuo"); p.companions[doctor.id] = doctor; p.active_companion = doctor.id
	sim._tick_companion_body(p,0.016); sim.clock += 1; p.hp = 30
	sim.records[ally.id].x = p.x; sim.records[ally.id].y = p.y; sim.records[ally.id].hp = 20; sim.records[ally.id].party = id; p.party = id
	sim._tick_companion_action(p)
	check.call(p.hp == 50 and sim.records[ally.id].hp == 20,"healer prioritizes owner")
	p.hp = Catalog.stats(p).hp; doctor.skill_cooldown_remaining = 0; doctor.hp = 20
	sim._tick_companion_action(p)
	check.call(doctor.hp == 40,"healer next prioritizes itself")
	doctor.hp = CompanionRules.stats(doctor).hp; doctor.skill_cooldown_remaining = 0
	sim._tick_companion_action(p)
	check.call(sim.records[ally.id].hp == 40,"healer then heals same-map party member")
	doctor.skill_cooldown_remaining = 0; sim.records[ally.id].dead = true; sim.records[ally.id].hp = 0
	sim._tick_companion_action(p)
	check.call(sim.records[ally.id].hp == 0,"healer never revives downed players")
	p.dead = true; sim._tick_companion_body(p,0.016)
	check.call(sim.snapshot(id).companions.is_empty(),"dead owner stops companion simulation")
	p.dead = false; sim.disconnect_player(id)
	check.call(sim.snapshot(ally.id).companions.is_empty(),"offline owner removes companion")

static func _persistence(check: Callable) -> void:
	var path = "user://companion-tests-"+str(Time.get_ticks_usec())
	var disk = FailingStore.new(path)
	var sim = GameSimulation.new(disk)
	var login = sim.join("","持久副将","JS")
	var id: String = login.id
	var p: Dictionary = sim.records[id]; p.x = 380; p.inventory.recruit_token = 2
	check.call(call_op(sim,id,"companion_recruit",{"kind":"huangzhong"}).ok,"recruit durable transaction")
	var before = sim.persistent_state().duplicate(true)
	disk.fail = true
	check.call(not call_op(sim,id,"companion_recruit",{"kind":"huatuo"}).ok and sim.persistent_state() == before,"recruit failure rolls back collection token and revision")
	disk.fail = false; p = sim.records[id]
	var c: Dictionary = p.companions.values()[0]; p.active_companion = c.id; p.map = "west"; p.x = 600; p.y = 600
	c.hp = 17; c.skill_cooldown_remaining = 1.5; c.recovery_remaining = 9.0; p.combat_until = sim.clock+6
	sim.checkpoint()
	var restored = GameSimulation.new(SaveStore.new(path)); restored.join(login.token,"","JS")
	var loaded: Dictionary = restored.records[id].companions[c.id]
	check.call(loaded.hp == 17 and loaded.skill_cooldown_remaining == 1.5 and loaded.recovery_remaining == 9,"restart preserves health recovery cooldown")
	check.call(restored.records[id].combat_until == 6,"restart preserves remaining combat lock")
	restored.clock = 7; restored.records[id].dead = true; restored.records[id].hp = 0
	check.call(restored.command(id,"respawn",{}).ok and restored.records[id].combat_until == 7,"respawn does not reapply expired saved combat lock")
	check.call(restored.records[id].companions[c.id].hp == 17 and restored.records[id].companions[c.id].skill_cooldown_remaining == 1.5,"owner respawn preserves companion health and cooldown")
	sim._tick_companion_body(p,0.016); sim.clock = 1; c.skill_cooldown_remaining = 0; p.companion_target = "west:0"; p.combat_until = 9
	sim.monsters["west:0"].hp = 1
	sim.companion_bodies[id].x = 600; sim.companion_bodies[id].settle_until = 0
	before = sim._capture_state(); disk.fail = true
	sim._tick_companion_action(p)
	var after = sim._capture_state()
	check.call(after == before,"autonomous kill disk failure rolls back HP XP loot events RNG and cooldown")
	disk.fail = false
	sim.ai_retry_at = 0; sim._tick_companion_action(sim.records[id])
	check.call(sim.monsters["west:0"].dead,"autonomous kill retries after writable storage")
	p = sim.records[id]
	var doctor = CompanionRules.create("huatuo"); p.companions[doctor.id] = doctor; p.active_companion = doctor.id; p.hp = 20
	sim._tick_companion_body(p,0.016); sim.companion_bodies[id].settle_until = 0
	before = sim._capture_state(); disk.fail = true
	sim._tick_companion_action(p)
	check.call(sim._capture_state() == before,"autonomous healing failure restores patient HP event and skill cooldown")
	disk.fail = false; sim.ai_retry_at = 0; p = sim.records[id]
	var boss: Dictionary = sim.monsters["camp:4"]; p.map = "camp"; p.x = boss.x; p.y = boss.y
	sim._tick_companion_body(p,0.016); sim.companion_bodies[id].x = boss.x
	before = sim._capture_state(); disk.fail = true
	sim._resolve_monster_attack(boss)
	check.call(sim._capture_state() == before,"monster damage failure restores both player and companion HP")
	disk.fail = false
	var state = sim.persistent_state().duplicate(true)
	state.records[id].active_companion = "comp_missing"
	check.call(SaveStore.decode(envelope(state)).is_empty(),"invalid deployment reference rejected")
	state = sim.persistent_state().duplicate(true); state.records[id].companions[c.id].hp = -1
	check.call(SaveStore.decode(envelope(state)).is_empty(),"negative companion HP rejected")
	state = sim.persistent_state().duplicate(true); state.version = 2
	for key in ["companions","active_companion","companion_mode","companion_revision","companion_combat_remaining"]: state.records[id].erase(key)
	var raw = envelope(state)
	var migrated = SaveStore.decode(raw)
	check.call(migrated.version == 3 and migrated.records[id].companions.is_empty() and migrated.records[id].gear.size() == state.records[id].gear.size() and migrated.records[id].equipment == state.records[id].equipment,"v2 migration preserves gear and creates empty collection")
	var old_path = path+"-v2"; DirAccess.make_dir_recursive_absolute(old_path)
	var f = FileAccess.open(old_path.path_join("world.json"),FileAccess.WRITE); f.store_string(raw); f.close()
	var old_disk = SaveStore.new(old_path); old_disk.read()
	var backups: Array = Array(DirAccess.get_files_at(old_path)).filter(func(n): return n.begins_with("world.v2."))
	check.call(backups.size() == 1 and FileAccess.get_file_as_string(old_path.path_join(backups[0])) == raw,"v2 archive preserves exact original bytes")
	for directory in [path,old_path]:
		for name in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(name))
		DirAccess.remove_absolute(directory)
