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
	_one_shot_left = maxf(_one_shot_left - delta, 0.0)
	if _one_shot_left <= 0.0 and _player.mode == PlayerController.Mode.NORMAL:
		_update_locomotion()


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
