#!/usr/bin/env python3
"""Original face card for Fony. Not a copy of the concept drawing."""
import struct
import zlib
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "assets" / "library" / "fony" / "face_albedo.png"


def chunk(tag, data):
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)


def main() -> None:
    w = h = 128
    skin = (240, 201, 160)
    ink = (42, 33, 28)
    blush = (214, 140, 120)
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        for x in range(w):
            col = skin
            if 28 < y < 36 and (24 < x < 48 or 80 < x < 104):
                col = ink
            if 40 < y < 58 and (30 < x < 50 or 78 < x < 98):
                col = (250, 244, 236)
                if 34 < x < 46 or 82 < x < 94:
                    if 44 < y < 56:
                        col = ink
            if 78 < y < 88 and 48 < x < 80:
                col = blush
            raw.extend(col)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_bytes(png)
    print(OUT)


if __name__ == "__main__":
    main()
