"""Деревянный ящик 1×1×1 м: доски, рамка по рёбрам, диагональная распорка.

Строительный кубик тестовых уровней и будущий мусор свалки.
Запуск отдельно: blender -b -P art_src/blender/assets/props/crate_wood.py
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from lib import geo, pipeline  # noqa: E402

S = 1.0          # сторона ящика
FRAME = 0.09     # ширина бруска рамки
PLANKS = 3       # досок на грань
INSET = 0.03     # доски утоплены относительно рамки


def build() -> None:
    pipeline.reset_scene()
    b = geo.Builder("crate_wood")
    h = S / 2
    wood = ["wood", "wood_light", "wood", "wood_dark"]
    # стенки из досок: четыре боковые грани, дно и крышка
    pw = (S - 2 * INSET) / PLANKS
    for i in range(PLANKS):
        o = -h + INSET + pw * (i + 0.5)
        c = wood[i % len(wood)]
        t = 0.03
        b.box((pw - 0.012, t, S - 2 * INSET), (o, -h + INSET + t / 2, 0), c)          # перед
        b.box((pw - 0.012, t, S - 2 * INSET), (o, h - INSET - t / 2, 0), wood[(i + 1) % 4])  # зад
        b.box((t, pw - 0.012, S - 2 * INSET), (-h + INSET + t / 2, o, 0), wood[(i + 2) % 4])  # лево
        b.box((t, pw - 0.012, S - 2 * INSET), (h - INSET - t / 2, o, 0), c)           # право
        b.box((pw - 0.012, S - 2 * INSET, t), (o, 0, h - INSET - t / 2), wood[(i + 3) % 4])  # крышка
    b.box((S - 2 * INSET, S - 2 * INSET, 0.03), (0, 0, -h + INSET + 0.015), "wood_dark")  # дно одной плитой
    # рамка: 12 брусков по рёбрам, с фаской
    frame_faces = []
    e = h - FRAME / 2
    for sx in (-1, 1):
        for sy in (-1, 1):
            frame_faces += b.box((FRAME, FRAME, S), (sx * e, sy * e, 0), "wood_dark", bevel=0.012)
        for sz in (-1, 1):
            frame_faces += b.box((FRAME, S - 2 * FRAME, FRAME), (sx * e, 0, sz * e), "wood_dark", bevel=0.012)
    for sy in (-1, 1):
        for sz in (-1, 1):
            frame_faces += b.box((S - 2 * FRAME, FRAME, FRAME), (0, sy * e, sz * e), "wood_dark", bevel=0.012)
    # диагональные распорки на двух боках: силуэт «ящика» читается издалека
    diag = (S - 2 * FRAME) * 1.36
    b.box((FRAME * 0.8, 0.03, diag), (0, -h + 0.016, 0), "wood", rotation=(0, 45, 0))
    b.box((0.03, FRAME * 0.8, diag), (h - 0.016, 0, 0), "wood", rotation=(45, 0, 0))
    # ржавые уголки-гвозди на части фасок
    b.chip_faces(frame_faces, "rust_dark", 0.12, seed=4, max_area=0.004)

    obj = b.build()
    obj.location.z = h
    geo.grime(obj, seed=9, dirt_height=0.5, strength=0.5, rust_tint=0.15, noise_scale=3.0)
    geo.collider_box("body", (S, S, S), (0, 0, h))
    geo.grip("left", (-h, 0, h + 0.1), (0, 0, 90))
    geo.grip("right", (h, 0, h + 0.1), (0, 0, -90))
    pipeline.finish("props/crate_wood", tri_budget=800)


if __name__ == "__main__":
    build()
