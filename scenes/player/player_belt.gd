class_name PlayerBelt
extends Node
## Пояс: три слота под инструменты и мелочь. Клавиши 1–3: в руках что-то есть —
## вешаем на пояс, руки пусты — снимаем и бросаем перед собой.
## Инструмент работает, пока висит на поясе (лопата копает, лом добавляет силы,
## фонарь светит ярче, металлоискатель пищит). Упавший с пояса инструмент — обычный
## предмет: его можно потерять в завале.

signal changed

const SLOTS: int = 3

## Предметы на поясе (вне дерева сцены, пока висят)
var slots: Array[Item] = [null, null, null]

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


## Клавиша слота (с 0): повесить то, что в руках, или снять на землю.
func use_slot(index: int) -> void:
	var held: Item = _player.grab.held as Item
	if held != null:
		if slots[index] == null and can_stow(held):
			_player.grab.release(false)
			stow(index, held)
	elif slots[index] != null and _player.grab.held == null:
		drop(index)


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


## Металлоискатель: чем ближе закопанная вещь, тем чаще писк.
func _physics_process(delta: float) -> void:
	if _player == null or not has_tool(&"metal_detector"):
		_loot_distance = INF
		return
	_scan_wait -= delta
	if _scan_wait <= 0.0:
		_scan_wait = 0.3
		_loot_distance = INF
		for dump: Dump in get_tree().get_nodes_in_group(&"dumps"):
			_loot_distance = minf(_loot_distance, dump.nearest_loot_distance(_player.global_position + Vector3.UP * 0.8, _feel.detector_range))
	_beep_wait -= delta
	if _loot_distance < _feel.detector_range and _beep_wait <= 0.0:
		var k: float = _loot_distance / _feel.detector_range
		_beep_wait = lerpf(_feel.detector_beep_near, _feel.detector_beep_far, k)
		Audio.play_at(&"beep", _player.global_position + Vector3.UP, -8.0, lerpf(1.5, 0.9, k))


## Расстояние до ближайшей закопанной вещи, м (INF — далеко или нет прибора).
func loot_distance() -> float:
	return _loot_distance
