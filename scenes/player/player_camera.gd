class_name PlayerCamera
extends Node3D
## Голова и камера от первого лица. Только читает контроллер и ничего в нём не меняет.
## Качание от шага, наклон при движении боком, просадка при приземлении,
## рывок при залезании, падение камеры на землю при сбивании с ног.
##
## Узел отвязан от физической интерполяции: позиция берётся из сглаженного
## положения тела, а поворот — сразу из мыши, без задержки.

## Слой отрисовки тела местного игрока (второй)
const OWN_BODY_LAYER: int = 2

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
var _has_ragdoll_view: bool = false
var _smooth_y: float = 0.0
var _height_ready: bool = false
var _fall_target := Vector3.ZERO
var _fall_pos := Vector3.ZERO
var _outside: bool = false
var _mantle_kick: float = 0.0
var _shake: float = 0.0
var _flashlight: SpotLight3D


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
	add_to_group(&"player_cameras")
	player.struggled.connect(func() -> void: _shake = maxf(_shake, 0.45))
	player.buried_started.connect(func() -> void: _shake = 1.0)
	# фонарь: узкий тёплый луч чуть ниже и правее глаз, чтобы тени читались
	_flashlight = SpotLight3D.new()
	_flashlight.light_color = Color(1.0, 0.93, 0.78)
	_flashlight.light_energy = _feel.flashlight_energy
	_flashlight.spot_range = _feel.flashlight_range
	_flashlight.spot_angle = _feel.flashlight_angle_deg
	_flashlight.spot_angle_attenuation = 0.6
	_flashlight.spot_attenuation = 1.2
	_flashlight.shadow_enabled = true
	_flashlight.light_volumetric_fog_energy = 1.5
	_flashlight.position = Vector3(0.14, -0.16, -0.05)
	_flashlight.visible = player.flashlight_on
	# своё тело от своего фонаря тень не бросает: лампа у самых глаз, и тень рук
	# и туловища прыгала рябью по всему лучу. От остальных ламп тень остаётся.
	for mesh: Node in player.body.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).layers = OWN_BODY_LAYER
	_flashlight.shadow_caster_mask = 0xFFFFF & ~OWN_BODY_LAYER
	camera.add_child(_flashlight)
	player.flashlight_toggled.connect(func(on: bool) -> void:
		_flashlight.visible = on
		Audio.play_at(&"grab", global_position, -10.0, 1.6))
	player.belt.changed.connect(_apply_headlamp)
	_apply_headlamp()
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
	var phase: float = _player.stride_phase * TAU
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

	_eye_height = lerpf(_eye_height, _player.eye_height(), 1.0 - exp(-18.0 * delta))

	# обычный вид: позиция из сглаженного тела, поворот сразу из мыши
	var base: Vector3 = _player.get_global_transform_interpolated().origin
	# высота глаз догоняет тело плавно: на куче мусора под ногами сплошные ступеньки,
	# и без этого камеру трясёт на каждом куске. В воздухе догоняет почти сразу.
	var follow: float = _feel.camera_height_smoothing if grounded else _feel.camera_height_smoothing * 3.0
	if not _height_ready or absf(base.y - _smooth_y) > _feel.camera_height_max_lag * 3.0:
		_smooth_y = base.y
		_height_ready = true
	_smooth_y = lerpf(_smooth_y, base.y, 1.0 - exp(-follow * delta))
	_smooth_y = clampf(_smooth_y, base.y - _feel.camera_height_max_lag, base.y + _feel.camera_height_max_lag)
	base.y = _smooth_y
	var offset := Vector3(bob_x, _eye_height + bob_y + _dip, 0.0)
	var yaw_basis := Basis(Vector3.UP, _player.yaw)
	var pos: Vector3 = base + yaw_basis * offset
	var roll: float = _roll + bob_roll - _mantle_kick * 0.04
	var basis_n: Basis = yaw_basis * Basis(Vector3.RIGHT, _player.pitch + mantle_pitch) * Basis(Vector3.BACK, roll)

	# за рулём: голова едет и кренится вместе с машиной
	if _player.mode == PlayerController.Mode.SEATED and is_instance_valid(_player.seat_body()):
		var seat: Transform3D = _player.seat_body().get_global_transform_interpolated()
		pos = seat * _player.seat_eye_local + Vector3.UP * _dip
		basis_n = seat.basis.orthonormalized() * Basis(Vector3.UP, _player.seat_yaw + _player.seat_look) \
				* Basis(Vector3.RIGHT, _player.pitch)

	# сбили с ног: камера отлетает назад и смотрит со стороны, как мужичок кувыркается;
	# при вставании плавно возвращается в глаза
	var down: float = _player.downed_amount()
	if down > 0.0 and _has_ragdoll_view:
		var head: Vector3 = _player.body.ragdoll.head_transform().origin
		_fall_target = _fall_target.lerp(head, 1.0 - exp(-10.0 * delta))
		var back: Vector3 = Basis(Vector3.UP, _player.yaw) * Vector3.BACK
		var want: Vector3 = _fall_target + back * _feel.fall_cam_distance + Vector3.UP * _feel.fall_cam_height
		# не уходим камерой в стену или в кучу
		var q := PhysicsRayQueryParameters3D.create(_fall_target + Vector3.UP * 0.3, want)
		q.exclude = [_player.get_rid()]
		q.collision_mask = 1
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty() and not (hit["collider"] is RigidBody3D):
			want = (hit["position"] as Vector3).lerp(_fall_target + Vector3.UP * 0.3, 0.15)
		_fall_pos = _fall_pos.lerp(want, 1.0 - exp(-8.0 * delta))
		var k: float = smoothstep(0.0, 1.0, down)
		var look: Vector3 = _fall_target - _fall_pos
		if look.length() > 0.2:
			var side_basis: Basis = Basis.looking_at(look.normalized(), Vector3.UP)
			basis_n = basis_n.slerp(side_basis, k).orthonormalized()
		pos = pos.lerp(_fall_pos, k)
		_set_outside_view(k > 0.3)
	else:
		_has_ragdoll_view = false
		_set_outside_view(false)
	# дрожь (завал рядом): быстро гаснет, сила — квадрат «встряски»
	_shake = maxf(_shake - delta * 1.4, 0.0)
	if _shake > 0.0:
		var s: float = _shake * _shake
		pos += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * s * 0.035
		basis_n = basis_n * Basis.from_euler(Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0),
				randf_range(-1.0, 1.0)) * s * 0.02)
	global_position = pos
	global_basis = basis_n

	var fov_target: float = _feel.sprint_fov_add if _player.sprinting else 0.0
	_fov_add = lerpf(_fov_add, fov_target, 1.0 - exp(-6.0 * delta))
	camera.fov = _feel.fov + _fov_add


