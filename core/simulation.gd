class_name GameSimulation
extends RefCounted

var records: Dictionary = {}
var tokens: Dictionary = {}
var online: Array[String] = []
var monsters: Dictionary = {}
var drops: Dictionary = {}
var invites: Dictionary = {}
var events: Array[Dictionary] = []
var inputs: Dictionary = {}
var clock = 0.0
var save_clock = 0.0
var next_drop = 0
var loot_turn = 0
var rng = RandomNumberGenerator.new()
var store: SaveStore
var config: Dictionary
var fatal_error = ""
var enhancement_result: Dictionary = {}

func _init(save_store: SaveStore = null, options: Dictionary = {}) -> void:
	Catalog.load_data()
	store = save_store
	config = {"max_players": 4, "xp_multiplier": 1.0, "drop_multiplier": 1.0}
	config.merge(options, true)
	rng.randomize()
	if store:
		var state = store.read()
		if store.error != "":
			fatal_error = store.error
			return
		if not state.is_empty():
			records = state.records
			tokens = state.tokens
			drops = state.drops
			next_drop = int(state.get("next_drop", 0))
			loot_turn = int(state.get("loot_turn", 0))
			for p in records.values():
				_initialize_body(p)
	for map_id in Catalog.table("maps"):
		var map: Dictionary = Catalog.table("maps")[map_id]
		for i in range(map.spawns.size()):
			var spawn: Dictionary = map.spawns[i]
			var kind: Dictionary = Catalog.table("monsters")[spawn.kind]
			var id = "%s:%s" % [map_id, i]
			monsters[id] = {"id": id, "kind": spawn.kind, "name": kind.name, "map": map_id,
				"x": float(spawn.x), "y": float(spawn.y), "home": float(spawn.x), "hp": kind.hp,
				"max_hp": kind.hp, "facing": -1, "moving": false, "dead": false,
				"respawn_at": 0.0, "attack_at": 0.0, "windup": 0.0, "target": "", "anim_until": 0.0, "anim_started": 0.0,
				"hurt_until": 0.0, "death_started": 0.0, "windup_started": 0.0, "attack_range": 170 if spawn.kind == "boss" else 85}

func _initialize_body(p: Dictionary) -> void:
	var map: Dictionary = Catalog.table("maps")[p.map]
	var stats = Catalog.stats(p)
	p.x = float(map.spawn[0])
	p.y = float(map.spawn[1])
	p.vy = 0.0
	p.facing = 1
	p.grounded = true
	p.climbing = false
	p.moving = false
	p.hp = clampi(int(p.get("hp", stats.hp)), 0, stats.hp)
	p.mp = clampi(int(p.get("mp", stats.mp)), 0, stats.mp)
	p.dead = p.hp <= 0
	p.cooldowns = {}
	p.party = ""
	p.anim_until = 0.0
	p.anim_started = 0.0
	p.hurt_until = 0.0
	p.death_started = 0.0
	p.cast_skill = ""
	p.combat_until = 0.0
	p.regen_at = 0.0
	p.input_seq = 0

func persistent_state() -> Dictionary:
	var saved: Dictionary = {}
	for id in records:
		var p: Dictionary = records[id]
		var entry = {}
		for key in ["id", "name", "job", "level", "xp", "money", "map", "inventory", "equipment", "gear", "quests", "kills", "revision", "hp", "mp"]:
			entry[key] = p[key]
		saved[id] = entry
	return {"version": Catalog.SAVE_VERSION, "content": Catalog.CONTENT, "records": saved,
		"tokens": tokens, "drops": drops, "next_drop": next_drop, "loot_turn": loot_turn}

func checkpoint() -> bool:
	return store == null or store.write(persistent_state())

