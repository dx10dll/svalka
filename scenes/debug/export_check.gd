extends Node
## Проверка собранной игры: запускается из готового пакета (не из проекта) и смотрит,
## что данные пережили экспорт. Поймала пустую гору в 0.0.6–0.0.10: массивы весов
## из написанных руками .tres терялись при упаковке.
## Запуск: godot --headless --main-pack игра.pck res://scenes/debug/export_check.tscn


func _ready() -> void:
	var failed: int = 0
	for path: String in ["res://data/dump_test.tres", "res://data/dump_mountain.tres"]:
		var cfg: DumpConfig = load(path)
		var field := DumpField.new(cfg, 1)
		var ok: bool = cfg.junk.size() >= 6 and cfg.junk_weight_top.size() == cfg.junk.size() \
				and cfg.loot_weight_top.size() == cfg.loot.size() and field.solid_count() > 3000 and field.sites.size() >= 8
		print("  %s: %s — ячеек %d, вещей %d" % ["ок" if ok else "ПРОВАЛ", path, field.solid_count(), field.sites.size()])
		failed += 0 if ok else 1
	for data: ItemData in (load("res://data/dump_mountain.tres") as DumpConfig).junk:
		if data == null or data.model == null:
			print("  ПРОВАЛ: у мусора нет модели")
			failed += 1
	var feel: VanFeel = load("res://data/van_feel.tres")
	var player: PlayerFeel = load("res://data/player_feel.tres")
	if feel == null or feel.capacity <= 0.0 or player == null:
		print("  ПРОВАЛ: числа машины или игрока не загрузились")
		failed += 1
	var run := RunState.new(load("res://data/economy.tres"), 1, 1)
	if run.quota() != 1350 or run.economy.night_seconds < 60.0:
		print("  ПРОВАЛ: экономика не загрузилась (норма %d)" % run.quota())
		failed += 1
	if ShopDb.all().size() < 3 or ShopDb.all()[0] == null or ShopDb.all()[0].price <= 0 \
			or load("res://scenes/game/garage.tscn") == null:
		print("  ПРОВАЛ: лавка или гараж не загрузились")
		failed += 1
	if load("res://scenes/game/night.tscn") == null:
		print("  ПРОВАЛ: нет сцены ночи")
		failed += 1
	print("Проверка сборки: провалено %d" % failed)
	get_tree().quit(1 if failed > 0 else 0)
