extends Node

var elapsed = 0.0
var index = 0
var phase = 0
var saw_roster = false
var saw_chat = false
var saw_party = false
var last_sequence = 0
var finishing = false

func _ready() -> void:
	var args = Session.arguments()
	index = int(args.get("bot", 0))
	Session.credential_path = str(args["credentials"])
	Session.failed.connect(func(message): fail(message))
	Session.chat_received.connect(func(_who, message):
		if message == "集结完成": saw_chat = true)
	Session.connect_game("127.0.0.1", int(args.get("port", 24567)), "测试%s" % index, "XS" if index == 1 else "JS", "bot%s" % index)

func fail(message: String) -> void:
	push_error("BOT_FAIL %d %s" % [index, message])
	get_tree().quit(1)

func _physics_process(dt: float) -> void:
	elapsed += dt
	if elapsed > 22:
		fail("timeout phase=%d roster=%s chat=%s party=%s" % [phase, saw_roster, saw_chat, saw_party])
		return
	if Session.latest.is_empty() or not Session.welcomed or finishing: return
	var state: Dictionary = Session.latest
	var p: Dictionary = state.self
	if state.roster.size() == 4: saw_roster = true
	if p.party != "": saw_party = true
	if phase == 0:
		Session.send_input(Vector2(1,0) if float(p.x) < 375 else Vector2.ZERO, false)
		if float(p.x) >= 375:
			Session.request("quest", {"quest":"arrival"})
			phase = 1
	elif phase == 1 and p.quests.has("arrival"):
		last_sequence = Session.request("quest", {"quest":"arrival"})
		phase = 2
	elif phase == 2 and p.quests.arrival.state == "done":
		# Replay an identical request ID over the real RPC channel.
		Session.intent.rpc_id(1, last_sequence, "quest", {"quest":"arrival"})
		phase = 3
	elif phase == 3 and saw_roster:
		if int(p.money) != 130 or int(p.level) != 2 or int(p.xp) != 0:
			fail("duplicate request changed reward")
			return
		if index == 0:
			for other in state.roster:
				if other.name == "测试1": Session.request("invite", {"target":other.id})
			Session.send_chat("集结完成")
		phase = 4
	elif phase == 4:
		if index == 1 and not state.invite.is_empty() and p.party == "": Session.request("accept")
		if elapsed > 8 and saw_chat and (saw_party or index > 1):
			finishing = true
			Session.disconnect_game()
			await get_tree().create_timer(0.3).timeout
			Session.connect_game("127.0.0.1", Session.server_port, "不应改名", "JS", "bot%s" % index)
			await get_tree().create_timer(1.0).timeout
			if Session.latest.is_empty() or Session.latest.self.name != "测试%s" % index or int(Session.latest.self.money) != 130:
				fail("reconnect did not preserve identity/reward")
				return
			print("BOT_OK index=%d roster=4 movement quest replay party chat reconnect" % index)
			Session.disconnect_game()
			get_tree().quit(0)
