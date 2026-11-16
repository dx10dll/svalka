class_name Van
extends VehicleBody3D
## Фургон артели: физическая машина с настоящим грузом в кузове.
##
## Груз — обычные твёрдые тела на полу кузова, их вес сам давит на рессоры.
## Сверх грузоподъёмности тяга и скорость падают (overload_penalty в VanFeel):
## перегруженная машина не вытянет подъём, и её придётся толкать.
## Управление приходит числами (throttle, steer, brake) — от игрока за рулём,
## от теста или позже по сети. Перёд машины — ось +Z (так устроен VehicleBody3D).

signal engine_toggled(on: bool)
signal doors_toggled(open: bool)
signal stalled_out
signal straps_toggled(on: bool)

const MODEL: String = "res://assets/models/vehicles/van.glb"
const FEEL_PATH: String = "res://data/van_feel.tres"
const ENGINE_LOOP: String = "res://assets/audio/loops/engine_loop.wav"

@export var feel: VanFeel

## Газ -1..1 (минус — назад), руль -1..1 (плюс — влево), тормоз 0..1
var throttle: float = 0.0
var steer: float = 0.0
## По умолчанию стоит на ручнике
var brake_input: float = 1.0
## Кто за рулём
var driver: PlayerController
var passenger: PlayerController
## Мотор заглох: надо отпустить газ и нажать снова, стартер крутит crank_time
var stalled: bool = false
## Груз притянут ремнями к кузову
var strapped: bool = false
## Поставленные улучшения
var upgrades: Array[StringName] = []
var engine_on: bool = false
var headlights_on: bool = false
var doors_open: bool = false

var _model: Node3D
var _wheels: Array[VehicleWheel3D] = []
var _seats: Dictionary[StringName, Marker3D] = {}
var _exit_driver: Marker3D
var _cargo_area: Area3D
var _doors: Array[Node3D] = []
var _door_shapes: Array[CollisionShape3D] = []
var _door_angle: float = 0.0
var _lights: Array[SpotLight3D] = []
var _sound: AudioStreamPlayer3D
var _rpm: float = 0.0
var _stall_clock: float = 0.0
var _crank: float = 0.0
var _gas_released: bool = true
var _pushed: float = 0.0
var _strap_joints: Array[Joint3D] = []
var _strap_visual: Node3D


func _ready() -> void:
	if feel == null:
		feel = load(FEEL_PATH)
	mass = feel.mass
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = feel.center_of_mass
	can_sleep = false
	_model = (load(MODEL) as PackedScene).instantiate()
	_model.name = "Model"
	add_child(_model)
	for shape: Node in _model.find_children("col_*", "CollisionShape3D", true, false):
		var xf: Transform3D = (shape as CollisionShape3D).transform
		shape.owner = null
		shape.get_parent().remove_child(shape)
		add_child(shape)
		(shape as CollisionShape3D).transform = xf
	var mat := PhysicsMaterial.new()
	mat.friction = 0.8
	physics_material_override = mat
	_build_glass()
	_build_wheels()
	_build_doors()
	_build_cargo_area()
	_build_lights()
	_build_sound()
	_build_straps()
	for name: StringName in [&"seat_driver", &"seat_passenger"]:
		_seats[name] = _model.find_child("grip_" + name, true, false)
	_exit_driver = _model.find_child("grip_exit_driver", true, false)
	add_to_group(&"vans")


