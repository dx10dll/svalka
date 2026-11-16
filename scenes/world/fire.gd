class_name Fire
extends Node3D
## Костёр в бочке: мерцающий тёплый свет, языки пламени, искры и треск.
## Свет дрожит от суммы двух синусов и случайных рывков — без этого огонь «мёртвый».

@export var energy: float = 5.5
@export var light_range: float = 11.0
## Высота пламени над началом координат, м
@export var flame_height: float = 0.9

var _light: OmniLight3D
var _time: float = 0.0
var _kick: float = 0.0
var _sound: AudioStreamPlayer3D


func _ready() -> void:
	_time = randf() * 10.0
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.5, 0.18)
	_light.light_energy = energy
	_light.omni_range = light_range
	_light.omni_attenuation = 1.3
	_light.shadow_enabled = true
	_light.light_volumetric_fog_energy = 2.0
	_light.position.y = flame_height + 0.25
	add_child(_light)
	add_child(_particles(false))
	add_child(_particles(true))
	var stream: AudioStreamWAV = load("res://assets/audio/loops/fire_loop.wav")
	if stream != null:
		stream = stream.duplicate()
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
		_sound = AudioStreamPlayer3D.new()
		_sound.stream = stream
		_sound.unit_size = 3.0
		_sound.max_distance = 22.0
		_sound.volume_db = -6.0
		_sound.position.y = flame_height
		add_child(_sound)
		_sound.play(randf() * 2.0)


func _particles(sparks: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05) if sparks else Vector2(0.34, 0.42)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1.0, 0.55, 0.2)
	quad.material = mat
	p.mesh = quad
	p.amount = 10 if sparks else 16
	p.lifetime = 1.6 if sparks else 0.7
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.16
	p.direction = Vector3.UP
	p.spread = 35.0 if sparks else 12.0
	p.gravity = Vector3(0.0, 0.6, 0.0) if sparks else Vector3(0.0, 1.6, 0.0)
	p.initial_velocity_min = 1.2 if sparks else 0.5
	p.initial_velocity_max = 2.6 if sparks else 1.1
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.45, 0.9))
	ramp.set_color(1, Color(0.9, 0.15, 0.02, 0.0))
	p.color_ramp = ramp
	p.position.y = flame_height
	return p


func _process(delta: float) -> void:
	_time += delta
	if randf() < delta * 3.0:
		_kick = randf_range(-0.35, 0.35)
	_kick = lerpf(_kick, 0.0, 1.0 - exp(-6.0 * delta))
	var flicker: float = 1.0 + 0.16 * sin(_time * 11.0) + 0.1 * sin(_time * 23.7 + 1.3) + _kick
	_light.light_energy = energy * flicker
	_light.position.x = 0.04 * sin(_time * 7.0)
	_light.position.z = 0.04 * cos(_time * 9.0)
