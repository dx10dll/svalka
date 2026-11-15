class_name Item
extends RigidBody3D
## Физический предмет свалки. Модель, коллизии и точки хвата берутся из .glb,
## числа — из ItemData. Этап 0: только сборка и масса; захват и целость — этап 2.

@export var data: ItemData

## Точки хвата (Marker3D с именами grip_*), заполняется при сборке
var grips: Array[Marker3D] = []
## Целость 0..1 (для хрупких вещей)
var integrity: float = 1.0


func _ready() -> void:
	if data != null:
		setup(data, RandomNumberGenerator.new())


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
	mass = data.random_mass(rng)
	continuous_cd = mass < 10.0  # лёгкое и быстрое не должно пролетать сквозь пол


## Сколько предмет стоит сейчас как лом, ₽.
func scrap_value() -> int:
	return Quota.scrap_value(Game.economy, data.metal, mass)
