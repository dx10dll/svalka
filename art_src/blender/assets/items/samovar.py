"""Латунный самовар: пузатый корпус, крышка с шишкой, труба, кран и две ручки.

6 кг, антиквариат: целый стоит впятеро дороже лома, помятый — как лом.
Два варианта модели: целый (mesh) и помятый (mesh_broken).
Запуск отдельно: blender -b -P art_src/blender/assets/items/samovar.py
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from lib import geo, pipeline  # noqa: E402

SEG = 10


def _samovar(name: str, broken: bool):
    b = geo.Builder(name)
    lean = (0, 9, 0) if broken else (0, 0, 0)
    # поддон и ножки
    b.box((0.20, 0.20, 0.025), (0, 0, 0.055), "brass_dark", bevel=0.008)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.cylinder(0.018, 0.045, (sx * 0.075, sy * 0.075, 0.0225), "brass_dark", segments=5, radius_top=0.012)
    b.cylinder(0.05, 0.05, (0, 0, 0.09), "brass_dark", segments=SEG, radius_top=0.085)   # шейка
    # корпус: два усечённых конуса образуют «пузо»
    b.cylinder(0.085, 0.10, (0, 0, 0.165), "brass", segments=SEG, radius_top=0.135)
    b.cylinder(0.135, 0.11, (0, 0, 0.27), "brass", segments=SEG, radius_top=0.115)
    b.cylinder(0.118, 0.02, (0, 0, 0.335), "brass_dark", segments=SEG)                    # поясок
    if broken:
        # вмятина: тёмная заплата на боку и съехавшая крышка
        b.box((0.11, 0.05, 0.12), (0.02, -0.105, 0.22), "brass_dark", bevel=0.02, rotation=(0, 0, 8))
        b.box((0.07, 0.03, 0.07), (0.03, -0.118, 0.22), "soot", bevel=0.012, rotation=(0, 0, 8))
    # крышка, шишка и труба
    lid_x = 0.035 if broken else 0.0
    b.cylinder(0.112, 0.035, (lid_x, 0, 0.36), "brass", segments=SEG, radius_top=0.07)
    b.cylinder(0.045, 0.09, (lid_x, 0, 0.42), "brass_dark", segments=6, radius_top=0.036)
    b.cylinder(0.055, 0.03, (lid_x, 0, 0.475), "brass", segments=6, radius_top=0.03)
    for sy in (-1, 1):
        b.box((0.022, 0.022, 0.03), (lid_x, sy * 0.075, 0.385), "wood_dark", bevel=0.006)   # шишки крышки
    # ручки по бокам: скоба с деревянной накладкой
    for sx in (-1, 1):
        b.box((0.05, 0.022, 0.018), (sx * 0.15, 0, 0.30), "brass_dark", rotation=lean)
        b.box((0.05, 0.022, 0.018), (sx * 0.15, 0, 0.22), "brass_dark", rotation=lean)
        b.box((0.026, 0.03, 0.10), (sx * 0.175, 0, 0.26), "wood_dark", bevel=0.008)
    # кран с вертушкой
    b.box((0.03, 0.09, 0.03), (0, -0.14, 0.15), "brass_dark", bevel=0.008)
    b.box((0.028, 0.028, 0.05), (0, -0.18, 0.13), "brass", bevel=0.008)
    b.box((0.07, 0.014, 0.03), (0, -0.15, 0.185), "brass", bevel=0.006, rotation=(0, 0, 25 if broken else 0))
    return b.build()


def build() -> None:
    pipeline.reset_scene()
    intact = _samovar("mesh", broken=False)
    broken = _samovar("mesh_broken", broken=True)
    geo.grime(intact, seed=2, dirt_height=0.25, strength=0.35, rust_tint=0.12, noise_scale=9.0)
    geo.grime(broken, seed=2, dirt_height=0.6, strength=0.6, rust_tint=0.3, noise_scale=9.0)
    geo.collider_cylinder("body", 0.14, 0.34, (0, 0, 0.17), segments=8)
    geo.collider_cylinder("top", 0.06, 0.15, (0, 0, 0.41), segments=6)
    geo.grip("left", (-0.175, 0, 0.26), (0, 0, 90))
    geo.grip("right", (0.175, 0, 0.26), (0, 0, -90))
    pipeline.finish("items/samovar", tri_budget=800)


if __name__ == "__main__":
    build()
