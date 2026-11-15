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


func _physics_process(_delta: float) -> void:
	_prev_velocity = linear_velocity


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
	Audio.play_impact(data.impact_sound if data != null else &"metal_heavy", global_position, impact)
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
