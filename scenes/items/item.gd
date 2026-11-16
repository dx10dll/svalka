class_name Item
extends RigidBody3D
## Физический предмет свалки. Модель, коллизии и точки хвата берутся из .glb,
## числа — из ItemData. Хрупкие вещи теряют целость и цену от ударов.

## Любой заметный удар (для звука и эффектов): сила — изменение скорости, м/с
signal hit(impact: float)
## Хрупкая вещь пострадала: сколько рублей потеряно
signal damaged(loss: int)

## Удары слабее этого не считаются, м/с
const MIN_IMPACT: float = 1.2
const OUTLINE_MATERIAL: String = "res://assets/materials/outline.tres"
const POPUP_SCENE: String = "res://scenes/ui/world_popup.gd"

@export var data: ItemData

## Точки хвата (Marker3D с именами grip_*), заполняется при сборке
var grips: Array[Marker3D] = []
## Целость 0..1 (для хрупких вещей)
var integrity: float = 1.0
## Мешок уже порвался и высыпался
var spilled: bool = false
## Течёт прямо сейчас (аккумулятор набок или вверх дном): в руках не удержать
var leaking: bool = false

## Кто едет внутри (ванна-санки)
var rider: PlayerController

var _tilt_time: float = 0.0
var _saved_material: PhysicsMaterial

var _prev_velocity := Vector3.ZERO
var _intact_mesh: Node3D
var _broken_mesh: Node3D
var _highlighted: bool = false


func _ready() -> void:
	if data != null:
		setup(data, RandomNumberGenerator.new())
	add_to_group(&"items")
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)


## Собрать предмет по данным. rng задаёт случайный вес (в сети его даёт хост).
func setup(item_data: ItemData, rng: RandomNumberGenerator) -> void:
	data = item_data
	if has_node(^"Model"):
		return
	var model: Node3D = data.model.instantiate()
	model.name = "Model"
	add_child(model)
	# Коллизии должны быть прямыми детьми тела, поэтому переносим их из модели
	for shape: Node in model.find_children("col_*", "CollisionShape3D", true, false):
		var xf: Transform3D = (shape as CollisionShape3D).transform
		shape.owner = null
		shape.get_parent().remove_child(shape)
		add_child(shape)
		(shape as CollisionShape3D).transform = xf
	grips.clear()
	for g: Node in model.find_children("grip_*", "Marker3D", true, false):
		grips.append(g as Marker3D)
	# разбитый вариант лежит в той же модели и ждёт своего часа
	_broken_mesh = model.find_child("*_broken", true, false)
	if _broken_mesh != null:
		_broken_mesh.visible = false
		_intact_mesh = model.find_child(String(_broken_mesh.name).trim_suffix("_broken"), true, false)
	mass = data.random_mass(rng)
	continuous_cd = mass < 10.0  # лёгкое и быстрое не должно пролетать сквозь пол


func _physics_process(delta: float) -> void:
	_prev_velocity = linear_velocity
	if data != null and data.leak_tilt_deg > 0.0:
		if global_basis.y.y < cos(deg_to_rad(data.leak_tilt_deg)):
			_tilt_time += delta
		else:
			_tilt_time = 0.0
		leaking = _tilt_time >= data.leak_time


# --- езда в ванне ---------------------------------------------------------------

func can_ride() -> bool:
	return data != null and data.rideable and rider == null and not freeze and global_basis.y.y > 0.7


## Подсказка «E — сесть» для прицела игрока (пустой словарь — сесть нельзя).
func ride_action() -> Dictionary:
	return {"hint": "HINT_RIDE", "action": &"ride"} if can_ride() else {}


func interact(player: PlayerController, action: StringName) -> void:
	if action == &"ride" and can_ride():
		player.sit_on(self)


## Седок сел: днище скользит, вес седока добавляется.
func start_ride(player: PlayerController) -> void:
	rider = player
	_saved_material = physics_material_override
	var slick := PhysicsMaterial.new()
	slick.friction = data.ride_friction
	physics_material_override = slick
	mass += player.feel.body_mass
	can_sleep = false
	sleeping = false


func end_ride() -> void:
	if rider == null:
		return
	mass -= rider.feel.body_mass
	rider = null
	physics_material_override = _saved_material
	can_sleep = true


