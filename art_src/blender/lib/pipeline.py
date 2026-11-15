"""Сцена, материал, экспорт .glb и превью с четырёх ракурсов.

Типичный скрипт ассета:

    from lib import pipeline, geo
    pipeline.reset_scene()
    ... строим объекты через geo.Builder ...
    pipeline.finish("items/radiator_cast_iron", tri_budget=800)

finish() проверяет бюджет треугольников, экспортирует .glb в
assets/models/<путь>.glb и рендерит превью в art_src/previews/<путь>.png.
"""

from __future__ import annotations

import math
import os
import sys
from pathlib import Path

import bpy
from mathutils import Vector

from . import geo, palette

ROOT = Path(__file__).resolve().parents[3]           # корень проекта Godot
PALETTE_PNG = ROOT / "assets" / "textures" / "palette.png"
MODELS_DIR = ROOT / "assets" / "models"
PREVIEWS_DIR = ROOT / "art_src" / "previews"

PREVIEW_CELL = 384  # пикселей на один ракурс; итоговое превью 2×2


def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if not PALETTE_PNG.exists():
        palette.write_png(PALETTE_PNG)


def palette_material() -> bpy.types.Material:
    """Материал для превью в Blender: палитра × вертексный цвет.

    В Godot этот материал не используется: импорт-плагин ставит общий
    материал проекта (assets/shaders/palette.tres), чтобы всё рисовалось одинаково.
    """
    mat = bpy.data.materials.get("palette")
    if mat:
        return mat
    mat = bpy.data.materials.new("palette")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = 0.85
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(str(PALETTE_PNG), check_existing=True)
    tex.interpolation = "Closest"
    uv = nt.nodes.new("ShaderNodeUVMap")
    uv.uv_map = geo.UV_LAYER
    col = nt.nodes.new("ShaderNodeVertexColor")
    col.layer_name = geo.COLOR_LAYER
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    {s.identifier: s for s in mix.inputs}["Factor_Float"].default_value = 1.0
    nt.links.new(uv.outputs["UV"], tex.inputs["Vector"])
    # у узла Mix несколько сокетов с именем "A": берём цветовые по идентификатору
    sock_in = {s.identifier: s for s in mix.inputs}
    sock_out = {s.identifier: s for s in mix.outputs}
    nt.links.new(tex.outputs["Color"], sock_in["A_Color"])
    nt.links.new(col.outputs["Color"], sock_in["B_Color"])
    nt.links.new(sock_out["Result_Color"], bsdf.inputs["Base Color"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat


def _visual_meshes() -> list[bpy.types.Object]:
    return [o for o in bpy.context.scene.objects if o.type == "MESH" and not o.name.startswith("col_")]


def _budget_meshes() -> list[bpy.types.Object]:
    """Меши, которые видны одновременно: разбитый вариант заменяет целый, а не добавляется."""
    return [o for o in _visual_meshes() if not o.name.endswith("_broken")]


def finish(asset_path: str, tri_budget: int) -> dict:
    """Проверка, экспорт и превью. asset_path без расширения, например 'items/radiator_cast_iron'."""
    mat = palette_material()
    tris = 0
    for o in _visual_meshes():
        o.data.materials.clear()
        o.data.materials.append(mat)
    for o in _budget_meshes():
        tris += geo.triangle_count(o)
    if tris > tri_budget:
        raise RuntimeError(f"{asset_path}: {tris} треугольников, бюджет {tri_budget}")

    glb = MODELS_DIR / f"{asset_path}.glb"
    glb.parent.mkdir(parents=True, exist_ok=True)
    _export_glb(glb)

    png = PREVIEWS_DIR / f"{asset_path}.png"
    png.parent.mkdir(parents=True, exist_ok=True)
    _rest_pose_for_preview()
    render_preview(png)
    info = {"asset": asset_path, "triangles": tris, "glb": str(glb.relative_to(ROOT)),
            "preview": str(png.relative_to(ROOT))}
    print(f"[asset] {info}")
    return info


def _rest_pose_for_preview() -> None:
    """Превью снимаем в позе покоя: глушим NLA-дорожки и сбрасываем кости."""
    for o in bpy.context.scene.objects:
        if o.type != "ARMATURE":
            continue
        if o.animation_data:
            o.animation_data.action = None
            for track in o.animation_data.nla_tracks:
                track.mute = True
        for pb in o.pose.bones:
            pb.location = (0.0, 0.0, 0.0)
            pb.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
    bpy.context.view_layer.update()


def _export_glb(path: Path) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.context.scene.objects:
        o.select_set(True)
    # Материал в .glb только заглушка: настоящий ставит импорт-плагин Godot.
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_materials="PLACEHOLDER",
        export_vertex_color="ACTIVE",
        export_all_vertex_colors=False,
        export_extras=True,
        export_image_format="NONE",
        export_animations=True,
        export_animation_mode="NLA_TRACKS",
        export_skins=True,
        export_force_sampling=True,
        export_optimize_animation_size=False,
    )


# --- превью ---------------------------------------------------------------

def _bounds() -> tuple[Vector, float]:
    pts = []
    for o in _visual_meshes():
        pts += [o.matrix_world @ Vector(c) for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return (lo + hi) / 2, (hi - lo).length / 2


class _Studio:
    """Свет и камера для превью: тёплый ключ (натриевый фонарь) и холодный контровой (луна)."""

    def __init__(self) -> None:
        scene = bpy.context.scene
        self.scene = scene
        for o in scene.objects:
            # коллизии и «разбитые» варианты в превью не показываем
            if o.name.startswith("col_") or o.name.endswith("_broken"):
                o.hide_render = True
        scene.render.engine = "CYCLES"
        scene.cycles.device = "CPU"
        scene.cycles.samples = 32
        try:
            scene.cycles.use_denoising = True
        except AttributeError:
            pass
        scene.render.resolution_x = scene.render.resolution_y = PREVIEW_CELL
        scene.render.film_transparent = False
        scene.view_settings.view_transform = "Standard"
        world = scene.world or bpy.data.worlds.new("preview")
        scene.world = world
        world.use_nodes = True
        bg = world.node_tree.nodes.get("Background")
        bg.inputs["Color"].default_value = (0.045, 0.05, 0.065, 1.0)  # ночная синева
        bg.inputs["Strength"].default_value = 1.0

        self.center, self.radius = _bounds()
        self.key = bpy.data.objects.new("key", bpy.data.lights.new("key", "AREA"))
        self.key.data.energy = 35 * (self.radius * 3) ** 2  # мощность растёт с квадратом расстояния
        self.key.data.size = self.radius * 2.5
        self.key.data.color = (1.0, 0.82, 0.62)
        self.rim = bpy.data.objects.new("rim", bpy.data.lights.new("rim", "SUN"))
        self.rim.data.energy = 1.2
        self.rim.data.color = (0.62, 0.74, 1.0)
        self.cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
        self.cam.data.lens = 50
        for o in (self.key, self.rim, self.cam):
            scene.collection.objects.link(o)
        scene.camera = self.cam
        self.dist = self.radius / math.tan(self.cam.data.angle / 2) * 1.15
        self.tmp_dir = PREVIEWS_DIR / ".tmp"
        self.tmp_dir.mkdir(parents=True, exist_ok=True)
        self.tiles: list = []

    def shoot(self, azimuth: float, elevation: float) -> None:
        d = _dir(azimuth, elevation)
        self.cam.location = self.center + d * self.dist
        self.cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        kd = _dir(azimuth - 40, 45)
        self.key.location = self.center + kd * self.radius * 3
        self.key.rotation_euler = (-kd).to_track_quat("-Z", "Y").to_euler()
        self.rim.rotation_euler = (_dir(azimuth + 160, 30) * -1).to_track_quat("-Z", "Y").to_euler()
        self.scene.render.filepath = str(self.tmp_dir / f"v{len(self.tiles)}.png")
        bpy.ops.render.render(write_still=True)
        self.tiles.append(bpy.data.images.load(self.scene.render.filepath))

    def save(self, path: Path, cols: int) -> None:
        _compose(self.tiles, path, cols)
        for t in self.tiles:
            os.remove(bpy.path.abspath(t.filepath))
            bpy.data.images.remove(t)
        for o in (self.key, self.rim, self.cam):
            bpy.data.objects.remove(o)


def render_preview(path: Path) -> None:
    """Четыре ракурса в одной картинке 2×2: спереди-слева, сзади-справа, сбоку, сверху."""
    studio = _Studio()
    for az, el in [(-35, 22), (145, 22), (90, 8), (-35, 70)]:  # азимут от -Y, высота в градусах
        studio.shoot(az, el)
    studio.save(path, cols=2)


def render_pose_sheet(asset_path: str, armature: bpy.types.Object, poses: list[tuple[str, int]],
                      cols: int = 4, azimuth: float = -50, elevation: float = 12) -> Path:
    """Раскадровка: ключевые позы клипов (имя, кадр) на одной картинке."""
    from . import rig
    path = PREVIEWS_DIR / f"{asset_path}_poses.png"
    studio = _Studio()
    studio.radius *= 1.15  # запас под вытянутые руки и шаг
    studio.dist *= 1.15
    rig.pose_sheet(armature, poses, lambda _i: studio.shoot(azimuth, elevation))
    studio.save(path, cols=cols)
    print(f"[poses] {path.relative_to(ROOT)}")
    return path


def _dir(azimuth_deg: float, elevation_deg: float) -> Vector:
    a, e = math.radians(azimuth_deg), math.radians(elevation_deg)
    return Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))


