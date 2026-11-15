extends Node
## Автотест контроллера персонажа на площадке этапа 1 со сценарным вводом.
## Запуск: godot --headless --path . --fixed-fps 60 res://tests/player_test.tscn
## Проверяет цифры (скорость, высота прыжка) и то, что механики вообще срабатывают.
## Ощущение этим не проверить — его оценивает автор.

var _failed: int = 0
var _passed: int = 0
var _player: PlayerController
var _knocked: bool = false
var _mantles: int = 0


func _ready() -> void:
	var scene: Node = (load("res://scenes/debug/playground_stage1.tscn") as PackedScene).instantiate()
	add_child(scene)
	_player = scene.find_child("Player", true, false)
	_player.knocked_down.connect(func(_s: float) -> void: _knocked = true)
	_player.mantle_started.connect(func(_h: float, _t: float) -> void: _mantles += 1)
	_run.call_deferred()


func _run() -> void:
	var feel: PlayerFeel = _player.feel
	var input := PlayerInput.new()
	_player.scripted_input = input
	await _wait(0.3)

	# 1. ходьба: выходим на скорость шага и держим её
	await _place(Vector3(0, 0.05, 16), 0.0)
	input.move = Vector2(0, 1)
	await _wait(0.06)
	var early: float = _player.horizontal_speed()
	await _wait(1.0)
	_check(early > 1.0 and early < feel.walk_speed, "разгон не мгновенный (через 0.06 с: %.2f м/с)" % early)
	_check(absf(_player.horizontal_speed() - feel.walk_speed) < 0.15, "скорость шага %.2f м/с" % _player.horizontal_speed())
	input.sprint_held = true
	await _wait(1.0)
	_check(absf(_player.horizontal_speed() - feel.sprint_speed) < 0.2, "скорость бега %.2f м/с" % _player.horizontal_speed())
	input.sprint_held = false
	input.move = Vector2.ZERO
	await _wait(0.1)
	_check(_player.horizontal_speed() > 0.5, "есть инерция: не встаём как вкопанные")
	await _wait(0.6)
	_check(_player.horizontal_speed() < 0.05, "останавливаемся полностью")

	# 2. прыжок на месте
	await _place(Vector3(0, 0.05, 6), 0.0)
	var base_y: float = _player.global_position.y
	input.jump_pressed = true
	input.jump_held = true
	await _wait(0.02)
	input.jump_pressed = false
	var peak: float = 0.0
	for i: int in 60:
		await get_tree().physics_frame
		peak = maxf(peak, _player.global_position.y - base_y)
	input.jump_held = false
	_check(absf(peak - feel.jump_height) < 0.12, "высота прыжка %.2f м (цель %.2f)" % [peak, feel.jump_height])

	# 3. присед: капсула становится ниже, скорость падает
	input.crouch_held = true
	input.move = Vector2(0, 1)
	await _wait(1.0)
	_check(absf(_player.height - feel.crouch_height) < 0.02, "в приседе высота %.2f м" % _player.height)
	_check(absf(_player.horizontal_speed() - feel.crouch_speed) < 0.15, "скорость в приседе %.2f м/с" % _player.horizontal_speed())
	input.crouch_held = false
	input.move = Vector2.ZERO
	await _wait(0.6)
	_check(absf(_player.height - feel.stand_height) < 0.02, "встаём обратно")

	# 4. лестница из ящиков по 0.35 м: заходим без прыжка
	await _place(Vector3(-6, 0.05, -2.5), 0.0)
	input.move = Vector2(0, 1)
	await _wait(0.75)
	input.move = Vector2.ZERO
	await _wait(0.3)
	_check(_player.global_position.y > 1.0, "зашли по ступенькам на %.2f м" % _player.global_position.y)
	_check(_mantles == 0, "по ступенькам идём шагом, без залезания")

	# 5. ящик 1 м: по прыжку перелезаем
	await _place(Vector3(-2, 0.05, -4.9), 0.0)
	input.move = Vector2(0, 1)
	input.jump_pressed = true
	await _wait(0.02)
	input.jump_pressed = false
	await _wait(1.2)
	_check(_mantles == 1, "сработало перелезание через ящик 1 м")
	_check(absf(_player.global_position.y - 1.0) < 0.1, "стоим на ящике, y = %.2f" % _player.global_position.y)

	# 6. уступ 2 м с земли: прыжок и подтягивание (мужичок мелкий, достаёт до ~2.3 м)
	await _place(Vector3(2, 0.05, -7.4), 0.0)
	_mantles = 0
	input.move = Vector2(0, 1)
	input.jump_pressed = true
	input.jump_held = true
	await _wait(0.02)
	input.jump_pressed = false
	await _wait(0.75)
	input.jump_held = false
	input.move = Vector2.ZERO
	await _wait(0.5)
	_check(_mantles == 1, "подтянулись на уступ 2 м из прыжка")
	_check(absf(_player.global_position.y - 2.0) < 0.1, "стоим на уступе, y = %.2f" % _player.global_position.y)

	# 7. низкий лаз: стоя не пройти, сидя — пройти, под потолком не встать
	await _place(Vector3(2.5, 0.05, 0), -PI / 2.0)
	input.move = Vector2(0, 1)
	await _wait(1.2)
	_check(_player.global_position.x < 4.3, "стоя в лаз не пролезть (x = %.2f)" % _player.global_position.x)
	input.crouch_held = true
	await _wait(1.3)
	input.crouch_held = false
	input.move = Vector2.ZERO
	await _wait(0.4)
	_check(_player.global_position.x > 4.9 and _player.global_position.x < 7.6, "сидя пролезли внутрь (x = %.2f)" % _player.global_position.x)
	_check(_player.crouching, "под низким потолком остаёмся сидеть")

	# 8. падение с вышки 6 м валит с ног, потом встаём
	await _place(Vector3(-2, 6.05, -9), PI / 2.0)
	_knocked = false
	input.move = Vector2(0, 1)
	await _wait(2.0)
	input.move = Vector2.ZERO
	_check(_knocked, "падение с 6 м сбивает с ног")
	_check(_player.mode == PlayerController.Mode.DOWNED, "лежим после падения")
	await _wait(3.2)
	_check(_player.mode == PlayerController.Mode.NORMAL, "встали после падения")
	_check(absf(_player.global_position.y) < 0.15, "встали на землю, а не провалились (y = %.2f)" % _player.global_position.y)

	# 8б. упасть нарочно (Q) и встать
	await _place(Vector3(0, 0.05, 12), 0.0)
	_knocked = false
	input.flop_pressed = true
	await _wait(0.02)
	input.flop_pressed = false
	_check(_knocked and _player.body.ragdoll.active, "по Q персонаж падает рэгдоллом")
	await _wait(4.0)
	_check(_player.mode == PlayerController.Mode.NORMAL and not _player.body.ragdoll.active, "после Q встаём")
	_check(_player.global_position.distance_to(Vector3(0, 0, 12)) < 4.0, "рэгдолл не улетел: остались рядом")

	# 9. прыжок с 2 м с ног не валит
	await _place(Vector3(2, 2.05, -9), PI)
	_knocked = false
	input.move = Vector2(0, 1)
	await _wait(1.5)
	input.move = Vector2.ZERO
	_check(not _knocked, "спрыгнуть с 2 м можно без падения с ног")

	print("Тесты персонажа: прошло %d, провалено %d" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _place(pos: Vector3, yaw: float) -> void:
	_player.global_position = pos
	_player.velocity = Vector3.ZERO
	_player.yaw = yaw
	_player.mode = PlayerController.Mode.NORMAL
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
