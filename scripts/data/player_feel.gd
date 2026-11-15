class_name PlayerFeel
extends Resource
## Все числа ощущения от управления персонажем. Файл данных: res://data/player_feel.tres
## Правятся без кода: открыть .tres в редакторе Godot или в блокноте.

@export_group("Скорость, м/с")
@export var walk_speed: float = 4.3
@export var sprint_speed: float = 6.6
@export var crouch_speed: float = 2.1
## Назад и боком идём медленнее (доля от скорости вперёд)
@export var backward_factor: float = 0.72
@export var strafe_factor: float = 0.88

@export_group("Разгон и инерция, м/с²")
@export var ground_accel: float = 34.0
@export var ground_decel: float = 24.0
## При резкой смене направления тормозим быстрее: ощущение «цепкости»
@export var turn_boost: float = 1.6
@export var air_accel: float = 8.0
@export var air_decel: float = 1.5

@export_group("Прыжок")
@export var gravity: float = 24.0
## Падаем быстрее, чем взлетаем: прыжок выходит весомым
@export var fall_gravity_factor: float = 1.3
@export var jump_height: float = 1.05
## Отпустил прыжок рано — прыжок ниже (множитель гравитации на взлёте)
@export var jump_cut_factor: float = 2.2
## Можно прыгнуть спустя это время после схода с края, с
@export var coyote_time: float = 0.12
## Нажал прыжок чуть раньше приземления — прыжок всё равно сработает, с
@export var jump_buffer: float = 0.13
@export var max_fall_speed: float = 38.0

@export_group("Тело")
@export var radius: float = 0.3
@export var stand_height: float = 1.8
@export var crouch_height: float = 1.1
## Глаза ниже макушки на столько
@export var eye_drop: float = 0.14
@export var crouch_lerp_speed: float = 10.0
## Высота ступеньки, на которую заходим без прыжка
@export var step_height: float = 0.38
@export var floor_max_angle_deg: float = 46.0
## Сила, с которой расталкиваем предметы, Н
@export var push_force: float = 260.0

@export_group("Залезание на уступ")
## Уступ ниже этого перешагиваем по нажатию прыжка, не прыгая
@export var vault_height: float = 1.15
## Докуда дотягиваемся руками от подошв (в воздухе)
@export var mantle_reach_up: float = 1.7
@export var mantle_min_height: float = 0.45
@export var mantle_reach_forward: float = 0.55
@export var mantle_base_time: float = 0.22
@export var mantle_time_per_meter: float = 0.22
@export var mantle_exit_speed: float = 1.6

@export_group("Падение")
## Скорость удара о землю, с которой начинается «встряска», м/с
@export var hard_landing_speed: float = 9.0
## Скорость удара, с которой персонаж валится с ног, м/с (около 4 м высоты)
@export var knockdown_speed: float = 13.5
@export var knockdown_time: float = 1.3
@export var getup_time: float = 0.9

@export_group("Камера")
@export var fov: float = 78.0
@export var sprint_fov_add: float = 7.0
## Длина полного цикла шагов (два шага), м
@export var stride_length: float = 2.7
@export var bob_height: float = 0.045
@export var bob_side: float = 0.03
@export var bob_roll_deg: float = 0.6
## Наклон камеры при движении боком, градусов на полной скорости
@export var strafe_roll_deg: float = 1.8
## Просадка камеры при приземлении: метров на 1 м/с удара
@export var landing_dip_per_speed: float = 0.022
@export var landing_dip_max: float = 0.45
@export var landing_spring: float = 120.0
@export var landing_damping: float = 16.0
