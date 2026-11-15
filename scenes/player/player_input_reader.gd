class_name PlayerInputReader
extends Node
## Читает клавиатуру, мышь и геймпад локального игрока.
## Обзор копится здесь и забирается контроллером каждый кадр, остальное — каждый тик.

var enabled: bool = true
var _look: Vector2 = Vector2.ZERO
var _jump_queued: bool = false
var _flop_queued: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens: float = Settings.get_value("controls", "mouse_sensitivity")
		_look += (event as InputEventMouseMotion).relative * sens
	elif event.is_action_pressed(&"jump"):
		_jump_queued = true
	elif event.is_action_pressed(&"flop"):
		_flop_queued = true
	elif event.is_action_pressed(&"pause"):
		var captured: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if captured else Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseButton and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED \
			and (event as InputEventMouseButton).pressed and not DebugMenu.is_open():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Поворот обзора с прошлого вызова, радианы (x — вправо, y — вниз).
func take_look(delta: float) -> Vector2:
	var out: Vector2 = _look
	_look = Vector2.ZERO
	if enabled and not DebugMenu.is_open():
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
		_jump_queued = false
		_flop_queued = false
		return input
	var v: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_back", &"move_forward")
	input.move = v
	input.jump_pressed = _jump_queued
	input.jump_held = Input.is_action_pressed(&"jump")
	input.crouch_held = Input.is_action_pressed(&"crouch")
	input.sprint_held = Input.is_action_pressed(&"sprint")
	input.flop_pressed = _flop_queued
	_jump_queued = false
	_flop_queued = false
	return input
