extends Node

class BrokenStore extends SaveStore:
	func write(_state: Dictionary) -> bool:
		error = "injected save error"
		return false

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var failures: Array = []
	Session.failed.connect(func(message): failures.append(message))
	Session.reconnect_allowed = true
	Session._transport_failed("test")
	assert(Session.retry_attempt == 1 and Session.retry_at > 0)
	Session.disconnect_game()
	assert(Session.retry_at == 0 and not Session.reconnect_allowed)
	await get_tree().create_timer(1.2).timeout
	assert(Session.handshake_started == 0)
	Session.reconnect_allowed = true
	Session.rejected("版本不匹配")
	assert(not Session.reconnect_allowed and Session.retry_at == 0)
	Session.reconnect_allowed = true
	Session.rejected("凭据无效")
	assert(not Session.reconnect_allowed and Session.retry_at == 0)
	Session.reconnect_allowed = true
	for i in range(5):
		Session.retry_at = 0
		Session._transport_failed("test")
		assert(Session.retry_attempt == i + 1)
	Session.retry_at = 0
	Session._transport_failed("test exhausted")
	assert(not Session.reconnect_allowed and Session.retry_at == 0 and failures.size() == 3)
	Session.control_dir = Session.arguments().control
	Session.instance_id = "fixture-instance"
	Session.simulation = GameSimulation.new()
	Session.simulation.store = BrokenStore.new()
	Session._control_write("stop.json", {"instance":"other-instance"})
	Session._poll_control()
	assert(not FileAccess.file_exists(Session.control_dir.path_join("stop-result.json")))
	Session._control_write("stop.json", {"instance":Session.instance_id})
	Session._poll_control()
	var result = JSON.parse_string(FileAccess.get_file_as_string(Session.control_dir.path_join("stop-result.json")))
	assert(not result.ok and result.error == "injected save error")
	print("SESSION_RESULT cancel rejection exhaustion shutdown-failure PASS")
	get_tree().quit()
