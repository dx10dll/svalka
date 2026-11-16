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
var _columns := Vector2i.ZERO
var _layers: int = 0
## Какие столбцы чанков построены подробно
var _loaded: Dictionary[Vector2i, bool] = {}
var _skin: Dictionary[Vector2i, MeshInstance3D] = {}
var _queue: Array[Vector2i] = []
var _stream_timer: float = 0.0
var _debug_mesh: MeshInstance3D
var _debug_timer: float = 0.0


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
	_columns = Vector2i(int(ceil(float(field.size.x) / config.chunk_cells.x)),
			int(ceil(float(field.size.z) / config.chunk_cells.z)))
	_layers = int(ceil(float(field.size.y) / config.chunk_cells.y))
	if config.stream_radius <= 0.0:
		for cz: int in _columns.y:
			for cx: int in _columns.x:
				_load_column(Vector2i(cx, cz))
	else:
		_build_skin()
	Game.debug_flag_changed.connect(func(_flag: StringName, _on: bool) -> void: _debug_timer = 0.0)


# --- подгрузка -------------------------------------------------------------------
# Большая гора целиком не строится: подробные чанки (куски и коллизии) есть только
# рядом с игроками, остальное показано грубой «шкурой» по высотам столбиков.

## Сразу построить всё в радиусе от точки (перед появлением игрока).
func prime(point: Vector3, radius: float) -> void:
	for col: Vector2i in _columns_near(to_local(point), radius):
		_load_column(col)


func _column_center(col: Vector2i) -> Vector3:
	var cs: Vector3 = config.cell_size
	var cc: Vector3i = config.chunk_cells
	return field.origin + Vector3((col.x + 0.5) * cc.x * cs.x, 0.0, (col.y + 0.5) * cc.z * cs.z)


func _columns_near(point: Vector3, radius: float) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var step: Vector2 = Vector2(config.chunk_cells.x * config.cell_size.x, config.chunk_cells.z * config.cell_size.z)
	var lo := Vector2i(int(floor((point.x - radius - field.origin.x) / step.x)), int(floor((point.z - radius - field.origin.z) / step.y)))
	var hi := Vector2i(int(floor((point.x + radius - field.origin.x) / step.x)), int(floor((point.z + radius - field.origin.z) / step.y)))
	for cz: int in range(maxi(lo.y, 0), mini(hi.y, _columns.y - 1) + 1):
		for cx: int in range(maxi(lo.x, 0), mini(hi.x, _columns.x - 1) + 1):
			var col := Vector2i(cx, cz)
			var c: Vector3 = _column_center(col)
			if Vector2(c.x - point.x, c.z - point.z).length() <= radius and not _loaded.has(col):
				out.append(col)
	return out


func _load_column(col: Vector2i) -> void:
	_loaded[col] = true
	for cy: int in _layers:
		_rebuild(Vector3i(col.x, cy, col.y))
	if _skin.has(col):
		_skin[col].visible = false


func _unload_column(col: Vector2i) -> void:
	_loaded.erase(col)
	for cy: int in _layers:
		var key := Vector3i(col.x, cy, col.y)
		var chunk: DumpChunk = _chunks.get(key)
		if chunk != null:
			chunk.body.queue_free()
			_chunks.erase(key)
	if _skin.has(col):
		_skin[col].visible = true


func _viewers() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		out.append(to_local((node as Node3D).global_position))
	if out.is_empty():
		var cam: Camera3D = get_viewport().get_camera_3d()
		if cam != null:
			out.append(to_local(cam.global_position))
	return out


func _stream(delta: float) -> void:
	_stream_timer -= delta
	if _stream_timer <= 0.0:
		_stream_timer = 0.3
		var viewers: Array[Vector3] = _viewers()
		_queue.clear()
		var seen: Dictionary[Vector2i, float] = {}
		for v: Vector3 in viewers:
			for col: Vector2i in _columns_near(v, config.stream_radius):
				var c: Vector3 = _column_center(col)
				var d: float = Vector2(c.x - v.x, c.z - v.z).length()
				seen[col] = minf(seen.get(col, INF), d)
		_queue.assign(seen.keys())
		_queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return seen[a] > seen[b])  # ближние в конце
		# слишком далёкое убираем
		for col: Vector2i in _loaded.keys():
			var c: Vector3 = _column_center(col)
			var nearest: float = INF
			for v: Vector3 in viewers:
				nearest = minf(nearest, Vector2(c.x - v.x, c.z - v.z).length())
			if nearest > config.stream_radius + 10.0:
				_unload_column(col)
	var deadline: int = Time.get_ticks_usec() + int(config.stream_budget_ms * 1000.0)
	while not _queue.is_empty() and Time.get_ticks_usec() < deadline:
		var col: Vector2i = _queue.pop_back()
		if not _loaded.has(col):
			_load_column(col)


