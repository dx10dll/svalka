class_name PlayerBelt
extends Node
## Пояс: три слота под инструменты и мелочь, плюс «руки».
## Клавиша 1 — руки, 2–4 — слоты пояса: выбранное становится тем, что в руках.
## В руках лопата — копаем быстро; металлоискатель — пищит; лом — тянем сильнее;
## пустые руки — таскаем вещи. E по мелкой вещи — подобрать на пояс, G — выбросить
## выбранное. Налобный фонарь работает просто с пояса. Выброшенный инструмент —
## обычный предмет: его можно потерять в завале.

signal changed

const SLOTS: int = 3

## Предметы на поясе (вне дерева сцены, пока висят)
var slots: Array[Item] = [null, null, null]
## Что сейчас в руках: -1 — пустые руки, иначе номер слота
var active: int = -1

var _player: PlayerController
var _feel: PlayerFeel
var _beep_wait: float = 0.0
var _scan_wait: float = 0.0
var _loot_distance: float = INF


func setup(player: PlayerController) -> void:
	_player = player
	_feel = player.feel


func has_tool(tool: StringName) -> bool:
	for item: Item in slots:
		if item != null and item.data.tool == tool:
			return true
	return false


func free_slot() -> int:
	return slots.find(null)


## Выбрать, что в руках: -1 — руки, иначе слот. Пустой слот или повторное нажатие — руки.
func select(index: int) -> void:
	var next: int = index if index >= 0 and index < SLOTS and slots[index] != null and index != active else -1
	if next == active:
		return
	active = next
	if active >= 0:
		_player.grab.release(false)      # в руках теперь инструмент
	Audio.play_at(&"grab", _player.global_position + Vector3.UP, -10.0, 1.3 if active >= 0 else 1.0)
	changed.emit()


## Предмет, который сейчас в руках с пояса (null — пустые руки).
func active_item() -> Item:
	return slots[active] if active >= 0 else null


## Инструмент в руках ("" — руки пустые или в руках не инструмент).
func active_tool() -> StringName:
	var item: Item = active_item()
	return item.data.tool if item != null else &""


## Можно ли сейчас таскать вещи: пустыми руками или с ломом.
func can_grab() -> bool:
	return active < 0 or active_tool() == &"crowbar"


## E по вещи: подобрать на пояс в свободный слот.
func pickup(item: Item) -> bool:
	var slot: int = free_slot()
	if slot < 0 or not can_stow(item) or item.freeze:
		return false
	if _player.grab.held == item:
		_player.grab.release(false)
	stow(slot, item)
	return true


## G: выбросить то, что в руках с пояса.
func drop_active() -> Item:
	return drop(active) if active >= 0 else null


func can_stow(item: Item) -> bool:
	return item.mass <= _feel.belt_max_mass and not item.data.is_trash()


func stow(index: int, item: Item) -> void:
	if item.get_parent() != null:
		item.get_parent().remove_child(item)
	item.set_highlight(false)
	slots[index] = item
	Audio.play_at(&"grab", _player.global_position + Vector3.UP, -6.0, 0.8)
	changed.emit()


## Снять с пояса: предмет появляется перед игроком и падает.
func drop(index: int) -> Item:
	var item: Item = slots[index]
	if item == null:
		return null
	slots[index] = null
	if active == index:
		active = -1
	_player.get_parent().add_child(item)
	var ahead: Vector3 = Basis(Vector3.UP, _player.yaw) * Vector3(0.0, 0.0, -0.7)
	item.global_transform = Transform3D(Basis(Vector3.UP, _player.yaw), _player.global_position + ahead + Vector3.UP * 0.9)
	item.linear_velocity = _player.velocity
	item.angular_velocity = Vector3.ZERO
	item.sleeping = false
	item.reset_physics_interpolation()
	Audio.play_at(&"grab", item.global_position, -6.0, 1.2)
	changed.emit()
	return item


## Что на поясе, по слотам (id инструментов; обычные вещи между ночами не хранятся).
func ids() -> Array[String]:
	var out: Array[String] = []
	for item: Item in slots:
		out.append(String(item.data.id) if item != null and item.data.is_tool() else "")
	return out


## Собрать пояс по списку id (начало ночи, гараж).
func fill(tool_ids: Array[String]) -> void:
	active = -1
	for i: int in SLOTS:
		if slots[i] != null:
			slots[i].free()
			slots[i] = null
		if i < tool_ids.size() and not tool_ids[i].is_empty():
			var data: ItemData = ItemDb.tool(StringName(tool_ids[i]))
			if data != null:
				slots[i] = ItemDb.spawn(data, RandomNumberGenerator.new())
	changed.emit()


func _exit_tree() -> void:
	for item: Item in slots:
		if item != null and not item.is_inside_tree():
			item.queue_free()


## Металлоискатель в руках: чем ближе закопанная вещь, тем чаще и выше писк;
## вплотную — заливается трелью «нашёл».
func _physics_process(delta: float) -> void:
	if _player == null or active_tool() != &"metal_detector":
		_loot_distance = INF
		return
	_scan_wait -= delta
	if _scan_wait <= 0.0:
		_scan_wait = 0.25
		_loot_distance = INF
		for dump: Dump in get_tree().get_nodes_in_group(&"dumps"):
			_loot_distance = minf(_loot_distance, dump.nearest_loot_distance(_player.global_position + Vector3.UP * 0.8, _feel.detector_range))
	_beep_wait -= delta
	if _loot_distance >= _feel.detector_range or _beep_wait > 0.0:
		return
	if _loot_distance <= _feel.detector_found_range:
		_beep_wait = _feel.detector_found_repeat
		Audio.play_at(&"detector_found", _player.global_position + Vector3.UP, -3.0)
		return
	var k: float = signal_strength()
	_beep_wait = lerpf(_feel.detector_beep_far, _feel.detector_beep_near, k)
	Audio.play_at(&"beep", _player.global_position + Vector3.UP, lerpf(-14.0, -4.0, k), lerpf(0.75, 1.7, k))


## Сила сигнала 0..1 (0 — ничего рядом, 1 — стоим на находке).
func signal_strength() -> float:
	if _loot_distance >= _feel.detector_range:
		return 0.0
	return 1.0 - clampf((_loot_distance - _feel.detector_found_range) / (_feel.detector_range - _feel.detector_found_range), 0.0, 1.0)


## Расстояние до ближайшей закопанной вещи, м (INF — далеко или нет прибора).
func loot_distance() -> float:
	return _loot_distance
