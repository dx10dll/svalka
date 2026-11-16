class_name ShopItem
extends Resource
## Товар лавки Барыги. Файлы данных: res://data/shop/*.tres (список — в ShopDb).

@export var id: StringName
@export var name_key: String
@export var desc_key: String
## Цена, ₽
@export var price: int = 1000
