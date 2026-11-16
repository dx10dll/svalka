"""Сторож свалки: высокая фигура в плаще до земли, ушанка, фонарь в вытянутой руке.

Без скелета: ног под плащом не видно, поэтому он «плывёт» и покачивается —
движение делает код. Рядом с мужичками бригады (1.28 м) он великан: 1.95 м.
Лицо в -Y (в Godot — вперёд, -Z). Начало координат — низ по центру.
Запуск отдельно: blender -b -P art_src/blender/assets/characters/guard.py
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from lib import geo, pipeline  # noqa: E402


def build() -> None:
    pipeline.reset_scene()
    b = geo.Builder("mesh")
    # плащ: колокол до земли, сутулые плечи
    b.cylinder(0.42, 1.0, (0, 0, 0.5), "paint_khaki", segments=8, radius_top=0.3)
    b.cylinder(0.3, 0.5, (0, 0.02, 1.25), "paint_khaki", segments=8, radius_top=0.26)
    b.box((0.74, 0.34, 0.2), (0, 0.03, 1.5), "paint_khaki", bevel=0.07)                    # плечи
    b.box((0.5, 0.3, 0.22), (0, 0.12, 1.42), "paint_green_dark", bevel=0.08)               # капюшон на спине
    b.box((0.06, 0.02, 0.9), (0, -0.33, 0.75), "paint_green_dark", rotation=(4, 0, 0))     # планка с пуговицами
    for z in (0.5, 0.8, 1.1):
        b.cylinder(0.022, 0.02, (0, -0.35, z), "brass_dark", axis="Y", segments=6)
    b.box((0.62, 0.36, 0.07), (0, 0, 0.98), "boot_rubber", bevel=0.01)                     # ремень
    b.box((0.09, 0.03, 0.09), (0, -0.2, 0.98), "brass", bevel=0.01)                        # пряжка
    # голова: вытянута вперёд, ушанка, усы, тёмные глазницы
    b.box((0.26, 0.28, 0.3), (0, -0.1, 1.72), "skin_dark", bevel=0.06)
    b.box((0.34, 0.34, 0.16), (0, -0.08, 1.88), "hair_dark", bevel=0.05)                   # ушанка
    for sx in (-1, 1):
        b.box((0.07, 0.2, 0.2), (sx * 0.17, -0.06, 1.74), "hair_dark", bevel=0.02)         # уши шапки
        b.box((0.07, 0.03, 0.05), (sx * 0.065, -0.245, 1.76), "black")                     # глаза
    b.box((0.09, 0.03, 0.035), (0, -0.25, 1.9), "brass", bevel=0.008)                      # кокарда без знаков
    b.box((0.07, 0.09, 0.1), (0, -0.27, 1.69), "skin", bevel=0.02)                         # нос
    b.box((0.22, 0.05, 0.05), (0, -0.25, 1.62), "hair_light", bevel=0.015)                 # усы
    # правая рука с фонарём вытянута вперёд, левая висит
    b.box((0.13, 0.5, 0.13), (-0.36, -0.22, 1.36), "paint_khaki", bevel=0.03, rotation=(-12, 0, 0))
    b.box((0.12, 0.13, 0.12), (-0.36, -0.5, 1.3), "glove_cotton", bevel=0.03)
    b.cylinder(0.012, 0.16, (-0.36, -0.5, 1.2), "steel_dark", segments=5)                  # дужка фонаря
    b.cylinder(0.075, 0.03, (-0.36, -0.5, 1.12), "steel_dark", segments=7)
    b.cylinder(0.06, 0.16, (-0.36, -0.5, 1.03), "light_warm", segments=7)                  # стекло светится
    b.cylinder(0.08, 0.04, (-0.36, -0.5, 0.93), "steel_dark", segments=7)
    b.box((0.13, 0.14, 0.62), (0.4, 0.03, 1.2), "paint_khaki", bevel=0.03, rotation=(0, 6, 0))
    b.box((0.12, 0.13, 0.13), (0.43, 0.03, 0.85), "glove_cotton", bevel=0.03)
    # сапоги выглядывают из-под плаща
    for sx in (-1, 1):
        b.box((0.16, 0.3, 0.1), (sx * 0.14, -0.2, 0.05), "boot_rubber", bevel=0.03)
    obj = b.build()
    geo.grime(obj, seed=41, dirt_height=0.5, strength=0.5, rust_tint=0.0, noise_scale=3.0)
    geo.collider_cylinder("body", 0.4, 1.9, (0, 0, 0.95))
    pipeline.finish("characters/guard", tri_budget=1200)


if __name__ == "__main__":
    build()
