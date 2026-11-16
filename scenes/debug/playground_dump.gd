extends "res://scenes/debug/test_scene.gd"
## Площадка этапа 3: куча мусора по сиду. Копаем руками, вытаскиваем вещи,
## смотрим на завалы. Сид кучи можно задать: -- --dump-seed=N

const PLAYER_SCENE: String = "res://scenes/player/player.tscn"

var dump: Dump
## Окружение свалки (есть только у большой горы)
var site: DumpSite
var van: Van
var _player: PlayerController


## Какую кучу строить (наследники подменяют).
func _config_path() -> String:
	return Dump.CONFIG_PATH


func _populate() -> void:
	dump = Dump.new()
	dump.name = "Dump"
	dump.config = load(_config_path())
	dump.dump_seed = 1
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--dump-seed="):
			dump.dump_seed = int(arg.trim_prefix("--dump-seed="))
	var started: int = Time.get_ticks_msec()
	add_child(dump)
	var r: float = dump.config.radius
	if r > 30.0:
		# большой горе мала площадка тестовой сцены: стелем землю пошире
		var ground := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(r * 6.0, 1.0, r * 6.0)
		shape.shape = box
		ground.add_child(shape)
		var mesh := MeshInstance3D.new()
		var box_mesh := BoxMesh.new()
		box_mesh.size = box.size
		mesh.mesh = box_mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.18, 0.15)
		mat.roughness = 1.0
		mesh.material_override = mat
		ground.add_child(mesh)
		ground.position.y = -0.505
		add_child(ground)
		site = DumpSite.new()
		site.name = "Site"
		add_child(site)
		site.build(r, dump.dump_seed)
		_env.ssr_enabled = true   # лужи отражают фонари и костры
		_env.ssr_max_steps = 32
	dump.prime(Vector3(0.0, 0.0, r + 1.5), 22.0)
	print("Куча: сид %d, ячеек %d, вещей %d, построена за %d мс" % [dump.dump_seed, dump.field.solid_count(),
			dump.field.sites.size(), Time.get_ticks_msec() - started])
	if site == null:
		_build_lamp(Vector3(-r - 1.5, 0.0, r * 0.4))
		_build_lamp(Vector3(r + 1.0, 0.0, -r * 0.3))
		_build_lamp(Vector3(1.5, 0.0, r + 2.5))
	_player = (load(PLAYER_SCENE) as PackedScene).instantiate()
	_player.position = Vector3(0.0, 0.05, r + (7.0 if site != null else 1.5))
	add_child(_player)
	# буханка: на разворотной площадке задом к горе
	van = Van.new()
	van.name = "Van"
	van.position = Vector3(3.2, 0.25, r + 5.5) if site != null else Vector3(5.0, 0.25, r + 5.0)
	add_child(van)
	_build_hint("HINT_DUMP")
