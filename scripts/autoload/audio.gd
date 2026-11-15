extends Node
## Звук: удары по материалу и силе, шаги, разовые звуки в мире.
##
## Звуки лежат в assets/audio/sfx/ как <имя>_<номер>.wav (их делает
## tools/gen_sounds.py). Варианты одного имени чередуются случайно, высота
## слегка гуляет — так одинаковые удары не звучат одинаково.

const DIR: String = "res://assets/audio/sfx/"
## Сколько звуков в мире может играть одновременно
const VOICES: int = 20
## Один и тот же звук не чаще, чем раз в столько секунд (груда вещей не «трещит»)
const MIN_REPEAT: float = 0.07
## Удар такой силы (м/с) звучит в полную громкость
const FULL_IMPACT: float = 9.0

## Сколько звуков запущено с начала игры (для тестов и отладки)
var played_count: int = 0
## Имя последнего запущенного звука
var last_played: StringName = &""

var _bank: Dictionary[StringName, Array] = {}
var _pool: Array[AudioStreamPlayer3D] = []
var _next_voice: int = 0
var _last_time: Dictionary[StringName, float] = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for file: String in ResourceLoader.list_directory(DIR):
		if not file.ends_with(".wav"):
			continue
		var base: String = file.get_basename()           # metal_heavy_2
		var id := StringName(base.left(base.rfind("_")))  # metal_heavy
		if not _bank.has(id):
			_bank[id] = []
		_bank[id].append(load(DIR + file))
	for i: int in VOICES:
		var voice := AudioStreamPlayer3D.new()
		voice.unit_size = 4.0
		voice.max_distance = 45.0
		voice.attenuation_filter_cutoff_hz = 9000.0
		add_child(voice)
		_pool.append(voice)


func has_sound(id: StringName) -> bool:
	return _bank.has(id)


## Удар предмета: material — имя звука (metal_heavy, wood...), strength — сила удара, м/с.
func play_impact(material: StringName, position: Vector3, strength: float) -> void:
	var k: float = clampf(strength / FULL_IMPACT, 0.0, 1.0)
	# слабый удар тише и чуть глуше (ниже), сильный — громче
	play_at(material, position, lerpf(-22.0, 0.0, sqrt(k)), lerpf(0.9, 1.05, k))


## Разовый звук в точке мира. volume_db — громкость, pitch — высота (1 — как записано).
func play_at(id: StringName, position: Vector3, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _bank.has(id):
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_time.get(id, -1.0) < MIN_REPEAT:
		return
	_last_time[id] = now
	var variants: Array = _bank[id]
	var voice: AudioStreamPlayer3D = _pool[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	voice.stream = variants[_rng.randi() % variants.size()]
	voice.global_position = position
	voice.volume_db = volume_db
	voice.pitch_scale = pitch * _rng.randf_range(0.93, 1.07)
	voice.play()
	played_count += 1
	last_played = id


func play_ui(_id: StringName) -> void:
	pass
