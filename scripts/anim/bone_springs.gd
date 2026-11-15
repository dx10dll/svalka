class_name BoneSprings
extends SkeletonModifier3D
## Пружинящие кости: живот, кепка, позже капюшон и фонарь.
## Кость качается против ускорения тела и возвращается на место, как желе.
## Своя простая пружина вместо SpringBoneSimulator3D: кости у нас одиночные,
## а здесь всё настраивается тремя числами и одинаково ведёт себя в сети.

class Spring:
	var bone: int
	## Отклонение, радиан на 1 м/с² ускорения (в сотых долях)
	var amount: float
	var stiffness: float
	var damping: float
	var angle := Vector2.ZERO      # наклон вперёд-назад и вбок
	var velocity := Vector2.ZERO

const MAX_ANGLE: float = 0.5

var _springs: Array[Spring] = []
var _last_velocity := Vector3.ZERO
var _accel := Vector3.ZERO
var _has_velocity: bool = false


func add_spring(bone_name: StringName, amount: float, stiffness: float, damping: float) -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null:
		sk = get_parent() as Skeleton3D
	var idx: int = sk.find_bone(bone_name)
	if idx < 0:
		push_warning("BoneSprings: нет кости %s" % bone_name)
		return
	var s := Spring.new()
	s.bone = idx
	s.amount = amount
	s.stiffness = stiffness
	s.damping = damping
	_springs.append(s)


## Сообщить скорость тела в мире (каждый кадр). Ускорение считается отсюда.
func push(world_velocity: Vector3) -> void:
	if _has_velocity:
		_accel = world_velocity - _last_velocity
	_last_velocity = world_velocity
	_has_velocity = true


func _process_modification_with_delta(delta: float) -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null or delta <= 0.0:
		return
	# ускорение в осях скелета: x — вбок, y — вверх, z — вперёд-назад
	var local: Vector3 = sk.global_basis.inverse() * _accel
	_accel = Vector3.ZERO
	for s: Spring in _springs:
		# толчок от рывка тела: вертикальный рывок качает так же, как продольный
		s.velocity += Vector2(local.z - local.y, local.x) * s.amount
		s.velocity += (-s.stiffness * s.angle - s.damping * s.velocity) * delta
		s.angle += s.velocity * delta
		s.angle = s.angle.limit_length(MAX_ANGLE)
		var pose: Transform3D = sk.get_bone_global_pose(s.bone)
		var rot := Basis(Vector3.RIGHT, s.angle.x) * Basis(Vector3.BACK, s.angle.y)
		pose.basis = rot * pose.basis
		sk.set_bone_global_pose(s.bone, pose)
