extends CanvasLayer
## Меню по Esc: продолжить, чувствительность мыши, громкость, полный экран, выход.
## В одиночной игре мир на паузе; в сети (этап 7) пауза будет только у меню.

const CARD_WIDTH: float = 300.0

var _shade: ColorRect
var _mouse_before: Input.MouseMode = Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_apply_audio()
	_apply_fullscreen()
	if OS.get_cmdline_user_args().has("--demo-pause"):
		_shade.visible = true      # для снимков интерфейса: показать меню, не останавливая мир


func is_open() -> bool:
	return _shade.visible


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		set_open(not is_open())
		get_viewport().set_input_as_handled()


func set_open(open: bool) -> void:
	if open == is_open():
		return
	_shade.visible = open
	get_tree().paused = open
	if open:
		_mouse_before = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = _mouse_before


func _build() -> void:
	_shade = ColorRect.new()
	_shade.color = Color(0.0, 0.0, 0.0, 0.5)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.visible = false
	add_child(_shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.add_child(center)
	var card: PanelContainer = Ui.panel(Color(0.07, 0.07, 0.08, 0.95), 18.0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(card)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	column.add_theme_constant_override(&"separation", 8)
	card.add_child(column)
	var title: Label = Ui.label(tr("PAUSE_TITLE"), Ui.SIZE_BIG)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	column.add_child(_button("PAUSE_RESUME", func() -> void: set_open(false)))
	column.add_child(HSeparator.new())
	column.add_child(_slider("PAUSE_SENSITIVITY", 0.0006, 0.006, Settings.get_value("controls", "mouse_sensitivity"),
			func(v: float) -> void: Settings.set_value("controls", "mouse_sensitivity", v)))
	column.add_child(_slider("PAUSE_VOLUME", 0.0, 1.0, Settings.get_value("audio", "master"),
			func(v: float) -> void:
				Settings.set_value("audio", "master", v)
				_apply_audio()))
	var full := CheckBox.new()
	full.text = tr("PAUSE_FULLSCREEN")
	full.add_theme_font_size_override(&"font_size", Ui.SIZE_TEXT)
	full.button_pressed = Settings.get_value("video", "fullscreen")
	full.toggled.connect(func(on: bool) -> void:
		Settings.set_value("video", "fullscreen", on)
		_apply_fullscreen())
	column.add_child(full)
	column.add_child(HSeparator.new())
	column.add_child(_button("PAUSE_QUIT", func() -> void: get_tree().quit()))


func _button(key: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = tr(key)
	button.add_theme_font_size_override(&"font_size", Ui.SIZE_TEXT)
	button.add_theme_color_override(&"font_color", Ui.TEXT)
	button.add_theme_color_override(&"font_hover_color", Ui.ACCENT)
	button.add_theme_stylebox_override(&"normal", Ui.box(Color(1.0, 1.0, 1.0, 0.07), 8.0))
	button.add_theme_stylebox_override(&"hover", Ui.box(Color(1.0, 0.75, 0.35, 0.18), 8.0))
	button.add_theme_stylebox_override(&"pressed", Ui.box(Color(1.0, 0.75, 0.35, 0.3), 8.0))
	button.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	button.pressed.connect(action)
	return button


func _slider(key: String, from: float, to: float, value: float, on_change: Callable) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 1)
	box.add_child(Ui.label(tr(key), Ui.SIZE_SMALL, Ui.DIM))
	var slider := HSlider.new()
	slider.min_value = from
	slider.max_value = to
	slider.step = (to - from) / 100.0
	slider.value = value
	slider.value_changed.connect(on_change)
	box.add_child(slider)
	return box


func _apply_audio() -> void:
	var volume: float = Settings.get_value("audio", "master")
	AudioServer.set_bus_mute(0, volume <= 0.001)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.001)))


func _apply_fullscreen() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var on: bool = Settings.get_value("video", "fullscreen")
	var want: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want and not (not on and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED):
		DisplayServer.window_set_mode(want)
