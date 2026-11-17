# -*- coding: utf-8 -*-
"""丽天智能 MMR 光伏安装机器人 — 体素资产生成器
Blender 4.5 / 运行: blender -b --factory-startup --python blender/build_assets.py
输出: godot/assets/models/*.glb, blender/textures/*.png, blender/previews/*.png

坐标约定（Blender）: 机器人朝 +Y, Z 向上。导出 glTF 后 +Y -> Godot -Z。
关节: Turret(偏航, Godot local Y) / ArmLower, ArmUpper, Wrist(俯仰, Godot local X)
所有尺寸单位：米。
"""
import bpy
import math
import os
import struct
import zlib

import numpy as np
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEX_DIR = os.path.join(ROOT, "blender", "textures")
MODEL_DIR = os.path.join(ROOT, "godot", "assets", "models")
PREVIEW_DIR = os.path.join(ROOT, "blender", "previews")
GODOT_TEX = os.path.join(ROOT, "godot", "assets", "textures")
for d in (TEX_DIR, MODEL_DIR, PREVIEW_DIR, GODOT_TEX):
    os.makedirs(d, exist_ok=True)


# ---------------------------------------------------------------- PNG / 贴图
def save_png(path, arr):
    h, w, _ = arr.shape
    raw = b"".join(b"\x00" + arr[y].tobytes() for y in range(h))

    def chunk(tag, data):
        c = tag + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)

    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(raw, 9))
           + chunk(b"IEND", b""))
    with open(path, "wb") as f:
        f.write(png)


def noise_tex(w, h, base, amp, seed, specks=None):
    rng = np.random.default_rng(seed)
    arr = np.clip(np.array(base, dtype=np.int16)[None, None, :]
                  + rng.integers(-amp, amp + 1, size=(h, w, 1)), 0, 255).astype(np.uint8)
    if specks:
        color, count = specks
        ys = rng.integers(0, h, count)
        xs = rng.integers(0, w, count)
        arr[ys, xs] = color
    return arr


def sand_tex():
    rng = np.random.default_rng(7)
    arr = noise_tex(32, 32, (203, 178, 130), 9, 7, specks=((176, 150, 104), 26))
    for _ in range(10):
        x, y = rng.integers(0, 32, 2)
        arr[y:y + 2, x:x + 2] = (232, 210, 164)
    return arr


def panel_tex():
    w, h = 120, 60
    arr = np.zeros((h, w, 3), dtype=np.uint8)
    arr[:, :] = (12, 20, 32)
    cols, rows = 12, 6
    cw, ch = w // cols, h // rows
    rng = np.random.default_rng(21)
    for r in range(rows):
        for c in range(cols):
            tint = int(rng.integers(-5, 6))
            arr[r * ch + 1:(r + 1) * ch - 1, c * cw + 1:(c + 1) * cw - 1] = (17 + tint, 33 + tint, 55 + tint)
            if rng.random() < 0.15:
                arr[r * ch + 2:(r + 1) * ch - 2, c * cw + 2:(c + 1) * cw - 2] = (24, 48, 78)
    for c in range(cols + 1):
        arr[:, min(c * cw, w - 1)] = (118, 130, 144)
    for r in range(rows + 1):
        arr[min(r * ch, h - 1), :] = (118, 130, 144)
    return arr


def orange_tex():
    arr = noise_tex(16, 16, (226, 104, 28), 7, 81)
    arr[3::4, :] = (196, 84, 18)
    return arr


def wood_tex():
    rng = np.random.default_rng(91)
    arr = noise_tex(32, 32, (196, 162, 110), 7, 91)
    for y in range(0, 32, 8):
        arr[y, :] = (168, 136, 90)
    for _ in range(6):
        x, y = rng.integers(0, 31, 2)
        arr[y:y + 2, x:x + 3] = (178, 144, 96)
    return arr


