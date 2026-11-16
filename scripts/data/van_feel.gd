class_name VanFeel
extends Resource
## Числа фургона: мотор, руль, подвеска, грузоподъёмность. Файл данных: res://data/van_feel.tres

@export_group("Кузов")
## Масса пустой машины, кг
@export var mass: float = 1700.0
## Центр масс ниже и чуть впереди середины: меньше валится в поворотах
@export var center_of_mass := Vector3(0.0, 0.48, 0.25)
@export_group("Мотор и тормоза")
## Тяга на всех колёсах вместе, Н
@export var engine_force: float = 9000.0
## Сколько секунд мотор терпит «газ в пол, а машина стоит», потом глохнет
@export var stall_time: float = 1.8
## Сколько крутит стартер
@export var crank_time: float = 1.1
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
@export_group("Толкание")
## Сила одного толкающего, Н (силы игроков складываются)
@export var push_force: float = 1600.0
## Сила, когда машина лежит на боку или на крыше: чтобы её можно было перевалить на колёса
@export var flip_force: float = 9000.0
@export_group("Улучшения из лавки")
## Усиленные рессоры: прибавка к грузоподъёмности, кг, и во сколько раз жёстче
@export var springs_capacity_bonus: float = 300.0
@export var springs_stiffness_mult: float = 1.35
## Резина-вездеход: множители сцепления и тяги
@export var tyres_grip_mult: float = 1.5
@export var tyres_force_mult: float = 1.2
## Прожектор на крыше
@export var searchlight_energy: float = 22.0
@export var searchlight_range: float = 60.0
@export var searchlight_angle_deg: float = 48.0
@export_group("Свет")
@export var headlight_energy: float = 14.0
@export var headlight_range: float = 38.0
@export var headlight_angle_deg: float = 34.0
