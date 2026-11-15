class_name PlayerGrab
extends Node
## Физический захват: предмет висит на пружине перед игроком, а не «приклеен».
##
## Сила рук ограничена (lift_force, pull_force в PlayerFeel), поэтому вес решает
## сам: лёгкое несём, тяжёлое один игрок только волочит, приподняв край.
## Когда тянут двое, силы складываются — отдельного правила «несут вдвоём» нет.
## Вес замедляет шаг, предмет держит игрока на «поводке». Бросок с зарядкой.

signal grabbed(body: RigidBody3D)
signal released(body: RigidBody3D, thrown: bool)

## Лучи прицела: центр и небольшой разброс (тангенсы углов, около 6°)
const AIM_SPREAD: Array[Vector2] = [
	Vector2(0, 0), Vector2(0, -0.1), Vector2(0, 0.1), Vector2(-0.1, 0), Vector2(0.1, 0),
]

## Что сейчас в руках
var held: RigidBody3D
## На что смотрим (можно взять)
var focus: RigidBody3D
## Заряд броска 0..1
var throw_charge: float = 0.0
## Насколько предмет отстал от точки удержания, м (для рук и «поводка»)
var stretch: float = 0.0

var _player: PlayerController
var _feel: PlayerFeel
var _local_point := Vector3.ZERO     # точка хвата в осях предмета
var _hold_basis := Basis.IDENTITY    # поворот предмета относительно взгляда в момент захвата
var _was_grab_held: bool = false
var _was_throw_held: bool = false
var _overstretch_time: float = 0.0
var _saved_can_sleep: bool = true


func setup(player: PlayerController) -> void:
	_player = player
	_feel = player.feel


## Точка глаз без качания камеры (от неё идёт луч и считается удержание).
func eye() -> Vector3:
	return _player.global_position + Vector3.UP * _player.eye_height()


func look_dir() -> Vector3:
	return (Basis(Vector3.UP, _player.yaw) * Basis(Vector3.RIGHT, _player.pitch)) * Vector3.FORWARD


## Точка в мире, куда руки тянут предмет.
func hold_target() -> Vector3:
	var dir: Vector3 = look_dir()
	return eye() + dir * _feel.hold_distance + Vector3.DOWN * _feel.hold_drop


## Где сейчас на предмете точка хвата (мир).
func grab_point() -> Vector3:
	return held.global_transform * _local_point if held != null else Vector3.ZERO


## Масса удерживаемого, кг (0 — руки пусты).
func held_mass() -> float:
	return held.mass if held != null else 0.0


## Может ли один игрок оторвать предмет от земли.
func can_lift(mass: float) -> bool:
	return mass * 9.8 <= _feel.lift_force


func tick(input: PlayerInput, delta: float) -> void:
	if held != null and not is_instance_valid(held):
		held = null
	if _player.mode != PlayerController.Mode.NORMAL:
		release(false)
		focus = null
		_was_grab_held = input.grab_held
		return
	_update_focus()
	if held == null:
		throw_charge = 0.0
		if input.grab_held and not _was_grab_held and focus != null:
			_grab(focus)
	else:
		if not input.grab_held:
			release(false)
		else:
			_hold(delta)
			_update_throw(input, delta)
	_was_grab_held = input.grab_held
	_was_throw_held = input.throw_held


func _update_focus() -> void:
	focus = null
	if held != null:
		return
	# Прицел «с допуском»: сначала точно по центру, потом четыре луча рядом —
	# иначе мелкую вещь на земле приходится выцеливать.
	var basis: Basis = Basis(Vector3.UP, _player.yaw) * Basis(Vector3.RIGHT, _player.pitch)
	var from: Vector3 = eye()
	var space: PhysicsDirectSpaceState3D = _player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from)
	q.exclude = [_player.get_rid()]
	for spread: Vector2 in AIM_SPREAD:
		var dir: Vector3 = basis * Vector3(spread.x, spread.y, -1.0).normalized()
		q.to = from + dir * _feel.grab_reach
		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty():
			continue
		var body: RigidBody3D = hit["collider"] as RigidBody3D
		if body != null and not body.freeze:
			focus = body
			focus.set_meta(&"aim_point", hit["position"])
			return


func _grab(body: RigidBody3D) -> void:
	held = body
	var point: Vector3 = body.get_meta(&"aim_point", body.global_position)
	_local_point = body.global_transform.affine_inverse() * point
	_hold_basis = Basis(Vector3.UP, _player.yaw).inverse() * body.global_basis
	_saved_can_sleep = body.can_sleep
	body.can_sleep = false
	body.sleeping = false
	# предмет в руках не толкает самого игрока: иначе на нём можно «улететь»
	body.add_collision_exception_with(_player)
	_overstretch_time = 0.0
	throw_charge = 0.0
	focus = null
	grabbed.emit(body)


