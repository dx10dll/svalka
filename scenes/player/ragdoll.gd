class_name Ragdoll
extends Node3D
## Рэгдолл персонажа: 11 твёрдых тел на суставах поверх скелета.
##
## Свой, а не PhysicalBoneSimulator3D: так лимиты суставов, демпферы и массы
## лежат в одной таблице, а позы тел можно слать по сети как обычные тела.
## Пока рэгдолл выключен, тела заморожены и ни с чем не сталкиваются.
## activate() ставит тела в текущую позу анимации и отпускает их;
## release() плавно возвращает управление анимации (вставание).

## Таблица тел. bone — кость, которую ведёт тело; length — длина вдоль кости, м;
## size — радиус капсулы или размеры коробки; parent — к какому телу крепится;
## joint: "cone" (шаровой с ограничением) или "hinge" (колено, локоть).
const PARTS: Array[Dictionary] = [
	{"bone": &"hips", "shape": "box", "size": Vector3(0.32, 0.15, 0.24), "offset": 0.04, "mass": 9.0},
	{"bone": &"spine", "shape": "box", "size": Vector3(0.42, 0.3, 0.28), "offset": 0.15, "mass": 15.0,
		"parent": &"hips", "joint": "cone", "swing": 28.0, "twist": 22.0},
	{"bone": &"head", "shape": "sphere", "size": 0.17, "offset": 0.16, "mass": 6.0,
		"parent": &"spine", "joint": "cone", "swing": 42.0, "twist": 35.0},
	{"bone": &"upper_arm.L", "shape": "capsule", "size": 0.058, "length": 0.22, "mass": 1.6,
		"parent": &"spine", "joint": "cone", "swing": 85.0, "twist": 40.0},
	{"bone": &"upper_arm.R", "shape": "capsule", "size": 0.058, "length": 0.22, "mass": 1.6,
		"parent": &"spine", "joint": "cone", "swing": 85.0, "twist": 40.0},
	{"bone": &"forearm.L", "shape": "capsule", "size": 0.06, "length": 0.4, "mass": 1.8,
		"parent": &"upper_arm.L", "joint": "hinge", "min": 0.0, "max": 140.0},
	{"bone": &"forearm.R", "shape": "capsule", "size": 0.06, "length": 0.4, "mass": 1.8,
		"parent": &"upper_arm.R", "joint": "hinge", "min": 0.0, "max": 140.0},
	{"bone": &"thigh.L", "shape": "capsule", "size": 0.085, "length": 0.19, "mass": 3.5,
		"parent": &"hips", "joint": "cone", "swing": 65.0, "twist": 20.0},
	{"bone": &"thigh.R", "shape": "capsule", "size": 0.085, "length": 0.19, "mass": 3.5,
		"parent": &"hips", "joint": "cone", "swing": 65.0, "twist": 20.0},
	{"bone": &"shin.L", "shape": "capsule", "size": 0.085, "length": 0.26, "mass": 2.8,
		"parent": &"thigh.L", "joint": "hinge", "min": -140.0, "max": 0.0},
	{"bone": &"shin.R", "shape": "capsule", "size": 0.085, "length": 0.26, "mass": 2.8,
		"parent": &"thigh.R", "joint": "hinge", "min": -140.0, "max": 0.0},
]

## Слой столкновений частей рэгдолла (бит 4) и с чем они сталкиваются (мир и предметы)
const LAYER: int = 1 << 3
const MASK: int = 1

@export var linear_damp: float = 0.15
@export var angular_damp: float = 1.2
@export var friction: float = 0.9
## Случайная закрутка при падении, рад/с: без неё тело падает «солдатиком»
@export var tumble: float = 3.5

var active: bool = false
## Тела по имени кости
var bodies: Dictionary[StringName, RigidBody3D] = {}

var _skeleton: Skeleton3D
var _owner_body: PhysicsBody3D
var _modifier: RagdollPose
var _blend_tween: Tween


func setup(skeleton: Skeleton3D, owner_body: PhysicsBody3D) -> void:
	_skeleton = skeleton
	_owner_body = owner_body
	top_level = true
	global_transform = Transform3D.IDENTITY
	var sk_xf: Transform3D = skeleton.global_transform
	for part: Dictionary in PARTS:
		var bone: int = skeleton.find_bone(part["bone"])
		assert(bone >= 0, "рэгдолл: нет кости %s" % part["bone"])
		var body := RigidBody3D.new()
		body.name = String(part["bone"]).replace(".", "_")
		body.mass = part["mass"]
		body.linear_damp = linear_damp
		body.angular_damp = angular_damp
		body.can_sleep = false
		body.continuous_cd = true
		var mat := PhysicsMaterial.new()
		mat.friction = friction
		mat.bounce = 0.05
		body.physics_material_override = mat
		body.add_child(_make_shape(part))
		add_child(body)
		body.global_transform = (sk_xf * skeleton.get_bone_global_rest(bone)).orthonormalized()
		body.add_collision_exception_with(owner_body)
		body.set_meta(&"bone", bone)
		bodies[part["bone"]] = body
	for part: Dictionary in PARTS:
		if part.has("parent"):
			_make_joint(part)
	_set_frozen(true)

	_modifier = RagdollPose.new()
	_modifier.name = "RagdollPose"
	_modifier.ragdoll = self
	_modifier.influence = 0.0
	_modifier.active = false
	skeleton.add_child(_modifier)