def make_textures():
    specs = {
        "sand": sand_tex(),
        "panel": panel_tex(),
        "panel_back": noise_tex(16, 16, (200, 204, 208), 4, 31),
        "panel_frame": noise_tex(16, 16, (128, 132, 138), 4, 33),
        "white": noise_tex(16, 16, (230, 232, 234), 4, 41),
        "dark": noise_tex(16, 16, (52, 56, 60), 4, 43),
        "accent": noise_tex(16, 16, (46, 191, 113), 4, 47),
        "green": noise_tex(16, 16, (92, 158, 42), 5, 49),
        "orange": orange_tex(),
        "orange_dark": noise_tex(16, 16, (186, 78, 14), 5, 83),
        "blue": noise_tex(16, 16, (42, 104, 200), 5, 85),
        "red": noise_tex(16, 16, (198, 48, 38), 4, 87),
        "wood": wood_tex(),
        "hazard": hazard_tex(),
        "rubber": rubber_tex(),
        "steel": noise_tex(16, 16, (170, 176, 182), 6, 53),
        "rock": noise_tex(32, 32, (150, 130, 98), 12, 57, specks=((120, 102, 76), 18)),
        "cloud": noise_tex(16, 16, (250, 251, 252), 2, 61),
        "orange_worker": noise_tex(16, 16, (232, 126, 50), 4, 67),
        "yellow": noise_tex(16, 16, (240, 196, 64), 4, 71),
        "skin": noise_tex(16, 16, (214, 168, 128), 3, 73),
        "glass": noise_tex(8, 8, (40, 70, 90), 4, 79),
    }
    for name, arr in specs.items():
        save_png(os.path.join(TEX_DIR, name + ".png"), arr)
    save_png(os.path.join(GODOT_TEX, "sand.png"), specs["sand"])
    return specs


def hazard_tex():
    arr = np.zeros((16, 16, 3), dtype=np.uint8)
    for y in range(16):
        for x in range(16):
            arr[y, x] = (240, 190, 60) if ((x + y) // 4) % 2 == 0 else (44, 46, 50)
    return arr


def rubber_tex():
    arr = noise_tex(16, 16, (32, 34, 37), 3, 11)
    arr[3::4, :] = (46, 50, 54)
    return arr


# ---------------------------------------------------------------- 材质
_MATS = {}


def _image_mat(name, tex, rough=0.85, metal=0.0, emit=None):
    key = (name, rough, metal, bool(emit))
    if key in _MATS:
        return _MATS[key]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    node = nt.nodes.new("ShaderNodeTexImage")
    img = bpy.data.images.load(os.path.join(TEX_DIR, tex + ".png"), check_existing=True)
    img.colorspace_settings.name = "sRGB"
    node.image = img
    node.interpolation = "Closest"
    nt.links.new(node.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if emit:
        nt.links.new(node.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = emit
    mat.diffuse_color = (0.8, 0.8, 0.8, 1)
    _MATS[key] = mat
    return mat


def M(tex, **kw):
    return _image_mat(tex, tex, **kw)


def emissive(name, color, strength=4.0):
    key = ("emit_" + name,)
    if key in _MATS:
        return _MATS[key]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    b = mat.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Emission Color"].default_value = (*color, 1)
    b.inputs["Emission Strength"].default_value = strength
    b.inputs["Roughness"].default_value = 0.4
    mat.diffuse_color = (*color, 1)
    _MATS[key] = mat
    return mat


# ---------------------------------------------------------------- 几何
_WORLD = {}


def _parent_origin(parent):
    return _WORLD.get(parent.name, Vector((0, 0, 0))) if parent is not None else Vector((0, 0, 0))


def box(name, size, loc, mat, parent=None, rot=None):
    bpy.ops.object.select_all(action="DESELECT")
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0))
    o = bpy.context.object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.location = Vector(loc) - _parent_origin(parent)
    if rot is not None:
        o.rotation_mode = "QUATERNION"
        o.rotation_quaternion = rot
    if parent is not None:
        o.parent = parent
        o.matrix_parent_inverse = Matrix.Identity(4)
    _WORLD[name] = Vector(loc)
    o.data.materials.append(mat)
    for p in o.data.polygons:
        p.use_smooth = False
    return o


def empty(name, loc, parent=None):
    e = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(e)
    e.empty_display_size = 0.3
    e.location = Vector(loc) - _parent_origin(parent)
    if parent is not None:
        e.parent = parent
        e.matrix_parent_inverse = Matrix.Identity(4)
    _WORLD[name] = Vector(loc)
    return e


def descendants(root):
    out = [root]
    for c in root.children_recursive:
        out.append(c)
    return out


def export_glb(root, filename):
    objs = descendants(root)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(MODEL_DIR, filename),
        use_selection=True,
        export_format="GLB",
        export_apply=True,
        export_animations=False,
        export_skins=False,
        export_yup=True,
        export_image_format="AUTO",
        export_cameras=False,
        export_lights=False,
        export_extras=False,
    )
    print(f"[export] {filename}  objects={len(objs)}")


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _MATS.clear()
    _WORLD.clear()


