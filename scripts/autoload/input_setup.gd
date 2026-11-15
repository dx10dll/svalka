extends Node
## Карта управления: клавиатура, мышь и геймпад. Единственное место, где заданы
## кнопки по умолчанию. Действия создаются при запуске, поэтому в окне
## «Проект → Список действий» редактора их не видно — так позже проще сделать
## переназначение из настроек игры.
##
## Клавиши заданы физическими кодами: WASD работает и в русской раскладке.

const DEADZONE: float = 0.2

## действие -> список привязок. Привязка: ["key", Key], ["mouse", MouseButton],
## ["pad", JoyButton] или ["axis", JoyAxis, знак].
const DEFAULTS: Dictionary = {
	&"move_forward": [["key", KEY_W], ["axis", JOY_AXIS_LEFT_Y, -1.0]],
	&"move_back": [["key", KEY_S], ["axis", JOY_AXIS_LEFT_Y, 1.0]],
	&"move_left": [["key", KEY_A], ["axis", JOY_AXIS_LEFT_X, -1.0]],
	&"move_right": [["key", KEY_D], ["axis", JOY_AXIS_LEFT_X, 1.0]],
	&"look_up": [["axis", JOY_AXIS_RIGHT_Y, -1.0]],
	&"look_down": [["axis", JOY_AXIS_RIGHT_Y, 1.0]],
	&"look_left": [["axis", JOY_AXIS_RIGHT_X, -1.0]],
	&"look_right": [["axis", JOY_AXIS_RIGHT_X, 1.0]],
	&"jump": [["key", KEY_SPACE], ["pad", JOY_BUTTON_A]],
	&"crouch": [["key", KEY_CTRL], ["pad", JOY_BUTTON_B]],
	&"sprint": [["key", KEY_SHIFT], ["pad", JOY_BUTTON_LEFT_STICK]],
	&"grab": [["mouse", MOUSE_BUTTON_LEFT], ["axis", JOY_AXIS_TRIGGER_RIGHT, 1.0]],
	&"throw": [["mouse", MOUSE_BUTTON_RIGHT], ["axis", JOY_AXIS_TRIGGER_LEFT, 1.0]],
	&"interact": [["key", KEY_E], ["pad", JOY_BUTTON_X]],
	&"drop": [["key", KEY_G], ["pad", JOY_BUTTON_DPAD_DOWN]],
	&"flashlight": [["key", KEY_F], ["pad", JOY_BUTTON_Y]],
	&"slot_1": [["key", KEY_1], ["pad", JOY_BUTTON_DPAD_LEFT]],
	&"slot_2": [["key", KEY_2], ["pad", JOY_BUTTON_DPAD_UP]],
	&"slot_3": [["key", KEY_3], ["pad", JOY_BUTTON_DPAD_RIGHT]],
	&"gesture": [["key", KEY_C], ["pad", JOY_BUTTON_RIGHT_STICK]],
	&"push_to_talk": [["key", KEY_V], ["pad", JOY_BUTTON_RIGHT_SHOULDER]],
	&"radio": [["key", KEY_T], ["pad", JOY_BUTTON_LEFT_SHOULDER]],
	&"pause": [["key", KEY_ESCAPE], ["pad", JOY_BUTTON_START]],
	&"debug_menu": [["key", KEY_F1]],
}


func _enter_tree() -> void:
	apply_defaults()


## Сбросить все действия к значениям по умолчанию.
func apply_defaults() -> void:
	for action: StringName in DEFAULTS:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action, DEADZONE)
		for binding: Array in DEFAULTS[action]:
			InputMap.action_add_event(action, _make_event(binding))


func _make_event(binding: Array) -> InputEvent:
	match binding[0]:
		"key":
			var k := InputEventKey.new()
			k.physical_keycode = binding[1]
			return k
		"mouse":
			var m := InputEventMouseButton.new()
			m.button_index = binding[1]
			return m
		"pad":
			var b := InputEventJoypadButton.new()
			b.button_index = binding[1]
			return b
		"axis":
			var a := InputEventJoypadMotion.new()
			a.axis = binding[1]
			a.axis_value = binding[2]
			return a
	push_error("Неизвестный тип привязки: %s" % [binding])
	return null
