class_name Guard
extends CharacterBody3D
## Сторож свалки. Заплатили — сидит в будке. Пролезли мимо — выходит искать:
## обходит гору по кругу, идёт на шум и на свет фонаря, увидел — гонится.
## Поймал — отбирает то, что в руках, и выводит за ворота. На гору не лезет.
## Решения принимает только хост; состояние отделено от картинки.

signal state_changed(state: State)
signal spotted(player: PlayerController)
signal caught(player: PlayerController, taken: Item)
## Догнал, а ему сунули бутылку
signal bribed(player: PlayerController)

enum State { BOOTH, PATROL, INVESTIGATE, CHASE, RETURN }

const MODEL: String = "res://assets/models/characters/guard.glb"
const CONFIG_PATH: String = "res://data/guard.tres"
const PATROL_POINTS: int = 8

var config: GuardConfig
var state: State = State.BOOTH
## Центр и радиус горы: вокруг неё он ходит
var heap_center := Vector3.ZERO
var heap_radius: float = 20.0
var booth_point := Vector3.ZERO
## Куда выводит пойманных (за ворота)
var exit_point := Vector3.ZERO
var target: PlayerController
## Насколько он уверен, что видит игрока, 0..1
var suspicion: float = 0.0

var _goal := Vector3.ZERO
var _patrol_index: int = 0
var _patrol_dir: int = 1
var _lost_time: float = 0.0
var _wait: float = 0.0
var _cooldown: float = 0.0
var _model: Node3D
var _lantern: OmniLight3D
var _mark: Label3D
var _walk_phase: float = 0.0
var _stuck_time: float = 0.0
var _sidestep: float = 0.0


func _ready() -> void:
	if config == null:
		config = load(CONFIG_PATH)
	add_to_group(&"guards")
	collision_layer = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.9
	shape.shape = capsule
	shape.position.y = 0.95
	add_child(shape)
	_model = (load(MODEL) as PackedScene).instantiate()
	for col: Node in _model.find_children("col_*", "CollisionShape3D", true, false):
		col.queue_free()
	add_child(_model)
	_lantern = OmniLight3D.new()
	_lantern.light_color = Color(1.0, 0.82, 0.5)
	_lantern.light_energy = config.lantern_energy
	_lantern.omni_range = config.lantern_range
	_lantern.shadow_enabled = true
	_lantern.light_volumetric_fog_energy = 0.35
	_lantern.position = Vector3(-0.36, 1.05, -0.62)
	_model.add_child(_lantern)
	_mark = Label3D.new()
	_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_mark.no_depth_test = true
	_mark.font_size = 96
	_mark.pixel_size = 0.006
	_mark.outline_size = 16
	_mark.position.y = 2.35
	_mark.visible = false
	add_child(_mark)
	Game.noise.connect(hear)


## Привязать к свалке: где гора, где будка, куда выводить.
func setup(center: Vector3, radius: float, booth: Vector3, exit_at: Vector3) -> void:
	heap_center = center
	heap_radius = radius
	booth_point = booth
	exit_point = exit_at
	global_position = booth
	_goal = booth


## Выйти искать (игроки пролезли мимо).
func start_search() -> void:
	if state == State.BOOTH or state == State.RETURN:
		_patrol_index = _nearest_patrol_index()
		_set_state(State.PATROL)


## Вернуться в будку (заплатили, ночь кончилась).
func go_home() -> void:
	target = null
	_set_state(State.RETURN)


## Услышать шум. В будке он глух: радио орёт.
func hear(at: Vector3, radius: float) -> void:
	if state == State.BOOTH or state == State.RETURN or state == State.CHASE:
		return
	if global_position.distance_to(at) > radius:
		return
	_goal = ground_point(at)
	_wait = config.look_around_time
	_set_state(State.INVESTIGATE)


func _set_state(next: State) -> void:
	if next == state:
		return
	state = next
	_stuck_time = 0.0
	match state:
		State.CHASE:
			_show_mark("!", Color(1.0, 0.35, 0.25))
			Audio.play_at(&"whistle", global_position + Vector3.UP * 1.7, 4.0)
		State.INVESTIGATE:
			_show_mark("?", Color(1.0, 0.8, 0.3))
		_:
			_mark.visible = false
	state_changed.emit(state)