# ---------------------------------------------------------------- 机器人
def decal(name, size, loc, rot_mat, mat, parent=None):
    bpy.ops.object.select_all(action="DESELECT")
    bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 0, 0))
    o = bpy.context.object
    o.name = name
    o.scale = (size[0], size[1], 1.0)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.location = Vector(loc) - _parent_origin(parent)
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = rot_mat.to_quaternion()
    if parent is not None:
        o.parent = parent
        o.matrix_parent_inverse = Matrix.Identity(4)
    _WORLD[name] = Vector(loc)
    o.data.materials.append(mat)
    return o


def build_robot():
    white = M("white", rough=0.7)
    dark = M("dark", rough=0.8)
    green = M("green", rough=0.75)
    orange = M("orange", rough=0.85)
    orange_dark = M("orange_dark", rough=0.9)
    steel = M("steel", rough=0.35, metal=0.7)
    silver = M("panel_frame", rough=0.35, metal=0.5)
    rubber = M("rubber", rough=0.95)
    blue = M("blue", rough=0.45)
    red = M("red", rough=0.7)
    glass = M("glass", rough=0.2)
    logo = M("logo", rough=0.6)
    light = emissive("headlamp", (1.0, 0.9, 0.65), 4.0)
    beacon = emissive("beacon", (1.0, 0.55, 0.1), 6.0)

    root = empty("MMR_Root", (0, 0, 0))
    chassis = empty("Chassis", (0, 0, 0), root)

    # 履带 + 红色警示条
    for side, x in (("L", -1.05), ("R", 1.05)):
        box(f"Track_{side}", (0.7, 4.6, 1.0), (x, 0, 0.5), rubber, chassis)
        box(f"TrackStrip_{side}", (0.04, 1.7, 0.13), (x * 1.34, 0.45, 0.3), red, chassis)
        box(f"TrackFrame_{side}", (0.5, 4.2, 0.55), (x, 0, 0.55), dark, chassis)
    # 绿色裙边
    box("Skirt", (2.0, 4.2, 0.45), (0, 0, 1.16), green, chassis)
    for x in (-1.005, 1.005):
        for y in (-1.25, 0.0, 1.25):
            box(f"SkirtVent_{x}_{y}", (0.02, 0.55, 0.12), (x, y, 1.14), dark, chassis)
    # 白色车身
    box("BodyLowerTrim", (2.02, 4.02, 0.05), (0, 0, 1.41), dark, chassis)
    box("Body", (2.0, 4.0, 0.62), (0, 0, 1.71), white, chassis)
    for x in (-1.006, 1.006):
        for y in (-1.35, 0.0, 1.35):
            box(f"BodySeam_{x}_{y}", (0.012, 0.035, 0.56), (x, y, 1.7), dark, chassis)
        box(f"BodyHandle_{x}", (0.03, 0.3, 0.06), (x, 1.7, 1.62), dark, chassis)
    box("DeckPlate", (2.04, 3.95, 0.05), (0, 0, 2.015), silver, chassis)
    # 后部控制柜（与实机同位置的白色大柜）
    box("Cabinet", (2.0, 0.75, 1.15), (0, -2.75, 2.6), white, chassis)
    box("CabinetTrim", (2.02, 0.77, 0.05), (0, -2.75, 2.04), dark, chassis)
    box("CabinetTopTrim", (2.02, 0.77, 0.05), (0, -2.75, 3.16), dark, chassis)
    for y in (-3.128,):
        for z in (2.16, 2.28, 2.4):
            box(f"CabinetVent_{z}", (0.72, 0.015, 0.045), (0.35, y, z), dark, chassis)
    box("CabinetHandle", (0.12, 0.02, 0.03), (0.55, -3.135, 2.62), dark, chassis)
    box("CabinetBeacon", (0.14, 0.14, 0.16), (0.7, -2.75, 3.26), beacon, chassis)
    # 前部设备箱
    for x in (-0.55, 0.55):
        box(f"FrontBox_{x}", (0.7, 0.5, 0.3), (x, 1.55, 2.19), white, chassis)
        box(f"FrontBoxTrim_{x}", (0.72, 0.52, 0.04), (x, 1.55, 2.05), dark, chassis)
        box(f"FrontBoxLamp_{x}", (0.1, 0.03, 0.06), (x, 1.79, 2.26), light, chassis)
    # 前部传感器与保险杠
    box("SensorPod", (0.62, 0.14, 0.2), (0, 2.03, 2.1), dark, chassis)
    for x in (-0.17, 0.17):
        box(f"SensorLens_{x}", (0.1, 0.02, 0.09), (x, 2.11, 2.1), glass, chassis)
    box("FrontBumper", (2.04, 0.12, 0.22), (0, 2.03, 1.32), white, chassis)
    box("FrontBumperGreen", (1.4, 0.03, 0.06), (0, 2.1, 1.32), green, chassis)
    # 后部组件承载架（实机为料架/仓）
    box("LoadPlatform", (2.46, 1.55, 0.1), (0, -1.8, 2.09), dark, chassis)
    box("LoadPallet", (2.3, 1.3, 0.06), (0, -1.8, 2.17), M("wood", rough=1.0), chassis)
    for x in (-1.26, 1.26):
        box(f"LoadGuide_{x}", (0.08, 1.35, 0.5), (x, -1.8, 2.35), white, chassis)
    box("LoadGate", (2.46, 0.06, 0.3), (0, -1.06, 2.3), white, chassis)
    box("LoadGateTrim", (2.0, 0.02, 0.06), (0, -1.02, 2.36), green, chassis)
    # 品牌标识
    side_p = Matrix.Rotation(math.radians(90), 4, "Y") @ Matrix.Rotation(math.radians(90), 4, "Z")
    side_n = Matrix.Rotation(math.radians(-90), 4, "Y") @ Matrix.Rotation(math.radians(-90), 4, "Z")
    rx_p = Matrix.Rotation(math.radians(90), 4, "X")
    decal("LogoBody_R", (1.1, 0.22), (1.012, 0.35, 1.72), side_p, logo, chassis)
    decal("LogoBody_L", (1.1, 0.22), (-1.012, 0.35, 1.72), side_n, logo, chassis)
    decal("LogoCab_R", (0.9, 0.18), (1.012, -2.75, 2.72), side_p, logo, chassis)
    decal("LogoCab_L", (0.9, 0.18), (-1.012, -2.75, 2.72), side_n, logo, chassis)
    decal("LogoCabRear", (1.0, 0.2), (0, -3.132, 2.82), rx_p, logo, chassis)
    decal("LogoBox_R", (0.42, 0.084), (0.912, 1.55, 2.22), side_p, logo, chassis)
    decal("LogoBox_L", (0.42, 0.084), (-0.912, 1.55, 2.22), side_n, logo, chassis)

    # 转台：橙色防护布套基座
    turret = empty("Turret", (0, 0, 2.04), chassis)
    box("TurretBase", (1.52, 1.52, 0.1), (0, 0, 2.1), white, turret)
    box("BootBase", (1.25, 1.25, 0.22), (0, 0, 2.2), orange, turret)
    box("BootMid", (1.05, 1.05, 0.28), (0, 0, 2.44), orange, turret)
    box("BootTop", (0.85, 0.85, 0.28), (0, 0, 2.72), orange, turret)
    for z, w in ((2.32, 1.27), (2.56, 1.07), (2.84, 0.87)):
        box(f"BootBand_{z}", (w, w, 0.035), (0, 0, z), orange_dark, turret)
    box("TurretJoint", (0.68, 0.68, 0.32), (0, 0, 2.94), orange, turret)
    box("ArmPin", (0.78, 0.46, 0.28), (0, 0, 3.05), silver, turret)

    # 下臂（橙色布套 + 黑色管线）
    arm_lower = empty("ArmLower", (0, 0, 3.05), turret)
    box("LowerJoint", (0.72, 0.5, 0.72), (0, 0, 3.05), orange_dark, arm_lower)
    box("LowerLink", (0.55, 2.5, 0.55), (0, 1.25, 3.05), orange, arm_lower)
    for y in (0.35, 0.75, 1.15, 1.55, 1.95):
        box(f"LowerBand_{y}", (0.58, 0.06, 0.58), (0, y, 3.05), orange_dark, arm_lower)
    box("LowerHose", (0.07, 2.3, 0.07), (0.22, 1.25, 3.36), dark, arm_lower)
    box("LowerHoseClamp", (0.1, 0.14, 0.1), (0.22, 2.1, 3.34), steel, arm_lower)

    # 上臂
    arm_upper = empty("ArmUpper", (0, 2.5, 3.05), arm_lower)
    box("UpperJoint", (0.7, 0.5, 0.7), (0, 2.5, 3.05), orange_dark, arm_upper)
    box("UpperLink", (0.45, 2.3, 0.45), (0, 3.65, 3.05), orange, arm_upper)
    for y in (2.85, 3.25, 3.65, 4.05):
        box(f"UpperBand_{y}", (0.48, 0.06, 0.48), (0, y, 3.05), orange_dark, arm_upper)
    box("UpperHose", (0.06, 2.0, 0.06), (0.17, 3.65, 3.3), dark, arm_upper)

    # 腕部
    wrist = empty("Wrist", (0, 4.8, 3.05), arm_upper)
    box("WristJoint", (0.6, 0.6, 0.6), (0, 4.8, 3.05), orange_dark, wrist)
    box("WristSleeve", (0.36, 0.32, 0.36), (0, 5.02, 3.05), orange, wrist)
    for i in range(3):
        box(f"CableLoop_{i}", (0.07, 0.09, 0.07), (0.12 - i * 0.05, 5.1 + i * 0.06, 3.3), dark, wrist)

    # 吸盘架：银色框架 + 蓝色吸盘（绕组件法线旋转）
    effector_yaw = empty("EffectorYaw", (0, 5.8, 3.05), wrist)
    effector = empty("Effector", (0, 5.1, 3.05), effector_yaw)
    box("EffectorHinge", (0.55, 0.4, 0.25), (0, 5.16, 2.95), silver, effector)
    for i, y in enumerate((5.45, 6.15)):
        box(f"SuctionBeam_{i}", (3.0, 0.16, 0.16), (0, y, 2.87), silver, effector)
    for x in (-1.45, 1.45):
        box(f"SuctionRail_{x}", (0.16, 0.95, 0.16), (x, 5.8, 2.87), silver, effector)
    box("SuctionManifold", (0.8, 0.24, 0.16), (0, 5.8, 3.02), dark, effector)
    for xi, x in enumerate((-0.95, -0.35, 0.35, 0.95)):
        for yi, y in enumerate((5.45, 6.15)):
            box(f"CupStalk_{xi}{yi}", (0.06, 0.06, 0.12), (x, y, 2.72), silver, effector)
            box(f"Cup_{xi}{yi}", (0.22, 0.22, 0.18), (x, y, 2.605), blue, effector)
            box(f"CupTip_{xi}{yi}", (0.16, 0.16, 0.02), (x, y, 2.51), dark, effector)
    box("EffectorCam", (0.3, 0.3, 0.2), (0, 6.05, 3.0), dark, effector)
    box("EffectorLens", (0.12, 0.12, 0.02), (0, 6.05, 2.885), glass, effector)
    box("EffectorSensor", (0.25, 0.18, 0.16), (1.15, 6.2, 2.96), white, effector)
    box("EffectorLamp", (0.1, 0.1, 0.06), (-1.2, 6.2, 2.94), light, effector)
    grip = empty("Grip", (0, 5.8, 2.47), effector)

    return root


