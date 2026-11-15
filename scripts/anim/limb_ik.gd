class_name LimbIk
extends SkeletonModifier3D
## Двухкостная IK для рук и ног: плечо — локоть — кисть тянутся к цели в мире.
## Своя, аналитическая (теорема косинусов): предсказуема и одинакова на всех машинах.
## Вес цепочки меняется плавно, поэтому руки не «телепортируются» на предмет.

class Chain:
	var upper: int
	var lower: int
	var end: int
	## Куда смотрит локоть или колено (в осях скелета)
	var pole: Vector3
	var target := Vector3.ZERO
	var want_weight: float = 0.0
	var weight: float = 0.0

## Скорость появления и ухода влияния, 1/с
@export var blend_speed: float = 7.0

var _chains: Array[Chain] = []


## Добавить цепочку по именам костей. Возвращает её номер.
func add_chain(skeleton: Skeleton3D, upper: StringName, lower: StringName, end: StringName, pole: Vector3) -> int:
	var c := Chain.new()
	c.upper = skeleton.find_bone(upper)
	c.lower = skeleton.find_bone(lower)
	c.end = skeleton.find_bone(end)
	assert(c.upper >= 0 and c.lower >= 0 and c.end >= 0, "LimbIk: нет костей %s/%s/%s" % [upper, lower, end])
	c.pole = pole.normalized()
	_chains.append(c)
	return _chains.size() - 1


## Задать цель в мире и желаемый вес (0 — анимация, 1 — цель).
func set_target(chain: int, world_position: Vector3, weight: float) -> void:
	_chains[chain].target = world_position
	_chains[chain].want_weight = weight


func release(chain: int) -> void:
	_chains[chain].want_weight = 0.0


func chain_weight(chain: int) -> float:
	return _chains[chain].weight


func _process_modification_with_delta(delta: float) -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null:
		return
	var inv: Transform3D = sk.global_transform.affine_inverse()
	for c: Chain in _chains:
		c.weight = move_toward(c.weight, c.want_weight, blend_speed * delta)
		if c.weight <= 0.001:
			continue
		_solve(sk, c, inv * c.target)


func _solve(sk: Skeleton3D, c: Chain, goal: Vector3) -> void:
	var upper: Transform3D = sk.get_bone_global_pose(c.upper)
	var a: Vector3 = upper.origin
	var b: Vector3 = sk.get_bone_global_pose(c.lower).origin
	var e: Vector3 = sk.get_bone_global_pose(c.end).origin
	var len_a: float = a.distance_to(b)
	var len_b: float = b.distance_to(e)
	# цель смешивается с позой анимации по весу
	var t: Vector3 = e.lerp(goal, smoothstep(0.0, 1.0, c.weight))
	var to_t: Vector3 = t - a
	var dist: float = clampf(to_t.length(), absf(len_a - len_b) + 0.005, len_a + len_b - 0.005)
	var dir: Vector3 = to_t.normalized()
	# локоть: на плоскости, заданной направлением «полюса»
	var cos_a: float = clampf((len_a * len_a + dist * dist - len_b * len_b) / (2.0 * len_a * dist), -1.0, 1.0)
	var perp: Vector3 = c.pole - dir * c.pole.dot(dir)
	if perp.length() < 0.001:
		perp = dir.cross(Vector3.RIGHT)
	perp = perp.normalized()
	var elbow: Vector3 = a + dir * (len_a * cos_a) + perp * (len_a * sqrt(1.0 - cos_a * cos_a))
	# поворачиваем верхнюю кость на локоть
	upper.basis = Basis(Quaternion((b - a).normalized(), (elbow - a).normalized())) * upper.basis
	sk.set_bone_global_pose(c.upper, upper)
	# нижнюю — на цель
	var lower: Transform3D = sk.get_bone_global_pose(c.lower)
	var end_now: Vector3 = sk.get_bone_global_pose(c.end).origin
	var hand_goal: Vector3 = a + dir * dist
	lower.basis = Basis(Quaternion((end_now - lower.origin).normalized(), (hand_goal - lower.origin).normalized())) * lower.basis
	sk.set_bone_global_pose(c.lower, lower)
