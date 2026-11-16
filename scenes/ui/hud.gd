class_name Hud
extends CanvasLayer
## Интерфейс поверх игры: прицел-точка, подсказка по предмету под прицелом,
## полоска заряда броска. Собирается кодом, читает PlayerGrab.

var _grab: PlayerGrab
var _dot: ColorRect
var _info: Label
var _charge: ProgressBar
var _player: PlayerController
var _buried: ColorRect
var _buried_material: ShaderMaterial
var _struggle_shake: float = 0.0


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

	_info = Label.new()
	_info.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_info.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_info.offset_top = 26.0
	_info.offset_left = -300.0
	_info.offset_right = 300.0
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_info.add_theme_constant_override(&"outline_size", 5)
	_info.add_theme_font_size_override(&"font_size", 18)
	root.add_child(_info)

	_charge = ProgressBar.new()
	_charge.show_percentage = false
	_charge.min_value = 0.0
	_charge.max_value = 1.0
	_charge.custom_minimum_size = Vector2(140, 8)
	_charge.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_charge.offset_left = -70.0
	_charge.offset_right = 70.0
	_charge.offset_top = 60.0
	_charge.offset_bottom = 68.0
	_charge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_charge)


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
		_info.text = tr("HUD_BURIED") % int(ceil(_player.air_left))
		return
	_buried.visible = false
	_dot.visible = true
	var target: RigidBody3D = _grab.held if _grab.held != null else _grab.focus
	_dot.color = Color(1.0, 0.75, 0.35) if target != null or _grab.focus_dump != null else Color(1, 1, 1, 0.55)
	if target != null and is_instance_valid(target):
		_info.text = _describe(target)
	elif _grab.focus_dump != null:
		var junk: ItemData = _grab.focus_dump.junk_at(_grab.focus_cell)
		_info.text = (tr(junk.name_key) + "\n" if junk != null else "") + tr("HUD_DIG_HINT")
	else:
		_info.text = ""
	_charge.visible = _grab.throw_charge > 0.02
	_charge.value = _grab.throw_charge


func _describe(body: RigidBody3D) -> String:
	var parts: PackedStringArray = []
	var item: Item = body as Item
	if item != null and item.data != null:
		parts.append(tr(item.data.name_key))
	parts.append(Fmt.kg(body.mass))
	if item != null and item.data != null and not item.data.is_trash():
		parts.append(Fmt.rub(item.value()))
	var line: String = " · ".join(parts)
	if not _grab.can_lift(body.mass):
		line += "\n" + tr("HUD_TOO_HEAVY")
	elif _grab.held == null:
		line += "\n" + tr("HUD_GRAB_HINT")
	return line
