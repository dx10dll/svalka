"""Пересобрать все ассеты: .glb в assets/models и превью в art_src/previews.

Запуск (любой из вариантов):
    blender -b -P art_src/blender/build_all.py            # обычный Blender 4.2+/5.x
    blender -b -P art_src/blender/build_all.py -- radiator # только ассеты, где в пути есть 'radiator'
    python art_src/blender/build_all.py                   # Python с пакетом bpy (pip install bpy)
"""

import runpy
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from lib import palette, pipeline  # noqa: E402


def main() -> int:
    # В Blender аргументы идут после '--'; у python+bpy — сразу после имени скрипта
    raw = pipeline.run_from_cli() if "--" in sys.argv else sys.argv[1:]
    filters = [a for a in raw if not a.startswith("-") and not a.endswith(".py")]
    palette.write_png(pipeline.PALETTE_PNG)
    scripts = sorted((HERE / "assets").rglob("*.py"))
    if filters:
        scripts = [s for s in scripts if any(f in str(s) for f in filters)]
    failed = []
    for s in scripts:
        t = time.time()
        print(f"=== {s.relative_to(HERE)}")
        try:
            runpy.run_path(str(s), run_name="__main__")
            print(f"    готово за {time.time() - t:.1f} с")
        except Exception as e:  # продолжаем собирать остальные
            import traceback
            traceback.print_exc()
            failed.append(f"{s.name}: {e}")
    print(f"Собрано {len(scripts) - len(failed)} из {len(scripts)}")
    for f in failed:
        print("ОШИБКА", f)
    return 1 if failed else 0


if __name__ == "__main__":
    code = main()
    if code:
        sys.exit(code)
