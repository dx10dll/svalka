"""Телевизор с кинескопом: фанерный корпус, выпуклый экран, ручки, ножки.

25 кг, несёт один, хрупкий: в модели два варианта — целый (mesh) и разбитый
(mesh_broken, с дырой вместо экрана). Игра показывает один из них.
Запуск отдельно: blender -b -P art_src/blender/assets/items/tv_crt.py
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from lib import geo, pipeline  # noqa: E402

W, D, H = 0.56, 0.40, 0.44   # корпус: ширина, глубина, высота
LEG = 0.05
SCREEN_W, SCREEN_H = 0.34, 0.29
SCREEN_X = -0.075            # экран смещён влево, справа панель с ручками


def _tv(name: str, broken: bool):
    b = geo.Builder(name)
    z0 = LEG
    zc = z0 + H / 2
    front = -D / 2
    case = b.box((W, D, H), (0, 0, zc), "wood", bevel=0.03)
    b.chip_faces(case, "wood_dark", 0.35, seed=3, max_area=0.004)
    # лицевая панель и рамка экрана
    b.box((W - 0.04, 0.02, H - 0.04), (0, front - 0.004, zc), "plastic_black", bevel=0.008)
    b.box((SCREEN_W + 0.05, 0.025, SCREEN_H + 0.05), (SCREEN_X, front - 0.012, zc), "plastic_grey", bevel=0.012)
    if not broken:
        # выпуклый кинескоп с бликом
        b.box((SCREEN_W, 0.05, SCREEN_H), (SCREEN_X, front - 0.012, zc), "screen_crt", bevel=0.022)
        b.box((0.07, 0.006, 0.03), (SCREEN_X - 0.09, front - 0.04, zc + 0.08), "glass", rotation=(0, -18, 0))
    else:
        # дыра в темноту и торчащие осколки
        b.box((SCREEN_W, 0.02, SCREEN_H), (SCREEN_X, front + 0.004, zc), "soot")
        for i, (x, z, w, h, rot) in enumerate([(-0.13, -0.09, 0.10, 0.13, 20), (0.11, 0.08, 0.09, 0.14, -35),
                                               (0.10, -0.10, 0.12, 0.08, 50), (-0.10, 0.10, 0.08, 0.09, -15),
                                               (0.0, -0.12, 0.07, 0.06, 5)]):
            b.box((w, 0.008, h), (SCREEN_X + x, front - 0.012 - i * 0.002, zc + z), "glass", rotation=(0, rot, 0))
    # панель управления: решётка динамика и две ручки
    px = W / 2 - 0.085
    for i in range(5):
        b.box((0.09, 0.008, 0.012), (px, front - 0.016, zc + 0.14 - i * 0.028), "plastic_grey")
    b.cylinder(0.03, 0.035, (px, front - 0.03, zc - 0.045), "plastic_beige", axis="Y", segments=8, cap_color="plastic_grey")
    b.cylinder(0.022, 0.03, (px, front - 0.028, zc - 0.13), "plastic_beige", axis="Y", segments=6, cap_color="plastic_grey")
    b.box((0.012, 0.012, 0.03), (px, front - 0.05, zc - 0.045), "dial_needle")
    # задняя крышка с горбом кинескопа
    b.box((W - 0.12, 0.10, H - 0.14), (0, D / 2 + 0.045, zc), "plastic_brown", bevel=0.03)
    # ножки
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.cylinder(0.022, LEG, (sx * (W / 2 - 0.06), sy * (D / 2 - 0.06), LEG / 2), "plastic_black",
                       segments=5, radius_top=0.03)
    return b.build()


def build() -> None:
    pipeline.reset_scene()
    intact = _tv("mesh", broken=False)
    broken = _tv("mesh_broken", broken=True)
    geo.grime(intact, seed=4, dirt_height=0.3, strength=0.45, rust_tint=0.1)
    geo.grime(broken, seed=4, dirt_height=0.3, strength=0.45, rust_tint=0.1)
    geo.collider_box("body", (W, D + 0.08, H + LEG), (0, 0.04, (H + LEG) / 2))
    geo.grip("left", (-W / 2, 0, LEG + H * 0.35), (0, 0, 90))
    geo.grip("right", (W / 2, 0, LEG + H * 0.35), (0, 0, -90))
    pipeline.finish("items/tv_crt", tri_budget=800)


if __name__ == "__main__":
    build()