# ---------------------------------------------------------------- 组件 / 轨道
def build_panel_asset():
    reset_scene()
    frame_mat = M("panel_frame", rough=0.45, metal=0.4)
    cells = M("panel", rough=0.5)
    back = M("panel_back", rough=0.8)
    root = empty("PVPanel", (0, 0, 0))
    box("PanelFrame", (2.4, 1.2, 0.09), (0, 0, 0), frame_mat, root)
    box("PanelCells", (2.33, 1.13, 0.02), (0, 0, 0.05), cells, root)
    box("PanelBack", (2.36, 1.16, 0.02), (0, 0, -0.05), back, root)
    export_glb(root, "pv_panel.glb")


def _panel(name, center, tilt_deg, parent, cells, frame_mat):
    # 纵向铺装：长边 2.4m 沿坡面(X)，短边 1.2m 沿阵列方向(Y)，绕行轴 Y 倾斜
    rot = Matrix.Rotation(math.radians(tilt_deg), 4, "Y")
    q = rot.to_quaternion()
    box(name + "Frame", (2.4, 1.2, 0.09), center, frame_mat, parent, q)
    top = Vector(center) + rot @ Vector((0, 0, 0.05))
    box(name + "Cells", (2.28, 1.08, 0.02), tuple(top), cells, parent, q)


