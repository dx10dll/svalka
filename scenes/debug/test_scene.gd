extends Node3D
## Тестовая сцена этапа 0: ночь, туман, натриевый фонарь, площадка и несколько
## батарей. Проверяет, что проект, Jolt, палитра, импорт моделей и отладочное меню
## работают вместе. Собирается кодом: настоящие уровни появятся на этапе 3.

const MOON_COLOR := Color(0.55, 0.66, 1.0)
const SODIUM_COLOR := Color(1.0, 0.64, 0.28)
const DAWN_COLOR := Color(0.86, 0.62, 0.62)
const GROUND_SIZE := Vector3(80.0, 1.0, 80.0)

var _env: Environment
var _moon: DirectionalLight3D
var _camera: FreeCamera
var _spawned: Array[Node] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 1995
	_build_sky_and_light()
	_build_ground()
	_populate()
	DebugMenu.spawn_requested.connect(_on_spawn_requested)
	DebugMenu.clear_requested.connect(_on_clear_requested)
	Game.night_time_changed.connect(_apply_night_time)
	_apply_night_time(Game.night_time)


## Наполнение сцены. Наследники (другие тестовые площадки) заменяют его своим.
func _populate() -> void:
	_build_lamp(Vector3(2.5, 0.0, -1.5))
	_camera = FreeCamera.new()
	_camera.position = Vector3(-2.6, 1.6, 3.4)
	_camera.rotation = Vector3(-0.2, -0.62, 0.0)
	_camera.fov = 75.0
	add_child(_camera)
	_camera.make_current()
	_build_hint("HINT_TEST_SCENE")

	var radiator: ItemData = load("res://data/items/radiator_cast_iron.tres")
	# одна стоит, одна лежит, одна падает сверху — сразу видно физику и стопку
	_spawn(radiator, Transform3D(Basis(Vector3.UP, 0.4), Vector3(0.0, 0.02, 0.0)))
	_spawn(radiator, Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(1.0, 0.1, 0.6)))
	_spawn(radiator, Transform3D(Basis(Vector3(1, 0, 1).normalized(), 0.7), Vector3(0.6, 2.4, 0.3)))


func _build_sky_and_light() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.015, 0.02, 0.035)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = MOON_COLOR
	_env.ambient_light_energy = 0.12
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.glow_enabled = true
	_env.glow_intensity = 0.6
	_env.glow_bloom = 0.1
	_env.volumetric_fog_enabled = true
	_env.volumetric_fog_density = 0.035
	_env.volumetric_fog_albedo = Color(0.75, 0.8, 0.9)
	_env.volumetric_fog_anisotropy = 0.55
	_env.volumetric_fog_length = 48.0
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)

	_moon = DirectionalLight3D.new()
	_moon.light_color = MOON_COLOR
	_moon.light_energy = 0.25
	_moon.shadow_enabled = true
	_moon.rotation_degrees = Vector3(-38.0, 140.0, 0.0)
	add_child(_moon)


func _build_ground() -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = GROUND_SIZE
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = GROUND_SIZE
	mesh.mesh = box_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.18, 0.15)
	mat.roughness = 1.0
	mesh.material_override = mat
	body.add_child(mesh)
	body.position.y = -GROUND_SIZE.y / 2.0
	add_child(body)


## Фонарный столб-заглушка: настоящая модель придёт с китом свалки (этап 3).
func _build_lamp(at: Vector3) -> void:
	var pole := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.08
	cyl.height = 5.0
	cyl.radial_segments = 6
	pole.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.22, 0.2)
	pole.material_override = mat
	pole.position = at + Vector3(0.0, 2.5, 0.0)
	add_child(pole)

	var bulb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	sphere.radial_segments = 8
	sphere.rings = 4
	bulb.mesh = sphere
	var glow := StandardMaterial3D.new()
	glow.emission_enabled = true
	glow.emission = SODIUM_COLOR
	glow.emission_energy_multiplier = 6.0
	glow.albedo_color = SODIUM_COLOR
	bulb.material_override = glow
	bulb.position = at + Vector3(0.0, 4.9, 0.0)
	add_child(bulb)

	var light := SpotLight3D.new()
	light.light_color = SODIUM_COLOR
	light.light_energy = 9.0
	light.light_volumetric_fog_energy = 1.6
	light.spot_range = 14.0
	light.spot_angle = 58.0
	light.shadow_enabled = true
	light.position = at + Vector3(0.0, 4.8, 0.0)
	light.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	add_child(light)


func _build_hint(key: String) -> void:
	var layer := CanvasLayer.new()
	var label := Label.new()
	label.text = key
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_top = -40.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	label.add_theme_constant_override(&"outline_size", 4)
	layer.add_child(label)
	add_child(layer)


func _spawn(item_data: ItemData, xf: Transform3D) -> Item:
	var item: Item = ItemDb.spawn(item_data, _rng)
	item.transform = xf
	add_child(item)
	return item


func _on_spawn_requested(item_data: ItemData) -> void:
	if not Net.is_host():
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	var at: Vector3 = cam.global_position - cam.global_basis.z * 2.0
	var basis := Basis(Vector3.UP, _rng.randf_range(0.0, TAU))
	_spawned.append(_spawn(item_data, Transform3D(basis, at)))


func _on_clear_requested() -> void:
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.queue_free()
	_spawned.clear()


## Рассвет: к 04:30 (t=0.9) небо начинает сереть и розоветь.
func _apply_night_time(t: float) -> void:
	var dawn: float = smoothstep(0.85, 1.0, t)
	_env.background_color = Color(0.015, 0.02, 0.035).lerp(Color(0.42, 0.36, 0.42), dawn)
	_env.ambient_light_color = MOON_COLOR.lerp(DAWN_COLOR, dawn)
	_env.ambient_light_energy = lerpf(0.12, 0.7, dawn)
	_moon.light_color = MOON_COLOR.lerp(DAWN_COLOR, dawn)
	_moon.light_energy = lerpf(0.25, 0.9, dawn)
