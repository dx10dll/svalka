extends Node
## Серия снимков для отчётов и самопроверки: сценарий управляет персонажем,
## внешняя камера снимает его со стороны в заданные моменты.
## Запуск (нужен экран, в облаке — xvfb):
##   godot --path . res://tests/visual/shots.tscn -- --out=папка [--only=имя]

const DUMP_SCENE: String = "res://scenes/debug/playground_dump.tscn"
const PLAYGROUND: String = "res://scenes/debug/playground_stage1.tscn"

var _player: PlayerController
var _input := PlayerInput.new()
var _cam: Camera3D
var _out: String = "user://shots"
var _only: String = ""
var _counter: int = 0


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=")
	DirAccess.make_dir_recursive_absolute(_out)
	var scene: Node = (load(DUMP_SCENE if _only == "dump" or _only == "van" else PLAYGROUND) as PackedScene).instantiate()
	add_child(scene)
	_player = scene.find_child("Player", true, false)
	_player.scripted_input = _input
	_cam = Camera3D.new()
	_cam.fov = 60.0
	_cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_cam)
	_run.call_deferred()


func _run() -> void:
	await _wait(0.3)
	if _only == "dump":
		await _run_dump()
		get_tree().quit()
		return
	if _only == "van":
		await _run_van()
		get_tree().quit()
		return
	if _want("stand"):
		await _third_person(Vector3(0, 0.05, 2), 0.0, Vector3(1.6, 1.0, -0.4))
		await _snap("stand")
		_input.move = Vector2(0, 1)
		await _wait(0.5)
		_follow(Vector3(1.6, 1.0, -0.4))
		await _snap("walk")
		_input.sprint_held = true
		await _wait(0.5)
		_follow(Vector3(1.6, 1.0, -0.4))
		await _snap("run")
		_input.sprint_held = false
		_input.move = Vector2.ZERO
		_input.crouch_held = true
		await _wait(0.6)
		_follow(Vector3(1.6, 1.0, -0.4))
		await _snap("crouch")
		_input.crouch_held = false
	if _want("fall"):
		# шаг с вышки 6 м: рэгдолл в полёте, на земле и вставание
		await _third_person(Vector3(-2, 6.05, -9), PI / 2.0, Vector3(-6.5, 2.2, -4.5), false)
		_input.move = Vector2(0, 1)
		var times: Array[float] = [0.75, 0.12, 0.12, 0.15, 0.2, 0.4, 0.8, 0.5]
		for i: int in times.size():
			await _wait(times[i])
			if i >= 1:  # после срыва снимаем вблизи
				_cam.global_position = _player.body.ragdoll.hips_position() + Vector3(-1.6, 0.9, 2.0)
			_look_at_player()
			await _snap("fall")
		_input.move = Vector2.ZERO
		await _wait(1.5)
		_look_at_player()
		await _snap("fall")
	if _want("carry"):
		# несём бухту: вид сбоку и от первого лица
		var coil: Item = _find_item(&"cable_coil")
		await _third_person(coil.global_position + Vector3(0, 0.05, 1.1), 0.0, Vector3(1.5, 0.9, 0.2))
		await _take(coil)
		_follow(Vector3(1.4, 0.7, -0.9))
		await _snap("carry_coil")
		_first_person()
		await _wait(0.2)
		await _snap("carry_coil_first_person")
		_input.grab_held = false
		await _wait(0.4)
		# телевизор: несём, потом роняем с высоты — всплывает потеря
		var tv: Item = _find_item(&"tv_crt")
		await _third_person(tv.global_position + Vector3(0, 0.05, 1.1), 0.0, Vector3(1.5, 0.9, 0.2))
		await _take(tv)
		_first_person()
		await _wait(0.2)
		await _snap("carry_tv_first_person")
		_input.grab_held = false
		await _wait(0.3)
		tv.global_position += Vector3(0, 4.0, -1.0)
		tv.linear_velocity = Vector3.ZERO
		_player.pitch = -0.25
		await _wait(1.05)
		await _snap("tv_broken")
		# батарея: волоком
		var radiator: Item = _find_item(&"radiator_cast_iron")
		await _third_person(radiator.global_position + Vector3(0, 0.05, 1.2), 0.0, Vector3(1.6, 0.9, 0.3))
		await _take(radiator)
		_input.move = Vector2(0, -1)
		await _wait(1.2)
		_follow(Vector3(1.8, 0.9, -0.6))
		await _snap("drag_radiator")
		_input.move = Vector2.ZERO
		_input.grab_held = false
		await _wait(0.3)
	if _want("items"):
		# новые предметы: общий вид, обводка под прицелом, холодильник волоком
		await _place(Vector3(0.6, 0.05, 2.6), 0.0)
		_cam.global_position = Vector3(0.4, 1.5, 4.6)
		_cam.make_current()
		_cam.look_at(Vector3(0.4, 0.5, -0.5))
		_player.body.set_first_person(false)
		await _snap("items_overview")
		var samovar: Item = _find_item(&"samovar")
		await _place(samovar.global_position + Vector3(0, 0.05, 1.0), 0.0)
		var to: Vector3 = samovar.global_position + Vector3.UP * 0.2 - _player.grab.eye()
		_player.pitch = atan2(to.y, Vector2(to.x, to.z).length())
		_first_person()
		await _wait(0.3)
		await _snap("samovar_outline")
		await _take(samovar)
		await _snap("samovar_first_person")
		_input.grab_held = false
		await _wait(0.4)
		var fridge: Item = _find_item(&"fridge")
		await _third_person(fridge.global_position + Vector3(0.3, 0.05, 1.3), 0.0, Vector3(1.9, 1.0, 0.6))
		await _take(fridge)
		_input.move = Vector2(0, -1)
		await _wait(0.9)
		_follow(Vector3(2.1, 1.0, -0.4))
		await _snap("drag_fridge")
		_input.move = Vector2.ZERO
		_input.grab_held = false
		await _wait(0.3)
	if _want("fp"):
		# вид от первого лица: взгляд вниз на свои руки и ноги
		await _place(Vector3(0, 0.05, 2), 0.0)
		_player.body.set_first_person(true)
		_player.pitch = -0.9
		(_player.get_node(^"Camera") as PlayerCamera).camera.make_current()
		_input.move = Vector2(0, 1)
		await _wait(0.45)
		await _snap("first_person_down")
		_player.pitch = -0.1
		await _wait(0.2)
		await _snap("first_person")
		_input.move = Vector2.ZERO
	get_tree().quit()


