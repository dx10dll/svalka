"""Куски мусора, из которых сложена гора: мешки, покрышка, матрас, коробки, доски,
бетон, бочка, ком земли с хламом.

Каждый кусок вписан в ячейку решётки свалки 0.8 × 0.8 × 0.4 м (с небольшим
запасом, чтобы соседи перекрывались и не было щелей). Начало координат — низ по центру.
Запуск отдельно: blender -b -P art_src/blender/assets/junk/junk_pieces.py
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from lib import geo, pipeline  # noqa: E402

CELL = (0.8, 0.8, 0.4)


def _finish(name: str, obj, seed: int, budget: int = 320, col=(0.78, 0.78, 0.4), dirt: float = 0.6) -> None:
    geo.grime(obj, seed=seed, dirt_height=0.3, strength=dirt, rust_tint=0.25, noise_scale=4.0)
    geo.collider_box("body", col, (0, 0, col[2] / 2))
    geo.grip("left", (-col[0] / 2, 0, col[2] * 0.6), (0, 0, 90))
    geo.grip("right", (col[0] / 2, 0, col[2] * 0.6), (0, 0, -90))
    pipeline.finish(f"junk/{name}", tri_budget=budget)


def bag(color: str, seed: int) -> None:
    pipeline.reset_scene()
    b = geo.Builder("mesh")
    b.box((0.78, 0.66, 0.38), (0.0, 0.03, 0.2), f"bag_{color}", bevel=0.13, segments=2)
    b.box((0.5, 0.56, 0.3), (0.16, -0.14, 0.2), f"bag_{color}", bevel=0.1, rotation=(0, 8, 25))
    b.box((0.42, 0.4, 0.26), (-0.2, 0.2, 0.17), f"bag_{color}", bevel=0.09, rotation=(6, 0, -18))
    b.box((0.1, 0.1, 0.1), (-0.05, 0.05, 0.42), f"bag_{color}", bevel=0.03, rotation=(0, 20, 30))  # узел
    b.box((0.16, 0.05, 0.02), (-0.05, 0.05, 0.47), f"bag_{color}", rotation=(0, 0, 40))
    _finish(f"bag_{color}", b.build(), seed, dirt=0.45)


def tire() -> None:
    pipeline.reset_scene()
    b = geo.Builder("mesh")
    b.box((0.84, 0.8, 0.16), (0, 0, 0.08), "dirt_dark", bevel=0.06)
    rot = (7, -5, 0)
    b.cylinder(0.39, 0.22, (0.0, 0.0, 0.27), "tire", segments=10, rotation=rot)
    b.cylinder(0.36, 0.26, (0.0, 0.0, 0.27), "rubber_worn", segments=10, rotation=rot)
    b.cylinder(0.21, 0.27, (0.0, 0.0, 0.27), "soot", segments=8, rotation=rot)
    _finish("tire", b.build(), 41)


def mattress() -> None:
    pipeline.reset_scene()
    b = geo.Builder("mesh")
    b.box((0.86, 0.78, 0.2), (0, 0, 0.1), "mattress", bevel=0.05)
    b.box((0.82, 0.74, 0.2), (0.02, 0.02, 0.3), "mattress", bevel=0.06, rotation=(0, 3, 6))
    for i in range(5):
        x = -0.32 + i * 0.16
        b.box((0.035, 0.75, 0.205), (x, 0.0, 0.1), "telnyashka_blue")
        b.box((0.035, 0.7, 0.012), (x + 0.02, 0.02, 0.402), "telnyashka_blue", rotation=(0, 3, 6))
    b.box((0.2, 0.16, 0.012), (0.2, -0.15, 0.405), "water_dirty", rotation=(0, 3, 30))  # пятно
    b.box((0.1, 0.08, 0.05), (-0.25, 0.2, 0.41), "foam", bevel=0.02, rotation=(0, 3, 20))  # вылез поролон
    _finish("mattress", b.build(), 42)


def cardboard() -> None:
    pipeline.reset_scene()
    b = geo.Builder("mesh")
    b.box((0.52, 0.46, 0.36), (-0.14, 0.12, 0.19), "cardboard", bevel=0.015, rotation=(0, 4, 12))
    b.box((0.5, 0.03, 0.24), (-0.1, -0.16, 0.36), "cardboard", rotation=(35, 0, 12))   # отогнутый клапан
    b.box((0.06, 0.47, 0.365), (-0.14, 0.12, 0.19), "paper", rotation=(0, 4, 12))        # скотч
    b.box((0.38, 0.36, 0.26), (0.2, -0.18, 0.14), "plywood", bevel=0.015, rotation=(0, -6, -20))
    b.box((0.42, 0.34, 0.05), (0.18, 0.22, 0.04), "cardboard", rotation=(0, 0, 50))     # сплющенный лист
    b.box((0.2, 0.14, 0.012), (0.2, -0.18, 0.275), "paper", rotation=(0, -6, 10))
    _finish("cardboard", b.build(), 43)


def boards() -> None:
    pipeline.reset_scene()
    b = geo.Builder("mesh")
    b.box((0.82, 0.78, 0.12), (0, 0, 0.06), "dirt", bevel=0.05)
    woods = ["wood", "wood_dark", "wood_light", "plywood", "wood"]
    spots = [(-0.02, -0.2, 0.15, 8, 0, 6), (0.05, 0.02, 0.2, -6, 4, -14), (0.0, 0.24, 0.17, 4, -3, 22),
             (-0.1, 0.0, 0.29, 10, 6, 74), (0.16, -0.05, 0.34, -8, 0, -52)]
    for i, (x, y, z, rx, ry, rz) in enumerate(spots):
        faces = b.box((0.86, 0.13, 0.04), (x, y, z), woods[i], rotation=(rx, ry, rz))
        b.chip_faces(faces, "rust_dark", 0.2, seed=50 + i, max_area=0.006)
    b.box((0.03, 0.03, 0.08), (0.3, -0.18, 0.2), "rust")   # гвоздь торчит
    _finish("boards", b.build(), 44)


def concrete() -> None:
    pipeline.reset_scene()
    b = geo.Builder("mesh")
    b.box((0.72, 0.56, 0.36), (-0.02, 0.06, 0.19), "concrete", bevel=0.04, rotation=(4, -3, 14))
    b.box((0.36, 0.3, 0.26), (0.24, -0.24, 0.14), "concrete_dark", bevel=0.04, rotation=(10, 8, -30))
    b.box((0.3, 0.22, 0.16), (-0.26, -0.26, 0.09), "brick", bevel=0.02, rotation=(0, 5, 40))
    b.cylinder(0.012, 0.5, (0.2, 0.2, 0.34), "rust", segments=4, axis="Y", rotation=(20, 0, 30))
    b.cylinder(0.012, 0.42, (-0.2, 0.1, 0.36), "rust_dark", segments=4, axis="X", rotation=(0, 25, 10))
    _finish("concrete", b.build(), 45, dirt=0.5)


def barrel() -> None:
    pipeline.reset_scene()
    b = geo.Builder("mesh")
    body = b.cylinder(0.215, 0.8, (0, 0, 0.215), "paint_blue_dark", axis="X", segments=10, cap_color="rust_dark")
    for x in (-0.27, 0.0, 0.27):
        b.cylinder(0.225, 0.03, (x, 0, 0.215), "rust", axis="X", segments=10)
    b.cylinder(0.03, 0.03, (0.405, 0.1, 0.3), "steel_dark", axis="X", segments=5)   # пробка
    b.chip_faces(body, "rust", 0.35, seed=46, max_area=0.05)
    b.box((0.8, 0.5, 0.08), (0, 0.3, 0.04), "dirt_dark", bevel=0.03)
    b.box((0.8, 0.5, 0.08), (0, -0.3, 0.04), "dirt", bevel=0.03)
    _finish("barrel", b.build(), 46)


def dirt_clod(variant: int) -> None:
    pipeline.reset_scene()
    b = geo.Builder("mesh")
    main = ("dirt", "dirt_dark")[variant]
    other = ("dirt_dark", "mud")[variant]
    b.box((0.84, 0.82, 0.3), (0, 0, 0.15), main, bevel=0.09, segments=2)
    b.box((0.56, 0.5, 0.24), (0.1, -0.12, 0.3), other, bevel=0.09, rotation=(0, 6, 25 + 40 * variant))
    b.box((0.4, 0.36, 0.2), (-0.2, 0.2, 0.3), main, bevel=0.07, rotation=(8, 0, -15))
    # торчащая мелочь: тряпка, банка, бумага, обломок кирпича
    b.box((0.26, 0.16, 0.05), (-0.18, -0.22, 0.31), ("rag", "bag_white")[variant], bevel=0.015, rotation=(10, 5, 35))
    b.cylinder(0.035, 0.11, (0.26, 0.2, 0.33), ("aluminium", "rust_light")[variant], axis="X", segments=6,
               rotation=(0, 20, 40))
    b.box((0.16, 0.12, 0.012), (0.05, 0.26, 0.31), "paper", rotation=(12, 0, 60))
    b.box((0.14, 0.09, 0.07), (0.28, -0.26, 0.28), ("brick", "glass_dark")[variant], bevel=0.012, rotation=(15, 10, 20))
    _finish(f"dirt_clod_{variant + 1}", b.build(), 47 + variant, dirt=0.3)


def build() -> None:
    for i, color in enumerate(("black", "blue", "white")):
        bag(color, 30 + i)
    tire()
    mattress()
    cardboard()
    boards()
    concrete()
    barrel()
    dirt_clod(0)
    dirt_clod(1)


if __name__ == "__main__":
    build()