func join(token: String, display_name: String, job: String) -> Dictionary:
	if fatal_error != "":
		return {"error": fatal_error}
	if online.size() >= int(config.max_players):
		return {"error": "服务器人数已满"}
	var id: String = tokens.get(token.sha256_text(), "") if token != "" else ""
	if token != "" and id == "":
		return {"error": "角色凭据无效，请恢复正确凭据或建立新的本地档案"}
	if id in online:
		return {"error": "该角色已经在线"}
	if id == "":
		if job not in ["JS", "XS"] or display_name.strip_edges().length() < 1 or display_name.length() > 16 or display_name.contains("\n"):
			return {"error": "请输入 1–16 字角色名并选择职业"}
		var crypto = Crypto.new()
		id = crypto.generate_random_bytes(12).hex_encode()
		token = crypto.generate_random_bytes(32).hex_encode()
		records[id] = Catalog.new_character(id, display_name.strip_edges(), job)
		_initialize_body(records[id])
		tokens[token.sha256_text()] = id
		if not checkpoint():
			records.erase(id)
			tokens.erase(token.sha256_text())
			return {"error": "创建角色失败：存档不可写"}
	online.append(id)
	inputs[id] = {"axis": Vector2.ZERO, "jump": false, "time": clock}
	records[id].input_seq = 0
	return {"id": id, "token": token, "error": ""}

func disconnect_player(id: String) -> void:
	online.erase(id)
	inputs.erase(id)
	invites.erase(id)
	if records.has(id):
		records[id].moving = false
	checkpoint()

func input(id: String, seq: int, axis: Vector2, jump: bool) -> void:
	if id not in online or seq <= int(records[id].input_seq) or not axis.is_finite():
		return
	records[id].input_seq = seq
	inputs[id] = {"axis": axis.clamp(Vector2(-1, -1), Vector2(1, 1)),
		"jump": jump or inputs.get(id, {}).get("jump", false), "time": clock}

func tick(dt: float) -> void:
	clock += dt
	save_clock += dt
	for id in online:
		var p: Dictionary = records[id]
		var control: Dictionary = inputs[id]
		var axis: Vector2 = control.axis if clock - float(control.time) < 0.3 else Vector2.ZERO
		MovementRules.step(p, axis, control.jump, dt, Catalog.table("maps")[p.map])
		control.jump = false
		if clock >= float(p.regen_at) and clock > float(p.combat_until) and not p.dead:
			var stats = Catalog.stats(p)
			p.hp = mini(stats.hp, int(p.hp) + (25 if p.map == "bajun" else 4))
			p.mp = mini(stats.mp, int(p.mp) + (25 if p.map == "bajun" else 5))
			p.regen_at = clock + 2.0
	for m in monsters.values():
		_tick_monster(m, dt)
	if save_clock >= 30:
		save_clock = 0
		if not checkpoint():
			push_error("自动保存失败：" + store.error)

func _tick_monster(m: Dictionary, dt: float) -> void:
	var def: Dictionary = Catalog.table("monsters")[m.kind]
	if m.dead:
		if clock >= float(m.respawn_at):
			m.dead = false
			m.hp = def.hp
			m.x = m.home
			m.target = ""
			m.windup = 0.0
			m.death_started = 0.0
			m.hurt_until = 0.0
			m.anim_until = 0.0
		return
	# A telegraphed attack stays at its announced position until resolution.
	if float(m.windup) > 0:
		m.moving = false
		if clock >= float(m.windup): _resolve_monster_attack(m)
		return
	var target = ""
	var distance = 460.0 if m.kind == "boss" else 300.0
	for id in online:
		var p: Dictionary = records[id]
		if p.map != m.map or p.dead or absf(float(p.y) - float(m.y)) > 75:
			continue
		var dx = absf(float(p.x) - float(m.x))
		if dx < distance:
			target = id
			distance = dx
	if absf(float(m.x) - float(m.home)) > 550:
		target = ""
	m.target = target
	m.moving = false
	if target == "":
		m.windup = 0.0
		if absf(float(m.x) - float(m.home)) > 4:
			m.facing = signf(float(m.home) - float(m.x))
			m.x += m.facing * float(def.speed) * dt
			m.moving = true
		else:
			m.x = float(m.home) + sin(clock * 0.55 + float(m.home)) * 22.0
		m.hp = minf(float(def.hp), float(m.hp) + dt * 5)
		return
	var victim: Dictionary = records[target]
	m.facing = 1 if victim.x > m.x else -1
	if distance > (100 if m.kind == "boss" else 62):
		m.x += float(m.facing) * float(def.speed) * dt
		m.moving = true
		return
	if clock < float(m.attack_at):
		return
	m.windup_started = clock
	m.windup = clock + (1.0 if m.kind == "boss" else 0.4)
	m.anim_started = clock
	m.anim_until = m.windup

