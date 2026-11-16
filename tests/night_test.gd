extends Node
## Автотест цикла ночи: логика забега (нормы, касса, победа и поражение),
## часы, рассвет, приёмка с весами, итог ночи.
## Запуск: godot --headless --path . --fixed-fps 60 res://tests/night_test.tscn

var _failed: int = 0
var _passed: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var eco: EconomyConfig = Game.economy

	# 1. чистая логика забега
	var run := RunState.new(eco, 1, 7)
	_check(run.quota() == 1350 and run.night == 1, "первая ночь в одиночку: норма %d" % run.quota())
	run.sell(1000)
	_check(not run.quota_met() and run.quota_left() == 350, "сдали 1000 — до нормы 350")
	run.sell(600)
	_check(run.quota_met() and run.finish_night() == RunState.Outcome.NIGHT_PASSED and run.money == eco.start_money + 250,
			"норма закрыта, излишек 250 в кассу")
	run.next_night()
	_check(run.night == 2 and run.earned == 0 and run.quota() == 2250 and run.night_seed() != RunState.new(eco, 1, 7).night_seed(),
			"вторая ночь: норма %d, свалка другая" % run.quota())
	var copy: RunState = RunState.from_dict(eco, run.to_dict())
	_check(copy.night == 2 and copy.money == eco.start_money + 250 and copy.run_seed == 7, "сохранение и загрузка забега")
	run.sell(100)
	_check(run.finish_night() == RunState.Outcome.LOST, "не добрали норму — забег окончен")
	var long_run := RunState.new(eco, 4, 1)
	for night: int in eco.nights():
		long_run.sell(long_run.quota())
		var out: RunState.Outcome = long_run.finish_night()
		if night < eco.nights() - 1:
			long_run.next_night()
		elif true:
			_check(out == RunState.Outcome.WON and long_run.night == 7, "семь закрытых ночей — победа")

	# меню паузы
	_check(not PauseMenu.is_open(), "меню паузы закрыто")
	PauseMenu.set_open(true)
	_check(PauseMenu.is_open() and get_tree().paused, "Esc — меню открыто, мир на паузе")
	PauseMenu.set_open(false)
	_check(not get_tree().paused, "закрыли — игра идёт")

	# 2. сцена ночи
	Save.write({})
	Game.run = null
	var night: Node3D = (load("res://scenes/game/night.tscn") as PackedScene).instantiate()
	night.set(&"auto_advance", false)
	add_child(night)
	await _wait(0.5)
	var yard: ScrapYard = night.get(&"yard")
	var state: RunState = night.get(&"run")
	var player: PlayerController = night.find_child("Player", true, false)
	var input := PlayerInput.new()
	player.scripted_input = input
	var site: DumpSite = night.get(&"site")
	var nvan: Van = night.get(&"van")
	_check(state != null and state.night == 1 and Game.phase == Game.Phase.ROAD, "ночь началась на дороге")
	_check(nvan.global_position.z > site.gate_position.z + 80.0 and nvan.global_basis.z.z < -0.99,
			"буханка на подъезде, носом к воротам, до них %.0f м" % (nvan.global_position.z - site.gate_position.z))
	_check(nvan.global_basis.y.y > 0.99 and absf(nvan.global_position.y) < 0.3, "под подъездом есть земля")
	_check(is_zero_approx(Game.night_time) and not night.get(&"entered"), "до ворот часы стоят")
	_check(not site.barrier_open and absf(site.hole_position.x) > 15.0, "шлагбаум закрыт, дыра в заборе в %.0f м от ворот" % absf(site.hole_position.x))
	# закрытые ворота и забор — стена для машины, дыра — проезд
	var space: PhysicsDirectSpaceState3D = night.get_world_3d().direct_space_state
	var gate_z: float = site.gate_position.z
	var ray := PhysicsRayQueryParameters3D.create(Vector3(0.0, 0.95, gate_z + 4.0), Vector3(0.0, 0.95, gate_z - 4.0))
	_check(not space.intersect_ray(ray).is_empty(), "стрела шлагбаума перекрывает дорогу")
	ray = PhysicsRayQueryParameters3D.create(Vector3(-12.0, 1.0, gate_z + 4.0), Vector3(-12.0, 1.0, gate_z - 4.0))
	_check(not space.intersect_ray(ray).is_empty(), "забор глухой")
	ray = PhysicsRayQueryParameters3D.create(site.hole_position + Vector3(0.0, 1.0, 4.0), site.hole_position + Vector3(0.0, 1.0, -4.0))
	_check(space.intersect_ray(ray).is_empty(), "через дыру проезд свободен")
	var fee: int = night.call(&"guard_fee")
	_check(fee == 100 and eco.guard_fee_for(3) == 200, "сторож берёт %d ₽, к третьей ночи 200" % fee)
	state.money = 50
	_check(not night.call(&"pay_guard") and not site.barrier_open and state.money == 50, "без денег сторож не пускает")
	state.money = 200
	# игрок жмёт E у ящика сторожа
	var box: Node3D = night.get_node(^"GuardBox")
	player.global_position = box.global_position + Vector3(-1.3, -0.9, 0.0)
	var aim: Vector3 = box.global_position - (player.global_position + Vector3.UP * player.eye_height())
	player.yaw = atan2(-aim.x, -aim.z)
	player.pitch = atan2(aim.y, Vector2(aim.x, aim.z).length())
	await _wait(0.4)
	_check(player.grab.focus_use == box, "у ящика сторожа подсказка «заплатить»")
	input.interact_pressed = true
	await get_tree().physics_frame
	input.interact_pressed = false
	await _wait(1.6)
	_check(state.guard_paid and site.barrier_open and state.money == 100, "заплатили 100 ₽ — шлагбаум открыт")
	ray = PhysicsRayQueryParameters3D.create(Vector3(0.0, 0.95, gate_z + 4.0), Vector3(0.0, 0.95, gate_z - 4.0))
	_check(space.intersect_ray(ray).is_empty(), "поднятая стрела не мешает")
	_check(not night.get(&"entered"), "пока не въехали, часы стоят")
	player.global_position = Vector3(0.0, 0.05, gate_z - 6.0)
	await _wait(0.2)
	_check(night.get(&"entered") and Game.phase == Game.Phase.LANDFILL and not state.sneaked, "въехали — фаза «свалка», сторож не в обиде")
	_check(yard.global_position.z > (night.get(&"site") as DumpSite).gate_position.z, "приёмка стоит за воротами")
	var t0: float = Game.night_time
	await _wait(1.0)
	_check(absf((Game.night_time - t0) - 1.0 / eco.night_seconds) < 0.0005, "часы идут: %s" % Game.clock_text())

	# 3. весы: батарея и телевизор — деньги, мешок мусора — не берём
	var radiator: Item = night.call(&"_spawn", load("res://data/items/radiator_cast_iron.tres"),
			Transform3D(Basis.IDENTITY, yard.global_position + Vector3(0.6, 0.4, 0.5)))
	var tv: Item = night.call(&"_spawn", load("res://data/items/tv_crt.tres"),
			Transform3D(Basis.IDENTITY, yard.global_position + Vector3(-0.6, 0.4, -0.5)))
	var bag: Item = night.call(&"_spawn", load("res://data/junk/bag_black.tres"),
			Transform3D(Basis.IDENTITY, yard.global_position + Vector3(0.6, 0.5, -0.8)))
	await _wait(1.5)
	_check(yard.last_comment.begins_with("YARD_SEE_") and tr(yard.last_comment) != yard.last_comment,
			"приёмщик бурчит про вещь: «%s»" % tr(yard.last_comment))
	_check(yard.comment_for(tv) == "YARD_SEE_TV_CRT" and yard.comment_for(bag) == "YARD_SEE_TRASH"
			and yard.comment_for(radiator) == "YARD_SEE_HEAVY", "у телевизора своя реплика, у мусора и тяжёлого — общие")
	var w: Dictionary = yard.weigh()
	var expected: int = radiator.value() + tv.value()
	_check(w["count"] == 2 and w["trash"] == 1 and w["value"] == expected and absf(w["mass"] - 95.0) < 0.5,
			"на весах 2 вещи, %.0f кг, %d ₽, мусор отдельно" % [w["mass"], w["value"]])
	# игрок жмёт E у окошка
	var desk: Node3D = yard.get_node(^"Desk_sell")
	player.global_position = desk.global_position + Vector3(1.6, -1.2, 0.0)
	var to: Vector3 = desk.global_position - (player.global_position + Vector3.UP * player.eye_height())
	player.yaw = atan2(-to.x, -to.z)
	player.pitch = atan2(to.y, Vector2(to.x, to.z).length())
	player.velocity = Vector3.ZERO
	await _wait(0.4)
	_check(player.grab.focus_use == desk and player.grab.focus_action.get("action") == &"sell", "у окошка подсказка «сдать»")
	input.interact_pressed = true
	await get_tree().physics_frame
	input.interact_pressed = false
	await _wait(0.3)
	_check(state.earned == expected and not is_instance_valid(radiator) and not is_instance_valid(tv),
			"сдали на %d ₽, вещи ушли с весов" % state.earned)
	_check(is_instance_valid(bag), "мешок с мусором приёмщик не взял")
	_check(yard.sell() == 0, "пустые весы — нечего сдавать")

	# 4. рассвет и конец ночи
	Game.night_time = eco.dawn_at + 0.01
	await _wait(0.2)
	_check(night.get(&"dawn"), "в 04:30 рассвет и сирена")
	_check(Audio.has_sound(&"siren") and Audio.has_sound(&"cash"), "звуки сирены и кассы есть")
	Game.night_time = 0.9999
	await _wait(1.0)
	_check(night.get(&"finished") and state.outcome == RunState.Outcome.LOST and Game.phase == Game.Phase.SUMMARY,
			"05:00, норма не закрыта — поражение")
	_check((Save.read().get("run", {}) as Dictionary).is_empty(), "проигранный забег не сохраняется")
	night.queue_free()
	await _wait(0.3)

	# 5. закрытая норма — следующая ночь сохраняется
	Game.run = null
	night = (load("res://scenes/game/night.tscn") as PackedScene).instantiate()
	night.set(&"auto_advance", false)
	add_child(night)
	await _wait(0.3)
	state = night.get(&"run")
	# мимо сторожа: пешком через дыру
	site = night.get(&"site")
	player = night.find_child("Player", true, false)
	player.global_position = site.hole_position + Vector3(0.0, 0.05, -6.0)
	await _wait(0.2)
	_check(night.get(&"entered") and state.sneaked and not state.guard_paid and state.money == eco.start_money,
			"через дыру — бесплатно, но мимо сторожа")
	state.sell(state.quota() + 400)
	night.call(&"finish")
	_check(state.outcome == RunState.Outcome.NIGHT_PASSED and state.money == eco.start_money + 400, "норма закрыта: излишек 400 в кассу")
	state.next_night()
	Game.save_run()
	var saved: Dictionary = Save.read().get("run", {})
	_check(int(saved.get("night", 0)) == 2 and int(saved.get("money", 0)) == eco.start_money + 400, "сохранена вторая ночь и касса")
	Save.write({})

	# 6. гараж и лавка
	Game.run = null
	Game.start_run(false)
	Game.run.money = 2000
	var garage: Node3D = (load("res://scenes/game/garage.tscn") as PackedScene).instantiate()
	garage.set(&"auto_advance", false)
	add_child(garage)
	await _wait(1.0)
	var grun: RunState = garage.get(&"run")
	var gvan: Van = garage.get(&"van")
	player = garage.find_child("Player", true, false)
	input = PlayerInput.new()
	player.scripted_input = input
	_check(Game.phase == Game.Phase.GARAGE and grun == Game.run and gvan != null, "гараж: фаза, забег, буханка на месте")
	_check((garage.get(&"_board") as Label3D).text.contains("\n") and (garage.get(&"_board") as Label3D).text.contains(Fmt.rub(2000)),
			"доска показывает норму и кассу")
	_check(is_equal_approx(gvan.feel.capacity, 800.0), "без улучшений грузоподъёмность 800 кг")
	var items: Array[ShopItem] = ShopDb.all()
	_check(items.size() == 8 and items[0].price > 0 and tr(items[0].name_key) != items[0].name_key, "в лавке %d товара с названиями" % items.size())
	# покупка через E у ящика
	var crate: Node3D = garage.get_node(^"Shop_springs")
	player.global_position = Vector3(crate.global_position.x - 1.5, 0.05, crate.global_position.z)
	to = crate.global_position - (player.global_position + Vector3.UP * player.eye_height())
	player.yaw = atan2(-to.x, -to.z)
	player.pitch = atan2(to.y, Vector2(to.x, to.z).length())
	player.velocity = Vector3.ZERO
	await _wait(0.4)
	_check(player.grab.focus_use == crate and str(player.grab.focus_action.get("text", "")).contains(Fmt.rub(1500)),
			"у ящика подсказка с ценой: «%s»" % player.grab.focus_action.get("text", ""))
	input.interact_pressed = true
	await get_tree().physics_frame
	input.interact_pressed = false
	await _wait(0.2)
	_check(grun.has_upgrade(&"springs") and grun.money == 500, "купили рессоры, в кассе 500")
	_check(is_equal_approx(gvan.feel.capacity, 1100.0), "грузоподъёмность стала 1100 кг")
	_check(not garage.call(&"buy", items[1]) and not grun.has_upgrade(&"tyres"), "на резину денег не хватает")
	# пояс и инструменты
	var belt: PlayerBelt = player.belt
	_check(belt.has_tool(&"shovel") and belt.slots[0] != null and belt.free_slot() == 1, "в начале забега на поясе лопата")
	var base_lift: float = player.grab.lift_force()
	grun.money = 1000
	_check(garage.call(&"buy", items[4]) and belt.has_tool(&"crowbar") and grun.money == 100, "купили лом — он на поясе, в кассе 100")
	_check(grun.belt[1] == "crowbar", "пояс записан в забег: %s" % str(grun.belt))
	_check(belt.active == -1 and belt.can_grab() and is_equal_approx(player.grab.lift_force(), base_lift), "в начале в руках пусто, лом на поясе силы не даёт")
	# клавиша 3 — взять лом в руки (слот 2), сила растёт
	input.slot_pressed = 3
	await get_tree().physics_frame
	input.slot_pressed = 0
	_check(belt.active == 1 and belt.active_tool() == &"crowbar" and belt.can_grab(), "клавиша 3: лом в руках, таскать можно")
	_check(is_equal_approx(player.grab.lift_force(), base_lift * player.feel.crowbar_lift_mult), "с ломом в руках поднимаем в %.1f раза больше" % player.feel.crowbar_lift_mult)
	# клавиша 2 — лопата: таскать нельзя
	input.slot_pressed = 2
	await get_tree().physics_frame
	input.slot_pressed = 0
	_check(belt.active_tool() == &"shovel" and not belt.can_grab(), "клавиша 2: лопата в руках, таскать нельзя")
	# клавиша 1 — руки
	input.slot_pressed = 1
	await get_tree().physics_frame
	input.slot_pressed = 0
	_check(belt.active == -1 and belt.can_grab(), "клавиша 1: пустые руки")
	# G выбрасывает то, что в руках
	input.slot_pressed = 3
	await get_tree().physics_frame
	input.slot_pressed = 0
	input.drop_pressed = true
	await get_tree().physics_frame
	input.drop_pressed = false
	await _wait(0.8)
	var dropped: Item = null
	for n: Node in get_tree().get_nodes_in_group(&"items"):
		if (n as Item).data.id == &"crowbar" and n.is_inside_tree():
			dropped = n
	_check(dropped != null and not belt.has_tool(&"crowbar") and belt.active == -1, "G: лом упал на пол, в руках пусто")
	# E по лежащему инструменту — на пояс
	to = dropped.global_position - (player.global_position + Vector3.UP * player.eye_height())
	player.yaw = atan2(-to.x, -to.z)
	player.pitch = atan2(to.y, Vector2(to.x, to.z).length())
	await _wait(0.3)
	_check(player.grab.focus == dropped and player.grab.focus_action.get("action") == &"stow", "на лом можно нажать E")
	input.interact_pressed = true
	await get_tree().physics_frame
	input.interact_pressed = false
	await _wait(0.2)
	_check(belt.slots[1] == dropped and not dropped.is_inside_tree(), "E: лом снова на поясе")
	grun.money = 500
	_check(not garage.call(&"buy", items[0]) and grun.money == 500, "второй раз то же не купить")
	await _wait(2.0)
	_check(gvan.global_basis.y.y > 0.99 and gvan.global_position.y > 0.03 and gvan.global_position.y < 0.16, "машина с новыми рессорами стоит ровно и выше (на %.2f м)" % gvan.global_position.y)
	saved = Save.read().get("run", {})
	_check((saved.get("upgrades", []) as Array).has("springs"), "покупка сохранена")
	garage.call(&"leave")
	_check(garage.get(&"leaving"), "ворота: выезд на свалку")
	garage.queue_free()
	await _wait(0.3)
	# улучшение доезжает до ночи
	night = (load("res://scenes/game/night.tscn") as PackedScene).instantiate()
	night.set(&"auto_advance", false)
	add_child(night)
	await _wait(0.3)
	_check(is_equal_approx((night.get(&"van") as Van).feel.capacity, 1100.0), "на свалке буханка с купленными рессорами")
	player = night.find_child("Player", true, false)
	_check(player.belt.has_tool(&"shovel") and player.belt.has_tool(&"crowbar"), "пояс доехал до свалки: лопата и лом")
	# металлоискатель: вдали от горы молчит, у закопанной вещи слышит
	var ndump: Dump = night.get(&"dump")
	_check(is_inf(ndump.nearest_loot_distance(Vector3(0, 0, 200), 9.0)), "вдали от горы ценного нет")
	var site_at: Vector3 = ndump.to_global(ndump.field.cell_base(ndump.field.sites[0]["anchor"]))
	_check(ndump.nearest_loot_distance(site_at + Vector3(2, 0, 0), 9.0) < 2.5, "рядом с закопанной вещью прибор её слышит")
	_check(Audio.has_sound(&"beep") and Audio.has_sound(&"detector_found"), "писк и трель «нашёл» есть")
	# прибор работает только в руках
	var nbelt: PlayerBelt = player.belt
	nbelt.stow(2, ItemDb.spawn(ItemDb.tool(&"metal_detector"), RandomNumberGenerator.new()))
	player.global_position = site_at + Vector3(0.5, 0.3, 0.0)
	await _wait(0.6)
	_check(is_inf(nbelt.loot_distance()) and is_zero_approx(nbelt.signal_strength()), "металлоискатель на поясе молчит")
	nbelt.select(2)
	await _wait(0.6)
	_check(nbelt.loot_distance() < 3.0 and nbelt.signal_strength() > 0.6, "в руках — сигнал %.0f%%" % (nbelt.signal_strength() * 100.0))
	Save.write({})

	print("Тесты ночи: прошло %d, провалено %d" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _wait(seconds: float) -> void:
	for i: int in int(ceil(seconds * Engine.physics_ticks_per_second)):
		await get_tree().physics_frame


func _check(condition: bool, what: String) -> void:
	if condition:
		_passed += 1
		print("  ок: ", what)
	else:
		_failed += 1
		print("  ПРОВАЛ: ", what)