def build_row_asset():
    reset_scene()
    steel = M("steel", rough=0.4, metal=0.6)
    dark = M("dark", rough=0.8)
    cells = M("panel", rough=0.5)
    frame_mat = M("panel_frame", rough=0.45, metal=0.4)
    root = empty("ArrayRow", (0, 0, 0))
    # 轨道：row 沿 Y，纵向组件，20° 倾角
    for x, top in ((-0.55, 1.575), (0.55, 1.175)):
        box(f"Rail_{'W' if x < 0 else 'E'}", (0.16, 26.0, 0.14), (x, 1.0, top - 0.07), steel, root)
        for i, y in enumerate(np.arange(-12.0, 14.5, 2.5)):
            box(f"Post_{x}_{i}", (0.16, 0.16, top - 0.14), (x, float(y), (top - 0.14) / 2), dark, root)
    for i in range(18):
        y = -10.0 + i * 1.25
        _panel(f"Panel_{i}", (0.0, y, 1.42), 20.0, root, cells, frame_mat)
    export_glb(root, "array_row.glb")


def build_work_row_asset():
    reset_scene()
    steel = M("steel", rough=0.4, metal=0.6)
    dark = M("dark", rough=0.8)
    root = empty("WorkRow", (0, 0, 0))
    for x, top in ((-0.55, 1.575), (0.55, 1.175)):
        box(f"Rail_{'W' if x < 0 else 'E'}", (0.16, 40.0, 0.14), (x, 3.0, top - 0.07), steel, root)
        for i, y in enumerate(np.arange(-17.0, 23.5, 2.5)):
            box(f"Post_{x}_{i}", (0.16, 0.16, top - 0.14), (x, float(y), (top - 0.14) / 2), dark, root)
    export_glb(root, "work_row.glb")


