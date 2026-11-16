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
var dawn: bool = false
## Въехали на свалку: с этого момента идут часы
var entered: bool = false

var _hud: Label
var _notice: Label
var _summary: Label
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
	_build_hud()
	_say(tr("NIGHT_START") % [run.night, run.economy.nights(), Fmt.rub(run.quota())], 8.0)


func guard_fee() -> int:
	return run.economy.guard_fee_for(run.night)


func _guard_hint() -> String:
	if run.guard_paid or finished:
		return ""
	if run.money < guard_fee():
		return tr("GUARD_NO_MONEY") % Fmt.rub(guard_fee())
	return tr("GUARD_PAY") % Fmt.rub(guard_fee())


func _pay_guard(_player_who: PlayerController) -> void:
	pay_guard()


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


## Кто-то пересёк линию ворот: часы пошли. Без оплаты — значит, пролезли.
func _enter() -> void:
	entered = true
	Game.set_phase(Game.Phase.LANDFILL)
	if not run.guard_paid:
		run.sneaked = true
		run.count(&"sneaked")
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
	_hud = _label(layer, 20)
	_hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_hud.offset_top = 10.0
	_notice = _label(layer, 26)
	_notice.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_notice.offset_top = 90.0
	_summary = _label(layer, 30)
	_summary.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_summary.visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.show_behind_parent = true
	_summary.add_child(shade)


func _label(layer: CanvasLayer, font_size: int) -> Label:
	var label := Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	label.add_theme_constant_override(&"outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(label)
	return label


## Крупная надпись под часами на несколько секунд.
func _say(text: String, seconds: float = 4.0) -> void:
	_notice.text = text
	_notice_time = seconds


func _physics_process(delta: float) -> void:
	if finished:
		return
	if not entered:
		var line: float = site.gate_position.z - 4.5   # за шлагбаумом
		if _player.global_position.z < line or van.global_position.z < line:
			_enter()
		return
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
	if _hud == null:
		return
	_notice_time -= delta
	_notice.visible = _notice_time > 0.0 and not finished
	_hud.text = tr("NIGHT_HUD") % [run.night, run.economy.nights(), Game.clock_text(),
			Fmt.rub(run.earned), Fmt.rub(run.quota()), Fmt.rub(run.money)]
	_hud.modulate = Color(1.0, 0.6, 0.5) if dawn else Color.WHITE


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
	var lines: PackedStringArray = []
	match outcome:
		RunState.Outcome.NIGHT_PASSED:
			lines.append(tr("SUMMARY_PASSED") % run.night)
			lines.append(tr("SUMMARY_MONEY") % [Fmt.rub(earned), Fmt.rub(quota), Fmt.rub(earned - quota)])
		RunState.Outcome.WON:
			lines.append(tr("SUMMARY_WON"))
			lines.append(tr("SUMMARY_MONEY") % [Fmt.rub(earned), Fmt.rub(quota), Fmt.rub(earned - quota)])
		_:
			lines.append(tr("SUMMARY_LOST"))
			lines.append(tr("SUMMARY_SHORT") % [Fmt.rub(earned), Fmt.rub(quota)])
	lines.append("")
	for stat: Array in [[&"buried", "STAT_BURIED"], [&"collapses", "STAT_COLLAPSES"], [&"broken", "STAT_BROKEN"],
			[&"falls", "STAT_FALLS"], [&"sold_items", "STAT_SOLD"], [&"sneaked", "STAT_SNEAKED"]]:
		var n: int = run.stats.get(stat[0], 0)
		if n > 0:
			lines.append(tr(stat[1]) % n)
	lines.append("")
	lines.append(tr("SUMMARY_NEXT") if outcome == RunState.Outcome.NIGHT_PASSED else tr("SUMMARY_AGAIN"))
	_summary.text = "\n".join(lines)
	_summary.visible = true
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
