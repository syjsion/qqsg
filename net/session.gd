extends Node

signal reconnecting(message: String)
signal connected
signal failed(message: String)
signal snapshot_received(state: Dictionary)
signal result_received(result: Dictionary)
signal event_received(event: Dictionary)
signal chat_received(sender_name: String, message: String)

var simulation: GameSimulation
var is_host = false
var player_id = ""
var latest: Dictionary = {}
var server_address = ""
var server_port = 24567
var credential_path = "user://credentials.json"
var profile = "default"
var pending_name = ""
var pending_job = "JS"
var request_seq = 0
var input_seq = 0
var peers: Dictionary = {}
var pending_peers: Dictionary = {}
var request_cache: Dictionary = {}
var last_request: Dictionary = {}
var chat_at: Dictionary = {}
var send_counter = 0
var handshake_started = 0
var welcomed = false
var reconnect_allowed = false
var retry_attempt = 0
var retry_at = 0
const RETRY_DELAYS = [1, 2, 4, 8, 8]
var shutting_down = false
var control_dir = ""
var instance_id = ""


func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func(): _transport_failed("连接失败，请检查地址、UDP 端口和服务器"))
	multiplayer.server_disconnected.connect(_on_disconnected)
	multiplayer.peer_connected.connect(func(peer):
		if is_host: pending_peers[peer] = Time.get_ticks_msec())
	multiplayer.peer_disconnected.connect(_peer_left)

static func arguments() -> Dictionary:
	var values: Dictionary = {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var parts = arg.substr(2).split("=", true, 1)
			values[parts[0]] = parts[1]
	return values

func start_server() -> bool:
	var args = arguments()
	var options = {"port": 24567, "max_players": 4, "xp_multiplier": 1.0,
		"drop_multiplier": 1.0, "data_dir": "user://server", "bind_address": "*"}
	var config_path: String = args.get("config", "res://deploy/server.json")
	if not FileAccess.file_exists(config_path):
		push_error("配置文件不存在：" + config_path)
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(config_path))
	if not parsed is Dictionary:
		push_error("服务器配置不是有效 JSON")
		return false
	options.merge(parsed, true)
	for key in ["port", "data_dir", "bind_address"]:
		if args.has(key): options[key] = args[key]
	var port = int(options.port)
	if port < 1024 or port > 65535 or int(options.max_players) < 1 or int(options.max_players) > 4 or float(options.xp_multiplier) <= 0 or float(options.xp_multiplier) > 100 or float(options.drop_multiplier) < 0 or float(options.drop_multiplier) > 10:
		push_error("无效配置：端口 1024–65535、人数 1–4、经验倍率 (0,100]、掉落倍率 [0,10]")
		return false
	var peer = ENetMultiplayerPeer.new()
	peer.set_bind_ip(str(options.bind_address))
	var error = peer.create_server(port, 12, 3)
	if error != OK:
		push_error("无法监听 UDP %s，错误 %s" % [port, error])
		return false
	simulation = GameSimulation.new(SaveStore.new(str(options.data_dir)), options)
	if simulation.fatal_error != "" or not simulation.checkpoint():
		push_error("服务器存档不可用：" + simulation.fatal_error + simulation.store.error)
		peer.close()
		return false
	multiplayer.multiplayer_peer = peer
	is_host = true
	control_dir = str(args.get("control-dir", ""))
	instance_id = str(args.get("instance-id", ""))
	if control_dir != "" and instance_id != "":
		_control_write("ready.json", {"instance": instance_id, "pid": OS.get_process_id(), "port": port, "data_dir": ProjectSettings.globalize_path(str(options.data_dir))})
	print("SERVER_READY port=%s content=%s max_players=%s" % [port, Catalog.CONTENT, options.max_players])
	return true

func connect_game(address: String, port: int, display_name: String, job: String, selected_profile: String = "default") -> void:
	disconnect_game()
	server_address = address.strip_edges()
	server_port = port
	pending_name = display_name
	pending_job = job
	profile = selected_profile
	_open_connection()

func _open_connection() -> void:
	request_seq = 0
	input_seq = 0
	welcome_reset()
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(server_address, server_port, 3)
	if error != OK:
		_transport_failed("无法建立连接，错误 %s" % error)
		return
	multiplayer.multiplayer_peer = peer
	handshake_started = Time.get_ticks_msec()

func welcome_reset() -> void:
	welcomed = false
	player_id = ""
	latest = {}

func disconnect_game() -> void:
	reconnect_allowed = false
	retry_attempt = 0
	retry_at = 0
	_close_transport()

func _close_transport() -> void:
	handshake_started = 0
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	welcome_reset()

func _on_disconnected() -> void:
	_transport_failed("服务器连接已断开")

