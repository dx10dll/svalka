class_name PlayerCamera
extends Node3D
## Голова и камера от первого лица. Только читает контроллер и ничего в нём не меняет.
## Качание от шага, наклон при движении боком, просадка при приземлении,
## рывок при залезании, падение камеры на землю при сбивании с ног.
##
## Узел отвязан от физической интерполяции: позиция берётся из сглаженного
## положения тела, а поворот — сразу из мыши, без задержки.

var camera: Camera3D

var _player: PlayerController
var _feel: PlayerFeel
# пружина просадки при приземлении
var _dip: float = 0.0
var _dip_velocity: float = 0.0
var _bob_weight: float = 0.0
var _roll: float = 0.0
var _fov_add: float = 0.0
var _eye_height: float = 1.66
var _downed_roll_sign: float = 1.0
var _mantle_kick: float = 0.0


func setup(player: PlayerController) -> void:
	_player = player
	_feel = player.feel
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera = Camera3D.new()
	camera.fov = _feel.fov
	camera.near = 0.05
	camera.far = 400.0
	add_child(camera)
	camera.make_current()
	_eye_height = player.eye_height()
	player.landed.connect(_on_landed)
	player.jumped.connect(func() -> void: _dip_velocity += 0.9)
	player.knocked_down.connect(_on_knocked_down)
	player.mantle_started.connect(func(_h: float, _t: float) -> void: _mantle_kick = 1.0)


func _process(delta: float) -> void:
	if _player == null:
		return
	var speed: float = _player.horizontal_speed()
	var grounded: bool = _player.is_on_floor() and _player.mode == PlayerController.Mode.NORMAL

	# пружина просадки
	_dip_velocity += (-_feel.landing_spring * _dip - _feel.landing_damping * _dip_velocity) * delta
	_dip += _dip_velocity * delta
	_dip = clampf(_dip, -_feel.landing_dip_max, 0.15)

	# качание от шага: сила растёт со скоростью, в воздухе затухает
	var bob_target: float = clampf(speed / _feel.walk_speed, 0.0, 1.5) if grounded else 0.0
	_bob_weight = lerpf(_bob_weight, bob_target, 1.0 - exp(-9.0 * delta))
	var phase: float = _player.stride_distance / _feel.stride_length * TAU
	var bob_y: float = -absf(sin(phase)) * _feel.bob_height * _bob_weight
	var bob_x: float = cos(phase) * _feel.bob_side * _bob_weight
	var bob_roll: float = cos(phase) * deg_to_rad(_feel.bob_roll_deg) * _bob_weight

	# наклон при движении боком
	var local_v: Vector3 = Basis(Vector3.UP, _player.yaw).inverse() * _player.velocity
	var roll_target: float = -local_v.x / _feel.sprint_speed * deg_to_rad(_feel.strafe_roll_deg)
	_roll = lerpf(_roll, roll_target, 1.0 - exp(-8.0 * delta))

	# рывок камеры при залезании: клюём носом и выпрямляемся
	_mantle_kick = lerpf(_mantle_kick, 0.0, 1.0 - exp(-5.0 * delta))
	var mantle_pitch: float = 0.0
	if _player.mode == PlayerController.Mode.MANTLE:
		mantle_pitch = -sin(_player.mode_progress * PI) * 0.16

	# лежим: камера у земли, завалена набок
	var down: float = _player.downed_amount()
	_eye_height = lerpf(_eye_height, _player.eye_height(), 1.0 - exp(-18.0 * delta))
	var eye: float = lerpf(_eye_height, 0.28, down)

	var base: Vector3 = _player.get_global_transform_interpolated().origin
	var offset := Vector3(bob_x, eye + bob_y + _dip + _player.step_visual_offset, 0.0)
	var yaw_basis := Basis(Vector3.UP, _player.yaw)
	global_position = base + yaw_basis * offset
	var pitch: float = _player.pitch * (1.0 - down * 0.7) + mantle_pitch + down * 0.35
	var roll: float = _roll + bob_roll + down * 1.15 * _downed_roll_sign - _mantle_kick * 0.04
	global_basis = yaw_basis * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.BACK, roll)

	var fov_target: float = _feel.sprint_fov_add if _player.sprinting else 0.0
	_fov_add = lerpf(_fov_add, fov_target, 1.0 - exp(-6.0 * delta))
	camera.fov = _feel.fov + _fov_add


func _on_landed(impact: float) -> void:
	_dip_velocity -= impact * _feel.landing_dip_per_speed * _feel.landing_spring * 0.09
	if impact >= _feel.hard_landing_speed:
		_dip_velocity -= 1.2


func _on_knocked_down(_impact: float) -> void:
	_downed_roll_sign = 1.0 if randf() > 0.5 else -1.0
	_dip_velocity = 0.0
	_dip = 0.0
