#!/usr/bin/env python3
"""Cut out Fony's painted frames and pack a web atlas.

Source PNGs are paper-cream JPEGs saved as PNG. They are not transparent, and
the body scale and the sole position drift from frame to frame. This script:

- flood-fills the cream, including holes between the arms and the legs
- drops the ground shadow and loose gray speed-lines that touch the paper
- eats the cream fringe on the ink so the cutout has no paper halo
- scales each frame from the head width (pure back views keep scale 1, because
  the back of the hair measures narrower than the face)
- plants every frame on one foot pixel. Ollie, kickflip, and grab sit above
  that line by a fixed lift so the airborne pose is not stapled to the ground

Requires Pillow, numpy, and scipy.

    python3 tools/prepare_fony_sprites.py

Inputs default to art-src/fony2d/raw. Outputs:

    assets/library/fony2d/fony2d_atlas.png
    assets/library/fony2d/frames.json
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "art-src" / "fony2d" / "raw"
OUT_DIR = ROOT / "assets" / "library" / "fony2d"
ATLAS_NAME = "fony2d_atlas.png"

# Head width of the front and side masters, in source pixels.
REF_HEAD = 155.0
# Sole to the top of the hair, in metres, for a frame whose source height
# matches the idle-front master after the per-frame scale.
TARGET_BODY_M = 1.72
# How many source pixels become one atlas pixel. 5 keeps the pack small and
# the chase camera near 1:1.
DOWNSCALE = 5
# Transparent gutter between cells so linear filtering does not bleed.
GUTTER = 2

# Metres the lowest opaque pixel sits above the shared ground anchor.
AIR_LIFT_M = {
    "trick_ollie_front": 0.46,
    "trick_kickflip_front": 0.40,
    "trick_grab_front": 0.42,
}

DIRS = [
    "front",
    "front_right",
    "right",
    "back_right",
    "back",
    "back_left",
    "left",
    "front_left",
]


def cutout(rgb: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    src = rgb.astype(np.int16)
    border = np.concatenate([src[0], src[-1], src[:, 0], src[:, -1]], axis=0)
    bg = np.median(border, axis=0)
    dist = np.max(np.abs(src - bg), axis=2)
    chroma = src.max(axis=2) - src.min(axis=2)
    lum = src.mean(axis=2)

    # Flat paper, including enclosed gaps. The sheet is within a few levels of
    # the corner colour; ink and paint sit much further away.
    opaque = dist > 18
    for _ in range(3):
        edge = opaque & ndimage.binary_dilation(~opaque)
        fringe = edge & (dist <= 34) & (chroma <= 26) & (lum >= 175)
        if not fringe.any():
            break
        opaque &= ~fringe

    # Ground shadow and gray motion strokes are low-chroma and touch the paper.
    # Gray patches on the jacket do not, so the flood stops at the orange cloth.
    shadow_col = (chroma <= 34) & (lum >= 88) & (lum <= 186) & (dist >= 30)
    seeds = (~opaque) & ndimage.binary_dilation(shadow_col)
    if seeds.any():
        killed = ndimage.binary_propagation(seeds, mask=shadow_col | seeds)
        opaque &= ~(killed & shadow_col)

    stroke = (chroma <= 42) & (lum >= 160) & (dist >= 14) & (dist <= 72)
    seeds = (~opaque) & ndimage.binary_dilation(stroke)
    if seeds.any():
        killed = ndimage.binary_propagation(seeds, mask=stroke | seeds)
        opaque &= ~(killed & stroke)

    labels, count = ndimage.label(opaque)
    if count:
        sizes = np.bincount(labels.ravel())
        sizes[0] = 0
        keep = sizes >= 1400
        keep[int(sizes.argmax())] = True
        opaque = keep[labels]

    rgb_u = np.clip(src, 0, 255).astype(np.uint8)
    rgb_u = _defringe(rgb_u, opaque, bg)
    return rgb_u, opaque, bg


def _defringe(rgb: np.ndarray, opaque: np.ndarray, bg: np.ndarray) -> np.ndarray:
    dist = np.max(np.abs(rgb.astype(np.int16) - bg), axis=2)
    interior = ndimage.binary_erosion(opaque, iterations=2) & (dist > 60)
    if not interior.any():
        return rgb
    _distmap, indices = ndimage.distance_transform_edt(~interior, return_indices=True)
    edge = opaque & ~ndimage.binary_erosion(opaque, iterations=1)
    take = edge & (dist < 48) & (_distmap <= 5)
    out = rgb.copy()
    out[take] = rgb[indices[0][take], indices[1][take]]
    return out


def _measures(opaque: np.ndarray) -> dict:
    ys, xs = np.where(opaque)
    top = int(ys.min())
    bot = int(ys.max())
    height = bot - top + 1
    band = ys <= top + max(8, int(height * 0.11))
    hx = float(np.median(xs[band]))
    y0 = top + int(height * 0.04)
    y1 = top + int(height * 0.16)
    sel = (ys >= y0) & (ys <= y1) & (np.abs(xs - hx) <= 90)
    if int(sel.sum()) < 12:
        head_w = REF_HEAD
    else:
        head_w = float(np.percentile(xs[sel], 95) - np.percentile(xs[sel], 5))
    foot_rows = ys >= bot - max(4, int(height * 0.03))
    near = foot_rows & (np.abs(xs - hx) <= max(80, int(height * 0.28)))
    if int(near.sum()) < 8:
        near = foot_rows
    fx = float(np.median(xs[near])) if near.any() else hx
    return {
        "top": top,
        "bot": bot,
        "height": height,
        "hx": hx,
        "fx": fx,
        "head_w": head_w,
        "left": int(xs.min()),
        "right": int(xs.max()),
    }


def _scale_for(name: str, measures: dict) -> float:
    # Back-of-head silhouettes measure narrower than the face even when the
    # drawing is the same size, so only trust head width in the front/side band.
    del name
    head_w = measures["head_w"]
    if head_w < 148 or head_w > 166:
        return 1.0
    return float(np.clip(REF_HEAD / head_w, 0.96, 1.04))


def _paste(rgb: np.ndarray, opaque: np.ndarray, measures: dict, scale: float, lift_px: float, cell_w: int, cell_h: int, anchor: tuple[int, int]) -> np.ndarray:
    ys, xs = np.where(opaque)
    top, bot = int(ys.min()), int(ys.max())
    left, right = int(xs.min()), int(xs.max())
    crop_rgb = rgb[top : bot + 1, left : right + 1]
    crop_a = opaque[top : bot + 1, left : right + 1]
    scaled_w = max(1, int(round((right - left + 1) * scale)))
    scaled_h = max(1, int(round((bot - top + 1) * scale)))
    im = Image.fromarray(np.dstack([crop_rgb, crop_a.astype(np.uint8) * 255]), "RGBA")
    im = im.resize((scaled_w, scaled_h), Image.Resampling.LANCZOS)
    # LANCZOS revives a faint paper fringe. Snap alpha back to a hard edge.
    arr = np.array(im)
    arr[..., 3] = np.where(arr[..., 3] >= 48, 255, 0).astype(np.uint8)
    sy, sx = np.where(arr[..., 3] > 0)
    if len(sy) == 0:
        raise RuntimeError("empty frame after scale")
    # Head x keeps the skull on the capsule axis when the camera picks another
    # direction. The pushing foot and the deck extend away from that axis.
    # lift_px is already in the scaled pixel space (before the atlas downscale).
    ax_s = (measures["hx"] - left) * scale
    ay_s = (measures["bot"] - top) * scale + lift_px
    origin_x = int(round(anchor[0] - ax_s))
    origin_y = int(round(anchor[1] - ay_s))
    canvas = np.zeros((cell_h, cell_w, 4), dtype=np.uint8)
    src_y0 = max(0, -origin_y)
    src_x0 = max(0, -origin_x)
    dst_y0 = max(0, origin_y)
    dst_x0 = max(0, origin_x)
    copy_h = min(arr.shape[0] - src_y0, cell_h - dst_y0)
    copy_w = min(arr.shape[1] - src_x0, cell_w - dst_x0)
    if copy_h <= 0 or copy_w <= 0:
        raise RuntimeError("frame missed the cell")
    canvas[dst_y0 : dst_y0 + copy_h, dst_x0 : dst_x0 + copy_w] = arr[src_y0 : src_y0 + copy_h, src_x0 : src_x0 + copy_w]
    return canvas


def main() -> int:
    raw = Path(sys.argv[1]) if len(sys.argv) > 1 else RAW
    names = sorted(p.stem for p in raw.glob("*.png"))
    if not names:
        print("no pngs in", raw, file=sys.stderr)
        return 1
    loaded = {}
    for name in names:
        rgb = np.asarray(Image.open(raw / f"{name}.png").convert("RGB"))
        cut_rgb, opaque, _bg = cutout(rgb)
        measures = _measures(opaque)
        scale = _scale_for(name, measures)
        lift_m = AIR_LIFT_M.get(name, 0.0)
        loaded[name] = {
            "rgb": cut_rgb,
            "opaque": opaque,
            "measures": measures,
            "scale": scale,
            "lift_m": lift_m,
        }
        print(
            f"{name:24} h={measures['height']:4} head={measures['head_w']:6.1f} "
            f"scale={scale:.3f} hx={measures['hx']:.0f} fx={measures['fx']:.0f} lift={lift_m:.2f}"
        )

    # Learn the cell from source-pixel extents, then downscale each finished cell.
    body_px = [
        frame["measures"]["height"] * frame["scale"] / DOWNSCALE
        for name, frame in loaded.items()
        if name.startswith("idle_")
    ]
    pixel_size = TARGET_BODY_M / float(np.median(body_px))
    for frame in loaded.values():
        frame["lift_src"] = frame["lift_m"] / pixel_size * DOWNSCALE if frame["lift_m"] else 0.0

    max_left = 1.0
    max_right = 1.0
    max_up = 1.0
    for frame in loaded.values():
        m = frame["measures"]
        scale = frame["scale"]
        max_left = max(max_left, (m["hx"] - m["left"]) * scale)
        max_right = max(max_right, (m["right"] - m["hx"]) * scale)
        max_up = max(max_up, m["height"] * scale + frame["lift_src"])
    pad = 10
    src_w = int(np.ceil((max_left + max_right) / DOWNSCALE)) + pad * 2
    src_h = int(np.ceil(max_up / DOWNSCALE)) + pad * 2
    if src_w % 2:
        src_w += 1
    if src_h % 2:
        src_h += 1
    anchor = (src_w // 2, src_h - pad)
    order = names
    cols = 8
    rows = int(np.ceil(len(order) / cols))
    atlas_w = cols * src_w + (cols + 1) * GUTTER
    atlas_h = rows * src_h + (rows + 1) * GUTTER
    atlas = np.zeros((atlas_h, atlas_w, 4), dtype=np.uint8)
    meta_frames = {}
    sheet = Image.new("RGBA", (cols * (src_w + 8), rows * (src_h + 8)), (30, 24, 28, 255))
    for index, name in enumerate(order):
        frame = loaded[name]
        # Build the cell in source resolution, then downscale, so the foot
        # anchor survives the resize as an integer pixel.
        big_w = src_w * DOWNSCALE
        big_h = src_h * DOWNSCALE
        big_anchor = (anchor[0] * DOWNSCALE, anchor[1] * DOWNSCALE)
        cell_big = _paste(
            frame["rgb"],
            frame["opaque"],
            frame["measures"],
            frame["scale"],
            frame["lift_src"],
            big_w,
            big_h,
            big_anchor,
        )
        cell = np.array(Image.fromarray(cell_big, "RGBA").resize((src_w, src_h), Image.Resampling.BOX))
        # BOX on binary alpha can leave gray. Snap again.
        cell[..., 3] = np.where(cell[..., 3] >= 40, 255, 0).astype(np.uint8)
        # Bleed RGB into transparent texels so a linear filter does not pull black.
        cell = _bleed(cell)
        col = index % cols
        row = index // cols
        x = GUTTER + col * (src_w + GUTTER)
        y = GUTTER + row * (src_h + GUTTER)
        atlas[y : y + src_h, x : x + src_w] = cell
        meta_frames[name] = {
            "x": x,
            "y": y,
            "w": src_w,
            "h": src_h,
            "lift_m": frame["lift_m"],
        }
        preview = Image.fromarray(cell, "RGBA")
        backdrop = Image.new("RGBA", preview.size, (40, 28, 36, 255))
        sheet.paste(Image.alpha_composite(backdrop, preview), ((src_w + 8) * col + 4, (src_h + 8) * row + 4))

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    Image.fromarray(atlas, "RGBA").save(OUT_DIR / ATLAS_NAME, optimize=True)
    meta = {
        "atlas": ATLAS_NAME,
        "cell_w": src_w,
        "cell_h": src_h,
        "anchor_x": anchor[0],
        "anchor_y": anchor[1],
        "pixel_size": round(pixel_size, 6),
        "foot_local_y": 0.325,
        "gutter": GUTTER,
        "dirs": DIRS,
        "frames": meta_frames,
        "notes": [
            "Direction suffix is the way Fony faces on screen.",
            "anchor_x/anchor_y is the shared ground point in every cell.",
            "lift_m raises airborne trick poses above that ground point.",
            "Transitions and tricks are front-only in the runtime.",
            "face_front was not in the delivered PNG set.",
        ],
    }
    (OUT_DIR / "frames.json").write_text(json.dumps(meta, indent=2) + "\n")
    sheet_path = Path("/tmp/fony-atlas-sheet.png")
    sheet.convert("RGB").save(sheet_path, optimize=True)
    print(f"atlas {atlas_w}x{atlas_h} cell {src_w}x{src_h} anchor {anchor} pixel_size {pixel_size:.5f}")
    print("bytes", (OUT_DIR / ATLAS_NAME).stat().st_size)
    print("sheet", sheet_path)
    return 0


def _bleed(cell: np.ndarray) -> np.ndarray:
    """Copy edge colour into transparent texels so bilinear samples stay ink-coloured."""
    alpha = cell[..., 3] > 0
    if not alpha.any() or alpha.all():
        return cell
    _dist, indices = ndimage.distance_transform_edt(~alpha, return_indices=True)
    out = cell.copy()
    hole = ~alpha
    out[hole, 0] = cell[indices[0][hole], indices[1][hole], 0]
    out[hole, 1] = cell[indices[0][hole], indices[1][hole], 1]
    out[hole, 2] = cell[indices[0][hole], indices[1][hole], 2]
    out[hole, 3] = 0
    return out


if __name__ == "__main__":
    sys.exit(main())
