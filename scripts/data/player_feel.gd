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
@export var jump_height: float = 1.0
## Отпустил прыжок рано — прыжок ниже (множитель гравитации на взлёте)
@export var jump_cut_factor: float = 2.2
## Можно прыгнуть спустя это время после схода с края, с
@export var coyote_time: float = 0.12
## Нажал прыжок чуть раньше приземления — прыжок всё равно сработает, с
@export var jump_buffer: float = 0.13
@export var max_fall_speed: float = 38.0

@export_group("Тело")
@export var radius: float = 0.28
@export var stand_height: float = 1.28
@export var crouch_height: float = 0.8
## Глаза ниже макушки на столько
@export var eye_drop: float = 0.2
@export var crouch_lerp_speed: float = 10.0
## Высота ступеньки, на которую заходим без прыжка
@export var step_height: float = 0.42
@export var floor_max_angle_deg: float = 46.0
## Сила, с которой расталкиваем предметы, Н
@export var push_force: float = 260.0

@export_group("Залезание на уступ")
## Уступ ниже этого перешагиваем по нажатию прыжка, не прыгая
@export var vault_height: float = 0.85
## Докуда дотягиваемся руками от подошв (в воздухе)
@export var mantle_reach_up: float = 1.4
@export var mantle_min_height: float = 0.4
@export var mantle_reach_forward: float = 0.55
@export var mantle_base_time: float = 0.22
@export var mantle_time_per_meter: float = 0.22
@export var mantle_exit_speed: float = 1.6

@export_group("Захват и переноска")
## Докуда дотягиваемся взглядом, м
@export var grab_reach: float = 2.0
## Где держим предмет: вперёд от глаз и ниже линии взгляда, м
@export var hold_distance: float = 0.64
@export var hold_drop: float = 0.22
## Сила рук вверх, Н. Поднимаем всё, что легче lift_force / 9.8 кг (сейчас около 43 кг)
@export var lift_force: float = 420.0
## Сила тяги вбок, Н (ею волочим тяжёлое)
@export var pull_force: float = 380.0
## Как быстро предмет догоняет руки (рад/с): больше — жёстче хват
@export var grab_frequency: float = 13.0
## Предел усилия, которым удерживаем поворот предмета, Н·м
@export var hold_torque: float = 55.0
## Предмет отстал от рук на столько — начинает тормозить игрока, м
@export var tether_slack: float = 0.45
## Отстал на столько — руки срываются, м
@export var grab_break_distance: float = 1.5
## Скорость шага с предельным весом в руках и волоком (доля от обычной)
@export var carry_speed_factor: float = 0.6
@export var drag_speed_factor: float = 0.42
## С грузом тяжелее этого бегать нельзя, кг
@export var sprint_mass_limit: float = 12.0
@export_subgroup("Бросок")
@export var throw_charge_time: float = 0.8
## Импульс полного броска, Н·с: скорость = импульс / масса
@export var throw_impulse: float = 150.0
@export var throw_max_speed: float = 13.0
@export var throw_up_bias: float = 0.18

@export_group("Падение")
## Скорость удара о землю, с которой начинается «встряска», м/с
@export var hard_landing_speed: float = 9.0
## Скорость удара, с которой персонаж валится с ног, м/с (около 4 м высоты)
@export var knockdown_speed: float = 13.5
@export var knockdown_time: float = 1.7
## Толчок при падении нарочно (Q): вперёд и вверх, м/с
@export var flop_push: Vector2 = Vector2(2.5, 2.5)
@export var getup_time: float = 0.9

@export_group("Камера")
@export var fov: float = 78.0
@export var sprint_fov_add: float = 7.0
## Длина полного цикла шагов (два шага) шагом, бегом и в приседе, м
@export var stride_walk: float = 2.1
@export var stride_run: float = 2.9
@export var stride_crouch: float = 1.3
@export var bob_height: float = 0.035
@export var bob_side: float = 0.03
@export var bob_roll_deg: float = 0.6
## Наклон камеры при движении боком, градусов на полной скорости
@export var strafe_roll_deg: float = 1.8
## Просадка камеры при приземлении: метров на 1 м/с удара
@export var landing_dip_per_speed: float = 0.022
@export var landing_dip_max: float = 0.45
@export var landing_spring: float = 120.0
@export var landing_damping: float = 16.0
@export_group("Фонарь")
@export var flashlight_energy: float = 5.0
@export var flashlight_range: float = 22.0
## Половина угла луча, градусы
@export var flashlight_angle_deg: float = 26.0
