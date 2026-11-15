"""Бухта медного кабеля: три витка в чёрной оплётке, местами оплётка содрана до меди.

15–25 кг, несёт один, сдаётся как медь. Самая желанная находка первых ночей.
Запуск отдельно: blender -b -P art_src/blender/assets/items/cable_coil.py
"""

import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from lib import geo, pipeline  # noqa: E402

RADIUS = 0.23     # радиус бухты по центру кабеля
THICK = 0.075     # толщина кабеля
SEGMENTS = 14
LAYERS = 3


def build() -> None:
    pipeline.reset_scene()
    rnd = random.Random(12)
    b = geo.Builder("mesh")
    seg_len = 2 * RADIUS * math.tan(math.pi / SEGMENTS) + 0.025
    for layer in range(LAYERS):
        z = THICK * 0.5 + layer * THICK * 0.86
        r = RADIUS + rnd.uniform(-0.018, 0.018)
        phase = rnd.uniform(0, 360)
        for i in range(SEGMENTS):
            a = math.radians(phase + i * 360 / SEGMENTS)
            # содранная оплётка: редкие медные сегменты, в основном на верхнем витке
            stripped = rnd.random() < (0.3 if layer == LAYERS - 1 else 0.08)
            color = "copper" if stripped else ("cable_insulation" if rnd.random() > 0.25 else "rubber_worn")
            t = THICK * (0.8 if stripped else 1.0)
            b.box((t, seg_len, t), (math.cos(a) * r, math.sin(a) * r, z + rnd.uniform(-0.008, 0.008)),
                  color, rotation=(rnd.uniform(-4, 4), 0, math.degrees(a)))
    # свободный конец с зачищенной медью
    top = THICK * 0.5 + (LAYERS - 1) * THICK * 0.86
    b.box((THICK * 0.9, 0.2, THICK * 0.9), (RADIUS + 0.03, 0.12, top + 0.03), "cable_insulation", rotation=(12, 0, -8))
    b.box((THICK * 0.55, 0.09, THICK * 0.55), (RADIUS + 0.045, 0.255, top + 0.062), "copper", rotation=(12, 0, -8))
    # проволочные стяжки
    for a_deg in (40, 160, 280):
        a = math.radians(a_deg)
        b.box((THICK + 0.035, 0.02, LAYERS * THICK * 0.86 + 0.05),
              (math.cos(a) * RADIUS, math.sin(a) * RADIUS, top / 2 + THICK * 0.25), "steel", rotation=(0, 0, a_deg))
    obj = b.build()
    height = top + THICK * 0.5
    geo.grime(obj, seed=8, dirt_height=0.6, strength=0.4, rust_tint=0.2, noise_scale=7.0)
    geo.collider_cylinder("body", RADIUS + THICK * 0.55, height, (0, 0, height / 2), segments=8)
    geo.grip("left", (-RADIUS, 0, height), (0, 0, 90))
    geo.grip("right", (RADIUS, 0, height), (0, 0, -90))
    pipeline.finish("items/cable_coil", tri_budget=800)


if __name__ == "__main__":
    build()
