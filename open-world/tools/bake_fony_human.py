#!/usr/bin/env python3
"""Bake Fony's human mesh from the CC0 Quaternius Standard subset.

Reads assets/library/fony/quaternius (Universal Base Characters, FREE Standard
pack only) and writes a glTF skinned to the 17-bone HQ trick skeleton.

The paid Source pack is not used. Hair_Long is the only hair mesh; it is
recolored copper and deformed into messy spikes because the free pack has no
spiky groom. The superhero male body is the only male mesh in that pack, so
limb girth is scaled down around the existing skate bones instead of swapping
in a teen base.

Run from anywhere:
  python3 open-world/tools/bake_fony_human.py
"""

from __future__ import annotations

import json
import math
import struct
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets/library/fony/quaternius"
OUT = ROOT / "assets/library/fony/human"
PREVIEW = Path("/tmp/fony-preview")

BONES = [
    "Hips", "Spine", "Chest", "Neck", "Head",
    "ArmL", "ForeL", "HandL", "ArmR", "ForeR", "HandR",
    "LegL", "ShinL", "AnkleL", "LegR", "ShinR", "AnkleR",
]
PARENT = {
    "Hips": None,
    "Spine": "Hips", "Chest": "Spine", "Neck": "Chest", "Head": "Neck",
    "ArmL": "Chest", "ForeL": "ArmL", "HandL": "ForeL",
    "ArmR": "Chest", "ForeR": "ArmR", "HandR": "ForeR",
    "LegL": "Hips", "ShinL": "LegL", "AnkleL": "ShinL",
    "LegR": "Hips", "ShinR": "LegR", "AnkleR": "ShinR",
}
# Local rest translations. These match scripts/fony_mesh.gd exactly.
LOCAL = {
    "Hips": (0.0, 1.02, 0.0),
    "Spine": (0.0, 0.16, 0.0),
    "Chest": (0.0, 0.16, 0.0),
    "Neck": (0.0, 0.18, 0.0),
    "Head": (0.0, 0.10, 0.0),
    "ArmL": (-0.155, 0.07, 0.0),
    "ForeL": (0.0, -0.26, 0.0),
    "HandL": (0.0, -0.22, 0.0),
    "ArmR": (0.155, 0.07, 0.0),
    "ForeR": (0.0, -0.26, 0.0),
    "HandR": (0.0, -0.22, 0.0),
    "LegL": (-0.08, -0.04, 0.0),
    "ShinL": (0.0, -0.42, 0.0),
    "AnkleL": (0.0, -0.42, 0.0),
    "LegR": (0.08, -0.04, 0.0),
    "ShinR": (0.0, -0.42, 0.0),
    "AnkleR": (0.0, -0.42, 0.0),
}

# Girth (width, depth) in the bone frame, plus an along-bone scale.
# fit=True stretches the along axis onto the trick-skeleton bone length.
GROUP = {
    "Hips": dict(src="pelvis", child="spine_01", tgt="Hips", tgt_child="Spine", girth=(0.78, 0.80), fit=True),
    "Spine": dict(src="spine_01", child="spine_02", tgt="Spine", tgt_child="Chest", girth=(0.70, 0.76), fit=True),
    "Chest": dict(src="spine_03", child="neck_01", tgt="Chest", tgt_child="Neck", girth=(0.84, 1.02), fit=True),
    "Neck": dict(src="neck_01", child="Head", tgt="Neck", tgt_child="Head", girth=(0.92, 0.92), fit=True),
    "Head": dict(src="Head", child=None, tgt="Head", tgt_child=None, girth=(1.0, 1.0), fit=False, along=1.0),
    "ArmL": dict(src="upperarm_l", child="lowerarm_l", tgt="ArmL", tgt_child="ForeL", girth=(0.78, 0.78), fit=True),
    "ForeL": dict(src="lowerarm_l", child="hand_l", tgt="ForeL", tgt_child="HandL", girth=(0.80, 0.80), fit=True),
    "HandL": dict(src="hand_l", child=None, tgt="HandL", tgt_child=None, girth=(0.88, 0.88), fit=False, along=0.92),
    "ArmR": dict(src="upperarm_r", child="lowerarm_r", tgt="ArmR", tgt_child="ForeR", girth=(0.78, 0.78), fit=True),
    "ForeR": dict(src="lowerarm_r", child="hand_r", tgt="ForeR", tgt_child="HandR", girth=(0.80, 0.80), fit=True),
    "HandR": dict(src="hand_r", child=None, tgt="HandR", tgt_child=None, girth=(0.88, 0.88), fit=False, along=0.92),
    "LegL": dict(src="thigh_l", child="calf_l", tgt="LegL", tgt_child="ShinL", girth=(1.02, 1.00), fit=True),
    "ShinL": dict(src="calf_l", child="foot_l", tgt="ShinL", tgt_child="AnkleL", girth=(0.92, 0.94), fit=True),
    "AnkleL": dict(src="foot_l", child="ball_l", tgt="AnkleL", tgt_child=None, girth=(1.0, 1.0), fit=False, along=0.96),
    "LegR": dict(src="thigh_r", child="calf_r", tgt="LegR", tgt_child="ShinR", girth=(1.02, 1.00), fit=True),
    "ShinR": dict(src="calf_r", child="foot_r", tgt="ShinR", tgt_child="AnkleR", girth=(0.92, 0.94), fit=True),
    "AnkleR": dict(src="foot_r", child="ball_r", tgt="AnkleR", tgt_child=None, girth=(1.0, 1.0), fit=False, along=0.96),
}

SKIN = np.array([0.93, 0.71, 0.54], np.float32)
HOODIE = np.array([0.07, 0.07, 0.09], np.float32)
PANTS = np.array([0.34, 0.40, 0.20], np.float32)
PANTS_DARK = np.array([0.24, 0.29, 0.14], np.float32)
SHOE = np.array([0.78, 0.70, 0.56], np.float32)
SHOE_DARK = np.array([0.16, 0.12, 0.10], np.float32)
SOLE = np.array([0.22, 0.16, 0.12], np.float32)
RUST = np.array([0.72, 0.38, 0.18], np.float32)
RUST_DARK = np.array([0.42, 0.22, 0.12], np.float32)
COPPER = np.array([0.74, 0.36, 0.14], np.float32)
COPPER_DARK = np.array([0.36, 0.16, 0.07], np.float32)
FRONT = np.array([0.0, 0.0, -1.0])
UP = np.array([0.0, 1.0, 0.0])


def unit(v: np.ndarray) -> np.ndarray:
    n = float(np.linalg.norm(v))
    if n < 1e-8:
        return np.array([0.0, 1.0, 0.0])
    return v / n


def basis_along_front(along: np.ndarray, front_hint: np.ndarray = FRONT) -> np.ndarray:
    y = unit(along)
    f = front_hint - y * float(np.dot(front_hint, y))
    if float(np.linalg.norm(f)) < 1e-4:
        f = UP - y * float(np.dot(UP, y))
    if float(np.linalg.norm(f)) < 1e-4:
        f = np.array([1.0, 0.0, 0.0])
    z = unit(f)
    x = unit(np.cross(z, y))
    z = unit(np.cross(y, x))
    return np.column_stack([x, y, z])


def quat_to_mat(q) -> np.ndarray:
    x, y, z, w = q
    n = math.sqrt(x * x + y * y + z * z + w * w) or 1.0
    x, y, z, w = x / n, y / n, z / n, w / n
    return np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
    ], dtype=np.float64)


def load_gltf(path: Path):
    data = json.loads(path.read_text())
    blob = (path.parent / data["buffers"][0]["uri"]).read_bytes()
    return data, blob


