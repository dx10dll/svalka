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


def finish(asset_path: str, tri_budget: int) -> dict:
    """Проверка, экспорт и превью. asset_path без расширения, например 'items/radiator_cast_iron'."""
    mat = palette_material()
    tris = 0
    for o in _visual_meshes():
        o.data.materials.clear()
        o.data.materials.append(mat)
        tris += geo.triangle_count(o)
    if tris > tri_budget:
        raise RuntimeError(f"{asset_path}: {tris} треугольников, бюджет {tri_budget}")

    glb = MODELS_DIR / f"{asset_path}.glb"
    glb.parent.mkdir(parents=True, exist_ok=True)
    _export_glb(glb)

    png = PREVIEWS_DIR / f"{asset_path}.png"
    png.parent.mkdir(parents=True, exist_ok=True)
    render_preview(png)
    info = {"asset": asset_path, "triangles": tris, "glb": str(glb.relative_to(ROOT)),
            "preview": str(png.relative_to(ROOT))}
    print(f"[asset] {info}")
    return info


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
    )


# --- превью ---------------------------------------------------------------

def _bounds() -> tuple[Vector, float]:
    pts = []
    for o in _visual_meshes():
        pts += [o.matrix_world @ Vector(c) for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return (lo + hi) / 2, (hi - lo).length / 2


def render_preview(path: Path) -> None:
    """Четыре ракурса в одной картинке 2×2: спереди-слева, сзади-справа, сбоку, сверху."""
    scene = bpy.context.scene
    hidden = [o for o in scene.objects if o.name.startswith("col_")]
    for o in hidden:
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

    world = bpy.data.worlds.new("preview") if not scene.world else scene.world
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.045, 0.05, 0.065, 1.0)  # ночная синева
    bg.inputs["Strength"].default_value = 1.0

    center, radius = _bounds()
    # тёплый ключевой свет (как натриевый фонарь) и холодный контровой (луна)
    key = bpy.data.objects.new("key", bpy.data.lights.new("key", "AREA"))
    key.data.energy = 35 * (radius * 3) ** 2  # мощность растёт с квадратом расстояния до предмета
    key.data.size = radius * 2.5
    key.data.color = (1.0, 0.82, 0.62)
    rim = bpy.data.objects.new("rim", bpy.data.lights.new("rim", "SUN"))
    rim.data.energy = 1.2
    rim.data.color = (0.62, 0.74, 1.0)
    for o in (key, rim):
        scene.collection.objects.link(o)

    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.lens = 50
    scene.collection.objects.link(cam)
    scene.camera = cam
    dist = radius / math.tan(cam.data.angle / 2) * 1.15

    views = [(-35, 22), (145, 22), (90, 8), (-35, 70)]  # азимут от -Y, высота в градусах
    tiles = []
    tmp_dir = PREVIEWS_DIR / ".tmp"
    tmp_dir.mkdir(parents=True, exist_ok=True)
    for i, (az, el) in enumerate(views):
        d = _dir(az, el)
        cam.location = center + d * dist
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        kd = _dir(az - 40, 45)
        key.location = center + kd * radius * 3
        key.rotation_euler = (-kd).to_track_quat("-Z", "Y").to_euler()
        rim.rotation_euler = (_dir(az + 160, 30) * -1).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(tmp_dir / f"v{i}.png")
        bpy.ops.render.render(write_still=True)
        tiles.append(bpy.data.images.load(scene.render.filepath))

    _compose(tiles, path)
    for t in tiles:
        os.remove(bpy.path.abspath(t.filepath))
        bpy.data.images.remove(t)
    for o in (key, rim, cam):
        bpy.data.objects.remove(o)


def _dir(azimuth_deg: float, elevation_deg: float) -> Vector:
    a, e = math.radians(azimuth_deg), math.radians(elevation_deg)
    return Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))


def _compose(tiles: list, path: Path) -> None:
    import numpy as np
    n = PREVIEW_CELL
    canvas = np.zeros((n * 2, n * 2, 4), dtype=np.float32)
    for i, img in enumerate(tiles):
        px = np.array(img.pixels[:], dtype=np.float32).reshape(n, n, 4)
        # пиксели Blender идут снизу вверх: верхний ряд картинок — это нижние строки
        row, col = 1 - i // 2, i % 2
        canvas[row * n:(row + 1) * n, col * n:(col + 1) * n] = px
    canvas[:, n - 1:n + 1] = (0.2, 0.2, 0.2, 1)
    canvas[n - 1:n + 1, :] = (0.2, 0.2, 0.2, 1)
    out = bpy.data.images.new("preview_out", n * 2, n * 2, alpha=True)
    out.pixels[:] = canvas.ravel()
    out.filepath_raw = str(path)
    out.file_format = "PNG"
    out.save()
    bpy.data.images.remove(out)


def run_from_cli() -> list[str]:
    """Аргументы после '--' (для запуска через blender -b -P)."""
    return sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
