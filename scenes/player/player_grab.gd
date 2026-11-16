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
signal shoveled(piece: RigidBody3D)

## Лучи прицела: центр и небольшой разброс (тангенсы углов, около 6°)
const AIM_SPREAD: Array[Vector2] = [
	Vector2(0, 0), Vector2(0, -0.1), Vector2(0, 0.1), Vector2(-0.1, 0), Vector2(0.1, 0),
]

## Что сейчас в руках
var held: RigidBody3D
## На что смотрим (можно взять)
var focus: RigidBody3D
## Куча и её ячейка под прицелом (можно вытащить кусок), если focus пуст
var focus_dump: Dump
var focus_cell: Vector3i = Dump.NO_CELL
## Машина под прицелом (её ещё можно толкать)
var focus_van: Van
## То, с чем можно что-то сделать клавишей E (машина, весы, доска): у узла есть
## interaction_at(точка) -> {"hint", "action"} и interact(игрок, действие)
var focus_use: Node
var focus_action: Dictionary = {}
## Упёрлись руками в машину и толкаем
var pushing: bool = false
## Заряд броска 0..1
var throw_charge: float = 0.0
## Насколько предмет отстал от точки удержания, м (для рук и «поводка»)
var stretch: float = 0.0
## Обожгли руки кислотой: столько секунд ничего не взять
var burn_wait: float = 0.0

var _player: PlayerController
var _feel: PlayerFeel
var _local_point := Vector3.ZERO     # точка хвата в осях предмета
var _hold_basis := Basis.IDENTITY    # поворот предмета относительно взгляда в момент захвата
var _was_grab_held: bool = false
var _was_throw_held: bool = false
var _overstretch_time: float = 0.0
var _saved_can_sleep: bool = true
var _outlined: Item
var _dump_point := Vector3.ZERO
var _shovel_wait: float = 0.0
var _shovel_side: float = 1.0
var _van_point := Vector3.ZERO


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


## Сила рук вверх с учётом лома на поясе, Н.
func lift_force() -> float:
	return _feel.lift_force * _tool_mult()


func _tool_mult() -> float:
	return _feel.crowbar_lift_mult if _player.belt != null and _player.belt.has_tool(&"crowbar") else 1.0


## Может ли один игрок оторвать предмет от земли.
func can_lift(mass: float) -> bool:
	return mass * 9.8 <= lift_force()


func tick(input: PlayerInput, delta: float) -> void:
	if held != null and not is_instance_valid(held):
		held = null
	if _player.mode != PlayerController.Mode.NORMAL:
		release(false)
		focus = null
		focus_van = null
		focus_use = null
		pushing = false
		_update_highlight()
		_was_grab_held = input.grab_held
		return
	_update_focus()
	_update_highlight()
	if input.interact_pressed and focus_use != null and not focus_action.is_empty():
		focus_use.call(&"interact", _player, focus_action["action"])
		return
	pushing = held == null and focus_van != null and input.grab_held
	if pushing:
		# толкаем туда, куда смотрим, но без «вниз»: в землю машину не вдавить
		var dir: Vector3 = look_dir()
		dir.y = maxf(dir.y, 0.0)
		focus_van.push(_van_point, dir)
	_shovel_wait = maxf(_shovel_wait - delta, 0.0)
	burn_wait = maxf(burn_wait - delta, 0.0)
	if held == null:
		throw_charge = 0.0
		if input.throw_held and _shovel_wait <= 0.0:
			if focus_dump != null:
				_shovel(focus_dump.dig(focus_cell))
			elif focus is Item and (focus as Item).data.is_trash() and not focus.freeze:
				_shovel(focus as Item)   # лежащий мусор тоже отбрасываем
		if input.grab_held and not _was_grab_held and burn_wait <= 0.0:
			if focus != null:
				if focus.has_meta(&"dump_site"):
					(focus.get_parent() as Dump).release_site(focus as Item)
				elif focus.has_meta(&"burying"):
					focus.remove_meta(&"burying")   # сняли кусок с засыпанного товарища
					focus.freeze = false
				_grab(focus)
			elif focus_dump != null:
				var piece: Item = focus_dump.dig(focus_cell)
				if piece != null:
					piece.set_meta(&"aim_point", _dump_point)
					_grab(piece)
	else:
		if not input.grab_held:
			release(false)
		else:
			_hold(delta)
			_update_throw(input, delta)
	_was_grab_held = input.grab_held
	_was_throw_held = input.throw_held


## Обводка на предмете под прицелом.
func _update_highlight() -> void:
	var want: Item = focus as Item
	if want == _outlined:
		return
	if is_instance_valid(_outlined):
		_outlined.set_highlight(false)
	_outlined = want
	if _outlined != null:
		_outlined.set_highlight(true)


