extends Node

func _ready() -> void:
	var args = Session.arguments()
	var mode: String = args.get("probe", "version")
	Session.multiplayer.connected_to_server.disconnect(Session._on_connected)
	Session.multiplayer.connected_to_server.connect(func():
		Session.hello.rpc_id(1, -1 if mode == "version" else Catalog.PROTOCOL, Catalog.CONTENT,
			"invalid-token" if mode == "credential" else "", "拒绝测试", "JS"))
	Session.failed.connect(func(message):
		var expected = "版本不匹配" if mode == "version" else "凭据无效" if mode == "credential" else "人数已满"
		if not message.contains(expected):
			push_error("PROBE_FAIL unexpected rejection: " + message)
			get_tree().quit(1)
		else:
			print("PROBE_OK " + mode)
			get_tree().quit(0))
	Session.connected.connect(func():
		push_error("PROBE_FAIL rejected client was accepted")
		get_tree().quit(1))
	var peer = ENetMultiplayerPeer.new()
	peer.create_client("127.0.0.1", int(args.get("port",24567)), 3)
	Session.multiplayer.multiplayer_peer = peer
	get_tree().create_timer(5).timeout.connect(func():
		push_error("PROBE_FAIL timeout")
		get_tree().quit(1))
