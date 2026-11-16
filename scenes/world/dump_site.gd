class_name DumpSite
extends Node3D
## Окружение свалки вокруг горы: подъездная дорога, будка сторожа, редкие фонари,
## костры в бочках, лужи. Всё расставляется по сиду кучи, поэтому у всех игроков
## одинаково. Числа — в константах наверху: окружение пока не балансовая часть.

const LAMP_MODEL: String = "res://assets/models/props/lamp_post.glb"
const BOOTH_MODEL: String = "res://assets/models/props/guard_booth.glb"
const BARREL_MODEL: String = "res://assets/models/props/fire_barrel.glb"
const CRATE_MODEL: String = "res://assets/models/props/crate_wood.glb"
const SODIUM_COLOR := Color(1.0, 0.64, 0.28)

## Длина дороги от подножия горы до ворот, м
const ROAD_LENGTH: float = 46.0
const ROAD_WIDTH: float = 5.0
const BONFIRES: int = 3
const PUDDLES: int = 14
const RING_LAMPS: int = 4
## Подъезд к воротам снаружи: отсюда начинается ночь, м
const APPROACH_LENGTH: float = 120.0
const FENCE_HEIGHT: float = 2.3
const FENCE_PANEL: float = 3.0
## Ширина дыры в заборе, м
const HOLE_WIDTH: float = 4.6
const BARRIER_HEIGHT: float = 0.95

## Где стоит будка сторожа и где въезд (мир) — пригодится сторожу и буханке
var booth_position := Vector3.ZERO
var gate_position := Vector3.ZERO
var fires: Array[Fire] = []
var mound: Mound
## Середина дыры в заборе (мир): объезд мимо сторожа
var hole_position := Vector3.ZERO
## Откуда буханка начинает ночь (мир), носом к воротам
var start_position := Vector3.ZERO
var barrier_open: bool = true
## Ящик у будки, куда платят сторожу (вешает сцена ночи)
var booth_spot_position := Vector3.ZERO

var _arm_pivot: Node3D
var _arm_body: StaticBody3D

var _rng := RandomNumberGenerator.new()
var _radius: float = 20.0


## Построить окружение вокруг кучи радиуса radius. Дорога идёт от горы в сторону +Z.
func build(radius: float, site_seed: int) -> void:
	_radius = radius
	_rng.seed = site_seed * 2654435761 + 17
	gate_position = Vector3(0.0, 0.0, radius + ROAD_LENGTH)
	_build_road()
	_build_mound()
	_build_booth()
	_build_fence()
	_build_approach()
	_build_lamps()
	_build_bonfires()
	_build_puddles()


func _instance(path: String, at: Vector3, yaw: float) -> Node3D:
	var node: Node3D = (load(path) as PackedScene).instantiate()
	# коллизии модели должны лежать в статичном теле
	var body := StaticBody3D.new()
	body.position = at
	body.rotation.y = yaw
	add_child(body)
	body.add_child(node)
	for shape: Node in node.find_children("col_*", "CollisionShape3D", true, false):
		var xf: Transform3D = (shape as CollisionShape3D).transform
		shape.owner = null
		shape.get_parent().remove_child(shape)
		body.add_child(shape)
		(shape as CollisionShape3D).transform = xf
	return body


