extends Node

var phase = 0
var original_id = ""
var reconnected = false
var elapsed = 0.0

func _ready() -> void:
	var args = Session.arguments()
	Session.credential_path = args.credentials
	Session.failed.connect(func(message): push_error(message); get_tree().quit(1))
	Session.reconnecting.connect(func(_message): reconnected = true; print("RETRY_WAIT"))
	Session.connect_game("127.0.0.1", int(args.port), "重连测试", "JS", "reconnect")

func _physics_process(dt: float) -> void:
	elapsed += dt
	if elapsed > 45:
		push_error("Reconnect timeout phase %d" % phase)
		get_tree().quit(1)
	if not Session.welcomed or Session.latest.is_empty(): return
	var p: Dictionary = Session.latest.self
	if phase == 0:
		original_id = p.id
		Session.send_input(Vector2.RIGHT if p.x < 375 else Vector2.ZERO, false)
		if p.x >= 375:
			Session.request("quest", {"quest":"arrival"})
			phase = 1
	elif phase == 1 and p.quests.has("arrival"):
		Session.request("quest", {"quest":"arrival"})
		phase = 2
	elif phase == 2 and p.quests.arrival.state == "done":
		print("RESTART_READY")
		phase = 3
	elif phase == 3 and reconnected:
		assert(p.id == original_id and int(p.money) == 130 and p.quests.arrival.state == "done")
		assert(Session.request_seq == 0 and Session.input_seq == 0)
		print("RECONNECT_RESULT identity rewards no-replay PASS")
		Session.disconnect_game()
		get_tree().quit()
