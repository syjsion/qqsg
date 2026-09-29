extends Node

func _ready() -> void:
	if not Session.start_server():
		get_tree().quit(1)
		return
	var args = Session.arguments()
	if Session.simulation.records.is_empty():
		var identity = Session.simulation.join("", "强化联网", "JS")
		var p: Dictionary = Session.simulation.records[identity.id]
		p.money = 500
		p.inventory.enhance_stone = 10
		Session.simulation.disconnect_player(identity.id)
		var f = FileAccess.open(args.credentials,FileAccess.WRITE)
		f.store_string(JSON.stringify({"127.0.0.1:%s/economy" % args.port:identity.token}))
		f.close()
	print("ECONOMY_SERVER_READY")
