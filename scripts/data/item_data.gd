class_name ItemData
extends Resource
## Описание предмета свалки: вес, цена, кто может нести. Все числа — стартовые,
## правятся в .tres без кода.

enum Metal { COPPER, BRASS, ALUMINIUM, LEAD, FERROUS, ELECTRONICS, ANTIQUE, STRANGE, TRASH }

@export var id: StringName = &""
## Ключ перевода названия (locale/strings.csv)
@export var name_key: String = ""
## Модель из Blender-конвейера (.glb): меш, col_* коллизии, grip_* точки хвата
@export var model: PackedScene
@export_group("Вес")
@export var mass_min_kg: float = 1.0
@export var mass_max_kg: float = 1.0
## Сколько человек нужно, чтобы нести (1 — один, 2+ — в одиночку только волоком)
@export_range(1, 4) var carriers: int = 1
@export_group("Цена")
@export var metal: Metal = Metal.FERROUS
## Для техники и антиквариата: фиксированная цена за штуку целой вещи, ₽
@export var unit_price: int = 0
## Хрупкость: удар быстрее этой скорости (м/с) отнимает целость. 0 — не бьётся
@export var break_speed: float = 0.0
## Какая доля цены теряется при полном разбитии (0.7 = -70%)
@export_range(0.0, 1.0) var break_loss: float = 0.0
@export_group("Особенности")
## Что высыпается, если сильно ударить (мешок банок); пусто — ничего
@export var spill_item: ItemData
@export var spill_count: int = 0
## Удар сильнее этого рвёт мешок, м/с
@export var spill_speed: float = 0.0
## Наклон от вертикали, с которого течёт кислота, градусы (0 — не течёт)
@export var leak_tilt_deg: float = 0.0
## Сколько секунд надо продержать наклонённым, чтобы потекло
@export var leak_time: float = 0.6
## В этом можно съехать с горы (ванна)
@export var rideable: bool = false
## Высота глаз седока над началом координат предмета, м
@export var ride_eye_height: float = 0.75
## Трение днища, пока в нём едут (меньше — скользит лучше)
@export var ride_friction: float = 0.12
## Сила, с которой седок отталкивается и подруливает, Н и Н·м
@export var ride_push_force: float = 700.0
@export var ride_steer_torque: float = 260.0
## Быстрее этого отталкиваться уже нельзя, м/с
@export var ride_push_max_speed: float = 3.0
## Удар сильнее этого выбрасывает седока, м/с
@export var ride_crash_speed: float = 7.0
@export_group("Инструмент")
## Что это за инструмент (shovel, crowbar, metal_detector, headlamp); пусто — обычная вещь.
## Инструмент работает, пока висит на поясе.
@export var tool: StringName = &""
@export_group("В куче")
## Сколько ячеек решётки свалки занимает вещь, пока закопана (x, y, z)
@export var dump_cells: Vector3i = Vector3i(1, 1, 1)
## Как вещь лежит в куче: поворот в градусах (x, y, z)
@export var dump_rotation_deg: Vector3 = Vector3.ZERO
@export_group("Звук")
## Звук удара: имя из assets/audio/sfx (metal_heavy, metal_hollow, metal_ring, plastic, soft, wood)
@export var impact_sound: StringName = &"metal_heavy"
## Звук, когда хрупкая вещь разбилась окончательно (пусто — нет)
@export var break_sound: StringName = &""


func random_mass(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(mass_min_kg, mass_max_kg)


## Мусор, который ничего не стоит (куски кучи).
func is_trash() -> bool:
	return metal == Metal.TRASH and unit_price == 0 and tool.is_empty()


func is_tool() -> bool:
	return not tool.is_empty()


func is_fragile() -> bool:
	return break_speed > 0.0
