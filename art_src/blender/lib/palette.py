"""Общая палитра проекта.

Одна текстура 256×256: сетка 16×16 ячеек по 16 пикселей. Каждой грани модели
UV ставится в центр нужной ячейки, поэтому все модели красятся из одного файла.
Палитра описана здесь и только здесь; PNG собирается функцией write_png().

Внутри ячейки цвет чуть плывёт сверху вниз (на 6%), чтобы при фильтрации
текстуры на стыках не было жёстких полос и картинка выглядела «живее».
"""

from __future__ import annotations

import struct
import zlib
from pathlib import Path

GRID = 16          # ячеек по стороне
CELL = 16          # пикселей в ячейке
SIZE = GRID * CELL  # 256


def _hex(h: str) -> tuple[int, int, int]:
    h = h.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


# Имя цвета -> hex. Порядок важен: индекс в списке = номер ячейки.
# Строки по 16: металлы, ржавчина и грязь, краски техники, ткань и кожа, природа,
# свет и эмиссия, служебные. Новые цвета добавлять только в конец строки или в
# свободные ячейки, чтобы не сдвинуть уже готовые модели.
_ROWS: list[list[tuple[str, str]]] = [
    # 0: металлы
    [("copper", "#b8693a"), ("copper_dark", "#7a3f22"), ("copper_oxide", "#5f9a7e"),
     ("brass", "#c9a24a"), ("brass_dark", "#8a6a2a"), ("aluminium", "#b9bec4"),
     ("aluminium_dark", "#7f868e"), ("steel", "#8d9399"), ("steel_dark", "#555b62"),
     ("cast_iron", "#4a4644"), ("cast_iron_dark", "#2c2a29"), ("lead", "#6f7378"),
     ("chrome", "#dfe4e8"), ("gold", "#e0b84a"), ("zinc", "#a3a9a2"), ("solder", "#9a9a92")],
    # 1: ржавчина, грязь, мусор
    [("rust_light", "#b0603a"), ("rust", "#8a4426"), ("rust_dark", "#5a2c1a"),
     ("dirt_light", "#8a7a62"), ("dirt", "#5e5240"), ("dirt_dark", "#3a3228"),
     ("mud", "#4a3f2e"), ("ash", "#6b6862"), ("soot", "#262422"), ("clay", "#9a6a4a"),
     ("sand", "#b9a27a"), ("concrete", "#8f8c86"), ("concrete_dark", "#5c5a56"),
     ("brick", "#93452f"), ("brick_dark", "#62301f"), ("tar", "#1c1b1a")],
    # 2: краски техники и машин (выцветшие, советские)
    [("enamel_white", "#e4e0d4"), ("enamel_cream", "#d8ccaa"), ("enamel_grey", "#a7a69e"),
     ("paint_radiator", "#cfcab8"), ("paint_green", "#5e7a4e"), ("paint_green_dark", "#3d5233"),
     ("paint_khaki", "#7a7650"), ("paint_blue", "#4a6a8a"), ("paint_blue_dark", "#2f4660"),
     ("paint_red", "#a33a2e"), ("paint_red_dark", "#6e241c"), ("paint_yellow", "#d1a83a"),
     ("paint_orange", "#c86a2a"), ("paint_brown", "#6a4a32"), ("paint_teal", "#3f7a74"),
     ("paint_black", "#232425")],
    # 3: пластик, резина, стекло
    [("plastic_black", "#1f1f21"), ("plastic_grey", "#6a6a6c"), ("plastic_beige", "#c7b998"),
     ("plastic_brown", "#5a3e2c"), ("bakelite", "#3a2418"), ("rubber", "#1a1a1a"),
     ("rubber_worn", "#3a3836"), ("glass", "#6f8a8a"), ("glass_dark", "#2a3638"),
     ("screen_crt", "#1e2a28"), ("wood_light", "#a8834f"), ("wood", "#7a5a36"),
     ("wood_dark", "#4a3420"), ("plywood", "#c2a26a"), ("cardboard", "#a88a5a"),
     ("paper", "#d8d0b8")],
    # 4: ткань, одежда, кожа людей
    [("skin_light", "#e0b096"), ("skin", "#c48a6a"), ("skin_dark", "#8a5a42"),
     ("tracksuit_blue", "#2c3e7a"), ("tracksuit_black", "#202228"), ("stripe_white", "#e8e8e8"),
     ("quilted_green", "#4a5236"), ("quilted_black", "#26272a"), ("telnyashka_blue", "#2a3a6a"),
     ("hat_red", "#9a2e2e"), ("hat_blue", "#3a5a8a"), ("boot_rubber", "#2a3022"),
     ("glove_cotton", "#c8bf9e"), ("hair_dark", "#2a2018"), ("hair_light", "#8a6a42"),
     ("lips", "#a05a4a")],
    # 5: природа и свалка
    [("grass_dry", "#8a8448"), ("grass_dead", "#6a5e3a"), ("leaf_dark", "#3a4a2a"),
     ("water", "#2a3a3e"), ("water_dirty", "#3e3a2a"), ("snow", "#d8dde2"),
     ("bag_black", "#18191b"), ("bag_blue", "#2a4a7a"), ("bag_white", "#c8c8c0"),
     ("mattress", "#b8aa8a"), ("foam", "#d8c47a"), ("tire", "#202020"),
     ("rag", "#7a6a5a"), ("cable_insulation", "#2a2a2a"), ("cable_red", "#8a2a22"),
     ("cable_blue", "#2a4a8a")],
    # 6: свет и эмиссия (для фар, фонарей, костров, приборов)
    [("light_sodium", "#ffb24a"), ("light_warm", "#ffd68a"), ("light_cold", "#bcd4ff"),
     ("light_fire", "#ff7a2a"), ("light_red", "#ff3a2a"), ("light_green", "#6aff7a"),
     ("ember", "#c83a12"), ("lamp_off", "#8a8270"), ("dial_white", "#f0ead8"),
     ("dial_needle", "#c8281e"), ("led_green", "#4aff6a"), ("led_red", "#ff2a2a"),
     ("_free_6_12", "#ff00ff"), ("_free_6_13", "#ff00ff"), ("_free_6_14", "#ff00ff"),
     ("_free_6_15", "#ff00ff")],
]

