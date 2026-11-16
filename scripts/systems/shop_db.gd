class_name ShopDb
extends RefCounted
## Список товаров лавки. Пути перечислены явно: в собранной игре папку не перебрать.

const PATHS: Array[String] = [
	"res://data/shop/springs.tres",
	"res://data/shop/tyres.tres",
	"res://data/shop/searchlight.tres",
	"res://data/shop/tool_shovel.tres",
	"res://data/shop/tool_crowbar.tres",
	"res://data/shop/tool_detector.tres",
	"res://data/shop/tool_headlamp.tres",
	"res://data/shop/tool_bottle.tres",
]


static func all() -> Array[ShopItem]:
	var out: Array[ShopItem] = []
	for path: String in PATHS:
		out.append(load(path))
	return out