## Куча: общий вид, раскопка руками, вещь в мусоре, завал до и после.
func _run_dump() -> void:
	var dump: Dump = find_child("Dump", true, false)
	var f: DumpField = dump.field
	var r: float = dump.config.radius
	await _third_person(Vector3(0, 0.05, r + 0.2), 0.0, Vector3(3.5, 2.2, 6.0))
	await _snap("dump_overview")
	# раскопка руками: навелись на кучу, вытащили кусок
	await _place(Vector3(0.4, 0.05, r + 0.1), 0.0)
	_first_person()
	_input.flashlight_pressed = true
	await get_tree().physics_frame
	_input.flashlight_pressed = false
	_player.pitch = -0.3
	await _wait(0.3)
	await _snap("dump_aim")
	_input.grab_held = true
	await _wait(0.9)
	_player.pitch = -0.1
	await _wait(0.6)
	await _snap("dump_piece_in_hands")
	_player.yaw = 2.4
	await _wait(0.4)
	_input.throw_held = true
	await _wait(0.5)
	_input.throw_held = false
	_input.grab_held = false
	await _wait(0.2)
	# завал: выдёргиваем кусок из-под столбика на склоне
	var target := Dump.NO_CELL
	var best: int = 0
	for x: int in f.size.x:
		for z: int in f.size.z:
			for y: int in range(1, 6):
				var c := Vector3i(x, y, z)
				if f.at(c) <= 0 or not f.is_exposed(c) or f.cell_base(c).z < 3.0:
					continue
				var above: int = 0
				while f.at(c + Vector3i.UP * (above + 1)) != 0:
					above += 1
				if above > best and above <= 9 and absf(f.cell_base(c).x) < 5.0:
					best = above
					target = c
	var at: Vector3 = f.cell_base(target)
	print("Завал: ячейка ", target, ", над ней ", best)
	await _third_person(Vector3(at.x - 2.5, 0.05, 13.5), 0.0, Vector3.ZERO, false)
	_cam.global_position = at + Vector3(1.8, 1.4, 3.6)
	_cam.look_at(at + Vector3.UP * 0.7)
	var lamp := OmniLight3D.new()   # подсветка места завала для снимка
	lamp.light_color = Color(1.0, 0.8, 0.55)
	lamp.light_energy = 3.0
	lamp.omni_range = 9.0
	add_child(lamp)
	lamp.global_position = at + Vector3(-1.0, 2.2, 3.0)
	await _wait(0.3)
	await _snap("collapse_before")
	# копаем вглубь склона на три ячейки: над ямой остаётся всё больше мусора
	for step: int in 3:
		for side: int in [-1, 0, 1]:
			var pulled: Item = dump.dig(target + Vector3i.FORWARD * step + Vector3i.RIGHT * side)
			if pulled != null:
				pulled.apply_central_impulse(Vector3(side * 2.0, 1, 5) * pulled.mass)
	await _wait(dump.config.warning_time * 0.6)
	await _snap("collapse_warning")
	await _wait(dump.config.warning_time * 0.4 + 0.3)
	await _snap("collapse_falling")
	await _wait(0.4)
	await _snap("collapse_falling")
	await _wait(1.2)
	await _snap("collapse_settling")
	await _wait(7.0)
	await _snap("collapse_after")
	# вещь, торчащая из кучи
	var nearest: Item = null
	for item: Item in dump._site_nodes.values():
		if item.has_meta(&"dump_site") and item.global_position.y < 2.0 and item.global_position.z > 0.0 \
				and (nearest == null or item.global_position.z > nearest.global_position.z):
			nearest = item
	if nearest != null:
		_cam.global_position = nearest.global_position + Vector3(1.2, 1.3, 3.2)
		_cam.look_at(nearest.global_position + Vector3.UP * 0.3)
		nearest.set_highlight(true)
		await _wait(0.2)
		await _snap("loot_in_heap")
	# засыпанный игрок: вид со стороны и изнутри
	await _third_person(Vector3(2.0, 0.05, r + 0.3), 0.0, Vector3(2.2, 1.3, 2.6))
	var heap: Array[Item] = []
	for k: int in 6:
		heap.append(dump._spawn_junk(k % 6, Transform3D(Basis.IDENTITY, _player.global_position + Vector3(0, 1.0, -0.5))))
	dump._bury_players(dump.to_local(_player.global_position) + Vector3(0, 0.5, -0.5), heap)
	await _wait(0.4)
	_look_at_player()
	await _snap("buried_outside")
	_first_person()
	await _wait(0.3)
	await _snap("buried_inside")
	for k: int in _player.feel.buried_struggle_presses * 4:
		_input.jump_pressed = true
		await get_tree().physics_frame
		_input.jump_pressed = false
		await get_tree().physics_frame
	await _snap("buried_half_out")
	for k: int in _player.feel.buried_struggle_presses * 2:
		_input.jump_pressed = true
		await get_tree().physics_frame
		_input.jump_pressed = false
		await get_tree().physics_frame
	await _wait(0.5)
	# тёмная сторона кучи с фонарём
	await _place(Vector3(0.0, 0.05, -r - 1.2), PI)
	_first_person()
	_player.pitch = 0.15
	await _wait(0.3)
	await _snap("flashlight")


