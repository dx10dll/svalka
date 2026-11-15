class_name Quota
extends RefCounted
## Чистая логика нормы ночи, без сцен и узлов (тестируется в tests/).


## Норма ночи night (с 1) для players игроков, ₽.
static func for_night(cfg: EconomyConfig, night: int, players: int) -> int:
	assert(night >= 1 and night <= cfg.nights(), "ночь вне диапазона")
	var p: int = clampi(players, 1, cfg.player_multipliers.size())
	var raw: float = cfg.quotas_for_four[night - 1] * cfg.player_multipliers[p - 1]
	var step: int = maxi(cfg.quota_rounding, 1)
	return int(round(raw / step)) * step


## Стоимость металлолома по весу, ₽ (без засора и целости).
static func scrap_value(cfg: EconomyConfig, metal: ItemData.Metal, mass_kg: float) -> int:
	return int(round(cfg.price_per_kg(metal) * mass_kg))
