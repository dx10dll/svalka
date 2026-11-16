class_name GuardConfig
extends Resource
## Числа сторожа: скорость, зрение, слух, поимка. Файл данных: res://data/guard.tres

@export_group("Ходьба")
@export var walk_speed: float = 2.0
## Бегом он чуть медленнее бегущего налегке игрока, но быстрее гружёного
@export var run_speed: float = 5.4
@export var turn_speed: float = 4.0
## На сколько метров от подножия горы он держится (на гору не лезет)
@export var heap_margin: float = 3.0
@export_group("Зрение")
## Видит игрока без фонаря, м
@export var view_range: float = 13.0
## Видит игрока с включённым фонарём, м
@export var view_range_lit: float = 34.0
## Присевшего видит во столько раз хуже
@export var crouch_mult: float = 0.5
## Половина угла обзора, градусы
@export var view_half_angle: float = 55.0
## Сколько секунд надо быть на виду, чтобы он узнал (вблизи быстрее)
@export var notice_time: float = 1.4
## Сколько секунд он гонится, потеряв из виду
@export var lose_time: float = 5.0
@export_group("Слух")
## Радиус слышимости удара вещи = скорость удара × это, м
@export var impact_noise_per_speed: float = 3.5
@export var impact_noise_min_speed: float = 3.0
@export var impact_noise_max: float = 30.0
@export var collapse_noise: float = 50.0
@export var engine_noise: float = 26.0
@export_group("Поимка")
@export var catch_distance: float = 1.5
## Сколько секунд после поимки он никого не ловит (уходит на обход)
@export var catch_cooldown: float = 25.0
## Через сколько секунд после проезда мимо он выходит искать
@export var search_delay: float = 40.0
## Сколько секунд осматривает место шума
@export var look_around_time: float = 5.0
@export_group("Фонарь")
@export var lantern_energy: float = 2.6
@export var lantern_range: float = 12.0
@export_group("Пёс")
@export var dog_walk_speed: float = 2.4
## Пёс быстрее любого игрока
@export var dog_run_speed: float = 7.6
## Чует игрока на таком расстоянии, свет и стены не важны, м
@export var dog_smell_range: float = 15.0
@export var dog_bark_distance: float = 2.6
@export var dog_bark_every: float = 0.9
## На сколько метров слышен лай (на него идёт сторож)
@export var dog_bark_noise: float = 60.0
## Чует колбасу на земле, м
@export var dog_food_range: float = 14.0
## Сколько секунд ест колбасу
@export var dog_eat_time: float = 25.0
