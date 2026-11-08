#!/usr/bin/env python3
"""Original textures for the reusable quarter pipe. No imported art."""
import math
import struct
import zlib
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "assets" / "library" / "quarter_pipe"


def chunk(tag: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)


def write_png(path: Path, width: int, height: int, rgb: bytes) -> None:
    raw = bytearray()
    stride = width * 3
    for y in range(height):
        raw.append(0)
        raw.extend(rgb[y * stride:(y + 1) * stride])
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    path.write_bytes(png)


def hash01(x: int, y: int) -> float:
    n = (x * 374761393 + y * 668265263) & 0xFFFFFFFF
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return (n & 0xFFFFFF) / 16777215.0


def noise(x: float, y: float) -> float:
    x0 = math.floor(x)
    y0 = math.floor(y)
    fx = x - x0
    fy = y - y0
    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)
    a = hash01(x0, y0)
    b = hash01(x0 + 1, y0)
    c = hash01(x0, y0 + 1)
    d = hash01(x0 + 1, y0 + 1)
    return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def clamp_px(c):
    return tuple(max(0, min(255, int(v))) for v in c)


def dist_to_seg(px, py, ax, ay, bx, by) -> float:
    abx, aby = bx - ax, by - ay
    length = math.hypot(abx, aby) or 1.0
    t = max(0.0, min(1.0, ((px - ax) * abx + (py - ay) * aby) / (length * length)))
    return math.hypot(px - (ax + abx * t), py - (ay + aby * t))


def concrete(w=1024, h=512) -> bytes:
    cream = (236, 214, 186)
    warm = (214, 176, 140)
    scuff = (168, 122, 90)
    ink = (42, 36, 34)
    teal = (78, 188, 170)
    teal_deep = (46, 140, 132)
    rust = (176, 96, 64)
    seams = [0.18, 0.46, 0.74]
    cracks = [
        [(0.12, 0.06), (0.2, 0.14), (0.16, 0.2)],
        [(0.78, 0.9), (0.7, 0.96)],
    ]
    buf = bytearray(w * h * 3)
    for y in range(h):
        v = y / (h - 1)
        for x in range(w):
            u = x / (w - 1)
            n = noise(u * 14.0, v * 8.0)
            if v < 0.16 or v > 0.9:
                col = mix(cream, warm, n * 0.45)
            elif v < 0.24 or v > 0.82:
                col = mix(rust, scuff, n * 0.35)
            else:
                col = mix(teal, teal_deep, n * 0.35)
            for s in seams:
                if abs(v - s) < 0.006:
                    col = mix(col, ink, 0.85)
            edge = min(u, 1.0 - u)
            if edge < 0.018:
                col = mix(col, ink, (0.018 - edge) / 0.018)
            elif edge < 0.05:
                col = mix(col, rust, 0.35)
            buf[(y * w + x) * 3:(y * w + x) * 3 + 3] = bytes(clamp_px(col))
    for poly in cracks:
        pts = [(p[0] * (w - 1), p[1] * (h - 1)) for p in poly]
        for i in range(len(pts) - 1):
            ax, ay = pts[i]
            bx, by = pts[i + 1]
            minx = max(0, int(min(ax, bx) - 4))
            maxx = min(w - 1, int(max(ax, bx) + 4))
            miny = max(0, int(min(ay, by) - 4))
            maxy = min(h - 1, int(max(ay, by) + 4))
            for y in range(miny, maxy + 1):
                for x in range(minx, maxx + 1):
                    d = dist_to_seg(x, y, ax, ay, bx, by)
                    if d < 2.2:
                        i0 = (y * w + x) * 3
                        cur = (buf[i0], buf[i0 + 1], buf[i0 + 2])
                        buf[i0:i0 + 3] = bytes(mix(cur, ink, 0.7 if d < 1.1 else 0.35))
    return bytes(buf)


def graffiti(w=512, h=512) -> bytes:
    teal = (28, 110, 104)
    deep = (16, 64, 62)
    cream = (236, 224, 204)
    rust = (184, 78, 48)
    ink = (24, 22, 28)
    buf = bytearray()
    for y in range(h):
        for x in range(w):
            n = noise(x / 28.0, y / 28.0)
            buf.extend(mix(teal, deep, n * 0.45))
    def rect(x0, y0, x1, y1, color):
        for y in range(max(0, y0), min(h, y1)):
            for x in range(max(0, x0), min(w, x1)):
                buf[(y * w + x) * 3:(y * w + x) * 3 + 3] = bytes(color)
    def disc(cx, cy, r, color):
        r2 = r * r
        for y in range(max(0, cy - r), min(h, cy + r)):
            for x in range(max(0, cx - r), min(w, cx + r)):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r2:
                    buf[(y * w + x) * 3:(y * w + x) * 3 + 3] = bytes(color)
    rect(28, 28, w - 28, h - 28, cream)
    rect(48, 48, w - 48, h - 48, teal)
    rect(70, 150, 210, 190, rust)
    rect(86, 186, 118, 360, rust)
    rect(162, 186, 194, 360, rust)
    rect(118, 250, 162, 282, rust)
    rect(250, 160, 290, 360, cream)
    rect(290, 300, 420, 360, cream)
    rect(380, 160, 420, 360, cream)
    disc(140, 110, 36, ink)
    disc(140, 110, 18, cream)
    for i in range(8):
        rect(60 + i * 52, 400, 88 + i * 52, 430, cream if i % 2 == 0 else rust)
    rect(300, 80, 460, 112, rust)
    return bytes(buf)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    write_png(OUT / "concrete_albedo.png", 1024, 512, concrete())
    write_png(OUT / "graffiti_albedo.png", 512, 512, graffiti())
    print("wrote", OUT)


if __name__ == "__main__":
    main()
