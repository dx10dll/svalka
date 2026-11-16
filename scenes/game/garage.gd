extends "res://scenes/debug/test_scene.gd"
## Гараж между ночами: доска с долгом и нормой, лавка Барыги, буханка.
## Таймера нет. E у ворот — ехать на свалку.

const NIGHT_SCENE: String = "res://scenes/game/night.tscn"
const PLAYER_SCENE: String = "res://scenes/player/player.tscn"
## Размер гаража внутри, м
const ROOM := Vector3(11.0, 4.6, 15.0)

var run: RunState
var van: Van
## Тесты выключают: тогда «выезд» не грузит сцену ночи
var auto_advance: bool = true
var leaving: bool = false

var _board: Label3D
var _player: PlayerController
const BENCH_HEIGHT: float = 0.9
## Шаг между товарами на верстаке, м
const SHOP_STEP: float = 1.45
const UPGRADE_MODELS: Dictionary[StringName, String] = {
	&"springs": "res://assets/models/props/shop_springs.glb",
	&"tyres": "res://assets/models/props/shop_tyre.glb",
	&"searchlight": "res://assets/models/props/shop_searchlight.glb",
}

var _price_tags: Dictionary[StringName, Label3D] = {}
var _goods: Dictionary[StringName, Node3D] = {}


func _populate() -> void:
	if Game.run == null or Game.run.outcome != RunState.Outcome.RUNNING:
		Game.start_run(true)
	run = Game.run
	Game.night_time = 0.0
	Game.set_phase(Game.Phase.GARAGE)
	_build_room()
	van = Van.new()
	van.name = "Van"
	van.position = Vector3(-2.2, 0.25, 0.5)
	add_child(van)
	van.apply_upgrades(run.upgrades)
	_build_board()
	_build_shop()
	_build_gate()
	_player = (load(PLAYER_SCENE) as PackedScene).instantiate()
	_player.position = Vector3(2.5, 0.05, 3.0)
	_player.rotation.y = PI * 0.5
	add_child(_player)
	_env.volumetric_fog_density = 0.008     # в гараже воздух чище, чем на свалке


func _build_room() -> void:
	var wall := Color(0.3, 0.29, 0.27)
	var h: float = ROOM.y
	_slab(Vector3(ROOM.x, 0.06, ROOM.z), Vector3(0.0, 0.03, 0.0), Color(0.24, 0.24, 0.25))        # бетонный пол
	_slab(Vector3(ROOM.x + 0.6, 0.3, ROOM.z + 0.6), Vector3(0.0, h + 0.15, 0.0), Color(0.2, 0.19, 0.18))   # крыша
	_slab(Vector3(0.3, h, ROOM.z), Vector3(-ROOM.x * 0.5 - 0.15, h * 0.5, 0.0), wall)
	_slab(Vector3(0.3, h, ROOM.z), Vector3(ROOM.x * 0.5 + 0.15, h * 0.5, 0.0), wall)
	_slab(Vector3(ROOM.x + 0.6, h, 0.3), Vector3(0.0, h * 0.5, -ROOM.z * 0.5 - 0.15), wall)
	_slab(Vector3(ROOM.x + 0.6, h, 0.3), Vector3(0.0, h * 0.5, ROOM.z * 0.5 + 0.15), wall)
	for z: float in [-4.0, 3.5]:
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.86, 0.62)
		lamp.light_energy = 2.6
		lamp.omni_range = 11.0
		lamp.shadow_enabled = true
		lamp.position = Vector3(0.0, h - 0.5, z)
		add_child(lamp)


