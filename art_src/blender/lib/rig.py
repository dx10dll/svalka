"""Риг и анимации персонажей.

Подход: сегментный лоу-поли. Каждая деталь тела жёстко привязана к одной кости
(вес 1.0), суставы перекрываются скруглёнными краями деталей. Так скелет не
ломает геометрию при любых позах и рэгдолле, а стиль остаётся «рубленым».

Позы задаются поворотами вокруг МИРОВЫХ осей (как видит аниматор), а не
локальных осей кости:
    x > 0 — наклон вперёд (к -Y, куда смотрит персонаж) для туловища,
            для конечности, висящей вниз, — мах вперёд;
    y > 0 — завал на левый бок персонажа (+X); висящая рука при этом идёт к -X;
    z > 0 — поворот влево (против часовой, если смотреть сверху).
Библиотека сама переводит их в локальные оси костей.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field

import bpy
from mathutils import Euler, Matrix, Quaternion, Vector

from . import geo

FPS = 30


@dataclass
class BoneDef:
    name: str
    head: tuple[float, float, float]
    tail: tuple[float, float, float]
    parent: str | None = None
    connect: bool = False


def mirror_name(name: str) -> str:
    if name.endswith(".L"):
        return name[:-2] + ".R"
    if name.endswith(".R"):
        return name[:-2] + ".L"
    return name


def mirrored(bones: list[BoneDef]) -> list[BoneDef]:
    """Добавляет правые (.R) копии левых (.L) костей, отражая по X."""
    out: list[BoneDef] = []
    for b in bones:
        out.append(b)
        if b.name.endswith(".L"):
            flip = lambda p: (-p[0], p[1], p[2])  # noqa: E731
            out.append(BoneDef(mirror_name(b.name), flip(b.head), flip(b.tail),
                               mirror_name(b.parent) if b.parent else None, b.connect))
    return out


def build_armature(name: str, bones: list[BoneDef]) -> bpy.types.Object:
    arm = bpy.data.armatures.new(name)
    obj = bpy.data.objects.new(name, arm)
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    for b in bones:
        eb = arm.edit_bones.new(b.name)
        eb.head = b.head
        eb.tail = b.tail
        eb.roll = 0.0  # крен не важен: позы задаются в мировых осях
        if b.parent:
            eb.parent = arm.edit_bones[b.parent]
            eb.use_connect = b.connect
    bpy.ops.object.mode_set(mode="OBJECT")
    return obj


def skin_rigid(mesh_obj: bpy.types.Object, bone: str) -> None:
    """Все вершины объекта целиком привязываются к одной кости."""
    vg = mesh_obj.vertex_groups.new(name=bone)
    vg.add(range(len(mesh_obj.data.vertices)), 1.0, "REPLACE")


def join_skinned(name: str, parts: list[bpy.types.Object], armature: bpy.types.Object) -> bpy.types.Object:
    """Склеивает детали в один меш и вешает его на скелет."""
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    obj.data.name = name
    obj.parent = armature
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = armature
    return obj


# --- анимация ----------------------------------------------------------------

@dataclass
class Clip:
    """Клип: ключи по кадрам. keys[кадр][кость] = (x, y, z) в градусах, мировые оси.
    Особый ключ "_hips" = (dx, dy, dz) — смещение таза в метрах."""
    name: str
    length: int
    loop: bool
    keys: dict[int, dict[str, tuple[float, float, float]]] = field(default_factory=dict)


def _world_to_local(pbone: bpy.types.PoseBone, deg: tuple[float, float, float]) -> Quaternion:
    # x: наклон вперёд = поворот вокруг мировой X на -угол (вперёд у нас -Y)
    world = Euler((math.radians(-deg[0]), math.radians(deg[1]), math.radians(deg[2])), "XYZ").to_matrix()
    rest = pbone.bone.matrix_local.to_3x3()
    return (rest.inverted() @ world @ rest).to_quaternion()


def bake_clips(armature: bpy.types.Object, clips: list[Clip], hips_bone: str = "hips",
               hips_scale: float = 1.0) -> None:
    """Создаёт по Action на клип. Интерполяция Безье с авто-касательными: мягкие замахи и доводки."""
    bpy.context.scene.render.fps = FPS
    armature.animation_data_create()
    for pb in armature.pose.bones:
        pb.rotation_mode = "QUATERNION"
    actions = []
    for clip in clips:
        action = bpy.data.actions.new(clip.name)
        action.use_fake_user = True
        armature.animation_data.action = action
        used = sorted({b for k in clip.keys.values() for b in k if not b.startswith("_")})
        frames = sorted(clip.keys)
        last: dict[str, Quaternion] = {}
        for f in frames:
            pose = clip.keys[f]
            for bone in used:
                if bone not in pose and f != frames[0] and not (clip.loop and f == frames[-1]):
                    continue  # кость без ключа на этом кадре — кривая идёт плавно мимо
                pb = armature.pose.bones[bone]
                q = _world_to_local(pb, pose.get(bone, (0.0, 0.0, 0.0)))
                if bone in last and last[bone].dot(q) < 0.0:
                    q.negate()  # кратчайший путь между ключами
                last[bone] = q.copy()
                pb.rotation_quaternion = q
                pb.keyframe_insert("rotation_quaternion", frame=f)
            if "_hips" in pose or f == frames[0] or (clip.loop and f == frames[-1]):
                pb = armature.pose.bones[hips_bone]
                d = pose.get("_hips", (0.0, 0.0, 0.0))
                rest = pb.bone.matrix_local.to_3x3()
                pb.location = rest.inverted() @ (Vector(d) * hips_scale)
                pb.keyframe_insert("location", frame=f)
        _smooth_fcurves(action, clip.loop)
        action.frame_range = (0, clip.length)
        actions.append(action)
        # сброс позы перед следующим клипом
        for pb in armature.pose.bones:
            pb.rotation_quaternion = Quaternion()
            pb.location = Vector()
    # каждый клип — отдельная NLA-дорожка: так экспортёр glTF пишет их отдельными анимациями
    armature.animation_data.action = None
    for action in actions:
        track = armature.animation_data.nla_tracks.new()
        track.name = action.name
        track.strips.new(action.name, 0, action)


def _iter_fcurves(action: bpy.types.Action):
    if hasattr(action, "fcurves") and len(getattr(action, "fcurves", [])):
        yield from action.fcurves
        return
    # Blender 4.4+: слои и слоты
    for layer in getattr(action, "layers", []):
        for strip in layer.strips:
            for bag in getattr(strip, "channelbags", []):
                yield from bag.fcurves


def _smooth_fcurves(action: bpy.types.Action, loop: bool) -> None:
    for fc in _iter_fcurves(action):
        for kp in fc.keyframe_points:
            kp.interpolation = "BEZIER"
            kp.handle_left_type = "AUTO_CLAMPED"
            kp.handle_right_type = "AUTO_CLAMPED"
        if loop:
            mod = fc.modifiers.new("CYCLES")  # касательные на стыке цикла становятся гладкими
            mod.mode_before = "REPEAT"
            mod.mode_after = "REPEAT"
        fc.update()


def mirror_pose(pose: dict[str, tuple[float, float, float]]) -> dict[str, tuple[float, float, float]]:
    """Зеркальная поза: левое и правое меняются местами, боковые повороты меняют знак."""
    out = {}
    for bone, v in pose.items():
        if bone == "_hips":
            out[bone] = (-v[0], v[1], v[2])
        else:
            out[mirror_name(bone)] = (v[0], -v[1], -v[2])
    return out


def pose_sheet(armature: bpy.types.Object, clip_frames: list[tuple[str, int]], render_one) -> None:
    """Ставит позу клипа на кадре и вызывает render_one(индекс) — для раскадровки."""
    for i, (clip_name, frame) in enumerate(clip_frames):
        armature.animation_data.action = bpy.data.actions[clip_name]
        _assign_slot(armature)
        bpy.context.scene.frame_set(frame)
        bpy.context.view_layer.update()
        render_one(i)
    armature.animation_data.action = None


def _assign_slot(armature: bpy.types.Object) -> None:
    ad = armature.animation_data
    if hasattr(ad, "action_slot") and ad.action and ad.action_slot is None and len(ad.action.slots):
        ad.action_slot = ad.action.slots[0]


_ = (geo, Matrix)
