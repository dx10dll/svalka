"""Инструменты бригады: лопата, лом, металлоискатель, налобный фонарь.

Физические предметы: носятся на поясе, их можно уронить и потерять в завале.
Начало координат — низ по центру, длинные лежат вдоль X.
Запуск отдельно: blender -b -P art_src/blender/assets/tools/tools.py
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from lib import geo, pipeline  # noqa: E402


def shovel() -> None:
    """Совковая лопата: деревянный черенок, стальной штык, ручка-развилка."""
    pipeline.reset_scene()
    b = geo.Builder("mesh")
    b.cylinder(0.018, 0.95, (0.05, 0, 0.03), "wood", axis="X", segments=6)
    b.box((0.3, 0.22, 0.012), (-0.56, 0, 0.022), "steel", bevel=0.004, rotation=(0, -6, 0))      # штык
    b.box((0.3, 0.012, 0.03), (-0.56, 0.105, 0.035), "steel_dark", rotation=(0, -6, 0))           # бортики
    b.box((0.3, 0.012, 0.03), (-0.56, -0.105, 0.035), "steel_dark", rotation=(0, -6, 0))
    b.cylinder(0.024, 0.14, (-0.38, 0, 0.032), "steel_dark", axis="X", segments=6)               # тулейка
    b.box((0.02, 0.13, 0.02), (0.56, 0, 0.03), "wood_dark", bevel=0.005)                          # ручка
    for sy in (-1, 1):
        b.box((0.07, 0.016, 0.016), (0.53, sy * 0.05, 0.03), "wood_dark", rotation=(0, 0, sy * 40))
    obj = b.build()
    geo.grime(obj, seed=21, dirt_height=0.02, strength=0.5, rust_tint=0.3, noise_scale=10.0)
    geo.collider_box("body", (1.3, 0.2, 0.06), (-0.06, 0, 0.03))
    geo.grip("left", (0.2, 0, 0.03), (0, 0, 90))
    geo.grip("right", (0.5, 0, 0.03), (0, 0, -90))
    pipeline.finish("tools/shovel", tri_budget=400)


def crowbar() -> None:
    """Лом-гвоздодёр: шестигранный прут с загнутым раздвоенным концом."""
    pipeline.reset_scene()
    b = geo.Builder("mesh")
    b.cylinder(0.014, 0.9, (0, 0, 0.02), "paint_red_dark", axis="X", segments=6)
    b.cylinder(0.014, 0.14, (0.47, 0, 0.06), "steel_dark", axis="X", segments=6, rotation=(0, -50, 0))   # загиб
    b.box((0.07, 0.03, 0.008), (0.53, 0, 0.115), "steel", rotation=(0, -80, 0))                           # лапа
    b.box((0.09, 0.03, 0.01), (-0.48, 0, 0.018), "steel", rotation=(0, 6, 0))                             # лопатка
    obj = b.build()
    geo.grime(obj, seed=22, dirt_height=0.02, strength=0.45, rust_tint=0.4, noise_scale=12.0)
    geo.collider_box("body", (1.06, 0.05, 0.05), (0.02, 0, 0.025))
    geo.collider_box("hook", (0.08, 0.04, 0.12), (0.5, 0, 0.08))
    geo.grip("left", (-0.15, 0, 0.02), (0, 0, 90))
    geo.grip("right", (0.2, 0, 0.02), (0, 0, -90))
    pipeline.finish("tools/crowbar", tri_budget=300)


def metal_detector() -> None:
    """Металлоискатель: штанга, катушка-блин, коробка с лампочкой и подлокотник."""
    pipeline.reset_scene()
    b = geo.Builder("mesh")
    b.cylinder(0.014, 0.95, (0, 0, 0.12), "aluminium", axis="X", segments=6, rotation=(0, -12, 0))
    b.cylinder(0.14, 0.03, (-0.5, 0, 0.02), "plastic_black", segments=10, cap_color="plastic_grey")       # катушка
    b.cylinder(0.05, 0.034, (-0.5, 0, 0.022), "plastic_grey", segments=8)
    b.box((0.16, 0.08, 0.1), (0.2, 0, 0.21), "paint_khaki", bevel=0.01, rotation=(0, -12, 0))              # блок
    b.cylinder(0.012, 0.012, (0.16, 0, 0.27), "led_green", segments=6)
    b.cylinder(0.016, 0.02, (0.24, 0, 0.275), "bakelite", segments=6)                                     # ручка громкости
    b.box((0.12, 0.03, 0.03), (0.33, 0, 0.16), "rubber_worn", bevel=0.008, rotation=(0, -12, 0))           # рукоять
    b.box((0.03, 0.09, 0.07), (0.47, 0, 0.26), "plastic_grey", bevel=0.01)                                # подлокотник
    obj = b.build()
    geo.grime(obj, seed=23, dirt_height=0.05, strength=0.4, rust_tint=0.1, noise_scale=9.0)
    geo.collider_box("body", (1.0, 0.1, 0.24), (0.0, 0, 0.14))
    geo.collider_cylinder("coil", 0.14, 0.04, (-0.5, 0, 0.02), segments=8)
    geo.grip("left", (0.33, 0, 0.16), (0, 0, 90))
    geo.grip("right", (0.33, 0, 0.16), (0, 0, -90))
    pipeline.finish("tools/metal_detector", tri_budget=500)


def headlamp() -> None:
    """Налобный фонарь: коробочка с рефлектором на брезентовом ремне."""
    pipeline.reset_scene()
    b = geo.Builder("mesh")
    b.cylinder(0.09, 0.03, (0, 0, 0.03), "rag", segments=10)                                              # ремень кольцом
    b.cylinder(0.08, 0.034, (0, 0, 0.03), "soot", segments=10)
    b.box((0.07, 0.05, 0.06), (0, -0.1, 0.035), "paint_yellow", bevel=0.008)
    b.cylinder(0.03, 0.03, (0, -0.135, 0.035), "chrome", axis="Y", segments=8, cap_color="light_warm")
    b.box((0.05, 0.04, 0.05), (0, 0.1, 0.03), "plastic_black", bevel=0.006)                               # батарейный блок
    obj = b.build()
    geo.grime(obj, seed=24, dirt_height=0.01, strength=0.3, rust_tint=0.05, noise_scale=20.0)
    geo.collider_box("body", (0.19, 0.27, 0.07), (0, -0.01, 0.035))
    geo.grip("left", (-0.09, 0, 0.03), (0, 0, 90))
    geo.grip("right", (0.09, 0, 0.03), (0, 0, -90))
    pipeline.finish("tools/headlamp", tri_budget=400)


def build() -> None:
    shovel()
    crowbar()
    metal_detector()
    headlamp()


if __name__ == "__main__":
    build()
