extends Node
var phase = 0
var elapsed = 0.0
var gid = ""
var actor_id = ""
var sequence = 0
var rejected = false
var retried = false

func _ready() -> void:
	var args = Session.arguments()
	Session.credential_path = args.credentials
	Session.failed.connect(func(message): push_error(message); get_tree().quit(1))
	Session.reconnecting.connect(func(_message): retried = true; print("ECONOMY_RETRY"))
	Session.result_received.connect(func(result):
		if not result.ok and result.message.contains("装备状态已变化"): rejected = true)
	Session.connect_game("127.0.0.1",int(args.port),"强化联网","JS","economy")

func _physics_process(dt: float) -> void:
	elapsed += dt
	if elapsed > 50:
		push_error("economy timeout phase %d" % phase)
		get_tree().quit(1)
	if not Session.welcomed or Session.latest.is_empty(): return
	var p: Dictionary = Session.latest.self
	if phase == 0:
		Session.send_input(Vector2.RIGHT if p.x < 700 else Vector2.ZERO,false)
		if p.x >= 700:
			gid = p.equipment.weapon; actor_id = p.id
			sequence = Session.request("enhance",{"gear_id":gid,"expected_revision":0})
			phase = 1
	elif phase == 1 and p.gear[gid].revision == 1:
		assert(p.money == 480 and p.inventory.enhance_stone == 9)
		Session.intent.rpc_id(1,sequence,"enhance",{"gear_id":gid,"expected_revision":0})
		Session.request("enhance",{"gear_id":gid,"expected_revision":0})
		phase = 2
	elif phase == 2 and rejected:
		assert(p.money == 480 and p.gear[gid].enhance == 1)
		print("ECONOMY_RESTART_READY")
		phase = 3; rejected = false
	elif phase == 3 and retried:
		assert(p.id == actor_id and p.gear[gid].revision == 1 and p.money == 480)
		Session.send_input(Vector2.RIGHT if p.x < 700 else Vector2.ZERO,false)
		if p.x >= 700:
			Session.request("enhance",{"gear_id":gid,"expected_revision":0})
			phase = 4
	elif phase == 4 and rejected:
		Session.request("enhance",{"gear_id":gid,"expected_revision":1})
		phase = 5
	elif phase == 5 and p.gear[gid].revision == 2:
		assert(p.gear[gid].enhance == 2 and p.money == 440 and p.inventory.enhance_stone == 7)
		print("ECONOMY_RESULT duplicate restart stale revision exact-cost PASS")
		Session.disconnect_game()
		get_tree().quit()