## Дальний вид: по плитке на столбец чанков, ступеньки по высотам столбиков, цвет по вершинам.
func _build_skin() -> void:
	var cs: Vector3 = config.cell_size
	var cc: Vector3i = config.chunk_cells
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	var tints: Array[Color] = [Color(0.09, 0.085, 0.08), Color(0.16, 0.14, 0.12), Color(0.08, 0.1, 0.17),
			Color(0.42, 0.4, 0.36), Color(0.3, 0.21, 0.13), Color(0.13, 0.12, 0.1), Color(0.2, 0.18, 0.15)]
	for cz: int in _columns.y:
		for cx: int in _columns.x:
			var verts := PackedVector3Array()
			var normals := PackedVector3Array()
			var colors := PackedColorArray()
			for z: int in range(cz * cc.z, mini((cz + 1) * cc.z, field.size.z)):
				for x: int in range(cx * cc.x, mini((cx + 1) * cc.x, field.size.x)):
					var h: int = field.heights[z * field.size.x + x]
					if h == 0:
						continue
					var base: Vector3 = field.origin + Vector3(x * cs.x, 0.0, z * cs.z)
					var top: float = h * cs.y
					var tint: Color = tints[int(field.hash01(x, h, z, 31) * tints.size()) % tints.size()]
					_quad(verts, normals, colors, base + Vector3(0, top, 0), Vector3(0, 0, cs.z), Vector3(cs.x, 0, 0), tint)
					# стенки к более низким соседям
					for side: Array in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
						var nx: int = x + side[0]
						var nz: int = z + side[1]
						var nh: int = 0
						if nx >= 0 and nz >= 0 and nx < field.size.x and nz < field.size.z:
							nh = field.heights[nz * field.size.x + nx]
						if nh >= h:
							continue
						var drop := Vector3(0, (nh - h) * cs.y, 0)
						var dark: Color = tint * 0.7
						match side:
							[-1, 0]: _quad(verts, normals, colors, base + Vector3(0, top, 0), drop, Vector3(0, 0, cs.z), dark)
							[1, 0]: _quad(verts, normals, colors, base + Vector3(cs.x, top, 0), Vector3(0, 0, cs.z), drop, dark)
							[0, -1]: _quad(verts, normals, colors, base + Vector3(0, top, 0), Vector3(cs.x, 0, 0), drop, dark)
							[0, 1]: _quad(verts, normals, colors, base + Vector3(0, top, cs.z), drop, Vector3(cs.x, 0, 0), dark)
			if verts.is_empty():
				continue
			var arrays: Array = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = verts
			arrays[Mesh.ARRAY_NORMAL] = normals
			arrays[Mesh.ARRAY_COLOR] = colors
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.material_override = mat
			add_child(mi)
			_skin[Vector2i(cx, cz)] = mi


## Четырёхугольник из точки o со сторонами a и b (нормаль a × b), двумя треугольниками.
func _quad(verts: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray,
		o: Vector3, a: Vector3, b: Vector3, color: Color) -> void:
	var n: Vector3 = a.cross(b).normalized()
	for p: Vector3 in [o, o + a, o + a + b, o, o + a + b, o + b]:
		verts.append(p)
		normals.append(n)
		colors.append(color)


