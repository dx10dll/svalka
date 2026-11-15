extends "res://scenes/debug/test_scene.gd"
## Площадка этапа 1: горка из ящиков для проверки бега, прыжков, ступенек,
## залезания на уступы и падения с высоты. Раскладка задана таблицей ниже.

const CRATE_MODEL: String = "res://assets/models/props/crate_wood.glb"
const PLAYER_SCENE: String = "res://scenes/player/player.tscn"

## Статичные ящики: [x, y(низ), z, размер]. Горка поднимается ступенями разной
## высоты: 0.5 (ступенька-переросток), 1 (перешагнуть), 1.5–2 (подпрыгнуть и подтянуться).
const CRATES: Array = [
	# лестница из маленьких ящиков: заходим без прыжка (ступенька 0.35)
	[-6.0, 0.0, -4.0, 0.35], [-6.0, 0.0, -4.7, 0.7], [-6.0, 0.0, -5.75, 1.05],
	# первый ярус, 1 м
	[-3.0, 0.0, -6.0, 1.0], [-2.0, 0.0, -6.0, 1.0], [-1.0, 0.0, -6.0, 1.0], [0.0, 0.0, -6.0, 1.0],
	[-3.0, 0.0, -7.0, 1.0], [-2.0, 0.0, -7.0, 1.0], [-1.0, 0.0, -7.0, 1.0], [0.0, 0.0, -7.0, 1.0],
	[-4.5, 0.0, -6.5, 1.5],
	# второй ярус, 2–2.5 м
	[-2.25, 1.0, -7.25, 1.5], [-0.75, 1.0, -7.25, 1.5],
	[-2.0, 0.0, -9.0, 2.0], [0.0, 0.0, -9.0, 2.0], [2.0, 0.0, -9.0, 2.0],
	[1.25, 0.0, -6.75, 1.5],
	# третий ярус, 4 м
	[-2.0, 2.0, -9.0, 2.0], [0.0, 2.0, -9.0, 2.0],
	[2.0, 2.0, -9.0, 1.0],
	# вышка для смешного падения, 6 м, с трамплином-пропастью
	[-2.0, 4.0, -9.0, 2.0],
	# островок через провал 2.5 м: прыжок с разбега
	[4.75, 0.0, -9.0, 2.0], [4.75, 2.0, -9.0, 1.0],
	# низкий лаз: пройти только присев (просвет 1 м)
	[5.0, 1.0, 0.0, 1.5], [6.5, 1.0, 0.0, 1.5], [4.75, 0.0, -1.0, 1.0], [4.75, 0.0, 1.0, 1.0],
	[6.75, 0.0, -1.0, 1.0], [6.75, 0.0, 1.0, 1.0],
]

## Свободные ящики (физические): [x, y, z, размер, масса]
const LOOSE: Array = [
	[2.5, 0.0, -3.0, 0.6, 18.0], [3.2, 0.0, -3.2, 0.6, 18.0], [2.8, 0.6, -3.1, 0.6, 18.0],
	[-0.5, 1.0, -6.0, 0.5, 12.0], [0.0, 4.0, -9.0, 0.5, 12.0],
]

var _player: PlayerController


func _populate() -> void:
	_build_lamp(Vector3(-4.5, 0.0, -2.5))
	_build_lamp(Vector3(4.0, 0.0, -5.0))
	var model: PackedScene = load(CRATE_MODEL)
	for c: Array in CRATES:
		_add_crate(model, Vector3(c[0], c[1], c[2]), c[3], 0.0)
	for c: Array in LOOSE:
		_add_crate(model, Vector3(c[0], c[1], c[2]), c[3], c[4])

	# предметы трёх весовых классов: лёгкий, хрупкий, неподъёмный в одиночку
	_spawn(load("res://data/items/radiator_cast_iron.tres"), Transform3D(Basis(Vector3.UP, 0.4), Vector3(1.8, 0.02, -1.2)))
	_spawn(load("res://data/items/cable_coil.tres"), Transform3D(Basis.IDENTITY, Vector3(-1.2, 0.02, -0.6)))
	_spawn(load("res://data/items/cable_coil.tres"), Transform3D(Basis(Vector3.UP, 1.0), Vector3(-1.9, 0.02, -1.4)))
	_spawn(load("res://data/items/tv_crt.tres"), Transform3D(Basis(Vector3.UP, 2.8), Vector3(0.3, 0.02, -1.6)))
	_spawn(load("res://data/items/tv_crt.tres"), Transform3D(Basis(Vector3.UP, 3.4), Vector3(-0.5, 1.02, -6.2)))

	# крупная техника (вдвоём или волоком) и хрупкий антиквариат
	_spawn(load("res://data/items/fridge.tres"), Transform3D(Basis(Vector3.UP, 2.6), Vector3(-3.4, 0.02, -0.4)))
	_spawn(load("res://data/items/washing_machine.tres"), Transform3D(Basis(Vector3.UP, 3.5), Vector3(4.4, 0.02, 2.8)))
	_spawn(load("res://data/items/samovar.tres"), Transform3D(Basis(Vector3.UP, 0.3), Vector3(0.9, 0.02, 0.3)))
	_spawn(load("res://data/items/samovar.tres"), Transform3D(Basis(Vector3.UP, 2.0), Vector3(2.8, 1.22, -3.1)))

	_player = (load(PLAYER_SCENE) as PackedScene).instantiate()
	_player.position = Vector3(0.0, 0.05, 2.0)
	add_child(_player)
	_build_hint("HINT_PLAYGROUND")


## Ящик со стороной size, стоящий низом в точке at. mass = 0 — статичный.
func _add_crate(model: PackedScene, at: Vector3, size: float, mass: float) -> void:
	var body: PhysicsBody3D
	if mass > 0.0:
		var rb := RigidBody3D.new()
		rb.mass = mass
		rb.add_child(ImpactSound.new())  # стук дерева
		body = rb
	else:
		body = StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE * size
	shape.shape = box
	body.add_child(shape)
	var visual: Node3D = model.instantiate()
	for col: Node in visual.find_children("col_*", "CollisionShape3D", true, false):
		col.free()  # коллизия у нас своя, точно по размеру
	visual.scale = Vector3.ONE * size
	visual.position.y = -size * 0.5
	# четверть-обороты, чтобы ящики не выглядели одинаковыми
	visual.rotation.y = (_rng.randi() % 4) * PI * 0.5
	body.add_child(visual)
	body.position = at + Vector3.UP * size * 0.5
	add_child(body)