def build_trailer_asset():
    reset_scene()
    green = M("green", rough=0.8)
    dark = M("dark", rough=0.9)
    steel = M("steel", rough=0.4, metal=0.6)
    yellow = M("yellow", rough=0.7)
    wood = M("wood", rough=1.0)
    cells = M("panel", rough=0.5)
    frame = M("panel_frame", rough=0.45, metal=0.4)
    root = empty("PanelTrailer", (0, 0, 0))
    box("TrailerBed", (2.7, 1.5, 0.14), (0, 0, 0.78), dark, root)
    box("TrailerFrame", (2.8, 1.6, 0.1), (0, 0, 0.9), green, root)
    for x in (-1.15, 1.15):
        for y in (-0.7, 0.7):
            box(f"Tire_{x}_{y}", (0.55, 0.38, 0.55), (x, y, 0.36), dark, root)
            box(f"Hub_{x}_{y}", (0.3, 0.42, 0.3), (x, y, 0.36), yellow, root)
    box("Hitch", (0.1, 1.2, 0.1), (0, 1.9, 0.55), steel, root)
    box("Jack", (0.1, 0.1, 0.45), (0, 2.3, 0.25), steel, root)
    rot = Matrix.Rotation(math.radians(-25), 4, "X")
    q = rot.to_quaternion()
    base_center = Vector((0, 0.1, 1.62))
    for i in range(4):
        c = base_center + rot @ Vector((0, 0, 0.13 * i))
        box(f"StackPanel_{i}", (2.4, 1.2, 0.09), tuple(c), frame, root, q)
        top = c + rot @ Vector((0, 0, 0.055))
        box(f"StackCells_{i}", (2.28, 1.08, 0.02), tuple(top), cells, root, q)
    for x in (-0.8, 0.8):
        c = base_center + rot @ Vector((x, 0, 0.3))
        box(f"Strap_{x}", (0.12, 1.3, 0.05), tuple(c), green, root, q)
    box("PalletBase", (2.5, 1.4, 0.1), (0, 0.1, 1.35), wood, root)
    for x in (-1.1, 1.1):
        box(f"PalletEnd_{x}", (0.12, 1.3, 0.5), (x, 0.1, 1.38), wood, root)
    export_glb(root, "panel_trailer.glb")


