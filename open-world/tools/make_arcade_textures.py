#!/usr/bin/env python3
"""Arcade exterior textures (Phase 1, LOCAL).

Builds two textures from art-src/arcade:
  assets/arcade/arcade_trim.png   512x512 greyscale trim sheet, four 256 px tiles
                                  (concrete, roll-up shutter slats, box-profile sheet, rust/weathering).
                                  Posterized from CC0 Poly Haven sources; the toon shader tints it.
  assets/arcade/arcade_art.png    2048x1024 atlas of our own art: marquee, wheatpaste covers,
                                  Zero glyph neon, and the three mural candidates.
  assets/arcade/arcade_screens.png 1024x768 interior atlas (Phase 2): cabinet screens and marquees from the
                                  Punk Arcade covers on algorithmicuprising.com, the Zero screen face, the
                                  ZERO GAME THING PRO 2K side art, the Bars per Watt sign and power-rack cells.
                                  Text is rasterized here (URW Nimbus Sans Narrow Bold, the site display face);
                                  no font file ships in the pck.
and writes scripts/arcade_atlas.gd with the UV rects (RECTS for the art atlas, SCREENS for the interior one).
Needs Pillow.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "art-src" / "arcade"
OUT = ROOT / "assets" / "arcade"
PAD = 6


def trim_sheet() -> None:
    tiles = [
        "concrete_floor_worn_001_diff_1k.jpg",
        "painted_metal_shutter_diff_1k.jpg",
        "box_profile_metal_sheet_diff_1k.jpg",
        "rusty_metal_sheet_diff_1k.jpg",
    ]
    sheet = Image.new("L", (512, 512))
    for i, name in enumerate(tiles):
        im = Image.open(SRC / "cc0" / name).convert("L").resize((256, 256), Image.LANCZOS)
        blur = 0.8 if i in (1, 2) else 2.2
        im = ImageOps.autocontrast(im.filter(ImageFilter.GaussianBlur(blur)), cutoff=2)
        im = ImageOps.posterize(im.convert("RGB"), 2).convert("L")
        # lift the floor so the tint never goes to pure dark_color everywhere
        im = im.point(lambda v: int(70 + v * 185 / 255))
        sheet.paste(im, ((i % 2) * 256, (i // 2) * 256))
    sheet.save(OUT / "arcade_trim.png", optimize=True)


def crop_band(path: Path, y0: int, y1: int) -> Image.Image:
    im = Image.open(path).convert("RGB")
    return im.crop((0, y0, im.width, y1))


def art_atlas() -> dict:
    atlas = Image.new("RGBA", (2048, 1024), (18, 19, 16, 255))
    rects = {}

    def put(name: str, im: Image.Image, x: int, y: int, w: int, h: int) -> None:
        im = im.convert("RGBA").resize((w, h), Image.LANCZOS)
        # edge-extend padding so mipmaps do not bleed neighbours
        padded = im.resize((w + PAD * 2, h + PAD * 2), Image.NEAREST)
        padded.paste(im, (PAD, PAD))
        atlas.paste(padded, (x - PAD, y - PAD))
        rects[name] = (x / 2048.0, y / 1024.0, w / 2048.0, h / 1024.0)

    m = SRC / "murals"
    put("mural_b", crop_band(m / "mural_B_press_start_raw.jpg", 75, 640), PAD, PAD, 1012, 446)
    put("mural_c", crop_band(m / "mural_C_high_score_raw.jpg", 105, 620), 1024 + PAD, PAD, 1012, 407)
    put("mural_a", crop_band(m / "mural_A_insert_human_raw.jpg", 20, 700), PAD, 470, 1012, 538)
    c = SRC / "covers"
    put("marquee", Image.open(c / "marquee_punk_arcade.png"), 1024 + PAD, 430, 1012, 158)
    x = 1024 + PAD
    for name, w in [("do-not-feed-the-algorithm", 190), ("the-human-zoo", 190), ("the-alignment-problem", 285)]:
        put(name, Image.open(c / f"{name}.jpg"), x, 600, w, 285)
        x += w + PAD * 2
    put("zero-cover-band", Image.open(c / "zero-cover-band.jpg"), x, 600, 311, 233)
    put("deadpan-flow", Image.open(c / "deadpan-flow.jpg"), 1024 + PAD, 897, 215, 121)
    put("zero_glyph", Image.open(c / "zero_glyph_acid.png"), 1024 + PAD + 227, 897, 121, 121)
    stripe = Image.new("RGBA", (64, 64))
    for yy in range(64):
        for xx in range(64):
            stripe.putpixel((xx, yy), (240, 193, 74, 255) if ((xx + yy) // 16) % 2 == 0 else (18, 19, 16, 255))
    put("caution", stripe, 1024 + PAD + 360, 897, 121, 121)
    # solar cell tile: dark blue cells with light grid lines
    cell = Image.new("RGBA", (128, 128), (29, 60, 110, 255))
    for yy in range(128):
        for xx in range(128):
            if xx % 32 < 2 or yy % 32 < 2:
                cell.putpixel((xx, yy), (170, 190, 215, 255))
            elif (xx // 32 + yy // 32) % 2 == 0:
                cell.putpixel((xx, yy), (36, 74, 132, 255))
    put("solar", cell, 1024 + PAD + 493, 897, 121, 121)
    atlas.convert("RGB").save(OUT / "arcade_art.png", optimize=True)
    return rects


FONT_DISPLAY = "/usr/share/fonts/opentype/urw-base35/NimbusSansNarrow-Bold.otf"
FONT_MONO = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf"
ACID = (219, 255, 0)
COOLANT = (46, 196, 182)
PINK = (255, 61, 127)
INK = (18, 19, 16)
PAPER = (247, 241, 232)


def font(path: str, size: int) -> ImageFont.FreeTypeFont:
    try:
        return ImageFont.truetype(path, size)
    except OSError:
        return ImageFont.load_default()


def text_center(d: ImageDraw.ImageDraw, box, txt: str, fnt, fill, stroke=0, stroke_fill=INK) -> None:
    l, t, r, b = d.textbbox((0, 0), txt, font=fnt, stroke_width=stroke)
    x = box[0] + (box[2] - box[0] - (r - l)) / 2 - l
    y = box[1] + (box[3] - box[1] - (b - t)) / 2 - t
    d.text((x, y), txt, font=fnt, fill=fill, stroke_width=stroke, stroke_fill=stroke_fill)


def fit_font(d, txt: str, path: str, w: int, h: int, start: int = 200):
    size = start
    while size > 8:
        f = font(path, size)
        l, t, r, b = d.textbbox((0, 0), txt, font=f, stroke_width=2)
        if r - l <= w and b - t <= h:
            return f
        size -= 2
    return font(path, 8)


def cover_crop(im: Image.Image, w: int, h: int, cx=0.5, cy=0.5) -> Image.Image:
    im = im.convert("RGBA")
    s = max(w / im.width, h / im.height)
    im = im.resize((max(w, round(im.width * s)), max(h, round(im.height * s))), Image.LANCZOS)
    x = int((im.width - w) * cx)
    y = int((im.height - h) * cy)
    return im.crop((x, y, x + w, y + h))


def marquee(txt: str, bg, fg, w=488, h=104) -> Image.Image:
    im = Image.new("RGBA", (w, h), bg)
    d = ImageDraw.Draw(im)
    d.rectangle((3, 3, w - 4, h - 4), outline=fg, width=3)
    text_center(d, (10, 6, w - 10, h - 6), txt, fit_font(d, txt, FONT_DISPLAY, w - 28, h - 26, 90), fg, 2)
    return im


def screens_atlas() -> dict:
    W, H = 1024, 768
    atlas = Image.new("RGBA", (W, H), INK + (255,))
    rects = {}

    def put(name: str, im: Image.Image, x: int, y: int, w: int, h: int) -> None:
        im = im.convert("RGBA").resize((w, h), Image.LANCZOS)
        padded = im.resize((w + PAD * 2, h + PAD * 2), Image.NEAREST)
        padded.paste(im, (PAD, PAD))
        atlas.paste(padded, (x - PAD, y - PAD))
        rects[name] = (x / W, y / H, w / W, h / H)

    s = SRC / "screens"
    sw, sh = 488, 360   # drawn at 2x, packed at 244x180

    def cell(i: int, row: int):
        return i * 256 + PAD, row * 192 + PAD, 244, 180

    grind = cover_crop(Image.open(s / "grind-title-card.jpg"), sw, sh, 0.18, 0.5)
    d = ImageDraw.Draw(grind)
    text_center(d, (0, sh - 92, sw, sh - 10), "GRIND THE TERMS", fit_font(d, "GRIND THE TERMS", FONT_DISPLAY, 448, 70, 64), PAPER, 4)
    put("s_grind", grind, *cell(0, 0))
    tag = cover_crop(Image.open(s / "tag-background.png"), sw, sh)
    title = Image.open(s / "tag-title.png").convert("RGBA")
    title = title.resize((sw - 30, round((sw - 30) * title.height / title.width)), Image.LANCZOS)
    tag.alpha_composite(title, (15, (sh - title.height) // 2))
    put("s_tag", tag, *cell(1, 0))
    cookie = cover_crop(Image.open(s / "cookie-court.webp"), sw, sh)
    logo = Image.open(s / "cookie-logo.png").convert("RGBA").resize((sw - 40, round((sw - 40) * 96 / 320)), Image.NEAREST)
    cookie.alpha_composite(logo, (20, 40))
    d = ImageDraw.Draw(cookie)
    text_center(d, (0, 190, sw, 290), "COOKIE WALL", font(FONT_DISPLAY, 76), PINK, 4)
    put("s_cookie", cookie, *cell(2, 0))
    bpw = Image.new("RGBA", (sw, sh), (12, 10, 22, 255))
    d = ImageDraw.Draw(bpw)
    lane_cols = [PINK, COOLANT, ACID, (255, 170, 60)]
    for k in range(4):
        x0 = 70 + k * 90
        d.rectangle((x0, 20, x0 + 70, sh - 70), fill=(24, 22, 40, 255), outline=(60, 56, 90, 255), width=2)
        for n in range(3):
            y = 40 + ((k * 53 + n * 97) % 200)
            d.rounded_rectangle((x0 + 6, y, x0 + 64, y + 18), 6, fill=lane_cols[k])
        d.rectangle((x0, sh - 92, x0 + 70, sh - 84), fill=lane_cols[k])
    text_center(d, (0, sh - 66, sw, sh - 6), "BARS PER WATT", font(FONT_DISPLAY, 56), ACID, 3)
    put("s_bpw", bpw, *cell(3, 0))
    face = Image.open(s / "zero_screen_face_640x480.png").convert("RGBA")
    put("s_zero", cover_crop(face, sw, sh), *cell(0, 1))
    zgt = Image.new("RGBA", (sw, sh), (10, 12, 10, 255))
    d = ImageDraw.Draw(zgt)
    text_center(d, (0, 30, sw, 120), "ZERO GAME THING", fit_font(d, "ZERO GAME THING", FONT_DISPLAY, 438, 80, 64), ACID, 3)
    text_center(d, (0, 120, sw, 230), "PRO 2K", font(FONT_DISPLAY, 110), PAPER, 4)
    text_center(d, (0, 250, sw, 320), "PRESS  Ø  TO PLAY", font(FONT_MONO, 34), COOLANT, 2)
    put("s_zgt", zgt, *cell(1, 1))
    soon = Image.new("RGBA", (sw, sh), (16, 15, 22, 255))
    d = ImageDraw.Draw(soon)
    import random
    rnd = random.Random(7)
    for _ in range(2600):
        x, y = rnd.randrange(sw), rnd.randrange(sh)
        v = rnd.randrange(30, 90)
        d.point((x, y), fill=(v, v, v + 10, 255))
    text_center(d, (0, 110, sw, 250), "INSERT HUMAN", font(FONT_DISPLAY, 70), (180, 180, 190), 3)
    put("s_soon", soon, *cell(2, 1))
    hs = Image.new("RGBA", (sw, sh), (14, 10, 18, 255))
    d = ImageDraw.Draw(hs)
    text_center(d, (0, 14, sw, 80), "HIGH SCORES", font(FONT_DISPLAY, 58), ACID, 3)
    fm = font(FONT_MONO, 32)
    for k, (n, v) in enumerate([("ZERO", "999999"), ("FONY", "420069"), ("YOU?", "000000")]):
        d.text((50, 110 + k * 66), f"{k + 1}  {n}", font=fm, fill=PAPER)
        d.text((300, 110 + k * 66), v, font=fm, fill=PINK)
    put("s_hiscore", hs, *cell(3, 1))

    def mcell(i: int, row: int):
        return i * 256 + PAD, 384 + row * 64 + PAD, 244, 52

    put("m_grind", marquee("GRIND THE TERMS", (32, 10, 26, 255), PINK), *mcell(0, 0))
    put("m_tag", marquee("TAG BEFORE TRAINING", (14, 26, 30, 255), COOLANT), *mcell(1, 0))
    put("m_cookie", marquee("COOKIE WALL", (30, 16, 30, 255), (255, 200, 90)), *mcell(2, 0))
    put("m_bpw", marquee("BARS PER WATT", (10, 24, 12, 255), ACID), *mcell(3, 0))
    put("m_zgt", marquee("ZERO GAME THING PRO 2K", (10, 10, 10, 255), ACID), *mcell(0, 1))
    put("m_soon", marquee("PUNK ARCADE", (24, 18, 30, 255), (200, 190, 210)), *mcell(1, 1))
    put("m_hq", marquee("HQ TEST CABINET", (40, 28, 20, 255), (224, 161, 90)), *mcell(2, 1))
    put("m_tokens", marquee("TOKENS  ·  PRIZES", (26, 12, 18, 255), (255, 120, 160)), *mcell(3, 1))
    # featured cabinet side art: Zero glyph, PRO 2K, acid/coolant stripes
    side = Image.new("RGBA", (232, 488), (14, 14, 12, 255))
    d = ImageDraw.Draw(side)
    for k in range(9):
        y = 300 + k * 22
        d.polygon([(0, y), (232, y - 60), (232, y - 50), (0, y + 10)], fill=ACID if k % 2 == 0 else COOLANT)
    glyph = Image.open(SRC / "covers" / "zero_glyph_acid.png").convert("RGBA").resize((180, 180), Image.LANCZOS)
    side.alpha_composite(glyph, (26, 30))
    text_center(d, (0, 214, 232, 280), "PRO 2K", fit_font(d, "PRO 2K", FONT_DISPLAY, 200, 60, 64), PAPER, 3)
    text_center(d, (0, 440, 232, 484), "MODEL Ø-1", font(FONT_MONO, 26), ACID, 1)
    put("side_zgt", side, PAD, 512 + PAD, 116, 244)
    side2 = Image.new("RGBA", (232, 488), (10, 22, 12, 255))
    d = ImageDraw.Draw(side2)
    for k in range(4):
        d.rectangle((40 + k * 40, 60, 66 + k * 40, 420), fill=lane_cols[k])
    text_center(d, (0, 0, 232, 56), "BPW", font(FONT_DISPLAY, 50), ACID, 2)
    put("side_bpw", side2, 128 + PAD, 512 + PAD, 116, 244)
    sign = Image.new("RGBA", (1000, 232), (10, 12, 10, 255))
    d = ImageDraw.Draw(sign)
    text_center(d, (0, 0, 1000, 160), "BARS PER WATT", fit_font(d, "BARS PER WATT", FONT_DISPLAY, 920, 140, 150), ACID, 5)
    text_center(d, (0, 160, 1000, 228), "POWER RACK  ·  PUNK ARCADE", font(FONT_MONO, 44), COOLANT, 2)
    put("bpw_sign", sign, 256 + PAD, 512 + PAD, 500, 116)
    counter = Image.new("RGBA", (1000, 232), (26, 12, 18, 255))
    d = ImageDraw.Draw(counter)
    text_center(d, (0, 0, 1000, 160), "TOKENS · PRIZES", fit_font(d, "TOKENS · PRIZES", FONT_DISPLAY, 920, 140, 140), (255, 120, 160), 5)
    text_center(d, (0, 160, 1000, 228), "NO REFUNDS ON YOUR DATA", font(FONT_MONO, 44), PAPER, 2)
    put("counter_sign", counter, 256 + PAD, 640 + PAD, 500, 116)
    rack = Image.new("RGBA", (488, 232), (8, 14, 10, 255))
    d = ImageDraw.Draw(rack)
    for r in range(3):
        for c in range(8):
            x0, y0 = 10 + c * 59, 12 + r * 72
            lvl = (c * 37 + r * 11) % 5
            d.rectangle((x0, y0, x0 + 50, y0 + 62), fill=(16, 30, 20, 255), outline=(60, 90, 70, 255), width=2)
            for k in range(5):
                col = ACID if k < 5 - lvl else (30, 50, 36)
                d.rectangle((x0 + 8, y0 + 50 - k * 11, x0 + 42, y0 + 57 - k * 11), fill=col)
    put("rack", rack, 768 + PAD, 512 + PAD, 244, 116)
    rug = Image.new("RGBA", (488, 232), (40, 14, 30, 255))
    d = ImageDraw.Draw(rug)
    d.rectangle((10, 10, 477, 221), outline=ACID, width=8)
    glyph2 = Image.open(SRC / "covers" / "zero_glyph_acid.png").convert("RGBA").resize((170, 170), Image.LANCZOS)
    rug.alpha_composite(glyph2, (159, 31))
    put("rug", rug, 768 + PAD, 640 + PAD, 244, 116)
    atlas.convert("RGB").save(OUT / "arcade_screens.png", optimize=True)
    return rects


def write_rects(rects: dict, screens: dict) -> None:
    lines = ["extends RefCounted", "", "# Generated by tools/make_arcade_textures.py. UV rects (x, y, w, h) in arcade_art.png.", "const RECTS := {"]
    for k, (x, y, w, h) in rects.items():
        lines.append('\t"%s": Rect2(%.6f, %.6f, %.6f, %.6f),' % (k, x, y, w, h))
    lines.append("}")
    lines += ["", "# UV rects in arcade_screens.png (interior screens, marquees, signs).", "const SCREENS := {"]
    for k, (x, y, w, h) in screens.items():
        lines.append('\t"%s": Rect2(%.6f, %.6f, %.6f, %.6f),' % (k, x, y, w, h))
    lines.append("}")
    (ROOT / "scripts" / "arcade_atlas.gd").write_text("\n".join(lines) + "\n")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    trim_sheet()
    write_rects(art_atlas(), screens_atlas())
    print("ok")
