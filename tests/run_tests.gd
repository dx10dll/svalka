extends SceneTree
## Автотесты чистой логики без графики.
## Запуск: godot --headless --path . -s tests/run_tests.gd
## Код выхода 0 — всё прошло, 1 — есть провалы.

var _failed: int = 0
var _passed: int = 0


func _initialize() -> void:
	_test_quota()
	_test_scrap_value()
	_test_seed_is_deterministic()
	_test_items_load()
	_test_translations_complete()
	_test_input_actions()
	print("Тесты: прошло %d, провалено %d" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(condition: bool, what: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("ПРОВАЛ: " + what)


func _economy() -> EconomyConfig:
	return load("res://data/economy.tres")


func _test_quota() -> void:
	var cfg: EconomyConfig = _economy()
	_check(cfg.nights() == 7, "в забеге 7 ночей")
	_check(Quota.for_night(cfg, 1, 4) == 3000, "норма 1-й ночи на четверых 3000")
	_check(Quota.for_night(cfg, 7, 4) == 23000, "норма 7-й ночи на четверых 23000")
	_check(Quota.for_night(cfg, 1, 1) == 1350, "норма 1-й ночи в одиночку 1350")
	_check(Quota.for_night(cfg, 3, 2) == 4900, "норма 3-й ночи вдвоём округляется до 4900")
	var prev: int = 0
	for night: int in range(1, cfg.nights() + 1):
		var q: int = Quota.for_night(cfg, night, 3)
		_check(q > prev, "норма растёт от ночи к ночи (ночь %d)" % night)
		prev = q


func _test_scrap_value() -> void:
	var cfg: EconomyConfig = _economy()
	_check(Quota.scrap_value(cfg, ItemData.Material.FERROUS, 70.0) == 420, "батарея 70 кг = 420 ₽")
	_check(Quota.scrap_value(cfg, ItemData.Material.COPPER, 20.0) == 2400, "медь 20 кг = 2400 ₽")


## Заготовка под генерацию свалки: одинаковый сид обязан давать одинаковый результат.
func _test_seed_is_deterministic() -> void:
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 1995
	b.seed = 1995
	var same: bool = true
	for i: int in 64:
		same = same and a.randi() == b.randi()
	_check(same, "одинаковый сид даёт одинаковую последовательность")


func _test_items_load() -> void:
	var items: Array[ItemData] = ItemDb.all()
	_check(items.size() >= 1, "в каталоге есть предметы")
	for it: ItemData in items:
		_check(it.model != null, "у предмета %s есть модель" % it.id)
		_check(it.mass_min_kg > 0.0 and it.mass_max_kg >= it.mass_min_kg, "вес %s задан верно" % it.id)
		var node: Item = ItemDb.spawn(it, RandomNumberGenerator.new())
		_check(node.get_children().any(func(c: Node) -> bool: return c is CollisionShape3D),
				"у предмета %s есть коллизия" % it.id)
		_check(node.grips.size() >= 1, "у предмета %s есть точки хвата" % it.id)
		_check(node.find_children("col_*", "MeshInstance3D", true, false).is_empty(),
				"меши коллизий %s не попали в картинку" % it.id)
		node.free()


func _test_translations_complete() -> void:
	var f := FileAccess.open("res://locale/strings.csv", FileAccess.READ)
	_check(f != null, "файл переводов открывается")
	if f == null:
		return
	var header: PackedStringArray = f.get_csv_line()
	_check(header.size() == 3 and header[1] == "ru" and header[2] == "en", "в переводах языки ru и en")
	var keys: Dictionary = {}
	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		if row.size() < 3 or row[0].is_empty():
			continue
		_check(not keys.has(row[0]), "ключ перевода %s не повторяется" % row[0])
		keys[row[0]] = true
		_check(not row[1].is_empty() and not row[2].is_empty(), "ключ %s переведён на оба языка" % row[0])
	for it: ItemData in ItemDb.all():
		_check(keys.has(it.name_key), "название предмета %s есть в переводах" % it.id)


func _test_input_actions() -> void:
	for action: StringName in [&"move_forward", &"jump", &"crouch", &"grab", &"throw", &"debug_menu"]:
		_check(InputMap.has_action(action), "действие %s есть в карте управления" % action)
	_check(InputMap.action_get_events(&"jump").size() >= 2, "у прыжка есть клавиша и кнопка геймпада")
