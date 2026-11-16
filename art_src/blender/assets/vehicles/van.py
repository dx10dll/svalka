"""Фургон артели: вагонная компоновка, кабина над передней осью, грузовой отсек
с двумя распашными задними дверями. Без марок и шильдиков.

Перёд смотрит в -Y Blender (в Godot это +Z — туда едет VehicleBody3D), левый
борт (водитель) — +X. Начало координат — на земле под центром кузова.
Отдельные объекты: mesh (кузов), door_l / door_r (петля в начале координат
объекта), wheel (центр колеса). Точки grip_* — места сидений, фар и груза.
Запуск отдельно: blender -b -P art_src/blender/assets/vehicles/van.py
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from lib import geo, pipeline  # noqa: E402

L, W = 4.3, 1.9              # длина и ширина кузова
Z0, Z1 = 0.45, 2.15          # низ и крыша
FRONT, REAR = -L / 2, L / 2
CAB_END = FRONT + 1.3        # перегородка кабины
FLOOR = 0.6                  # верх пола грузового отсека
T = 0.06                     # толщина стенок
BODY, BODY2 = "paint_khaki", "paint_green_dark"
WHEEL_R, WHEEL_W = 0.38, 0.24
AXLE_F, AXLE_R = FRONT + 0.75, REAR - 1.05
TRACK = 0.78


def _body() -> None:
    b = geo.Builder("mesh")
    cargo_len = REAR - CAB_END
    cargo_mid = (REAR + CAB_END) / 2
    # пол и рама
    b.box((W, L, FLOOR - Z0), (0, 0, (FLOOR + Z0) / 2), "steel_dark")
    b.box((W - T * 2, cargo_len - 0.02, 0.02), (0, cargo_mid, FLOOR + 0.01), "wood_dark")     # настил
    for y in (FRONT + 0.3, 0.0, REAR - 0.3):
        b.box((1.2, 0.12, 0.14), (0, y, Z0 - 0.07), "paint_black")
    # борта грузового отсека с нижним поясом другого цвета и подштамповками
    for sx in (-1, 1):
        x = sx * (W / 2 - T / 2)
        wall = b.box((T, cargo_len, Z1 - FLOOR), (x, cargo_mid, (Z1 + FLOOR) / 2), BODY)
        b.chip_faces(wall, "rust", 0.0, seed=1)
        b.box((T + 0.02, cargo_len + 0.02, 0.5), (x, cargo_mid, FLOOR + 0.2), BODY2)
        b.box((0.02, cargo_len - 0.5, 0.05), (sx * (W / 2 + 0.01), cargo_mid, 1.45), BODY2)
        b.box((0.03, 0.7, 0.42), (sx * (W / 2 + 0.005), cargo_mid - 0.2, 1.72), "glass_dark")  # окошко отсека
        # колёсные арки
        for ay in (AXLE_F, AXLE_R):
            b.box((0.05, 1.0, 0.32), (sx * (W / 2 + 0.005), ay, Z0 + 0.3), "paint_black", bevel=0.05)
    # крыша: чуть выпуклая, с рёбрами
    b.box((W, L - 0.15, T), (0, 0.05, Z1 - T / 2), BODY, bevel=0.02)
    b.box((W - 0.3, L - 0.5, 0.06), (0, 0.1, Z1 + 0.02), BODY, bevel=0.025)
    for i in range(4):
        b.box((W - 0.5, 0.05, 0.02), (0, CAB_END + 0.4 + i * 0.75, Z1 + 0.055), BODY2)
    # перегородка с окошком
    b.box((W - T * 2, T, 0.75), (0, CAB_END, FLOOR + 0.375), BODY2)
    b.box((W - T * 2, T, 0.2), (0, CAB_END, Z1 - 0.16), BODY2)
    for sx in (-1, 1):
        b.box((0.45, T, 0.6), (sx * (W / 2 - T - 0.225), CAB_END, 1.65), BODY2)
    # кабина: скруглённый лоб, борта с окнами
    b.box((W, 0.1, 0.95), (0, FRONT + 0.05, Z0 + 0.475), BODY, bevel=0.04)                      # лоб ниже стекла
    b.box((W - 0.1, 0.08, 0.14), (0, FRONT + 0.06, Z1 - 0.1), BODY, bevel=0.03)                 # над стеклом
    b.box((0.05, 0.06, 0.62), (0, FRONT + 0.045, 1.72), BODY, rotation=(-8, 0, 0))              # стойка посередине
    for sx in (-1, 1):
        x = sx * (W / 2 - T / 2)
        b.box((T, 1.3, 0.95), (x, FRONT + 0.65, Z0 + 0.475), BODY)                               # дверь кабины, низ
        b.box((T + 0.02, 1.3, 0.3), (x, FRONT + 0.65, Z0 + 0.15), BODY2)
        b.box((T, 0.12, 0.75), (x, FRONT + 0.06, 1.775), BODY)                                   # передняя стойка
        b.box((T, 0.14, 0.75), (x, CAB_END - 0.07, 1.775), BODY)                                 # задняя стойка
        b.box((0.03, 0.02, 0.9), (sx * (W / 2 + 0.005), CAB_END - 0.16, 1.0), "paint_black")     # щель двери
        b.box((0.04, 0.12, 0.04), (sx * (W / 2 + 0.02), CAB_END - 0.32, 1.25), "chrome")         # ручка
        b.box((0.16, 0.05, 0.2), (sx * (W / 2 + 0.12), FRONT + 0.16, 1.62), "paint_black", bevel=0.02)  # зеркало
        # фары, поворотники, задние огни
        b.cylinder(0.11, 0.05, (sx * 0.62, FRONT - 0.01, 1.02), "light_warm", axis="Y", segments=8)
        b.cylinder(0.13, 0.03, (sx * 0.62, FRONT + 0.0, 1.02), "chrome", axis="Y", segments=8)
        b.box((0.1, 0.03, 0.06), (sx * 0.62, FRONT - 0.005, 0.84), "paint_orange")
        b.box((0.07, 0.03, 0.2), (sx * (W / 2 - 0.05), REAR + 0.005, 0.95), "light_red")
    b.box((0.7, 0.03, 0.22), (0, FRONT - 0.005, 1.0), "paint_black")                             # решётка
    for i in range(4):
        b.box((0.66, 0.035, 0.02), (0, FRONT - 0.008, 0.93 + i * 0.045), "steel")
    b.box((W + 0.06, 0.1, 0.14), (0, FRONT - 0.04, Z0 + 0.1), "steel_dark", bevel=0.02)          # бамперы
    b.box((W + 0.06, 0.08, 0.12), (0, REAR + 0.04, Z0 + 0.08), "steel_dark", bevel=0.02)
    # проём задних дверей: рамка
    b.box((W, T, 0.1), (0, REAR - T / 2, Z1 - 0.05), BODY)
    # кабина внутри: сиденья, руль, панель
    for sx in (-1, 1):
        b.box((0.5, 0.5, 0.14), (sx * 0.45, FRONT + 0.85, FLOOR + 0.27), "plastic_brown", bevel=0.03)
        b.box((0.5, 0.1, 0.55), (sx * 0.45, FRONT + 1.12, FLOOR + 0.6), "plastic_brown", bevel=0.03)
        b.box((0.4, 0.4, 0.2), (sx * 0.45, FRONT + 0.85, FLOOR + 0.1), "steel_dark")
    b.box((W - 0.2, 0.22, 0.2), (0, FRONT + 0.22, 1.3), "plastic_black", bevel=0.03)             # панель
    b.cylinder(0.19, 0.03, (0.45, FRONT + 0.42, 1.42), "bakelite", axis="Y", segments=10, rotation=(-25, 0, 0))
    b.cylinder(0.025, 0.3, (0.45, FRONT + 0.32, 1.34), "steel_dark", axis="Y", segments=5, rotation=(-25, 0, 0))
    b.box((0.5, 0.6, 0.35), (0, FRONT + 0.75, FLOOR + 0.175), "steel_dark", bevel=0.04)          # кожух мотора между сидений
    obj = b.build()
    geo.grime(obj, seed=3, dirt_height=0.9, strength=0.6, rust_tint=0.3, noise_scale=1.3)


def _glass() -> None:
    """Стёкла кабины отдельным объектом: в игре им дают прозрачный материал."""
    b = geo.Builder("glass")
    b.box((W - 0.22, 0.03, 0.62), (0, FRONT + 0.06, 1.72), "glass", rotation=(-8, 0, 0))
    for sx in (-1, 1):
        b.box((0.02, 1.04, 0.6), (sx * (W / 2 - 0.02), FRONT + 0.65, 1.72), "glass")
    b.build()


def _door(name: str, sx: int) -> None:
    """Створка задней двери. Петля — на внешнем ребре, в начале координат объекта."""
    b = geo.Builder(name)
    w = W / 2 - 0.01
    h = Z1 - 0.1 - FLOOR
    cx = -sx * w / 2            # створка уходит от петли к середине
    b.box((w, T, h), (cx, 0, h / 2), BODY, bevel=0.012)
    b.box((w + 0.005, T + 0.02, 0.5), (cx, 0, 0.2), BODY2)
    b.box((w - 0.25, 0.03, 0.45), (cx, 0.02, h - 0.4), "glass_dark")
    b.box((0.04, 0.05, 0.16), (-sx * (w - 0.08), 0.045, h * 0.45), "chrome")
    for z in (0.25, h - 0.2):
        b.box((0.06, 0.05, 0.12), (-sx * 0.02, 0.03, z), "steel_dark")
    obj = b.build()
    obj.location = (sx * (W / 2 - 0.005), REAR, FLOOR)
    geo.grime(obj, seed=4 + sx, dirt_height=0.5, strength=0.6, rust_tint=0.35, noise_scale=1.5)


def _wheel() -> None:
    b = geo.Builder("wheel")
    b.cylinder(WHEEL_R, WHEEL_W, (0, 0, 0), "tire", axis="X", segments=12)
    b.cylinder(WHEEL_R - 0.03, WHEEL_W + 0.02, (0, 0, 0), "rubber_worn", axis="X", segments=12)
    b.cylinder(0.2, WHEEL_W + 0.03, (0, 0, 0), "steel", axis="X", segments=8)
    b.cylinder(0.08, WHEEL_W + 0.06, (0, 0, 0), "steel_dark", axis="X", segments=6)
    for i in range(5):
        import math
        a = math.radians(i * 72)
        b.box((WHEEL_W + 0.035, 0.035, 0.035), (0, math.cos(a) * 0.13, math.sin(a) * 0.13), "rust")
    obj = b.build()
    obj.location = (TRACK, AXLE_F, WHEEL_R)   # в превью стоит на месте переднего левого
    geo.grime(obj, seed=9, dirt_height=0.2, strength=0.7, rust_tint=0.2, noise_scale=6.0)


def build() -> None:
    pipeline.reset_scene()
    _body()
    _glass()
    _door("door_l", 1)
    _door("door_r", -1)
    _wheel()
    cargo_len = REAR - CAB_END
    cargo_mid = (REAR + CAB_END) / 2
    geo.collider_box("floor", (W, L, FLOOR - Z0), (0, 0, (FLOOR + Z0) / 2))
    geo.collider_box("wall_l", (T, cargo_len, Z1 - FLOOR), (W / 2 - T / 2, cargo_mid, (Z1 + FLOOR) / 2))
    geo.collider_box("wall_r", (T, cargo_len, Z1 - FLOOR), (-W / 2 + T / 2, cargo_mid, (Z1 + FLOOR) / 2))
    geo.collider_box("roof", (W, L, T), (0, 0, Z1 - T / 2))
    geo.collider_box("cab", (W, CAB_END - FRONT, Z1 - FLOOR - T), (0, (CAB_END + FRONT) / 2, (Z1 + FLOOR - T) / 2))
    # точки: сиденья (ось Y Blender — назад), фары, центр грузового отсека
    geo.grip("seat_driver", (0.45, FRONT + 0.85, FLOOR + 0.34))
    geo.grip("seat_passenger", (-0.45, FRONT + 0.85, FLOOR + 0.34))
    geo.grip("headlight_l", (0.62, FRONT - 0.06, 1.02))
    geo.grip("headlight_r", (-0.62, FRONT - 0.06, 1.02))
    geo.grip("cargo", (0, cargo_mid, (Z1 + FLOOR) / 2))
    geo.grip("exit_driver", (W / 2 + 0.6, FRONT + 0.85, 0.05))
    geo.grip("wheel_fl", (TRACK, AXLE_F, WHEEL_R))
    geo.grip("wheel_fr", (-TRACK, AXLE_F, WHEEL_R))
    geo.grip("wheel_rl", (TRACK, AXLE_R, WHEEL_R))
    geo.grip("wheel_rr", (-TRACK, AXLE_R, WHEEL_R))
    pipeline.finish("vehicles/van", tri_budget=2400)


if __name__ == "__main__":
    build()
