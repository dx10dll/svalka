class_name PlayerController
extends CharacterBody3D
## Персонаж от первого лица: разгон и инерция, прыжок, присед, бег, ступеньки,
## залезание на уступы, падение с ног от удара о землю.
##
## Состояние (позиция, скорость, режим) отделено от ввода: контроллер получает
## PlayerInput и не знает, откуда он пришёл. Камера живёт в player_camera.gd и
## только читает контроллер. Все числа — в data/player_feel.tres.

signal jumped
signal landed(impact_speed: float)
signal mantle_started(height: float, duration: float)
signal knocked_down(impact_speed: float)
## Упавший начинает вставать (duration — сколько это займёт)
signal getup_started(duration: float)
signal got_up
signal footstep(speed: float)

enum Mode { NORMAL, MANTLE, DOWNED }

const FEEL_PATH: String = "res://data/player_feel.tres"

@export var feel: PlayerFeel

var mode: Mode = Mode.NORMAL
## Куда смотрит игрок: рыскание и тангаж, радианы
var yaw: float = 0.0
var pitch: float = 0.0
## Текущая высота капсулы (плавно меняется при приседе)
var height: float = 1.8
var crouching: bool = false
var sprinting: bool = false
## Фаза шагов в циклах (1.0 = два шага): по ней идут качание камеры, звуки и анимация ног
var stride_phase: float = 0.0
## Смещение картинки вниз после захода на ступеньку, плавно уходит в 0
var step_visual_offset: float = 0.0
## 0..1 — прогресс залезания или лежания
var mode_progress: float = 0.0

## Если задан, ввод берётся отсюда, а не с клавиатуры (автотесты, позже — сеть и боты)
var scripted_input: PlayerInput = null

## Видимое тело с анимациями и рэгдоллом
var body: PlayerBody

var _input := PlayerInput.new()
var _reader: PlayerInputReader
var _shape: CapsuleShape3D
var _collider: CollisionShape3D
var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _was_on_floor: bool = true
var _fall_speed: float = 0.0
var _spawn_point: Vector3
var _mantle_from: Vector3
var _mantle_to: Vector3
var _mantle_time: float = 0.0
var _mode_time: float = 0.0
var _last_step_index: int = 0
var _mantle_cooldown: float = 0.0
var _getting_up: bool = false


func _ready() -> void:
	if feel == null:
		feel = load(FEEL_PATH)
	height = feel.stand_height
	_shape = CapsuleShape3D.new()
	_shape.radius = feel.radius
	_collider = CollisionShape3D.new()
	_collider.shape = _shape
	add_child(_collider)
	_apply_height()
	floor_max_angle = deg_to_rad(feel.floor_max_angle_deg)
	floor_snap_length = 0.25
	_spawn_point = global_position
	yaw = rotation.y
	rotation = Vector3.ZERO  # тело не вращаем, поворот хранится в yaw
	_reader = PlayerInputReader.new()
	add_child(_reader)
	body = PlayerBody.new()
	body.name = "Body"
	add_child(body)
	body.setup(self, true)
	var cam := PlayerCamera.new()
	cam.name = "Camera"
	add_child(cam)
	cam.setup(self)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	if mode != Mode.DOWNED:
		var look: Vector2 = _reader.take_look(delta)
		yaw = wrapf(yaw - look.x, -PI, PI)
		pitch = clampf(pitch - look.y, -1.5, 1.5)
	else:
		_reader.take_look(delta)
	step_visual_offset = lerpf(step_visual_offset, 0.0, 1.0 - exp(-14.0 * delta))


func _physics_process(delta: float) -> void:
	_input = scripted_input if scripted_input != null else _reader.sample()
	match mode:
		Mode.NORMAL:
			_tick_normal(delta)
		Mode.MANTLE:
			_tick_mantle(delta)
		Mode.DOWNED:
			_tick_downed(delta)
	if global_position.y < -30.0:
		respawn()


## Высота глаз над подошвами.
func eye_height() -> float:
	return height - feel.eye_drop


## Длина цикла шагов при текущем способе передвижения, м.
func stride_length() -> float:
	if crouching:
		return feel.stride_crouch
	var t: float = inverse_lerp(feel.walk_speed, feel.sprint_speed, horizontal_speed())
	return lerpf(feel.stride_walk, feel.stride_run, clampf(t, 0.0, 1.0))


func forward() -> Vector3:
	return -Basis(Vector3.UP, yaw).z


func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


## Вернуть игрока на старт (выпал из мира или кнопка в отладке).
func respawn() -> void:
	global_position = _spawn_point
	velocity = Vector3.ZERO
	mode = Mode.NORMAL
	reset_physics_interpolation()


