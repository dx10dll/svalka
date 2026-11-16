"""Пёс сторожа: лохматая дворняга, большая голова, одно ухо висит.

Без скелета: бег и лай показывает код (покачивание и наклоны).
Лицо в -Y (в Godot — вперёд, -Z). Начало координат — низ по центру.
Запуск отдельно: blender -b -P art_src/blender/assets/characters/dog.py
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from lib import geo, pipeline  # noqa: E402

FUR, FUR_DARK, FUR_LIGHT = "paint_brown", "hair_dark", "plastic_beige"


def build() -> None:
    pipeline.reset_scene()
    b = geo.Builder("mesh")
    b.box((0.3, 0.62, 0.3), (0, 0.02, 0.42), FUR, bevel=0.08)                       # туловище
    b.box((0.26, 0.2, 0.26), (0, -0.2, 0.46), FUR_LIGHT, bevel=0.07)                # грудь
    b.box((0.26, 0.26, 0.26), (0, -0.4, 0.6), FUR, bevel=0.07)                      # голова
    b.box((0.15, 0.18, 0.13), (0, -0.57, 0.55), FUR_LIGHT, bevel=0.04)              # морда
    b.box((0.07, 0.05, 0.05), (0, -0.67, 0.58), "black", bevel=0.015)               # нос
    b.box((0.11, 0.03, 0.03), (0, -0.63, 0.49), "paint_red_dark")                   # пасть
    for sx in (-1, 1):
        b.box((0.045, 0.02, 0.045), (sx * 0.07, -0.53, 0.66), "black")              # глаза
        b.box((0.08, 0.12, 0.3), (sx * 0.1, -0.2, 0.15), FUR_DARK if sx > 0 else FUR, bevel=0.03)   # передние лапы
        b.box((0.08, 0.14, 0.3), (sx * 0.1, 0.26, 0.15), FUR, bevel=0.03)           # задние лапы
    b.box((0.07, 0.04, 0.16), (0.1, -0.36, 0.78), FUR_DARK, bevel=0.02, rotation=(0, 12, 0))      # ухо торчит
    b.box((0.07, 0.04, 0.14), (-0.13, -0.38, 0.66), FUR_DARK, bevel=0.02, rotation=(0, -70, 0))   # ухо висит
    b.box((0.06, 0.26, 0.06), (0, 0.42, 0.6), FUR_DARK, bevel=0.02, rotation=(40, 0, 0))          # хвост
    b.box((0.27, 0.05, 0.28), (0, -0.28, 0.5), "paint_red", bevel=0.01)             # ошейник
    obj = b.build()
    geo.grime(obj, seed=43, dirt_height=0.3, strength=0.5, rust_tint=0.0, noise_scale=5.0)
    pipeline.finish("characters/dog", tri_budget=700)


if __name__ == "__main__":
    build()
