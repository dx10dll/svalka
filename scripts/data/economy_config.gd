class_name EconomyConfig
extends Resource
## Нормы по ночам и цены приёмки. Файл данных: res://data/economy.tres

## Норма каждой ночи для 4 игроков, ₽
@export var quotas_for_four: PackedInt32Array = [3000, 5000, 7500, 10500, 14000, 18000, 23000]
## Множитель нормы для 1, 2, 3, 4 игроков
@export var player_multipliers: PackedFloat32Array = [0.45, 0.65, 0.85, 1.0]
## Округление нормы, ₽
@export var quota_rounding: int = 50
## Сколько секунд длится ночь на свалке (00:00–05:00 на часах)
@export var night_seconds: float = 720.0
## С какой доли ночи светает и воет сирена (0.9 — это 04:30)
@export var dawn_at: float = 0.9
## Сколько денег в кармане в начале забега, ₽
@export var start_money: int = 200
## Сколько берёт сторож за въезд в первую ночь и на сколько дорожает каждую следующую, ₽
@export var guard_fee: int = 100
@export var guard_fee_per_night: int = 50
## Пороги цены вещи для цвета обводки, ₽: дешевле первого — серая, дальше зелёная, синяя, фиолетовая, золотая
@export var tier_prices: PackedInt32Array = [250, 700, 1400, 2400]
@export_group("Цены за кг, ₽")
@export var price_copper: int = 120
@export var price_brass: int = 70
@export var price_aluminium: int = 45
@export var price_lead: int = 35
@export var price_ferrous: int = 6


func nights() -> int:
	return quotas_for_four.size()


## Ступень ценности вещи по цене: 0 (дешёвка) … 4 (сокровище).
func tier_for(value: int) -> int:
	var tier: int = 0
	for price: int in tier_prices:
		if value >= price:
			tier += 1
	return tier


func guard_fee_for(night: int) -> int:
	return guard_fee + guard_fee_per_night * (night - 1)


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