## Седок рулит: move.y — оттолкнуться вперёд или назад, move.x — довернуть.
func ride_control(move: Vector2) -> void:
	var ahead: Vector3 = global_basis.x.slide(Vector3.UP)
	if ahead.length() < 0.2:
		return
	ahead = ahead.normalized()
	if absf(move.y) > 0.1 and linear_velocity.length() < data.ride_push_max_speed:
		apply_central_force(ahead * move.y * data.ride_push_force)
	if absf(move.x) > 0.1:
		apply_torque(Vector3.UP * -move.x * data.ride_steer_torque)


## Дать время выровнять (взяли в руки лежащее на боку).
func leak_grace(seconds: float) -> void:
	_tilt_time = -seconds
	leaking = false


## Мешок порвался: часть веса разлетается отдельными мелкими вещами.
func spill() -> void:
	if spilled or data == null or data.spill_item == null or data.spill_count <= 0:
		return
	spilled = true
	var rng := RandomNumberGenerator.new()
	rng.seed = get_instance_id()
	var lost: float = 0.0
	for i: int in data.spill_count:
		var piece: Item = ItemDb.spawn(data.spill_item, rng)
		if mass - lost - piece.mass < 0.5:
			piece.free()
			break
		lost += piece.mass
		var dir := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)).normalized()
		piece.transform = Transform3D(Basis(Vector3(1.0, 0.3, 0.2).normalized(), rng.randf() * TAU),
				global_position + Vector3.UP * 0.35 + dir * 0.25)
		get_parent().add_child(piece)
		piece.linear_velocity = linear_velocity * 0.3 + dir * rng.randf_range(1.0, 2.6) + Vector3.UP * rng.randf_range(1.5, 3.0)
		piece.angular_velocity = Vector3(rng.randf_range(-8.0, 8.0), rng.randf_range(-8.0, 8.0), rng.randf_range(-8.0, 8.0))
	mass -= lost
	Audio.play_at(&"soft", global_position, 2.0)
	WorldPopup.spawn(get_tree().current_scene, global_position + Vector3.UP * 0.6, tr("POPUP_BAG_TORN"), Color(1.0, 0.75, 0.3))


## Обводка, когда игрок навёлся на предмет и может его взять.
func set_highlight(on: bool) -> void:
	if on == _highlighted:
		return
	_highlighted = on
	var overlay: Material = load(OUTLINE_MATERIAL) if on else null
	for mesh: Node in find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_overlay = overlay


## Сколько предмет стоит сейчас, ₽ (с учётом целости).
func value() -> int:
	var full: int = data.unit_price if data.unit_price > 0 else Quota.scrap_value(Game.economy, data.metal, mass)
	return roundi(full * (1.0 - data.break_loss * (1.0 - integrity)))


## Сколько предмет стоит сейчас как лом, ₽.
func scrap_value() -> int:
	return Quota.scrap_value(Game.economy, data.metal, mass)


func _on_body_entered(_other: Node) -> void:
	# скорость до шага физики минус после — это и есть сила удара
	var impact: float = (_prev_velocity - linear_velocity).length()
	if impact < MIN_IMPACT:
		return
	hit.emit(impact)
	if rider != null and (impact >= data.ride_crash_speed or global_basis.y.y < 0.3):
		rider.thrown_from_ride(impact)
	Audio.play_impact(data.impact_sound if data != null else &"metal_heavy", global_position, impact)
	if data != null and data.spill_speed > 0.0 and impact >= data.spill_speed and Net.is_host():
		spill.call_deferred()
	if data == null or not data.is_fragile() or integrity <= 0.0 or impact < data.break_speed:
		return
	if not Net.is_host():
		return
	var before: int = value()
	var harm: float = clampf((impact - data.break_speed) / (data.break_speed * 1.5), 0.2, 1.0)
	integrity = maxf(integrity - harm, 0.0)
	var loss: int = before - value()
	if integrity <= 0.0:
		Audio.play_at(data.break_sound, global_position)
		if _broken_mesh != null:
			_broken_mesh.visible = true
			if _intact_mesh != null:
				_intact_mesh.visible = false
	if loss > 0:
		damaged.emit(loss)
		WorldPopup.spawn(get_tree().current_scene, global_position + Vector3.UP * 0.5,
				Fmt.rub(-loss), Color(1.0, 0.32, 0.25))