# --- обычное движение -----------------------------------------------------

func _tick_normal(delta: float) -> void:
	var on_floor: bool = is_on_floor()
	if _input.flop_pressed:
		# упасть нарочно: бросок вперёд и вверх, дальше работает рэгдолл
		velocity += forward() * feel.flop_push.x + Vector3.UP * feel.flop_push.y
		_enter_downed(0.0)
		return
	_update_crouch(delta)
	sprinting = _input.sprint_held and not crouching and _input.move.y > 0.5 and on_floor

	# таймеры прощения: «койот» и буфер прыжка
	_coyote = feel.coyote_time if on_floor else maxf(_coyote - delta, 0.0)
	_jump_buffer = feel.jump_buffer if _input.jump_pressed else maxf(_jump_buffer - delta, 0.0)

	_apply_horizontal(delta, on_floor)

	# вертикаль
	if not on_floor:
		var g: float = feel.gravity
		if velocity.y < 0.0:
			g *= feel.fall_gravity_factor
		elif not _input.jump_held:
			g *= feel.jump_cut_factor
		velocity.y = maxf(velocity.y - g * delta, -feel.max_fall_speed)

	if _jump_buffer > 0.0:
		if on_floor and _try_start_mantle(feel.step_height, feel.vault_height):
			return
		if _coyote > 0.0:
			velocity.y = sqrt(2.0 * feel.gravity * feel.jump_height)
			_coyote = 0.0
			_jump_buffer = 0.0
			on_floor = false
			jumped.emit()

	# в воздухе тянемся к уступу, если идём вперёд
	_mantle_cooldown = maxf(_mantle_cooldown - delta, 0.0)
	if not on_floor and _mantle_cooldown <= 0.0 and _input.move.y > 0.3 and velocity.y < 2.5:
		if _try_start_mantle(feel.mantle_min_height, feel.mantle_reach_up):
			return

	if not is_on_floor():
		_fall_speed = maxf(_fall_speed, -velocity.y)
		# падаем слишком быстро: уже в воздухе теряем контроль и летим рэгдоллом
		if -velocity.y >= feel.knockdown_speed and not Game.debug_flag(&"god_mode"):
			_enter_downed(-velocity.y)
			return

	var stepped: bool = on_floor and _try_step_up(delta)
	if not stepped:
		move_and_slide()
		_push_bodies(delta)

	# приземление
	if is_on_floor() and not _was_on_floor:
		_on_landed(_fall_speed)
	if is_on_floor():
		_fall_speed = 0.0
		stride_phase += horizontal_speed() * delta / stride_length()
		var step_index: int = int(stride_phase * 2.0)
		if step_index != _last_step_index:
			_last_step_index = step_index
			footstep.emit(horizontal_speed())
	_was_on_floor = is_on_floor()


func _apply_horizontal(delta: float, on_floor: bool) -> void:
	var move: Vector2 = _input.move.limit_length(1.0)
	var top: float = feel.walk_speed
	if crouching:
		top = feel.crouch_speed
	elif sprinting:
		top = feel.sprint_speed
	# назад и боком медленнее, чем вперёд
	var fwd_scale: float = 1.0 if move.y >= 0.0 else feel.backward_factor
	var local := Vector3(move.x * feel.strafe_factor, 0.0, -move.y * fwd_scale)
	var wish: Vector3 = Basis(Vector3.UP, yaw) * local * top

	var hv := Vector3(velocity.x, 0.0, velocity.z)
	var accel: float
	if on_floor:
		if wish.is_zero_approx():
			accel = feel.ground_decel
		else:
			accel = feel.ground_accel
			# разворот: тормозим энергичнее, чтобы не «плыть»
			if hv.length() > 0.5 and hv.normalized().dot(wish.normalized()) < 0.2:
				accel *= feel.turn_boost
	else:
		accel = feel.air_decel if wish.is_zero_approx() else feel.air_accel
		if wish.is_zero_approx():
			wish = hv  # в воздухе без ввода сохраняем инерцию
	hv = hv.move_toward(wish, accel * delta)
	velocity.x = hv.x
	velocity.z = hv.z


func _update_crouch(delta: float) -> void:
	var want: bool = _input.crouch_held
	if not want and crouching and not _can_fit(global_position, feel.stand_height):
		want = true  # над головой препятствие: остаёмся сидеть
	crouching = want
	var target: float = feel.crouch_height if crouching else feel.stand_height
	if not is_equal_approx(height, target):
		height = lerpf(height, target, 1.0 - exp(-feel.crouch_lerp_speed * delta))
		if absf(height - target) < 0.005:
			height = target
		_apply_height()