def read_accessor(data, blob, index: int) -> np.ndarray:
    acc = data["accessors"][index]
    view = data["bufferViews"][acc["bufferView"]]
    comp = {5120: "b", 5121: "B", 5122: "h", 5123: "H", 5125: "I", 5126: "f"}[acc["componentType"]]
    ncomp = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[acc["type"]]
    count = acc["count"]
    width = struct.calcsize("<" + comp) * ncomp
    stride = view.get("byteStride", width)
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    out = np.empty((count, ncomp), dtype=np.float64 if comp == "f" else np.int32)
    for i in range(count):
        vals = struct.unpack_from("<" + comp * ncomp, blob, start + i * stride)
        out[i] = vals
    return out[:, 0] if ncomp == 1 else out


def node_locals(data):
    nodes = data["nodes"]
    mats = []
    for node in nodes:
        t = np.array(node.get("translation", [0, 0, 0]), dtype=np.float64)
        r = quat_to_mat(node.get("rotation", [0, 0, 0, 1]))
        s = np.array(node.get("scale", [1, 1, 1]), dtype=np.float64)
        m = np.eye(4)
        m[:3, :3] = r @ np.diag(s)
        m[:3, 3] = t
        mats.append(m)
    return mats


def world_nodes(data):
    nodes = data["nodes"]
    parent = {c: i for i, n in enumerate(nodes) for c in n.get("children", [])}
    local = node_locals(data)
    world = {}

    def rec(i):
        if i in world:
            return world[i]
        m = local[i]
        if i in parent:
            m = rec(parent[i]) @ m
        world[i] = m
        return m

    for i in range(len(nodes)):
        rec(i)
    return world


def skin_bones(data, blob):
    skin = data["skins"][0]
    names = [data["nodes"][j]["name"] for j in skin["joints"]]
    world = world_nodes(data)
    info = {}
    for name, node_index in zip(names, skin["joints"]):
        m = world[node_index]
        info[name] = {
            "origin": m[:3, 3].copy(),
            "x": m[:3, 0].copy(),
            "y": m[:3, 1].copy(),
            "z": m[:3, 2].copy(),
        }
    return names, info


def mirror_point(p: np.ndarray) -> np.ndarray:
    return np.array([-p[0], p[1], -p[2]], dtype=np.float64)


def mirror_vec(v: np.ndarray) -> np.ndarray:
    return np.array([-v[0], v[1], -v[2]], dtype=np.float64)


def fony_globals():
    origin = {}
    for name in BONES:
        local = np.array(LOCAL[name], dtype=np.float64)
        parent = PARENT[name]
        origin[name] = local if parent is None else origin[parent] + local
    return origin


def target_for(name: str) -> str:
    direct = {
        "root": "Hips",
        "pelvis": "Hips",
        "spine_01": "Spine",
        "spine_02": "Chest",
        "spine_03": "Chest",
        "neck_01": "Neck",
        "Head": "Head",
    }
    if name in direct:
        return direct[name]
    if name.endswith("_l"):
        side = "L"
    elif name.endswith("_r"):
        side = "R"
    else:
        raise KeyError(name)
    if name.startswith("clavicle") or name.startswith("upperarm"):
        return f"Arm{side}"
    if name.startswith("lowerarm"):
        return f"Fore{side}"
    if name.startswith("hand") or name.startswith(("index", "middle", "ring", "pinky", "thumb")):
        return f"Hand{side}"
    if name.startswith("thigh"):
        return f"Leg{side}"
    if name.startswith("calf"):
        return f"Shin{side}"
    if name.startswith("foot") or name.startswith("ball"):
        return f"Ankle{side}"
    raise KeyError(name)


def build_groups(bones: dict, fony: dict) -> dict:
    groups = {}
    for name, spec in GROUP.items():
        src = bones[spec["src"]]
        src_origin = mirror_point(src["origin"])
        if spec["child"]:
            child = bones[spec["child"]]
            along = mirror_point(child["origin"]) - src_origin
        else:
            along = mirror_vec(src["y"])
            if name.startswith("Ankle"):
                ball = bones[spec["src"].replace("foot", "ball")]
                along = mirror_point(ball["origin"]) - src_origin
            if name.startswith("Hand"):
                along = mirror_vec(src["y"])
        tgt_origin = fony[spec["tgt"]]
        if spec["tgt_child"]:
            tgt_along = fony[spec["tgt_child"]] - tgt_origin
        elif name.startswith("Hand"):
            tgt_along = np.array([0.0, -1.0, 0.0])
        elif name.startswith("Ankle"):
            tgt_along = np.array([0.0, -0.38, -1.0])
        elif name == "Head":
            tgt_along = np.array([0.0, 1.0, 0.0])
        else:
            tgt_along = np.array([0.0, 1.0, 0.0])
        src_len = float(np.linalg.norm(along)) or 1.0
        tgt_len = float(np.linalg.norm(tgt_along)) or src_len
        along_scale = (tgt_len / src_len) if spec["fit"] else float(spec.get("along", 1.0))
        gx, gz = spec["girth"]
        groups[name] = {
            "src_origin": src_origin,
            "tgt_origin": tgt_origin,
            "src_basis": basis_along_front(along),
            "tgt_basis": basis_along_front(tgt_along),
            "scale": np.array([gx, along_scale, gz], dtype=np.float64),
            "bone": BONES.index(spec["tgt"]),
        }
    return groups


def retarget(pos, joints, weights, bone_names, groups):
    count = len(pos)
    out = np.zeros((count, 3), dtype=np.float64)
    skin = np.zeros((count, len(BONES)), dtype=np.float64)
    mirrored = np.stack([-pos[:, 0], pos[:, 1], -pos[:, 2]], axis=1)
    for influence in range(4):
        w = weights[:, influence]
        active = w > 1e-5
        if not np.any(active):
            continue
        names = [bone_names[int(j)] for j in joints[active, influence]]
        # group per vertex
        for name in set(names):
            group_name = target_for(name)
            g = groups[group_name]
            mask_names = np.array([n == name for n in names])
            idx = np.flatnonzero(active)[mask_names]
            ww = w[idx][:, None]
            local = (mirrored[idx] - g["src_origin"]) @ g["src_basis"]
            local *= g["scale"]
            placed = g["tgt_origin"] + local @ g["tgt_basis"].T
            out[idx] += placed * ww
            skin[idx, g["bone"]] += w[idx]
    total = skin.sum(axis=1, keepdims=True)
    missing = total[:, 0] < 1e-5
    skin[missing, 0] = 1.0
    out[missing] = mirrored[missing]
    total = skin.sum(axis=1, keepdims=True)
    skin /= total
    out /= np.maximum(total, 1e-8)
    # pack 4 influences, strongest first
    order = np.argsort(-skin, axis=1)[:, :4]
    packed_w = np.take_along_axis(skin, order, axis=1)
    packed_w /= np.maximum(packed_w.sum(axis=1, keepdims=True), 1e-8)
    return out, order.astype(np.int32), packed_w.astype(np.float32)


def recompute_normals(pos: np.ndarray, idx: np.ndarray) -> np.ndarray:
    n = np.zeros_like(pos)
    v0 = pos[idx[:, 0]]
    v1 = pos[idx[:, 1]]
    v2 = pos[idx[:, 2]]
    face = np.cross(v1 - v0, v2 - v0)
    for k in range(3):
        np.add.at(n, idx[:, k], face)
    length = np.linalg.norm(n, axis=1, keepdims=True)
    length[length < 1e-8] = 1.0
    return n / length


def load_mesh(data, blob, mesh_index: int):
    prim = data["meshes"][mesh_index]["primitives"][0]
    attrs = prim["attributes"]
    pos = read_accessor(data, blob, attrs["POSITION"]).astype(np.float64)
    nrm = read_accessor(data, blob, attrs["NORMAL"]).astype(np.float64)
    uv = read_accessor(data, blob, attrs["TEXCOORD_0"]).astype(np.float64)
    joints = read_accessor(data, blob, attrs["JOINTS_0"]).astype(np.int32)
    weights = read_accessor(data, blob, attrs["WEIGHTS_0"]).astype(np.float64)
    idx = read_accessor(data, blob, prim["indices"]).astype(np.int32)
    return pos, nrm, uv, joints, weights, idx


