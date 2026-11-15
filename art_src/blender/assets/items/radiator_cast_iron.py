"""Чугунная батарея (секционный радиатор), 7 секций, старая кремовая краска.

Первый тестовый предмет конвейера. 70 кг, несут вдвоём-втроём, хватать за торцы.
Запуск отдельно: blender -b -P art_src/blender/assets/items/radiator_cast_iron.py
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from lib import geo, pipeline  # noqa: E402

SECTIONS = 7
PITCH = 0.082        # шаг секций, м
COLUMN = (0.072, 0.042, 0.50)  # ширина, глубина, высота одной колонки
DEPTH = 0.13         # полная глубина секции (две колонки + перемычка)
HUB_Z = 0.215        # высота коллекторов от центра
HUB_R = 0.03
BEVEL = 0.011


def build() -> None:
    pipeline.reset_scene()
    b = geo.Builder("radiator_cast_iron")
    length = SECTIONS * PITCH
    x0 = -length / 2 + PITCH / 2
    paint_faces = []
    for i in range(SECTIONS):
        x = x0 + i * PITCH
        # передняя и задняя колонки с фаской — читаемый «рёбристый» силуэт
        for side in (-1, 1):
            y = side * (DEPTH / 2 - COLUMN[1] / 2)
            paint_faces += b.box(COLUMN, (x, y, 0.0), "paint_radiator", bevel=BEVEL)
        # тонкая перемычка между колонками, утоплена — даёт щель-тень
        paint_faces += b.box((COLUMN[0] * 0.55, DEPTH - COLUMN[1] * 1.6, COLUMN[2] * 0.78),
                             (x, 0.0, 0.0), "paint_radiator")
    # коллекторы сверху и снизу видны в щелях между секциями
    for z in (HUB_Z, -HUB_Z):
        b.cylinder(HUB_R, length + 0.01, (0.0, 0.0, z), "cast_iron", axis="X", segments=6)
    # пробки на торцах: одна латунная (старый кран), остальные чугунные
    for sx in (-1, 1):
        for z in (HUB_Z, -HUB_Z):
            color = "brass_dark" if (sx, z) == (1, HUB_Z) else "cast_iron_dark"
            b.cylinder(0.034, 0.03, (sx * (length / 2 + 0.012), 0.0, z), color,
                       axis="X", segments=4, cap_color="rust" if color != "brass_dark" else None)
    # сколы краски: часть граней становится ржавой или голым чугуном
    b.chip_faces(paint_faces, "rust", 0.22, seed=7)
    b.chip_faces(paint_faces, "rust_dark", 0.08, seed=11)

    obj = b.build()
    obj.location.z = COLUMN[2] / 2  # ставим на землю: начало координат внизу по центру
    geo.grime(obj, seed=3, dirt_height=0.35, strength=0.75, rust_tint=0.7)

    # коллизия: один выпуклый блок (дешёво и устойчиво в стопках)
    col = geo.collider_box("body", (length + 0.05, DEPTH, COLUMN[2]), (0.0, 0.0, COLUMN[2] / 2))
    # точки хвата: верх торцов, кисть смотрит внутрь
    top = COLUMN[2] - 0.03
    geo.grip("left", (-length / 2 - 0.01, 0.0, top), (0, 0, 90))
    geo.grip("right", (length / 2 + 0.01, 0.0, top), (0, 0, -90))
    geo.grip("bottom_left", (-length / 2 - 0.01, 0.0, 0.06), (0, 0, 90))
    _ = col
    pipeline.finish("items/radiator_cast_iron", tri_budget=800)


if __name__ == "__main__":
    build()