func _apply_height() -> void:
	_shape.height = height
	_collider.position.y = height * 0.5


## Заход на ступеньку: если упёрлись в невысокий край, поднимаемся на него.
func _try_step_up(delta: float) -> bool:
	# Щупаем по направлению ввода, а не по скорости: упёршись в край, скорость уже нулевая
	var wish: Vector3 = Basis(Vector3.UP, yaw) * Vector3(_input.move.x, 0.0, -_input.move.y)
	if wish.length() < 0.1:
		return false
	var speed: float = maxf(horizontal_speed(), 1.0)
	var motion: Vector3 = wish.normalized() * maxf(speed * delta, 0.04)
	var xf: Transform3D = global_transform
	if not test_move(xf, motion):
		return false
	var up: Vector3 = Vector3.UP * feel.step_height
	if test_move(xf, up):
		return false
	xf.origin += up
	# шагаем чуть дальше, чтобы встать на край уверенно
	var reach: Vector3 = motion + motion.normalized() * 0.08
	if test_move(xf, reach):
		return false
	xf.origin += reach
	var hit := KinematicCollision3D.new()
	if not test_move(xf, -up, hit):
		return false
	if hit.get_normal().angle_to(Vector3.UP) > floor_max_angle:
		return false
	var target: Vector3 = xf.origin + hit.get_travel()
	var rise: float = target.y - global_position.y
	if rise < 0.03:
		return false
	global_position = target
	step_visual_offset -= rise
	return true


func _push_bodies(delta: float) -> void:
	for i: int in get_slide_collision_count():
		var c: KinematicCollision3D = get_slide_collision(i)
		var body: RigidBody3D = c.get_collider() as RigidBody3D
		if body == null:
			continue
		var dir: Vector3 = -c.get_normal()
		dir.y = 0.0
		if dir.length() < 0.2:
			continue
		body.apply_impulse(dir.normalized() * feel.push_force * delta,
				c.get_position() - body.global_position)


func _on_landed(impact: float) -> void:
	if impact >= feel.knockdown_speed and not Game.debug_flag(&"god_mode"):
		_enter_downed(impact)
	elif impact > 1.0:
		landed.emit(impact)


# --- залезание --------------------------------------------------------------

## Ищет уступ перед игроком высотой от min_h до max_h над подошвами и начинает залезание.
func _try_start_mantle(min_h: float, max_h: float) -> bool:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var feet: Vector3 = global_position
	var fwd: Vector3 = forward()
	var exclude: Array[RID] = [get_rid()]

	# перед нами должна быть стенка: луч на уровне чуть выше минимальной высоты
	var chest: Vector3 = feet + Vector3.UP * minf(min_h + 0.1, height)
	var wall_q := PhysicsRayQueryParameters3D.create(
			chest, chest + fwd * (feel.radius + feel.mantle_reach_forward + 0.15))
	wall_q.exclude = exclude
	var has_wall: bool = not space.intersect_ray(wall_q).is_empty()
	if not has_wall:
		# низкий край может быть ниже луча: проверим у самых ног
		var low: Vector3 = feet + Vector3.UP * 0.15
		wall_q.from = low
		wall_q.to = low + fwd * (feel.radius + feel.mantle_reach_forward + 0.15)
		if space.intersect_ray(wall_q).is_empty():
			return false

	# над головой должно быть свободно до высоты уступа
	var top_y: float = feet.y + max_h + 0.05
	var head: Vector3 = feet + Vector3.UP * (height - 0.1)
	if top_y > head.y:
		var up_q := PhysicsRayQueryParameters3D.create(head, Vector3(feet.x, top_y, feet.z))
		up_q.exclude = exclude
		if not space.intersect_ray(up_q).is_empty():
			return false

	# лучи сверху вниз ищут верх уступа: сначала у самого края, потом глубже
	var found: bool = false
	var target := Vector3.ZERO
	for depth: float in [0.2, 0.38, feel.mantle_reach_forward]:
		var top: Vector3 = feet + fwd * (feel.radius + depth)
		top.y = top_y
		var down_q := PhysicsRayQueryParameters3D.create(top, top + Vector3.DOWN * (max_h + 0.05 - min_h))
		down_q.exclude = exclude
		var hit: Dictionary = space.intersect_ray(down_q)
		if hit.is_empty() or (hit["normal"] as Vector3).y < 0.7:
			continue
		var candidate: Vector3 = (hit["position"] as Vector3) + Vector3.UP * 0.03
		# наверху должно хватать места хотя бы сидя
		if _can_fit(candidate, feel.crouch_height):
			target = candidate
			found = true
			break
	if not found:
		return false

	_mantle_from = feet
	_mantle_to = target
	var rise: float = maxf(target.y - feet.y, 0.0)
	_mantle_time = feel.mantle_base_time + feel.mantle_time_per_meter * rise
	_mode_time = 0.0
	mode_progress = 0.0
	mode = Mode.MANTLE
	velocity = Vector3.ZERO
	_jump_buffer = 0.0
	_fall_speed = 0.0
	if not _can_fit(target, feel.stand_height):
		crouching = true
	mantle_started.emit(rise, _mantle_time)
	return true