def sample_tex(image: np.ndarray, uv: np.ndarray) -> np.ndarray:
    h, w, _ = image.shape
    x = np.clip(uv[:, 0], 0, 0.999) * (w - 1)
    y = np.clip(1.0 - uv[:, 1], 0, 0.999) * (h - 1)
    x0 = np.floor(x).astype(np.int32)
    y0 = np.floor(y).astype(np.int32)
    return image[y0, x0]


def toon_face(color: np.ndarray) -> np.ndarray:
    luma = color.mean(axis=1, keepdims=True)
    mixed = color * 0.62 + SKIN * 0.38
    # Keep painted features: brows, lashes, mouth line.
    dark = luma < 0.34
    mixed = np.where(dark, color * 0.9, mixed)
    red = (color[:, 0] > color[:, 1] * 1.25) & (color[:, 0] > 0.35) & (luma[:, 0] < 0.62)
    lips = np.array([0.72, 0.38, 0.36], np.float32)
    mixed[red] = lips * 0.65 + color[red] * 0.35
    steps = np.round(np.clip(mixed, 0, 1) * 10.0) / 10.0
    return steps.astype(np.float32)


def region_colors(pos, weights, uv, albedo):
    bone = {name: i for i, name in enumerate(BONES)}
    w = lambda *names: sum(weights[:, bone[n]] for n in names)
    head = w("Head")
    neck = w("Neck")
    hands = w("HandL", "HandR")
    arms = w("ArmL", "ArmR", "ForeL", "ForeR")
    legs = w("LegL", "LegR", "ShinL", "ShinR")
    ankles = w("AnkleL", "AnkleR")
    hips = w("Hips")
    sampled = sample_tex(albedo, uv)
    luma = sampled.mean(axis=1, keepdims=True)
    out = np.zeros((len(pos), 3), np.float32)
    # Default hoodie, including the neck the jacket leaves open.
    out[:] = HOODIE
    skin_mask = (head > 0.42) | (hands > 0.38)
    # Wrists just above the hands stay skin so the cuff reads as a hoodie sleeve.
    wrist = (arms > 0.45) & (hands > 0.12) & (pos[:, 1] < 1.05)
    skin_mask = skin_mask | wrist
    face = (head > 0.5) & (pos[:, 2] < -0.01) & (pos[:, 1] > 1.48) & (pos[:, 1] < 1.78)
    out[skin_mask] = (SKIN * (0.9 + 0.18 * luma[skin_mask])).clip(0, 1)
    out[face] = toon_face(sampled[face])
    pants = (legs > 0.35) | ((hips > 0.35) & (pos[:, 1] < 1.12))
    pants = pants & ~skin_mask
    tone = PANTS * (0.9 + 0.18 * luma)
    # Cargo pocket blocks on the outer thigh.
    for leg_name, sign in (("LegL", -1.0), ("LegR", 1.0)):
        leg_w = weights[:, bone[leg_name]]
        outer = (pos[:, 0] * sign) > (0.08 + 0.045)
        pocket = (leg_w > 0.4) & outer & (pos[:, 1] > 0.62) & (pos[:, 1] < 0.86) & (pos[:, 2] < 0.03)
        tone[pocket] = PANTS_DARK
    waist = pants & (pos[:, 1] > 1.02)
    tone[waist] = PANTS_DARK
    out[pants] = tone[pants].clip(0, 1)
    shoes = ankles > 0.45
    shoe_col = np.repeat(SHOE[None, :], len(pos), axis=0)
    for ankle_name in ("AnkleL", "AnkleR"):
        aw = weights[:, bone[ankle_name]]
        origin = fony_globals()[ankle_name]
        along = -(pos[:, 2] - origin[2])
        stripe = ((along > 0.035) & (along < 0.052)) | ((along > 0.07) & (along < 0.086))
        use = (aw > 0.45) & stripe
        shoe_col[use] = SHOE_DARK
        sole = (aw > 0.45) & (pos[:, 1] < origin[1] - 0.045)
        shoe_col[sole] = SOLE
        toe = (aw > 0.45) & (along > 0.10)
        shoe_col[toe] = SHOE * 0.82
    out[shoes] = shoe_col[shoes]
    return out


def rasterize(uv: np.ndarray, idx: np.ndarray, colors: np.ndarray, size: int) -> np.ndarray:
    image = np.zeros((size, size, 3), np.float32)
    covered = np.zeros((size, size), np.uint8)
    u = np.clip(uv[:, 0], 0, 1) * (size - 1)
    v = np.clip(uv[:, 1], 0, 1) * (size - 1)
    for tri in idx:
        p = np.stack([u[tri], v[tri]], axis=1)
        c = colors[tri]
        minx = max(int(np.floor(p[:, 0].min())), 0)
        maxx = min(int(np.ceil(p[:, 0].max())), size - 1)
        miny = max(int(np.floor(p[:, 1].min())), 0)
        maxy = min(int(np.ceil(p[:, 1].max())), size - 1)
        if maxx <= minx or maxy <= miny:
            continue
        xs = np.arange(minx, maxx + 1)
        ys = np.arange(miny, maxy + 1)
        gx, gy = np.meshgrid(xs, ys)
        x = gx.astype(np.float32) + 0.5
        y = gy.astype(np.float32) + 0.5
        v0, v1, v2 = p[0], p[1], p[2]
        den = (v1[1] - v2[1]) * (v0[0] - v2[0]) + (v2[0] - v1[0]) * (v0[1] - v2[1])
        if abs(float(den)) < 1e-8:
            continue
        a = ((v1[1] - v2[1]) * (x - v2[0]) + (v2[0] - v1[0]) * (y - v2[1])) / den
        b = ((v2[1] - v0[1]) * (x - v2[0]) + (v0[0] - v2[0]) * (y - v2[1])) / den
        g = 1.0 - a - b
        inside = (a >= -0.01) & (b >= -0.01) & (g >= -0.01)
        if not np.any(inside):
            continue
        col = a[..., None] * c[0] + b[..., None] * c[1] + g[..., None] * c[2]
        yy = (size - 1) - gy
        image[yy[inside], gx[inside]] = col[inside]
        covered[yy[inside], gx[inside]] = 1
    # Pad a 1px skirt so the GPU filter does not pull black seams.
    grown = image.copy()
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dx == 0 and dy == 0:
                continue
            shifted_c = np.roll(np.roll(covered, dy, axis=0), dx, axis=1)
            shifted_i = np.roll(np.roll(image, dy, axis=0), dx, axis=1)
            fill = (covered == 0) & (shifted_c == 1)
            grown[fill] = shifted_i[fill]
    return grown


def spike_hair(pos: np.ndarray, head: np.ndarray) -> np.ndarray:
    """Lift Hair_Long into messy spikes while keeping a full scalp of volume.

    The free pack has no spiky groom. Each vertex keeps its distance from the
    skull and its triangle connectivity. Hanging lengths rotate upward; a few
    azimuth clumps are pushed further out so the crown is uneven.
    """
    center = head + np.array([0.0, 0.05, 0.0])
    d = pos - center
    r = np.clip(np.linalg.norm(d, axis=1), 1e-5, None)
    elev = np.arcsin(np.clip(d[:, 1] / r, -1.0, 1.0))
    az = np.arctan2(d[:, 0], d[:, 2])
    clump = np.sin(az * 5.0 + 0.4) ** 2
    # Cover the scalp. Only the outer clumps become tall spikes.
    lifted = np.where(elev < 0.35, 0.45 + 0.35 * clump, elev * 0.65 + 0.28)
    front = np.abs(az) > 2.15
    lifted = np.where(front, np.minimum(lifted, 0.38), lifted)
    lifted = np.clip(lifted, -0.1, 1.2)
    new_r = np.clip(r * 0.95 + 0.025 * clump, 0.09, 0.23)
    new_r = np.where(clump > 0.72, new_r * 1.18, new_r)
    ce = np.cos(lifted)
    direction = np.stack((np.sin(az) * ce, np.sin(lifted), np.cos(az) * ce), axis=1)
    out = center + direction * new_r[:, None]
    rel = out - head
    over_eyes = (rel[:, 2] < -0.05) & (rel[:, 1] < 0.08)
    rel[over_eyes, 1] += 0.06
    rel[over_eyes, 2] *= 0.7
    return head + rel