func _build_glass() -> void:
	var glass: MeshInstance3D = _model.find_child("glass", true, false)
	if glass == null:
		return
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.55, 0.7, 0.75, 0.16)
	mat.roughness = 0.08
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.material_override = mat
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_wheels() -> void:
	var source: MeshInstance3D = _model.find_child("wheel", true, false)
	for id: String in ["fl", "fr", "rl", "rr"]:
		var hub: Marker3D = _model.find_child("grip_wheel_" + id, true, false)
		var wheel := VehicleWheel3D.new()
		wheel.name = "Wheel_" + id
		# пустая машина сама проседает на рессорах: поднимаем крепление, чтобы колёса стояли в арках
		wheel.position = hub.position + Vector3.UP * (feel.suspension_rest - feel.static_sag)
		wheel.wheel_radius = feel.wheel_radius
		wheel.wheel_rest_length = feel.suspension_rest
		wheel.suspension_travel = feel.suspension_travel
		wheel.suspension_stiffness = feel.suspension_stiffness
		wheel.suspension_max_force = 30000.0
		wheel.damping_compression = feel.damping_compression
		wheel.damping_relaxation = feel.damping_relaxation
		wheel.wheel_friction_slip = feel.wheel_friction
		wheel.wheel_roll_influence = feel.roll_influence
		wheel.use_as_steering = id.begins_with("f")
		wheel.use_as_traction = true     # полный привод: по свалке иначе не проехать
		add_child(wheel)
		var visual := MeshInstance3D.new()
		visual.mesh = source.mesh
		if id.ends_with("r"):
			visual.rotation.y = PI       # правые колёса колпаком наружу
		wheel.add_child(visual)
		_wheels.append(wheel)
	source.visible = false


## Задние двери: створки на петлях. Коллизии створок — формы самого кузова,
## их положение двигается вместе со створкой.
func _build_doors() -> void:
	for id: String in ["door_l", "door_r"]:
		var door: Node3D = _model.find_child(id, true, false)
		_doors.append(door)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.93, 1.44, 0.06)
		shape.shape = box
		add_child(shape)
		_door_shapes.append(shape)
	_apply_doors()


func _apply_doors() -> void:
	for i: int in _doors.size():
		var door: Node3D = _doors[i]
		var side: float = 1.0 if i == 0 else -1.0   # левая створка на +X
		door.rotation.y = -side * _door_angle
		# центр коробки: от петли к середине проёма, на половину высоты створки
		_door_shapes[i].transform = Transform3D(door.transform.basis, door.transform * Vector3(-side * 0.47, 0.72, 0.0))


func _build_cargo_area() -> void:
	var center: Marker3D = _model.find_child("grip_cargo", true, false)
	_cargo_area = Area3D.new()
	_cargo_area.name = "Cargo"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.74, 1.45, 2.95)
	shape.shape = box
	_cargo_area.add_child(shape)
	_cargo_area.position = center.position
	_cargo_area.collision_mask = 0xFFFF
	add_child(_cargo_area)


func _build_lights() -> void:
	for id: String in ["headlight_l", "headlight_r"]:
		var at: Marker3D = _model.find_child("grip_" + id, true, false)
		var light := SpotLight3D.new()
		light.light_color = Color(1.0, 0.92, 0.72)
		light.light_energy = feel.headlight_energy
		light.spot_range = feel.headlight_range
		light.spot_angle = feel.headlight_angle_deg
		light.spot_attenuation = 0.9
		light.shadow_enabled = id == "headlight_l"   # одна тень на пару: дешевле
		light.light_volumetric_fog_energy = 0.5
		light.position = at.position + Vector3(0, 0, 0.3)   # вынесены вперёд: не светят в собственный капот
		light.rotation = Vector3(deg_to_rad(-4.0), PI, 0.0)   # свет летит вдоль -Z узла, перёд машины +Z
		light.visible = false
		add_child(light)
		_lights.append(light)


func _build_sound() -> void:
	var stream: AudioStreamWAV = load(ENGINE_LOOP)
	if stream == null:
		return
	stream = stream.duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	_sound = AudioStreamPlayer3D.new()
	_sound.stream = stream
	_sound.unit_size = 6.0
	_sound.max_distance = 70.0
	_sound.position = Vector3(0.0, 0.9, 1.3)
	add_child(_sound)


