"""Мужик бригады: сегментный лоу-поли на общем риге (31 кость) + базовые анимации.

Автор попросил персонажей мельче и не таких человекоподобных, поэтому это
мужичок ростом 1.28 м: большая голова, короткие ноги, длинные руки, огромные
кисти. Первый — «Серёга»: ватник, спортивки с лампасами, кепка, сапоги,
перчатки. Остальные трое получатся сменой пропорций и одежды на том же риге.

Запуск отдельно: blender -b -P art_src/blender/assets/characters/man.py

Знаки поворотов в позах (градусы, мировые оси, см. lib/rig.py):
    x > 0 — «нос вверх»: нога и рука идут вперёд, туловище и голова — назад,
            носок вверх. Наклон корпуса вперёд — это x < 0, сгиб колена — x < 0,
            сгиб локтя — x > 0.
    y > 0 — завал влево (+X); z > 0 — поворот влево.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from lib import geo, pipeline, rig  # noqa: E402
from lib.rig import BoneDef as B, Clip  # noqa: E402

# --- скелет (метры, Z вверх, лицо в -Y) ---------------------------------------
# Мелкий мужичок ростом 1.28 м: огромная голова в кепке, бочонок-туловище,
# короткие ноги в сапогах и длинные руки с большими кистями почти до земли.
ARM_X = 0.25
LEG_X = 0.10
## Во сколько раз ноги короче «человеческих» 0.85 м: на это множатся смещения таза в позах
HIPS_SCALE = 0.46
BONES = rig.mirrored([
    B("hips", (0, 0, 0.47), (0, 0, 0.56)),
    B("spine", (0, 0, 0.56), (0, 0, 0.70), "hips", True),
    B("chest", (0, 0, 0.70), (0, 0, 0.86), "spine", True),
    B("neck", (0, 0, 0.86), (0, -0.01, 0.90), "chest", True),
    B("head", (0, -0.01, 0.90), (0, -0.01, 1.20), "neck", True),
    B("jaw", (0, -0.03, 0.955), (0, -0.17, 0.92), "head"),
    B("brow.L", (0.085, -0.17, 1.115), (0.085, -0.22, 1.115), "head"),
    B("hat", (0, 0, 1.17), (0, 0, 1.27), "head"),
    B("belly", (0, -0.12, 0.62), (0, -0.24, 0.62), "spine"),
    B("clavicle.L", (0.04, 0, 0.83), (ARM_X - 0.03, 0, 0.83), "chest"),
    B("upper_arm.L", (ARM_X, 0, 0.82), (ARM_X, 0, 0.60), "clavicle.L"),
    B("forearm.L", (ARM_X, 0, 0.60), (ARM_X, 0, 0.38), "upper_arm.L", True),
    B("hand.L", (ARM_X, 0, 0.38), (ARM_X, 0, 0.29), "forearm.L", True),
    B("fingers.L", (ARM_X, 0, 0.29), (ARM_X, 0, 0.20), "hand.L", True),
    B("thumb.L", (ARM_X, -0.055, 0.36), (ARM_X, -0.105, 0.29), "hand.L"),
    B("thigh.L", (LEG_X, 0, 0.46), (LEG_X, 0, 0.27), "hips"),
    B("shin.L", (LEG_X, 0, 0.27), (LEG_X, 0, 0.08), "thigh.L", True),
    B("foot.L", (LEG_X, 0, 0.08), (LEG_X, -0.13, 0.03), "shin.L", True),
    B("toe.L", (LEG_X, -0.13, 0.03), (LEG_X, -0.23, 0.03), "foot.L", True),
])

JACKET, JACKET_DARK = "quilted_green", "quilted_black"
PANTS, STRIPE = "tracksuit_blue", "stripe_white"
SKIN, GLOVE, BOOT, CAP = "skin", "glove_cotton", "boot_rubber", "hat_blue"


def _parts() -> tuple[list, list]:
    """Возвращает (детали тела, детали головы). Каждая деталь привязана к одной кости."""
    body: list = []
    head: list = []

    def part(target: list, bone: str, fn) -> None:
        b = geo.Builder(f"p_{bone}_{len(target)}")
        fn(b)
        obj = b.build()
        rig.skin_rigid(obj, bone)
        target.append(obj)

    # туловище-бочонок
    part(body, "hips", lambda b: b.box((0.35, 0.27, 0.15), (0, 0.005, 0.50), PANTS, bevel=0.04))
    part(body, "spine", lambda b: b.box((0.42, 0.31, 0.19), (0, 0, 0.635), JACKET, bevel=0.05))
    part(body, "belly", lambda b: b.box((0.34, 0.17, 0.20), (0, -0.14, 0.62), JACKET, bevel=0.06))
    def chest(b: geo.Builder) -> None:
        b.box((0.47, 0.32, 0.20), (0, 0.005, 0.78), JACKET, bevel=0.055)
        for z in (0.745, 0.815):  # стёжка ватника: крестом, чтобы не торчала из скошенных углов
            b.box((0.36, 0.326, 0.014), (0, 0.005, z), JACKET_DARK)
            b.box((0.476, 0.21, 0.014), (0, 0.005, z), JACKET_DARK)
        b.box((0.03, 0.02, 0.19), (0, -0.16, 0.78), JACKET_DARK)             # застёжка
        b.box((0.30, 0.26, 0.05), (0, 0.0, 0.885), JACKET_DARK, bevel=0.02)  # воротник
    part(body, "chest", chest)
    part(body, "neck", lambda b: b.cylinder(0.075, 0.08, (0, -0.005, 0.89), SKIN, segments=6))

    # голова: почти треть роста, тяжёлая челюсть, нос картошкой
    def skull(b: geo.Builder) -> None:
        b.box((0.37, 0.37, 0.25), (0, -0.01, 1.065), SKIN, bevel=0.075)
        b.box((0.075, 0.10, 0.095), (0, -0.215, 1.015), "skin_dark", bevel=0.028)        # нос
        for sx in (-1, 1):
            b.box((0.045, 0.08, 0.11), (sx * 0.195, 0.01, 1.04), "skin_dark", bevel=0.015)  # уши
            b.box((0.07, 0.014, 0.05), (sx * 0.09, -0.193, 1.075), "soot")                # глаза
            b.box((0.022, 0.016, 0.022), (sx * 0.098, -0.199, 1.083), "white")            # блик
        b.box((0.22, 0.16, 0.07), (0, -0.10, 0.945), "soot")                              # темнота рта
        b.box((0.33, 0.13, 0.13), (0, 0.135, 1.0), "hair_dark", bevel=0.03)               # затылок
    part(head, "head", skull)
    def jaw(b: geo.Builder) -> None:
        b.box((0.33, 0.31, 0.10), (0, -0.045, 0.925), SKIN, bevel=0.04)
        b.box((0.22, 0.02, 0.035), (0, -0.198, 0.957), "lips")
        b.box((0.33, 0.20, 0.035), (0, -0.10, 0.887), "hair_dark", bevel=0.012)           # щетина
    part(head, "jaw", jaw)
    for sx, bone in ((1, "brow.L"), (-1, "brow.R")):
        part(head, bone, lambda b, sx=sx: b.box((0.105, 0.03, 0.03), (sx * 0.088, -0.196, 1.125),
                                                "hair_dark", rotation=(0, sx * -10, 0)))
    def cap(b: geo.Builder) -> None:
        b.box((0.39, 0.40, 0.11), (0, -0.005, 1.225), CAP, bevel=0.05)
        b.box((0.31, 0.17, 0.026), (0, -0.265, 1.182), CAP, bevel=0.01, rotation=(-8, 0, 0))  # козырёк
        b.box((0.04, 0.04, 0.018), (0, -0.005, 1.285), "stripe_white")                    # пуговка
    part(head, "hat", cap)

    # руки и ноги: строим обе стороны зеркально
    for sx, s in ((1, ".L"), (-1, ".R")):
        ax, lx = sx * ARM_X, sx * LEG_X
        part(body, "clavicle" + s, lambda b, ax=ax, sx=sx: b.box((0.16, 0.20, 0.13), (ax - sx * 0.025, 0, 0.815),
                                                               JACKET, bevel=0.05))
        part(body, "upper_arm" + s, lambda b, ax=ax: b.box((0.12, 0.135, 0.24), (ax, 0, 0.705), JACKET, bevel=0.04))
        def forearm(b: geo.Builder, ax=ax) -> None:
            b.box((0.115, 0.13, 0.22), (ax, 0, 0.495), JACKET, bevel=0.038)
            b.box((0.122, 0.137, 0.035), (ax, 0, 0.40), JACKET_DARK)                       # манжета
        part(body, "forearm" + s, forearm)
        # кисти огромные: хват и жесты должны читаться издалека
        part(body, "hand" + s, lambda b, ax=ax: b.box((0.095, 0.15, 0.115), (ax, -0.005, 0.335), GLOVE, bevel=0.028))
        part(body, "fingers" + s, lambda b, ax=ax: b.box((0.085, 0.14, 0.10), (ax, -0.005, 0.245), GLOVE, bevel=0.028))
        part(body, "thumb" + s, lambda b, ax=ax: b.box((0.055, 0.06, 0.095), (ax, -0.09, 0.325), GLOVE,
                                                     bevel=0.018, rotation=(25, 0, 0)))
        def thigh(b: geo.Builder, lx=lx, sx=sx) -> None:
            b.box((0.175, 0.20, 0.22), (lx, 0, 0.365), PANTS, bevel=0.045)
            b.box((0.012, 0.04, 0.20), (lx + sx * 0.088, 0, 0.365), STRIPE)               # лампас
        part(body, "thigh" + s, thigh)
        def shin(b: geo.Builder, lx=lx) -> None:
            b.box((0.15, 0.17, 0.08), (lx, 0, 0.245), PANTS, bevel=0.03)
            b.box((0.175, 0.19, 0.16), (lx, 0, 0.155), BOOT, bevel=0.035)                  # голенище сапога
        part(body, "shin" + s, shin)
        part(body, "foot" + s, lambda b, lx=lx: b.box((0.155, 0.25, 0.10), (lx, -0.045, 0.05), BOOT, bevel=0.035))
        part(body, "toe" + s, lambda b, lx=lx: b.box((0.15, 0.12, 0.09), (lx, -0.195, 0.045), BOOT, bevel=0.035))
    return body, head


# --- позы ------------------------------------------------------------------------
# Базовая стойка: сутулый, руки чуть согнуты и отведены, колени мягкие.
BASE = {
    "hips": (0, 0, 0), "spine": (-5, 0, 0), "chest": (-8, 0, 0), "neck": (-9, 0, 0), "head": (14, 0, 0),
    "clavicle.L": (0, 0, 0), "clavicle.R": (0, 0, 0),
    "upper_arm.L": (-3, -7, 0), "upper_arm.R": (-3, 7, 0),
    "forearm.L": (22, 0, 0), "forearm.R": (22, 0, 0),
    "hand.L": (4, 0, 0), "hand.R": (4, 0, 0), "fingers.L": (18, 0, 0), "fingers.R": (18, 0, 0),
    "thigh.L": (6, -3, 0), "thigh.R": (6, 3, 0), "shin.L": (-11, 0, 0), "shin.R": (-11, 0, 0),
    "foot.L": (5, 0, 0), "foot.R": (5, 0, 0), "toe.L": (0, 0, 0), "toe.R": (0, 0, 0),
    "jaw": (0, 0, 0), "belly": (0, 0, 0), "hat": (0, 0, 0),
    "_hips": (0, 0, -0.012),
}


def P(**over) -> dict:
    """Поза = базовая стойка + изменения. Точки в именах костей пишутся как __ (thigh__L)."""
    pose = dict(BASE)
    for k, v in over.items():
        pose[k.replace("__", ".")] = v
    return pose


def M(pose: dict) -> dict:
    return rig.mirror_pose(pose)


def _clips() -> list[Clip]:
    clips: list[Clip] = []

    # idle: дыхание, лёгкое покачивание веса
    breathe = P(spine=(-4, 0, 0), chest=(-5.5, 0, 0), head=(12.5, 0, 1.5),
                upper_arm__L=(-3, -9, 0), upper_arm__R=(-3, 9, 0),
                clavicle__L=(0, -3, 0), clavicle__R=(0, 3, 0), _hips=(0.006, 0, -0.016), belly=(2, 0, 0))
    clips.append(Clip("idle", 72, True, {0: P(), 30: breathe, 44: P(head=(14, 0, -1.5)), 72: P()}))

    # walk: контакт — просадка — проход — мах. Цикл 32 кадра (два шага).
    w_contact = P(hips=(0, 0, -6), spine=(-6, 0, 4), chest=(-9, 0, 8), head=(14, 0, -5),
                  thigh__L=(30, -3, 0), shin__L=(-9, 0, 0), foot__L=(-3, 0, 0),
                  thigh__R=(-22, 3, 0), shin__R=(-20, 0, 0), foot__R=(14, 0, 0), toe__R=(22, 0, 0),
                  upper_arm__L=(-20, -6, 0), forearm__L=(12, 0, 0),
                  upper_arm__R=(22, 6, 0), forearm__R=(34, 0, 0), _hips=(0, 0, -0.04))
    w_down = P(hips=(0, 2, -4), spine=(-7, -1, 3), chest=(-10, 0, 5), head=(15, 0, -3),
               thigh__L=(26, -3, 0), shin__L=(-26, 0, 0), foot__L=(0, 0, 0),
               thigh__R=(-28, 3, 0), shin__R=(-34, 0, 0), foot__R=(8, 0, 0), toe__R=(12, 0, 0),
               upper_arm__L=(-16, -6, 0), forearm__L=(14, 0, 0),
               upper_arm__R=(18, 6, 0), forearm__R=(30, 0, 0), _hips=(0.012, 0, -0.062), belly=(-4, 0, 0))
    w_pass = P(hips=(0, 3.5, 0), spine=(-5, -2, 0), chest=(-8, -1, 0),
               thigh__L=(3, -3, 0), shin__L=(-5, 0, 0), foot__L=(2, 0, 0),
               thigh__R=(20, 3, 0), shin__R=(-58, 0, 0), foot__R=(10, 0, 0),
               upper_arm__L=(-2, -7, 0), forearm__L=(20, 0, 0),
               upper_arm__R=(2, 7, 0), forearm__R=(22, 0, 0), _hips=(0.02, 0, 0.004), belly=(3, 0, 0))
    clips.append(Clip("walk", 32, True, {
        0: w_contact, 4: w_down, 10: w_pass, 16: M(w_contact), 20: M(w_down), 26: M(w_pass), 32: w_contact}))

    # run: корпус вперёд, локти согнуты, высокий вынос колена
    r_contact = P(hips=(-6, 0, -10), spine=(-10, 0, 6), chest=(-12, 0, 12), neck=(-4, 0, 0), head=(20, 0, -8),
                  thigh__L=(44, -3, 0), shin__L=(-30, 0, 0), foot__L=(0, 0, 0),
                  thigh__R=(-28, 3, 0), shin__R=(-72, 0, 0), foot__R=(-15, 0, 0),
                  upper_arm__L=(-42, -8, 0), forearm__L=(70, 0, 0),
                  upper_arm__R=(46, 8, 0), forearm__R=(88, 0, 0), _hips=(0, 0, -0.07), belly=(-6, 0, 0))
    r_pass = P(hips=(-6, 3, 0), spine=(-11, -1, 0), chest=(-13, 0, 0), neck=(-4, 0, 0), head=(20, 0, 0),
               thigh__L=(-4, -3, 0), shin__L=(-14, 0, 0), foot__L=(12, 0, 0), toe__L=(15, 0, 0),
               thigh__R=(48, 3, 0), shin__R=(-100, 0, 0), foot__R=(5, 0, 0),
               upper_arm__L=(0, -9, 0), forearm__L=(80, 0, 0),
               upper_arm__R=(4, 9, 0), forearm__R=(80, 0, 0), _hips=(0.015, 0, 0.02), belly=(5, 0, 0))
    clips.append(Clip("run", 22, True, {
        0: r_contact, 6: r_pass, 11: M(r_contact), 17: M(r_pass), 22: r_contact}))

    # присед: глубокий сед «на кортах», локти на колени
    c_base = dict(hips=(-18, 0, 0), spine=(-14, 0, 0), chest=(-10, 0, 0), neck=(4, 0, 0), head=(26, 0, 0),
                  thigh__L=(98, -14, 0), shin__L=(-146, 0, 0), foot__L=(66, 0, 0),
                  thigh__R=(98, 14, 0), shin__R=(-146, 0, 0), foot__R=(66, 0, 0),
                  upper_arm__L=(52, -10, 0), forearm__L=(40, 0, 0),
                  upper_arm__R=(52, 10, 0), forearm__R=(40, 0, 0), _hips=(0, 0.10, -0.50))
    c_idle = P(**c_base)
    c_breathe = P(**{**c_base, "chest": (-8, 0, 0), "head": (24, 0, 2), "_hips": (0, 0.10, -0.508)})
    clips.append(Clip("crouch_idle", 72, True, {0: c_idle, 34: c_breathe, 72: c_idle}))
    cw_a = P(**{**c_base, "hips": (-18, 3, -6), "chest": (-10, 0, 8),
                "thigh__L": (116, -12, 0), "shin__L": (-140, 0, 0), "foot__L": (40, 0, 0),
                "thigh__R": (78, 14, 0), "shin__R": (-150, 0, 0), "foot__R": (84, 0, 0),
                "upper_arm__L": (36, -12, 0), "upper_arm__R": (64, 10, 0), "_hips": (0.02, 0.10, -0.47)})
    clips.append(Clip("crouch_walk", 36, True, {0: cw_a, 9: P(**c_base), 18: M(cw_a), 27: P(**c_base), 36: cw_a}))

    # полёт: ноги поджаты вразнобой, руки в стороны для равновесия
    air_a = P(spine=(-8, 0, 0), chest=(-6, 0, 0), head=(10, 0, 0),
              thigh__L=(42, -6, 0), shin__L=(-70, 0, 0), foot__L=(-14, 0, 0),
              thigh__R=(8, 6, 0), shin__R=(-40, 0, 0), foot__R=(-20, 0, 0),
              upper_arm__L=(10, -48, 0), forearm__L=(34, 0, 0),
              upper_arm__R=(-14, 44, 0), forearm__R=(46, 0, 0), _hips=(0, 0, 0), belly=(6, 0, 0))
    air_b = P(spine=(-6, 0, 0), chest=(-8, 0, 3), head=(8, 0, 0),
              thigh__L=(34, -8, 0), shin__L=(-58, 0, 0), foot__L=(-18, 0, 0),
              thigh__R=(16, 8, 0), shin__R=(-50, 0, 0), foot__R=(-14, 0, 0),
              upper_arm__L=(2, -58, 0), forearm__L=(26, 0, 0),
              upper_arm__R=(-6, 54, 0), forearm__R=(36, 0, 0), _hips=(0, 0, 0), belly=(-4, 0, 0))
    clips.append(Clip("air", 24, True, {0: air_a, 12: air_b, 24: air_a}))

    # приземление: глубокая просадка, руки вперёд, потом выпрямление с доводкой
    land_deep = P(hips=(-14, 0, 0), spine=(-18, 0, 0), chest=(-14, 0, 0), head=(30, 0, 0),
                  thigh__L=(64, -8, 0), shin__L=(-104, 0, 0), foot__L=(40, 0, 0),
                  thigh__R=(64, 8, 0), shin__R=(-104, 0, 0), foot__R=(40, 0, 0),
                  upper_arm__L=(40, -20, 0), forearm__L=(50, 0, 0),
                  upper_arm__R=(40, 20, 0), forearm__R=(50, 0, 0), _hips=(0, 0.04, -0.27), belly=(-10, 0, 0))
    land_over = P(spine=(-2, 0, 0), chest=(-4, 0, 0), head=(10, 0, 0), _hips=(0, 0, 0.012), belly=(6, 0, 0),
                  upper_arm__L=(-8, -12, 0), upper_arm__R=(-8, 12, 0))
    clips.append(Clip("land", 20, False, {0: land_deep, 3: land_deep, 12: land_over, 20: P()}))

    # залезание: руки на край, подтянулись, колено на край, встали
    m_hang = P(spine=(4, 0, 0), chest=(8, 0, 0), head=(28, 0, 0),
               upper_arm__L=(158, -22, 0), forearm__L=(10, 0, 0), hand__L=(-60, 0, 0),
               upper_arm__R=(158, 22, 0), forearm__R=(10, 0, 0), hand__R=(-60, 0, 0),
               thigh__L=(10, -4, 0), shin__L=(-30, 0, 0), thigh__R=(-6, 4, 0), shin__R=(-18, 0, 0),
               foot__L=(-25, 0, 0), foot__R=(-25, 0, 0))
    m_push = P(hips=(-10, 0, 0), spine=(-18, 0, 0), chest=(-16, 0, 0), head=(30, 0, 0),
               upper_arm__L=(40, -18, 0), forearm__L=(96, 0, 0), hand__L=(-70, 0, 0),
               upper_arm__R=(40, 18, 0), forearm__R=(96, 0, 0), hand__R=(-70, 0, 0),
               thigh__L=(100, -12, 0), shin__L=(-120, 0, 0), foot__L=(10, 0, 0),
               thigh__R=(4, 4, 0), shin__R=(-30, 0, 0), foot__R=(-20, 0, 0), _hips=(0, 0, -0.06))
    clips.append(Clip("mantle", 20, False, {0: m_hang, 3: m_hang, 12: m_push, 20: P(**c_base)}))
    return clips


def build() -> None:
    pipeline.reset_scene()
    armature = rig.build_armature("man_rig", BONES)
    body_parts, head_parts = _parts()
    body = rig.join_skinned("mesh_body", body_parts, armature)
    head = rig.join_skinned("mesh_head", head_parts, armature)
    geo.grime(body, seed=5, dirt_height=0.35, strength=0.5, rust_tint=0.1, noise_scale=5.0)
    geo.grime(head, seed=6, dirt_height=0.0, strength=0.0, rust_tint=0.06, noise_scale=8.0)
    rig.bake_clips(armature, _clips(), hips_scale=HIPS_SCALE)
    info = pipeline.finish("characters/man", tri_budget=4000)
    assert len(BONES) <= 32, f"костей {len(BONES)}, бюджет около 30"
    pipeline.render_pose_sheet("characters/man", armature, [
        ("idle", 0), ("walk", 0), ("walk", 4), ("walk", 10),
        ("run", 0), ("run", 6), ("crouch_idle", 0), ("crouch_walk", 0),
        ("air", 0), ("land", 2), ("mantle", 2), ("mantle", 12),
    ], cols=4)
    _ = info


if __name__ == "__main__":
    build()