def baggy_legs(pos: np.ndarray, weights: np.ndarray, fony: dict) -> None:
    bone = {name: i for i, name in enumerate(BONES)}
    for leg, shin in (("LegL", "ShinL"), ("LegR", "ShinR")):
        w = weights[:, bone[leg]] + weights[:, bone[shin]]
        mask = w > 0.35
        if not np.any(mask):
            continue
        axis_x = fony[leg][0]
        dx = pos[mask, 0] - axis_x
        dz = pos[mask, 2]
        horiz = np.sqrt(dx * dx + dz * dz)
        horiz = np.clip(horiz, 1e-4, None)
        push = 0.02 * np.clip(w[mask], 0, 1)
        pos[mask, 0] += dx / horiz * push
        pos[mask, 2] += dz / horiz * push


def seat_soles(pos: np.ndarray, weights: np.ndarray, fony: dict) -> None:
    bone = {name: i for i, name in enumerate(BONES)}
    for ankle in ("AnkleL", "AnkleR"):
        index = bone[ankle]
        w = weights[:, index]
        mask = w > 0.55
        if not np.any(mask):
            continue
        desired = fony[ankle][1] - 0.065
        lowest = float(pos[mask, 1].min())
        delta = desired - lowest
        pos[:, 1] += delta * np.clip(w * 1.25, 0.0, 1.0)


def jacket_from_body(pos, nrm, uv, joints, weights, idx):
    bone = {name: i for i, name in enumerate(BONES)}
    keep = []
    for tri in idx:
        c = pos[tri].mean(axis=0)
        ww = weights[tri].mean(axis=0)
        arm = ww[bone["ArmL"]] + ww[bone["ArmR"]] + ww[bone["ForeL"]] + ww[bone["ForeR"]]
        torso = ww[bone["Chest"]] + ww[bone["Spine"]] + ww[bone["Hips"]] + ww[bone["Neck"]]
        hand = ww[bone["HandL"]] + ww[bone["HandR"]]
        leg = ww[bone["LegL"]] + ww[bone["LegR"]] + ww[bone["ShinL"]] + ww[bone["ShinR"]] + ww[bone["AnkleL"]] + ww[bone["AnkleR"]]
        head = ww[bone["Head"]]
        if hand > 0.4 or leg > 0.5 or head > 0.7:
            continue
        upper = 0.98 < c[1] < 1.58
        if upper and (torso + arm) > 0.12:
            keep.append(tri)
    if not keep:
        raise RuntimeError("jacket selection was empty")
    print("jacket tris", len(keep), "of", len(idx))
    tris = np.array(keep, dtype=np.int32)
    used = np.unique(tris)
    remap = -np.ones(len(pos), dtype=np.int32)
    remap[used] = np.arange(len(used))
    base = pos[used]
    outward = np.stack((base[:, 0], np.zeros(len(base)), base[:, 2]), axis=1)
    outward_len = np.linalg.norm(outward, axis=1, keepdims=True)
    outward_len[outward_len < 1e-4] = 1.0
    outward = outward / outward_len
    # Push out from the spine so creases do not fold the shell back into the body.
    jpos = base + outward * 0.02 + nrm[used] * 0.008
    jn = nrm[used].copy()
    juv = uv[used].copy()
    jj = joints[used].copy()
    jw = weights[used].copy()
    jidx = remap[tris]
    # Worn rust, darker at the hem, cuffs, and the center zipper.
    color = np.repeat(RUST[None, :], len(jpos), axis=0)
    hem = np.clip((1.12 - jpos[:, 1]) / 0.12, 0, 1)
    cuff = np.clip((1.08 - jpos[:, 1]) / 0.10, 0, 1) * (
        (jpos[:, 0] < -0.12) | (jpos[:, 0] > 0.12)
    ).astype(np.float64)
    zipper = np.clip(1.0 - np.abs(jpos[:, 0]) / 0.012, 0, 1) * (jpos[:, 2] < -0.05)
    wear = 0.06 * np.sin(jpos[:, 0] * 37.0 + jpos[:, 1] * 21.0)
    mix = np.clip(hem * 0.4 + cuff * 0.35 + zipper * 0.28, 0, 1)
    color = RUST * (1.0 - mix[:, None]) + RUST_DARK * mix[:, None]
    color *= (1.0 + wear[:, None])
    return jpos, jn, juv, jj, jw, jidx, np.clip(color, 0, 1).astype(np.float32)


def empty_mesh():
    return {
        "pos": [],
        "nrm": [],
        "uv": [],
        "joints": [],
        "weights": [],
        "idx": [],
    }


def add_vert(mesh, p, n, uv, bones, weights):
    mesh["pos"].append(p)
    mesh["nrm"].append(unit(np.array(n, dtype=np.float64)))
    mesh["uv"].append(uv)
    jb = list(bones) + [0, 0, 0, 0]
    jw = list(weights) + [0, 0, 0, 0]
    mesh["joints"].append(jb[:4])
    s = sum(jw[:4]) or 1.0
    mesh["weights"].append([jw[i] / s for i in range(4)])
    return len(mesh["pos"]) - 1


def add_tri(mesh, a, b, c):
    mesh["idx"].extend([a, b, c])


def finalize(mesh):
    return (
        np.array(mesh["pos"], np.float64),
        np.array(mesh["nrm"], np.float64),
        np.array(mesh["uv"], np.float64),
        np.array(mesh["joints"], np.int32),
        np.array(mesh["weights"], np.float32),
        np.array(mesh["idx"], np.int32).reshape(-1, 3),
    )


def add_box(mesh, center, size, x_axis, y_axis, z_axis, bones, weights):
    center = np.array(center, dtype=np.float64)
    hx, hy, hz = size
    x_axis = unit(np.array(x_axis, dtype=np.float64))
    y_axis = unit(np.array(y_axis, dtype=np.float64))
    z_axis = unit(np.array(z_axis, dtype=np.float64))
    faces = [
        (z_axis, [(-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)]),
        (-z_axis, [(-1, -1, -1), (-1, 1, -1), (1, 1, -1), (1, -1, -1)]),
        (x_axis, [(1, -1, -1), (1, 1, -1), (1, 1, 1), (1, -1, 1)]),
        (-x_axis, [(-1, -1, -1), (-1, -1, 1), (-1, 1, 1), (-1, 1, -1)]),
        (y_axis, [(-1, 1, -1), (-1, 1, 1), (1, 1, 1), (1, 1, -1)]),
        (-y_axis, [(-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1)]),
    ]
    for normal, corners in faces:
        ids = []
        for cx, cy, cz in corners:
            p = center + x_axis * (cx * hx) + y_axis * (cy * hy) + z_axis * (cz * hz)
            ids.append(add_vert(mesh, p, normal, ((cx + 1) * 0.5, (cy + 1) * 0.5), bones, weights))
        add_tri(mesh, ids[0], ids[1], ids[2])
        add_tri(mesh, ids[0], ids[2], ids[3])


def add_sphere(mesh, center, radii, bones, weights, seg=14, rings=8):
    center = np.array(center, dtype=np.float64)
    radii = np.array(radii, dtype=np.float64)
    grid = []
    for iy in range(rings + 1):
        v = iy / rings
        phi = math.pi * (v - 0.5)
        row = []
        for ix in range(seg):
            u = ix / seg
            theta = u * math.tau
            n = np.array([math.cos(theta) * math.cos(phi), math.sin(phi), math.sin(theta) * math.cos(phi)])
            p = center + n * radii
            row.append(add_vert(mesh, p, n, (u, v), bones, weights))
        grid.append(row)
    for iy in range(rings):
        for ix in range(seg):
            a = grid[iy][ix]
            b = grid[iy][(ix + 1) % seg]
            c = grid[iy + 1][(ix + 1) % seg]
            d = grid[iy + 1][ix]
            add_tri(mesh, a, d, b)
            add_tri(mesh, b, d, c)


