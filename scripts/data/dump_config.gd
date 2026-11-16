class_name DumpConfig
extends Resource
## Настройки кучи мусора: размеры решётки, форма, из чего сложена, как рушится.
## Файл данных: res://data/dump_test.tres

@export_group("Решётка")
## Размер одной ячейки, м. Высота меньше шага залезания, чтобы по куче ходили как по ступеням
@export var cell_size: Vector3 = Vector3(0.8, 0.4, 0.8)
## Размер чанка в ячейках (4 × 4 × 4 м)
@export var chunk_cells: Vector3i = Vector3i(5, 10, 5)
@export_group("Форма")
## Радиус основания, м
@export var radius: float = 13.0
## Высота вершины, м
@export var height: float = 8.0
## Свободное поле вокруг (туда скатывается мусор), м
@export var margin: float = 4.0
## Неровность склонов: доля высоты и размер бугров, м
@export var lump_strength: float = 0.35
@export var lump_size: float = 5.0
@export_group("Состав")
## Куски мусора и их доли у поверхности и в глубине (глубже deep_depth метров)
@export var junk: Array[ItemData] = []
@export var junk_weight_top: PackedFloat32Array = []
@export var junk_weight_deep: PackedFloat32Array = []
@export var deep_depth: float = 3.0
## Ценные вещи и их доли у поверхности и в глубине
@export var loot: Array[ItemData] = []
@export var loot_weight_top: PackedFloat32Array = []
@export var loot_weight_deep: PackedFloat32Array = []
## Шанс, что в ячейке лежит ценная вещь: у поверхности и в глубине
@export var loot_chance_top: float = 0.006
@export var loot_chance_deep: float = 0.016
@export_group("Завалы")
## Сколько секунд куча «предупреждает» перед обвалом
@export var warning_time: float = 1.3
## Сколько кусков кучи может быть живыми телами одновременно
@export var max_awake: int = 110
## Тело, пролежавшее столько секунд неподвижно, запекается обратно в кучу
@export var rest_time: float = 2.5
## Медленнее этой скорости тело считается лежащим, м/с
@export var rest_speed: float = 0.12
## С какой скоростью куски вылетают из завала наружу, м/с
@export var slide_speed: float = 3.2
## Отвесная стенка выше стольких ячеек рядом с ямой оползает
@export var cliff_cells: int = 4
@export_group("Засыпанный игрок")
## Завал от стольких кусков может засыпать игрока
@export var bury_min_pieces: int = 4
## Насколько близко к завалу надо стоять, чтобы засыпало, м
@export var bury_radius: float = 2.3
## Сколько кусков ложится на засыпанного
@export var bury_pieces: int = 6
