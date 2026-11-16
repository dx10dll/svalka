extends SceneTree
## Пересобирает списки ценных вещей в кучах и пересохраняет файлы движком
## (руками массивы в .tres не пишем: они теряются при упаковке игры).
## Запуск: godot --headless --path . -s tools/update_loot.gd

## Вещь: [id, вес сверху, вес в глубине, вес у дна]
const LOOT: Array = [
	["cable_coil", 1.0, 1.5, 2.0],
	["tv_crt", 1.5, 0.6, 0.3],
	["samovar", 0.3, 1.0, 1.6],
	["washing_machine", 1.0, 0.8, 0.5],
	["fridge", 0.8, 1.0, 0.8],
	["radiator_cast_iron", 0.4, 1.5, 2.2],
	["cans_bag", 2.2, 0.6, 0.2],
	["car_battery", 0.6, 1.2, 1.0],
	["bathtub", 0.1, 0.6, 1.2],
	["car_radiator", 0.4, 1.2, 1.4],
	["radio", 0.15, 0.7, 1.5],
	["camera", 0.1, 0.5, 1.2],
]


func _init() -> void:
	for path: String in ["res://data/dump_test.tres", "res://data/dump_mountain.tres"]:
		var cfg: DumpConfig = load(path)
		var loot: Array[ItemData] = []
		var top := PackedFloat32Array()
		var deep := PackedFloat32Array()
		var bottom := PackedFloat32Array()
		for row: Array in LOOT:
			loot.append(load("res://data/items/%s.tres" % row[0]))
			top.append(row[1])
			deep.append(row[2])
			bottom.append(row[3])
		var had_bottom: bool = not cfg.loot_weight_bottom.is_empty()
		cfg.loot = loot
		cfg.loot_weight_top = top
		cfg.loot_weight_deep = deep
		cfg.loot_weight_bottom = bottom if had_bottom else PackedFloat32Array()
		print(path, ": вещей ", loot.size(), ", сохранение ", error_string(ResourceSaver.save(cfg, path)))
	quit()
