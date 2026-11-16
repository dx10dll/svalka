"""Остаток стартового набора: мешок банок, аккумулятор, чугунная ванна,
автомобильный радиатор, радиоприёмник, фотоаппарат.

Один скрипт собирает шесть предметов. Начало координат — низ по центру.
Запуск отдельно: blender -b -P art_src/blender/assets/items/more_items.py
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from lib import geo, pipeline  # noqa: E402


def cans_bag() -> None:
    """Мешок алюминиевых банок, 5 кг: сетчатый мешок, сверху торчат банки."""
    pipeline.reset_scene()
    b = geo.Builder("mesh")
    b.box((0.5, 0.42, 0.42), (0, 0, 0.22), "bag_white", bevel=0.12, segments=2)
    b.box((0.2, 0.18, 0.12), (0, 0, 0.47), "bag_white", bevel=0.05)              # горловина
    b.box((0.24, 0.05, 0.03), (0, 0, 0.44), "rag", bevel=0.01)                   # завязка
    for i, (x, y, z, rot) in enumerate([(-0.12, 0.05, 0.5, (70, 0, 20)), (0.1, -0.04, 0.52, (60, 20, -30)),
                                        (0.0, 0.1, 0.55, (80, -10, 60)), (0.27, 0.0, 0.2, (0, 90, 0)),
                                        (-0.26, -0.05, 0.3, (20, 80, 0))]):
        b.cylinder(0.033, 0.12, (x, y, z), "aluminium" if i % 2 else "paint_red", segments=6,
                   cap_color="aluminium_dark", rotation=rot)
    obj = b.build()
    geo.grime(obj, seed=11, dirt_height=0.2, strength=0.4, rust_tint=0.05, noise_scale=6.0)
    geo.collider_box("body", (0.5, 0.42, 0.5), (0, 0, 0.25))
    geo.grip("left", (-0.2, 0, 0.48), (0, 0, 90))
    geo.grip("right", (0.2, 0, 0.48), (0, 0, -90))
    pipeline.finish("items/cans_bag", tri_budget=700)


def car_battery() -> None:
    """Аккумулятор, 15 кг: чёрный ящик, крышка с пробками, две клеммы, ручка-ремень."""
    pipeline.reset_scene()
    b = geo.Builder("mesh")
    b.box((0.34, 0.18, 0.2), (0, 0, 0.1), "plastic_black", bevel=0.012)
    b.box((0.35, 0.19, 0.03), (0, 0, 0.205), "plastic_grey", bevel=0.008)
    for i in range(6):
        b.cylinder(0.014, 0.014, (-0.11 + i * 0.044, 0.03, 0.226), "paint_yellow", segments=6)
    b.cylinder(0.016, 0.03, (-0.13, -0.05, 0.235), "lead", segments=6)
    b.cylinder(0.016, 0.03, (0.13, -0.05, 0.235), "lead", segments=6)
    b.box((0.03, 0.03, 0.006), (-0.13, -0.05, 0.222), "paint_red")
    b.box((0.03, 0.03, 0.006), (0.13, -0.05, 0.222), "paint_blue")
    b.box((0.2, 0.02, 0.012), (0, 0.0, 0.3), "rubber_worn", bevel=0.004)          # ручка
    for sx in (-1, 1):
        b.box((0.012, 0.02, 0.09), (sx * 0.1, 0.0, 0.26), "rubber_worn")
    b.box((0.2, 0.004, 0.08), (0, -0.092, 0.1), "paper")                           # наклейка без надписей
    obj = b.build()
    geo.grime(obj, seed=12, dirt_height=0.15, strength=0.5, rust_tint=0.15, noise_scale=8.0)
    geo.collider_box("body", (0.35, 0.19, 0.24), (0, 0, 0.12))
    geo.grip("left", (-0.08, 0, 0.3), (0, 0, 90))
    geo.grip("right", (0.08, 0, 0.3), (0, 0, -90))
    pipeline.finish("items/car_battery", tri_budget=500)


def bathtub() -> None:
    """Чугунная ванна, 110 кг: корыто на четырёх ножках, эмаль внутри, ржавчина снаружи."""
    pipeline.reset_scene()
    b = geo.Builder("mesh")
    length, width, height, wall = 1.6, 0.7, 0.5, 0.05
    z0 = 0.12
    b.box((length - 0.16, width - 0.12, wall), (0, 0, z0 + wall / 2), "cast_iron", bevel=0.02)            # дно
    b.box((length - 0.2, width - 0.18, 0.012), (0, 0, z0 + wall + 0.004), "enamel_white")                # эмаль дна
    for sy in (-1, 1):
        b.box((length - 0.06, wall, height), (0, sy * (width / 2 - wall / 2), z0 + height / 2), "cast_iron",
              bevel=0.015, rotation=(sy * -6, 0, 0))
        b.box((length - 0.16, 0.012, height - 0.08), (0, sy * (width / 2 - wall - 0.004), z0 + height / 2 + 0.02),
              "enamel_white", rotation=(sy * -6, 0, 0))
    for sx, tilt in ((-1, 14), (1, -6)):
        b.box((wall, width - 0.06, height), (sx * (length / 2 - wall / 2 - 0.02), 0, z0 + height / 2), "cast_iron",
              bevel=0.015, rotation=(0, tilt, 0))
        b.box((0.012, width - 0.16, height - 0.08), (sx * (length / 2 - wall - 0.03), 0, z0 + height / 2 + 0.02),
              "enamel_cream", rotation=(0, tilt, 0))
    # бортик: четыре планки по краю, середина открыта
    for sy in (-1, 1):
        b.box((length + 0.06, 0.09, 0.03), (0, sy * (width / 2 + 0.01), z0 + height), "enamel_white", bevel=0.01)
    b.box((0.09, width - 0.06, 0.03), (-(length / 2 + 0.04), 0, z0 + height), "enamel_white", bevel=0.01)
    b.box((0.09, width - 0.06, 0.03), (length / 2 - 0.02, 0, z0 + height), "enamel_white", bevel=0.01)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.cylinder(0.04, z0, (sx * 0.55, sy * 0.22, z0 / 2), "cast_iron_dark", segments=6, radius_top=0.055)
    b.cylinder(0.03, 0.02, (0.6, 0, z0 + wall + 0.01), "chrome", segments=6)                             # слив
    obj = b.build()
    geo.grime(obj, seed=13, dirt_height=0.35, strength=0.7, rust_tint=0.5, noise_scale=2.5)
    geo.collider_box("bottom", (length - 0.1, width - 0.06, 0.2), (0, 0, 0.12))
    geo.collider_box("side_l", (length, 0.07, height), (0, width / 2 - 0.035, z0 + height / 2))
    geo.collider_box("side_r", (length, 0.07, height), (0, -width / 2 + 0.035, z0 + height / 2))
    geo.collider_box("end_a", (0.07, width, height), (length / 2 - 0.05, 0, z0 + height / 2))
    geo.collider_box("end_b", (0.07, width, height), (-length / 2 + 0.05, 0, z0 + height / 2))
    geo.grip("left", (-length / 2, 0, z0 + height), (0, 0, 90))
    geo.grip("right", (length / 2, 0, z0 + height), (0, 0, -90))
    pipeline.finish("items/bathtub", tri_budget=900)


def car_radiator() -> None:
    """Автомобильный радиатор, 8 кг: медные соты между двумя латунными бачками."""
    pipeline.reset_scene()
    b = geo.Builder("mesh")
    b.box((0.56, 0.05, 0.36), (0, 0, 0.23), "copper_dark")
    for i in range(9):
        b.box((0.012, 0.058, 0.36), (-0.24 + i * 0.06, 0, 0.23), "copper")
    for i in range(4):
        b.box((0.56, 0.054, 0.008), (0, 0, 0.1 + i * 0.085), "copper_oxide")
    b.box((0.6, 0.08, 0.06), (0, 0, 0.44), "brass", bevel=0.015)
    b.box((0.6, 0.08, 0.06), (0, 0, 0.03), "brass_dark", bevel=0.015)
    b.cylinder(0.03, 0.03, (-0.18, 0, 0.485), "brass_dark", segments=6)                                  # горловина
    b.cylinder(0.02, 0.08, (0.22, 0.07, 0.44), "brass", axis="Y", segments=6)                            # патрубки
    b.cylinder(0.02, 0.08, (-0.22, 0.07, 0.03), "brass", axis="Y", segments=6)
    for sx in (-1, 1):
        b.box((0.02, 0.06, 0.4), (sx * 0.29, 0, 0.23), "steel_dark")
    obj = b.build()
    geo.grime(obj, seed=14, dirt_height=0.3, strength=0.55, rust_tint=0.1, noise_scale=7.0)
    geo.collider_box("body", (0.6, 0.09, 0.47), (0, 0, 0.235))
    geo.grip("left", (-0.3, 0, 0.3), (0, 0, 90))
    geo.grip("right", (0.3, 0, 0.3), (0, 0, -90))
    pipeline.finish("items/car_radiator", tri_budget=700)


def _radio(name: str, broken: bool):
    b = geo.Builder(name)
    b.box((0.42, 0.14, 0.26), (0, 0, 0.13), "wood" if not broken else "wood_dark", bevel=0.015)
    b.box((0.2, 0.012, 0.18), (-0.085, -0.071, 0.14), "rag")                                             # ткань динамика
    for i in range(4):
        b.box((0.2, 0.016, 0.008), (-0.085, -0.072, 0.075 + i * 0.045), "wood_dark")
    b.box((0.15, 0.012, 0.07), (0.115, -0.071, 0.185), "soot" if broken else "dial_white")               # шкала
    if not broken:
        b.box((0.004, 0.014, 0.06), (0.09, -0.073, 0.185), "dial_needle")
    for i, x in enumerate((0.07, 0.16)):
        if broken and i == 1:
            continue                                                                                      # ручка отлетела
        b.cylinder(0.022, 0.025, (x, -0.08, 0.085), "bakelite", axis="Y", segments=8)
    b.box((0.02, 0.02, 0.3), (0.17, 0.04, 0.4 if not broken else 0.3), "chrome",
          rotation=(0, 0, 0) if not broken else (0, 55, 0))                                              # антенна
    if broken:
        b.box((0.12, 0.02, 0.1), (-0.12, -0.066, 0.2), "soot", rotation=(0, 20, 0))                      # дыра в ткани
    return b.build()


def radio() -> None:
    """Ламповый радиоприёмник, 3 кг, антиквариат. Хрупкий: целый и разбитый варианты."""
    pipeline.reset_scene()
    intact = _radio("mesh", False)
    broken = _radio("mesh_broken", True)
    geo.grime(intact, seed=15, dirt_height=0.15, strength=0.35, rust_tint=0.05, noise_scale=8.0)
    geo.grime(broken, seed=15, dirt_height=0.3, strength=0.6, rust_tint=0.1, noise_scale=8.0)
    geo.collider_box("body", (0.42, 0.14, 0.26), (0, 0, 0.13))
    geo.grip("left", (-0.21, 0, 0.14), (0, 0, 90))
    geo.grip("right", (0.21, 0, 0.14), (0, 0, -90))
    pipeline.finish("items/radio", tri_budget=700)


def _camera(name: str, broken: bool):
    b = geo.Builder(name)
    b.box((0.15, 0.05, 0.085), (0, 0, 0.045), "plastic_black", bevel=0.008)
    b.box((0.152, 0.052, 0.022), (0, 0, 0.08), "chrome", bevel=0.005)                                    # верхняя панель
    b.box((0.152, 0.052, 0.012), (0, 0, 0.008), "chrome", bevel=0.004)
    b.cylinder(0.034, 0.04, (0.01, -0.04, 0.045), "chrome", axis="Y", segments=8)                        # объектив
    b.cylinder(0.026, 0.02, (0.01, -0.065 if not broken else -0.058, 0.045), "steel_dark", axis="Y", segments=8,
               cap_color="soot" if broken else "glass_dark", rotation=(0, 0, 0) if not broken else (0, 0, 14))
    b.box((0.03, 0.03, 0.02), (-0.04, 0, 0.1), "steel_dark", bevel=0.004)                                # видоискатель
    b.cylinder(0.012, 0.012, (0.05, 0, 0.097), "chrome", segments=6)                                     # спуск
    b.cylinder(0.016, 0.01, (-0.06, 0, 0.096), "chrome", segments=6)
    if broken:
        b.box((0.06, 0.006, 0.05), (-0.04, -0.027, 0.045), "soot", rotation=(0, 0, 0))
    return b.build()


def camera() -> None:
    """Плёночный фотоаппарат, 1 кг, антиквариат. Хрупкий."""
    pipeline.reset_scene()
    intact = _camera("mesh", False)
    broken = _camera("mesh_broken", True)
    geo.grime(intact, seed=16, dirt_height=0.03, strength=0.25, rust_tint=0.05, noise_scale=20.0)
    geo.grime(broken, seed=16, dirt_height=0.06, strength=0.5, rust_tint=0.1, noise_scale=20.0)
    geo.collider_box("body", (0.15, 0.09, 0.11), (0, -0.015, 0.055))
    geo.grip("left", (-0.075, 0, 0.05), (0, 0, 90))
    geo.grip("right", (0.075, 0, 0.05), (0, 0, -90))
    pipeline.finish("items/camera", tri_budget=500)


def build() -> None:
    cans_bag()
    car_battery()
    bathtub()
    car_radiator()
    radio()
    camera()


if __name__ == "__main__":
    build()
