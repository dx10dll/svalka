class_name FreeCamera
extends Camera3D
## Летающая камера для тестовых сцен, пока нет персонажа (он появится на этапе 1).
## WASD — полёт, мышь или правый стик — обзор, Shift — быстрее, ЛКМ — толкнуть предмет.

@export var speed: float = 5.0
@export var fast_multiplier: float = 3.0
@export var shove_impulse_per_kg: float = 4.0
@export var shove_reach: float = 6.0

var _yaw: float = 0.0
var _pitch: float = 0.0


func _ready() -> void:
	_yaw = rotation.y
	_pitch = rotation.x
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion: InputEventMouseMotion = event
		var sens: float = Settings.get_value("controls", "mouse_sensitivity")
		_turn(-motion.relative.x * sens, -motion.relative.y * sens)
	elif event.is_action_pressed(&"grab") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_shove()
	elif event.is_action_pressed(&"pause"):
		var captured: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if captured else Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	if DebugMenu.is_open():
		return
	var look: Vector2 = Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
	var pad_sens: float = Settings.get_value("controls", "pad_sensitivity")
	_turn(-look.x * pad_sens * delta, -look.y * pad_sens * delta)
	var move: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var lift: float = Input.get_axis(&"crouch", &"jump")
	var dir: Vector3 = global_basis * Vector3(move.x, 0.0, move.y) + Vector3.UP * lift
	var v: float = speed * (fast_multiplier if Input.is_action_pressed(&"sprint") else 1.0)
	global_position += dir * v * delta


func _turn(dyaw: float, dpitch: float) -> void:
	_yaw += dyaw
	_pitch = clampf(_pitch + dpitch, -1.5, 1.5)
	rotation = Vector3(_pitch, _yaw, 0.0)


## Толкнуть тело под прицелом: быстрый способ проверить физику без персонажа.
func _shove() -> void:
	var from: Vector3 = global_position
	var to: Vector3 = from - global_basis.z * shove_reach
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(from, to))
	if hit.is_empty():
		return
	var body: RigidBody3D = hit["collider"] as RigidBody3D
	if body != null:
		var push: Vector3 = (-global_basis.z + Vector3.UP * 0.35).normalized()
		body.apply_impulse(push * shove_impulse_per_kg * body.mass,
				(hit["position"] as Vector3) - body.global_position)
