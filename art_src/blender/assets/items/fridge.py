"""Холодильник советского типа: скруглённый эмалевый корпус, одна дверь, ручка-скоба.

60 кг, один только волочит. Сдаётся как чёрный металл (плюс медный компрессор).
Запуск отдельно: blender -b -P art_src/blender/assets/items/fridge.py
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from lib import geo, pipeline  # noqa: E402

W, D, H = 0.58, 0.56, 1.36
LEG = 0.04


def build() -> None:
    pipeline.reset_scene()
    b = geo.Builder("mesh")
    zc = LEG + H / 2
    front = -D / 2
    body = b.box((W, D, H), (0, 0.02, zc), "enamel_cream", bevel=0.06, segments=2)
    # дверь: чуть выступает, с зазором-тенью по периметру
    b.box((W - 0.03, 0.02, H - 0.05), (0, front + 0.012, zc), "soot")
    door = b.box((W - 0.01, 0.055, H - 0.03), (0, front - 0.02, zc), "enamel_white", bevel=0.035, segments=2)
    # ручка-скоба и шильдик
    b.box((0.035, 0.045, 0.30), (W / 2 - 0.085, front - 0.07, zc + 0.12), "chrome", bevel=0.012)
    b.box((0.05, 0.03, 0.03), (W / 2 - 0.085, front - 0.055, zc + 0.255), "steel_dark")
    b.box((0.05, 0.03, 0.03), (W / 2 - 0.085, front - 0.055, zc - 0.015), "steel_dark")
    b.box((0.16, 0.008, 0.035), (-0.12, front - 0.05, LEG + H - 0.14), "paint_red", bevel=0.004)
    b.box((0.06, 0.008, 0.012), (-0.15, front - 0.056, LEG + H - 0.14), "chrome")
    # решётка конденсатора и компрессор сзади
    back = D / 2 + 0.02
    b.box((W - 0.14, 0.02, H * 0.55), (0, back + 0.012, zc + 0.12), "paint_black")
    for i in range(6):
        b.box((W - 0.10, 0.03, 0.014), (0, back + 0.022, zc - 0.20 + i * 0.13), "steel_dark")
    b.cylinder(0.085, 0.16, (0.08, back - 0.02, LEG + 0.14), "paint_black", axis="X", segments=8, cap_color="copper_dark")
    # ножки
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box((0.05, 0.05, LEG), (sx * (W / 2 - 0.07), sy * (D / 2 - 0.07) + 0.02, LEG / 2), "plastic_black")
    # сколы эмали и ржавчина по фаскам
    b.chip_faces(body + door, "rust", 0.14, seed=21, max_area=0.006)
    b.chip_faces(body + door, "rust_dark", 0.06, seed=22, max_area=0.006)
    obj = b.build()
    geo.grime(obj, seed=14, dirt_height=0.22, strength=0.7, rust_tint=0.45, noise_scale=3.5)
    geo.collider_box("body", (W, D + 0.08, H + LEG), (0, 0.0, (H + LEG) / 2))
    geo.grip("top_left", (-W / 2, 0, LEG + H - 0.05), (0, 0, 90))
    geo.grip("top_right", (W / 2, 0, LEG + H - 0.05), (0, 0, -90))
    geo.grip("mid_left", (-W / 2, 0, zc), (0, 0, 90))
    geo.grip("mid_right", (W / 2, 0, zc), (0, 0, -90))
    geo.grip("bottom_left", (-W / 2, 0, 0.1), (0, 0, 90))
    geo.grip("bottom_right", (W / 2, 0, 0.1), (0, 0, -90))
    pipeline.finish("items/fridge", tri_budget=800)


if __name__ == "__main__":
    build()