func release(thrown: bool) -> void:
	if held == null:
		return
	var body: RigidBody3D = held
	held = null
	stretch = 0.0
	throw_charge = 0.0
	if is_instance_valid(body):
		body.can_sleep = _saved_can_sleep
		# столкновение с игроком возвращаем чуть позже, чтобы предмет не выстрелил из-под ног
		var body_id: int = body.get_instance_id()
		var timer: SceneTreeTimer = get_tree().create_timer(0.35, false, true)
		timer.timeout.connect(func() -> void:
			var later: RigidBody3D = instance_from_id(body_id) as RigidBody3D
			if later != null and later != held:
				later.remove_collision_exception_with(_player))
		released.emit(body, thrown)


func _hold(delta: float) -> void:
	var mass: float = held.mass
	var point: Vector3 = grab_point()
	var target: Vector3 = hold_target()
	var offset: Vector3 = target - point
	stretch = offset.length()

	# пружина с критическим демпфированием, жёсткость растёт с массой:
	# лёгкое и тяжёлое догоняют руки одинаково быстро, пока хватает силы
	var arm: Vector3 = point - held.global_position
	var v_point: Vector3 = held.linear_velocity + held.angular_velocity.cross(arm) - _player.velocity
	var w: float = _feel.grab_frequency
	var force: Vector3 = offset * (mass * w * w) - v_point * (2.0 * mass * w)
	force.y += mass * 9.8  # держим вес
	# силы рук не бесконечны: отдельно подъём и отдельно тяга
	force.y = clampf(force.y, -_feel.lift_force, _feel.lift_force)
	var horizontal := Vector3(force.x, 0.0, force.z).limit_length(_feel.pull_force)
	force.x = horizontal.x
	force.z = horizontal.z
	held.apply_force(force, arm)

	# удерживаем поворот, каким взяли: тяжёлое почти не слушается и болтается
	var want: Basis = Basis(Vector3.UP, _player.yaw) * _hold_basis
	var diff: Quaternion = (want * held.global_basis.inverse()).get_rotation_quaternion()
	if diff.w < 0.0:
		diff = -diff
	var angle: float = 2.0 * acos(clampf(diff.w, -1.0, 1.0))
	var axis := Vector3(diff.x, diff.y, diff.z)
	if axis.length() > 0.0001 and angle > 0.001:
		axis = axis.normalized()
		var inertia: float = maxf(mass * 0.12, 0.05)
		var torque: Vector3 = axis * angle * inertia * w * w - held.angular_velocity * (2.0 * inertia * w)
		held.apply_torque(torque.limit_length(_feel.hold_torque))

	# предмет застрял или слишком тяжёл и далеко: руки срываются
	if stretch > _feel.grab_break_distance:
		_overstretch_time += delta
		if _overstretch_time > 0.25:
			release(false)
	else:
		_overstretch_time = 0.0


func _update_throw(input: PlayerInput, delta: float) -> void:
	if held == null:
		return
	if input.throw_held:
		throw_charge = minf(throw_charge + delta / _feel.throw_charge_time, 1.0)
	elif _was_throw_held and throw_charge > 0.08:
		var body: RigidBody3D = held
		var dir: Vector3 = (look_dir() + Vector3.UP * _feel.throw_up_bias).normalized()
		var speed: float = minf(_feel.throw_impulse * throw_charge / body.mass, _feel.throw_max_speed)
		release(true)
		body.apply_central_impulse(dir * speed * body.mass)
		body.apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
				* body.mass * 0.05 * speed)
	else:
		throw_charge = 0.0


## Насколько вес в руках замедляет шаг (1 — не мешает).
func speed_scale() -> float:
	if held == null:
		return 1.0
	if not can_lift(held.mass):
		return _feel.drag_speed_factor
	var load: float = clampf(held.mass * 9.8 / _feel.lift_force, 0.0, 1.0)
	return lerpf(1.0, _feel.carry_speed_factor, load * load)


## «Поводок»: не даём уйти от отставшего предмета, пока тянем его.
func filter_move(wish: Vector3) -> Vector3:
	if held == null or stretch < _feel.tether_slack:
		return wish
	var away: Vector3 = _player.global_position - grab_point()
	away.y = 0.0
	if away.length() < 0.01:
		return wish
	away = away.normalized()
	var outward: float = wish.dot(away)
	if outward <= 0.0:
		return wish  # идём к предмету — не мешаем
	var pull: float = clampf((stretch - _feel.tether_slack) / (_feel.grab_break_distance - _feel.tether_slack), 0.0, 1.0)
	return wish - away * outward * pull