## Отладка (F1 «показать чанки и опоры»): рамки построенных чанков и куски, которые вот-вот поедут.
func _update_debug(delta: float) -> void:
	var on: bool = Game.debug_flag(&"show_chunks")
	if _debug_mesh == null:
		if not on:
			return
		_debug_mesh = MeshInstance3D.new()
		_debug_mesh.mesh = ImmediateMesh.new()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		_debug_mesh.material_override = mat
		add_child(_debug_mesh)
	_debug_mesh.visible = on
	_debug_timer -= delta
	if not on or _debug_timer > 0.0:
		return
	_debug_timer = 0.25
	var im: ImmediateMesh = _debug_mesh.mesh
	im.clear_surfaces()
	var cs: Vector3 = config.cell_size
	var size: Vector3 = Vector3(config.chunk_cells) * cs
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var any: bool = false
	for key: Vector3i in _chunks:
		_wire_box(im, field.origin + Vector3(key) * size, size, Color(0.3, 1.0, 0.4))
		any = true
	for p: Dictionary in _pending:
		for c: Vector3i in p["junk"]:
			_wire_box(im, field.cell_base(c) - Vector3(cs.x, 0, cs.z) * 0.5, cs, Color(1.0, 0.2, 0.15))
			any = true
	if not any:
		_wire_box(im, Vector3.ZERO, Vector3.ONE * 0.01, Color.BLACK)
	im.surface_end()


func _wire_box(im: ImmediateMesh, o: Vector3, s: Vector3, color: Color) -> void:
	var corners: Array[Vector3] = []
	for i: int in 8:
		corners.append(o + Vector3(s.x * (i & 1), s.y * ((i >> 1) & 1), s.z * ((i >> 2) & 1)))
	for edge: Array in [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]:
		im.surface_set_color(color)
		im.surface_add_vertex(corners[edge[0]])
		im.surface_set_color(color)
		im.surface_add_vertex(corners[edge[1]])


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
		if _loaded.has(Vector2i(key.x, key.z)):   # непостроенное возьмёт изменения, когда подгрузится
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


func _process(delta: float) -> void:
	if config.stream_radius > 0.0:
		_stream(delta)
	_update_debug(delta)


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
	var spawned: Array[Item] = []
	for w: Array in waking:
		if awake.size() >= config.max_awake:
			crumbled += 1   # лимит живых тел: остальное просто рассыпается в труху
			continue
		var body: Item = _spawn_junk(w[0], w[1])
		# куски выталкивает наружу и вниз по склону: завал едет на того, кто копал
		body.linear_velocity = outward * _rng.randf_range(config.slide_speed * 0.5, config.slide_speed) \
				+ Vector3(_rng.randf_range(-0.6, 0.6), _rng.randf_range(0.3, 1.6), _rng.randf_range(-0.6, 0.6))
		body.angular_velocity = Vector3(_rng.randf_range(-1.5, 1.5), _rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.5, 1.5))
		spawned.append(body)
	_bury_players(center, spawned)
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


## Завал накрыл игрока: несколько кусков ложатся на него и замирают,
## пока их не снимут товарищи или он сам не выберется.
func _bury_players(center: Vector3, spawned: Array[Item]) -> void:
	if spawned.size() < config.bury_min_pieces:
		return
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var player: PlayerController = node as PlayerController
		if player == null or player.mode != PlayerController.Mode.NORMAL:
			continue
		var p: Vector3 = to_local(player.global_position)
		if Vector2(p.x - center.x, p.z - center.z).length() > config.bury_radius or p.y > center.y + 0.3:
			continue
		spawned.sort_custom(func(a: Item, b: Item) -> bool:
			return a.position.distance_squared_to(p) < b.position.distance_squared_to(p))
		var pieces: Array[RigidBody3D] = []
		var n: int = mini(config.bury_pieces, spawned.size())
		for i: int in n:
			var piece: Item = spawned[i]
			# кольцом вокруг груди и горкой над головой
			var angle: float = TAU * i / float(n) + _rng.randf_range(-0.3, 0.3)
			var ring: float = 0.42 if i < 4 else 0.15
			var lift: float = _rng.randf_range(0.35, 0.6) if i < 4 else 0.95 + 0.25 * (i - 4)
			piece.position = p + Vector3(cos(angle) * ring, lift, sin(angle) * ring)
			piece.rotation = Vector3(_rng.randf_range(-0.6, 0.6), _rng.randf_range(0.0, TAU), _rng.randf_range(-0.6, 0.6))
			piece.linear_velocity = Vector3.ZERO
			piece.angular_velocity = Vector3.ZERO
			piece.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
			piece.freeze = true
			piece.set_meta(&"burying", true)
			piece.add_collision_exception_with(player)
			piece.reset_physics_interpolation()
			pieces.append(piece)
		player.bury(pieces)
		return   # одним завалом засыпает одного: куски второй раз не делим


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
		if item.has_meta(&"burying"):
			continue   # лежит на засыпанном игроке
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
