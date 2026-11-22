#!/usr/bin/env python3
"""Tiling skate-park concrete. Original, generated. Saw cuts meet at the borders so it repeats."""
import math
import struct
import zlib
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "assets" / "library" / "skate_park" / "park_concrete.png"
SIZE = 512
TAU = math.tau


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
    n = (int(x) * 374761393 + int(y) * 668265263) & 0xFFFFFFFF
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


def tile(u: float, v: float, freq: float) -> float:
    # sin/cos of the tile coordinate is continuous across the repeat, so the noise is too.
    ax = math.cos(u * TAU) * freq
    ay = math.sin(u * TAU) * freq
    bx = math.cos(v * TAU) * freq
    by = math.sin(v * TAU) * freq
    return noise(ax, bx) * 0.5 + noise(ay, by) * 0.5


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * max(0.0, min(1.0, t))) for i in range(3))


def main() -> None:
    base = (186, 178, 168)
    warm = (198, 188, 176)
    joint = (112, 106, 98)
    scuff = (150, 140, 128)
    wax = (96, 90, 84)
    rubber = (72, 68, 64)
    buf = bytearray(SIZE * SIZE * 3)
    cuts = 4
    for y in range(SIZE):
        v = y / SIZE
        for x in range(SIZE):
            u = x / SIZE
            n = tile(u, v, 3.2)
            n2 = tile(u + 0.37, v + 0.18, 7.5)
            col = mix(base, warm, n)
            col = mix(col, scuff, max(0.0, n2 - 0.62) * 1.6)
            # Saw-cut expansion joints. A cut on the 0 edge is the seam with the next tile.
            cell = 1.0 / cuts
            du = min(u % cell, cell - (u % cell)) * SIZE
            dv = min(v % cell, cell - (v % cell)) * SIZE
            if du < 1.2 or dv < 1.2:
                col = mix(col, joint, 0.85)
            elif du < 2.4 or dv < 2.4:
                col = mix(col, joint, 0.35)
            # Faint wax and rubber, kept off the border so the repeat stays even.
            wax_u = (u - 0.22) * SIZE
            wax_v = (v - 0.31) * SIZE
            if 18 < abs(wax_u) < 70 and abs(wax_v - wax_u * 0.15) < 3.5:
                col = mix(col, wax, 0.45)
            rub = (u - 0.62) * (u - 0.62) * 2.2 + (v - 0.58) * (v - 0.58)
            if rub < 0.012:
                col = mix(col, rubber, 0.35 * (1.0 - rub / 0.012))
            i = (y * SIZE + x) * 3
            buf[i] = col[0]
            buf[i + 1] = col[1]
            buf[i + 2] = col[2]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    write_png(OUT, SIZE, SIZE, bytes(buf))
    print(OUT, OUT.stat().st_size)


if __name__ == "__main__":
    main()
