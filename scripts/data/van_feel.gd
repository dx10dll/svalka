class_name VanFeel
extends Resource
## Числа фургона: мотор, руль, подвеска, грузоподъёмность. Файл данных: res://data/van_feel.tres

@export_group("Кузов")
## Масса пустой машины, кг
@export var mass: float = 1700.0
## Центр масс ниже и чуть впереди середины: меньше валится в поворотах
@export var center_of_mass := Vector3(0.0, 0.48, 0.25)
@export_group("Мотор и тормоза")
## Тяга на колёсах на первой «передаче», Н
@export var engine_force: float = 6200.0
## Наибольшая скорость вперёд и назад, м/с
@export var max_speed: float = 13.0
@export var max_reverse_speed: float = 4.5
## Тормозное усилие (единицы VehicleBody3D)
@export var brake_force: float = 55.0
## Торможение двигателем, когда газ отпущен
@export var idle_brake: float = 4.0
## Вязкость стоящей на ручнике машины (чтобы не сползала)
@export var parked_damp: float = 6.0
@export_group("Руль")
## Наибольший угол поворота колёс на месте и на полной скорости, рад
@export var steer_max: float = 0.55
@export var steer_max_fast: float = 0.2
## Скорость поворота руля, рад/с
@export var steer_speed: float = 1.6
@export_group("Подвеска")
@export var wheel_radius: float = 0.38
## Свободный ход подвески, м
@export var suspension_rest: float = 0.26
@export var suspension_travel: float = 0.22
## Просадка пустой машины под своим весом, м (измерена; меняется вместе с жёсткостью)
@export var static_sag: float = 0.165
## Жёсткость рессор: подобрана так, что 800 кг груза почти сажают зад на отбойники
@export var suspension_stiffness: float = 26.0
@export var damping_compression: float = 2.2
@export var damping_relaxation: float = 3.2
## Сцепление шин (ниже — легче заносит)
@export var wheel_friction: float = 2.4
## Крен в поворотах: в Godot меньше значение — сильнее валится (проверено тестом)
@export var roll_influence: float = 0.5
@export_group("Груз")
## Грузоподъёмность, кг
@export var capacity: float = 800.0
## На каждые 100 кг сверх нормы тяга и скорость падают на эту долю
@export var overload_penalty: float = 0.12
## Меньше этой доли тяга от перегруза не падает
@export var overload_min_power: float = 0.3
@export_group("Свет")
@export var headlight_energy: float = 14.0
@export var headlight_range: float = 38.0
@export var headlight_angle_deg: float = 34.0
