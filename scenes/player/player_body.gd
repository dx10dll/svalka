class_name PlayerBody
extends Node3D
## Видимое тело персонажа: модель, выбор анимации по состоянию контроллера,
## пружинки (живот, кепка), рэгдолл. Только читает контроллер.
##
## Для своего игрока голова не рисуется (остаётся только её тень), а тело чуть
## сдвинуто назад, чтобы камера не оказывалась внутри груди.

const MODEL_PATH: String = "res://assets/models/characters/man.glb"
const LOOPED: Array[StringName] = [&"idle", &"walk", &"run", &"crouch_idle", &"crouch_walk", &"air"]
## Модель из Blender смотрит в +Z, а «вперёд» у игрока — это -Z
const MODEL_TURN: float = PI

## Насколько тело отодвинуто назад от оси игрока в виде от первого лица, м
@export var first_person_back_offset: float = 0.2
@export var blend_time: float = 0.16

var skeleton: Skeleton3D
var anim: AnimationPlayer
var ragdoll: Ragdoll

var _player: PlayerController
var _model: Node3D
var _head_mesh: MeshInstance3D
var _current: StringName = &""
var _one_shot_left: float = 0.0
var _springs: BoneSprings
var _back_offset: float = 0.0
var _arms: LimbIk
var _arm_l: int = -1
var _arm_r: int = -1
var _shoulder_l: int = -1
var _shoulder_r: int = -1

## Дальше этого от плеча кисть до точки хвата не дотянется, м
const ARM_REACH: float = 0.62
## Если у предмета нет удобных точек хвата — руки по бокам от точки захвата, м
const HAND_SPREAD: float = 0.13


func setup(player: PlayerController, first_person: bool) -> void:
	_player = player
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_model = (load(MODEL_PATH) as PackedScene).instantiate()
	add_child(_model)
	skeleton = _model.find_child("Skeleton3D", true, false)
	anim = _model.find_child("AnimationPlayer", true, false)
	_head_mesh = _model.find_child("mesh_head", true, false)
	for clip: StringName in LOOPED:
		if anim.has_animation(clip):
			anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	anim.playback_default_blend_time = blend_time
	_back_offset = first_person_back_offset
	set_first_person(first_person)

	_springs = BoneSprings.new()
	_springs.name = "Springs"
	skeleton.add_child(_springs)
	_springs.add_spring(&"belly", 0.5, 90.0, 9.0)
	_springs.add_spring(&"hat", 0.35, 140.0, 10.0)

	_arms = LimbIk.new()
	_arms.name = "ArmIk"
	skeleton.add_child(_arms)
	# локти смотрят вниз, назад и наружу (модель лицом в +Z, левая рука на +X)
	_arm_l = _arms.add_chain(skeleton, &"upper_arm.L", &"forearm.L", &"hand.L", Vector3(0.6, -1.0, -0.5))
	_arm_r = _arms.add_chain(skeleton, &"upper_arm.R", &"forearm.R", &"hand.R", Vector3(-0.6, -1.0, -0.5))
	_shoulder_l = skeleton.find_bone(&"upper_arm.L")
	_shoulder_r = skeleton.find_bone(&"upper_arm.R")

	ragdoll = Ragdoll.new()
	ragdoll.name = "Ragdoll"
	add_child(ragdoll)
	ragdoll.setup(skeleton, player)

	player.landed.connect(_on_landed)
	player.mantle_started.connect(_on_mantle)
	player.knocked_down.connect(_on_knocked_down)
	player.getup_started.connect(_on_getup_started)
	_play(&"idle", 1.0)


## Вид от первого лица: голова не рисуется (только тень), тело чуть отодвинуто назад.
func set_first_person(on: bool) -> void:
	if _head_mesh != null:
		_head_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if on \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	first_person_back_offset = _back_offset if on else 0.0