func _make_shape(part: Dictionary) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	match part["shape"]:
		"box":
			var box := BoxShape3D.new()
			box.size = part["size"]
			cs.shape = box
			cs.position.y = part["offset"]
		"sphere":
			var sphere := SphereShape3D.new()
			sphere.radius = part["size"]
			cs.shape = sphere
			cs.position.y = part["offset"]
		"capsule":
			var capsule := CapsuleShape3D.new()
			capsule.radius = part["size"]
			capsule.height = part["length"]
			cs.shape = capsule
			cs.position.y = float(part["length"]) * 0.5  # кость идёт вдоль своей оси Y
	return cs


func _make_joint(part: Dictionary) -> void:
	var child: RigidBody3D = bodies[part["bone"]]
	var parent: RigidBody3D = bodies[part["parent"]]
	var along: Vector3 = child.global_basis.y.normalized()   # вдоль кости
	var side: Vector3 = _skeleton.global_basis.x.normalized()  # вбок персонажа
	var joint: Joint3D
	var frame: Transform3D
	if part["joint"] == "hinge":
		var hinge := HingeJoint3D.new()
		# ось шарнира — локальная Z сустава: ставим её вбок персонажа
		var z: Vector3 = side
		var y: Vector3 = (along - z * along.dot(z)).normalized()
		frame = Transform3D(Basis(y.cross(z), y, z), child.global_position)
		hinge.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
		hinge.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, deg_to_rad(part["min"]))
		hinge.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, deg_to_rad(part["max"]))
		joint = hinge
	else:
		var cone := ConeTwistJoint3D.new()
		# ось скручивания — локальная X сустава: ставим её вдоль кости
		var x: Vector3 = along
		var helper: Vector3 = side if absf(along.dot(side)) < 0.9 else Vector3.UP
		var z2: Vector3 = x.cross(helper).normalized()
		frame = Transform3D(Basis(x, z2.cross(x), z2), child.global_position)
		cone.swing_span = deg_to_rad(part["swing"])
		cone.twist_span = deg_to_rad(part["twist"])
		joint = cone
	add_child(joint)
	joint.global_transform = frame
	joint.node_a = joint.get_path_to(parent)
	joint.node_b = joint.get_path_to(child)


func _set_frozen(frozen: bool) -> void:
	for body: RigidBody3D in bodies.values():
		body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		body.freeze = frozen
		body.collision_layer = 0 if frozen else LAYER
		body.collision_mask = 0 if frozen else MASK


## Включить рэгдолл из текущей позы анимации, с начальной скоростью тела.
func activate(velocity: Vector3) -> void:
	if _blend_tween != null:
		_blend_tween.kill()
	var sk_xf: Transform3D = _skeleton.global_transform
	for body: RigidBody3D in bodies.values():
		var bone: int = body.get_meta(&"bone")
		body.global_transform = (sk_xf * _skeleton.get_bone_global_pose(bone)).orthonormalized()
		body.reset_physics_interpolation()
	_set_frozen(false)
	var spin := Vector3(randf_range(-1.0, 1.0), randf_range(-0.3, 0.3), randf_range(-1.0, 1.0)) * tumble
	for body: RigidBody3D in bodies.values():
		body.linear_velocity = velocity
		body.angular_velocity = spin
	active = true
	_modifier.active = true
	_modifier.influence = 1.0


## Плавно вернуть скелет анимации за duration секунд (персонаж встаёт).
func release(duration: float) -> void:
	if not active:
		return
	_set_frozen(true)  # тела замирают, поза держится и растворяется в анимации
	active = false
	_blend_tween = create_tween()
	_blend_tween.tween_property(_modifier, ^"influence", 0.0, maxf(duration * 0.6, 0.05)) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_blend_tween.tween_callback(func() -> void: _modifier.active = false)


## Где сейчас таз (по нему контроллер и камера следят за упавшим).
func hips_position() -> Vector3:
	return bodies[&"hips"].global_position


func head_transform() -> Transform3D:
	return bodies[&"head"].get_global_transform_interpolated()


func total_speed() -> float:
	return bodies[&"hips"].linear_velocity.length()