func _show_mark(text: String, color: Color) -> void:
	_mark.text = text
	_mark.modulate = color
	_mark.visible = true


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	var speed: float = 0.0
	if Net.is_host():
		speed = _think(delta)
	_move(speed, delta)
	_animate(speed, delta)


## Решить, куда идти. Возвращает желаемую скорость.
func _think(delta: float) -> float:
	if state != State.BOOTH and state != State.RETURN and _cooldown <= 0.0:
		_look_for_players(delta)
	match state:
		State.BOOTH:
			return 0.0
		State.RETURN:
			_goal = booth_point
			if _flat_distance(booth_point) < 0.6:
				_set_state(State.BOOTH)
				return 0.0
			return config.walk_speed
		State.PATROL:
			_goal = patrol_point(_patrol_index)
			if _flat_distance(_goal) < 1.5:
				_patrol_index = posmod(_patrol_index + _patrol_dir, PATROL_POINTS)
			return config.walk_speed
		State.INVESTIGATE:
			if _flat_distance(_goal) < 1.2:
				_wait -= delta
				rotation.y += delta * 1.2      # оглядывается
				if _wait <= 0.0:
					_patrol_index = _nearest_patrol_index()
					_set_state(State.PATROL)
				return 0.0
			return config.walk_speed * 1.4
		State.CHASE:
			if not is_instance_valid(target):
				_set_state(State.PATROL)
				return 0.0
			if can_see(target):
				_lost_time = 0.0
				_goal = ground_point(target.global_position)
			else:
				_lost_time += delta
				if _lost_time > config.lose_time:
					# потерял: идёт туда, где видел в последний раз, и осматривается
					target = null
					suspicion = 0.0
					_wait = config.look_around_time
					_set_state(State.INVESTIGATE)
					return config.walk_speed
			if target.mode != PlayerController.Mode.SEATED \
					and global_position.distance_to(target.global_position) < config.catch_distance:
				catch_player(target)
				return 0.0
			return config.run_speed
	return 0.0


## Точка обхода номер i: кольцо вокруг горы. Со стороны дороги — подальше, там площадка.
func patrol_point(i: int) -> Vector3:
	var a: float = TAU * i / PATROL_POINTS
	return heap_center + Vector3(cos(a), 0.0, sin(a)) * (heap_radius + config.heap_margin + 3.0)


func _nearest_patrol_index() -> int:
	var best: int = 0
	for i: int in PATROL_POINTS:
		if _flat_distance(patrol_point(i)) < _flat_distance(patrol_point(best)):
			best = i
	return best


func _flat_distance(to: Vector3) -> float:
	return Vector2(to.x - global_position.x, to.z - global_position.z).length()


## Точка на земле, куда он может дойти: на гору не лезет, встаёт у подножия.
func ground_point(at: Vector3) -> Vector3:
	var flat := Vector3(at.x - heap_center.x, 0.0, at.z - heap_center.z)
	var edge: float = heap_radius + config.heap_margin
	if flat.length() < edge:
		flat = (flat.normalized() if flat.length() > 0.1 else Vector3.BACK) * edge
	return heap_center + flat


## Видит ли он игрока: дальность (с фонарём — далеко), угол, прямая видимость.
func can_see(player: PlayerController) -> bool:
	if player.mode == PlayerController.Mode.BURIED:
		return false
	var eye: Vector3 = global_position + Vector3.UP * 1.75
	var aim: Vector3 = player.global_position + Vector3.UP * (player.eye_height() * 0.7)
	var to: Vector3 = aim - eye
	var reach: float = config.view_range_lit if player.flashlight_on else config.view_range
	if player.crouching:
		reach *= config.crouch_mult
	if to.length() > reach:
		return false
	var ahead: Vector3 = -global_basis.z
	if to.length() > 2.5 and ahead.angle_to(to.slide(Vector3.UP)) > deg_to_rad(config.view_half_angle):
		return false
	var q := PhysicsRayQueryParameters3D.create(eye, aim)
	q.exclude = [get_rid(), player.get_rid()]
	q.collision_mask = 1
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	# вещь в руках и машина, в которой сидят, не прячут
	return hit.is_empty() or hit["collider"] == player.grab.held or hit["collider"] == player.seat_body()