func _resolve_monster_attack(m: Dictionary) -> void:
	var def: Dictionary = Catalog.table("monsters")[m.kind]
	m.windup = 0.0
	m.attack_at = clock + (2.0 if m.kind == "boss" else 1.4)
	for id in online:
		var p: Dictionary = records[id]
		if p.map != m.map or p.dead or absf(float(p.y) - float(m.y)) > 70 or absf(float(p.x) - float(m.x)) > float(m.attack_range):
			continue
		if m.kind != "boss" and id != m.target:
			continue
		var amount = maxi(1, int(def.damage) - int(Catalog.stats(p).defense))
		p.hp = maxi(0, int(p.hp) - amount)
		p.combat_until = clock + 8
		p.dead = p.hp == 0
		p.hurt_until = clock + 0.2
		if p.dead: p.death_started = clock
		_emit(m.map, "damage", id, amount)
		if p.dead:
			checkpoint()

func command(id: String, operation: String, args: Dictionary) -> Dictionary:
	enhancement_result = {}
	if id not in online:
		return {"ok": false, "message": "角色未在线"}
	# Capture state before economic operations. A failed disk commit rolls everything back.
	var before = {"records": records.duplicate(true), "monsters": monsters.duplicate(true),
		"drops": drops.duplicate(true), "invites": invites.duplicate(true), "events": events.duplicate(true),
		"next_drop": next_drop, "loot_turn": loot_turn, "rng": rng.state, "inputs": inputs.duplicate(true)}
	var message = _execute(id, operation, args)
	if message != "":
		_restore(before)
		return {"ok": false, "message": message}
	records[id].revision += 1
	if not checkpoint():
		_restore(before)
		return {"ok": false, "message": "保存失败，操作已撤销，请联系服务器管理者"}
	return {"ok": true, "message": "", "revision": records[id].revision, "enhancement":enhancement_result}

func _restore(before: Dictionary) -> void:
	records = before.records
	monsters = before.monsters
	drops = before.drops
	invites = before.invites
	events.assign(before.events)
	next_drop = before.next_drop
	loot_turn = before.loot_turn
	rng.state = before.rng
	inputs = before.inputs