def build_props():
    # 沙块
    reset_scene()
    sand = M("sand", rough=1.0)
    root = empty("SandBlock", (0, 0, 0))
    box("SandCube", (1, 1, 1), (0, 0, 0.5), sand, root)
    export_glb(root, "sand_block.glb")

    # 云
    reset_scene()
    cloud = M("cloud", rough=1.0)
    root = empty("Cloud", (0, 0, 0))
    for i, (x, y, z, sx, sy, sz) in enumerate([
        (-1.6, 0, 0, 2.6, 1.6, 0.7), (0.2, 0.5, 0.35, 3.2, 2.0, 0.8),
        (1.9, -0.2, 0.1, 2.2, 1.4, 0.6), (0.3, -0.4, -0.35, 2.0, 1.2, 0.5),
        (-0.6, 0.9, 0.55, 1.6, 1.0, 0.45),
    ]):
        box(f"CloudPart_{i}", (sx, sy, sz), (x, y, z), cloud, root)
    export_glb(root, "cloud.glb")

    # 岩石
    reset_scene()
    rock = M("rock", rough=1.0)
    root = empty("Rock", (0, 0, 0))
    box("RockA", (1.6, 1.3, 0.8), (0, 0, 0.4), rock, root)
    box("RockB", (0.9, 1.0, 0.7), (0.7, 0.4, 0.75), rock, root)
    box("RockC", (0.7, 0.7, 0.5), (-0.6, -0.3, 0.6), rock, root)
    export_glb(root, "rock.glb")

    # 工人（原创方块工人，橙色反光背心 + 黄色安全帽）
    reset_scene()
    orange = M("orange_worker", rough=0.9)
    yellow = M("yellow", rough=0.7)
    skin = M("skin", rough=0.9)
    dark = M("dark", rough=0.9)
    root = empty("Worker", (0, 0, 0))
    box("LegL", (0.18, 0.18, 0.6), (-0.12, 0, 0.3), dark, root)
    box("LegR", (0.18, 0.18, 0.6), (0.12, 0, 0.3), dark, root)
    box("Torso", (0.46, 0.26, 0.55), (0, 0, 0.875), orange, root)
    box("VestStripe", (0.47, 0.27, 0.1), (0, 0, 0.95), yellow, root)
    box("ArmL", (0.13, 0.15, 0.5), (-0.3, 0, 0.83), orange, root)
    box("ArmR", (0.13, 0.15, 0.5), (0.3, 0, 0.83), orange, root)
    box("Head", (0.3, 0.3, 0.3), (0, 0, 1.32), skin, root)
    box("Helmet", (0.36, 0.36, 0.14), (0, 0, 1.54), yellow, root)
    box("HelmetBrim", (0.42, 0.42, 0.05), (0, 0.06, 1.47), yellow, root)
    export_glb(root, "worker.glb")


