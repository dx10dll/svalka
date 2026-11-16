class_name GuardDog
extends CharacterBody3D
## Пёс сторожа. Пока сторож в будке — лежит рядом. Сторож вышел искать — пёс бежит
## впереди: чует игрока без всякого света, подбегает и лает, а на лай идёт сторож.
## Сам не ловит. Колбаса на земле важнее любого игрока. На гору не лезет.

signal state_changed(state: State)

enum State { REST, HEEL, TRACK, BARK, EAT }

const MODEL: String = "res://assets/models/characters/dog.glb"

var config: GuardConfig
var guard: Guard
var state: State = State.REST
var target: PlayerController
var food: Item

var _goal := Vector3.ZERO
var _bark_wait: float = 0.0
var _eat_left: float = 0.0
var _scan_wait: float = 0.0
var _model: Node3D
var _phase: float = 0.0
var _bark_kick: float = 0.0


func _ready() -> void:
	if config == null:
		config = load(Guard.CONFIG_PATH)
	add_to_group(&"guard_dogs")
	collision_layer = 0          # пса нельзя подпереть вещами и он никого не толкает
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.25
	capsule.height = 0.7
	shape.shape = capsule
	shape.position.y = 0.35
	add_child(shape)
	_model = (load(MODEL) as PackedScene).instantiate()
	add_child(_model)


## Привязать к сторожу: пёс живёт при нём.
func setup(owner_guard: Guard) -> void:
	guard = owner_guard
	global_position = guard.booth_point + Vector3(0.9, 0.0, 0.8)
	_goal = global_position


func _set_state(next: State) -> void:
	if next == state:
		return
	state = next
	state_changed.emit(state)


func _physics_process(delta: float) -> void:
	var speed: float = _think(delta) if Net.is_host() and is_instance_valid(guard) else 0.0
	_move(speed, delta)
	_animate(delta)


func _think(delta: float) -> float:
	var working: bool = guard.state != Guard.State.BOOTH and guard.state != Guard.State.RETURN
	if state == State.EAT:
		_eat_left -= delta
		if _eat_left <= 0.0 or not is_instance_valid(food):
			if is_instance_valid(food):
				food.queue_free()
			food = null
			_set_state(State.HEEL if working else State.REST)
		return 0.0
	_scan_wait -= delta
	if _scan_wait <= 0.0:
		_scan_wait = 0.3
		_sniff(working)
	if is_instance_valid(food):
		# колбаса: бежит к ней, что бы ни происходило
		_goal = guard.ground_point(food.global_position)
		if _flat_distance(food.global_position) < 0.9:
			_eat_left = config.dog_eat_time
			food.freeze = true
			_set_state(State.EAT)
			return 0.0
		return config.dog_run_speed
	if not working:
		_goal = guard.booth_point + Vector3(0.9, 0.0, 0.8)
		_set_state(State.REST)
		var home: float = _flat_distance(_goal)
		return 0.0 if home < 0.5 else (config.dog_run_speed if home > 6.0 else config.dog_walk_speed)
	if is_instance_valid(target):
		var away: float = _flat_distance(target.global_position)
		var lost: bool = global_position.distance_to(target.global_position) > config.dog_smell_range * 1.6 \
				or target.mode == PlayerController.Mode.SEATED or target.mode == PlayerController.Mode.BURIED
		if lost:
			target = null
		elif away < config.dog_bark_distance or _flat_distance(guard.ground_point(target.global_position)) < 0.8:
			# рядом (или игрок на горе, а пёс под ним): стоит и лает, зовёт сторожа
			_set_state(State.BARK)
			_face(target.global_position, delta)
			_bark_wait -= delta
			if _bark_wait <= 0.0:
				bark()
			return 0.0
		else:
			_goal = guard.ground_point(target.global_position)
			_set_state(State.TRACK)
			return config.dog_run_speed
	# идёт у ноги сторожа, чуть впереди
	_set_state(State.HEEL)
	_goal = guard.global_position - guard.global_basis.z * 2.2 + guard.global_basis.x * 0.9
	var gap: float = _flat_distance(_goal)
	return 0.0 if gap < 0.6 else (config.dog_run_speed if gap > 5.0 else config.dog_walk_speed * 1.3)


## Лай: слышно далеко, сторож идёт на звук.
func bark() -> void:
	_bark_wait = config.dog_bark_every
	_bark_kick = 1.0
	Audio.play_at(&"bark", global_position + Vector3.UP * 0.5, 2.0, randf_range(0.9, 1.1))
	Game.make_noise(global_position, config.dog_bark_noise)


## Нюх: колбаса на земле и игроки поблизости (свет и стены не важны).
func _sniff(working: bool) -> void:
	if not is_instance_valid(food):
		food = null
		for node: Node in get_tree().get_nodes_in_group(&"items"):
			var item: Item = node as Item
			if item != null and item.data != null and item.data.tool == &"sausage" and item.is_inside_tree() \
					and global_position.distance_to(item.global_position) < config.dog_food_range:
				food = item
				break
	if not working or is_instance_valid(target):
		return
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var player: PlayerController = node as PlayerController
		if player != null and player.mode != PlayerController.Mode.SEATED \
				and global_position.distance_to(player.global_position) < config.dog_smell_range:
			target = player
			return


func _flat_distance(to: Vector3) -> float:
	return Vector2(to.x - global_position.x, to.z - global_position.z).length()


func _face(at: Vector3, delta: float) -> void:
	var to: Vector3 = at - global_position
	rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-8.0 * delta))


func _move(speed: float, delta: float) -> void:
	var to: Vector3 = _goal - global_position
	to.y = 0.0
	var dir := Vector3.ZERO
	if speed > 0.0 and to.length() > 0.2:
		dir = guard.steer_from(global_position, to.normalized())
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-9.0 * delta))
	velocity.x = move_toward(velocity.x, dir.x * speed, 30.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, 30.0 * delta)
	velocity.y = velocity.y - 20.0 * delta if not is_on_floor() else -0.5
	move_and_slide()


## Картинка: скачет на бегу, подпрыгивает на лае, ест — мордой вниз.
func _animate(delta: float) -> void:
	var moving: float = clampf(Vector2(velocity.x, velocity.z).length() / maxf(config.dog_run_speed, 0.1), 0.0, 1.0)
	_phase += delta * (6.0 + moving * 12.0) * (1.0 if moving > 0.02 else 0.0)
	_bark_kick = move_toward(_bark_kick, 0.0, delta * 5.0)
	_model.position.y = absf(sin(_phase)) * 0.09 * moving + _bark_kick * 0.08
	var nod: float = 0.5 if state == State.EAT else (-0.35 * _bark_kick + sin(_phase) * 0.12 * moving)
	_model.rotation.x = lerpf(_model.rotation.x, nod, 1.0 - exp(-12.0 * delta))
	if state == State.REST and moving < 0.02:
		_model.position.y = -0.12           # лежит
