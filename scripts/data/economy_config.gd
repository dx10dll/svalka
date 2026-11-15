class_name EconomyConfig
extends Resource
## Нормы по ночам и цены приёмки. Файл данных: res://data/economy.tres

## Норма каждой ночи для 4 игроков, ₽
@export var quotas_for_four: PackedInt32Array = [3000, 5000, 7500, 10500, 14000, 18000, 23000]
## Множитель нормы для 1, 2, 3, 4 игроков
@export var player_multipliers: PackedFloat32Array = [0.45, 0.65, 0.85, 1.0]
## Округление нормы, ₽
@export var quota_rounding: int = 50
@export_group("Цены за кг, ₽")
@export var price_copper: int = 120
@export var price_brass: int = 70
@export var price_aluminium: int = 45
@export var price_lead: int = 35
@export var price_ferrous: int = 6


func nights() -> int:
	return quotas_for_four.size()


func price_per_kg(metal: ItemData.Metal) -> int:
	match metal:
		ItemData.Metal.COPPER:
			return price_copper
		ItemData.Metal.BRASS:
			return price_brass
		ItemData.Metal.ALUMINIUM:
			return price_aluminium
		ItemData.Metal.LEAD:
			return price_lead
		ItemData.Metal.FERROUS:
			return price_ferrous
	return 0