## Буханка: общий вид, кузов с грузом, подсказка у двери, вид из кабины, езда, перегруз.
func _run_van() -> void:
	var van: Van = find_child("Van", true, false)
	var scene: Node = van.get_parent()
	# разворачиваем носом вдоль кучи: впереди 45 м площадки
	var turn: float = -PI * 0.5
	van.global_transform = Transform3D(Basis(Vector3.UP, turn), van.global_position)
	van.reset_physics_interpolation()
	await _wait(1.0)
	await _third_person(van.to_global(Vector3(2.6, 0.0, 3.6)), 0.6 + turn, Vector3(1.6, 0.9, 2.4))
	_cam.global_position = van.to_global(Vector3(4.6, 1.7, 5.6))
	_cam.look_at(van.to_global(Vector3(0, 0.9, 0)))
	await _snap("van_front")
	# кузов: двери открыты, внутри груз
	van.toggle_doors()
	var radiator: ItemData = load("res://data/items/radiator_cast_iron.tres")
	var fridge: ItemData = load("res://data/items/fridge.tres")
	var tv: ItemData = load("res://data/items/tv_crt.tres")
	scene._spawn(fridge, Transform3D(van.global_basis, van.to_global(Vector3(-0.45, 1.0, 0.3))))
	scene._spawn(radiator, Transform3D(van.global_basis * Basis(Vector3.RIGHT, PI * 0.5), van.to_global(Vector3(0.4, 0.9, -0.2))))
	scene._spawn(radiator, Transform3D(van.global_basis * Basis(Vector3.RIGHT, PI * 0.5), van.to_global(Vector3(0.4, 0.9, -0.9))))
	scene._spawn(tv, Transform3D(van.global_basis, van.to_global(Vector3(-0.4, 0.9, -1.1))))
	await _place(van.to_global(Vector3(-1.9, 0.0, -4.2)), turn)
	_player.yaw = PI + 0.5 + turn
	await _wait(1.5)
	van.set_straps(true)
	_cam.global_position = van.to_global(Vector3(-2.6, 1.9, -5.4))
	_cam.look_at(van.to_global(Vector3(0, 1.1, -1.2)))
	await _snap("van_cargo")
	# подсказка у задних дверей от первого лица
	await _place(van.to_global(Vector3(0.2, 0.0, -4.4)), PI + turn)
	_first_person()
	_player.pitch = 0.1
	await _wait(0.3)
	await _snap("van_bay_first_person")
	# подсказка у двери водителя
	await _place(van.to_global(Vector3(2.5, 0.0, 1.5)), PI * 0.5 + turn)
	_player.pitch = 0.1
	await _wait(0.3)
	await _snap("van_door_hint")
	# сели за руль
	await get_tree().physics_frame      # после снимка мы вне физического тика: выравниваемся
	_input.interact_pressed = true
	await get_tree().physics_frame
	_input.interact_pressed = false
	await _wait(0.5)
	await _snap("van_cab")
	van.toggle_doors()
	_input.move = Vector2(0.0, 1.0)
	await _wait(1.2)
	await _snap("van_cab_driving")
	_player.body.set_first_person(false)
	_cam.make_current()
	_cam.global_position = van.to_global(Vector3(-5.0, 1.6, 9.0))
	await _wait(0.4)
	_cam.look_at(van.global_position + Vector3(0, 1.0, 0.0))
	await _snap("van_driving")
	_input.move = Vector2(-1.0, 0.6)
	await _wait(1.2)
	_cam.global_position = van.global_position + van.global_basis * Vector3(-5.5, 1.8, 5.0)
	_cam.look_at(van.global_position + Vector3(0, 1.0, 0.0))
	await _snap("van_turning")
	_input.move = Vector2.ZERO
	_input.jump_held = true
	await _wait(2.5)
	_input.jump_held = false
	# перегруз: ещё 14 батарей в кузов
	for i: int in 14:
		scene._spawn(radiator, Transform3D(van.global_basis * Basis(Vector3.RIGHT, PI * 0.5),
				van.to_global(Vector3(-0.42 + 0.84 * (i % 2), 1.3 + 0.18 * (i / 2), -1.3 - 0.05 * (i / 2)))))
	await _wait(3.0)
	_cam.global_position = van.global_position + van.global_basis * Vector3(6.5, 1.1, -0.6)
	_cam.look_at(van.global_position + Vector3(0, 0.9, 0.0))
	await _snap("van_overloaded")
	_first_person()
	_player.pitch = -0.25
	_player.seat_look = 0.5
	await _wait(0.3)
	await _snap("van_overloaded_hud")