# ---------------------------------------------------------------- 预览渲染
def setup_preview(bg=(0.62, 0.78, 0.92), ground=True):
    scn = bpy.context.scene
    scn.render.engine = "BLENDER_EEVEE_NEXT"
    scn.eevee.taa_render_samples = 24
    scn.render.resolution_x = 960
    scn.render.resolution_y = 720
    scn.render.film_transparent = False
    world = bpy.data.worlds.new("PreviewWorld")
    world.use_nodes = True
    bg_node = world.node_tree.nodes.get("Background")
    bg_node.inputs[0].default_value = (*bg, 1)
    bg_node.inputs[1].default_value = 0.75
    scn.world = world

    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    bpy.context.collection.objects.link(sun)
    sun.data.energy = 3.2
    sun.data.angle = math.radians(8)
    sun.rotation_euler = (math.radians(52), math.radians(6), math.radians(-38))

    if ground:
        sand = M("sand", rough=1.0)
        box("PreviewGround", (80, 80, 0.2), (0, 0, -0.1), sand)

    cam_data = bpy.data.cameras.new("PreviewCam")
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    bpy.context.collection.objects.link(cam)
    scn.camera = cam
    cam.data.lens = 42
    return cam


def look_at(cam, loc, target):
    cam.location = loc
    d = Vector(target) - Vector(loc)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


def render_preview(cam, filename, loc, target):
    look_at(cam, loc, target)
    bpy.context.scene.render.filepath = os.path.join(PREVIEW_DIR, filename)
    bpy.ops.render.render(write_still=True)
    print("[preview]", filename)


def robot_previews(root):
    cam = setup_preview()
    render_preview(cam, "robot_three_quarter.png", (9.5, 9.0, 6.2), (0, 0.6, 1.9))
    render_preview(cam, "robot_front.png", (0, 12.5, 3.2), (0, 0, 2.0))
    render_preview(cam, "robot_side.png", (11.0, 1.0, 3.0), (0, 0, 2.0))


def scene_preview():
    # 轨道排 + 机器人 + 组件
    reset_scene()
    steel = M("steel", rough=0.4, metal=0.6)
    dark = M("dark", rough=0.8)
    cells = M("panel", rough=0.5)
    frame = M("panel_frame", rough=0.45, metal=0.4)
    row = empty("PreviewRow", (0, 0, 0))
    for x, top in ((-0.55, 1.575), (0.55, 1.175)):
        box(f"Rail_{x}", (0.16, 20.0, 0.14), (x, 2.0, top - 0.07), steel, row)
    for i, y in enumerate(np.arange(-8.0, 13.0, 1.25)):
        _panel(f"Panel_{i}", (0, float(y), 1.42), 20.0, row, cells, frame)
    robot = build_robot()
    robot.location = (4.4, 8.0, 0)
    cam = setup_preview()
    render_preview(cam, "scene_overview.png", (17.0, 16.0, 8.5), (2.0, 2.2, 3.2))


def main():
    make_textures()
    reset_scene()
    robot = build_robot()
    robot_previews(robot)
    export_glb(robot, "mmr_robot.glb")

    build_panel_asset()
    build_row_asset()
    build_work_row_asset()
    build_props()
    build_trailer_asset()
    scene_preview()

    print("[done] assets:", sorted(os.listdir(MODEL_DIR)))


if __name__ == "__main__":
    main()
