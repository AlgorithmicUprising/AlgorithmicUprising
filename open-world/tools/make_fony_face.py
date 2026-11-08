#!/usr/bin/env python3
"""Original face card for Fony. Not a copy of the concept drawing."""
import struct
import zlib
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "assets" / "library" / "fony" / "face_albedo.png"


def chunk(tag, data):
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)


def main() -> None:
    w = h = 256
    skin = (240, 201, 160)
    ink = (42, 33, 28)
    white = (248, 244, 236)
    blush = (214, 120, 110)
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        for x in range(w):
            col = skin
            if 48 < y < 64 and (40 < x < 110 or 146 < x < 216):
                col = ink
            if 78 < y < 128 and (52 < x < 108 or 148 < x < 204):
                col = white
                if 68 < x < 96 or 164 < x < 192:
                    if 90 < y < 122:
                        col = ink
            if 150 < y < 168 and 108 < x < 148:
                col = blush
            if 176 < y < 196 and 88 < x < 168:
                col = blush
            raw.extend(col)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_bytes(png)
    print(OUT)


if __name__ == "__main__":
    main()