func _tick_mantle(delta: float) -> void:
	_mode_time += delta
	var t: float = clampf(_mode_time / _mantle_time, 0.0, 1.0)
	mode_progress = t
	# сначала подтягиваемся вверх, потом переваливаемся вперёд
	var up_t: float = ease(clampf(t / 0.7, 0.0, 1.0), 0.45)
	var fwd_t: float = smoothstep(0.35, 1.0, t)
	var pos: Vector3 = _mantle_from.lerp(_mantle_to, fwd_t)
	pos.y = lerpf(_mantle_from.y, _mantle_to.y, up_t)
	global_position = pos
	_update_height_only(delta)
	if t >= 1.0:
		mode = Mode.NORMAL
		velocity = forward() * feel.mantle_exit_speed
		_mantle_cooldown = 0.3  # чтобы не цепляться за следующий ящик без команды игрока
		_was_on_floor = true
		_coyote = feel.coyote_time


func _update_height_only(delta: float) -> void:
	var target: float = feel.crouch_height if crouching else feel.stand_height
	height = lerpf(height, target, 1.0 - exp(-feel.crouch_lerp_speed * delta))
	_apply_height()


# --- падение с ног -----------------------------------------------------------

func _enter_downed(impact: float) -> void:
	mode = Mode.DOWNED
	_mode_time = 0.0
	mode_progress = 0.0
	sprinting = false
	_getting_up = false
	_collider.disabled = true  # пока лежим, за тело отвечает рэгдолл
	knocked_down.emit(impact)


func _tick_downed(delta: float) -> void:
	_mode_time += delta
	var total: float = feel.knockdown_time + feel.getup_time
	mode_progress = clampf(_mode_time / total, 0.0, 1.0)
	if not _getting_up:
		# капсула едет за тазом рэгдолла, чтобы встать там, где упали
		velocity = Vector3.ZERO
		if body != null and body.ragdoll.active:
			global_position = _floor_under(body.ragdoll.hips_position())
			# не встаём, пока тело ещё катится
			if _mode_time >= feel.knockdown_time and body.ragdoll.total_speed() > 1.2 \
					and _mode_time < feel.knockdown_time + 8.0:
				_mode_time = feel.knockdown_time - delta
		if _mode_time >= feel.knockdown_time:
			_getting_up = true
			_collider.disabled = false
			crouching = not _can_fit(global_position, feel.stand_height)
			reset_physics_interpolation()
			getup_started.emit(feel.getup_time)
		return
	if not is_on_floor():
		velocity.y -= feel.gravity * feel.fall_gravity_factor * delta
	move_and_slide()
	if _mode_time >= total:
		mode = Mode.NORMAL
		_was_on_floor = is_on_floor()
		_fall_speed = 0.0
		got_up.emit()


## Точка на полу под заданной позицией (куда поставить капсулу).
func _floor_under(pos: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.3, pos + Vector3.DOWN * 3.0)
	q.exclude = [get_rid()]
	q.collision_mask = 1
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return pos
	return (hit["position"] as Vector3) + Vector3.UP * 0.02


## Доля «лежания» 0..1 для камеры: 1 — лежим, 0 — стоим.
func downed_amount() -> float:
	if mode != Mode.DOWNED:
		return 0.0
	if _mode_time < feel.knockdown_time:
		return clampf(_mode_time / 0.18, 0.0, 1.0)
	return 1.0 - smoothstep(0.0, 1.0, (_mode_time - feel.knockdown_time) / feel.getup_time)


# --- служебное ----------------------------------------------------------------

## Помещается ли капсула высотой h, стоя подошвами в точке feet.
func _can_fit(feet: Vector3, h: float) -> bool:
	var probe := CapsuleShape3D.new()
	probe.radius = feel.radius - 0.02
	probe.height = maxf(h - 0.06, probe.radius * 2.0)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = probe
	q.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * (h * 0.5 + 0.03))
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()
