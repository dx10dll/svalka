extends Node
## Состояние забега: фаза ночи, номер ночи, время на часах, отладочные флаги.
## Заглушка этапа 0: сами фазы появятся на этапе 5, но остальные системы уже
## подписываются на эти сигналы, а не друг на друга.

signal phase_changed(phase: Phase)
signal night_time_changed(t: float)
signal debug_flag_changed(flag: StringName, enabled: bool)

enum Phase { GARAGE, ROAD, LANDFILL, WEIGHING, SUMMARY }

const ECONOMY_PATH: String = "res://data/economy.tres"

var economy: EconomyConfig
## Текущий забег (создаётся сценой ночи)
var run: RunState
var phase: Phase = Phase.GARAGE
var night: int = 1
var player_count: int = 1
var seed_value: int = 0
## Время ночи: 0.0 — полночь (00:00), 1.0 — рассвет (05:00)
var night_time: float = 0.0: set = set_night_time

var _debug_flags: Dictionary = {}


func _ready() -> void:
	economy = load(ECONOMY_PATH)
	assert(economy != null, "нет файла экономики " + ECONOMY_PATH)


func set_phase(p: Phase) -> void:
	if p == phase:
		return
	phase = p
	phase_changed.emit(p)


func set_night_time(t: float) -> void:
	night_time = clampf(t, 0.0, 1.0)
	night_time_changed.emit(night_time)


## Начать новый забег или продолжить сохранённый.
func start_run(continue_saved: bool) -> RunState:
	var saved: Dictionary = Save.read().get("run", {}) if continue_saved else {}
	if saved.is_empty():
		run = RunState.new(economy, player_count, randi_range(1, 99999))
	else:
		run = RunState.from_dict(economy, saved)
	night = run.night
	return run


func save_run() -> void:
	Save.write({"run": run.to_dict()} if run != null and run.outcome != RunState.Outcome.LOST \
			and run.outcome != RunState.Outcome.WON else {})


## Часы свалки строкой: 0.0 -> "00:00", 1.0 -> "05:00".
func clock_text() -> String:
	var minutes: int = int(round(night_time * 300.0))
	return "%02d:%02d" % [minutes / 60, minutes % 60]


func quota() -> int:
	return Quota.for_night(economy, night, player_count)


func set_debug_flag(flag: StringName, enabled: bool) -> void:
	_debug_flags[flag] = enabled
	debug_flag_changed.emit(flag, enabled)


func debug_flag(flag: StringName) -> bool:
	return _debug_flags.get(flag, false)
