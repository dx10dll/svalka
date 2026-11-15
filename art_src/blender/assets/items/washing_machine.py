"""Стиральная машина с фронтальной загрузкой: люк-иллюминатор, панель с ручками.

45 кг, один только волочит. Сдаётся как чёрный металл (плюс алюминиевый барабан).
Запуск отдельно: blender -b -P art_src/blender/assets/items/washing_machine.py
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from lib import geo, pipeline  # noqa: E402

W, D, H = 0.60, 0.50, 0.82
LEG = 0.03


def build() -> None:
    pipeline.reset_scene()
    b = geo.Builder("mesh")
    zc = LEG + H / 2
    front = -D / 2
    body = b.box((W, D, H), (0, 0, zc), "enamel_grey", bevel=0.035)
    # панель управления сверху спереди
    b.box((W - 0.03, 0.02, 0.13), (0, front - 0.006, LEG + H - 0.085), "plastic_beige", bevel=0.008)
    b.cylinder(0.04, 0.035, (W / 2 - 0.10, front - 0.03, LEG + H - 0.085), "plastic_grey", axis="Y", segments=8,
               cap_color="plastic_black")
    b.box((0.012, 0.012, 0.04), (W / 2 - 0.10, front - 0.05, LEG + H - 0.07), "dial_white")
    for i in range(3):
        b.box((0.04, 0.02, 0.03), (-W / 2 + 0.09 + i * 0.06, front - 0.02, LEG + H - 0.085),
              ("led_red", "plastic_grey", "plastic_grey")[i], bevel=0.006)
    b.box((0.13, 0.012, 0.05), (-0.01, front - 0.016, LEG + H - 0.085), "paint_blue_dark")  # лоток порошка
    # люк: хромированное кольцо, тёмное стекло, в глубине блестит барабан
    door_z = LEG + H * 0.42
    b.cylinder(0.205, 0.05, (0, front - 0.02, door_z), "chrome", axis="Y", segments=10)
    b.cylinder(0.16, 0.07, (0, front - 0.025, door_z), "glass_dark", axis="Y", segments=10, radius_top=0.13)
    b.cylinder(0.07, 0.075, (0.02, front - 0.027, door_z + 0.02), "aluminium_dark", axis="Y", segments=6)
    b.box((0.04, 0.04, 0.09), (-0.2, front - 0.04, door_z), "plastic_grey", bevel=0.01)  # ручка люка
    # цоколь с фильтром
    b.box((W - 0.04, 0.015, 0.09), (0, front - 0.004, LEG + 0.065), "plastic_grey")
    b.cylinder(0.03, 0.02, (W / 2 - 0.09, front - 0.012, LEG + 0.065), "plastic_black", axis="Y", segments=6)
    # сзади: шланги
    b.cylinder(0.02, 0.3, (-0.15, D / 2 + 0.02, zc + 0.1), "rubber_worn", axis="Z", segments=5)
    b.cylinder(0.016, 0.24, (0.12, D / 2 + 0.02, zc - 0.05), "cable_blue", axis="Z", segments=5)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.cylinder(0.025, LEG, (sx * (W / 2 - 0.06), sy * (D / 2 - 0.06), LEG / 2), "plastic_black", segments=5)
    b.chip_faces(body, "rust", 0.18, seed=31, max_area=0.006)
    obj = b.build()
    geo.grime(obj, seed=17, dirt_height=0.3, strength=0.65, rust_tint=0.5, noise_scale=4.0)
    geo.collider_box("body", (W, D + 0.04, H + LEG), (0, 0, (H + LEG) / 2))
    geo.grip("left", (-W / 2, 0, LEG + H - 0.05), (0, 0, 90))
    geo.grip("right", (W / 2, 0, LEG + H - 0.05), (0, 0, -90))
    geo.grip("bottom_left", (-W / 2, 0, 0.12), (0, 0, 90))
    geo.grip("bottom_right", (W / 2, 0, 0.12), (0, 0, -90))
    pipeline.finish("items/washing_machine", tri_budget=800)


if __name__ == "__main__":
    build()
