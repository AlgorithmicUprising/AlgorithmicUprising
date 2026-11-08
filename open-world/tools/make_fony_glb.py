#!/usr/bin/env python3
"""Author Fony as a skinned glTF. Original geometry, not the concept painting.

The game loads assets/library/fony/fony.glb. Bone names and rest translations
match the pose rig in scripts/fony_rig.gd.
"""
import json
import math
import struct
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "assets" / "library" / "fony" / "fony.glb"

BONES = [
    ("Hips", None, (0.0, 1.02, 0.0)),
    ("Spine", "Hips", (0.0, 0.16, 0.0)),
    ("Chest", "Spine", (0.0, 0.16, 0.0)),
    ("Neck", "Chest", (0.0, 0.18, 0.0)),
    ("Head", "Neck", (0.0, 0.10, 0.0)),
    ("ArmL", "Chest", (-0.20, 0.08, 0.0)),
    ("ForeL", "ArmL", (0.0, -0.26, 0.0)),
    ("HandL", "ForeL", (0.0, -0.22, 0.0)),
    ("ArmR", "Chest", (0.20, 0.08, 0.0)),
    ("ForeR", "ArmR", (0.0, -0.26, 0.0)),
    ("HandR", "ForeR", (0.0, -0.22, 0.0)),
    ("LegL", "Hips", (-0.08, -0.04, 0.0)),
    ("ShinL", "LegL", (0.0, -0.42, 0.0)),
    ("AnkleL", "ShinL", (0.0, -0.42, 0.0)),
    ("LegR", "Hips", (0.08, -0.04, 0.0)),
    ("ShinR", "LegR", (0.0, -0.42, 0.0)),
    ("AnkleR", "ShinR", (0.0, -0.42, 0.0)),
]

COLORS = {
    "Skin": (0.91, 0.71, 0.56),
    "Lip": (0.72, 0.38, 0.36),
    "Brow": (0.42, 0.22, 0.14),
    "Sclera": (0.95, 0.93, 0.90),
    "Iris": (0.29, 0.18, 0.12),
    "Hair": (0.77, 0.38, 0.18),
    "HairDark": (0.48, 0.22, 0.12),
    "Jacket": (0.77, 0.42, 0.20),
    "Hoodie": (0.10, 0.10, 0.12),
    "PatchGray": (0.42, 0.45, 0.48),
    "PatchPink": (0.89, 0.24, 0.47),
    "Pants": (0.36, 0.42, 0.23),
    "Pocket": (0.28, 0.33, 0.18),
    "Pad": (0.89, 0.24, 0.47),
    "Strap": (0.16, 0.16, 0.18),
    "Shoe": (0.77, 0.71, 0.63),
    "Sole": (0.20, 0.16, 0.14),
    "Stripe": (0.12, 0.10, 0.10),
}