func _flat_mesh(size: Vector2, at: Vector3, yaw: float, color: Color, roughness: float, metallic: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = size
	mi.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	mi.material_override = mat
	mi.position = at
	mi.rotation.y = yaw
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## Грунтовка: тёмная полоса с двумя колеями и обочинами.
func _build_road() -> void:
	var mid: float = _radius + ROAD_LENGTH * 0.5 - 1.0
	var length: float = ROAD_LENGTH + 6.0
	_flat_mesh(Vector2(ROAD_WIDTH, length), Vector3(0.0, 0.012, mid), 0.0, Color(0.13, 0.115, 0.1), 0.95)
	for side: float in [-1.0, 1.0]:
		_flat_mesh(Vector2(0.55, length), Vector3(side * 0.95, 0.02, mid), 0.0, Color(0.075, 0.068, 0.06), 0.92)
		_flat_mesh(Vector2(0.5, length), Vector3(side * (ROAD_WIDTH * 0.5 + 0.2), 0.016, mid), 0.0, Color(0.17, 0.155, 0.12), 1.0)
	# разворотная площадка у подножия: тут встанет буханка
	_flat_mesh(Vector2(11.0, 9.0), Vector3(0.0, 0.011, _radius + 5.5), 0.0, Color(0.13, 0.115, 0.1), 0.95)


## Насыпь поперёк дороги на полпути к воротам: гружёной машине её ещё надо взять.
func _build_mound() -> void:
	mound = Mound.new()
	mound.position = Vector3(0.0, 0.0, _radius + 21.0)
	add_child(mound)
	mound.build()


func _build_booth() -> void:
	booth_position = Vector3(ROAD_WIDTH * 0.5 + 2.4, 0.0, gate_position.z - 6.0)
	_instance(BOOTH_MODEL, booth_position, PI * 0.5)   # окно смотрит на дорогу
	var window := OmniLight3D.new()
	window.light_color = Color(1.0, 0.8, 0.5)
	window.light_energy = 1.6
	window.omni_range = 6.0
	window.position = booth_position + Vector3(-1.5, 1.6, 0.4)
	add_child(window)
	# шлагбаум: стойка у будки, стрела на шарнире поперёк дороги
	var post_at: Vector3 = booth_position + Vector3(-1.6, 0.0, 3.2)
	var post := _box(Vector3(0.16, 1.1, 0.16), post_at + Vector3.UP * 0.55, Color(0.7, 0.68, 0.6))
	post.name = "BarrierPost"
	var arm_length: float = ROAD_WIDTH + 1.6
	_arm_pivot = Node3D.new()
	_arm_pivot.name = "BarrierArm"
	_arm_pivot.position = post_at + Vector3.UP * BARRIER_HEIGHT
	add_child(_arm_pivot)
	_arm_body = _box(Vector3(arm_length, 0.1, 0.1), Vector3.ZERO, Color(0.75, 0.2, 0.15))
	remove_child(_arm_body)
	_arm_pivot.add_child(_arm_body)
	_arm_body.position = Vector3(-arm_length * 0.5, 0.0, 0.0)
	booth_spot_position = Vector3(ROAD_WIDTH * 0.5 + 1.7, 0.95, gate_position.z + 1.0)   # снаружи, у столба ворот
	set_barrier(true, true)
	_lamp(booth_position + Vector3(1.2, 0.0, 3.6), PI)


## Открыть или закрыть шлагбаум. instant — без движения стрелы.
func set_barrier(open: bool, instant: bool = false) -> void:
	barrier_open = open
	var angle: float = -1.25 if open else 0.0
	_arm_body.collision_layer = 0 if open else 1    # поднятая стрела не мешает машине
	if instant or not is_inside_tree():
		_arm_pivot.rotation.z = angle
		return
	var tween: Tween = create_tween()
	tween.tween_property(_arm_pivot, ^"rotation:z", angle, 1.2).set_trans(Tween.TRANS_SINE)


## Бетонный забор по линии ворот на всю ширину площадки. В нём проезд под шлагбаумом
## и дыра в стороне — по сиду то слева, то справа.
func _build_fence() -> void:
	var half: float = _radius * 3.0
	var side: float = -1.0 if _rng.randf() < 0.5 else 1.0
	hole_position = Vector3(side * _rng.randf_range(20.0, 32.0), 0.0, gate_position.z)
	var gate_left: float = -ROAD_WIDTH * 0.5 - 0.7
	var gate_right: float = ROAD_WIDTH * 0.5 + 0.9
	var cuts: Array[Vector2] = [Vector2(gate_left, gate_right),
			Vector2(hole_position.x - HOLE_WIDTH * 0.5, hole_position.x + HOLE_WIDTH * 0.5)]
	cuts.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var spans: Array[Vector2] = [Vector2(-half, cuts[0].x), Vector2(cuts[0].y, cuts[1].x), Vector2(cuts[1].y, half)]
	var panels: Array[Transform3D] = []
	for span: Vector2 in spans:
		var length: float = span.y - span.x
		var wall := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(length, FENCE_HEIGHT, 0.18)
		shape.shape = box
		wall.add_child(shape)
		wall.position = Vector3(span.x + length * 0.5, FENCE_HEIGHT * 0.5, gate_position.z)
		add_child(wall)
		var count: int = maxi(1, roundi(length / FENCE_PANEL))
		var step: float = length / count
		for i: int in count:
			var basis := Basis(Vector3.UP, _rng.randf_range(-0.03, 0.03)) * Basis(Vector3.RIGHT, _rng.randf_range(-0.05, 0.05))
			basis = basis.scaled(Vector3(step / FENCE_PANEL * 0.985, 1.0, 1.0))
			panels.append(Transform3D(basis, Vector3(span.x + step * (i + 0.5), FENCE_HEIGHT * 0.5 - _rng.randf_range(0.0, 0.08), gate_position.z)))
	# выломанная плита лежит у дыры, к ней накатана колея
	panels.append(Transform3D(Basis(Vector3.RIGHT, -1.42) * Basis(Vector3.UP, 0.3),
			hole_position + Vector3(side * 1.2, 0.22, -2.2)))
	_flat_mesh(Vector2(3.2, 14.0), hole_position + Vector3.UP * 0.012, 0.0, Color(0.115, 0.1, 0.088), 0.95)
	# у дыры горит фонарь: её должно быть видно с дороги
	_lamp(hole_position + Vector3(-side * (HOLE_WIDTH * 0.5 + 1.2), 0.0, -1.5), 0.0 if side > 0.0 else PI)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var slab := BoxMesh.new()
	slab.size = Vector3(FENCE_PANEL, FENCE_HEIGHT, 0.16)
	mm.mesh = slab
	mm.instance_count = panels.size()
	for i: int in panels.size():
		mm.set_instance_transform(i, panels[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Fence"
	mmi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.35, 0.33)
	mat.roughness = 1.0
	mmi.material_override = mat
	add_child(mmi)
	# столбы ворот
	for x: float in [gate_left, gate_right]:
		_box(Vector3(0.35, FENCE_HEIGHT + 0.5, 0.35), Vector3(x, (FENCE_HEIGHT + 0.5) * 0.5, gate_position.z), Color(0.3, 0.29, 0.27))


## Подъезд снаружи: земля и грунтовка от края площадки до места, где начинается ночь.
func _build_approach() -> void:
	var edge: float = _radius * 3.0
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(_radius * 6.0, 1.0, APPROACH_LENGTH)
	shape.shape = box
	ground.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = box.size
	mesh.mesh = box_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.18, 0.15)
	mat.roughness = 1.0
	mesh.material_override = mat
	ground.add_child(mesh)
	ground.position = Vector3(0.0, -0.505, edge + APPROACH_LENGTH * 0.5)
	add_child(ground)
	var from: float = _radius + ROAD_LENGTH + 2.0
	var to: float = edge + APPROACH_LENGTH - 4.0
	var mid: float = (from + to) * 0.5
	_flat_mesh(Vector2(ROAD_WIDTH, to - from), Vector3(0.0, 0.012, mid), 0.0, Color(0.13, 0.115, 0.1), 0.95)
	for side: float in [-1.0, 1.0]:
		_flat_mesh(Vector2(0.55, to - from), Vector3(side * 0.95, 0.02, mid), 0.0, Color(0.075, 0.068, 0.06), 0.92)
	start_position = Vector3(0.0, 0.0, to - 10.0)
	_lamp(Vector3(ROAD_WIDTH * 0.5 + 0.8, 0.0, start_position.z - 6.0), PI)
	_lamp(Vector3(-ROAD_WIDTH * 0.5 - 0.8, 0.0, (start_position.z + gate_position.z) * 0.5), 0.0)


func _box(size: Vector3, at: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mi.material_override = mat
	body.add_child(mi)
	body.position = at
	add_child(body)
	return body


## Фонарь: столб из модели, лампа светит вниз. yaw — куда смотрит «гусак».
func _lamp(at: Vector3, yaw: float) -> void:
	_instance(LAMP_MODEL, at, yaw)
	var head: Vector3 = at + Basis(Vector3.UP, yaw) * Vector3(0.95, 5.72, 0.0)
	var bulb := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.4, 0.04, 0.15)
	bulb.mesh = mesh
	var glow := StandardMaterial3D.new()
	glow.emission_enabled = true
	glow.emission = SODIUM_COLOR
	glow.emission_energy_multiplier = 7.0
	glow.albedo_color = SODIUM_COLOR
	bulb.material_override = glow
	bulb.position = head
	bulb.rotation.y = yaw
	add_child(bulb)
	var light := SpotLight3D.new()
	light.light_color = SODIUM_COLOR
	light.light_energy = 10.0
	light.light_volumetric_fog_energy = 1.6
	light.spot_range = 16.0
	light.spot_angle = 60.0
	light.shadow_enabled = true
	light.position = head + Vector3.DOWN * 0.08
	light.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	add_child(light)


func _build_lamps() -> void:
	# вдоль дороги редко и по одной стороне, у разворота, и несколько вокруг горы
	_lamp(Vector3(-ROAD_WIDTH * 0.5 - 0.8, 0.0, _radius + 4.0), 0.0)
	_lamp(Vector3(-ROAD_WIDTH * 0.5 - 0.8, 0.0, _radius + ROAD_LENGTH * 0.55), 0.0)
	var start: float = _rng.randf() * TAU
	for i: int in RING_LAMPS:
		var a: float = start + TAU * (i + 0.5) / RING_LAMPS + _rng.randf_range(-0.25, 0.25)
		var dir := Vector3(cos(a), 0.0, sin(a))
		if dir.z > 0.8:
			continue   # там дорога
		_lamp(dir * (_radius + 2.5), atan2(dir.x, dir.z) + PI * 0.5)


## Костры бомжей: бочка с огнём, пара ящиков вместо стульев.
func _build_bonfires() -> void:
	var start: float = _rng.randf() * TAU
	for i: int in BONFIRES:
		var a: float = start + TAU * i / BONFIRES + _rng.randf_range(-0.4, 0.4)
		var dir := Vector3(cos(a), 0.0, sin(a))
		if dir.z > 0.75:
			dir = Vector3(dir.x, 0.0, -dir.z)
		var at: Vector3 = dir * (_radius + _rng.randf_range(6.0, 10.0))
		_instance(BARREL_MODEL, at, _rng.randf() * TAU)
		var fire := Fire.new()
		fire.position = at
		add_child(fire)
		fires.append(fire)
		for k: int in 2 + _rng.randi() % 2:
			var seat_a: float = _rng.randf() * TAU
			var seat: Node3D = _instance(CRATE_MODEL, at + Vector3(cos(seat_a), 0.0, sin(seat_a)) * _rng.randf_range(1.3, 1.9),
					_rng.randf() * TAU)
			seat.scale = Vector3.ONE * 0.45


## Лужи: тёмные гладкие пятна, в которых отражаются фонари и костры.
func _build_puddles() -> void:
	for i: int in PUDDLES:
		var at: Vector3
		if i < 5:
			# в колеях дороги
			at = Vector3(_rng.randf_range(-1.6, 1.6), 0.026, _radius + _rng.randf_range(4.0, ROAD_LENGTH - 4.0))
		else:
			var a: float = _rng.randf() * TAU
			at = Vector3(cos(a), 0.0, sin(a)) * (_radius + _rng.randf_range(1.5, 9.0)) + Vector3.UP * 0.014
		var size := Vector2(_rng.randf_range(1.0, 3.2), _rng.randf_range(0.8, 2.2))
		_flat_mesh(size, at, _rng.randf() * TAU, Color(0.02, 0.022, 0.03), 0.04, 0.6)
