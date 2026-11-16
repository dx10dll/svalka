class_name ScrapYard
extends Node3D
## Приёмка: весы-платформа, вагончик приёмщика и доска с нормой.
## Вещи таскают на весы руками. E у окошка — сдать всё, что лежит на весах;
## E у колокола — закончить ночь. Мусор приёмщик не берёт.

signal sold(total: int, count: int)
signal finish_requested

const BOOTH_MODEL: String = "res://assets/models/props/guard_booth.glb"
const PLATFORM := Vector3(3.4, 0.14, 3.4)

## Забег, в который идут деньги
var run: RunState

var _area: Area3D
var _board: Label3D
var _refresh: float = 0.0
var _speech: Label3D
var _speech_time: float = 0.0
var _lamp: OmniLight3D
var _flash: float = 0.0


## Окошко и колокол: то, на что игрок жмёт E.
class Desk extends StaticBody3D:
	var yard: ScrapYard
	var action: StringName

	func interaction_at(_point: Vector3) -> Dictionary:
		return yard.hint_for(action)

	func interact(_player: PlayerController, what: StringName) -> void:
		yard.use(what)


func build(state: RunState) -> void:
	run = state
	# весы: низкая стальная платформа с жёлтой каймой
	var scale := _box(PLATFORM, Vector3(0.0, PLATFORM.y * 0.5, 0.0), Color(0.32, 0.33, 0.35), 0.5)
	scale.name = "Scale"
	_box(Vector3(PLATFORM.x + 0.16, 0.06, PLATFORM.z + 0.16), Vector3(0.0, 0.03, 0.0), Color(0.75, 0.6, 0.1), 0.8)
	_area = Area3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(PLATFORM.x, 2.4, PLATFORM.z)
	shape.shape = box
	_area.add_child(shape)
	_area.position = Vector3(0.0, PLATFORM.y + 1.2, 0.0)
	_area.collision_mask = 0xFFFF
	add_child(_area)
	# вагончик приёмщика сбоку от весов, окно смотрит на весы
	var booth: Node3D = (load(BOOTH_MODEL) as PackedScene).instantiate()
	booth.position = Vector3(-4.2, 0.0, 0.0)
	booth.rotation.y = PI * 0.5
	add_child(booth)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.82, 0.55)
	light.light_energy = 3.0
	light.omni_range = 9.0
	light.position = Vector3(-2.4, 2.6, 0.0)
	add_child(light)
	_lamp = light
	# реплики приёмщика: субтитр у окошка
	_speech = Label3D.new()
	_speech.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_speech.pixel_size = 0.004
	_speech.font_size = 48
	_speech.outline_size = 12
	_speech.no_depth_test = true
	_speech.modulate = Color(0.9, 0.95, 1.0)
	_speech.position = Vector3(-2.6, 2.2, 0.6)
	_speech.visible = false
	add_child(_speech)
	# окошко — сдать, колокол — закончить ночь
	_desk(&"sell", Vector3(0.5, 0.5, 0.9), Vector3(-2.75, 1.25, 0.6), Color(0.2, 0.45, 0.22))
	_desk(&"finish", Vector3(0.35, 0.35, 0.35), Vector3(-2.75, 1.25, -0.9), Color(0.7, 0.55, 0.12))
	_board = Label3D.new()
	_board.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_board.pixel_size = 0.006
	_board.font_size = 64
	_board.outline_size = 14
	_board.modulate = Color(1.0, 0.9, 0.7)
	_board.position = Vector3(-3.0, 3.5, 0.0)
	add_child(_board)
	_update_board()


func _desk(action: StringName, size: Vector3, at: Vector3, color: Color) -> void:
	var desk := Desk.new()
	desk.yard = self
	desk.action = action
	desk.name = "Desk_" + action
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	desk.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.6
	mesh.material_override = mat
	desk.add_child(mesh)
	desk.position = at
	add_child(desk)


