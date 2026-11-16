extends Node
## Автотест кучи: генерация по сиду, раскопка, завал, засыпание, ходьба по склону.
## Запуск: godot --headless --path . --fixed-fps 60 res://tests/dump_test.tscn

var _failed: int = 0
var _passed: int = 0
var _player: PlayerController
var _scene: Node
var _dump: Dump
var _input := PlayerInput.new()


func _ready() -> void:
	_scene = (load("res://scenes/debug/test_scene.tscn") as PackedScene).instantiate()
	_scene.set_script(load("res://tests/empty_stage.gd"))
	add_child(_scene)
	_run.call_deferred()


func _run() -> void:
	var cfg: DumpConfig = load("res://data/dump_test.tres")

	# 1. чистая логика: одинаковый сид = одинаковая куча
	var t0: int = Time.get_ticks_msec()
	var a := DumpField.new(cfg, 7)
	var gen_ms: int = Time.get_ticks_msec() - t0
	var b := DumpField.new(cfg, 7)
	var c := DumpField.new(cfg, 8)
	_check(a.checksum() == b.checksum(), "одинаковый сид даёт одинаковую кучу")
	_check(a.checksum() != c.checksum(), "другой сид даёт другую кучу")
	_check(a.sites.size() == b.sites.size() and a.sites.size() >= 8, "ценных вещей в куче: %d" % a.sites.size())
	_check(a.solid_count() > 3000, "ячеек в куче: %d (генерация %d мс)" % [a.solid_count(), gen_ms])
	_check(gen_ms < 1500, "генерация быстрее 1.5 с")
	var top: float = 0.0
	for z: int in a.size.z:
		for x: int in a.size.x:
			var base: Vector3 = a.cell_base(Vector3i(x, 0, z))
			top = maxf(top, a.height_at(base.x, base.z))
	_check(top > cfg.height * 0.7 and top < cfg.height * 1.4, "высота кучи %.1f м" % top)
	var sites_ok: bool = true
	for i: int in a.sites.size():
		for ci: int in a.sites[i]["cells"]:
			sites_ok = sites_ok and a.cells[ci] == -(i + 1)
	_check(sites_ok, "ячейки ценных вещей не пересекаются")

	# 2. опоры: убрали низ столбика мусора — всё, что выше, падает
	var column := Vector3i(-1, -1, -1)
	for x: int in a.size.x:
		for z: int in a.size.z:
			var all_junk: bool = true
			var n: int = 0
			for y: int in a.size.y:
				var v: int = a.at(Vector3i(x, y, z))
				if v < 0:
					all_junk = false
				elif v > 0:
					n += 1
			if all_junk and n >= 6 and column.x < 0:
				column = Vector3i(x, n, z)
	_check(column.x >= 0, "нашёлся столбик из %d кусков" % column.y)
	a.remove_junk(Vector3i(column.x, 0, column.z))
	var lost: Dictionary = a.find_unsupported([Vector3i(column.x, 0, column.z)])
	var fell: Array = lost["junk"]
	var whole_column: bool = true
	for y: int in range(1, column.y):
		whole_column = whole_column and fell.has(Vector3i(column.x, y, column.z))
	_check(whole_column, "без нижнего падают все %d верхних (и ещё %d с боков)" % [column.y - 1, fell.size() - column.y + 1])
	var top_cell := Vector3i(column.x, column.y - 1, column.z)
	a = DumpField.new(cfg, 7)
	a.remove_junk(top_cell)
	_check((a.find_unsupported([top_cell])["junk"] as Array).is_empty(), "сняли верхний — ничего не падает")

	# 2б. склон: вырыли колодец на 5 ячеек — стенки оползают
	a = DumpField.new(cfg, 7)
	for k: int in 5:
		a.remove_junk(Vector3i(column.x, column.y - 1 - k, column.z))
	var slump: Dictionary = a.find_unsupported([Vector3i(column.x, column.y - 5, column.z)])
	_check((slump["junk"] as Array).size() >= 1, "стенки колодца оползают: %d кусков" % (slump["junk"] as Array).size())
	a = DumpField.new(cfg, 7)
	a.remove_junk(top_cell)
	a.remove_junk(top_cell + Vector3i.DOWN)
	var small: int = (a.find_unsupported([top_cell + Vector3i.DOWN])["junk"] as Array).size()
	_check(small <= 2, "ямка в 2 ячейки почти ничего не роняет (%d)" % small)

	# 3. куча в мире
	_dump = Dump.new()
	_dump.dump_seed = 7
	_scene.add_child(_dump)
	await _wait(0.3)
	var f: DumpField = _dump.field
	var shapes: int = 0
	var drawn: int = 0
	for chunk: Dump.DumpChunk in _dump._chunks.values():
		shapes += chunk.shape_cells.size()
		for mmi: MultiMeshInstance3D in chunk.instances:
			if mmi != null:
				drawn += mmi.multimesh.instance_count
	_check(shapes > 300 and shapes < f.solid_count(), "твёрдых ячеек снаружи %d из %d" % [shapes, f.solid_count()])
	_check(drawn == shapes, "нарисовано столько же, сколько твёрдых")
	_check(_dump._site_nodes.size() >= 1, "из кучи торчит вещей: %d" % _dump._site_nodes.size())

	# 4. раскопка: вытащили верхний кусок
	var solid_before: int = f.solid_count()
	var piece: Item = _dump.dig(top_cell)
	_check(piece != null and f.at(top_cell) == 0, "кусок вытащен, ячейка пуста")
	_check(_dump.awake.size() == 1 and _dump.collapse_count == 0, "одно живое тело, завала нет")
	piece.queue_free()
	await _wait(0.1)

	# 5. завал: выдернули кусок из-под других
	var low := Vector3i(column.x, maxi(column.y - 5, 0), column.z)
	var above: int = column.y - 2 - low.y
	var warnings: Array[int] = []
	_dump.collapse_warning.connect(func(_at: Vector3, n: int) -> void: warnings.append(n))
	var pulled: Item = _dump.dig(low)
	_check(warnings.size() == 1 and warnings[0] >= above, "куча предупредила: поедет %d кусков" % warnings[0])
	_check(f.at(low + Vector3i.UP) > 0, "во время предупреждения всё ещё стоит")
	pulled.queue_free()
	await _wait(cfg.warning_time + 0.3)
	_check(_dump.collapse_count >= 1 and f.at(low + Vector3i.UP) == 0, "после предупреждения поехало")
	_check(_dump.awake.size() >= above, "проснулось тел: %d" % _dump.awake.size())

	# 6. засыпание: тела легли и запеклись обратно
	await _wait(9.0)
	_check(_dump.awake.size() <= 4, "через 9 с живых тел осталось %d" % _dump.awake.size())
	_check(f.solid_count() >= solid_before - 8, "куски вернулись в решётку: %d из %d" % [f.solid_count(), solid_before])

	# 7. ценная вещь: забрали — место опустело
	var site_item: Item = _dump._site_nodes.values()[0]
	var site_index: int = site_item.get_meta(&"dump_site")
	_check(site_item.freeze, "вещь в куче неподвижна")
	_dump.release_site(site_item)
	_check(not site_item.freeze and f.sites[site_index]["taken"], "вещь забрана и ожила")
	_check(f.cells[f.sites[site_index]["cells"][0]] == 0, "место вещи опустело")

	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	_player.position = Vector3(0, 0.05, cfg.radius + 1.0)
	_scene.add_child(_player)
	_player.scripted_input = _input
	await _wait(0.5)
	# 8. раскопка руками через обычный ввод: навелись на кучу, зажали ЛКМ
	_input.move = Vector2(0, 1)
	await _wait(0.6)
	_input.move = Vector2.ZERO
	_player.pitch = -0.45
	await _wait(0.2)
	_check(_player.grab.focus_dump == _dump or _player.grab.focus != null,
			"куча или вещь под прицелом (z = %.1f)" % _player.global_position.z)
	_input.grab_held = true
	await _wait(0.8)
	_check(_player.grab.held != null, "кусок кучи в руках")
	_check(_player.grab.held != null and _player.grab.held.get_parent() == _dump and not _player.grab.held.freeze,
			"вытащенный кусок стал живым телом")
	_input.grab_held = false
	await _wait(0.3)

	# 8б. лопата: ПКМ по куче отбрасывает куски, руки остаются пустыми
	await _wait(4.0)   # вытащенный кусок улёгся и снова стал частью кучи
	_check(_player.grab.focus_dump == _dump, "перед лопатой под прицелом снова куча")
	var tossed: Array[RigidBody3D] = []
	_player.grab.shoveled.connect(func(p: RigidBody3D) -> void: tossed.append(p))
	_input.throw_held = true
	await _wait(2.0)
	_input.throw_held = false
	var found_loot: bool = _player.grab.focus is Item and not (_player.grab.focus as Item).data.is_trash()
	_check((tossed.size() >= 2 or found_loot) and tossed.size() >= 1 and _player.grab.held == null,
			"лопатой за 2 секунды отброшено %d кусков%s" % [tossed.size(), ", докопались до вещи" if found_loot else ""])

	# 8в. засыпанный игрок: выбирается рывками
	var pile: Array[RigidBody3D] = []
	for k: int in 2:
		var piece_b: Item = _dump._spawn_junk(0, Transform3D(Basis.IDENTITY, _player.global_position + Vector3(0.3 * k, 0.6, 0)))
		piece_b.freeze = true
		piece_b.set_meta(&"burying", true)
		pile.append(piece_b)
	var ended: Array[bool] = []
	_player.buried_ended.connect(func(ok: bool) -> void: ended.append(ok))
	_player.bury(pile)
	var buried_at: Vector3 = _player.global_position
	_input.move = Vector2(0, 1)
	await _wait(1.0)
	_check(_player.mode == PlayerController.Mode.BURIED and _player.global_position.distance_to(buried_at) < 0.05,
			"под завалом не уйти")
	_check(_player.air_left < _player.feel.buried_air - 0.9, "воздух уходит: %.1f с" % _player.air_left)
	_input.move = Vector2.ZERO
	for k: int in _player.feel.buried_struggle_presses * 2:
		_input.jump_pressed = true
		await get_tree().physics_frame
		_input.jump_pressed = false
		await get_tree().physics_frame
	await _wait(0.1)
	_check(_player.mode == PlayerController.Mode.NORMAL and ended == [true], "выбрался сам за %d рывков" % (_player.feel.buried_struggle_presses * 2))
	# не выбрался: воздух кончился
	var one: Item = _dump._spawn_junk(0, Transform3D(Basis.IDENTITY, _player.global_position + Vector3(0, 0.6, 0)))
	one.freeze = true
	_player.bury([one] as Array[RigidBody3D])
	_player.air_left = 0.2
	await _wait(0.5)
	_check(ended == [true, false] and _player.mode == PlayerController.Mode.NORMAL, "без воздуха — возврат на старт")
	_check(_player.global_position.distance_to(Vector3(0, 0.05, cfg.radius + 1.0)) < 1.0, "игрок снова на старте")
	await _wait(0.3)

	# 9. по куче можно зайти наверх пешком
	_input.move = Vector2(0, 1)
	_input.jump_held = true
	var reached: float = 0.0
	for i: int in 60 * 14:
		_input.jump_pressed = i % 40 == 0
		await get_tree().physics_frame
		reached = maxf(reached, _player.global_position.y)
	_input.move = Vector2.ZERO
	_check(reached > cfg.height * 0.8, "пешком и прыжками поднялись на %.1f м (вершина %.1f)" % [reached, top])

	# 10. большая гора: подробные чанки только рядом с игроком
	_dump.queue_free()
	_player.queue_free()
	await _wait(0.2)
	var big_cfg: DumpConfig = load("res://data/dump_mountain.tres")
	t0 = Time.get_ticks_msec()
	var big := Dump.new()
	big.config = big_cfg
	big.dump_seed = 3
	_scene.add_child(big)
	big.prime(Vector3(0, 0, big_cfg.radius), 20.0)
	var build_ms: int = Time.get_ticks_msec() - t0
	var total_columns: int = big._columns.x * big._columns.y
	var loaded_first: int = big._loaded.size()
	_check(build_ms < 6000, "гора из %d ячеек готова за %d мс" % [big.field.solid_count(), build_ms])
	_check(loaded_first > 10 and loaded_first < total_columns / 4, "подробно построено %d столбцов из %d" % [loaded_first, total_columns])
	var top_big: float = 0.0
	for h: int in big.field.heights:
		top_big = maxf(top_big, h * big_cfg.cell_size.y)
	_check(top_big > 25.0 and top_big < 45.0, "высота горы %.1f м" % top_big)
	var walker := Node3D.new()
	walker.add_to_group(&"players")
	_scene.add_child(walker)
	walker.global_position = Vector3(0, 0, -big_cfg.radius)
	await _wait(3.0)
	var near_col: Vector2i = Vector2i(big._columns.x / 2, 1 + int(big_cfg.margin / 4.0))
	_check(big._loaded.has(near_col), "у нового места чанки подгрузились")
	_check(not big._loaded.has(Vector2i(big._columns.x / 2, big._columns.y - 2 - int(big_cfg.margin / 4.0))),
			"у старого места чанки выгружены (построено %d)" % big._loaded.size())
	var body_count: int = 0
	for chunk: Dump.DumpChunk in big._chunks.values():
		body_count += chunk.shape_cells.size()
	_check(body_count > 500 and body_count < 40000, "твёрдых ячеек рядом с игроком: %d" % body_count)

	# 11. окружение свалки: по сиду, одинаковое у всех
	var site_a := DumpSite.new()
	_scene.add_child(site_a)
	site_a.build(big_cfg.radius, 3)
	var site_b := DumpSite.new()
	_scene.add_child(site_b)
	site_b.build(big_cfg.radius, 3)
	_check(site_a.fires.size() == DumpSite.BONFIRES, "костров: %d" % site_a.fires.size())
	var same_site: bool = site_a.get_child_count() == site_b.get_child_count()
	for i: int in site_a.fires.size():
		same_site = same_site and site_a.fires[i].position.is_equal_approx(site_b.fires[i].position)
	_check(same_site, "одинаковый сид расставляет окружение одинаково")
	var clear: bool = true
	for fire: Fire in site_a.fires:
		clear = clear and Vector2(fire.position.x, fire.position.z).length() > big_cfg.radius + 3.0 \
				and (absf(fire.position.x) > 4.0 or fire.position.z < 0.0)
	_check(clear, "костры стоят вне горы и не на дороге")
	_check(site_a.booth_position.z > big_cfg.radius + 20.0, "будка сторожа у въезда")

	print("Тесты кучи: прошло %d, провалено %d" % [_passed, _failed])
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
