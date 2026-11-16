"""Товары лавки, которые ставятся на буханку: пакет рессор, колесо-вездеход, прожектор.

Лежат на верстаке в гараже вместо надписей. Начало координат — низ по центру.
Запуск отдельно: blender -b -P art_src/blender/assets/props/shop_goods.py
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from lib import geo, pipeline  # noqa: E402


def springs() -> None:
    """Пакет листовых рессор: пять полос разной длины, стянутых хомутами."""
    pipeline.reset_scene()
    b = geo.Builder("mesh")
    for i, length in enumerate((0.9, 0.78, 0.64, 0.5, 0.36)):
        b.box((length, 0.09, 0.022), (0, 0, 0.03 + i * 0.026), "steel_dark" if i % 2 else "steel", bevel=0.004)
    for x in (-0.14, 0.14):
        b.box((0.035, 0.11, 0.16), (x, 0, 0.08), "paint_red_dark", bevel=0.005)        # хомуты
    for sx in (-1, 1):
        b.cylinder(0.035, 0.1, (sx * 0.45, 0, 0.045), "steel_dark", axis="Y", segments=7)   # ушки
    obj = b.build()
    geo.grime(obj, seed=51, dirt_height=0.05, strength=0.3, rust_tint=0.3, noise_scale=6.0)
    pipeline.finish("props/shop_springs", tri_budget=400)


def tyre() -> None:
    """Колесо с грязевым протектором: шина с шашками, диск, пять болтов."""
    pipeline.reset_scene()
    b = geo.Builder("mesh")
    b.cylinder(0.38, 0.24, (0, 0, 0.38), "tire", axis="Y", segments=12, bevel=0.03)
    for i in range(12):
        import math
        a = math.radians(i * 30)
        b.box((0.09, 0.27, 0.06), (math.cos(a) * 0.385, 0, 0.38 + math.sin(a) * 0.385), "rubber",
              rotation=(0, -math.degrees(a) + 90, 0), bevel=0.01)                      # шашки
    b.cylinder(0.2, 0.26, (0, 0, 0.38), "paint_khaki", axis="Y", segments=10)          # диск
    b.cylinder(0.07, 0.28, (0, 0, 0.38), "steel_dark", axis="Y", segments=7)           # ступица
    for i in range(5):
        a = math.radians(i * 72)
        b.cylinder(0.018, 0.275, (math.cos(a) * 0.13, 0, 0.38 + math.sin(a) * 0.13), "steel", axis="Y", segments=5)
    obj = b.build()
    geo.grime(obj, seed=52, dirt_height=0.2, strength=0.5, rust_tint=0.1, noise_scale=5.0)
    pipeline.finish("props/shop_tyre", tri_budget=900)


def searchlight() -> None:
    """Прожектор на скобе: круглый корпус, светлое стекло, решётка, провод."""
    pipeline.reset_scene()
    b = geo.Builder("mesh")
    b.box((0.26, 0.2, 0.03), (0, 0, 0.015), "steel_dark", bevel=0.006)                  # площадка
    for sx in (-1, 1):
        b.box((0.025, 0.05, 0.3), (sx * 0.2, 0, 0.17), "steel_dark", bevel=0.005)      # скоба
    b.cylinder(0.17, 0.2, (0, 0.02, 0.28), "paint_black", axis="Y", segments=10, radius_top=0.12)
    b.cylinder(0.175, 0.03, (0, -0.09, 0.28), "chrome", axis="Y", segments=10)         # ободок
    b.cylinder(0.15, 0.012, (0, -0.105, 0.28), "light_warm", axis="Y", segments=10)    # стекло
    b.box((0.3, 0.012, 0.015), (0, -0.115, 0.28), "steel_dark")
    b.box((0.015, 0.012, 0.3), (0, -0.115, 0.28), "steel_dark")
    b.cylinder(0.012, 0.16, (0.05, 0.16, 0.2), "cable_insulation", axis="Y", segments=5, rotation=(-30, 0, 0))
    obj = b.build()
    geo.grime(obj, seed=53, dirt_height=0.1, strength=0.3, rust_tint=0.2, noise_scale=6.0)
    pipeline.finish("props/shop_searchlight", tri_budget=500)


def build() -> None:
    springs()
    tyre()
    searchlight()


if __name__ == "__main__":
    build()
