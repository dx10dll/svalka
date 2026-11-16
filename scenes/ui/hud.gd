class_name Hud
extends CanvasLayer
## Интерфейс поверх игры: прицел-точка, подсказка по предмету под прицелом,
## полоска заряда броска. Собирается кодом, читает PlayerGrab.

const SEAT_HINT_SECONDS: float = 8.0

var _grab: PlayerGrab
var _dot: ColorRect
var _prompt: PanelContainer
var _prompt_rows: VBoxContainer
var _prompt_text: String = ""
var _prompt_low: bool = false
var _charge: ProgressBar
## Сколько секунд сидим: подсказка по клавишам потом прячется
var _seat_time: float = 0.0
var _player: PlayerController
var _buried: ColorRect
var _buried_material: ShaderMaterial
var _struggle_shake: float = 0.0
var _belt: HBoxContainer


func setup(grab: PlayerGrab) -> void:
	_grab = grab
	layer = 5
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# вид из-под завала: темнота со щелями, поверх мира и под надписями
	_player = grab.get_parent() as PlayerController
	_buried = ColorRect.new()
	_buried.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_buried.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buried_material = ShaderMaterial.new()
	_buried_material.shader = load("res://assets/shaders/buried.gdshader")
	_buried.material = _buried_material
	_buried.visible = false
	root.add_child(_buried)
	if _player != null:
		_player.struggled.connect(func() -> void: _struggle_shake = 1.0)

	_dot = ColorRect.new()
	_dot.size = Vector2(4, 4)
	_dot.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_dot)

	# подсказка под прицелом: маленькая плашка, строки с клавишами
	_prompt = Ui.panel()
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.visible = false
	root.add_child(_prompt)
	_prompt_rows = VBoxContainer.new()
	_prompt_rows.add_theme_constant_override(&"separation", 3)
	_prompt_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.add_child(_prompt_rows)

	# пояс: три ячейки слева внизу
	_belt = HBoxContainer.new()
	_belt.add_theme_constant_override(&"separation", 4)
	_belt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_belt.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_belt.offset_left = 14.0
	_belt.offset_bottom = -14.0
	_belt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_belt)
	if _player != null and _player.belt != null:
		_player.belt.changed.connect(_update_belt)
		_update_belt()

	_charge = Ui.bar(110.0, 4.0)
	_charge.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_charge.offset_left = -55.0
	_charge.offset_right = 55.0
	_charge.offset_top = 18.0
	_charge.offset_bottom = 22.0
	_charge.visible = false
	root.add_child(_charge)


## Показать подсказку. Первая строка без клавиш — заголовок, остальные — ряды клавиш.
## low — прижать к низу экрана (за рулём), иначе под прицелом.
func _show(text: String, low: bool = false) -> void:
	if text == _prompt_text and low == _prompt_low:
		return
	_prompt_text = text
	_prompt_low = low
	for child: Node in _prompt_rows.get_children():
		_prompt_rows.remove_child(child)
		child.queue_free()
	_prompt.visible = not text.is_empty()
	if text.is_empty():
		return
	var first: bool = true
	for line: String in text.split("\n"):
		if line.is_empty():
			continue
		if first and not line.contains(" — "):
			var title: Label = Ui.label(line, Ui.SIZE_TEXT)
			title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_prompt_rows.add_child(title)
		else:
			_prompt_rows.add_child(Ui.hint_row(line))
		first = false
	_prompt.reset_size()
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM if low else Control.PRESET_CENTER)
	_prompt.grow_vertical = Control.GROW_DIRECTION_BEGIN if low else Control.GROW_DIRECTION_END
	_prompt.offset_top = -60.0 if low else 34.0
	_prompt.offset_bottom = -60.0 if low else 34.0
	_prompt.offset_left = 0.0
	_prompt.offset_right = 0.0


