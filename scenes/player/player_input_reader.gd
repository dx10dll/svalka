class_name PlayerInputReader
extends Node
## Читает клавиатуру, мышь и геймпад локального игрока.
## Обзор копится здесь и забирается контроллером каждый кадр, остальное — каждый тик.

var enabled: bool = true
var _look: Vector2 = Vector2.ZERO
var _jump_queued: bool = false
var _flop_queued: bool = false
var _flashlight_queued: bool = false
var _interact_queued: bool = false
var _slot_queued: int = 0
var _drop_queued: bool = false
## Была ли мышь вообще: с геймпадом захват курсора не обязателен
var _mouse_seen: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouse:
		_mouse_seen = true
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens: float = Settings.get_value("controls", "mouse_sensitivity")
		_look += (event as InputEventMouseMotion).relative * sens
	elif event.is_action_pressed(&"jump"):
		_jump_queued = true
	elif event.is_action_pressed(&"flop"):
		_flop_queued = true
	elif event.is_action_pressed(&"flashlight"):
		_flashlight_queued = true
	elif event.is_action_pressed(&"interact"):
		_interact_queued = true
	elif event.is_action_pressed(&"slot_1"):
		_slot_queued = 1
	elif event.is_action_pressed(&"slot_2"):
		_slot_queued = 2
	elif event.is_action_pressed(&"slot_3"):
		_slot_queued = 3
	elif event.is_action_pressed(&"slot_4"):
		_slot_queued = 4
	elif event.is_action_pressed(&"drop_item"):
		_drop_queued = true
	elif event is InputEventMouseButton and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED \
			and (event as InputEventMouseButton).pressed and not DebugMenu.is_open() and not PauseMenu.is_open():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Поворот обзора с прошлого вызова, радианы (x — вправо, y — вниз).
func take_look(delta: float) -> Vector2:
	var out: Vector2 = _look
	_look = Vector2.ZERO
	if enabled and not DebugMenu.is_open() and not PauseMenu.is_open():
		var stick: Vector2 = Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
		var pad_sens: float = Settings.get_value("controls", "pad_sensitivity")
		out += stick * stick.length() * pad_sens * delta  # квадратичная кривая: точнее у центра
	if Settings.get_value("controls", "invert_y"):
		out.y = -out.y
	return out


## Ввод для физического тика.
func sample() -> PlayerInput:
	var input := PlayerInput.new()
	if not enabled or DebugMenu.is_open():
		_flashlight_queued = false
		_interact_queued = false
		_slot_queued = 0
		_jump_queued = false
		_flop_queued = false
		return input
	var v: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_back", &"move_forward")
	input.move = v
	input.jump_pressed = _jump_queued
	input.jump_held = Input.is_action_pressed(&"jump")
	input.crouch_held = Input.is_action_pressed(&"crouch")
	input.sprint_held = Input.is_action_pressed(&"sprint")
	var captured: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or not _mouse_seen
	input.grab_held = captured and Input.is_action_pressed(&"grab")
	input.throw_held = captured and Input.is_action_pressed(&"throw")
	input.flop_pressed = _flop_queued
	input.flashlight_pressed = _flashlight_queued
	input.interact_pressed = _interact_queued
	_interact_queued = false
	input.slot_pressed = _slot_queued
	_slot_queued = 0
	input.drop_pressed = _drop_queued
	_drop_queued = false
	_flashlight_queued = false
	_jump_queued = false
	_flop_queued = false
	return input