## Налобный фонарь на поясе делает луч ярче и шире.
func _apply_headlamp() -> void:
	var on: bool = _player.belt.has_tool(&"headlamp")
	_flashlight.light_energy = _feel.flashlight_energy * (_feel.headlamp_energy_mult if on else 1.0)
	_flashlight.spot_angle = _feel.flashlight_angle_deg * (_feel.headlamp_angle_mult if on else 1.0)


## Встряхнуть камеру от события в точке мира (чем дальше, тем слабее; дальше 16 м не чувствуется).
func shake_from(point: Vector3, strength: float) -> void:
	var k: float = clampf(1.0 - global_position.distance_to(point) / 16.0, 0.0, 1.0)
	_shake = minf(maxf(_shake, strength * k), 1.0)


func _on_landed(impact: float) -> void:
	if impact < _feel.landing_dip_min_speed:
		return      # мелкие ступеньки и кочки камеру не качают
	_dip_velocity -= impact * _feel.landing_dip_per_speed * _feel.landing_spring * 0.09
	if impact >= _feel.hard_landing_speed:
		_dip_velocity -= 1.2


func _on_knocked_down(_impact: float) -> void:
	_dip_velocity = 0.0
	_dip = 0.0
	if _player.body == null:
		return
	# камера стартует из глаз и отъезжает
	_fall_target = _player.body.ragdoll.bodies[&"head"].global_position
	_fall_pos = global_position
	_has_ragdoll_view = true


## Вид со стороны: показываем голову (в виде из глаз она спрятана).
func _set_outside_view(on: bool) -> void:
	if on == _outside:
		return
	_outside = on
	_player.body.set_first_person(not on)
