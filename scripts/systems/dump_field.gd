class_name DumpField
extends RefCounted
## Куча мусора как решётка ячеек. Чистая логика без узлов: генерация по сиду,
## что где лежит, что видно снаружи, что упадёт, если убрать опору.
##
## Каждая ячейка либо пуста, либо в ней кусок мусора, либо часть ценной вещи
## («место»: вещь может занимать несколько ячеек). Одинаковый сид даёт одинаковую
## кучу на любой машине: внутри только целочисленный хеш и простая арифметика,
## поэтому по сети достаточно передать сид и список изменений.

const EMPTY: int = 0

var config: DumpConfig
var seed: int
## Размер решётки в ячейках
var size: Vector3i
## Мир: угол решётки (минимум по x и z, низ)
var origin: Vector3
## Содержимое: 0 — пусто, k > 0 — мусор config.junk[k - 1], k < 0 — место sites[-k - 1]
var cells: PackedInt32Array
## Сколько ячеек было в каждом столбике при генерации (для дальнего вида), индекс z * size.x + x
var heights: PackedInt32Array
## Места ценных вещей: {"item": индекс в config.loot, "anchor": Vector3i, "cells": Array[int], "taken": bool}
var sites: Array[Dictionary] = []
## Куски, которые упали и заснули не по решётке: индекс ячейки -> их точное положение
var custom_transforms: Dictionary[int, Transform3D] = {}


func _init(cfg: DumpConfig, dump_seed: int) -> void:
	config = cfg
	seed = dump_seed
	var cs: Vector3 = cfg.cell_size
	var half: float = cfg.radius + cfg.margin
	size = Vector3i(int(ceil(half * 2.0 / cs.x)), int(ceil(cfg.height * 1.25 / cs.y)) + 4, int(ceil(half * 2.0 / cs.z)))
	origin = Vector3(-size.x * cs.x * 0.5, 0.0, -size.z * cs.z * 0.5)
	cells.resize(size.x * size.y * size.z)
	_generate()


# --- хеш и шум ---------------------------------------------------------------

## Целочисленный хеш трёх координат и «соли», 0..1.
func hash01(x: int, y: int, z: int, salt: int) -> float:
	var h: int = (x * 73856093) ^ (y * 19349663) ^ (z * 83492791) ^ (salt * 2654435761) ^ (seed * 40503)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFFFF) / 16777216.0


func _value_noise(x: float, z: float, salt: int) -> float:
	var xi: int = int(floor(x))
	var zi: int = int(floor(z))
	var fx: float = x - xi
	var fz: float = z - zi
	fx = fx * fx * (3.0 - 2.0 * fx)
	fz = fz * fz * (3.0 - 2.0 * fz)
	var a: float = lerpf(hash01(xi, 0, zi, salt), hash01(xi + 1, 0, zi, salt), fx)
	var b: float = lerpf(hash01(xi, 0, zi + 1, salt), hash01(xi + 1, 0, zi + 1, salt), fx)
	return lerpf(a, b, fz)


## Высота кучи над точкой (x, z) мира, м.
func height_at(x: float, z: float) -> float:
	var r: float = sqrt(x * x + z * z) / config.radius
	if r >= 1.0:
		return 0.0
	var dome: float = (1.0 - r * r) * (1.0 - r * r * 0.35)   # пологая вершина, крутые бока
	var lumps: float = _value_noise(x / config.lump_size, z / config.lump_size, 11) \
			+ 0.5 * _value_noise(x / config.lump_size * 2.3, z / config.lump_size * 2.3, 12)
	var edge: float = clampf((1.0 - r) * 4.0, 0.0, 1.0)       # к краю бугры сходят на нет
	return maxf(config.height * dome * (1.0 + config.lump_strength * (lumps / 1.5 - 0.5) * 2.0 * edge), 0.0)


# --- адресация ----------------------------------------------------------------