def _compose(tiles: list, path: Path, cols: int) -> None:
    import numpy as np
    n = PREVIEW_CELL
    rows = math.ceil(len(tiles) / cols)
    canvas = np.zeros((n * rows, n * cols, 4), dtype=np.float32)
    canvas[..., 3] = 1.0
    for i, img in enumerate(tiles):
        px = np.array(img.pixels[:], dtype=np.float32).reshape(n, n, 4)
        # пиксели Blender идут снизу вверх: первый ряд картинок — это верхние строки
        row, col = rows - 1 - i // cols, i % cols
        canvas[row * n:(row + 1) * n, col * n:(col + 1) * n] = px
    for c in range(1, cols):
        canvas[:, c * n - 1:c * n + 1] = (0.2, 0.2, 0.2, 1)
    for r in range(1, rows):
        canvas[r * n - 1:r * n + 1, :] = (0.2, 0.2, 0.2, 1)
    out = bpy.data.images.new("preview_out", n * cols, n * rows, alpha=True)
    out.pixels[:] = canvas.ravel()
    out.filepath_raw = str(path)
    out.file_format = "PNG"
    out.save()
    bpy.data.images.remove(out)


def run_from_cli() -> list[str]:
    """Аргументы после '--' (для запуска через blender -b -P)."""
    return sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