func _execute(id: String, operation: String, args: Dictionary) -> String:
	var p: Dictionary = records[id]
	if operation == "respawn":
		if not p.dead:
			return "角色尚未倒下"
		p.map = "bajun"
		_initialize_body(p)
		p.hp = Catalog.stats(p).hp
		p.mp = Catalog.stats(p).mp
		p.dead = false
		return ""
	if p.dead:
		return "请先回城复活"
	match operation:
		"skill": return _skill(p, str(args.get("skill", "")), str(args.get("target", "")))
		"pickup": return _pickup(p, str(args.get("drop", "")))
		"equip":
			var result = InventoryRules.equip(p, str(args.get("gear_id", "")))
			if result == "":
				var stats = Catalog.stats(p)
				p.hp = mini(p.hp, stats.hp)
				p.mp = mini(p.mp, stats.mp)
			return result
		"use":
			var item_id = str(args.get("item", ""))
			if item_id not in ["potion", "ether"] or not p.inventory.has(item_id):
				return "没有可用药品"
			if clock < float(p.cooldowns.get("potion", 0)):
				return "药品冷却中"
			var item: Dictionary = Catalog.table("items")[item_id]
			var stats = Catalog.stats(p)
			InventoryRules.take(p.inventory, item_id)
			p.hp = mini(stats.hp, int(p.hp) + int(item.get("hp", 0)))
			p.mp = mini(stats.mp, int(p.mp) + int(item.get("mp", 0)))
			p.cooldowns.potion = clock + 3
			return ""
		"enhance":
			if not _near_npc(p, "merchant"): return "请靠近巴郡装备商人进行强化"
			if not SaveStore._integer(args.get("expected_revision")): return "无效装备修订号"
			enhancement_result = GearRules.enhance(p, str(args.get("gear_id", "")), int(args.expected_revision), rng)
			return enhancement_result.error
		"sell_gear":
			if not _near_npc(p, "merchant"): return "请靠近巴郡装备商人"
			var gid = str(args.get("gear_id", ""))
			if not p.gear.has(gid) or gid in p.equipment.values(): return "装备不存在或仍在穿戴"
			p.money += int(Catalog.table("items")[p.gear[gid].item].sell_price)
			p.gear.erase(gid)
			return ""
		"buy", "sell": return _shop(p, operation, str(args.get("item", "")))
		"quest": return _quest(p, str(args.get("quest", "")))
		"portal":
			var map: Dictionary = Catalog.table("maps")[p.map]
			for portal in map.portals:
				if absf(float(p.x) - float(portal.x)) < 95 and absf(float(p.y) - float(portal.y)) < 60:
					p.map = portal.to
					p.x = float(portal.spawn[0])
					p.y = float(portal.spawn[1])
					p.vy = 0
					inputs[p.id].axis = Vector2.ZERO
					return ""
			return "请靠近传送点"
		"invite":
			var other = str(args.get("target", ""))
			if other == id or other not in online or records[other].party != "":
				return "对方不在线或已在队伍中"
			if p.party != "" and p.party != id:
				return "只有队长可以邀请"
			p.party = id
			invites[other] = {"from": id, "until": clock + 30}
			return ""
		"accept":
			var invitation: Dictionary = invites.get(id, {})
			if invitation.is_empty() or invitation.until < clock or invitation.from not in online or p.party != "":
				return "邀请已失效"
			p.party = invitation.from
			invites.erase(id)
			return ""
		"leave_party":
			if p.party == id:
				for other in records.values():
					if other.party == id:
						other.party = ""
				for invited in invites.keys():
					if invites[invited].from == id:
						invites.erase(invited)
			p.party = ""
			return ""
	return "未知操作"

func _near_npc(p: Dictionary, npc: String) -> bool:
	for n in Catalog.table("maps")[p.map].npcs:
		if n.id == npc and absf(float(p.x) - float(n.x)) < 150 and absf(float(p.y) - float(n.y)) < 70:
			return true
	return false

func _shop(p: Dictionary, op: String, id: String) -> String:
	if not _near_npc(p, "merchant"):
		return "请靠近巴郡装备商人"
	var item: Dictionary = Catalog.table("items").get(id, {})
	if item.is_empty():
		return "物品不存在"
	if op == "buy":
		if not item.get("shop_buyable", false):
			return "该物品不在商店出售"
		if p.money < item.price:
			return "金钱不足"
		if not InventoryRules.add_item(p, id):
			return "背包已满"
		p.money -= item.price
	else:
		if not InventoryRules.take(p.inventory, id):
			return "没有该物品"
		p.money += int(item.sell_price)
	return ""

func _quest(p: Dictionary, id: String) -> String:
	if not _near_npc(p, "guide"):
		return "请靠近巴郡简雍"
	var q: Dictionary = Catalog.table("quests").get(id, {})
	if q.is_empty():
		return "任务不存在"
	var current: Dictionary = p.quests.get(id, {})
	if current.is_empty():
		if q.previous != "" and p.quests.get(q.previous, {}).get("state", "") != "done":
			return "请先完成前置任务"
		p.quests[id] = {"state": "active", "progress": 1 if q.type == "talk" else 0}
		return ""
	if current.state == "done":
		return "任务已经完成"
	var progress = int(p.inventory.get(q.target, 0)) if q.type == "collect" else int(current.progress)
	if progress < int(q.count):
		return "任务目标尚未完成"
	if q.type == "collect":
		InventoryRules.take(p.inventory, q.target, q.count)
	current.state = "done"
	p.money += int(q.money)
	_gain_exp(p, roundi(float(q.xp) * float(config.xp_multiplier)))
	_emit(p.map, "notice", p.id, 0, "完成任务：" + q.name)
	return ""

