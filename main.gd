extends Node

func _ready() -> void:
	if "--server" in OS.get_cmdline_user_args() or OS.has_feature("dedicated_server"):
		if not Session.start_server():
			get_tree().quit(1)
	else:
		var game = load("res://client/game.gd").new()
		add_child(game)
