class_name RunState
extends RefCounted
## Забег из семи ночей: долг, нормы, касса, статистика. Чистая логика без узлов —
## её тестируют tests/ и она же потом поедет по сети с хоста.

enum Outcome { RUNNING, NIGHT_PASSED, WON, LOST }

var economy: EconomyConfig
var players: int = 1
## Сид забега: от него считаются сиды свалок каждой ночи
var run_seed: int = 1
## Текущая ночь, с 1
var night: int = 1
## Касса бригады (излишки прошлых ночей), ₽
var money: int = 0
## Сдано за эту ночь, ₽
var earned: int = 0
var outcome: Outcome = Outcome.RUNNING
## Смешная статистика ночи: имя -> число
var stats: Dictionary[StringName, int] = {}


func _init(cfg: EconomyConfig, player_count: int = 1, seed_value: int = 1) -> void:
	economy = cfg
	players = player_count
	run_seed = seed_value


func quota() -> int:
	return Quota.for_night(economy, night, players)


func quota_left() -> int:
	return maxi(quota() - earned, 0)


func quota_met() -> bool:
	return earned >= quota()


## Сид свалки этой ночи.
func night_seed() -> int:
	return run_seed * 1000 + night


func sell(value: int) -> void:
	earned += maxi(value, 0)


func count(stat: StringName, amount: int = 1) -> void:
	stats[stat] = stats.get(stat, 0) + amount


## Закрыть ночь. Норма есть — излишек в кассу; нет — забег окончен.
func finish_night() -> Outcome:
	if outcome != Outcome.RUNNING:
		return outcome
	if not quota_met():
		outcome = Outcome.LOST
	else:
		money += earned - quota()
		outcome = Outcome.WON if night >= economy.nights() else Outcome.NIGHT_PASSED
	return outcome


## Перейти к следующей ночи (после NIGHT_PASSED).
func next_night() -> void:
	assert(outcome == Outcome.NIGHT_PASSED, "следующая ночь только после закрытой нормы")
	night += 1
	earned = 0
	stats.clear()
	outcome = Outcome.RUNNING


func to_dict() -> Dictionary:
	return {"seed": run_seed, "night": night, "money": money, "players": players}


static func from_dict(cfg: EconomyConfig, d: Dictionary) -> RunState:
	var run := RunState.new(cfg, int(d.get("players", 1)), int(d.get("seed", 1)))
	run.night = clampi(int(d.get("night", 1)), 1, cfg.nights())
	run.money = int(d.get("money", 0))
	return run
