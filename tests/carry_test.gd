extends Node
## Автотест переноски со сценарным вводом.
## Запуск: godot --headless --path . --fixed-fps 60 res://tests/carry_test.tscn

var _failed: int = 0
var _passed: int = 0
var _player: PlayerController
var _scene: Node
var _input := PlayerInput.new()
var _losses: Array[int] = []


func _ready() -> void:
	_scene = (load("res://scenes/debug/test_scene.tscn") as PackedScene).instantiate()
	_scene.set_script(load("res://tests/empty_stage.gd"))
	add_child(_scene)
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	_player.position = Vector3(0, 0.05, 0)
	_scene.add_child(_player)
	_player.scripted_input = _input
	_run.call_deferred()


func _spawn(id: String, pos: Vector3) -> Item:
	var item: Item = ItemDb.spawn(load("res://data/items/%s.tres" % id), RandomNumberGenerator.new())
	item.position = pos
	_scene.add_child(item)
	item.damaged.connect(func(loss: int) -> void: _losses.append(loss))
	return item


func _run() -> void:
	var feel: PlayerFeel = _player.feel
	await _wait(0.5)

	# 1. лёгкое (бухта, до 25 кг): поднимается и висит перед игроком
	var coil: Item = _spawn("cable_coil", Vector3(0, 0.02, -1.1))
	await _wait(0.6)
	_aim_at(coil)
	await _wait(0.1)
	_check(_player.grab.focus == coil, "бухта под прицелом")
	_check(coil.find_child("mesh", true, false).material_overlay != null, "предмет под прицелом обведён")
	_input.grab_held = true
	await _wait(1.2)
	_check(_player.grab.held == coil, "бухта в руках")
	_check(coil.find_child("mesh", true, false).material_overlay == null, "в руках обводка снята")
	_player.pitch = 0.0
	await _wait(1.0)
	_check(coil.global_position.y > 0.45, "бухта поднята на %.2f м" % coil.global_position.y)
	_check(_player.grab.stretch < 0.25, "висит у рук, отставание %.2f м" % _player.grab.stretch)
	_check(_player.grab.can_lift(coil.mass), "бухту (%.0f кг) можно нести одному" % coil.mass)
	# несём: идём вперёд, предмет не отстаёт, шаг чуть медленнее
	_input.move = Vector2(0, 1)
	await _wait(1.5)
	var carry_speed: float = _player.horizontal_speed()
	_check(carry_speed < feel.walk_speed * 0.98 and carry_speed > feel.walk_speed * 0.55,
			"с грузом идём медленнее: %.2f м/с" % carry_speed)
	_check(_player.grab.held == coil, "груз не выпал на ходу")
	_check(coil.global_position.distance_to(_player.global_position) < 1.6, "груз идёт вместе с нами")
	_input.move = Vector2.ZERO
	await _wait(0.5)

	# 2. бросок с зарядкой
	var before: Vector3 = coil.global_position
	_input.throw_held = true
	await _wait(feel.throw_charge_time + 0.1)
	_input.throw_held = false
	await _wait(0.05)
	_check(_player.grab.held == null, "после броска руки пусты")
	_input.grab_held = false
	await _wait(1.5)
	var thrown: float = Vector2(coil.global_position.x - before.x, coil.global_position.z - before.z).length()
	_check(thrown > 2.0, "бухта улетела на %.1f м" % thrown)
	coil.queue_free()

	# 3. тяжёлое (батарея 70 кг): не поднять, но можно волочить
	await _place(Vector3(0, 0.05, 20))
	var radiator: Item = _spawn("radiator_cast_iron", Vector3(0, 0.02, 18.9))
	await _wait(0.8)
	_aim_at(radiator)
	await _wait(0.1)
	_input.grab_held = true
	await _wait(1.0)
	_check(_player.grab.held == radiator, "батарея схвачена")
	_check(not _player.grab.can_lift(radiator.mass), "батарею (70 кг) одному не поднять")
	_player.pitch = 0.2
	await _wait(1.2)
	_check(radiator.global_position.y < 0.6, "центр батареи остался у земли (y = %.2f)" % radiator.global_position.y)
	var start_z: float = radiator.global_position.z
	_input.move = Vector2(0, -1)  # пятимся и тянем
	await _wait(3.0)
	var dragged: float = radiator.global_position.z - start_z
	_check(dragged > 1.0, "батарею протащили на %.1f м за 3 с" % dragged)
	_check(_player.horizontal_speed() < feel.walk_speed * 0.6, "волоком идём медленно: %.2f м/с" % _player.horizontal_speed())
	_check(_player.grab.held == radiator, "батарея не сорвалась с рук")
	_input.move = Vector2.ZERO
	_input.grab_held = false
	await _wait(0.3)
	_check(_player.grab.held == null, "отпустили ЛКМ — отпустили предмет")
	radiator.queue_free()

	# 4. хрупкое (телевизор): аккуратно поставить — цел, уронить с высоты — теряет цену
	await _place(Vector3(0, 0.05, 40))
	var tv: Item = _spawn("tv_crt", Vector3(0, 0.02, 38.9))
	await _wait(0.8)
	var full: int = tv.value()
	_check(full == 1800, "целый телевизор стоит %d ₽" % full)
	_aim_at(tv)
	await _wait(0.1)
	_input.grab_held = true
	await _wait(1.0)
	_player.pitch = 0.0
	await _wait(1.0)
	_check(_player.grab.held == tv and tv.integrity == 1.0, "телевизор в руках и цел")
	_input.grab_held = false
	await _wait(1.5)
	_check(tv.integrity == 1.0, "отпустили с высоты рук — выжил (целость %.2f)" % tv.integrity)
	tv.global_position = Vector3(0, 5.0, 38.5)
	tv.linear_velocity = Vector3.ZERO
	await _wait(2.0)
	_check(tv.integrity < 1.0, "падение с 5 м бьёт телевизор (целость %.2f)" % tv.integrity)
	_check(tv.value() < full, "цена упала до %d ₽" % tv.value())
	_check(_losses.size() >= 1 and _losses[0] > 0, "о потере сообщили: %s" % [_losses])

	# 5. крупная техника и антиквариат
	var sounds_before: int = Audio.played_count
	await _place(Vector3(20, 0.05, 0))
	var fridge: Item = _spawn("fridge", Vector3(20, 0.02, -1.2))
	await _wait(0.8)
	_check(fridge.global_basis.y.y > 0.95, "холодильник стоит и не падает сам")
	_aim_at(fridge)
	await _wait(0.1)
	_input.grab_held = true
	await _wait(0.6)
	_check(_player.grab.held == fridge and not _player.grab.can_lift(fridge.mass), "холодильник (60 кг) одному только волоком")
	_input.move = Vector2(0, -1)
	var fridge_from: Vector3 = fridge.global_position
	await _wait(3.0)
	_input.move = Vector2.ZERO
	_check(fridge.global_position.distance_to(fridge_from) > 0.8,
			"холодильник протащили на %.1f м за 3 с" % fridge.global_position.distance_to(fridge_from))
	_input.grab_held = false
	await _wait(0.3)
	fridge.queue_free()
	await _place(Vector3(-20, 0.05, 0))
	var samovar: Item = _spawn("samovar", Vector3(-20, 0.02, -1.0))
	await _wait(0.8)
	_check(samovar.value() == 2100 and samovar.scrap_value() == 420,
			"целый самовар %d ₽, ломом %d ₽" % [samovar.value(), samovar.scrap_value()])
	samovar.global_position = Vector3(-20, 7.0, -1.5)
	samovar.linear_velocity = Vector3.ZERO
	await _wait(2.2)
	_check(samovar.integrity < 1.0 and samovar.value() < 2100, "самовар помялся от падения: %d ₽" % samovar.value())
	_check(samovar.value() >= samovar.scrap_value(), "помятый самовар не дешевле лома")
	_check(Audio.played_count > sounds_before, "удары и шаги звучат (%d звуков)" % (Audio.played_count - sounds_before))

	# 6. формат денег
	_check(Fmt.rub(-1200) == "−1 200 ₽", "формат суммы: " + Fmt.rub(-1200))
	_check(Fmt.rub(23000) == "23 000 ₽", "формат суммы: " + Fmt.rub(23000))

	print("Тесты переноски: прошло %d, провалено %d" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


## Навести взгляд на середину предмета.
func _aim_at(item: Item) -> void:
	var to: Vector3 = item.global_position + Vector3.UP * 0.12 - _player.grab.eye()
	_player.yaw = atan2(-to.x, -to.z)
	_player.pitch = atan2(to.y, Vector2(to.x, to.z).length())


func _place(pos: Vector3) -> void:
	_input.move = Vector2.ZERO
	_input.grab_held = false
	_player.global_position = pos
	_player.velocity = Vector3.ZERO
	_player.yaw = 0.0
	_player.pitch = 0.0
	_player.reset_physics_interpolation()
	await _wait(0.4)


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
