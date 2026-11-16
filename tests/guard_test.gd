extends Node
## Автотест сторожа: будка, выход на поиски, слух, зрение (фонарь, присед, спина),
## погоня, поимка с отбором вещи, отказ лезть на гору.
## Запуск: godot --headless --path . --fixed-fps 60 res://tests/guard_test.tscn

var _failed: int = 0
var _passed: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Save.write({})
	Game.run = null
	var night: Node3D = (load("res://scenes/game/night.tscn") as PackedScene).instantiate()
	night.set(&"auto_advance", false)
	add_child(night)
	await _wait(0.5)
	var guard: Guard = night.get(&"guard")
	var site: DumpSite = night.get(&"site")
	var state: RunState = night.get(&"run")
	var player: PlayerController = night.find_child("Player", true, false)
	var input := PlayerInput.new()
	player.scripted_input = input
	var cfg: GuardConfig = guard.config
	var r: float = guard.heap_radius

	# 1. в будке
	_check(guard.state == Guard.State.BOOTH and guard.global_position.distance_to(site.booth_position) < 4.0, "сторож сидит у будки")
	Game.make_noise(guard.global_position + Vector3(3.0, 0.0, 0.0), 30.0)
	await _wait(0.2)
	_check(guard.state == Guard.State.BOOTH, "в будке он шума не слышит")

	# 2. пролезли через дыру — через время выходит искать
	player.global_position = site.hole_position + Vector3(0.0, 0.05, -6.0)
	await _wait(0.2)
	_check(state.sneaked and is_equal_approx(night.get(&"search_in"), cfg.search_delay) or night.get(&"search_in") > cfg.search_delay - 1.0,
			"пролезли: сторож выйдет через %.0f с" % cfg.search_delay)
	# игрока прячем далеко за горой, чтобы не мешал проверкам
	player.global_position = Vector3(0.0, 0.05, -r - 30.0)
	night.set(&"search_in", 0.05)
	await _wait(0.3)
	_check(guard.state == Guard.State.PATROL, "сторож вышел на обход")
	var from: Vector3 = guard.global_position
	await _wait(3.0)
	_check(guard.global_position.distance_to(from) > cfg.walk_speed * 2.0, "идёт: за 3 с прошёл %.1f м" % guard.global_position.distance_to(from))
	_check(guard.patrol_point(0).length() > r + cfg.heap_margin and guard.patrol_point(3).length() > r + cfg.heap_margin, "обход — кольцом вокруг горы")

	# 3. слух
	var bang: Vector3 = guard.global_position + Vector3(-9.0, 0.0, 2.0)
	Game.make_noise(bang, 5.0)
	await _wait(0.1)
	_check(guard.state == Guard.State.PATROL, "тихий шум далеко — не слышит")
	Game.make_noise(bang, 20.0)
	await _wait(0.1)
	_check(guard.state == Guard.State.INVESTIGATE, "громкий шум — идёт смотреть")
	await _wait(7.0)
	_check(guard.global_position.distance_to(bang) < 2.5, "дошёл до места шума (осталось %.1f м)" % guard.global_position.distance_to(bang))
	await _wait(cfg.look_around_time + 1.0)
	_check(guard.state == Guard.State.PATROL, "осмотрелся и вернулся на обход")
	# шум на горе: на гору не лезет
	Game.make_noise(Vector3(0.0, 20.0, 0.0), 500.0)
	await _wait(0.1)
	var goal: Vector3 = guard.get(&"_goal")
	_check(guard.state == Guard.State.INVESTIGATE and goal.length() >= r + cfg.heap_margin - 0.1, "шум на горе — встанет у подножия, не полезет")

	# 4. зрение: ставим сторожа на ровное место за воротами дороги, игрока перед ним
	guard.set_physics_process(false)
	var spot := Vector3(-20.0, 0.0, r + 30.0)
	guard.global_position = spot
	guard.rotation.y = 0.0                    # смотрит в -Z
	player.flashlight_on = false
	player.global_position = spot + Vector3(0.0, 0.05, -8.0)
	await _wait(0.2)
	_check(guard.can_see(player), "в 8 м перед собой видит и без фонаря")
	player.global_position = spot + Vector3(0.0, 0.05, 8.0)
	await _wait(0.1)
	_check(not guard.can_see(player), "за спиной не видит")
	player.global_position = spot + Vector3(0.0, 0.05, -22.0)
	await _wait(0.1)
	_check(not guard.can_see(player), "в 22 м без фонаря не видит")
	player.flashlight_on = true
	_check(guard.can_see(player), "в 22 м с фонарём видит")
	player.flashlight_on = false
	player.global_position = spot + Vector3(0.0, 0.05, -9.0)
	input.crouch_held = true
	await _wait(0.4)
	var crouched_seen: bool = guard.can_see(player)
	input.crouch_held = false
	await _wait(0.4)
	_check(not crouched_seen, "присевшего в 9 м не видит")
	# за стеной (забор) не видит
	var gate_z: float = site.gate_position.z
	guard.global_position = Vector3(-15.0, 0.0, gate_z - 4.0)
	guard.rotation.y = PI                     # смотрит в +Z, на забор
	player.global_position = Vector3(-15.0, 0.05, gate_z + 4.0)
	await _wait(0.1)
	_check(not guard.can_see(player), "через забор не видит")

	# 5. погоня и поимка
	guard.global_position = spot
	guard.rotation.y = 0.0
	guard.set(&"_cooldown", 0.0)
	player.global_position = spot + Vector3(0.0, 0.05, -7.0)
	var coil: Item = night.call(&"_spawn", load("res://data/items/cable_coil.tres"),
			Transform3D(Basis.IDENTITY, player.global_position + Vector3(0.0, 0.2, -1.1)))
	await _wait(0.4)
	var aim: Vector3 = coil.global_position - (player.global_position + Vector3.UP * player.eye_height())
	player.yaw = atan2(-aim.x, -aim.z)
	player.pitch = atan2(aim.y, Vector2(aim.x, aim.z).length())
	await _wait(0.2)
	input.grab_held = true
	await _wait(0.5)
	_check(player.grab.held == coil, "игрок держит бухту")
	guard.set_physics_process(true)
	guard.start_search()
	guard.set(&"state", Guard.State.PATROL)
	var spotted: Array[bool] = [false]
	guard.spotted.connect(func(_p: PlayerController) -> void: spotted[0] = true)
	await _wait(2.5)
	_check(spotted[0] or state.stats.get(&"caught", 0) > 0, "заметил игрока и погнался")
	await _wait(4.0)
	_check(state.stats.get(&"caught", 0) == 1, "догнал и поймал")
	_check(not is_instance_valid(coil) and player.grab.held == null, "отобрал бухту из рук")
	_check(player.global_position.z > gate_z and player.global_position.distance_to(guard.exit_point) < 2.0, "вывел за ворота")
	_check(guard.state == Guard.State.PATROL, "после поимки уходит на обход")
	player.global_position = guard.global_position + guard.global_basis * Vector3(0.0, 0.05, -4.0)
	await _wait(2.0)
	_check(guard.state != Guard.State.CHASE and state.stats.get(&"caught", 0) == 1, "сразу второй раз не ловит")
	_check(Audio.has_sound(&"whistle"), "свисток сторожа есть")

	# бутылка в руках: догнал — берёт её и уходит
	guard.set(&"_cooldown", 0.0)
	guard.start_search()
	guard.set(&"state", Guard.State.PATROL)
	player.belt.stow(2, ItemDb.spawn(ItemDb.tool(&"bottle"), RandomNumberGenerator.new()))
	player.belt.select(2)
	_check(player.belt.active_tool() == &"bottle", "бутылка в руках")
	var before_exit: Vector3 = guard.global_position + guard.global_basis * Vector3(0.0, 0.05, -1.0)
	player.global_position = before_exit
	guard.catch_player(player)
	_check(guard.state == Guard.State.RETURN and not player.belt.has_tool(&"bottle") and state.guard_paid
			and state.stats.get(&"caught", 0) == 1 and player.global_position.distance_to(before_exit) < 0.5,
			"сторож взял бутылку, не тронул игрока и пошёл в будку")
	_check(site.barrier_open, "шлагбаум после бутылки открыт")

	# 6. заплатили — сидит в будке
	guard.go_home()
	_check(guard.state == Guard.State.RETURN, "идёт домой")
	guard.global_position = guard.booth_point + Vector3(0.3, 0.0, 0.0)
	await _wait(1.0)
	_check(guard.state == Guard.State.BOOTH, "дошёл до будки и сел")

	# 7. пёс
	var dog: GuardDog = night.get(&"dog")
	player.belt.fill(["", "", ""])
	player.global_position = Vector3(0.0, 0.05, -r - 40.0)
	dog.global_position = guard.booth_point + Vector3(2.0, 0.0, 2.0)
	dog.target = null
	await _wait(1.5)
	_check(dog.state == GuardDog.State.REST and dog.global_position.distance_to(guard.booth_point) < 4.0, "сторож в будке — пёс лежит рядом")
	guard.set(&"_cooldown", 999.0)            # сторож в этих проверках никого не ловит
	guard.start_search()
	await _wait(2.0)
	_check(dog.state == GuardDog.State.HEEL, "сторож вышел — пёс идёт рядом")
	player.global_position = dog.global_position + Vector3(-10.0, 0.05, 0.0)
	var barks: Array[int] = [0]
	Game.noise.connect(func(_at: Vector3, radius: float) -> void:
		if is_equal_approx(radius, cfg.dog_bark_noise):
			barks[0] += 1)
	await _wait(0.6)
	_check(dog.target == player and dog.state == GuardDog.State.TRACK, "пёс учуял игрока в 10 м без света и побежал")
	await _wait(3.5)
	_check(dog.state == GuardDog.State.BARK and dog.global_position.distance_to(player.global_position) < cfg.dog_bark_distance + 0.5 and barks[0] >= 2,
			"подбежал и лает (%d раз)" % barks[0])
	_check(guard.state == Guard.State.INVESTIGATE, "сторож идёт на лай")
	_check(player.mode == PlayerController.Mode.NORMAL and state.stats.get(&"caught", 0) == 1, "сам пёс не ловит")
	# колбаса
	var sausage: Item = night.call(&"_spawn", ItemDb.tool(&"sausage"),
			Transform3D(Basis.IDENTITY, dog.global_position + Vector3(4.0, 0.3, 3.0)))
	await _wait(3.0)
	_check(dog.state == GuardDog.State.EAT and dog.food == sausage, "бросили колбасу — пёс ест")
	var barks_before: int = barks[0]
	await _wait(2.0)
	_check(barks[0] == barks_before, "пока ест — не лает")
	dog.set(&"_eat_left", 0.1)
	await _wait(0.5)
	_check(not is_instance_valid(sausage) and dog.state != GuardDog.State.EAT, "доел — колбасы нет, снова на службе")
	_check(Audio.has_sound(&"bark"), "лай есть")

	Save.write({})
	print("Тесты сторожа: прошло %d, провалено %d" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _wait(seconds: float) -> void:
	for i: int in int(ceil(seconds * Engine.physics_ticks_per_second)):
		await get_tree().physics_frame


func _check(condition: bool, what: String) -> void:
	if condition:
		_passed += 1
		print("  ок: " + what)
	else:
		_failed += 1
		printerr("ПРОВАЛ: " + what)
