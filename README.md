# ЦВЕТМЕТ

Кооператив на 1–4 игроков про бригаду охотников за цветным металлом на ночной свалке середины 90-х. Godot 4.7, GDScript, физика Jolt.

- Полное задание и план этапов: [docs/PROMPT.md](docs/PROMPT.md)
- Журнал разработки (что сделано, что дальше): [docs/DEVLOG.md](docs/DEVLOG.md)

## Запуск

Открыть папку в Godot 4.7+ и нажать F5. Готовые сборки под Windows лежат в разделе Releases.

## Модели

Модели строятся скриптами Blender. Пересобрать всё:

```
blender -b -P art_src/blender/build_all.py
```

## Тесты

```
godot --headless --path . --import
godot --headless --path . -s tests/run_tests.gd
```