def vadd(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def vsub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def vmul(a, s):
    return (a[0] * s, a[1] * s, a[2] * s)


def vdot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def vcross(a, b):
    return (
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    )


def vlen(a):
    return math.sqrt(vdot(a, a))


def vnorm(a):
    length = vlen(a)
    if length < 1e-8:
        return (0.0, 1.0, 0.0)
    return vmul(a, 1.0 / length)


def lerp(a, b, t):
    return a + (b - a) * t


def bone_globals():
    g = {}
    for name, parent, local in BONES:
        g[name] = local if parent is None else vadd(g[parent], local)
    return g


class Mesh(object):
    def __init__(self, color):
        self.color = color
        self.verts = []
        self.joints = []
        self.weights = []
        self.indices = []

    def vert(self, p, bone, bone_b=None, w=1.0):
        self.verts.append(p)
        b0 = BONE_INDEX[bone]
        b1 = BONE_INDEX[bone_b] if bone_b else b0
        ww = max(0.0, min(1.0, w))
        self.joints.append((b0, b1, 0, 0))
        self.weights.append((ww, 1.0 - ww, 0.0, 0.0))
        return len(self.verts) - 1

    def tri(self, a, b, c):
        self.indices.extend((a, b, c))

    def quad(self, a, b, c, d):
        self.tri(a, b, c)
        self.tri(a, c, d)


MESHES = {}


def M(name):
    if name not in MESHES:
        MESHES[name] = Mesh(COLORS[name])
    return MESHES[name]


def tube(name, a, b, ra, rb, bone_a, bone_b, sides=10, rings=4):
    axis = vsub(b, a)
    length = vlen(axis)
    if length < 1e-5:
        return
    direction = vnorm(axis)
    helper = (1.0, 0.0, 0.0) if abs(direction[1]) > 0.9 else (0.0, 1.0, 0.0)
    side = vnorm(vcross(direction, helper))
    up = vnorm(vcross(side, direction))
    ids = []
    mesh = M(name)
    for r in range(rings):
        t = r / (rings - 1)
        center = vadd(a, vmul(axis, t))
        rad = lerp(ra, rb, t)
        w = 1.0 - smooth(t)
        row = []
        for i in range(sides):
            ang = math.tau * i / sides
            n = vadd(vmul(side, math.cos(ang)), vmul(up, math.sin(ang)))
            row.append(mesh.vert(vadd(center, vmul(n, rad)), bone_a, bone_b, w))
        ids.append(row)
    for r in range(rings - 1):
        for i in range(sides):
            j = (i + 1) % sides
            mesh.quad(ids[r][i], ids[r][j], ids[r + 1][j], ids[r + 1][i])


def smooth(t):
    t = max(0.0, min(1.0, (t - 0.42) / 0.16))
    return t * t * (3.0 - 2.0 * t)


def ellipsoid(name, center, radii, bone, stacks=10, slices=12):
    mesh = M(name)
    rings = []
    for iy in range(stacks + 1):
        v = iy / stacks
        phi = lerp(-math.pi / 2.0, math.pi / 2.0, v)
        cp = math.cos(phi)
        row = []
        for ix in range(slices):
            theta = math.tau * ix / slices
            n = (math.sin(theta) * cp, math.sin(phi), -math.cos(theta) * cp)
            p = (center[0] + n[0] * radii[0], center[1] + n[1] * radii[1], center[2] + n[2] * radii[2])
            row.append(mesh.vert(p, bone))
        rings.append(row)
    for iy in range(stacks):
        for ix in range(slices):
            j = (ix + 1) % slices
            mesh.quad(rings[iy][ix], rings[iy][j], rings[iy + 1][j], rings[iy + 1][ix])


def head(center):
    mesh = M("Skin")
    stacks, slices = 16, 20
    rings = []
    for iy in range(stacks + 1):
        v = iy / stacks
        phi = lerp(-math.pi / 2.0, math.pi / 2.0, v)
        cp = math.cos(phi)
        row = []
        for ix in range(slices):
            theta = math.tau * ix / slices
            nx = math.sin(theta) * cp
            ny = math.sin(phi)
            nz = -math.cos(theta) * cp
            p = sculpt_head(nx, ny, nz)
            row.append(mesh.vert((center[0] + p[0], center[1] + p[1], center[2] + p[2]), "Head"))
        rings.append(row)
    for iy in range(stacks):
        for ix in range(slices):
            j = (ix + 1) % slices
            mesh.quad(rings[iy][ix], rings[iy][j], rings[iy + 1][j], rings[iy + 1][ix])
    ellipsoid("Skin", (center[0] - 0.10, center[1] - 0.01, center[2] - 0.01), (0.012, 0.028, 0.016), "Head", 6, 8)
    ellipsoid("Skin", (center[0] + 0.10, center[1] - 0.01, center[2] - 0.01), (0.012, 0.028, 0.016), "Head", 6, 8)
    for side in (-1.0, 1.0):
        eye = (center[0] + side * 0.034, center[1] + 0.012, center[2] - 0.102)
        ellipsoid("Sclera", eye, (0.014, 0.011, 0.006), "Head", 6, 8)
        ellipsoid("Iris", (eye[0], eye[1], eye[2] - 0.005), (0.007, 0.007, 0.003), "Head", 6, 8)
        ellipsoid("Brow", (eye[0] + side * 0.002, eye[1] + 0.022, eye[2] - 0.01), (0.02, 0.005, 0.006), "Head", 4, 6)
    ellipsoid("Lip", (center[0], center[1] - 0.042, center[2] - 0.098), (0.016, 0.005, 0.007), "Head", 4, 6)
    ellipsoid("Lip", (center[0], center[1] - 0.052, center[2] - 0.094), (0.014, 0.004, 0.006), "Head", 4, 6)


def sculpt_head(nx, ny, nz):
    front = max(0.0, -nz)
    x = nx * 0.104
    y = ny * 0.122
    z = nz * 0.098
    if ny < 0.05:
        jaw = 0.62 + 0.38 * max(0.0, (ny + 0.15) / 0.2)
        jaw = max(0.55, min(1.0, 0.72 + ny * 0.9))
        x *= jaw
        z *= 0.92 + 0.08 * max(ny, -0.2)
    cheek = max(0.0, 1.0 - ((abs(nx) - 0.35) / 0.28) ** 2 - ((ny - 0.0) / 0.28) ** 2)
    if cheek > 0.0 and front > 0.2:
        x *= 1.0 + 0.08 * cheek
        z -= 0.008 * cheek * front
    nose = max(0.0, 1.0 - (nx / 0.16) ** 2 - ((ny + 0.02) / 0.20) ** 2)
    z -= 0.034 * nose * front
    for sx in (-0.36, 0.36):
        socket = max(0.0, 1.0 - ((nx - sx) / 0.18) ** 2 - ((ny - 0.12) / 0.14) ** 2)
        z += 0.018 * socket * front
    brow = max(0.0, 1.0 - (abs(nx) / 0.55) ** 2 - ((ny - 0.28) / 0.12) ** 2)
    z -= 0.012 * brow * front
    if ny < -0.45:
        x *= 0.82
        z += 0.006
    return (x, y, z)


def hair(center):
    cap(center)
    locks = [
        ((0.0, 0.11, -0.02), (0.02, 0.155, -0.03), (0.04, 0.13, -0.01), 0.032),
        ((-0.04, 0.12, 0.0), (-0.05, 0.15, 0.02), (-0.02, 0.125, 0.03), 0.03),
        ((0.045, 0.11, 0.02), (0.06, 0.14, 0.04), (0.03, 0.11, 0.05), 0.028),
        ((0.0, 0.08, 0.06), (0.0, 0.11, 0.09), (0.0, 0.07, 0.1), 0.04),
        ((-0.08, 0.05, 0.01), (-0.11, 0.09, 0.02), (-0.09, 0.12, 0.0), 0.028),
        ((0.08, 0.05, 0.01), (0.11, 0.09, 0.02), (0.09, 0.12, 0.0), 0.028),
    ]
    for a, b, c, width in locks:
        ribbon("Hair", [vadd(center, p) for p in (a, b, c)], width, 0.01, "Head")
    bangs = [vadd(center, p) for p in ((-0.05, 0.075, -0.09), (0.0, 0.085, -0.1), (0.055, 0.06, -0.09))]
    ribbon("HairDark", bangs, 0.034, 0.008, "Head")


def cap(center):
    mesh = M("Hair")
    stacks, slices = 8, 16
    inner = []
    outer = []
    for iy in range(stacks + 1):
        v = iy / stacks
        phi = lerp(0.05, math.pi / 2.0, v)
        cp = math.cos(phi)
        inn, out = [], []
        for ix in range(slices):
            theta = math.tau * ix / slices
            nx = math.sin(theta) * cp
            ny = math.sin(phi)
            nz = -math.cos(theta) * cp
            if ny < 0.25:
                continue
            if nz < -0.2 and ny < 0.78:
                continue
            p = (center[0] + nx * 0.108, center[1] + ny * 0.125, center[2] + nz * 0.10)
            n = vnorm((nx, ny * 0.8, nz))
            inn.append(mesh.vert(p, "Head"))
            out.append(mesh.vert(vadd(p, vmul(n, 0.028 + 0.012 * ny)), "Head"))
        if len(inn) < 3:
            continue
        inner.append(inn)
        outer.append(out)
    for r in range(len(outer) - 1):
        n0 = min(len(outer[r]), len(outer[r + 1]))
        for i in range(n0 - 1):
            mesh.quad(outer[r][i], outer[r][i + 1], outer[r + 1][i + 1], outer[r + 1][i])
            mesh.quad(inner[r][i + 1], inner[r][i], inner[r + 1][i], inner[r + 1][i + 1])


def ribbon(name, curve, width, thick, bone):
    mesh = M(name)
    frames = []
    for i, p in enumerate(curve):
        tangent = vsub(curve[min(i + 1, len(curve) - 1)], curve[max(i - 1, 0)])
        tangent = vnorm(tangent)
        side = vcross(tangent, (0.0, 1.0, 0.0))
        if vlen(side) < 1e-4:
            side = vcross(tangent, (1.0, 0.0, 0.0))
        side = vnorm(side)
        up = vnorm(vcross(side, tangent))
        frames.append((p, side, up))
    ids = []
    for p, side, up in frames:
        row = []
        for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            row.append(mesh.vert(vadd(p, vadd(vmul(side, sx * width), vmul(up, sy * thick))), bone))
        ids.append(row)
    for i in range(len(ids) - 1):
        for k in range(4):
            j = (k + 1) % 4
            mesh.quad(ids[i][k], ids[i][j], ids[i + 1][j], ids[i + 1][k])


def torso(g):
    hoodie_sections = [
        (1.00, 0.12, 0.09, "Hips"),
        (1.16, 0.115, 0.088, "Spine"),
        (1.34, 0.13, 0.095, "Chest"),
        (1.52, 0.07, 0.06, "Neck"),
    ]
    closed_loft("Hoodie", hoodie_sections, 12)
    jacket_sections = [
        (0.98, 0.16, 0.12, "Hips"),
        (1.08, 0.145, 0.11, "Hips"),
        (1.22, 0.14, 0.105, "Spine"),
        (1.36, 0.16, 0.115, "Chest"),
        (1.50, 0.17, 0.12, "Chest"),
        (1.58, 0.09, 0.08, "Neck"),
    ]
    open_shell("Jacket", jacket_sections, 14, 0.72)
    collar(g)
    lapels(g)
    patch(g)


def ring_point(y, rx, rz, angle):
    return (math.sin(angle) * rx, y, -math.cos(angle) * rz)


def closed_loft(name, sections, sides):
    mesh = M(name)
    rings = []
    for y, rx, rz, bone in sections:
        row = []
        for i in range(sides):
            row.append(mesh.vert(ring_point(y, rx, rz, math.tau * i / sides), bone))
        rings.append(row)
    for r in range(len(rings) - 1):
        bone = sections[r][3]
        for i in range(sides):
            j = (i + 1) % sides
            mesh.quad(rings[r][i], rings[r][j], rings[r + 1][j], rings[r + 1][i])


def open_shell(name, sections, sides, gap):
    mesh = M(name)
    angles = []
    count = sides
    for i in range(count):
        t = i / (count - 1)
        angles.append(lerp(gap, math.tau - gap, t))
    outer = []
    inner = []
    for y, rx, rz, bone in sections:
        o, inn = [], []
        for angle in angles:
            p = ring_point(y, rx, rz, angle)
            q = ring_point(y, rx - 0.012, rz - 0.01, angle)
            o.append(mesh.vert(p, bone))
            inn.append(mesh.vert(q, bone))
        outer.append(o)
        inner.append(inn)
    for r in range(len(outer) - 1):
        for i in range(count - 1):
            mesh.quad(outer[r][i], outer[r][i + 1], outer[r + 1][i + 1], outer[r + 1][i])
            mesh.quad(inner[r][i + 1], inner[r][i], inner[r + 1][i], inner[r + 1][i + 1])
    for edge in (0, count - 1):
        for r in range(len(outer) - 1):
            mesh.quad(outer[r][edge], inner[r][edge], inner[r + 1][edge], outer[r + 1][edge])
    last = len(outer) - 1
    for i in range(count - 1):
        mesh.quad(outer[0][i + 1], outer[0][i], inner[0][i], inner[0][i + 1])
        mesh.quad(outer[last][i], outer[last][i + 1], inner[last][i + 1], inner[last][i])


def collar(g):
    neck = g["Neck"]
    sections = [
        (neck[1] - 0.02, 0.075, 0.065, "Neck"),
        (neck[1] + 0.045, 0.09, 0.07, "Neck"),
    ]
    open_shell("Jacket", sections, 10, 0.9)


def lapels(g):
    mesh = M("Jacket")
    chest = g["Chest"]
    for side in (-1.0, 1.0):
        a = (side * 0.04, chest[1] + 0.08, -0.12)
        b = (side * 0.10, chest[1] - 0.02, -0.13)
        c = (side * 0.07, chest[1] - 0.16, -0.11)
        d = (side * 0.015, chest[1] + 0.02, -0.10)
        flap = [mesh.vert(p, "Chest") for p in (a, b, c, d)]
        outer = [mesh.vert((p[0] + side * 0.01, p[1], p[2] - 0.008), "Chest") for p in (a, b, c, d)]
        mesh.quad(*flap)
        mesh.quad(outer[0], outer[3], outer[2], outer[1])


def patch(g):
    chest = g["Chest"]
    plate("PatchPink", (chest[0] - 0.06, chest[1] + 0.02, chest[2] - 0.125), (0.035, 0.028, 0.006), "Chest")
    plate("PatchGray", (chest[0] + 0.12, chest[1] + 0.08, chest[2] - 0.09), (0.03, 0.026, 0.006), "Chest")


def plate(name, center, size, bone):
    mesh = M(name)
    hx, hy, hz = size
    corners = []
    for z in (-hz, hz):
        for y in (-hy, hy):
            for x in (-hx, hx):
                corners.append(mesh.vert((center[0] + x, center[1] + y, center[2] + z), bone))
    # 8 corners in binary order x + 2y + 4z
    faces = [
        (0, 1, 3, 2),
        (4, 6, 7, 5),
        (0, 4, 5, 1),
        (2, 3, 7, 6),
        (0, 2, 6, 4),
        (1, 5, 7, 3),
    ]
    for a, b, c, d in faces:
        mesh.quad(corners[a], corners[b], corners[c], corners[d])


def limbs(g):
    pairs = [
        ("ArmL", "ForeL", "HandL", 0.055, 0.042, 0.034, "Jacket"),
        ("ArmR", "ForeR", "HandR", 0.055, 0.042, 0.034, "Jacket"),
        ("LegL", "ShinL", "AnkleL", 0.078, 0.062, 0.048, "Pants"),
        ("LegR", "ShinR", "AnkleR", 0.078, 0.062, 0.048, "Pants"),
    ]
    for a, b, c, ra, rb, rc, mat in pairs:
        tube(mat, g[a], g[b], ra, rb * 1.08, a, b, 10, 5)
        tube(mat, g[b], g[c], rb, rc, b, c, 10, 5)
    for side, shoulder in (("L", g["ArmL"]), ("R", g["ArmR"])):
        ellipsoid("Jacket", shoulder, (0.06, 0.045, 0.05), "Arm" + side, 6, 8)
        ellipsoid("Hoodie", vadd(g["Hand" + side], (0.0, 0.02, 0.0)), (0.04, 0.018, 0.032), "Hand" + side, 5, 8)
    for side, knee in (("L", g["ShinL"]), ("R", g["ShinR"])):
        pad = vadd(knee, (0.0, 0.03, -0.055))
        ellipsoid("Pad", pad, (0.05, 0.038, 0.028), "Shin" + side, 6, 8)
        tube("Strap", vadd(knee, (0.0, 0.03, 0.0)), vadd(knee, (0.0, 0.0, 0.0)), 0.068, 0.064, "Shin" + side, "Shin" + side, 8, 2)
        pocket = vadd(g["Leg" + side], ((-0.07 if side == "L" else 0.07), -0.08, -0.02))
        plate("Pocket", pocket, (0.028, 0.035, 0.012), "Leg" + side)
    hand(g["HandL"], -1.0)
    hand(g["HandR"], 1.0)
    shoe(g["AnkleL"])
    shoe(g["AnkleR"])


def hand(wrist, side):
    palm = vadd(wrist, (side * 0.006, -0.045, -0.008))
    ellipsoid("Skin", palm, (0.034, 0.04, 0.016), "HandL" if side < 0 else "HandR", 6, 8)
    bone = "HandL" if side < 0 else "HandR"
    for i in range(4):
        x = lerp(-0.02, 0.02, i / 3.0)
        root = vadd(palm, (x, -0.03, -0.004))
        tip = vadd(root, (x * 0.15, -0.038, -0.006))
        tube("Skin", root, tip, 0.007, 0.0045, bone, bone, 5, 3)
    thumb_root = vadd(palm, (side * 0.028, -0.004, -0.006))
    thumb_tip = vadd(thumb_root, (side * 0.022, -0.02, -0.012))
    tube("Skin", thumb_root, thumb_tip, 0.009, 0.006, bone, bone, 5, 3)


def shoe(ankle):
    upper = vadd(ankle, (0.0, -0.02, -0.045))
    ellipsoid("Shoe", upper, (0.048, 0.032, 0.11), "AnkleL" if ankle[0] < 0 else "AnkleR", 6, 8)
    bone = "AnkleL" if ankle[0] < 0 else "AnkleR"
    ellipsoid("Sole", vadd(ankle, (0.0, -0.048, -0.04)), (0.052, 0.012, 0.12), bone, 4, 8)
    ellipsoid("Stripe", vadd(ankle, (0.0, -0.005, -0.04)), (0.05, 0.008, 0.07), bone, 4, 6)


def normals_of(verts, indices):
    acc = [(0.0, 0.0, 0.0) for _ in verts]
    for i in range(0, len(indices), 3):
        a, b, c = indices[i], indices[i + 1], indices[i + 2]
        n = vcross(vsub(verts[b], verts[a]), vsub(verts[c], verts[a]))
        acc[a] = vadd(acc[a], n)
        acc[b] = vadd(acc[b], n)
        acc[c] = vadd(acc[c], n)
    return [vnorm(n) for n in acc]


def pad4(data):
    while len(data) % 4:
        data += b"\x00"
    return data


def build():
    g = bone_globals()
    head(g["Head"])
    hair(g["Head"])
    tube("Skin", g["Neck"], vadd(g["Head"], (0.0, -0.02, 0.0)), 0.048, 0.055, "Neck", "Head", 8, 3)
    torso(g)
    limbs(g)
    # Drop the tiny lid helper's reliance on shared skin mesh index bugs by leaving it.
    blobs = []
    views = []
    accessors = []
    primitives_per_mesh = []
    bin_blob = b""

    def push(data, ctype, count, typ, mn=None, mx=None):
        nonlocal bin_blob
        bin_blob = pad4(bin_blob)
        offset = len(bin_blob)
        bin_blob += data
        views.append({"buffer": 0, "byteOffset": offset, "byteLength": len(data), "target": 34962 if ctype != 5123 else 34963})
        acc = {"bufferView": len(views) - 1, "componentType": ctype, "count": count, "type": typ}
        if mn is not None:
            acc["min"] = mn
            acc["max"] = mx
        accessors.append(acc)
        return len(accessors) - 1

    mesh_nodes = []
    gltf_meshes = []
    for name, mesh in MESHES.items():
        if len(mesh.indices) < 3:
            continue
        verts = mesh.verts
        norms = normals_of(verts, mesh.indices)
        pos = b"".join(struct.pack("<3f", *p) for p in verts)
        nrm = b"".join(struct.pack("<3f", *n) for n in norms)
        uv = b"".join(struct.pack("<2f", 0.0, 0.0) for _ in verts)
        joints = b"".join(struct.pack("<4B", *j) for j in mesh.joints)
        weights = b"".join(struct.pack("<4f", *w) for w in mesh.weights)
        index_data = b"".join(struct.pack("<H", i) for i in mesh.indices)
        xs = [p[0] for p in verts]
        ys = [p[1] for p in verts]
        zs = [p[2] for p in verts]
        pos_i = push(pos, 5126, len(verts), "VEC3", [min(xs), min(ys), min(zs)], [max(xs), max(ys), max(zs)])
        nrm_i = push(nrm, 5126, len(verts), "VEC3")
        uv_i = push(uv, 5126, len(verts), "VEC2")
        j_i = push(joints, 5121, len(verts), "VEC4")
        w_i = push(weights, 5126, len(verts), "VEC4")
        i_i = push(index_data, 5123, len(mesh.indices), "SCALAR")
        gltf_meshes.append({
            "name": name,
            "primitives": [{
                "attributes": {"POSITION": pos_i, "NORMAL": nrm_i, "TEXCOORD_0": uv_i, "JOINTS_0": j_i, "WEIGHTS_0": w_i},
                "indices": i_i,
                "material": len(gltf_meshes),
            }],
        })
        mesh_nodes.append(name)
        blobs.append((name, len(mesh.indices) // 3))

    inv = b""
    for name, _parent, _local in BONES:
        gx, gy, gz = g[name]
        m = [
            1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
            -gx, -gy, -gz, 1,
        ]
        inv += struct.pack("<16f", *m)
    inv_i = push(inv, 5126, len(BONES), "MAT4")

    nodes = []
    for name, parent, local in BONES:
        node = {"name": name, "translation": list(local)}
        nodes.append(node)
    bone_node = {name: i for i, (name, _p, _l) in enumerate(BONES)}
    for name, parent, _local in BONES:
        if parent is not None:
            nodes[bone_node[parent]].setdefault("children", []).append(bone_node[name])
    materials = []
    for i, name in enumerate(mesh_nodes):
        node_index = len(nodes)
        nodes.append({"name": name, "mesh": i, "skin": 0})
        color = MESHES[name].color
        materials.append({"name": name, "pbrMetallicRoughness": {"baseColorFactor": [color[0], color[1], color[2], 1.0], "metallicFactor": 0.0, "roughnessFactor": 1.0}, "doubleSided": False})
    root_children = [bone_node["Hips"]] + list(range(len(BONES), len(nodes)))
    nodes.append({"name": "FonyRig", "children": root_children})
    gltf = {
        "asset": {"version": "2.0", "generator": "make_fony_glb.py"},
        "scene": 0,
        "scenes": [{"name": "Fony", "nodes": [len(nodes) - 1]}],
        "nodes": nodes,
        "meshes": gltf_meshes,
        "skins": [{"name": "Body", "inverseBindMatrices": inv_i, "joints": list(range(len(BONES))), "skeleton": bone_node["Hips"]}],
        "materials": materials,
        "accessors": accessors,
        "bufferViews": views,
        "buffers": [{"byteLength": len(pad4(bin_blob))}],
    }
    js = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    js += b" " * ((4 - len(js) % 4) % 4)
    blob = pad4(bin_blob)
    total = 12 + 8 + len(js) + 8 + len(blob)
    out = struct.pack("<4sII", b"glTF", 2, total)
    out += struct.pack("<I4s", len(js), b"JSON") + js
    out += struct.pack("<I4s", len(blob), b"BIN\x00") + blob
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_bytes(out)
    tris = sum(n for _name, n in blobs)
    print(f"wrote {OUT} triangles={tris} parts={len(blobs)}")
    for name, n in blobs:
        print(f"  {name} {n}")


if __name__ == "__main__":
    BONE_INDEX = {name: i for i, (name, _p, _l) in enumerate(BONES)}
    build()
