extends Node
## Автотест фургона: стоит, едет, тормозит, рулит, возит груз, перегруз душит мотор,
## игрок садится за руль и выходит.
## Запуск: godot --headless --path . --fixed-fps 60 res://tests/van_test.tscn

const RADIATOR: String = "res://data/items/radiator_cast_iron.tres"

var _failed: int = 0
var _passed: int = 0
var _scene: Node
var _van: Van


func _ready() -> void:
	_scene = (load("res://scenes/debug/test_scene.tscn") as PackedScene).instantiate()
	_scene.set_script(load("res://tests/empty_stage.gd"))
	add_child(_scene)
	_run.call_deferred()


func _new_van(at: Vector3) -> Van:
	if _van != null:
		_van.queue_free()
	_van = Van.new()
	_van.position = at
	_scene.add_child(_van)
	return _van


func _run() -> void:
	var feel: VanFeel = load(Van.FEEL_PATH)

	# 1. стоит на колёсах и не уезжает
	_new_van(Vector3(0.0, 0.4, -38.0))
	await _wait(2.0)
	var rest_y: float = _van.global_position.y
	var rest_rear: float = _van.rear_height()
	_check(absf(rest_y) < 0.04, "машина встала на колёса, кузов на высоте %.2f м от задуманной" % rest_y)
	_check(_van.global_basis.y.y > 0.995, "стоит ровно")
	var parked_at: Vector3 = _van.global_position
	await _wait(2.0)
	_check(_van.global_position.distance_to(parked_at) < 0.01,
			"на ручнике не ползёт (за 2 с сдвиг %.3f м)" % _van.global_position.distance_to(parked_at))
	_check(is_equal_approx(_van.cargo_mass(), 0.0) and is_equal_approx(_van.power_factor(), 1.0), "кузов пуст, тяга полная")

	# 2. разгон, тормоз
	_van.set_engine(true)
	_van.brake_input = 0.0
	_van.throttle = 1.0
	await _wait(3.0)
	var empty_run: float = _van.global_position.z + 38.0
	var v3: float = _van.forward_speed()
	_check(v3 > 6.0 and empty_run > 10.0, "за 3 с разогналась до %.1f м/с и проехала %.1f м" % [v3, empty_run])
	_check(absf(_van.global_position.x) < 0.6, "едет прямо (увело на %.2f м)" % _van.global_position.x)
	await _wait(1.8)
	var top: float = _van.forward_speed()
	_check(top > feel.max_speed * 0.8 and top <= feel.max_speed * 1.05, "наибольшая скорость %.1f м/с" % top)
	_van.throttle = 0.0
	_van.brake_input = 1.0
	var brake_from: float = _van.global_position.z
	await _wait(3.0)
	_check(absf(_van.forward_speed()) < 0.2, "затормозила, путь %.1f м" % (_van.global_position.z - brake_from))
	_check(_van.global_basis.y.y > 0.98, "не перевернулась при торможении")

	# 3. руль: плюс — влево (к +X), минус — вправо
	_new_van(Vector3(0.0, 0.4, 0.0))
	await _wait(1.0)
	_van.set_engine(true)
	_van.brake_input = 0.0
	_van.throttle = 0.6
	_van.steer = 1.0
	await _wait(2.5)
	_check(_van.global_position.x > 1.0 and _van.global_basis.z.x > 0.3, "руль влево уводит к +X (x=%.1f)" % _van.global_position.x)
	_van.steer = -1.0
	_van.throttle = 1.0      # газ в пол с вывернутым рулём
	await _wait(4.0)
	_check(_van.global_basis.y.y > 0.95, "в повороте не опрокинулась (крен %.0f°)" % rad_to_deg(acos(clampf(_van.global_basis.y.y, -1.0, 1.0))))
	_van.steer = 0.0
	_van.throttle = 0.0
	_van.brake_input = 1.0
	await _wait(2.0)

	# 4. задний ход
	_new_van(Vector3(0.0, 0.4, 0.0))
	await _wait(1.0)
	_van.set_engine(true)
	_van.brake_input = 0.0
	_van.throttle = -1.0
	await _wait(3.0)
	_check(_van.global_position.z < -3.0 and _van.forward_speed() < -2.0 and _van.forward_speed() > -feel.max_reverse_speed * 1.1,
			"задний ход: %.1f м/с" % _van.forward_speed())
	_van.throttle = 0.0
	_van.brake_input = 1.0
	await _wait(2.0)

	# 5. двери и подсказки
	_check(_van.interaction_at(_van.to_global(Vector3(0.0, 1.2, -2.2))).get("action") == &"doors", "сзади — двери")
	_check(_van.interaction_at(_van.to_global(Vector3(0.95, 1.2, 1.5))).get("action") == &"drive", "у кабины слева — за руль")
	_check(_van.interaction_at(_van.to_global(Vector3(-0.95, 1.2, -0.5))).is_empty(), "у борта — ничего")
	_van.toggle_doors()
	await _wait(0.8)
	_check(_van.doors_open and _van._doors[0].rotation.y < -1.5, "двери открылись")

	# 6. груз: вес считается, зад проседает
	_new_van(Vector3(0.0, 0.4, -30.0))
	await _wait(1.5)
	var data: ItemData = load(RADIATOR)
	var cargo: Array[Item] = []
	for i: int in 8:
		cargo.append(_load(data, i))
	await _wait(2.5)
	_check(absf(_van.cargo_mass() - 560.0) < 1.0, "в кузове %.0f кг (8 батарей)" % _van.cargo_mass())
	var sag: float = rest_rear - _van.rear_height()
	_check(sag > 0.03 and sag < 0.2, "зад просел на %.1f см" % (sag * 100.0))
	_check(is_equal_approx(_van.power_factor(), 1.0), "в пределах нормы тяга полная")
	_van.set_engine(true)
	_van.brake_input = 0.0
	_van.throttle = 1.0
	await _wait(3.0)
	var loaded_run: float = _van.global_position.z + 30.0
	_check(loaded_run > 6.0 and loaded_run < empty_run, "с грузом за 3 с проехала %.1f м (пустая %.1f)" % [loaded_run, empty_run])
	_van.throttle = 0.0
	_van.brake_input = 1.0
	await _wait(3.0)
	var kept: int = 0
	for item: Item in cargo:
		if absf(_van.to_local(item.global_position).x) < 0.95 and _van.to_local(item.global_position).y > 0.5:
			kept += 1
	_check(kept == 8, "груз остался в кузове после разгона и торможения: %d из 8" % kept)

	# 7. перегруз: 20 батарей — 1400 кг
	_new_van(Vector3(0.0, 0.4, -30.0))
	for item: Item in cargo:
		item.queue_free()
	await _wait(1.5)
	for i: int in 20:
		_load(data, i)
	await _wait(3.0)
	var over: float = _van.cargo_mass()
	_check(over > 1300.0, "в кузове %.0f кг при норме %.0f" % [over, feel.capacity])
	_check(_van.power_factor() < 0.5, "мотор душит: тяга %.0f%%" % (_van.power_factor() * 100.0))
	var over_sag: float = rest_rear - _van.rear_height()
	_check(over_sag > sag * 1.5, "зад просел на %.1f см" % (over_sag * 100.0))
	_check(_van.global_basis.y.y > 0.97, "не опрокинулась под грузом")
	_van.set_engine(true)
	_van.brake_input = 0.0
	_van.throttle = 1.0
	await _wait(3.0)
	var over_run: float = _van.global_position.z + 30.0
	_check(over_run > 0.5 and over_run < loaded_run * 0.6, "перегруженная за 3 с проехала %.1f м" % over_run)
	_van.throttle = 0.0
	_van.brake_input = 1.0
	await _wait(2.0)

	# 8. игрок: сесть за руль, поехать, выйти
	_new_van(Vector3(0.0, 0.4, -25.0))
	await _wait(1.5)
	var player: PlayerController = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	var input := PlayerInput.new()
	player.scripted_input = input
	player.position = Vector3(2.4, 0.05, -23.6)
	player.rotation.y = PI * 0.5      # лицом к -X, к двери водителя
	_scene.add_child(player)
	await _wait(0.5)
	_check(player.grab.focus_van == _van and player.grab.focus_action.get("action") == &"drive",
			"смотрим на дверь кабины — подсказка «за руль»")
	_check(player.grab.focus == null, "машину нельзя взять руками")
	input.interact_pressed = true
	await get_tree().physics_frame
	input.interact_pressed = false
	await _wait(0.2)
	_check(player.mode == PlayerController.Mode.SEATED and _van.driver == player and _van.engine_on, "сел за руль, мотор завёлся")
	_check(_van.headlights_on, "фары включились")
	input.move = Vector2(0.0, 1.0)
	await _wait(3.0)
	_check(_van.global_position.z > -19.0, "едет от ввода игрока (z=%.1f)" % _van.global_position.z)
	var seat_error: float = (_van.to_global(player.seat_eye_local) - (player.global_position + Vector3.UP * player.eye_height())).length()
	_check(seat_error < 0.35, "игрок едет вместе с машиной (отстал на %.2f м)" % seat_error)
	input.move = Vector2.ZERO
	input.jump_held = true
	await _wait(3.0)
	input.jump_held = false
	_check(absf(_van.forward_speed()) < 0.2, "пробел — тормоз")
	input.interact_pressed = true
	await get_tree().physics_frame
	input.interact_pressed = false
	await _wait(1.0)
	var out: Vector3 = _van.to_local(player.global_position)
	_check(player.mode == PlayerController.Mode.NORMAL and _van.driver == null and not _van.engine_on, "вышел, мотор заглушен")
	_check(absf(out.x) > 1.2 and player.global_position.y < 0.3 and player.is_on_floor(),
			"стоит на земле рядом с машиной (%.1f м от оси)" % absf(out.x))
	await _wait(1.0)
	var left_at: Vector3 = _van.global_position
	await _wait(1.0)
	_check(_van.global_position.distance_to(left_at) < 0.01, "оставленная машина стоит на ручнике")

	print("Тесты фургона: прошло %d, провалено %d" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


## Кладёт батарею в кузов: по две в ряд, рядами от кабины к дверям, слоями.
func _load(data: ItemData, i: int) -> Item:
	var layer: int = i / 8
	var slot: int = i % 8
	var local := Vector3(-0.42 + 0.84 * (slot % 2), 0.95 + layer * 0.5, 0.45 - 0.62 * (slot / 2))
	var item: Item = _scene._spawn(data, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), _van.to_global(local)))
	return item


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
