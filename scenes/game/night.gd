extends "res://scenes/debug/playground_dump.gd"
## Ночь на свалке: часы от 00:00 до 05:00, норма, приёмка у ворот, итог.
## Ночь начинается на подъезде: до ворот надо доехать. У ворот сторож и шлагбаум —
## заплатить в ящик у будки или объехать через дыру в заборе. Часы идут с въезда.
## Свалка каждой ночи своя — по сиду забега и номеру ночи.

signal night_finished(outcome: RunState.Outcome)

const SIREN_EVERY: float = 9.0
const GARAGE_SCENE: String = "res://scenes/game/garage.tscn"

## Тесты выключают: тогда после итога сцена сама не перезагружается
var auto_advance: bool = true
var yard: ScrapYard
var run: RunState
var finished: bool = false
## Строки итога ночи (для тестов и сети)
var summary_lines: PackedStringArray = []
var dawn: bool = false
## Въехали на свалку: с этого момента идут часы
var entered: bool = false
var guard: Guard
## Сколько секунд осталось до выхода сторожа на поиски (после проезда мимо него)
var search_in: float = -1.0

const NOTICE_WIDTH: float = 420.0

var _clock: Label
var _night_label: Label
var _quota_bar: ProgressBar
var _quota_label: Label
var _cash_label: Label
var _notice_panel: PanelContainer
var _notice: Label
var _summary_shade: ColorRect
var _summary: VBoxContainer
var _notice_time: float = 0.0
var _siren_wait: float = 0.0


func _config_path() -> String:
	return "res://data/dump_mountain.tres"


func _dump_seed() -> int:
	if Game.run == null or Game.run.outcome != RunState.Outcome.RUNNING:
		Game.start_run(true)
	return Game.run.night_seed()


func _hint_key() -> String:
	return ""


func _populate() -> void:
	super()
	run = Game.run
	Game.night = run.night
	Game.night_time = 0.0
	Game.set_phase(Game.Phase.ROAD)
	run.sneaked = false
	run.guard_paid = false
	van.apply_upgrades(run.upgrades)
	# ночь начинается на подъезде, носом к воротам
	van.position = site.start_position + Vector3(0.0, 0.25, 0.0)
	van.rotation.y = PI
	_player.position = site.start_position + Vector3(2.4, 0.05, 1.0)
	_player.rotation.y = 0.0
	site.set_barrier(false, true)
	var spot: UseSpot = UseSpot.make(Vector3(0.45, 0.4, 0.35), Color(0.8, 0.62, 0.1), _guard_hint, _pay_guard)
	spot.name = "GuardBox"
	spot.position = site.booth_spot_position
	add_child(spot)
	var stand := MeshInstance3D.new()
	var stand_mesh := BoxMesh.new()
	stand_mesh.size = Vector3(0.08, site.booth_spot_position.y, 0.08)
	stand.mesh = stand_mesh
	stand.position = Vector3(0.0, -site.booth_spot_position.y * 0.5, 0.0)
	spot.add_child(stand)
	yard = ScrapYard.new()
	yard.name = "Yard"
	yard.position = site.gate_position + Vector3(-7.5, 0.0, 9.0)
	add_child(yard)
	yard.build(run)
	yard.finish_requested.connect(finish)
	yard.sold.connect(func(total: int, _count: int) -> void:
		run.count(&"sold_items", _count)
		if run.quota_met():
			_say(tr("NIGHT_QUOTA_MET"))
		else:
			_say(tr("NIGHT_SOLD") % [Fmt.rub(total), Fmt.rub(run.quota_left())]))
	_player.buried_started.connect(func() -> void: run.count(&"buried"))
	_player.knocked_down.connect(func(_impact: float) -> void: run.count(&"falls"))
	dump.collapsed.connect(func(_center: Vector3, _pieces: int) -> void: run.count(&"collapses"))
	get_tree().node_added.connect(_on_node_added)
	guard = Guard.new()
	guard.name = "Guard"
	add_child(guard)
	guard.setup(Vector3.ZERO, dump.config.radius, site.booth_position + Vector3(-1.9, 0.0, -1.6),
			site.gate_position + Vector3(1.0, 0.05, 5.0))
	guard.rotation.y = PI * 0.5
	guard.state_changed.connect(_on_guard_state)
	guard.caught.connect(_on_guard_caught)
	guard.bribed.connect(_on_guard_bribed)
	_build_hud()
	if OS.get_cmdline_user_args().has("--demo-summary"):
		# для снимков интерфейса: сразу показать итог ночи
		run.sell(run.quota() + 350)
		run.count(&"falls", 3)
		run.count(&"sold_items", 7)
		get_tree().create_timer(0.3).timeout.connect(finish)
	_say(tr("NIGHT_START") % [run.night, run.economy.nights(), Fmt.rub(run.quota())], 8.0)


func guard_fee() -> int:
	return run.economy.guard_fee_for(run.night)


func _guard_hint() -> String:
	if run.guard_paid or finished:
		return ""
	if _player.belt.active_tool() == &"bottle":
		return tr("GUARD_GIVE_BOTTLE")
	if run.money < guard_fee():
		return tr("GUARD_NO_MONEY") % Fmt.rub(guard_fee())
	return tr("GUARD_PAY") % Fmt.rub(guard_fee())