func _process(delta: float) -> void:
	if _player == null:
		return
	if not ragdoll.active:
		var base: Transform3D = _player.get_global_transform_interpolated()
		var yaw_basis := Basis(Vector3.UP, _player.yaw)
		global_transform = Transform3D(yaw_basis * Basis(Vector3.UP, MODEL_TURN),
				base.origin + yaw_basis * Vector3(0.0, _player.step_visual_offset, first_person_back_offset))
		_springs.push(_player.velocity)
	_update_hands()
	_one_shot_left = maxf(_one_shot_left - delta, 0.0)
	if _one_shot_left <= 0.0 and _player.mode == PlayerController.Mode.NORMAL:
		_update_locomotion()
	elif _player.mode == PlayerController.Mode.BURIED or _player.mode == PlayerController.Mode.SEATED:
		_play(&"crouch_idle", 1.0)


## Руки тянутся к предмету в руках: к его точкам хвата grip_*, а если до них
## не достать или их нет — берутся по бокам от места, за которое схватили.
func _update_hands() -> void:
	var grab: PlayerGrab = _player.grab
	if grab == null or grab.held == null or ragdoll.active:
		_arms.release(_arm_l)
		_arms.release(_arm_r)
		return
	var right: Vector3 = Basis(Vector3.UP, _player.yaw).x
	var point: Vector3 = grab.grab_point()
	var left_goal: Vector3 = point - right * HAND_SPREAD
	var right_goal: Vector3 = point + right * HAND_SPREAD
	var item: Item = grab.held as Item
	if item != null and item.grips.size() >= 2:
		var sk_xf: Transform3D = skeleton.global_transform
		var best_l: Marker3D = _pick_grip(item, sk_xf * skeleton.get_bone_global_pose(_shoulder_l).origin, -right, point)
		var best_r: Marker3D = _pick_grip(item, sk_xf * skeleton.get_bone_global_pose(_shoulder_r).origin, right, point)
		if best_l != null and best_r != null and best_l != best_r:
			left_goal = best_l.global_position
			right_goal = best_r.global_position
	_arms.set_target(_arm_l, left_goal, 1.0)
	_arms.set_target(_arm_r, right_goal, 1.0)


## Точка хвата, до которой достаёт рука и которая лежит с нужной стороны.
func _pick_grip(item: Item, shoulder: Vector3, side: Vector3, around: Vector3) -> Marker3D:
	var best: Marker3D = null
	var best_score: float = -INF
	for g: Marker3D in item.grips:
		var pos: Vector3 = g.global_position
		if pos.distance_to(shoulder) > ARM_REACH:
			continue
		var score: float = (pos - around).dot(side) - pos.distance_to(shoulder) * 0.3
		if score > best_score:
			best_score = score
			best = g
	return best


## Выбор цикла по состоянию. Скорость проигрывания привязана к фазе шагов
## контроллера, поэтому ноги не «скользят» и совпадают с качанием камеры.
func _update_locomotion() -> void:
	var speed: float = _player.horizontal_speed()
	var cycles_per_sec: float = speed / _player.stride_length()
	if not _player.is_on_floor():
		_play(&"air", 1.0)
	elif _player.crouching:
		if speed > 0.4:
			_play(&"crouch_walk", cycles_per_sec * anim.get_animation(&"crouch_walk").length)
		else:
			_play(&"crouch_idle", 1.0)
	elif speed > 0.4:
		var clip: StringName = &"run" if speed > (_player.feel.walk_speed + _player.feel.sprint_speed) * 0.5 else &"walk"
		_play(clip, cycles_per_sec * anim.get_animation(clip).length)
	else:
		_play(&"idle", 1.0)


func _play(clip: StringName, speed: float) -> void:
	if _current != clip:
		_current = clip
		anim.play(clip, blend_time)
	anim.speed_scale = speed


func _play_once(clip: StringName, duration: float) -> void:
	var length: float = anim.get_animation(clip).length
	_current = clip
	anim.play(clip, 0.08)
	anim.speed_scale = length / maxf(duration, 0.05)
	_one_shot_left = duration


func _on_landed(impact: float) -> void:
	if impact > 4.0:
		_play_once(&"land", remap(clampf(impact, 4.0, 13.0), 4.0, 13.0, 0.3, 0.7))


func _on_mantle(_height: float, duration: float) -> void:
	_play_once(&"mantle", duration + 0.15)


func _on_knocked_down(_impact: float) -> void:
	ragdoll.activate(_player.velocity)


func _on_getup_started(duration: float) -> void:
	ragdoll.release(duration)
	_play_once(&"land", duration)