# Служебные ячейки: чистые белый/чёрный для отладки и масок
_ROWS.append([("white", "#ffffff"), ("black", "#000000")] + [(f"_free_7_{i}", "#ff00ff") for i in range(2, 16)])

COLORS: dict[str, tuple[int, int, int]] = {}
CELLS: dict[str, tuple[int, int]] = {}
for _r, _row in enumerate(_ROWS):
    assert len(_row) == GRID, f"строка палитры {_r} должна иметь {GRID} цветов"
    for _c, (_name, _hx) in enumerate(_row):
        if _name.startswith("_free"):
            continue
        assert _name not in COLORS, f"повтор цвета {_name}"
        COLORS[_name] = _hex(_hx)
        CELLS[_name] = (_c, _r)


def uv_of(name: str) -> tuple[float, float]:
    """UV центра ячейки цвета (в системе Blender: v=0 внизу текстуры)."""
    if name not in CELLS:
        raise KeyError(f"нет цвета '{name}' в палитре; есть: {', '.join(sorted(CELLS))}")
    c, r = CELLS[name]
    u = (c + 0.5) / GRID
    v = 1.0 - (r + 0.5) / GRID
    return u, v


def linear(name: str) -> tuple[float, float, float, float]:
    """Цвет в линейном пространстве (для материалов превью внутри Blender)."""
    def to_lin(x: float) -> float:
        x = x / 255.0
        return x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4
    r, g, b = COLORS[name]
    return to_lin(r), to_lin(g), to_lin(b), 1.0


def write_png(path: str | Path) -> Path:
    """Собирает palette.png без сторонних библиотек."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    rows = bytearray()
    for y in range(SIZE):
        rows.append(0)  # PNG filter: none
        r_idx = y // CELL
        t = (y % CELL) / (CELL - 1)  # 0 вверху ячейки, 1 внизу
        shade = 1.03 - 0.06 * t
        for x in range(SIZE):
            c_idx = x // CELL
            if r_idx >= len(_ROWS):
                rows += b"\xff\x00\xff"  # пустая ячейка: ярко-розовый, чтобы ошибка UV сразу бросалась в глаза
                continue
            name, hx = _ROWS[r_idx][c_idx]
            rgb = _hex(hx)
            if not name.startswith("_free") and name not in ("white", "black"):
                rgb = tuple(max(0, min(255, round(ch * shade))) for ch in rgb)
            rows += bytes(rgb)

    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(rows), 9))
    png += chunk(b"IEND", b"")
    path.write_bytes(png)
    return path


# Оставшиеся пустые строки 8–15 зарезервированы под будущие наборы цветов.
assert len(_ROWS) <= GRID
