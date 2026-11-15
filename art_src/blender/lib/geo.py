"""Построение лоу-поли геометрии через bmesh.

Каждая деталь сразу получает цвет из палитры: UV всех её граней указывают в
центр ячейки. Фаска делается по рёбрам детали, новые грани наследуют её цвет.
Единицы — метры, ось Z вверх (Blender). Перед моделью смотрит в -Y: после
экспорта в glTF это станет +Z, то есть «лицом» модели в Godot.
"""

from __future__ import annotations

import math
import random
from typing import Iterable

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

from . import palette

UV_LAYER = "UVMap"
COLOR_LAYER = "Color"


class Builder:
    """Копит детали одной модели в одном bmesh."""

    def __init__(self, name: str) -> None:
        self.name = name
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new(UV_LAYER)

    # --- служебное -------------------------------------------------------
    def _paint(self, faces: Iterable[bmesh.types.BMFace], color: str) -> None:
        u, v = palette.uv_of(color)
        for f in faces:
            for loop in f.loops:
                loop[self.uv].uv = (u, v)

    def _bevel(self, geom_faces: list[bmesh.types.BMFace], width: float, segments: int) -> list[bmesh.types.BMFace]:
        """Фаска по рёбрам детали. Bevel пересоздаёт грани, поэтому возвращаем новый список."""
        if width <= 0.0:
            return geom_faces
        before = set(self.bm.faces)
        edges = {e for f in geom_faces for e in f.edges}
        bmesh.ops.bevel(self.bm, geom=list(edges), offset=width, offset_type="OFFSET",
                        segments=segments, profile=0.5, affect="EDGES", clamp_overlap=True)
        return [f for f in self.bm.faces if f not in before] + [f for f in geom_faces if f.is_valid]

    # --- примитивы -------------------------------------------------------
    def box(self, size: tuple[float, float, float], center: tuple[float, float, float],
            color: str, bevel: float = 0.0, segments: int = 1,
            rotation: tuple[float, float, float] = (0.0, 0.0, 0.0)) -> list[bmesh.types.BMFace]:
        """Параллелепипед с фаской. size — полные размеры по X, Y, Z."""
        res = bmesh.ops.create_cube(self.bm, size=1.0)
        verts = res["verts"]
        m = (Matrix.Translation(center) @ _euler(rotation) @ Matrix.Diagonal((*size, 1.0)))
        bmesh.ops.transform(self.bm, matrix=m, verts=verts)
        faces = list({f for v in verts for f in v.link_faces})
        self._paint(faces, color)
        return self._bevel(faces, bevel, segments)

    def cylinder(self, radius: float, depth: float, center: tuple[float, float, float],
                 color: str, axis: str = "Z", segments: int = 8, bevel: float = 0.0,
                 radius_top: float | None = None, cap_color: str | None = None) -> list[bmesh.types.BMFace]:
        """Цилиндр (или усечённый конус) вдоль оси axis."""
        r2 = radius if radius_top is None else radius_top
        res = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=segments,
                                    radius1=radius, radius2=r2, depth=depth)
        verts = res["verts"]
        rot = {"Z": Matrix.Identity(4),
               "X": Matrix.Rotation(math.radians(90), 4, "Y"),
               "Y": Matrix.Rotation(math.radians(90), 4, "X")}[axis]
        bmesh.ops.transform(self.bm, matrix=Matrix.Translation(center) @ rot, verts=verts)
        faces = list({f for v in verts for f in v.link_faces})
        self._paint(faces, color)
        if cap_color:
            ax = {"X": Vector((1, 0, 0)), "Y": Vector((0, 1, 0)), "Z": Vector((0, 0, 1))}[axis]
            self._paint([f for f in faces if abs(f.normal.dot(ax)) > 0.99], cap_color)
        return self._bevel(faces, bevel, 1)

    def chip_faces(self, faces: list[bmesh.types.BMFace], color: str, share: float, seed: int,
                   max_area: float = 0.0015) -> None:
        """Перекрашивает случайную долю мелких граней (фаски, торцы): сколы краски.

        Большие грани не трогаем: целиком ржавая сторона выглядит как полоса, а не как скол.
        """
        rnd = random.Random(seed)
        alive = [f for f in faces if f.is_valid and f.calc_area() <= max_area]
        self._paint([f for f in alive if rnd.random() < share], color)

    # --- сборка ----------------------------------------------------------
    def build(self, collection: bpy.types.Collection | None = None) -> bpy.types.Object:
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-5)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        mesh = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        for p in mesh.polygons:
            p.use_smooth = False
        obj = bpy.data.objects.new(self.name, mesh)
        (collection or bpy.context.scene.collection).objects.link(obj)
        return obj