func _find_item(id: StringName) -> Item:
	for n: Node in get_tree().get_nodes_in_group(&"items"):
		if (n as Item).data.id == id:
			return n
	return null


## Навестись на предмет, взять и поднять взгляд.
func _take(item: Item) -> void:
	var to: Vector3 = item.global_position + Vector3.UP * 0.12 - _player.grab.eye()
	_player.yaw = atan2(-to.x, -to.z)
	_player.pitch = atan2(to.y, Vector2(to.x, to.z).length())
	await _wait(0.1)
	_input.grab_held = true
	await _wait(0.4)
	_player.pitch = -0.1
	await _wait(1.0)


func _first_person() -> void:
	_player.body.set_first_person(true)
	(_player.get_node(^"Camera") as PlayerCamera).camera.make_current()


func _want(scenario: String) -> bool:
	return _only.is_empty() or _only == scenario


func _third_person(pos: Vector3, yaw: float, cam_offset: Vector3, follow: bool = true) -> void:
	await _place(pos, yaw)
	_player.body.set_first_person(false)
	_cam.global_position = pos + cam_offset if follow else cam_offset
	_cam.make_current()
	_look_at_player()


func _follow(cam_offset: Vector3) -> void:
	_cam.global_position = _player.global_position + cam_offset
	_look_at_player()


func _look_at_player() -> void:
	var target: Vector3 = _player.global_position + Vector3.UP * 0.7
	if _player.body.ragdoll.active:
		target = _player.body.ragdoll.hips_position()
	_cam.look_at(target)


func _place(pos: Vector3, yaw: float) -> void:
	_player.global_position = pos
	_player.velocity = Vector3.ZERO
	_player.yaw = yaw
	_player.pitch = 0.0
	_player.reset_physics_interpolation()
	await _wait(0.4)


func _wait(seconds: float) -> void:
	for i: int in int(ceil(seconds * Engine.physics_ticks_per_second)):
		await get_tree().physics_frame


func _snap(label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_counter += 1
	var path: String = "%s/%02d_%s.png" % [_out, _counter, label]
	get_viewport().get_texture().get_image().save_png(path)
	print("Снимок: ", path)