func _skill(p: Dictionary, skill_id: String, target: String) -> String:
	var skill: Dictionary = Catalog.table("skills").get(skill_id, {})
	if skill.is_empty() or skill.job != p.job:
		return "无法使用该技能"
	if p.level < skill.level:
		return "技能尚未解锁"
	if clock < float(p.cooldowns.get(skill_id, 0)) or clock < float(p.cooldowns.get("global", 0)):
		return "技能冷却中"
	if p.mp < skill.cost:
		return "体力不足"
	var stats = Catalog.stats(p)
	if skill.type == "heal":
		if target == "":
			target = p.id
		if target not in online:
			return "目标不在线"
		var ally: Dictionary = records[target]
		if target != p.id and (p.party == "" or ally.party != p.party):
			return "只能治疗自己或队友"
		if ally.map != p.map or ally.dead or _distance(p, ally) > float(skill.range):
			return "治疗目标不可达"
		var before = int(ally.hp)
		ally.hp = mini(Catalog.stats(ally).hp, int(ally.hp) + CombatRules.healing(stats, skill))
		_emit(p.map, "heal", target, int(ally.hp) - before)
	else:
		if not monsters.has(target) or monsters[target].map != p.map or monsters[target].dead:
			return "请先选择怪物"
		var m: Dictionary = monsters[target]
		if _distance(p, m) > float(skill.range) or absf(float(p.y) - float(m.y)) > 85:
			return "目标超出技能范围"
		p.facing = 1 if m.x > p.x else -1
		var damage = CombatRules.damage(stats, float(Catalog.table("monsters")[m.kind].defense), skill, rng.randf())
		m.hp = maxi(0, int(m.hp) - int(damage.amount))
		m.hurt_until = clock + 0.2
		_emit(p.map, "critical" if damage.critical else "damage", target, damage.amount)
		if skill_id == "blood":
			p.hp = mini(stats.hp, int(p.hp) + roundi(float(damage.amount) * 0.15))
		if m.hp == 0:
			_kill(p, m)
	p.mp -= skill.cost
	p.cooldowns[skill_id] = clock + float(skill.cooldown)
	p.cooldowns.global = clock + 0.35
	p.anim_started = clock
	p.cast_skill = skill_id
	p.anim_until = clock + 0.4
	p.combat_until = clock + 8
	_emit(p.map, "cast", p.id, 0, skill_id)
	return ""

static func _distance(a: Dictionary, b: Dictionary) -> float:
	return Vector2(float(a.x), float(a.y)).distance_to(Vector2(float(b.x), float(b.y)))

func _gain_exp(p: Dictionary, xp: int) -> void:
	if Catalog.gain_exp(p, xp):
		var stats = Catalog.stats(p)
		p.hp = stats.hp
		p.mp = stats.mp
		_emit(p.map, "level", p.id, p.level)