func in_bounds(c: Vector3i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.z >= 0 and c.x < size.x and c.y < size.y and c.z < size.z


func index_of(c: Vector3i) -> int:
	return (c.y * size.z + c.z) * size.x + c.x


func coords_of(index: int) -> Vector3i:
	var x: int = index % size.x
	var rest: int = index / size.x
	return Vector3i(x, rest / size.z, rest % size.z)


## Содержимое ячейки (за границей — пусто).
func at(c: Vector3i) -> int:
	return cells[index_of(c)] if in_bounds(c) else EMPTY


## Занята ли ячейка. Всё, что ниже нуля, — земля, она «занята».
func is_solid(c: Vector3i) -> bool:
	if c.y < 0:
		return true
	return in_bounds(c) and cells[index_of(c)] != EMPTY


## Низ ячейки по центру, мир.
func cell_base(c: Vector3i) -> Vector3:
	var cs: Vector3 = config.cell_size
	return origin + Vector3((c.x + 0.5) * cs.x, c.y * cs.y, (c.z + 0.5) * cs.z)


## В какой ячейке лежит точка мира.
func cell_of(point: Vector3) -> Vector3i:
	var p: Vector3 = (point - origin) / config.cell_size
	return Vector3i(int(floor(p.x)), int(floor(p.y)), int(floor(p.z)))


## Как лежит кусок мусора в ячейке: сдвиг, поворот и размер слегка случайны,
## чтобы решётка не читалась глазом.
func piece_transform(c: Vector3i) -> Transform3D:
	var i: int = index_of(c)
	if custom_transforms.has(i):
		return custom_transforms[i]
	var yaw: float = floor(hash01(c.x, c.y, c.z, 21) * 4.0) * PI * 0.5 + (hash01(c.x, c.y, c.z, 22) - 0.5) * 0.5
	var tilt_x: float = (hash01(c.x, c.y, c.z, 23) - 0.5) * 0.22
	var tilt_z: float = (hash01(c.x, c.y, c.z, 24) - 0.5) * 0.22
	var scale: float = 1.04 + hash01(c.x, c.y, c.z, 25) * 0.14
	var basis: Basis = Basis.from_euler(Vector3(tilt_x, yaw, tilt_z)).scaled(Vector3.ONE * scale)
	var jitter := Vector3(hash01(c.x, c.y, c.z, 26) - 0.5, 0.0, hash01(c.x, c.y, c.z, 27) - 0.5) * 0.14
	return Transform3D(basis, cell_base(c) + jitter - Vector3.UP * 0.03)


## Как лежит ценная вещь на своём месте.
func site_transform(site_index: int) -> Transform3D:
	var site: Dictionary = sites[site_index]
	var item: ItemData = config.loot[site["item"]]
	var a: Vector3i = site["anchor"]
	var cs: Vector3 = config.cell_size
	var block: Vector3 = Vector3(item.dump_cells) * cs
	var center: Vector3 = origin + Vector3(a.x * cs.x, a.y * cs.y, a.z * cs.z) + Vector3(block.x * 0.5, 0.0, block.z * 0.5)
	var r: Vector3 = item.dump_rotation_deg * (PI / 180.0)
	var basis: Basis = Basis.from_euler(r)
	# модель стоит на своём низу; положенная на спину должна лечь на дно блока
	var lift: float = 0.02
	if absf(item.dump_rotation_deg.x) > 45.0:
		lift = block.y * 0.5 - 0.06
		var half: float = block.z * 0.5 - 0.08
		center += Vector3(0.0, 0.0, half if item.dump_rotation_deg.x < 0.0 else -half)
	return Transform3D(basis, center + Vector3.UP * lift)


# --- генерация -----------------------------------------------------------------

## Выбор по долям трёх слоёв: у поверхности, в глубине и в нижнем «советском» слое.
## depth_k — глубина 0..1, low_k — близость к земле 0..1 (нижний слой только в глубине).
func _pick(weights_top: PackedFloat32Array, weights_deep: PackedFloat32Array, weights_bottom: PackedFloat32Array,
		depth_k: float, low_k: float, roll: float) -> int:
	var n: int = weights_top.size()
	var bottom_k: float = depth_k * low_k if weights_bottom.size() == n else 0.0
	var total: float = 0.0
	for i: int in n:
		var w: float = lerpf(weights_top[i], weights_deep[i], depth_k)
		total += lerpf(w, weights_bottom[i], bottom_k) if bottom_k > 0.0 else w
	var acc: float = 0.0
	for i: int in n:
		var w: float = lerpf(weights_top[i], weights_deep[i], depth_k)
		acc += lerpf(w, weights_bottom[i], bottom_k) if bottom_k > 0.0 else w
		if roll * total < acc:
			return i
	return n - 1


func _low_k(height_above_ground: float) -> float:
	if config.bottom_height <= 0.0:
		return 0.0
	return clampf(1.0 - height_above_ground / config.bottom_height, 0.0, 1.0)


func _generate() -> void:
	var cs: Vector3 = config.cell_size
	# 1. мусор: всё, что под поверхностью
	var depth: PackedFloat32Array = []
	depth.resize(cells.size())
	heights.resize(size.x * size.z)
	for z: int in size.z:
		for x: int in size.x:
			var wx: float = origin.x + (x + 0.5) * cs.x
			var wz: float = origin.z + (z + 0.5) * cs.z
			var h: float = height_at(wx, wz)
			var filled: int = 0
			for y: int in size.y:
				var mid: float = (y + 0.5) * cs.y
				if mid >= h:
					break
				var c := Vector3i(x, y, z)
				var k: float = clampf((h - mid) / config.deep_depth, 0.0, 1.0)
				var i: int = index_of(c)
				depth[i] = k
				cells[i] = _pick(config.junk_weight_top, config.junk_weight_deep, config.junk_weight_bottom,
						k, _low_k(mid), hash01(x, y, z, 1)) + 1
				filled += 1
			heights[z * size.x + x] = filled
	# 2. ценные вещи: занимают блок ячеек вместо мусора
	if config.loot.is_empty():
		return
	for y: int in size.y:
		for z: int in size.z:
			for x: int in size.x:
				var i: int = index_of(Vector3i(x, y, z))
				if cells[i] <= 0:
					continue
				var k: float = depth[i]
				if hash01(x, y, z, 2) >= lerpf(config.loot_chance_top, config.loot_chance_deep, k):
					continue
				var item_index: int = _pick(config.loot_weight_top, config.loot_weight_deep, config.loot_weight_bottom,
						k, _low_k((y + 0.5) * cs.y), hash01(x, y, z, 3))
				var block: Vector3i = config.loot[item_index].dump_cells
				var claimed: Array[int] = []
				var fits: bool = true
				for dy: int in block.y:
					for dz: int in block.z:
						for dx: int in block.x:
							var c := Vector3i(x + dx, y + dy, z + dz)
							if not in_bounds(c) or cells[index_of(c)] <= 0:
								fits = false
							else:
								claimed.append(index_of(c))
				if not fits:
					continue
				sites.append({"item": item_index, "anchor": Vector3i(x, y, z), "cells": claimed, "taken": false})
				for ci: int in claimed:
					cells[ci] = -sites.size()


# --- запросы и изменения ---------------------------------------------------------

## Видна ли ячейка снаружи (есть пустой сосед). Земля снизу не в счёт.
func is_exposed(c: Vector3i) -> bool:
	return not (is_solid(c + Vector3i.UP) and is_solid(c + Vector3i.DOWN) and is_solid(c + Vector3i.LEFT)
			and is_solid(c + Vector3i.RIGHT) and is_solid(c + Vector3i.FORWARD) and is_solid(c + Vector3i.BACK))


func is_site_exposed(site_index: int) -> bool:
	for ci: int in sites[site_index]["cells"]:
		if is_exposed(coords_of(ci)):
			return true
	return false


## Убрать кусок мусора из ячейки. Возвращает индекс вида мусора или -1.
func remove_junk(c: Vector3i) -> int:
	if not in_bounds(c):
		return -1
	var i: int = index_of(c)
	var v: int = cells[i]
	if v <= 0:
		return -1
	cells[i] = EMPTY
	custom_transforms.erase(i)
	return v - 1


## Забрать ценную вещь: её ячейки пустеют. Возвращает освободившиеся ячейки.
func take_site(site_index: int) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var site: Dictionary = sites[site_index]
	if site["taken"]:
		return out
	site["taken"] = true
	for ci: int in site["cells"]:
		cells[ci] = EMPTY
		out.append(coords_of(ci))
	return out


## Положить кусок мусора в пустую ячейку (тело заснуло). transform — как оно легло.
func place_junk(c: Vector3i, junk_index: int, transform: Transform3D) -> bool:
	if not in_bounds(c) or cells[index_of(c)] != EMPTY:
		return false
	cells[index_of(c)] = junk_index + 1
	custom_transforms[index_of(c)] = transform
	return true


## Что потеряло опору после того, как опустели ячейки emptied.
## Правило простое и понятное игроку: кусок держится, пока под ним что-то есть.
## Вещь на несколько ячеек держится, пока опора есть хотя бы под половиной её низа.
## Возвращает {"junk": Array[Vector3i], "sites": Array[int]} — что должно упасть.
func find_unsupported(emptied: Array[Vector3i]) -> Dictionary:
	var junk_out: Array[Vector3i] = []
	var sites_out: Array[int] = []
	var falling: Dictionary[int, bool] = {}
	var queue: Array[Vector3i] = []
	for c: Vector3i in emptied:
		queue.append(c + Vector3i.UP)
	while not queue.is_empty():
		var c: Vector3i = queue.pop_back()
		if not in_bounds(c):
			continue
		var i: int = index_of(c)
		var v: int = cells[i]
		if v == EMPTY or falling.has(i):
			continue
		if v > 0:
			falling[i] = true
			junk_out.append(c)
			queue.append(c + Vector3i.UP)
			continue
		var site_index: int = -v - 1
		if sites_out.has(site_index):
			continue
		var site: Dictionary = sites[site_index]
		var bottom_y: int = (site["anchor"] as Vector3i).y
		var bottom: int = 0
		var held: int = 0
		for ci: int in site["cells"]:
			var sc: Vector3i = coords_of(ci)
			if sc.y != bottom_y:
				continue
			bottom += 1
			var below: Vector3i = sc + Vector3i.DOWN
			if is_solid(below) and not (in_bounds(below) and falling.has(index_of(below))):
				held += 1
		if held * 2 >= bottom:
			continue
		sites_out.append(site_index)
		for ci: int in site["cells"]:
			falling[ci] = true
			queue.append(coords_of(ci) + Vector3i.UP)
	# склон: рядом с ямой не устоит отвесная стенка выше cliff_cells ячеек —
	# её верхний кусок съезжает. Так подкопанный склон оползает волна за волной.
	var sources: Array[Vector3i] = emptied.duplicate()
	sources.append_array(junk_out)
	for e: Vector3i in sources:
		for d: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
			for y: int in range(e.y + config.cliff_cells - 1, mini(e.y + config.cliff_cells + 8, size.y)):
				var c := Vector3i(e.x - d.x, y, e.z - d.z)
				if not in_bounds(c):
					break
				var i: int = index_of(c)
				if cells[i] <= 0 or falling.has(i):
					continue
				var up: Vector3i = c + Vector3i.UP
				if in_bounds(up) and cells[index_of(up)] != EMPTY and not falling.has(index_of(up)):
					continue   # съезжает только верхний кусок стенки
				if _is_cliff(c, d, falling):
					falling[i] = true
					junk_out.append(c)
	return {"junk": junk_out, "sites": sites_out}


## Обрыв ли рядом с ячейкой c в сторону d: пусто на cliff_cells ячеек вниз.
func _is_cliff(c: Vector3i, d: Vector3i, falling: Dictionary[int, bool]) -> bool:
	for k: int in config.cliff_cells:
		var n: Vector3i = c + d + Vector3i.DOWN * k
		if n.y < 0 or not in_bounds(n):
			return false
		if cells[index_of(n)] != EMPTY and not falling.has(index_of(n)):
			return false
	return true


## Сколько ячеек занято (для тестов и отладки).
func solid_count() -> int:
	var n: int = 0
	for v: int in cells:
		if v != EMPTY:
			n += 1
	return n


## Отпечаток кучи: одинаковый сид обязан дать одинаковое число.
func checksum() -> int:
	var h: int = 1469598103
	for v: int in cells:
		h = ((h ^ (v + 4096)) * 16777619) & 0x7FFFFFFFFFFF
	return h