def add_hood(mesh, fony):
    """A short cowl on the shoulders. The hood stays down, behind the neck."""
    neck = fony["Neck"]
    bone = {name: i for i, name in enumerate(BONES)}
    bones = [bone["Neck"], bone["Head"], bone["Chest"]]
    weights = [0.5, 0.2, 0.3]
    center = neck + np.array([0.0, -0.02, 0.03])
    major = 0.09
    minor = 0.038
    around = 18
    tube = 8
    ids = []
    for ia in range(around):
        u = ia / (around - 1)
        theta = math.radians(25 + u * 130)  # back arc: +Z is behind the character
        row = []
        ring_center = center + np.array([math.cos(theta) * major, 0.03 + 0.02 * math.sin(theta), math.sin(theta) * major * 0.85])
        for ib in range(tube):
            v = ib / tube
            phi = v * math.tau
            radial = np.array([
                math.cos(theta) * math.cos(phi),
                math.sin(phi),
                math.sin(theta) * math.cos(phi),
            ])
            p = ring_center + radial * minor
            row.append(add_vert(mesh, p, radial, (u, v), bones, weights))
        ids.append(row)
    for ia in range(around - 1):
        for ib in range(tube):
            a = ids[ia][ib]
            b = ids[ia][(ib + 1) % tube]
            c = ids[ia + 1][(ib + 1) % tube]
            d = ids[ia + 1][ib]
            add_tri(mesh, a, b, d)
            add_tri(mesh, b, c, d)


def surface_point(pos, nrm, weights, point, bone_index, forward=True, y_pad=0.08):
    w = weights[:, bone_index] if bone_index is not None else np.ones(len(pos))
    dist = np.linalg.norm(pos - point, axis=1)
    score = dist + (1.0 - w) * 0.35 + np.abs(pos[:, 1] - point[1]) * 1.5
    if forward:
        # Prefer the face of the cloth, which is -Z on this skeleton.
        score = score + np.clip(pos[:, 2] - point[2], 0, None) * 3.0
    score = np.where(np.abs(pos[:, 1] - point[1]) > y_pad, score + 2.0, score)
    near = score < (np.min(score) + 0.08)
    if not np.any(near):
        near = score <= np.min(score)
    if forward:
        i = int(np.flatnonzero(near)[np.argmin(pos[near, 2])])
    else:
        i = int(np.argmin(score))
    normal = nrm[i].copy()
    if forward and normal[2] > 0:
        normal[2] *= -1
    if not forward and float(np.dot(normal, point - pos[i])) < 0:
        normal = -normal
    return pos[i] + unit(normal) * 0.01, unit(normal)


def smooth_mesh(pos: np.ndarray, idx: np.ndarray, iters=5, amount=0.55) -> np.ndarray:
    pos = pos.copy()
    for _ in range(iters):
        acc = np.zeros_like(pos)
        cnt = np.zeros(len(pos))
        for k in range(3):
            np.add.at(acc, idx[:, k], pos[idx[:, (k + 1) % 3]] + pos[idx[:, (k + 2) % 3]])
            np.add.at(cnt, idx[:, k], 2.0)
        avg = acc / np.maximum(cnt[:, None], 1.0)
        pos = pos * (1.0 - amount) + avg * amount
    return pos


def shoe_shells(pos, nrm, weights, idx, fony):
    """Inflated foot shells so the bare superhero toes read as skate shoes."""
    shells = {}
    bone = {name: i for i, name in enumerate(BONES)}
    for ankle, name in (("AnkleL", "ShoeL"), ("AnkleR", "ShoeR")):
        w = weights[:, bone[ankle]]
        keep = [tri for tri in idx if float(w[tri].mean()) > 0.5]
        if not keep:
            continue
        tris = np.array(keep, dtype=np.int32)
        used = np.unique(tris)
        remap = -np.ones(len(pos), dtype=np.int32)
        remap[used] = np.arange(len(used))
        spos = pos[used] + nrm[used] * 0.01
        suv = np.zeros((len(used), 2))
        sj = np.zeros((len(used), 4), np.int32)
        sj[:, 0] = bone[ankle]
        sw = np.zeros((len(used), 4), np.float32)
        sw[:, 0] = 1.0
        sidx = remap[tris]
        sn = recompute_normals(spos, sidx)
        # A toe cap covers the separated toes.
        mesh = empty_mesh()
        for i in range(len(spos)):
            add_vert(mesh, spos[i], sn[i], suv[i], [bone[ankle]], [1.0])
        for tri in sidx:
            add_tri(mesh, int(tri[0]), int(tri[1]), int(tri[2]))
        origin = fony[ankle]
        toe = origin + np.array([0.0, -0.02, -0.15])
        add_box(mesh, toe, (0.048, 0.032, 0.07), (1, 0, 0), (0, 1, 0), (0, 0, -1), [bone[ankle]], [1.0])
        shells[name] = finalize(mesh)
        stripes = empty_mesh()
        origin = fony[ankle]
        for along in (-0.075, -0.115):
            add_box(
                stripes,
                origin + np.array([0.0, 0.0, along]),
                (0.052, 0.016, 0.01),
                (1, 0, 0), (0, 1, 0), (0, 0, -1),
                [bone[ankle]], [1.0],
            )
        shells["Stripe" + name[-1]] = finalize(stripes)
    return shells


def props_from_body(pos, nrm, weights, fony, cloth_pos, cloth_nrm):
    bone = {name: i for i, name in enumerate(BONES)}
    parts = {}

    def part(name, bones, wts):
        mesh = empty_mesh()
        parts[name] = (mesh, bones, wts)
        return mesh

    # Knee pads sit on the front of the knee. Character-left (PadL) is more faded.
    for leg, shin, name in (("LegL", "ShinL", "PadL"), ("LegR", "ShinR", "PadR")):
        knee = fony[shin] + np.array([0.0, 0.015, -0.06])
        point, normal = surface_point(pos, nrm, weights, knee, bone[shin], forward=True)
        center = point + np.array([0.0, 0.0, -0.012])
        mesh = part(name, [bone[shin], bone[leg]], [0.62, 0.38])
        add_sphere(mesh, center, (0.062, 0.05, 0.022), [bone[shin], bone[leg]], [0.62, 0.38], seg=14, rings=8)

    # Cloth pieces stick to the jacket shell, not the skin underneath it.
    # Magenta patch is on the character's right chest (viewer's left, front view).
    patch_point = np.array([0.055, 1.38, -0.2])
    point, normal = surface_point(cloth_pos, cloth_nrm, None, patch_point, None, forward=True)
    mesh = part("Patch", [bone["Chest"]], [1.0])
    add_box(mesh, point + np.array([0.0, 0.0, -0.008]), (0.028, 0.046, 0.006), (1, 0, 0), (0, 1, 0), (0, 0, -1), [bone["Chest"]], [1.0])

    tape_specs = [
        ("TapeChest", np.array([-0.05, 1.40, -0.2]), bone["Chest"], (0.042, 0.012, 0.004), (0.95, 0.22, 0)),
        ("TapeArmL", fony["ForeL"] + np.array([0.0, -0.05, -0.08]), bone["ForeL"], (0.05, 0.012, 0.004), (0.35, 0.2, 0)),
        ("TapeArmR", fony["ForeR"] + np.array([0.0, -0.08, -0.08]), bone["ForeR"], (0.048, 0.012, 0.004), (0.4, -0.1, 0)),
    ]
    for name, guess, bone_index, size, axis in tape_specs:
        point, normal = surface_point(cloth_pos, cloth_nrm, None, guess, None, forward=True)
        side = unit(np.array(axis, dtype=np.float64))
        up = unit(np.cross(np.array([0.0, 0.0, -1.0]), side))
        mesh = part(name, [bone_index], [1.0])
        add_box(mesh, point + np.array([0.0, 0.0, -0.008]), size, side, up, (0, 0, -1), [bone_index], [1.0])

    # Grey shoulder patches. Character-left is larger, the way the sheet reads.
    for name, arm, scale in (("ShoulderL", "ArmL", (0.05, 0.038, 0.007)), ("ShoulderR", "ArmR", (0.036, 0.03, 0.006))):
        guess = fony[arm] + np.array([0.0, 0.045, -0.04])
        point, _normal = surface_point(cloth_pos, cloth_nrm, None, guess, None, forward=False)
        mesh = part(name, [bone[arm], bone["Chest"]], [0.75, 0.25])
        add_box(mesh, point + np.array([0.0, 0.012, -0.006]), scale, (1, 0, 0), (0, 1, 0), (0, 0, -1), [bone[arm], bone["Chest"]], [0.75, 0.25])

    # Cargo pockets, outer thigh.
    for name, leg, sign in (("PocketL", "LegL", -1.0), ("PocketR", "LegR", 1.0)):
        guess = fony[leg] + np.array([sign * 0.045, -0.18, -0.07])
        point, _normal = surface_point(pos, nrm, weights, guess, bone[leg], forward=True, y_pad=0.1)
        mesh = part(name, [bone[leg]], [1.0])
        add_box(mesh, point + np.array([sign * 0.01, 0.0, -0.008]), (0.026, 0.04, 0.008), (sign, 0, 0), (0, 1, 0), (0, 0, -1), [bone[leg]], [1.0])
    return parts