func _box(size: Vector3, at: Vector3, color: Color, roughness: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = 0.4
	mesh.material_override = mat
	body.add_child(mesh)
	body.position = at
	add_child(body)
	return body


## Вещи, лежащие на весах (не в руках и не мусор — тот считается отдельно).
func items_on_scale() -> Array[Item]:
	var out: Array[Item] = []
	for body: Node3D in _area.get_overlapping_bodies():
		var item: Item = body as Item
		if item != null and not item.freeze:
			out.append(item)
	return out


## Сколько сейчас на весах: {"count", "mass", "value", "trash"}.
func weigh() -> Dictionary:
	var result: Dictionary = {"count": 0, "mass": 0.0, "value": 0, "trash": 0}
	for item: Item in items_on_scale():
		if item.data.is_trash():
			result["trash"] += 1
			continue
		result["count"] += 1
		result["mass"] += item.mass
		result["value"] += item.value()
	return result


func hint_for(action: StringName) -> Dictionary:
	if action == &"sell":
		return {"hint": "HINT_YARD_SELL", "action": action}
	return {"hint": "HINT_YARD_FINISH" if run.quota_met() else "HINT_YARD_FINISH_EARLY", "action": action}


func use(action: StringName) -> void:
	if action == &"sell":
		sell()
	else:
		finish_requested.emit()


## Сдать всё с весов. Возвращает выручку.
func sell() -> int:
	var total: int = 0
	var count: int = 0
	for item: Item in items_on_scale():
		if item.data.is_trash():
			continue       # мусор остаётся лежать: не берём
		var value: int = item.value()
		total += value
		count += 1
		WorldPopup.spawn(get_parent(), item.global_position + Vector3.UP * 0.5, "+ " + Fmt.rub(value), Color(0.55, 1.0, 0.5))
		item.queue_free()
	if count == 0:
		Audio.play_at(&"deny", global_position + Vector3.UP, -6.0)
		say(tr("YARD_LINE_TRASH") if weigh()["trash"] > 0 else tr("YARD_LINE_EMPTY"))
		return 0
	var was_met: bool = run.quota_met()
	run.sell(total)
	Audio.play_at(&"cash", global_position + Vector3.UP, 0.0)
	if run.quota_met() and not was_met:
		# норма закрыта: зелёная вспышка и второй звон повыше
		_flash = 1.0
		Audio.play_at(&"cash", global_position + Vector3.UP * 2.0, 4.0, 1.5)
		say(tr("YARD_LINE_QUOTA"))
	else:
		say(tr("YARD_LINE_%d" % (1 + randi() % 5)))
	_update_board()
	sold.emit(total, count)
	return total


## Реплика приёмщика на несколько секунд.
func say(text: String) -> void:
	_speech.text = "«%s»" % text
	_speech.visible = true
	_speech_time = 4.0


func _process(delta: float) -> void:
	_speech_time -= delta
	if _speech_time <= 0.0:
		_speech.visible = false
	_flash = maxf(_flash - delta * 0.5, 0.0)
	_lamp.light_color = Color(1.0, 0.82, 0.55).lerp(Color(0.4, 1.0, 0.4), _flash)
	_lamp.light_energy = 3.0 + _flash * 14.0
	_refresh -= delta
	if _refresh <= 0.0 and run != null:
		_refresh = 0.25
		_update_board()


func _update_board() -> void:
	var w: Dictionary = weigh()
	var lines: PackedStringArray = [tr("YARD_TITLE")]
	if w["count"] > 0:
		lines.append(tr("YARD_ON_SCALE") % [w["count"], Fmt.kg(w["mass"]), Fmt.rub(w["value"])])
	elif w["trash"] > 0:
		lines.append(tr("YARD_NO_TRASH"))
	else:
		lines.append(tr("YARD_EMPTY"))
	lines.append(tr("YARD_QUOTA") % [Fmt.rub(run.earned), Fmt.rub(run.quota())])
	_board.text = "\n".join(lines)
	_board.modulate = Color(0.6, 1.0, 0.55) if run.quota_met() else Color(1.0, 0.9, 0.7)