func _pay_guard(who: PlayerController) -> void:
	if who.belt.active_tool() == &"bottle" and not run.guard_paid:
		if give_bottle(who):
			_say(tr("GUARD_BOTTLE_THANKS"), 6.0)
	else:
		pay_guard()


## Отдать сторожу бутылку из рук: пускает без денег и ложится спать (или бросает поиски).
func give_bottle(who: PlayerController) -> bool:
	if who.belt.active_tool() != &"bottle":
		return false
	var bottle: Item = who.belt.take_active()
	if bottle != null:
		bottle.free()
	run.guard_paid = true
	run.count(&"bottles")
	search_in = -1.0
	site.set_barrier(true)
	guard.go_home()
	Audio.play_at(&"cash", who.global_position, -4.0, 0.7)
	return true


## Заплатить сторожу за въезд: шлагбаум поднимается.
func pay_guard() -> bool:
	if run.guard_paid or not run.pay(guard_fee()):
		Audio.play_at(&"deny", site.booth_spot_position)
		return false
	run.guard_paid = true
	site.set_barrier(true)
	Audio.play_at(&"cash", site.booth_spot_position)
	_say(tr("GUARD_THANKS"))
	return true


func _on_guard_state(state: Guard.State) -> void:
	if state == Guard.State.CHASE:
		_say(tr("GUARD_SPOTTED"), 3.0)


## Сторож догнал, а в руках бутылка: берёт её вместо вещей и уходит.
func _on_guard_bribed(_who: PlayerController) -> void:
	run.guard_paid = true
	run.count(&"bottles")
	search_in = -1.0
	site.set_barrier(true)
	_say(tr("GUARD_BRIBED"), 6.0)


func _on_guard_caught(_who: PlayerController, taken: Item) -> void:
	run.count(&"caught")
	if taken != null and taken.data != null:
		_say(tr("GUARD_CAUGHT_TOOK") % tr(taken.data.name_key), 6.0)
	else:
		_say(tr("GUARD_CAUGHT"), 6.0)


## Кто-то пересёк линию ворот: часы пошли. Без оплаты — значит, пролезли.
func _enter() -> void:
	entered = true
	Game.set_phase(Game.Phase.LANDFILL)
	if not run.guard_paid:
		run.sneaked = true
		run.count(&"sneaked")
		search_in = guard.config.search_delay
		_say(tr("GUARD_SNEAKED"), 6.0)
	else:
		_say(tr("NIGHT_CLOCK_STARTED"))


func _on_node_added(node: Node) -> void:
	var item: Item = node as Item
	if item != null and not item.damaged.is_connected(_on_item_damaged):
		item.damaged.connect(_on_item_damaged)