def _euler(rot: tuple[float, float, float]) -> Matrix:
    from mathutils import Euler
    return Euler(tuple(math.radians(a) for a in rot), "XYZ").to_matrix().to_4x4()


def grime(obj: bpy.types.Object, seed: int = 0, dirt_height: float = 0.25, strength: float = 0.55,
          rust_tint: float = 0.35, noise_scale: float = 6.0) -> None:
    """Вертексный цвет поверх палитры: грязь снизу, пятна ржавчины, лёгкий шум.

    Итоговый цвет = палитра × вертексный цвет, поэтому здесь только затемнения
    и сдвиг в рыжий, белый (1,1,1) означает «как в палитре».
    """
    mesh = obj.data
    if COLOR_LAYER in mesh.color_attributes:
        mesh.color_attributes.remove(mesh.color_attributes[COLOR_LAYER])
    attr = mesh.color_attributes.new(COLOR_LAYER, "BYTE_COLOR", "CORNER")
    zs = [v.co.z for v in mesh.vertices]
    z0, z1 = min(zs), max(zs)
    off = Vector((seed * 17.31, seed * 5.77, seed * 3.13))
    for poly in mesh.polygons:
        for li in poly.loop_indices:
            vi = mesh.loops[li].vertex_index
            co = mesh.vertices[vi].co
            h = (co.z - z0) / max(z1 - z0, 1e-4)
            dirt = max(0.0, 1.0 - h / max(dirt_height, 1e-4)) * strength
            n = noise.noise(co * noise_scale + off)  # -1..1
            spot = max(0.0, n) * rust_tint
            k = 1.0 - dirt * 0.6 - abs(n) * 0.08
            r = k * (1.0 + spot * 0.15)
            g = k * (1.0 - spot * 0.25)
            b = k * (1.0 - spot * 0.45)
            attr.data[li].color = (_c(r), _c(g), _c(b), 1.0)
    mesh.color_attributes.active_color = attr
    mesh.color_attributes.render_color_index = mesh.color_attributes.find(COLOR_LAYER)


def _c(x: float) -> float:
    return max(0.0, min(1.0, x))


def collider_box(name: str, size: tuple[float, float, float], center: tuple[float, float, float],
                 rotation: tuple[float, float, float] = (0.0, 0.0, 0.0)) -> bpy.types.Object:
    """Выпуклая коллизия. Имя начинается с col_: в Godot станет CollisionShape3D."""
    b = Builder(f"col_{name}")
    b.box(size, center, "white", rotation=rotation)
    obj = b.build()
    obj.display_type = "WIRE"
    obj.hide_render = True
    return obj


def grip(name: str, location: tuple[float, float, float],
         rotation: tuple[float, float, float] = (0.0, 0.0, 0.0)) -> bpy.types.Object:
    """Точка хвата для IK рук. В Godot станет Marker3D с именем grip_*."""
    e = bpy.data.objects.new(f"grip_{name}", None)
    e.empty_display_type = "ARROWS"
    e.empty_display_size = 0.08
    e.location = location
    e.rotation_euler = tuple(math.radians(a) for a in rotation)
    bpy.context.scene.collection.objects.link(e)
    return e


def triangle_count(obj: bpy.types.Object) -> int:
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)
