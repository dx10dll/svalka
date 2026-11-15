class_name Dump
extends Node3D
## Куча мусора в мире: рисует и делает твёрдой решётку DumpField.
##
## Гибрид из промта: гора статична и дёшева (по чанку 4×4×4 м: MultiMesh на каждый
## вид мусора и одно статичное тело с коробками видимых ячеек), а настоящими
## телами становятся только те куски, которые игрок вытащил или которые потеряли
## опору. Полежав неподвижно, тела запекаются обратно в решётку.
## Невидимые (заваленные со всех сторон) ячейки не рисуются и не имеют коллизии.

## Куча предупреждает: скоро поедет (center — где, pieces — сколько кусков)
signal collapse_warning(center: Vector3, pieces: int)
signal collapsed(center: Vector3, pieces: int)

const CONFIG_PATH: String = "res://data/dump_test.tres"
const NO_CELL := Vector3i(-1, -1, -1)

@export var config: DumpConfig
@export var dump_seed: int = 1

var field: DumpField
## Живые куски мусора (настоящие тела), которые следят за засыпанием
var awake: Array[Item] = []
## Сколько завалов случилось (для тестов и отладки)
var collapse_count: int = 0

var _chunks: Dictionary[Vector3i, DumpChunk] = {}
var _dirty: Dictionary[Vector3i, bool] = {}
var _meshes: Array[Mesh] = []
var _mesh_offsets: Array[Transform3D] = []
var _box: BoxShape3D
var _site_nodes: Dictionary[int, Item] = {}
var _pending: Array[Dictionary] = []
var _rest_time: Dictionary[int, float] = {}
var _rng := RandomNumberGenerator.new()


class DumpChunk:
	var body: StaticBody3D
	var instances: Array[MultiMeshInstance3D] = []
	## Номер коробки в теле -> индекс ячейки
	var shape_cells: PackedInt32Array = []


func _ready() -> void:
	if config == null:
		config = load(CONFIG_PATH)
	_rng.seed = dump_seed
	field = DumpField.new(config, dump_seed)
	for data: ItemData in config.junk:
		var model: Node3D = data.model.instantiate()
		var mi: MeshInstance3D = model.find_child("mesh", true, false)
		_meshes.append(mi.mesh)
		_mesh_offsets.append(mi.transform)
		model.free()
	_box = BoxShape3D.new()
	_box.size = config.cell_size
	var cc: Vector3i = config.chunk_cells
	for cz: int in int(ceil(float(field.size.z) / cc.z)):
		for cy: int in int(ceil(float(field.size.y) / cc.y)):
			for cx: int in int(ceil(float(field.size.x) / cc.x)):
				_rebuild(Vector3i(cx, cy, cz))


# --- отрисовка и коллизии чанков -------------------------------------------------

func _chunk_of(c: Vector3i) -> Vector3i:
	var cc: Vector3i = config.chunk_cells
	return Vector3i(c.x / cc.x, c.y / cc.y, c.z / cc.z)


func _mark_dirty(c: Vector3i) -> void:
	# меняется сама ячейка и видимость шести соседей
	for d: Vector3i in [Vector3i.ZERO, Vector3i.UP, Vector3i.DOWN, Vector3i.LEFT, Vector3i.RIGHT,
			Vector3i.FORWARD, Vector3i.BACK]:
		var n: Vector3i = c + d
		if field.in_bounds(n):
			_dirty[_chunk_of(n)] = true


func _flush_dirty() -> void:
	for key: Vector3i in _dirty:
		_rebuild(key)
	_dirty.clear()


