extends Node
## Серия снимков для отчётов и самопроверки: сценарий управляет персонажем,
## внешняя камера снимает его со стороны в заданные моменты.
## Запуск (нужен экран, в облаке — xvfb):
##   godot --path . res://tests/visual/shots.tscn -- --out=папка [--only=имя]

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
	var scene: Node = (load(PLAYGROUND) as PackedScene).instantiate()
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