func _slab(size: Vector3, at: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	mesh.material_override = mat
	body.add_child(mesh)
	body.position = at
	add_child(body)
	return body


func _text(at: Vector3, yaw: float, size: int) -> Label3D:
	var label := Label3D.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.pixel_size = 0.004
	label.font_size = size
	label.outline_size = 12
	label.position = at
	label.rotation.y = yaw
	add_child(label)
	return label


## Доска на правой стене: ночь, норма, касса.
func _build_board() -> void:
	_slab(Vector3(0.08, 1.7, 3.2), Vector3(ROOM.x * 0.5 - 0.05, 2.1, 4.5), Color(0.1, 0.16, 0.12))
	_board = _text(Vector3(ROOM.x * 0.5 - 0.12, 2.1, 4.5), -PI * 0.5, 84)
	_board.modulate = Color(0.95, 0.95, 0.85)
	_update_board()


func _update_board() -> void:
	_board.text = tr("GARAGE_BOARD") % [run.night, run.economy.nights(), Fmt.rub(run.quota()), Fmt.rub(run.money)]


## Лавка у правой стены: верстак, на нём лежат сами товары, перед каждым — ценник.
func _build_shop() -> void:
	var items: Array[ShopItem] = ShopDb.all()
	var x: float = ROOM.x * 0.5 - 0.6
	var from: float = -6.6
	var length: float = (items.size() - 1) * SHOP_STEP + 1.6
	var mid: float = from + (items.size() - 1) * SHOP_STEP * 0.5
	_slab(Vector3(1.0, 0.07, length), Vector3(x, BENCH_HEIGHT - 0.035, mid), Color(0.36, 0.26, 0.16))      # столешница
	_slab(Vector3(0.9, 0.05, length - 0.2), Vector3(x, 0.3, mid), Color(0.3, 0.22, 0.14))                 # нижняя полка
	for z: float in [mid - length * 0.5 + 0.1, mid, mid + length * 0.5 - 0.1]:
		for dx: float in [-0.42, 0.42]:
			_slab(Vector3(0.08, BENCH_HEIGHT - 0.07, 0.08), Vector3(x + dx, (BENCH_HEIGHT - 0.07) * 0.5, z), Color(0.25, 0.18, 0.12))
	var lamp := SpotLight3D.new()                 # лампа над верстаком: товар должен быть виден
	lamp.light_color = Color(1.0, 0.9, 0.7)
	lamp.light_energy = 6.0
	lamp.spot_range = 7.0
	lamp.spot_angle = 70.0
	lamp.position = Vector3(x - 0.6, 3.0, mid)
	lamp.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	add_child(lamp)
	for i: int in items.size():
		var item: ShopItem = items[i]
		var z: float = from + i * SHOP_STEP
		var spot: UseSpot = UseSpot.make(Vector3(0.9, 0.7, 1.2), Color.WHITE,
				func() -> String: return _shop_hint(item), func(_p: PlayerController) -> void: buy(item))
		spot.name = "Shop_" + item.id
		spot.position = Vector3(x, BENCH_HEIGHT + 0.35, z)
		(spot.get_child(1) as MeshInstance3D).visible = false      # вместо коробки — сам товар
		add_child(spot)
		var model: Node3D = _goods_model(item)
		if model != null:
			spot.add_child(model)
			model.position.y = -0.35
			_goods[item.id] = model
		# ценник: бумажка у переднего края
		var card: StaticBody3D = _slab(Vector3(0.02, 0.11, 0.26), Vector3(x - 0.47, BENCH_HEIGHT + 0.055, z), Color(0.9, 0.87, 0.75))
		card.collision_layer = 0
		var tag: Label3D = _text(Vector3(x - 0.482, BENCH_HEIGHT + 0.055, z), -PI * 0.5, 40)
		tag.pixel_size = 0.0016
		tag.outline_size = 0
		tag.modulate = Color(0.1, 0.1, 0.12)
		_price_tags[item.id] = tag
	_update_tags()


## Модель товара на верстак: инструмент — его же модель, улучшение — деталь.
func _goods_model(item: ShopItem) -> Node3D:
	var scene: PackedScene = null
	var lay := Basis.IDENTITY
	if not item.tool.is_empty():
		var data: ItemData = ItemDb.tool(item.tool)
		scene = data.model if data != null else null
		lay = Basis(Vector3.UP, PI * 0.5)          # длинные инструменты лежат вдоль верстака
	elif UPGRADE_MODELS.has(item.id):
		scene = load(UPGRADE_MODELS[item.id])
		lay = Basis(Vector3.UP, PI * 0.5)
	if scene == null:
		return null
	var model: Node3D = scene.instantiate()
	for col: Node in model.find_children("col_*", "CollisionShape3D", true, false):
		col.queue_free()
	model.basis = lay
	return model


func _update_tags() -> void:
	for item: ShopItem in ShopDb.all():
		var tag: Label3D = _price_tags[item.id]
		var bought: bool = item.tool.is_empty() and run.has_upgrade(item.id)
		tag.text = "✓" if bought else Fmt.rub(item.price)
		tag.modulate = Color(0.1, 0.45, 0.1) if bought else (Color(0.1, 0.1, 0.12) if run.money >= item.price else Color(0.7, 0.1, 0.08))
		if _goods.has(item.id):
			_goods[item.id].visible = not bought      # купленная деталь уже на буханке


## Подсказка под прицелом: название и цена, что даёт, и клавиша — если купить можно.
func _shop_hint(item: ShopItem) -> String:
	var head: String = "%s · %s\n%s" % [tr(item.name_key), Fmt.rub(item.price), tr(item.desc_key)]
	if item.tool.is_empty() and run.has_upgrade(item.id):
		return "%s\n%s" % [tr(item.name_key), tr("SHOP_HINT_BOUGHT")]
	if run.money < item.price:
		return head + "\n" + tr("SHOP_HINT_POOR") % Fmt.rub(item.price - run.money)
	if not item.tool.is_empty() and _player.belt.free_slot() < 0:
		return head + "\n" + tr("SHOP_HINT_BELT_FULL")
	return head + "\n" + tr("SHOP_HINT_BUY")


## Купить товар: деньги из кассы, улучшение сразу ставится на машину.
func buy(item: ShopItem) -> bool:
	var ok: bool
	if item.tool.is_empty():
		ok = run.buy(item)
		if ok:
			van.apply_upgrades(run.upgrades)
	else:
		# инструмент сразу вешается на пояс
		var slot: int = _player.belt.free_slot()
		ok = slot >= 0 and run.pay(item.price)
		if ok:
			_player.belt.stow(slot, ItemDb.spawn(ItemDb.tool(item.tool), RandomNumberGenerator.new()))
			run.belt = _player.belt.ids()
	if not ok:
		Audio.play_at(&"deny", _player.global_position, -6.0)
		return false
	Audio.play_at(&"cash", _player.global_position, -2.0)
	Game.save_run()
	_update_board()
	_update_tags()
	return true


## Ворота в торце: большая створка, E — выехать.
func _build_gate() -> void:
	var gate: UseSpot = UseSpot.make(Vector3(4.2, 3.2, 0.12), Color(0.36, 0.2, 0.14),
			func() -> String: return tr("GARAGE_HINT_LEAVE") % [run.night, Fmt.rub(run.quota())],
			func(_p: PlayerController) -> void: leave())
	gate.name = "Gate"
	gate.position = Vector3(-2.2, 1.6, ROOM.z * 0.5 - 0.06)
	add_child(gate)
	var label: Label3D = _text(Vector3(-2.2, 3.7, ROOM.z * 0.5 - 0.15), PI, 56)
	label.text = tr("GARAGE_GATE")
	label.modulate = Color(1.0, 0.75, 0.35)


## Ехать на свалку.
func leave() -> void:
	if leaving:
		return
	leaving = true
	run.belt = _player.belt.ids()
	Game.save_run()
	if auto_advance:
		get_tree().change_scene_to_file.call_deferred(NIGHT_SCENE)