## Взмах лопатой: кусок кучи вылетает вбок и за спину. Стороны чередуются.
func _shovel(piece: Item) -> void:
	if piece == null:
		return
	var has_shovel: bool = _player.belt == null or _player.belt.has_tool(&"shovel")
	_shovel_wait = _feel.shovel_cooldown if has_shovel else _feel.hands_dig_cooldown   # без лопаты гребём руками
	_shovel_side = -_shovel_side
	var flat: Vector3 = Basis(Vector3.UP, _player.yaw) * Vector3.FORWARD
	var right: Vector3 = Basis(Vector3.UP, _player.yaw) * Vector3.RIGHT
	var dir: Vector3 = (right * _shovel_side * 0.9 - flat * 0.45 + Vector3.UP * 0.9).normalized()
	# тяжёлое с лопаты летит хуже
	var speed: float = _feel.shovel_throw_speed * minf(1.0, sqrt(14.0 / piece.mass))
	piece.add_collision_exception_with(_player)
	var piece_id: int = piece.get_instance_id()
	get_tree().create_timer(0.5, false, true).timeout.connect(func() -> void:
		var later: RigidBody3D = instance_from_id(piece_id) as RigidBody3D
		if later != null and later != held:
			later.remove_collision_exception_with(_player))
	piece.linear_velocity = dir * speed
	piece.angular_velocity = Vector3(randf_range(-4, 4), randf_range(-2, 2), randf_range(-4, 4))
	Audio.play_at(&"whoosh", eye(), -9.0, 0.8)
	Audio.play_impact(&"soft", _dump_point, 4.0)
	get_tree().call_group(&"player_cameras", &"shake_from", eye(), 0.22)
	shoveled.emit(piece)


func _update_focus() -> void:
	focus = null
	focus_dump = null
	focus_cell = Dump.NO_CELL
	focus_van = null
	focus_use = null
	focus_action = {}
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
		if hit["collider"] is Van:
			if focus_van == null and focus_dump == null:
				focus_van = hit["collider"]
				focus_use = focus_van
				_van_point = hit["position"]
				focus_action = focus_van.interaction_at(hit["position"])
			continue
		if (hit["collider"] as Object).has_method(&"interaction_at"):
			if focus_use == null and focus_dump == null:
				focus_use = hit["collider"]
				focus_action = focus_use.call(&"interaction_at", hit["position"])
			continue
		var body: RigidBody3D = hit["collider"] as RigidBody3D
		if body != null and body.has_meta(&"strapped_to"):
			# притянутый ремнями груз — часть машины: руками не взять
			if focus_van == null and focus_dump == null:
				focus_van = body.get_meta(&"strapped_to")
				focus_use = focus_van
				_van_point = hit["position"]
				focus_action = {"hint": "HINT_VAN_STRAPS_OFF", "action": &"straps"}
			continue
		if body != null and (not body.freeze or body.has_meta(&"dump_site") or body.has_meta(&"burying")):
			focus = body
			focus.set_meta(&"aim_point", hit["position"])
			if body is Item and focus_use == null:
				# в ванну можно сесть: E, а ЛКМ по-прежнему берёт
				focus_action = (body as Item).ride_action()
				focus_use = body if not focus_action.is_empty() else null
			focus_dump = null
			return
		# куча: запоминаем первый попавший луч, но вещь рядом важнее мусора
		if focus_dump == null and hit["collider"] is StaticBody3D and (hit["collider"] as Node).get_parent() is Dump:
			var dump: Dump = (hit["collider"] as Node).get_parent()
			var cell: Vector3i = dump.cell_from_hit(hit["collider"], hit["shape"])
			if cell != Dump.NO_CELL:
				focus_dump = dump
				focus_cell = cell
				_dump_point = hit["position"]


func _grab(body: RigidBody3D) -> void:
	held = body
	var point: Vector3 = body.get_meta(&"aim_point", body.global_position)
	_local_point = body.global_transform.affine_inverse() * point
	_hold_basis = Basis(Vector3.UP, _player.yaw).inverse() * body.global_basis
	var item: Item = body as Item
	if item != null and item.data != null and item.data.leak_tilt_deg > 0.0:
		# то, что течёт, руки сами ставят ровно; дальше — не раскачивай
		var flat: Vector3 = body.global_basis.x.slide(Vector3.UP)
		var item_yaw: float = atan2(-flat.z, flat.x) if flat.length() > 0.1 else _player.yaw
		_hold_basis = Basis(Vector3.UP, item_yaw - _player.yaw)
		item.leak_grace(1.2)
	_saved_can_sleep = body.can_sleep
	body.can_sleep = false
	body.sleeping = false
	# предмет в руках не толкает самого игрока: иначе на нём можно «улететь»
	body.add_collision_exception_with(_player)
	_overstretch_time = 0.0
	throw_charge = 0.0
	focus = null
	Audio.play_at(&"grab", point, -8.0)
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
	var item: Item = held as Item
	if item != null and item.leaking:
		# кислота из аккумулятора жжёт руки: бросаем и какое-то время не можем взять
		WorldPopup.spawn(get_tree().current_scene, item.global_position + Vector3.UP * 0.4, tr("POPUP_ACID"), Color(0.75, 1.0, 0.3))
		Audio.play_at(&"deny", item.global_position, -4.0)
		burn_wait = _feel.acid_burn_time
		release(false)
		return
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
	force.y = clampf(force.y, -lift_force(), lift_force())
	var horizontal := Vector3(force.x, 0.0, force.z).limit_length(_feel.pull_force * _tool_mult())
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
		var throw_charge_was: float = throw_charge
		var dir: Vector3 = (look_dir() + Vector3.UP * _feel.throw_up_bias).normalized()
		var speed: float = minf(_feel.throw_impulse * throw_charge / body.mass, _feel.throw_max_speed)
		release(true)
		Audio.play_at(&"whoosh", eye(), lerpf(-12.0, -3.0, throw_charge_was), lerpf(0.85, 1.2, throw_charge_was))
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
	var load: float = clampf(held.mass * 9.8 / lift_force(), 0.0, 1.0)
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