func _on_item_damaged(_loss: int) -> void:
	run.count(&"broken")


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	# слева сверху: часы, ночь, норма полоской, касса
	var status: PanelContainer = Ui.panel()
	status.position = Vector2(14, 14)
	layer.add_child(status)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 3)
	status.add_child(column)
	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", 10)
	column.add_child(top)
	_clock = Ui.label("00:00", Ui.SIZE_BIG)
	top.add_child(_clock)
	_night_label = Ui.label("", Ui.SIZE_SMALL, Ui.DIM)
	_night_label.size_flags_vertical = Control.SIZE_SHRINK_END
	top.add_child(_night_label)
	_quota_bar = Ui.bar(170.0)
	column.add_child(_quota_bar)
	_quota_label = Ui.label("", Ui.SIZE_SMALL)
	column.add_child(_quota_label)
	_cash_label = Ui.label("", Ui.SIZE_SMALL, Ui.DIM)
	column.add_child(_cash_label)
	# сверху по центру: короткие сообщения, сами гаснут
	_notice_panel = Ui.panel()
	_notice_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_notice_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_notice_panel.offset_top = 18.0
	_notice_panel.modulate.a = 0.0
	layer.add_child(_notice_panel)
	_notice = Ui.label("", Ui.SIZE_TEXT)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.custom_minimum_size = Vector2(NOTICE_WIDTH, 0)
	_notice_panel.add_child(_notice)
	# итог ночи: карточка по центру на затемнённом фоне
	_summary_shade = ColorRect.new()
	_summary_shade.color = Color(0.0, 0.0, 0.0, 0.55)
	_summary_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_summary_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_summary_shade.visible = false
	layer.add_child(_summary_shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_summary_shade.add_child(center)
	var card: PanelContainer = Ui.panel(Color(0.07, 0.07, 0.08, 0.94), 18.0)
	center.add_child(card)
	_summary = VBoxContainer.new()
	_summary.add_theme_constant_override(&"separation", 5)
	_summary.custom_minimum_size = Vector2(340, 0)
	card.add_child(_summary)


## Короткое сообщение сверху на несколько секунд.
func _say(text: String, seconds: float = 4.0) -> void:
	_notice.text = text
	_notice.custom_minimum_size.x = minf(NOTICE_WIDTH, _notice.get_theme_font(&"font").get_string_size(text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.SIZE_TEXT).x + 2.0)
	_notice_panel.reset_size()
	_notice_time = seconds


func _physics_process(delta: float) -> void:
	if finished:
		return
	if not entered:
		var line: float = site.gate_position.z - 4.5   # за шлагбаумом
		if _player.global_position.z < line or van.global_position.z < line:
			_enter()
		return
	if search_in > 0.0:
		search_in -= delta
		if search_in <= 0.0:
			guard.start_search()
			_say(tr("GUARD_SEARCHING"), 6.0)
	Game.night_time += delta / run.economy.night_seconds
	if not dawn and Game.night_time >= run.economy.dawn_at:
		dawn = true
		_say(tr("NIGHT_DAWN"), 8.0)
		_siren_wait = 0.0
	if dawn:
		_siren_wait -= delta
		if _siren_wait <= 0.0:
			_siren_wait = SIREN_EVERY
			Audio.play_at(&"siren", site.booth_position + Vector3.UP * 3.0, 6.0)
	if Game.night_time >= 1.0:
		_say(tr("NIGHT_TOO_LATE"), 6.0)
		finish()


func _process(delta: float) -> void:
	if _clock == null:
		return
	_notice_time -= delta
	var want: float = 1.0 if _notice_time > 0.0 and not finished else 0.0
	_notice_panel.modulate.a = move_toward(_notice_panel.modulate.a, want, delta * 4.0)
	_clock.text = Game.clock_text()
	_clock.add_theme_color_override(&"font_color", Ui.DANGER if dawn else Ui.TEXT)
	_night_label.text = tr("NIGHT_OF") % [run.night, run.economy.nights()]
	var met: bool = run.quota_met()
	_quota_bar.value = clampf(float(run.earned) / maxf(run.quota(), 1.0), 0.0, 1.0)
	_quota_label.text = tr("NIGHT_QUOTA") % [Fmt.rub(run.earned), Fmt.rub(run.quota())]
	_quota_label.add_theme_color_override(&"font_color", Ui.GOOD if met else Ui.TEXT)
	_cash_label.text = tr("NIGHT_CASH") % Fmt.rub(run.money)


## Закончить ночь: посчитать норму, показать итог.
func finish() -> void:
	if finished:
		return
	finished = true
	var earned: int = run.earned
	var quota: int = run.quota()
	run.belt = _player.belt.ids()      # что донесли на поясе — то и осталось
	var outcome: RunState.Outcome = run.finish_night()
	Game.set_phase(Game.Phase.SUMMARY)
	Game.save_run()
	_player.scripted_input = PlayerInput.new()     # игрок замирает
	var title: String = ""
	var title_color: Color = Ui.GOOD
	var money_line: String = ""
	match outcome:
		RunState.Outcome.NIGHT_PASSED:
			title = tr("SUMMARY_PASSED") % run.night
			money_line = tr("SUMMARY_MONEY") % [Fmt.rub(earned), Fmt.rub(quota), Fmt.rub(earned - quota)]
		RunState.Outcome.WON:
			title = tr("SUMMARY_WON")
			money_line = tr("SUMMARY_MONEY") % [Fmt.rub(earned), Fmt.rub(quota), Fmt.rub(earned - quota)]
		_:
			title = tr("SUMMARY_LOST")
			title_color = Ui.DANGER
			money_line = tr("SUMMARY_SHORT") % [Fmt.rub(earned), Fmt.rub(quota)]
	summary_lines = [title, money_line]
	var head: Label = Ui.label(title, Ui.SIZE_BIG, title_color)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.add_child(head)
	var money: Label = Ui.label(money_line, Ui.SIZE_TEXT)
	money.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	money.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.add_child(money)
	_summary.add_child(HSeparator.new())
	for stat: Array in [[&"buried", "STAT_BURIED"], [&"collapses", "STAT_COLLAPSES"], [&"broken", "STAT_BROKEN"],
			[&"falls", "STAT_FALLS"], [&"sold_items", "STAT_SOLD"], [&"sneaked", "STAT_SNEAKED"], [&"caught", "STAT_CAUGHT"]]:
		var n: int = run.stats.get(stat[0], 0)
		if n > 0:
			summary_lines.append(tr(stat[1]) % n)
			_summary.add_child(Ui.label(tr(stat[1]) % n, Ui.SIZE_SMALL, Ui.DIM))
	var next: HBoxContainer = Ui.hint_row(tr("SUMMARY_NEXT") if outcome == RunState.Outcome.NIGHT_PASSED else tr("SUMMARY_AGAIN"))
	_summary.add_child(next)
	_summary_shade.visible = true
	night_finished.emit(outcome)


func _unhandled_input(event: InputEvent) -> void:
	if not finished or not auto_advance:
		return
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"jump"):
		advance()


## После итога: следующая ночь или новый забег.
func advance() -> void:
	if run.outcome == RunState.Outcome.NIGHT_PASSED:
		run.next_night()
	else:
		Game.start_run(false)
	Game.save_run()
	get_tree().node_added.disconnect(_on_node_added)
	get_tree().change_scene_to_file.call_deferred(GARAGE_SCENE)
