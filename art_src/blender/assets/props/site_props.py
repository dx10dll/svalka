"""Окружение свалки: фонарный столб, будка сторожа, бочка для костра.

Начало координат у всех — низ по центру. Светящиеся части (лампа, окно, угли)
окрашены ячейками света палитры, сам свет ставит игра.
Запуск отдельно: blender -b -P art_src/blender/assets/props/site_props.py
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from lib import geo, pipeline  # noqa: E402


def lamp_post() -> None:
    """Бетонный столб 6 м с «гусаком» и плафоном. Лампа — в точке (0.9, 0, 5.75)."""
    pipeline.reset_scene()
    b = geo.Builder("mesh")
    b.box((0.34, 0.34, 0.5), (0, 0, 0.25), "concrete_dark", bevel=0.04)
    pole = b.cylinder(0.11, 5.6, (0, 0, 3.2), "concrete", segments=6, radius_top=0.075)
    b.chip_faces(pole, "concrete_dark", 0.3, seed=3, max_area=0.5)
    b.cylinder(0.035, 1.0, (0.45, 0, 5.92), "steel_dark", axis="X", segments=5, rotation=(0, -12, 0))
    b.box((0.5, 0.2, 0.1), (0.95, 0, 5.84), "steel_dark", bevel=0.03)
    b.box((0.4, 0.15, 0.05), (0.95, 0, 5.77), "light_sodium")
    b.box((0.12, 0.16, 0.2), (0.0, 0.0, 5.3), "rust_dark")            # коробка с проводкой
    b.cylinder(0.012, 1.1, (0.0, 0.0, 4.7), "cable_insulation", segments=4)
    obj = b.build()
    geo.grime(obj, seed=5, dirt_height=1.2, strength=0.5, rust_tint=0.2, noise_scale=2.0)
    geo.collider_box("pole", (0.26, 0.26, 6.0), (0, 0, 3.0))
    pipeline.finish("props/lamp_post", tri_budget=300)


def guard_booth() -> None:
    """Будка сторожа 2.4 × 2.2 м: дощатые стены, окно со светом, дверь, односкатная крыша, труба."""
    pipeline.reset_scene()
    b = geo.Builder("mesh")
    w, d, h = 2.4, 2.2, 2.3
    b.box((w + 0.3, d + 0.3, 0.16), (0, 0, 0.08), "concrete_dark", bevel=0.03)
    walls = b.box((w, d, h), (0, 0, 0.16 + h / 2), "paint_green_dark", bevel=0.02)
    b.chip_faces(walls, "wood_dark", 0.25, seed=8, max_area=2.0)
    # вертикальные доски-нащельники
    for i in range(7):
        x = -w / 2 + 0.2 + i * (w - 0.4) / 6
        b.box((0.06, 0.03, h - 0.1), (x, -d / 2 - 0.015, 0.16 + h / 2), "paint_green")
        b.box((0.06, 0.03, h - 0.1), (x, d / 2 + 0.015, 0.16 + h / 2), "wood_dark")
    # окно на дорогу: рама, светящееся стекло, переплёт
    b.box((1.0, 0.06, 0.8), (-0.45, -d / 2 - 0.03, 1.55), "enamel_white", bevel=0.01)
    b.box((0.86, 0.07, 0.66), (-0.45, -d / 2 - 0.035, 1.55), "light_warm")
    b.box((0.04, 0.08, 0.66), (-0.45, -d / 2 - 0.04, 1.55), "enamel_white")
    b.box((0.86, 0.08, 0.04), (-0.45, -d / 2 - 0.04, 1.6), "enamel_white")
    b.box((1.1, 0.14, 0.05), (-0.45, -d / 2 - 0.07, 1.12), "wood")                  # подоконник
    # дверь сбоку и крыльцо
    b.box((0.06, 0.85, 1.9), (w / 2 + 0.03, 0.3, 0.16 + 0.95), "paint_brown", bevel=0.01)
    b.box((0.05, 0.06, 0.14), (w / 2 + 0.08, 0.0, 1.15), "steel_dark")
    b.box((0.6, 1.1, 0.12), (w / 2 + 0.36, 0.3, 0.1), "wood_dark")
    # крыша с уклоном назад и свесами
    b.box((w + 0.5, d + 0.6, 0.08), (0, 0, 0.16 + h + 0.12), "rust_dark", rotation=(7, 0, 0))
    b.box((w + 0.5, 0.06, 0.12), (0, -d / 2 - 0.3, 0.16 + h + 0.2), "rust", rotation=(7, 0, 0))
    # печная труба с колпаком
    b.cylinder(0.07, 0.9, (0.75, 0.5, 0.16 + h + 0.5), "rust", segments=6)
    b.cylinder(0.13, 0.05, (0.75, 0.5, 0.16 + h + 0.98), "rust_dark", segments=6, radius_top=0.03)
    # табличка и фонарь над окном
    b.box((0.5, 0.03, 0.18), (0.7, -d / 2 - 0.03, 2.05), "paint_yellow", bevel=0.005)
    b.box((0.36, 0.035, 0.03), (0.7, -d / 2 - 0.035, 2.07), "paint_black")
    b.box((0.36, 0.035, 0.03), (0.7, -d / 2 - 0.035, 2.0), "paint_black")
    obj = b.build()
    geo.grime(obj, seed=6, dirt_height=0.7, strength=0.55, rust_tint=0.2, noise_scale=1.6)
    geo.collider_box("walls", (w, d, h + 0.3), (0, 0, 0.16 + (h + 0.3) / 2))
    geo.collider_box("base", (w + 0.3, d + 0.3, 0.16), (0, 0, 0.08))
    pipeline.finish("props/guard_booth", tri_budget=700)


def fire_barrel() -> None:
    """Ржавая бочка, в которой жгут костёр: прогоревшие дыры, угли сверху."""
    pipeline.reset_scene()
    b = geo.Builder("mesh")
    body = b.cylinder(0.3, 0.86, (0, 0, 0.43), "rust_dark", segments=10)
    b.chip_faces(body, "soot", 0.35, seed=11, max_area=0.2)
    b.chip_faces(body, "rust", 0.25, seed=12, max_area=0.2)
    for z in (0.28, 0.6):
        b.cylinder(0.31, 0.03, (0, 0, z), "rust", segments=10)
    # прогары: светятся изнутри
    for i, (ang, z) in enumerate(((20, 0.2), (140, 0.34), (255, 0.16), (320, 0.42))):
        import math
        x, y = math.cos(math.radians(ang)) * 0.295, math.sin(math.radians(ang)) * 0.295
        b.box((0.09, 0.09, 0.07 + 0.02 * i), (x, y, z), "ember", rotation=(0, 0, ang + 45))
    b.cylinder(0.27, 0.04, (0, 0, 0.8), "ember", segments=10)
    b.box((0.4, 0.07, 0.06), (0.02, 0.0, 0.86), "soot", rotation=(0, 22, 30))
    b.box((0.36, 0.06, 0.06), (-0.04, 0.03, 0.88), "wood_dark", rotation=(0, -18, 110))
    obj = b.build()
    geo.grime(obj, seed=7, dirt_height=0.3, strength=0.4, rust_tint=0.3, noise_scale=5.0)
    geo.collider_cylinder("body", 0.3, 0.86, (0, 0, 0.43), segments=8)
    pipeline.finish("props/fire_barrel", tri_budget=300)


def build() -> None:
    lamp_post()
    guard_booth()
    fire_barrel()


if __name__ == "__main__":
    build()
