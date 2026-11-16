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
	_check(run.quota_met() and run.finish_night() == RunState.Outcome.NIGHT_PASSED and run.money == 250,
			"норма закрыта, излишек 250 в кассе")
	run.next_night()
	_check(run.night == 2 and run.earned == 0 and run.quota() == 2250 and run.night_seed() != RunState.new(eco, 1, 7).night_seed(),
			"вторая ночь: норма %d, свалка другая" % run.quota())
	var copy: RunState = RunState.from_dict(eco, run.to_dict())
	_check(copy.night == 2 and copy.money == 250 and copy.run_seed == 7, "сохранение и загрузка забега")
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
	_check(state != null and state.night == 1 and Game.phase == Game.Phase.LANDFILL, "ночь началась, фаза «свалка»")
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
	state.sell(state.quota() + 400)
	night.call(&"finish")
	_check(state.outcome == RunState.Outcome.NIGHT_PASSED and state.money == 400, "норма закрыта: в кассе 400")
	state.next_night()
	Game.save_run()
	var saved: Dictionary = Save.read().get("run", {})
	_check(int(saved.get("night", 0)) == 2 and int(saved.get("money", 0)) == 400, "сохранена вторая ночь и касса")
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
	_check(items.size() == 3 and items[0].price > 0 and tr(items[0].name_key) != items[0].name_key, "в лавке %d товара с названиями" % items.size())
	# покупка через E у ящика
	var crate: Node3D = garage.get_node(^"Shop_springs")
	player.global_position = crate.global_position + Vector3(-1.5, -0.4, 0.0)
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