func _process(delta: float) -> void:
	if _grab == null:
		return
	if _player != null and _player.mode == PlayerController.Mode.BURIED:
		_struggle_shake = maxf(_struggle_shake - delta * 3.0, 0.0)
		_buried.visible = true
		_buried_material.set_shader_parameter(&"open", _player.dug_out_amount())
		_buried_material.set_shader_parameter(&"shake", _struggle_shake)
		_dot.visible = false
		_charge.visible = false
		_show(tr("HUD_BURIED") % int(ceil(_player.air_left)), true)
		return
	_buried.visible = false
	if _player != null and _player.mode == PlayerController.Mode.SEATED:
		var van: Van = _player.vehicle
		_dot.visible = false
		_charge.visible = false
		_seat_time += delta
		var keys: bool = _seat_time < SEAT_HINT_SECONDS     # клавиши показываем только первые секунды
		if van == null:
			var tub: Item = _player.ride
			var tub_line: String = "%d %s" % [int(tub.linear_velocity.length() * 3.6) if is_instance_valid(tub) else 0, tr("UNIT_KMH")]
			_show(tub_line + ("\n" + tr("HUD_RIDE") if keys else ""), true)
			return
		var line: String = "%d %s  ·  %s" % [int(absf(van.forward_speed()) * 3.6), tr("UNIT_KMH"), _cargo_line(van)]
		if van.stalled and van.driver == _player:
			line += "\n" + tr("HUD_VAN_STALLED")
		elif keys:
			line += "\n" + (tr("HUD_VAN_LEAVE") if van.driver == _player else tr("HUD_VAN_LEAVE_PASSENGER"))
		_show(line, true)
		return
	_seat_time = 0.0
	_dot.visible = true
	var target: RigidBody3D = _grab.held if _grab.held != null else _grab.focus
	_dot.color = Ui.ACCENT if target != null or _grab.focus_dump != null else Color(1, 1, 1, 0.55)
	var text: String = ""
	if target != null and is_instance_valid(target):
		text = _describe(target)
		if _grab.held == null and not _grab.focus_action.is_empty():
			text += "\n" + _grab.focus_action.get("text", tr(_grab.focus_action.get("hint", "")))
	elif _grab.focus_dump != null:
		var junk: ItemData = _grab.focus_dump.junk_at(_grab.focus_cell)
		text = (tr(junk.name_key) + "\n" if junk != null else "") + tr("HUD_DIG_HINT")
	elif _grab.focus_van != null:
		_dot.color = Ui.ACCENT
		text = _cargo_line(_grab.focus_van)
		var van_hints: String = tr("HINT_VAN_PUSH")
		if not _grab.focus_action.is_empty():
			van_hints = tr(_grab.focus_action["hint"]) + " · " + van_hints
		text += "\n" + van_hints
	elif _grab.focus_use != null and not _grab.focus_action.is_empty():
		_dot.color = Ui.ACCENT
		text = _grab.focus_action.get("text", tr(_grab.focus_action.get("hint", "")))
	_show(text)
	_charge.visible = _grab.throw_charge > 0.02
	_charge.value = _grab.throw_charge


func _update_belt() -> void:
	for child: Node in _belt.get_children():
		_belt.remove_child(child)
		child.queue_free()
	for i: int in PlayerBelt.SLOTS:
		var item: Item = _player.belt.slots[i]
		var cell: PanelContainer = Ui.panel(Ui.BACK if item != null else Color(0.05, 0.05, 0.06, 0.4), 6.0)
		cell.custom_minimum_size = Vector2(92, 0)
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 6)
		row.add_child(Ui.label(str(i + 1), Ui.SIZE_SMALL, Ui.ACCENT))
		row.add_child(Ui.label(tr(item.data.name_key) if item != null else "—", Ui.SIZE_SMALL, Ui.TEXT if item != null else Ui.DIM))
		cell.add_child(row)
		_belt.add_child(cell)


## Груз машины: сколько лежит и сколько можно; перегруз — с пометкой.
func _cargo_line(van: Van) -> String:
	var load_kg: float = van.cargo_mass()
	var line: String = tr("HUD_VAN_CARGO") % [Fmt.kg(load_kg), Fmt.kg(van.feel.capacity)]
	if load_kg > van.feel.capacity:
		line += " · " + tr("HUD_VAN_OVERLOAD")
	return line


func _describe(body: RigidBody3D) -> String:
	var parts: PackedStringArray = []
	var item: Item = body as Item
	if item != null and item.data != null:
		parts.append(tr(item.data.name_key))
	parts.append(Fmt.kg(body.mass))
	if item != null and item.data != null and not item.data.is_trash() and not item.data.is_tool():
		parts.append(Fmt.rub(item.value()))
	var line: String = " · ".join(parts)
	if not _grab.can_lift(body.mass):
		line += "\n" + tr("HUD_TOO_HEAVY")
	elif _grab.held == null:
		line += "\n" + tr("HUD_TOOL_HINT" if item != null and item.data.is_tool() else "HUD_GRAB_HINT")
	elif item != null and _player != null and _player.belt.can_stow(item) and _player.belt.free_slot() >= 0:
		line += "\n" + tr("HUD_BELT_HINT")
	return line