func _kill(killer: Dictionary, monster: Dictionary) -> void:
	if monster.dead: return
	monster.death_started = clock
	monster.windup = 0.0
	monster.dead = true
	monster.moving = false
	var def: Dictionary = Catalog.table("monsters")[monster.kind]
	monster.respawn_at = clock + float(def.respawn)
	var eligible: Array[String] = []
	for id in online:
		var p: Dictionary = records[id]
		if p.map == killer.map and not p.dead and _distance(p, monster) <= 900 and (id == killer.id or (killer.party != "" and p.party == killer.party)):
			eligible.append(id)
	eligible.sort()
	for id in eligible:
		var p: Dictionary = records[id]
		p.revision += 1
		_gain_exp(p, maxi(1, roundi(float(def.xp) * float(config.xp_multiplier) / eligible.size())))
		p.money += maxi(1, int(def.money) / eligible.size())
		p.kills[monster.kind] = int(p.kills.get(monster.kind, 0)) + 1
		for qid in p.quests:
			var q: Dictionary = Catalog.table("quests")[qid]
			if p.quests[qid].state == "active" and q.type == "kill" and q.target == monster.kind:
				p.quests[qid].progress = mini(q.count, int(p.quests[qid].progress) + 1)
	if eligible.is_empty(): return
	if monster.kind == "boss":
		for owner in eligible:
			for i in range(LootRules.rounds(float(config.drop_multiplier), rng)):
				for entry in LootRules.boss(records[owner].job, rng): _drop(monster, owner, entry)
	else:
		for i in range(LootRules.rounds(float(config.drop_multiplier), rng)):
			for entry in LootRules.monster(monster.kind, rng):
				var owner = eligible[loot_turn % eligible.size()]
				loot_turn += 1
				_drop(monster, owner, entry)

func _drop(monster: Dictionary, owner: String, entry: Dictionary) -> void:
	next_drop += 1
	var id = "drop_%d" % next_drop
	var d = {"id":id, "item":entry.item, "owner":owner, "map":monster.map,
		"x":monster.x + (next_drop % 7 - 3) * 18, "y":monster.y, "count":entry.count}
	if Catalog.table("items")[entry.item].has("slot"): d.gear = GearRules.create(entry.item)
	drops[id] = d

func _pickup(p: Dictionary, id: String) -> String:
	if not drops.has(id):
		return "掉落已被拾取"
	var d: Dictionary = drops[id]
	if d.owner != p.id:
		return "该掉落属于其他队友"
	if d.map != p.map or _distance(p, d) > 110:
		return "请靠近掉落物"
	if not InventoryRules.add_item(p, d.item, int(d.count), d.get("gear", {})):
		return "背包已满，掉落物仍保留"
	drops.erase(id)
	return ""

func _emit(map: String, kind: String, target: String, amount: int, text: String = "") -> void:
	events.append({"map": map, "kind": kind, "target": target, "amount": amount, "text": text})

func snapshot(id: String) -> Dictionary:
	var p: Dictionary = records[id]
	var visible: Array = []
	var roster: Array = []
	for other in online:
		var actor: Dictionary = records[other]
		var stats = Catalog.stats(actor)
		var view = {"id": other, "name": actor.name, "job": actor.job, "level": actor.level,
			"map": actor.map, "x": actor.x, "y": actor.y, "hp": actor.hp, "mp": actor.mp,
			"max_hp": stats.hp, "max_mp": stats.mp, "facing": actor.facing, "party": actor.party,
			"dead": actor.dead, "moving": actor.moving, "climbing": actor.climbing,
			"grounded": actor.grounded, "anim_until": actor.anim_until, "vy": actor.vy,
			"anim_started": actor.anim_started, "hurt_until": actor.hurt_until,
			"death_started": actor.death_started, "cast_skill": actor.cast_skill}
		roster.append(view)
		if actor.map == p.map:
			visible.append(view)
	var mobs: Array = []
	var loot: Array = []
	for m in monsters.values():
		if m.map == p.map:
			mobs.append(m.duplicate())
	for d in drops.values():
		if d.map == p.map:
			loot.append(d.duplicate())
	var own = p.duplicate(true)
	own.stats = Catalog.stats(p)
	own.next_xp = Catalog.required_exp(p.level)
	var cooldowns = {}
	for skill in p.cooldowns:
		cooldowns[skill] = maxf(0, float(p.cooldowns[skill]) - clock)
	own.cooldowns = cooldowns
	return {"time": clock, "map": p.map, "self": own, "players": visible, "monsters": mobs,
		"drops": loot, "roster": roster, "invite": invites.get(id, {}), "ack": p.input_seq}