## Ремни: две оранжевые ленты крест-накрест в проёме кузова, видны, когда затянуты.
func _build_straps() -> void:
	_strap_visual = Node3D.new()
	_strap_visual.position = Vector3(0.0, 1.32, -2.02)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.42, 0.08)
	mat.roughness = 0.9
	for tilt: float in [-0.66, 0.66]:
		var band := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(2.2, 0.07, 0.015)
		band.mesh = box
		band.material_override = mat
		band.rotation.z = tilt
		_strap_visual.add_child(band)
	_strap_visual.visible = false
	add_child(_strap_visual)


# --- состояние -------------------------------------------------------------------

## Скорость вдоль машины, м/с (плюс — вперёд).
func forward_speed() -> float:
	return linear_velocity.dot(global_basis.z)


## Сколько килограммов лежит в кузове (предметы и люди).
func cargo_mass() -> float:
	var total: float = 0.0
	for body: Node3D in _cargo_area.get_overlapping_bodies():
		if body == self:
			continue
		if body is RigidBody3D:
			total += (body as RigidBody3D).mass
		elif body is PlayerController:
			total += 70.0
	return total


## Предметы в кузове.
func cargo_bodies() -> Array[RigidBody3D]:
	var out: Array[RigidBody3D] = []
	for body: Node3D in _cargo_area.get_overlapping_bodies():
		if body != self and body is RigidBody3D:
			out.append(body)
	return out


## Затянуть или отпустить ремни. Затянутый груз жёстко держится за кузов
## и не сползает даже с открытыми дверями; взять его руками нельзя, пока не отпустишь.
func set_straps(on: bool) -> void:
	if strapped == on:
		return
	strapped = on
	for joint: Joint3D in _strap_joints:
		if is_instance_valid(joint):
			joint.queue_free()
	_strap_joints.clear()
	for body: RigidBody3D in get_tree().get_nodes_in_group(&"strapped_cargo"):
		if body.get_meta(&"strapped_to", null) == self:
			body.remove_meta(&"strapped_to")
			body.remove_from_group(&"strapped_cargo")
	if on:
		for body: RigidBody3D in cargo_bodies():
			var joint := Generic6DOFJoint3D.new()   # все оси заперты по умолчанию
			add_child(joint)
			joint.global_position = body.global_position
			joint.node_a = joint.get_path_to(self)
			joint.node_b = joint.get_path_to(body)
			_strap_joints.append(joint)
			body.set_meta(&"strapped_to", self)
			body.add_to_group(&"strapped_cargo")
	_strap_visual.visible = on
	Audio.play_at(&"grab", _strap_visual.global_position, -4.0, 0.7 if on else 1.1)
	straps_toggled.emit(on)


## Толчок руками в точке кузова. Зовётся каждый тик, пока игрок толкает.
func push(world_point: Vector3, direction: Vector3) -> void:
	var on_wheels: bool = global_basis.y.y > 0.6
	var force: float = feel.push_force if on_wheels else feel.flip_force
	apply_force(direction.normalized() * force, world_point - global_position)
	_pushed = 0.15


## Доля тяги с учётом перегруза: 1 — норма, меньше — мотор не тянет.
func power_factor() -> float:
	var over: float = maxf(cargo_mass() - feel.capacity, 0.0)
	return maxf(1.0 - over / 100.0 * feel.overload_penalty, feel.overload_min_power)


## Высота заднего бампера над землёй, м (по ней видно перегруз).
func rear_height() -> float:
	return to_global(Vector3(0.0, 0.45, -2.15)).y


func set_engine(on: bool) -> void:
	if on:
		stalled = false
	if engine_on == on:
		return
	engine_on = on
	_stall_clock = 0.0
	set_headlights(on)
	if _sound != null:
		if on:
			_sound.play()
		else:
			_sound.stop()
	engine_toggled.emit(on)


func set_headlights(on: bool) -> void:
	headlights_on = on
	for light: SpotLight3D in _lights:
		light.visible = on