def clean_eye(path: Path) -> Image.Image:
    image = np.array(Image.open(path).convert("RGBA")).astype(np.float32) / 255.0
    rgb = image[:, :, :3]
    # The packed eye atlas is an iris surrounded by eyelid skin. The eyeball
    # mesh should read as sclera plus a brown iris, not a red disc.
    red = (rgb[:, :, 0] > 0.42) & (rgb[:, :, 0] > rgb[:, :, 1] * 1.12) & (rgb[:, :, 1] < 0.62)
    rgb[red] = np.array([0.93, 0.94, 0.96], np.float32)
    # Posterize slightly so the iris stays cel.
    rgb = np.round(np.clip(rgb, 0, 1) * 14.0) / 14.0
    return Image.fromarray((rgb * 255).astype(np.uint8), "RGB")


def tint_hair(path: Path) -> Image.Image:
    image = np.array(Image.open(path).convert("RGB")).astype(np.float32) / 255.0
    luma = image.mean(axis=2, keepdims=True)
    tint = COPPER_DARK + (COPPER - COPPER_DARK) * np.clip(luma * 1.15, 0, 1)
    tint = np.round(np.clip(tint, 0, 1) * 12.0) / 12.0
    small = Image.fromarray((tint * 255).astype(np.uint8), "RGB")
    return small.resize((1024, 1024), Image.Resampling.LANCZOS)


class Buffer:
    def __init__(self):
        self.blob = bytearray()
        self.views = []
        self.accessors = []

    def pad(self):
        while len(self.blob) % 4:
            self.blob.append(0)

    def add_array(self, array: np.ndarray, gl_type: str, component: int, target: int | None, with_bounds=False):
        self.pad()
        raw = np.ascontiguousarray(array)
        data = raw.tobytes()
        view = {"buffer": 0, "byteOffset": len(self.blob), "byteLength": len(data)}
        if target:
            view["target"] = target
        self.blob.extend(data)
        acc = {
            "bufferView": len(self.views),
            "componentType": component,
            "count": int(raw.shape[0]),
            "type": gl_type,
        }
        if with_bounds:
            acc["min"] = raw.reshape(raw.shape[0], -1).min(axis=0).astype(float).tolist()
            acc["max"] = raw.reshape(raw.shape[0], -1).max(axis=0).astype(float).tolist()
        self.views.append(view)
        self.accessors.append(acc)
        return len(self.accessors) - 1