func _rebuild(key: Vector3i) -> void:
	var cc: Vector3i = config.chunk_cells
	var per_kind: Array[Array] = []
	per_kind.resize(config.junk.size())
	for i: int in per_kind.size():
		per_kind[i] = []
	var shape_cells: PackedInt32Array = []
	var shape_xf: Array[Transform3D] = []
	var half_up := Vector3.UP * config.cell_size.y * 0.5
	for y: int in range(key.y * cc.y, mini((key.y + 1) * cc.y, field.size.y)):
		for z: int in range(key.z * cc.z, mini((key.z + 1) * cc.z, field.size.z)):
			for x: int in range(key.x * cc.x, mini((key.x + 1) * cc.x, field.size.x)):
				var c := Vector3i(x, y, z)
				var i: int = field.index_of(c)
				var v: int = field.cells[i]
				if v == DumpField.EMPTY:
					continue
				if v < 0:
					var site: int = -v - 1
					if not _site_nodes.has(site) and field.is_exposed(c):
						_spawn_site(site)
					continue
				if not field.is_exposed(c):
					continue
				var xf: Transform3D = field.piece_transform(c)
				per_kind[v - 1].append(xf * _mesh_offsets[v - 1])
				shape_cells.append(i)
				if field.custom_transforms.has(i):
					var o: Transform3D = xf.orthonormalized()
					shape_xf.append(Transform3D(o.basis, o * half_up))
				else:
					shape_xf.append(Transform3D(Basis.IDENTITY, field.cell_base(c) + half_up))

	var chunk: DumpChunk = _chunks.get(key)
	if chunk == null:
		if shape_cells.is_empty():
			return
		chunk = DumpChunk.new()
		chunk.body = StaticBody3D.new()
		chunk.body.name = "Chunk_%d_%d_%d" % [key.x, key.y, key.z]
		chunk.body.set_meta(&"dump_chunk", key)
		var mat := PhysicsMaterial.new()
		mat.friction = 0.9
		chunk.body.physics_material_override = mat
		add_child(chunk.body)
		chunk.instances.resize(config.junk.size())
		_chunks[key] = chunk
	chunk.shape_cells = shape_cells
	var rid: RID = chunk.body.get_rid()
	PhysicsServer3D.body_clear_shapes(rid)
	for xf: Transform3D in shape_xf:
		PhysicsServer3D.body_add_shape(rid, _box.get_rid(), xf)
	for k: int in per_kind.size():
		var list: Array = per_kind[k]
		var mmi: MultiMeshInstance3D = chunk.instances[k]
		if mmi == null:
			if list.is_empty():
				continue
			mmi = MultiMeshInstance3D.new()
			mmi.multimesh = MultiMesh.new()
			mmi.multimesh.transform_format = MultiMesh.TRANSFORM_3D
			mmi.multimesh.mesh = _meshes[k]
			chunk.body.add_child(mmi)
			chunk.instances[k] = mmi
		mmi.multimesh.instance_count = list.size()
		for n: int in list.size():
			mmi.multimesh.set_instance_transform(n, list[n])


func _spawn_site(site_index: int) -> Item:
	var site: Dictionary = field.sites[site_index]
	var rng := RandomNumberGenerator.new()
	rng.seed = dump_seed * 7919 + site_index
	var item: Item = ItemDb.spawn(config.loot[site["item"]], rng)
	item.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	item.freeze = true
	item.set_meta(&"dump_site", site_index)
	item.transform = field.site_transform(site_index)
	add_child(item)
	_site_nodes[site_index] = item
	return item


# --- раскопка ------------------------------------------------------------------

## Какая ячейка кучи под лучом (collider и номер формы — из результата луча).
func cell_from_hit(collider: Object, shape_index: int) -> Vector3i:
	var body: StaticBody3D = collider as StaticBody3D
	if body == null or not body.has_meta(&"dump_chunk"):
		return NO_CELL
	var chunk: DumpChunk = _chunks.get(body.get_meta(&"dump_chunk"))
	if chunk == null or shape_index < 0 or shape_index >= chunk.shape_cells.size():
		return NO_CELL
	return field.coords_of(chunk.shape_cells[shape_index])


## Что лежит в ячейке (для подписи на экране).
func junk_at(c: Vector3i) -> ItemData:
	var v: int = field.at(c)
	return config.junk[v - 1] if v > 0 else null


## Вытащить кусок мусора из кучи: он становится настоящим телом.
func dig(c: Vector3i) -> Item:
	if field.at(c) <= 0:
		return null
	var xf: Transform3D = field.piece_transform(c)
	var kind: int = field.remove_junk(c)
	_mark_dirty(c)
	_flush_dirty()
	var body: Item = _spawn_junk(kind, xf)
	_check_support([c])
	return body


## Забрать ценную вещь, торчащую из кучи: она оживает, её место пустеет.
func release_site(item: Item) -> void:
	if not item.has_meta(&"dump_site"):
		return
	var site_index: int = item.get_meta(&"dump_site")
	item.remove_meta(&"dump_site")
	var emptied: Array[Vector3i] = field.take_site(site_index)
	for c: Vector3i in emptied:
		_mark_dirty(c)
	_flush_dirty()
	item.freeze = false
	item.sleeping = false
	_check_support(emptied)


func _spawn_junk(kind: int, xf: Transform3D) -> Item:
	var item: Item = ItemDb.spawn(config.junk[kind], _rng)
	item.set_meta(&"junk_kind", kind)
	item.transform = xf.orthonormalized()
	add_child(item)
	awake.append(item)
	return item


# --- завалы ----------------------------------------------------------------------

func _check_support(emptied: Array[Vector3i]) -> void:
	var lost: Dictionary = field.find_unsupported(emptied)
	var junk: Array[Vector3i] = lost["junk"]
	var sites: Array[int] = lost["sites"]
	if junk.is_empty() and sites.is_empty():
		return
	var center := Vector3.ZERO
	for c: Vector3i in junk:
		center += field.cell_base(c)
	for s: int in sites:
		center += field.cell_base(field.sites[s]["anchor"])
	center /= float(junk.size() + sites.size())
	_pending.append({"time": config.warning_time, "junk": junk, "sites": sites, "center": center})
	# предупреждение: скрип, сыплется мелочь, дрожит камера
	var pieces: int = junk.size() + sites.size()
	Audio.play_at(&"creak", to_global(center), -4.0 + minf(pieces, 8.0) * 0.5)
	_crumbs(center, 10 + pieces * 3, 0.6)
	get_tree().call_group(&"player_cameras", &"shake_from", to_global(center), 0.25 + minf(pieces * 0.03, 0.3))
	collapse_warning.emit(to_global(center), pieces)