## Поставить улучшения из лавки (id товаров). Числа — в VanFeel.
func apply_upgrades(ids: Array[StringName]) -> void:
	feel = feel.duplicate()
	if ids.has(&"springs"):
		feel.capacity += feel.springs_capacity_bonus
		feel.suspension_stiffness *= feel.springs_stiffness_mult
		# жёсткие рессоры меньше проседают: машина заметно приподнимается (около 10 см)
		for wheel: VehicleWheel3D in _wheels:
			wheel.suspension_stiffness = feel.suspension_stiffness
	if ids.has(&"tyres"):
		feel.wheel_friction *= feel.tyres_grip_mult
		feel.engine_force *= feel.tyres_force_mult
		for wheel: VehicleWheel3D in _wheels:
			wheel.wheel_friction_slip = feel.wheel_friction
	if ids.has(&"searchlight") and not has_node(^"Searchlight"):
		var light := SpotLight3D.new()
		light.name = "Searchlight"
		light.light_color = Color(0.95, 0.97, 1.0)
		light.light_energy = feel.searchlight_energy
		light.spot_range = feel.searchlight_range
		light.spot_angle = feel.searchlight_angle_deg
		light.shadow_enabled = true
		light.position = Vector3(0.0, 2.3, 1.2)
		light.rotation = Vector3(deg_to_rad(-9.0), PI, 0.0)
		light.visible = headlights_on
		add_child(light)
		_lights.append(light)
		var lamp := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.5, 0.16, 0.2)
		lamp.mesh = box
		lamp.position = light.position - Vector3(0.0, 0.08, 0.1)
		add_child(lamp)
	upgrades = ids.duplicate()


func toggle_doors() -> void:
	doors_open = not doors_open
	var tween: Tween = create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_method(func(a: float) -> void:
		_door_angle = a
		_apply_doors(), _door_angle, deg_to_rad(115.0) if doors_open else 0.0, 0.55) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	Audio.play_impact(&"metal_hollow", global_position - global_basis.z * 2.2 + Vector3.UP, 4.0)
	doors_toggled.emit(doors_open)


# --- езда ------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	var speed: float = forward_speed()
	_update_stall(delta, speed)
	var power: float = power_factor() if engine_on else 0.0
	# руль: на скорости колёса поворачиваются меньше
	var limit: float = lerpf(feel.steer_max, feel.steer_max_fast, clampf(absf(speed) / feel.max_speed, 0.0, 1.0))
	steering = move_toward(steering, clampf(steer, -1.0, 1.0) * limit, feel.steer_speed * delta)
	var gas: float = clampf(throttle, -1.0, 1.0)
	var force: float = 0.0
	var braking: float = clampf(brake_input, 0.0, 1.0) * feel.brake_force
	if gas > 0.0:
		if speed < -0.5:
			braking = maxf(braking, feel.brake_force * gas)      # едем назад — сначала тормозим
		else:
			# тяга падает к наибольшей скорости, как у настоящего мотора на одной передаче
			var top: float = feel.max_speed * lerpf(0.6, 1.0, power)
			force = feel.engine_force * power * gas * clampf(1.0 - speed / top, 0.0, 1.0)
	elif gas < 0.0:
		if speed > 0.5:
			braking = maxf(braking, feel.brake_force * -gas)
		else:
			force = feel.engine_force * 0.7 * power * gas * clampf(1.0 + speed / feel.max_reverse_speed, 0.0, 1.0)
	else:
		braking = maxf(braking, feel.idle_brake)
	# толкают пустую машину: считаем, что её сняли с ручника
	_pushed = maxf(_pushed - delta, 0.0)
	if _pushed > 0.0 and driver == null:
		braking = 0.0
	engine_force = force / 4.0     # движок отдаёт это число на каждое ведущее колесо
	brake = braking
	# на ручнике стоящую машину «примораживаем» вязкостью: иначе она ползёт на подвеске
	var parked: bool = _pushed <= 0.0 and brake_input >= 1.0 and absf(speed) < 0.6 and _wheels[0].is_in_contact() and _wheels[3].is_in_contact()
	linear_damp = feel.parked_damp if parked else 0.0
	angular_damp = feel.parked_damp if parked else 0.0
	# обороты для звука: от скорости и от газа
	var target_rpm: float = clampf(absf(speed) / feel.max_speed * 0.75 + absf(gas) * 0.35, 0.0, 1.2) if engine_on else 0.0
	_rpm = lerpf(_rpm, target_rpm, 1.0 - exp(-4.0 * delta))
	if _sound != null and _crank > 0.0:
		_sound.pitch_scale = 0.42 + 0.08 * sin(_crank * 40.0)   # стартер: низко и с дрожью
		_sound.volume_db = -8.0
	elif _sound != null and engine_on:
		_sound.pitch_scale = 0.75 + _rpm * 1.25
		# под нагрузкой (газ в пол, а скорость не растёт) мотор звучит громче и ниже
		_sound.volume_db = -9.0 + absf(gas) * 6.0 + (1.0 - power) * 3.0