func _transport_failed(message: String) -> void:
	_close_transport()
	if retry_at > 0: return
	if reconnect_allowed and retry_attempt < RETRY_DELAYS.size():
		var delay: int = RETRY_DELAYS[retry_attempt]
		retry_attempt += 1
		retry_at = Time.get_ticks_msec() + delay * 1000
		reconnecting.emit("%s，%d 秒后重连（%d/5）" % [message, delay, retry_attempt])
	else:
		disconnect_game()
		failed.emit(message + "。请检查服务器后重新连接。")

func _on_connected() -> void:
	var credentials = _read_credentials()
	var token: String = credentials.get(_credential_key(), "")
	hello.rpc_id(1, Catalog.PROTOCOL, Catalog.CONTENT, token, pending_name, pending_job)

func _credential_key() -> String:
	return "%s:%s/%s" % [server_address, server_port, profile]

func _read_credentials() -> Dictionary:
	if FileAccess.file_exists(credential_path):
		var value = JSON.parse_string(FileAccess.get_file_as_string(credential_path))
		if value is Dictionary: return value
	return {}

@rpc("any_peer", "call_remote", "reliable", 0)
func hello(protocol: int, content: String, token: String, display_name: String, job: String) -> void:
	if not is_host: return
	var peer = multiplayer.get_remote_sender_id()
	if peers.has(peer): return
	if protocol != Catalog.PROTOCOL or content != Catalog.CONTENT:
		_reject(peer, "版本不匹配，请下载相同版本客户端")
		return
	if token.length() > 128 or display_name.length() > 16:
		_reject(peer, "无效角色信息")
		return
	var result = simulation.join(token, display_name, job)
	if result.error != "":
		_reject(peer, result.error)
		return
	peers[peer] = result.id
	pending_peers.erase(peer)
	request_cache[peer] = {}
	last_request[peer] = 0
	welcome.rpc_id(peer, result.id, result.token)
	_send_snapshot(peer)
	print("PLAYER_JOIN online=%d" % peers.size())

func _reject(peer: int, reason: String) -> void:
	rejected.rpc_id(peer, reason)
	get_tree().create_timer(0.3).timeout.connect(func():
		if is_host and peer in multiplayer.get_peers(): multiplayer.multiplayer_peer.disconnect_peer(peer))

@rpc("authority", "call_remote", "reliable", 0)
func rejected(reason: String) -> void:
	disconnect_game()
	failed.emit(reason)

@rpc("authority", "call_remote", "reliable", 0)
func welcome(id: String, token: String) -> void:
	var credentials = _read_credentials()
	credentials[_credential_key()] = token
	var f = FileAccess.open(credential_path + ".tmp", FileAccess.WRITE)
	if f == null:
		failed.emit("角色凭据无法保存，请检查用户目录权限")
		disconnect_game()
		return
	f.store_string(JSON.stringify(credentials))
	f.flush()
	var write_error = f.get_error()
	f.close()
	if write_error != OK or DirAccess.rename_absolute(credential_path + ".tmp", credential_path) != OK:
		failed.emit("角色凭据保存失败，已停止登录")
		disconnect_game()
		return
	player_id = id
	welcomed = true
	reconnect_allowed = true
	retry_attempt = 0
	retry_at = 0
	handshake_started = 0
	connected.emit()

func send_input(axis: Vector2, jump: bool) -> int:
	if not welcomed: return 0
	input_seq += 1
	move_intent.rpc_id(1, input_seq, axis, jump)
	return input_seq

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func move_intent(sequence: int, axis: Vector2, jump: bool) -> void:
	var peer = multiplayer.get_remote_sender_id()
	if is_host and peers.has(peer): simulation.input(peers[peer], sequence, axis, jump)

func request(operation: String, payload: Dictionary = {}) -> int:
	if not welcomed: return 0
	request_seq += 1
	intent.rpc_id(1, request_seq, operation, payload)
	return request_seq

@rpc("any_peer", "call_remote", "reliable", 0)
func intent(sequence: int, operation: String, payload: Dictionary) -> void:
	var peer = multiplayer.get_remote_sender_id()
	if not is_host or not peers.has(peer): return
	if JSON.stringify(payload).length() > 2048 or sequence < 1: return
	if request_cache[peer].has(sequence):
		response.rpc_id(peer, request_cache[peer][sequence])
		return
	if sequence <= int(last_request[peer]):
		response.rpc_id(peer, {"seq": sequence, "ok": false, "message": "请求已过期"})
		return
	last_request[peer] = sequence
	var result = simulation.command(peers[peer], operation, payload)
	result.seq = sequence
	request_cache[peer][sequence] = result
	if request_cache[peer].size() > 64:
		request_cache[peer].erase(request_cache[peer].keys()[0])
	response.rpc_id(peer, result)
	# Reliable state follows the transaction, so inventory/quest UI updates immediately.
	state_update.rpc_id(peer, simulation.snapshot(peers[peer]))
	_flush_events()

