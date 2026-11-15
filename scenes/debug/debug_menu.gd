extends CanvasLayer
## Отладочное меню на F1: спавн предметов, время ночи, показ чанков, бессмертие,
## искусственный пинг, язык. Собирается кодом, чтобы не зависеть от сцен.
## Сверху всегда видна строка: кадры, активные тела, часы свалки.

signal spawn_requested(item_data: ItemData)
signal clear_requested

const SCENES: Array = [
	["SCENE_DUMP", "res://scenes/debug/playground_dump.tscn"],
	["SCENE_STAGE1", "res://scenes/debug/playground_stage1.tscn"],
	["SCENE_STAGE0", "res://scenes/debug/test_scene.tscn"],
]
const ACTIVE_BODY_BUDGET: int = 150  # цель из промта: не больше ~150 активных тел

var _panel: PanelContainer
var _stats: Label
var _time_slider: HSlider
var _mouse_mode_before: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_panel.visible = false


func is_open() -> bool:
	return _panel.visible


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_menu"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	_panel.visible = not _panel.visible
	if _panel.visible:
		_mouse_mode_before = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = _mouse_mode_before


func _process(_delta: float) -> void:
	var bodies: int = int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS))
	_stats.text = tr("DEBUG_STATS") % [Engine.get_frames_per_second(), bodies, Game.clock_text()]
	_stats.modulate = Color(1.0, 0.45, 0.35) if bodies > ACTIVE_BODY_BUDGET else Color.WHITE


func _build() -> void:
	_stats = Label.new()
	_stats.position = Vector2(12, 8)
	_stats.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_stats.add_theme_constant_override(&"outline_size", 4)
	add_child(_stats)

	_panel = PanelContainer.new()
	_panel.position = Vector2(12, 40)
	_panel.custom_minimum_size = Vector2(340, 0)
	add_child(_panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 8)
	margin.add_child(box)

	var title := Label.new()
	title.text = "DEBUG_TITLE"
	title.add_theme_font_size_override(&"font_size", 20)
	box.add_child(title)

	# тестовые сцены
	box.add_child(_caption("DEBUG_SCENES"))
	for entry: Array in SCENES:
		var sb := Button.new()
		sb.text = entry[0]
		sb.pressed.connect(func() -> void:
			toggle()
			get_tree().change_scene_to_file(entry[1]))
		box.add_child(sb)

	# спавн предметов
	box.add_child(_caption("DEBUG_SPAWN"))
	for item_data: ItemData in ItemDb.all():
		var b := Button.new()
		b.text = item_data.name_key
		b.pressed.connect(func() -> void: spawn_requested.emit(item_data))
		box.add_child(b)
	var clear := Button.new()
	clear.text = "DEBUG_CLEAR"
	clear.pressed.connect(func() -> void: clear_requested.emit())
	box.add_child(clear)

	# время ночи
	box.add_child(_caption("DEBUG_TIME"))
	_time_slider = HSlider.new()
	_time_slider.min_value = 0.0
	_time_slider.max_value = 1.0
	_time_slider.step = 0.005
	_time_slider.value = Game.night_time
	_time_slider.value_changed.connect(func(v: float) -> void: Game.night_time = v)
	box.add_child(_time_slider)

	box.add_child(_flag_toggle("DEBUG_GOD", &"god_mode"))
	box.add_child(_flag_toggle("DEBUG_CHUNKS", &"show_chunks"))

	# искусственный пинг
	var ping_row := HBoxContainer.new()
	var ping_label := _caption("DEBUG_PING")
	ping_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ping_row.add_child(ping_label)
	var ping := SpinBox.new()
	ping.min_value = 0
	ping.max_value = 500
	ping.step = 10
	ping.value = Net.simulated_ping_ms
	ping.value_changed.connect(func(v: float) -> void: Net.simulated_ping_ms = int(v))
	ping_row.add_child(ping)
	box.add_child(ping_row)

	# язык
	var lang_row := HBoxContainer.new()
	var lang_label := _caption("DEBUG_LANG")
	lang_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lang_row.add_child(lang_label)
	for code: String in ["ru", "en"]:
		var lb := Button.new()
		lb.text = code.to_upper()
		lb.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		lb.pressed.connect(func() -> void: Settings.set_value("game", "locale", code))
		lang_row.add_child(lb)
	box.add_child(lang_row)


func _caption(key: String) -> Label:
	var l := Label.new()
	l.text = key
	l.modulate = Color(1, 1, 1, 0.75)
	return l


func _flag_toggle(key: String, flag: StringName) -> CheckButton:
	var c := CheckButton.new()
	c.text = key
	c.button_pressed = Game.debug_flag(flag)
	c.toggled.connect(func(on: bool) -> void: Game.set_debug_flag(flag, on))
	return c