func _look_for_players(delta: float) -> void:
	if state == State.CHASE:
		return
	var seen: PlayerController = null
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var player: PlayerController = node as PlayerController
		if player != null and can_see(player):
			seen = player
			break
	if seen == null:
		suspicion = maxf(suspicion - delta * 0.5, 0.0)
		return
	# вблизи узнаёт сразу, издалека приглядывается
	var near: float = 1.0 - clampf(global_position.distance_to(seen.global_position) / config.view_range_lit, 0.0, 1.0)
	suspicion += delta / config.notice_time * (0.6 + near * 2.0)
	if suspicion >= 1.0:
		target = seen
		_lost_time = 0.0
		_goal = ground_point(seen.global_position)
		_set_state(State.CHASE)
		spotted.emit(seen)


## Поймал: отбирает то, что в руках, выводит за ворота и уходит на обход.
func catch_player(player: PlayerController) -> void:
	if player.belt.active_tool() == &"bottle":
		var bottle: Item = player.belt.take_active()
		if bottle != null:
			bottle.free()
		target = null
		suspicion = 0.0
		Audio.play_at(&"cash", global_position, -4.0, 0.7)
		go_home()
		bribed.emit(player)
		return
	var taken: Item = player.grab.held as Item
	player.grab.release(false)
	if taken != null:
		taken.queue_free()
	player.global_position = exit_point
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	Audio.play_at(&"deny", exit_point)
	target = null
	suspicion = 0.0
	_cooldown = config.catch_cooldown
	_patrol_index = _nearest_patrol_index()
	_set_state(State.PATROL)
	caught.emit(player, taken)


func _move(speed: float, delta: float) -> void:
	var to: Vector3 = _goal - global_position
	to.y = 0.0
	var dir := Vector3.ZERO
	if speed > 0.0 and to.length() > 0.2:
		dir = _steer(to.normalized())
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-config.turn_speed * delta))
	velocity.x = move_toward(velocity.x, dir.x * speed, 20.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, 20.0 * delta)
	velocity.y = velocity.y - 20.0 * delta if not is_on_floor() else -0.5
	var before: Vector3 = global_position
	move_and_slide()
	# упёрся (машина, бочка, столб): шаг вбок
	if speed > 0.0 and (global_position - before).length() < speed * delta * 0.25:
		_stuck_time += delta
		if _stuck_time > 0.5:
			_stuck_time = 0.0
			_sidestep = 1.2 if _sidestep <= 0.0 else -1.2
	else:
		_stuck_time = 0.0
	_sidestep = move_toward(_sidestep, 0.0, delta) if absf(_sidestep) > 0.0 else 0.0


## Направление шага: к цели, но в обход горы по касательной и с шагом вбок, если упёрся.
func _steer(want: Vector3) -> Vector3:
	var dir: Vector3 = steer_from(global_position, want)
	if absf(_sidestep) > 0.0:
		dir = (dir + Vector3(-dir.z, 0.0, dir.x) * signf(_sidestep) * 1.5).normalized()
	return dir


## Направление шага из точки at к цели в обход горы (им же пользуется пёс).
func steer_from(at: Vector3, want: Vector3) -> Vector3:
	var from_heap := Vector3(at.x - heap_center.x, 0.0, at.z - heap_center.z)
	var edge: float = heap_radius + config.heap_margin
	var dir: Vector3 = want
	if from_heap.length() < edge + 1.5 and want.dot(from_heap.normalized()) < 0.2:
		# гора на пути: идём вдоль неё в ту сторону, где цель
		var out: Vector3 = from_heap.normalized()
		var tangent := Vector3(-out.z, 0.0, out.x)
		if tangent.dot(want) < 0.0:
			tangent = -tangent
		dir = (tangent + out * clampf(edge - from_heap.length(), -0.3, 1.0)).normalized()
	return dir


## Картинка: плащ покачивается в такт шагу, на бегу наклоняется вперёд.
func _animate(speed: float, delta: float) -> void:
	var moving: float = clampf(Vector2(velocity.x, velocity.z).length() / maxf(config.run_speed, 0.1), 0.0, 1.0)
	_walk_phase += delta * (4.0 + moving * 8.0) * (1.0 if moving > 0.02 else 0.0)
	_model.rotation.z = sin(_walk_phase) * 0.07 * (0.3 + moving)
	_model.position.y = absf(sin(_walk_phase)) * 0.05 * (0.3 + moving)
	_model.rotation.x = lerpf(_model.rotation.x, -0.22 * moving if speed > config.walk_speed * 1.5 else 0.0, 1.0 - exp(-6.0 * delta))
