extends Node
var phase = 0
var index = 0
var elapsed = 0.0
var cid = ""
var added = ""
var sequence = 0
var rejected = false
var retried = false
var mismatch = false

func require(condition: bool, message: String) -> bool:
	if condition: return true
	push_error("COMPANION_NETWORK_FAIL "+message); get_tree().quit(1); return false

func _ready() -> void:
	var args = Session.arguments(); index = int(args.index)
	Session.credential_path = str(args.work).path_join("credentials%d.json" % index)
	Session.failed.connect(func(message): push_error(message); get_tree().quit(1))
	Session.reconnecting.connect(func(_message): retried = true; print("COMPANION_RETRY"))
	Session.result_received.connect(func(result):
		if not result.ok and result.message.contains("副将状态已变化"): rejected = true)
	Session.connect_game("127.0.0.1",int(args.port),"副将联网%d" % index,"JS","companions")

func _physics_process(dt: float) -> void:
	elapsed += dt
	if elapsed>65: require(false,"timeout phase %d" % phase); return
	if not Session.welcomed or Session.latest.is_empty(): return
	var p: Dictionary = Session.latest.self
	if phase == 0:
		Session.send_input(Vector2.RIGHT if p.x < 300 else Vector2.ZERO,false)
		if p.x >= 300:
			cid = p.active_companion
			sequence = Session.request("companion_recruit",{"kind":"huangzhong","expected_revision":0})
			phase = 1
	elif phase == 1 and p.companions.size() == 2:
		if not require(p.inventory.recruit_token == 1,"one token consumed"): return
		for id in p.companions:
			if id != cid: added = id
		Session.intent.rpc_id(1,sequence,"companion_recruit",{"kind":"huangzhong","expected_revision":0})
		Session.request("companion_recruit",{"kind":"huangzhong","expected_revision":0})
		phase = 2
	elif phase == 2 and rejected and Session.latest.companions.size() == 4:
		if not require(p.companions.size() == 2 and p.inventory.recruit_token == 1,"replay cannot duplicate recruit"): return
		if not require(Session.latest.companions.all(func(c): return c.entity_type == "companion" and c.owner in Session.latest.roster.map(func(a): return a.id)),"four owner-scoped entities"): return
		print("COMPANION_PHASE_READY index=%d" % index); phase = 3; rejected = false
	elif phase == 3 and p.map == "camp":
		if index == 0: Session.request("skill",{"skill":"slash","target":"camp:4"})
		phase = 4
	elif phase == 4:
		var tokens: Array = Session.latest.drops.filter(func(d): return d.item == "recruit_token")
		var owned: Array = tokens.filter(func(d): return d.owner == p.id)
		if not owned.is_empty():
			if not require(owned.size() == 1,"personal boss recruit drop"): return
			Session.request("pickup",{"drop":owned[0].id}); phase = 5
	elif phase == 5 and p.inventory.recruit_token == 2:
		print("COMPANION_RESTART_READY index=%d" % index); phase = 6
	elif phase == 6 and retried:
		if not require(p.companions.size() == 2 and p.companions.has(added) and p.active_companion == cid and p.inventory.recruit_token == 2 and p.companion_mode == "follow","restart identity collection deployment and rewards"): return
		Session.request("companion_recruit",{"kind":"huatuo","expected_revision":0}); phase = 7
	elif phase == 7 and rejected:
		if not require(p.companions.size() == 2 and p.inventory.recruit_token == 2,"restart stale revision rejected"): return
		print("COMPANION_BOT_OK index=%d" % index)
		Session.disconnect_game(); get_tree().quit()