## Мотор глохнет, если газ в пол, а машина не едет (перегруз на подъёме, упёрлась).
## Завести: отпустить газ и нажать снова.
func _update_stall(delta: float, speed: float) -> void:
	var gas: float = absf(throttle)
	if gas < 0.1:
		_gas_released = true
	if stalled:
		if _crank > 0.0:
			_crank -= delta
			if _crank <= 0.0:
				stalled = false
				engine_on = true
				engine_toggled.emit(true)
		elif gas > 0.5 and _gas_released and driver != null:
			_crank = feel.crank_time
			_gas_released = false
			if _sound != null:
				_sound.play()
		return
	# не едет туда, куда газуем (стоит или скатывается назад)
	if engine_on and gas > 0.5 and speed * signf(throttle) < 0.35 and brake_input < 0.5:
		_stall_clock += delta
		if _stall_clock >= feel.stall_time:
			stalled = true
			engine_on = false
			_stall_clock = 0.0
			_gas_released = false
			if _sound != null:
				_sound.stop()
			Audio.play_impact(&"metal_hollow", to_global(Vector3(0.0, 0.9, 1.6)), 5.0)
			stalled_out.emit()
			engine_toggled.emit(false)
	else:
		_stall_clock = maxf(_stall_clock - delta * 2.0, 0.0)


# --- взаимодействие ----------------------------------------------------------------

## Что можно сделать, глядя в точку машины: {"hint": ключ перевода, "action": имя} или пусто.
func interaction_at(world_point: Vector3) -> Dictionary:
	var p: Vector3 = to_local(world_point)
	if p.z < -1.7:
		return {"hint": "HINT_VAN_DOORS_CLOSE" if doors_open else "HINT_VAN_DOORS_OPEN", "action": &"doors"}
	if p.z > 0.75:
		if p.x > 0.3 and driver == null:
			return {"hint": "HINT_VAN_DRIVE", "action": &"drive"}
		if p.x < -0.3 and passenger == null:
			return {"hint": "HINT_VAN_RIDE", "action": &"ride"}
		return {}
	if strapped:
		return {"hint": "HINT_VAN_STRAPS_OFF", "action": &"straps"}
	if not cargo_bodies().is_empty():
		return {"hint": "HINT_VAN_STRAPS_ON", "action": &"straps"}
	return {}


func interact(player: PlayerController, action: StringName) -> void:
	match action:
		&"doors":
			toggle_doors()
		&"straps":
			set_straps(not strapped)
		&"ride":
			if passenger == null:
				passenger = player
				player.sit(self, _seats[&"seat_passenger"])
		&"drive":
			if driver == null:
				driver = player
				player.sit(self, _seats[&"seat_driver"])
				brake_input = 0.0
				set_engine(true)


## Игрок встаёт с места: где ему появиться.
func release(player: PlayerController) -> Vector3:
	if player == passenger:
		passenger = null
		var out: Vector3 = _exit_driver.position
		out.x = -out.x
		return to_global(out)
	driver = null
	stalled = false
	_crank = 0.0
	throttle = 0.0
	steer = 0.0
	brake_input = 1.0      # ручник
	set_engine(false)
	return _exit_driver.global_position
