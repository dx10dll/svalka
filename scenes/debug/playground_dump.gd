extends "res://scenes/debug/test_scene.gd"
## Площадка этапа 3: куча мусора по сиду. Копаем руками, вытаскиваем вещи,
## смотрим на завалы. Сид кучи можно задать: -- --dump-seed=N

const PLAYER_SCENE: String = "res://scenes/player/player.tscn"

var dump: Dump
var _player: PlayerController


func _populate() -> void:
	dump = Dump.new()
	dump.name = "Dump"
	dump.dump_seed = 1
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--dump-seed="):
			dump.dump_seed = int(arg.trim_prefix("--dump-seed="))
	add_child(dump)
	var r: float = dump.config.radius
	_build_lamp(Vector3(-r - 1.5, 0.0, r * 0.4))
	_build_lamp(Vector3(r + 1.0, 0.0, -r * 0.3))
	_build_lamp(Vector3(1.5, 0.0, r + 2.5))
	_player = (load(PLAYER_SCENE) as PackedScene).instantiate()
	_player.position = Vector3(0.0, 0.05, r + 1.5)
	add_child(_player)
	_build_hint("HINT_DUMP")