@rpc("authority", "call_remote", "reliable", 0)
func response(result: Dictionary) -> void:
	result_received.emit(result)

@rpc("authority", "call_remote", "unreliable_ordered", 2)
func snapshot(compressed: PackedByteArray) -> void:
	# Snapshots are small compressed packets instead of fragmented large dictionaries.
	var decoded = bytes_to_var(compressed.decompress_dynamic(262144, FileAccess.COMPRESSION_DEFLATE))
	if decoded is Dictionary: _accept_state(decoded)

@rpc("authority", "call_remote", "reliable", 0)
func state_update(state: Dictionary) -> void:
	_accept_state(state)

func _accept_state(state: Dictionary) -> void:
	if not welcomed: return
	if not latest.is_empty() and float(state.time) < float(latest.time): return
	if not latest.is_empty() and float(state.time) == float(latest.time) and int(state.self.revision) < int(latest.self.revision): return
	latest = state
	snapshot_received.emit(state)

@rpc("authority", "call_remote", "reliable", 0)
func world_event(event: Dictionary) -> void:
	event_received.emit(event)

func send_chat(message: String) -> void:
	if welcomed: chat.rpc_id(1, message.left(160))

@rpc("any_peer", "call_remote", "reliable", 0)
func chat(message: String) -> void:
	var peer = multiplayer.get_remote_sender_id()
	if not is_host or not peers.has(peer) or message.length() > 160: return
	if simulation.clock < float(chat_at.get(peer, 0)): return
	chat_at[peer] = simulation.clock + 0.5
	var sender_name: String = simulation.records[peers[peer]].name
	for recipient in peers: chat_message.rpc_id(recipient, sender_name, message.strip_edges())

@rpc("authority", "call_remote", "reliable", 0)
func chat_message(sender_name: String, message: String) -> void:
	chat_received.emit(sender_name, message)

func _peer_left(peer: int) -> void:
	if not is_host: return
	if peers.has(peer):
		simulation.disconnect_player(peers[peer])
		peers.erase(peer)
	pending_peers.erase(peer)
	request_cache.erase(peer)
	last_request.erase(peer)
	chat_at.erase(peer)

func _physics_process(dt: float) -> void:
	if not is_host:
		if handshake_started > 0 and not welcomed and Time.get_ticks_msec() - handshake_started > 8000:
			_transport_failed("连接超时，请确认服务器已启动且 UDP 端口可达")
		if retry_at > 0 and Time.get_ticks_msec() >= retry_at:
			retry_at = 0
			reconnecting.emit("正在重连（%d/5）……" % retry_attempt)
			_open_connection()
		return
	_poll_control()
	if shutting_down: return
	simulation.tick(dt)
	send_counter += 1
	if send_counter % 3 == 0:
		for peer in peers:
			_send_snapshot(peer)
	_flush_events()
	for peer in pending_peers.keys():
		if Time.get_ticks_msec() - int(pending_peers[peer]) > 5000:
			multiplayer.multiplayer_peer.disconnect_peer(peer)
			pending_peers.erase(peer)

func _send_snapshot(peer: int) -> void:
	var state = simulation.snapshot(peers[peer])
	var compressed = var_to_bytes(state).compress(FileAccess.COMPRESSION_DEFLATE)
	if compressed.size() <= 1200:
		snapshot.rpc_id(peer, compressed)
	elif send_counter % 6 == 0:
		# Large inventories use a reliable 10 Hz fallback, avoiding UDP fragmentation loss.
		state_update.rpc_id(peer, state)

func _flush_events() -> void:
	for event in simulation.events:
		for peer in peers:
			if simulation.records[peers[peer]].map == event.map: world_event.rpc_id(peer, event)
	simulation.events.clear()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_host and simulation:
		simulation.checkpoint()

# Local launcher control only. No network management RPC is exposed.
func _control_write(name: String, value: Dictionary) -> bool:
	var path = control_dir.path_join(name)
	var f = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if f == null: return false
	f.store_string(JSON.stringify(value))
	f.flush()
	var error = f.get_error()
	f.close()
	return error == OK and DirAccess.rename_absolute(path + ".tmp", path) == OK

func _poll_control() -> void:
	if control_dir == "" or instance_id == "": return
	var path = control_dir.path_join("stop.json")
	if not FileAccess.file_exists(path): return
	var parser = JSON.new()
	var valid = parser.parse(FileAccess.get_file_as_string(path)) == OK
	DirAccess.remove_absolute(path)
	if not valid or not parser.data is Dictionary or parser.data.get("instance", "") != instance_id: return
	if not simulation.checkpoint():
		_control_write("stop-result.json", {"ok": false, "error": simulation.store.error})
		return
	_control_write("stop-result.json", {"ok": true})
	shutting_down = true
	print("SERVER_STOPPED saved=true")
	get_tree().quit()
