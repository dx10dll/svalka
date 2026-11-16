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
var _price_tags: Dictionary[StringName, Label3D] = {}


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
	_build_hint("HINT_GARAGE")
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


## Лавка у правой стены: ящик на каждый товар, над ним название и цена.
func _build_shop() -> void:
	var title: Label3D = _text(Vector3(ROOM.x * 0.5 - 0.12, 3.2, -2.5), -PI * 0.5, 64)
	title.text = tr("SHOP_TITLE")
	title.modulate = Color(1.0, 0.75, 0.35)
	var items: Array[ShopItem] = ShopDb.all()
	for i: int in items.size():
		var item: ShopItem = items[i]
		var z: float = -6.6 + i * 1.5
		var spot: UseSpot = UseSpot.make(Vector3(0.8, 0.8, 0.8), Color(0.42, 0.3, 0.18),
				func() -> String: return _shop_hint(item), func(_p: PlayerController) -> void: buy(item))
		spot.name = "Shop_" + item.id
		spot.position = Vector3(ROOM.x * 0.5 - 0.7, 0.46, z)
		add_child(spot)
		var tag: Label3D = _text(Vector3(ROOM.x * 0.5 - 0.12, 1.75, z), -PI * 0.5, 50)
		_price_tags[item.id] = tag
	_update_tags()


func _update_tags() -> void:
	for item: ShopItem in ShopDb.all():
		var tag: Label3D = _price_tags[item.id]
		var bought: bool = item.tool.is_empty() and run.has_upgrade(item.id)
		tag.text = "%s\n%s\n%s" % [tr(item.name_key), tr(item.desc_key), tr("SHOP_BOUGHT") if bought else Fmt.rub(item.price)]
		tag.modulate = Color(0.55, 1.0, 0.5) if bought else (Color.WHITE if run.money >= item.price else Color(1.0, 0.55, 0.5))


func _shop_hint(item: ShopItem) -> String:
	if not item.tool.is_empty():
		if run.money < item.price:
			return tr("SHOP_HINT_POOR") % [tr(item.name_key), Fmt.rub(item.price - run.money)]
		if _player.belt.free_slot() < 0:
			return tr("SHOP_HINT_BELT_FULL") % tr(item.name_key)
		return tr("SHOP_HINT_BUY") % [tr(item.name_key), Fmt.rub(item.price)]
	if run.has_upgrade(item.id):
		return tr("SHOP_HINT_BOUGHT") % tr(item.name_key)
	if run.money < item.price:
		return tr("SHOP_HINT_POOR") % [tr(item.name_key), Fmt.rub(item.price - run.money)]
	return tr("SHOP_HINT_BUY") % [tr(item.name_key), Fmt.rub(item.price)]


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