def write_gltf(meshes: dict, images: dict, path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    buf = Buffer()
    fony = fony_globals()
    # Column-major inverse bind matrices, one per bone, in BONES order.
    inv_binds = []
    for name in BONES:
        parent = PARENT[name]
        local = np.eye(4)
        local[:3, 3] = LOCAL[name]
        if parent is None:
            global_m = local
        else:
            # Rebuild globals in the same loop order.
            global_m = None
        inv_binds.append(local)  # placeholder replaced below
    globals_m = {}
    for name in BONES:
        local = np.eye(4)
        local[:3, 3] = LOCAL[name]
        parent = PARENT[name]
        globals_m[name] = local if parent is None else globals_m[parent] @ local
    inv = []
    for name in BONES:
        inv.append(np.linalg.inv(globals_m[name]).T.reshape(-1, order="F"))
        # numpy reshape order F after transpose is messy. Store column-major explicitly.
    mats = np.stack([np.linalg.inv(globals_m[name]).flatten(order="F") for name in BONES])
    ibm = buf.add_array(mats.astype(np.float32), "MAT4", 5126, None)

    primitives_per_mesh = []
    material_index = {}
    textures = list(images.keys())
    for name, (pos, nrm, uv, joints, weights, idx) in meshes.items():
        a_pos = buf.add_array(pos.astype(np.float32), "VEC3", 5126, 34962, True)
        a_nrm = buf.add_array(nrm.astype(np.float32), "VEC3", 5126, 34962)
        a_uv = buf.add_array(uv.astype(np.float32), "VEC2", 5126, 34962)
        a_j = buf.add_array(joints.astype(np.uint16), "VEC4", 5123, 34962)
        a_w = buf.add_array(weights.astype(np.float32), "VEC4", 5126, 34962)
        flat = idx.astype(np.uint32).reshape(-1)
        a_i = buf.add_array(flat, "SCALAR", 5125, 34963)
        primitives_per_mesh.append({
            "name": name,
            "attributes": {
                "POSITION": a_pos,
                "NORMAL": a_nrm,
                "TEXCOORD_0": a_uv,
                "JOINTS_0": a_j,
                "WEIGHTS_0": a_w,
            },
            "indices": a_i,
        })

    nodes = []
    for i, name in enumerate(BONES):
        node = {"name": name, "translation": [float(v) for v in LOCAL[name]]}
        children = [j for j, child in enumerate(BONES) if PARENT[child] == name]
        if children:
            node["children"] = children
        nodes.append(node)
    mesh_nodes = []
    gltf_meshes = []
    for prim in primitives_per_mesh:
        gltf_meshes.append({"name": prim["name"], "primitives": [{
            "attributes": prim["attributes"],
            "indices": prim["indices"],
            "material": len(material_index),
            "mode": 4,
        }]})
        material_index[prim["name"]] = len(material_index)
        mesh_nodes.append(len(nodes))
        nodes.append({"name": prim["name"], "mesh": len(gltf_meshes) - 1, "skin": 0})
    root = len(nodes)
    nodes.append({"name": "Armature", "children": [0] + mesh_nodes})

    image_nodes = []
    texture_nodes = []
    for i, (filename, _image) in enumerate(images.items()):
        image_nodes.append({"mimeType": "image/png", "name": filename, "uri": filename})
        texture_nodes.append({"sampler": 0, "source": i})
    # Map mesh name to texture or solid factor. Solids still get a white pixel via albedo factor.
    solid = {
        "Brows": [0.28, 0.13, 0.07, 1],
        "Hood": [0.06, 0.06, 0.075, 1],
        "PadL": [0.86, 0.18, 0.42, 1],
        "PadR": [0.62, 0.28, 0.40, 1],
        "Patch": [0.89, 0.16, 0.46, 1],
        "TapeChest": [0.79, 0.66, 0.42, 1],
        "TapeArmL": [0.76, 0.63, 0.40, 1],
        "TapeArmR": [0.74, 0.61, 0.38, 1],
        "ShoulderL": [0.42, 0.43, 0.45, 1],
        "ShoulderR": [0.34, 0.35, 0.37, 1],
        "PocketL": [0.30, 0.36, 0.18, 1],
        "PocketR": [0.30, 0.36, 0.18, 1],
        "ShoeL": [0.79, 0.71, 0.56, 1],
        "ShoeR": [0.76, 0.68, 0.52, 1],
        "StripeL": [0.14, 0.11, 0.09, 1],
        "StripeR": [0.14, 0.11, 0.09, 1],
    }
    textured = {
        "Body": "body_albedo.png",
        "Jacket": "jacket_albedo.png",
        "Hair": "hair_albedo.png",
        "Eyes": "eye_albedo.png",
    }
    materials = []
    # Rebuild meshes' material indices now that we know the order.
    # gltf_meshes were given material = insertion order, which matches primitives_per_mesh order.
    # We'll overwrite materials to that same order.
    name_to_tex = {filename: i for i, filename in enumerate(images)}
    for prim in primitives_per_mesh:
        name = prim["name"]
        if name in textured:
            materials.append({
                "name": name,
                "doubleSided": name in ("Hair", "Hood", "Brows"),
                "pbrMetallicRoughness": {
                    "baseColorTexture": {"index": name_to_tex[textured[name]]},
                    "metallicFactor": 0.0,
                    "roughnessFactor": 1.0,
                },
            })
        else:
            materials.append({
                "name": name,
                "doubleSided": name == "Hood",
                "pbrMetallicRoughness": {
                    "baseColorFactor": solid.get(name, [1, 1, 1, 1]),
                    "metallicFactor": 0.0,
                    "roughnessFactor": 1.0,
                },
            })

    gltf = {
        "asset": {"version": "2.0", "generator": "bake_fony_human.py"},
        "scene": 0,
        "scenes": [{"nodes": [root], "name": "FonyHuman"}],
        "nodes": nodes,
        "meshes": gltf_meshes,
        "skins": [{
            "name": "Skeleton",
            "joints": list(range(len(BONES))),
            "inverseBindMatrices": ibm,
        }],
        "materials": materials,
        "textures": texture_nodes,
        "images": image_nodes,
        "samplers": [{"magFilter": 9729, "minFilter": 9987, "wrapS": 33071, "wrapT": 33071}],
        "accessors": buf.accessors,
        "bufferViews": buf.views,
        "buffers": [{"byteLength": len(buf.blob), "uri": "fony_human.bin"}],
    }
    path.write_text(json.dumps(gltf))
    (path.parent / "fony_human.bin").write_bytes(buf.blob)
    for filename, image in images.items():
        image.save(path.parent / filename)
    print("wrote", path, "buffer", len(buf.blob))


def render_preview(meshes: dict, colors: dict, path: Path):
    path.mkdir(parents=True, exist_ok=True)
    views = {
        "front": (np.array([0.0, 0.95, -1.0]), np.array([-1.0, 0.0, 0.0]), np.array([0.0, 1.0, 0.0])),
        "side": (np.array([1.0, 0.95, 0.0]), np.array([0.0, 0.0, -1.0]), np.array([0.0, 1.0, 0.0])),
        "back": (np.array([0.0, 0.95, 1.0]), np.array([1.0, 0.0, 0.0]), np.array([0.0, 1.0, 0.0])),
    }
    width, height = 640, 860
    light = unit(np.array([-0.35, 0.75, -0.55]))
    for view, (forward, right, up) in views.items():
        image = np.zeros((height, width, 3), np.float32)
        image[:] = np.array([0.93, 0.90, 0.84])
        depth = np.full((height, width), 1e9, np.float32)
        forward = unit(forward)
        right = unit(right)
        up = unit(up)
        for name, (pos, nrm, _uv, _j, _w, idx) in meshes.items():
            col = colors[name]
            cam = pos @ np.stack([right, up, -forward], axis=1)
            sx = (cam[:, 0] / 1.15 + 0.5) * (width - 1)
            sy = (1.0 - cam[:, 1] / 2.05) * (height - 1)
            sz = cam[:, 2]
            for tri in idx:
                p = np.stack([sx[tri], sy[tri]], axis=1)
                z = sz[tri]
                c = col[tri]
                n = nrm[tri]
                minx = max(int(np.floor(p[:, 0].min())), 0)
                maxx = min(int(np.ceil(p[:, 0].max())), width - 1)
                miny = max(int(np.floor(p[:, 1].min())), 0)
                maxy = min(int(np.ceil(p[:, 1].max())), height - 1)
                area = (p[1, 0] - p[0, 0]) * (p[2, 1] - p[0, 1]) - (p[2, 0] - p[0, 0]) * (p[1, 1] - p[0, 1])
                if maxx <= minx or maxy <= miny or abs(float(area)) < 0.5:
                    continue
                xs = np.arange(minx, maxx + 1)
                ys = np.arange(miny, maxy + 1)
                gx, gy = np.meshgrid(xs, ys)
                x = gx.astype(np.float32) + 0.5
                y = gy.astype(np.float32) + 0.5
                den = area
                a = ((p[1, 1] - p[2, 1]) * (x - p[2, 0]) + (p[2, 0] - p[1, 0]) * (y - p[2, 1])) / den
                b = ((p[2, 1] - p[0, 1]) * (x - p[2, 0]) + (p[0, 0] - p[2, 0]) * (y - p[2, 1])) / den
                g = 1.0 - a - b
                inside = (a >= 0) & (b >= 0) & (g >= 0)
                if not np.any(inside):
                    continue
                zz = a * z[0] + b * z[1] + g * z[2]
                nn = a[..., None] * n[0] + b[..., None] * n[1] + g[..., None] * n[2]
                nl = np.linalg.norm(nn, axis=2, keepdims=True)
                nl[nl < 1e-6] = 1
                nn = nn / nl
                ndot = np.clip((nn * light).sum(axis=2), 0, 1)
                band = np.where(ndot > 0.72, 1.0, np.where(ndot > 0.38, 0.68, 0.42))
                cc = a[..., None] * c[0] + b[..., None] * c[1] + g[..., None] * c[2]
                shaded = cc * band[..., None]
                yy = gy
                current = depth[yy, gx]
                win = inside & (zz < current)
                depth[yy[win], gx[win]] = zz[win]
                image[yy[win], gx[win]] = shaded[win]
        Image.fromarray((np.clip(image, 0, 1) * 255).astype(np.uint8), "RGB").save(path / f"{view}.png")
        print("preview", path / f"{view}.png")


def mesh_color(name: str, pos: np.ndarray, fallback: np.ndarray) -> np.ndarray:
    if name == "Body":
        return None
    return np.repeat(fallback[None, :], len(pos), axis=0)


def main():
    body_path = SRC / "body/Superhero_Male_FullBody.gltf"
    data, blob = load_gltf(body_path)
    bone_names, bone_info = skin_bones(data, blob)
    fony = fony_globals()
    groups = build_groups(bone_info, fony)
    albedo = np.array(Image.open(SRC / "textures/T_Superhero_Male_Dark.png").convert("RGB"), dtype=np.float32) / 255.0

    # Mesh 2 is the body. 0 is brows, 1 is eyes. Confirmed from the glTF nodes.
    body_pos, body_nrm, body_uv, body_j, body_w, body_i = load_mesh(data, blob, 2)
    brow_pos, brow_nrm, brow_uv, brow_j, brow_w, brow_i = load_mesh(data, blob, 0)
    eye_pos, eye_nrm, eye_uv, eye_j, eye_w, eye_i = load_mesh(data, blob, 1)

    def convert(pos, nrm, uv, joints, weights, idx, groups_):
        out, pj, pw = retarget(pos, joints, weights, bone_names, groups_)
        mirrored_n = np.stack([-nrm[:, 0], nrm[:, 1], -nrm[:, 2]], axis=1)
        # Rotate normals with the same per-influence blend as positions, approximately
        # by recomputing from the faces after the vertex move.
        new_n = recompute_normals(out, idx.reshape(-1, 3))
        # If the recompute flipped a region, prefer the direction closest to the
        # mirrored source normal so eyelids and lips do not invert.
        flip = (new_n * mirrored_n).sum(axis=1) < 0
        new_n[flip] *= -1
        return out, new_n, uv, pj, pw, idx.reshape(-1, 3)

    body = convert(body_pos, body_nrm, body_uv, body_j, body_w, body_i, groups)
    brows = convert(brow_pos, brow_nrm, brow_uv, brow_j, brow_w, brow_i, groups)
    eyes = convert(eye_pos, eye_nrm, eye_uv, eye_j, eye_w, eye_i, groups)
    # Eyes a touch larger and further forward so they read under the toon brow.
    head = fony["Head"]
    eyes = list(eyes)
    eyes[0] = head + (eyes[0] - head) * 1.08 + np.array([0.0, 0.0, -0.004])
    eyes = tuple(eyes)

    pos, nrm, uv, joints, weights, idx = body
    baggy_legs(pos, _weights_dense(joints, weights), fony)
    seat_soles(pos, _weights_dense(joints, weights), fony)
    nrm = recompute_normals(pos, idx)
    body = (pos, nrm, uv, joints, weights, idx)

    hair_data, hair_blob = load_gltf(SRC / "hair/Hair_Long.gltf")
    hair_names, hair_bones = skin_bones(hair_data, hair_blob)
    # Hair_Long is rigged to a different body than the superhero male. Anchor
    # that groom's head bone onto Fony's head, then reshape the volume.
    hair_groups = build_groups(hair_bones, fony)
    hpos, hnrm, huv, hj, hw, hi = load_mesh(hair_data, hair_blob, 0)
    hair = convert(hpos, hnrm, huv, hj, hw, hi, hair_groups)
    hair = list(hair)
    hair[0] = spike_hair(hair[0], head)
    radial = hair[0] - (head + np.array([0.0, 0.05, 0.0]))
    radial /= np.clip(np.linalg.norm(radial, axis=1, keepdims=True), 1e-5, None)
    face_n = recompute_normals(hair[0], hair[5])
    hair[1] = unit_rows(radial * 0.7 + face_n * 0.3)
    hair = tuple(hair)

    dense = _weights_dense(body[3], body[4])
    jacket = jacket_from_body(body[0], body[1], body[2], body[3], dense, body[5])
    jacket_color = jacket[-1]
    jacket = jacket[:-1]
    # Jacket normals already point out; recompute after the inflate offset.
    jacket = list(jacket)
    jacket[0] = smooth_mesh(jacket[0], jacket[5], iters=1, amount=0.25)
    jacket[1] = recompute_normals(jacket[0], jacket[5])
    # Smoothing moves vertices off the original UVs' color intent only a little;
    # the rust bake still follows these vertices.
    jacket_color = jacket_color  # color was computed pre-smooth; rebake below
    jacket = tuple(jacket)

    props = props_from_body(body[0], body[1], dense, fony, jacket[0], jacket[1])
    shoes = shoe_shells(body[0], body[1], dense, body[5], fony)
    hood = empty_mesh()
    add_hood(hood, fony)
    meshes = {
        "Body": body,
        "Jacket": jacket,
        "Hair": hair,
        "Eyes": tuple(eyes),
        "Brows": brows,
        "Hood": finalize(hood),
    }
    for name, (mesh, _bones, _weights) in props.items():
        meshes[name] = finalize(mesh)
    meshes.update(shoes)

    print("bounds body", body[0].min(0).round(3), body[0].max(0).round(3))
    print("bounds hair", hair[0].min(0).round(3), hair[0].max(0).round(3))
    for ankle in ("AnkleL", "AnkleR"):
        w = dense[:, BONES.index(ankle)]
        sel = body[0][w > 0.5]
        if len(sel):
            print(ankle, "sole", round(float(sel[:, 1].min()), 3), "toe z", round(float(sel[:, 2].min()), 3), "ankle", fony[ankle])

    body_color = region_colors(body[0], dense, body[2], albedo)
    print("raster body", len(body[5]))
    body_tex = rasterize(body[2], body[5], body_color, 1024)
    jacket_tex = rasterize(jacket[2], jacket[5], jacket_color, 512)
    images = {
        "body_albedo.png": Image.fromarray((np.clip(body_tex, 0, 1) * 255).astype(np.uint8), "RGB"),
        "jacket_albedo.png": Image.fromarray((np.clip(jacket_tex, 0, 1) * 255).astype(np.uint8), "RGB"),
        "hair_albedo.png": tint_hair(SRC / "textures/T_Hair_2_BaseColor.png"),
        "eye_albedo.png": clean_eye(SRC / "textures/T_Eye_Brown.png"),
    }
    write_gltf(meshes, images, OUT / "fony_human.gltf")

    preview_colors = {
        "Body": body_color,
        "Jacket": jacket_color,
        "Hair": np.repeat(COPPER[None, :], len(hair[0]), axis=0),
        "Eyes": np.repeat(np.array([[0.95, 0.95, 0.96]], np.float32), len(eyes[0]), axis=0),
        "Brows": np.repeat(np.array([[0.28, 0.13, 0.07]], np.float32), len(brows[0]), axis=0),
        "Hood": np.repeat(HOODIE[None, :], len(meshes["Hood"][0]), axis=0),
        "PadL": np.repeat(np.array([[0.86, 0.18, 0.42]], np.float32), len(meshes["PadL"][0]), axis=0),
        "PadR": np.repeat(np.array([[0.62, 0.28, 0.40]], np.float32), len(meshes["PadR"][0]), axis=0),
        "Patch": np.repeat(np.array([[0.89, 0.16, 0.46]], np.float32), len(meshes["Patch"][0]), axis=0),
        "TapeChest": np.repeat(np.array([[0.79, 0.66, 0.42]], np.float32), len(meshes["TapeChest"][0]), axis=0),
        "TapeArmL": np.repeat(np.array([[0.76, 0.63, 0.40]], np.float32), len(meshes["TapeArmL"][0]), axis=0),
        "TapeArmR": np.repeat(np.array([[0.74, 0.61, 0.38]], np.float32), len(meshes["TapeArmR"][0]), axis=0),
        "ShoulderL": np.repeat(np.array([[0.42, 0.43, 0.45]], np.float32), len(meshes["ShoulderL"][0]), axis=0),
        "ShoulderR": np.repeat(np.array([[0.34, 0.35, 0.37]], np.float32), len(meshes["ShoulderR"][0]), axis=0),
        "PocketL": np.repeat(PANTS_DARK[None, :], len(meshes["PocketL"][0]), axis=0),
        "PocketR": np.repeat(PANTS_DARK[None, :], len(meshes["PocketR"][0]), axis=0),
        "ShoeL": np.repeat(SHOE[None, :], len(meshes["ShoeL"][0]), axis=0),
        "ShoeR": np.repeat(SHOE[None, :], len(meshes["ShoeR"][0]), axis=0),
        "StripeL": np.repeat(SHOE_DARK[None, :], len(meshes["StripeL"][0]), axis=0),
        "StripeR": np.repeat(SHOE_DARK[None, :], len(meshes["StripeR"][0]), axis=0),
    }
    render_preview(meshes, preview_colors, PREVIEW)


def _weights_dense(joints: np.ndarray, weights: np.ndarray) -> np.ndarray:
    dense = np.zeros((len(joints), len(BONES)), dtype=np.float64)
    for k in range(4):
        np.add.at(dense, (np.arange(len(joints)), joints[:, k]), weights[:, k])
    return dense


def unit_rows(v: np.ndarray) -> np.ndarray:
    n = np.linalg.norm(v, axis=1, keepdims=True)
    n[n < 1e-8] = 1.0
    return v / n


if __name__ == "__main__":
    main()