func _physics_process(delta: float) -> void:
	for i: int in range(_pending.size() - 1, -1, -1):
		_pending[i]["time"] -= delta
		if _pending[i]["time"] <= 0.0:
			var p: Dictionary = _pending[i]
			_pending.remove_at(i)
			_collapse(p)
	_update_resting(delta)


func _collapse(p: Dictionary) -> void:
	var waking: Array[Array] = []
	var emptied: Array[Vector3i] = []
	for c: Vector3i in p["junk"]:
		if field.at(c) <= 0:
			continue
		var xf: Transform3D = field.piece_transform(c)
		waking.append([field.remove_junk(c), xf])
		emptied.append(c)
		_mark_dirty(c)
	var freed: Array[Item] = []
	for s: int in p["sites"]:
		if field.sites[s]["taken"]:
			continue
		var item: Item = _site_nodes.get(s)
		if item == null:
			item = _spawn_site(s)
		item.remove_meta(&"dump_site")
		for c: Vector3i in field.take_site(s):
			emptied.append(c)
			_mark_dirty(c)
		freed.append(item)
	if waking.is_empty() and freed.is_empty():
		return
	_flush_dirty()
	var center: Vector3 = p["center"]
	var outward := Vector3(center.x, 0.0, center.z)
	outward = outward.normalized() if outward.length() > 0.5 else Vector3.ZERO
	var crumbled: int = 0
	for w: Array in waking:
		if awake.size() >= config.max_awake:
			crumbled += 1   # лимит живых тел: остальное просто рассыпается в труху
			continue
		var body: Item = _spawn_junk(w[0], w[1])
		# куски выталкивает наружу и вниз по склону: завал едет на того, кто копал
		body.linear_velocity = outward * _rng.randf_range(config.slide_speed * 0.5, config.slide_speed) \
				+ Vector3(_rng.randf_range(-0.6, 0.6), _rng.randf_range(0.3, 1.6), _rng.randf_range(-0.6, 0.6))
		body.angular_velocity = Vector3(_rng.randf_range(-1.5, 1.5), _rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.5, 1.5))
	for item: Item in freed:
		item.freeze = false
		item.sleeping = false
		item.linear_velocity = outward * 0.6
	var pieces: int = waking.size() + freed.size()
	collapse_count += 1
	Audio.play_at(&"rumble", to_global(center), -6.0 + minf(pieces, 12.0) * 0.5)
	_crumbs(center, 20 + pieces * 6 + crumbled * 10, 1.4)
	get_tree().call_group(&"player_cameras", &"shake_from", to_global(center), 0.5 + minf(pieces * 0.05, 0.5))
	collapsed.emit(to_global(center), pieces)
	# то, что осталось висеть над опустевшим, проверяем ещё раз
	_check_support(emptied)


## Мелочь и пыль: частицы без коллизий.
func _crumbs(center: Vector3, amount: int, spread: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var p := CPUParticles3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.06, 0.04, 0.05)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.16, 0.12)
	mat.roughness = 1.0
	mesh.material = mat
	p.mesh = mesh
	p.amount = mini(amount, 160)
	p.one_shot = true
	p.explosiveness = 0.7
	p.lifetime = 1.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(spread, 0.3, spread)
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 1.8
	p.gravity = Vector3(0.0, -9.0, 0.0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.8
	p.position = center + Vector3.UP * 0.3
	add_child(p)
	p.emitting = true
	get_tree().create_timer(2.5).timeout.connect(p.queue_free)


# --- засыпание -------------------------------------------------------------------

func _update_resting(delta: float) -> void:
	var baked: bool = false
	for i: int in range(awake.size() - 1, -1, -1):
		var item: Item = awake[i]
		if not is_instance_valid(item):
			awake.remove_at(i)
			continue
		var id: int = item.get_instance_id()
		# в руках у игрока тело не засыпает (PlayerGrab выключает can_sleep)
		var still: bool = item.can_sleep and item.linear_velocity.length() < config.rest_speed \
				and item.angular_velocity.length() < config.rest_speed * 4.0
		if not still:
			_rest_time[id] = 0.0
			continue
		_rest_time[id] = _rest_time.get(id, 0.0) + delta
		if _rest_time[id] < config.rest_time:
			continue
		var c: Vector3i = field.cell_of(item.position + item.basis.y * config.cell_size.y * 0.5)
		if field.is_solid(c + Vector3i.DOWN) and field.place_junk(c, item.get_meta(&"junk_kind"), item.transform):
			_mark_dirty(c)
			_rest_time.erase(id)
			awake.remove_at(i)
			item.queue_free()
			baked = true
		else:
			_rest_time[id] = -3.0   # лежит неудобно (на вещи, вне кучи): попробуем позже
	if baked:
		_flush_dirty()
