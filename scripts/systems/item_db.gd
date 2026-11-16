class_name ItemDb
extends RefCounted
## Каталог предметов: читает все ItemData из res://data/items/.

const DIR: String = "res://data/items/"
const ITEM_SCENE: String = "res://scenes/items/item.tscn"


static func all() -> Array[ItemData]:
	var out: Array[ItemData] = []
	for file: String in ResourceLoader.list_directory(DIR):
		if file.ends_with(".tres"):
			var res: Resource = load(DIR + file)
			if res is ItemData:
				out.append(res)
	out.sort_custom(func(a: ItemData, b: ItemData) -> bool: return String(a.id) < String(b.id))
	return out


## Инструмент по id (res://data/tools/).
static func tool(id: StringName) -> ItemData:
	var path: String = "res://data/tools/%s.tres" % id
	return load(path) if ResourceLoader.exists(path) else null


static func spawn(item_data: ItemData, rng: RandomNumberGenerator) -> Item:
	var item: Item = (load(ITEM_SCENE) as PackedScene).instantiate()
	item.setup(item_data, rng)
	return item
