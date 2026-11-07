#!/usr/bin/env python3
"""Build the Cookie Wall Fony art pack from original pixel/vector primitives.

No source images are imported. The generated PNGs are reproducible, native-size
sprite art; gameplay labels remain live UI text and are not painted into bricks.
"""
from __future__ import annotations

import json
import random
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
BASE = ROOT.parent if ROOT.name == "source" else ROOT
OUT = BASE / "sprites"
OUT.mkdir(parents=True, exist_ok=True)
T = (0, 0, 0, 0)
C = {
    "void": "#090711", "bg": "#100b1c", "bg2": "#140d22", "grid": "#1d1530",
    "panel": "#21152e", "edge": "#442346", "edge2": "#70304e",
    "teal": "#35dfcc", "teal2": "#a0fff0", "tealD": "#146e74",
    "lime": "#c8ff45", "lime2": "#efffa2", "pink": "#f35b9f", "pink2": "#ffc0d2",
    "orange": "#ffad3f", "orange2": "#ffe39a", "purple": "#a96aff", "purple2": "#e0bdff",
    "cream": "#fff0d2", "shadow": "#08060d", "metal": "#554667", "steel": "#9b89aa",
    "muted": "#c0b4ca",
}

def rgba(color: str, alpha: int = 255):
    color = color.lstrip("#")
    return tuple(int(color[i:i+2], 16) for i in (0, 2, 4)) + (alpha,)

def new(size):
    return Image.new("RGBA", size, T)

def save(image: Image.Image, key: str, fmt="PNG"):
    suffix = ".webp" if fmt == "WEBP" else ".png"
    image.save(OUT / (key + suffix), format=fmt, lossless=True if fmt == "WEBP" else None)

def rect(d, box, fill, outline=None, width=1):
    if box[2] < box[0] or box[3] < box[1]:
        return
    d.rectangle(box, fill=rgba(fill) if isinstance(fill, str) else fill,
                outline=rgba(outline) if isinstance(outline, str) else outline, width=width)

def poly(d, points, fill, outline=None, width=1):
    d.polygon(points, fill=rgba(fill) if isinstance(fill, str) else fill)
    if outline:
        d.line(points + [points[0]], fill=rgba(outline) if isinstance(outline, str) else outline,
               width=width, joint="curve")

def line(d, points, fill, width=1):
    d.line(points, fill=rgba(fill) if isinstance(fill, str) else fill, width=width, joint="curve")

def court():
    im = Image.new("RGBA", (320, 320), C["bg"])
    d = ImageDraw.Draw(im)
    # Quiet playable field: subtle grid never competes with the packet or banners.
    for y in range(18, 320):
        if y % 4 == 0:
            shade = "#100b1d" if (y // 4) % 2 else "#110c20"
            rect(d, (8, y, 311, y), shade)
    for x in range(20, 320, 20):
        line(d, [(x, 18), (x, 315)], C["grid"])
    for y in range(20, 320, 20):
        line(d, [(8, y), (311, y)], C["grid"])
    # Browser-shell frame with an open lower drain; no fake platforms or collision lips.
    poly(d, [(0,0),(320,0),(320,14),(312,20),(8,20),(0,14)], C["panel"], C["shadow"])
    rect(d, (5, 4, 314, 8), C["edge"])
    rect(d, (14, 5, 55, 7), C["pink"])
    rect(d, (265, 5, 306, 7), C["teal"])
    for x in (8, 12, 308, 312):
        rect(d, (x, 4, x+1, 7), C["cream"])
    # Side rails sit exactly at court bounds, with abstract hardware and no labels.
    for side in ("left", "right"):
        x0 = 0 if side == "left" else 313
        x1 = 6 if side == "left" else 319
        rect(d, (x0, 18, x1, 294), C["panel"])
        edge_x = x1 if side == "left" else x0
        line(d, [(edge_x, 20), (edge_x, 292)], C["teal"] if side == "left" else C["pink"], 1)
        for y in (28, 76, 124, 172, 220, 268):
            if side == "left":
                poly(d, [(0,y),(5,y-4),(6,y-2),(6,y+7),(2,y+10),(0,y+7)], C["edge"], C["shadow"])
            else:
                poly(d, [(319,y),(314,y-4),(313,y-2),(313,y+7),(317,y+10),(319,y+7)], C["edge"], C["shadow"])
            rect(d, (2 if side == "left" else 316, y+1, 4 if side == "left" else 318, y+3), C["lime"])
        for y in (47, 101, 155, 209, 255):
            rect(d, (1 if side == "left" else 316, y, 5 if side == "left" else 318, y+1), C["teal"])
    # Corner equipment stops above the court floor and leaves the center drain open.
    poly(d, [(0,286),(24,281),(41,289),(55,297),(0,297)], C["panel"], C["shadow"])
    poly(d, [(320,286),(296,281),(279,289),(265,297),(320,297)], C["panel"], C["shadow"])
    line(d, [(4,294),(45,294)], C["pink"], 1)
    line(d, [(316,294),(275,294)], C["teal"], 1)
    # Sparse pixel glints and data dust, safely away from any implied obstacle.
    rng = random.Random(314)
    for _ in range(110):
        x, y = rng.randrange(12, 308), rng.randrange(24, 282)
        color = rng.choice(("#20162c", "#21172d", "#2a1836"))
        rect(d, (x, y, x, y), color)
    for x, y, color in ((36,42,C["pink"]),(286,51,C["teal"]),(53,255,C["purple"]),(270,238,C["orange"])):
        rect(d, (x,y,x+1,y), color)
    return im

def draw_symbol(d, kind, ink):
    dark = C["shadow"]
    if kind == "necessary":
        # Lock: a clear shackle, body and keyhole at 1x.
        line(d, [(13,8),(13,6),(14,4),(16,3),(18,3),(20,4),(21,6),(21,8)], C["cream"], 2)
        rect(d, (12,7,22,14), dark)
        rect(d, (13,8,21,13), ink)
        rect(d, (16,9,18,11), dark)
        rect(d, (16,11,18,13), dark)
    elif kind == "partners":
        # Three connected circles read as a partner network at 1x.
        line(d, [(11,9),(16,6),(22,9)], dark, 4)
        line(d, [(11,9),(16,6),(22,9)], ink, 2)
        for x,y in ((11,9),(16,6),(22,9)):
            rect(d, (x-2,y-2,x+2,y+2), C["shadow"])
            rect(d, (x-1,y-1,x+1,y+1), C["orange2"])
    elif kind == "interest":
        # Eye silhouette and pupil remain distinct from the purple tile.
        poly(d, [(10,9),(13,6),(17,5),(21,6),(24,9),(21,12),(17,13),(13,12)], C["cream"], dark)
        rect(d, (15,6,19,12), C["purple"])
        rect(d, (16,7,18,11), dark)
        rect(d, (17,8,17,9), C["cream"])
    else:
        # Reject All: strong crossed bars and no color-only coding.
        line(d, [(13,5),(21,13)], dark, 5)
        line(d, [(21,5),(13,13)], dark, 5)
        line(d, [(13,5),(21,13)], C["cream"], 3)
        line(d, [(21,5),(13,13)], C["cream"], 3)

def brick(kind, state="idle", phase=0):
    colors = {
        "necessary": (C["tealD"], C["teal"], C["teal2"]),
        "partners": ("#9a4b1b", C["orange"], C["orange2"]),
        "interest": ("#553387", C["purple"], C["purple2"]),
        "reject": ("#8f315a", C["pink"], C["pink2"]),
    }
    dark, body, light = colors[kind]
    im = new((34,18)); d=ImageDraw.Draw(im)
    if state == "break":
        if phase == 0:
            # First beat preserves the object silhouette and shows the split.
            im = brick(kind, "idle")
            d = ImageDraw.Draw(im)
            line(d, [(24,1),(21,6),(24,8),(20,12),(23,16)], C["shadow"], 3)
            line(d, [(24,1),(21,6),(24,8),(20,12),(23,16)], C["cream"], 1)
            rect(d,(20,7,21,8),C["lime"])
            return im
        if phase == 1:
            # Second beat: four recognizable chunks separate from the center.
            pieces=[
                ([(1,4),(4,2),(10,3),(10,7),(6,9),(2,8)],(-2,-1),light),
                ([(13,2),(20,2),(22,6),(19,9),(13,8)],(1,-2),body),
                ([(23,4),(30,3),(32,6),(30,11),(25,10)],(3,0),light),
                ([(9,11),(14,10),(19,12),(18,16),(11,15)],(-1,2),dark),
            ]
            for points,(dx,dy),fill in pieces:
                moved=[(max(0,min(33,x+dx)),max(0,min(17,y+dy))) for x,y in points]
                poly(d,moved,fill,C["shadow"])
                line(d,moved[:3],C["cream"],1)
            return im
        # Final beat: small shards fade outward; no text or false collision cue.
        shards=[(3,2,5,4),(11,5,13,7),(20,1,22,3),(29,5,31,7),
                (6,12,8,14),(16,13,18,15),(25,11,27,13)]
        for i,(x0,y0,x1,y1) in enumerate(shards):
            dx=(-3 if i%2==0 else 3); dy=(-2 if i<3 else 2)
            rect(d,(max(0,x0+dx),max(0,y0+dy),min(33,x1+dx),min(17,y1+dy)),(light,body,C["cream"])[i%3])
        return im
    # Eight-pixel chamfered casing around an inset, high-contrast face.
    poly(d, [(0,4),(3,1),(30,1),(33,4),(33,13),(30,16),(3,16),(0,13)], C["shadow"])
    poly(d, [(1,4),(4,2),(29,2),(32,4),(32,13),(29,15),(4,15),(1,13)], body, dark)
    line(d, [(4,3),(29,3)], light, 1)
    rect(d,(2,6,3,11),dark); rect(d,(30,6,31,11),dark)
    rect(d,(5,14,28,14),dark)
    # Small side rivets carry a repeated arcade cadence.
    rect(d,(4,6,5,7),light); rect(d,(28,6,29,7),light)
    draw_symbol(d,kind,light)
    if state == "crack":
        # Crack is offset so the icon is still the primary type cue.
        line(d, [(27,2),(24,6),(27,8),(23,11),(26,15)], C["shadow"], 3)
        line(d, [(27,2),(24,6),(27,8),(23,11),(26,15)], C["cream"], 1)
        rect(d,(24,7,25,8),C["lime"])
    return im

def blocker(state="idle", phase=0):
    im = new((64,16)); d=ImageDraw.Draw(im)
    color = C["teal"] if state == "idle" else (C["teal2"] if phase == 0 else C["lime"])
    poly(d, [(0,8),(4,3),(14,2),(22,5),(42,5),(50,2),(60,3),(64,8),(60,13),(50,14),(42,11),(22,11),(14,14),(4,13)], C["shadow"])
    poly(d, [(2,8),(5,4),(14,3),(22,6),(42,6),(50,3),(59,4),(62,8),(59,12),(50,13),(42,10),(22,10),(14,13),(5,12)], C["metal"], C["shadow"])
    # Teal energy caps and lime endpoint lights.
    poly(d, [(4,7),(7,4),(14,4),(19,6),(19,10),(14,12),(7,12),(4,9)], C["tealD"], C["shadow"])
    poly(d, [(60,7),(57,4),(50,4),(45,6),(45,10),(50,12),(57,12),(60,9)], C["tealD"], C["shadow"])
    rect(d,(8,6,15,9),color); rect(d,(49,6,56,9),color)
    rect(d,(10,5,14,5),C["teal2"]); rect(d,(50,5,54,5),C["teal2"])
    poly(d, [(20,6),(44,6),(47,8),(44,10),(20,10),(17,8)], C["shadow"])
    rect(d,(22,7,42,8),C["pink"] if state == "hit" else C["orange"])
    for x in (23,28,33,38): rect(d,(x,7,x+1,8),C["cream"] if state == "hit" and phase == 0 else C["orange2"])
    if state == "hit":
        for x in (2,61):
            rect(d,(x,1,x+1,2),C["lime"] if phase else C["teal2"])
            rect(d,(x,13,x+1,14),C["pink"] if phase else C["teal2"])
    return im

def ad_overlay(state="idle", phase=0):
    im=new((64,16)); d=ImageDraw.Draw(im)
    # Transparent carrier; only the small swappable patch bracket is drawn here.
    rect(d,(26,3,37,12),C["shadow"])
    rect(d,(27,4,36,11),C["panel"])
    line(d,[(27,4),(31,4)],C["lime"] if state=="idle" or phase==0 else C["teal"],1)
    line(d,[(32,11),(36,11)],C["pink"] if state=="hit" else C["teal"],1)
    rect(d,(25,6,26,9),C["steel"]); rect(d,(37,6,38,9),C["steel"])
    if state=="hit":
        rect(d,(29,2,30,3),C["lime"] if phase==0 else C["teal"])
        rect(d,(33,12,34,13),C["pink"] if phase else C["lime"])
    return im

def packet(frame):
    im=new((12,12)); d=ImageDraw.Draw(im)
    shapes=[
        [(5,0),(8,2),(11,5),(9,9),(6,11),(2,9),(0,5),(2,2)],
        [(5,0),(8,2),(10,5),(8,9),(6,11),(3,9),(1,5),(3,2)],
        [(5,1),(9,2),(11,5),(9,8),(6,11),(2,9),(0,5),(2,2)],
        [(5,0),(8,3),(10,5),(8,9),(6,11),(3,8),(1,5),(3,2)],
    ]
    poly(d,shapes[frame],C["lime"],C["shadow"])
    # Tiny data glint rotates with the packet; the square remains readable at 1x.
    rect(d,(4+(frame%2),4,6+(frame%2),6),C["teal"])
    rect(d,(5,3,6,3),C["cream"])
    return im

def tracker(frame):
    im=new((32,24)); d=ImageDraw.Draw(im)
    # A tiny fictional tracker-drain creature: surveillance lens above a comic mouth.
    poly(d,[(6,6),(10,2),(22,2),(26,6),(30,7),(30,18),(25,22),(7,22),(2,18),(2,7)],C["shadow"])
    poly(d,[(7,6),(11,3),(21,3),(25,6),(28,7),(28,17),(24,20),(8,20),(4,17),(4,7)],C["metal"],C["shadow"])
    rect(d,(9,7,13,12),C["lime"]); rect(d,(19,7,23,12),C["lime"])
    rect(d,(10,8,11,10),C["shadow"]); rect(d,(20,8,21,10),C["shadow"])
    line(d,[(5,5),(3,1),(8,3)],C["pink"],2); line(d,[(27,5),(29,1),(24,3)],C["teal"],2)
    rect(d,(13,13,19,14),C["pink"])
    if frame==0:
        rect(d,(11,15,21,18),C["shadow"])
        for x in (12,15,18,21): rect(d,(x,15,x+1,16),C["cream"])
    else:
        rect(d,(12,15,20,17),C["shadow"])
        line(d,[(13,16),(16,18),(19,16)],C["cream"],1)
    rect(d,(0,10,3,14),C["teal"]); rect(d,(29,10,31,14),C["pink"])
    return im

def crumb(frame):
    im=new((8,8)); d=ImageDraw.Draw(im)
    sets=[[(3,0),(5,2),(4,4),(2,3)],[(5,1),(7,3),(5,5),(3,3)],[(2,2),(5,1),(6,4),(3,6)],[(3,1),(4,3),(6,5),(3,6),(1,3)]]
    cols=[C["teal"],C["pink"],C["orange"],C["lime"]]
    poly(d,sets[frame],cols[frame],C["shadow"])
    rect(d,(3,2,3,2),C["cream"])
    return im

FONT5 = {
    "A":[14,17,17,31,17,17,17],"C":[15,16,16,16,16,16,15],"E":[31,16,16,30,16,16,31],
    "I":[31,4,4,4,4,4,31],"K":[17,18,20,24,20,18,17],"L":[16,16,16,16,16,16,31],
    "O":[14,17,17,17,17,17,14],"W":[17,17,17,21,21,21,10]," ":[0,0,0,0,0,0,0],
}

def title_logo():
    im=new((320,96)); d=ImageDraw.Draw(im)
    # Decorative title plate only; live skin text is rendered by the DOM.
    poly(d,[(8,24),(18,17),(302,17),(312,24),(312,70),(302,77),(18,77),(8,70)],C["shadow"])
    poly(d,[(10,25),(19,19),(301,19),(310,25),(310,69),(301,75),(19,75),(10,69)],C["panel"],C["edge"])
    line(d,[(21,22),(105,22)],C["pink"],2); line(d,[(215,22),(299,22)],C["teal"],2)
    line(d,[(21,72),(101,72)],C["teal"],2); line(d,[(219,72),(299,72)],C["pink"],2)
    # A tiny consent-wall/cookie glyph sits at center; no words or protected marks.
    for x,col in ((137,C["teal"]),(147,C["orange"]),(157,C["purple"]),(167,C["pink"])):
        rect(d,(x,32,x+6,54),C["shadow"]); rect(d,(x+1,33,x+5,53),col)
        rect(d,(x+2,36,x+4,38),C["cream"])
    poly(d,[(151,27),(148,31),(151,33),(148,37),(151,41)],C["lime"],C["shadow"])
    # Side rails echo the court frame while leaving broad title space.
    for x in (25,289):
        rect(d,(x,34,x+5,58),C["shadow"]); rect(d,(x+1,35,x+4,57),C["teal"] if x<100 else C["pink"])
        rect(d,(x+2,39,x+3,41),C["cream"]); rect(d,(x+2,50,x+3,52),C["lime"])
    return im

def icon(name):
    im=new((16,16)); d=ImageDraw.Draw(im); ink=C["cream"]; hi=C["teal"]; dark=C["shadow"]
    if "sound_on" in name:
        poly(d,[(1,6),(4,6),(8,3),(8,13),(4,10),(1,10)],ink,dark)
        line(d,[(10,6),(12,8),(10,10)],hi,1); line(d,[(12,4),(15,8),(12,12)],hi,1)
    elif "sound_off" in name:
        poly(d,[(1,6),(4,6),(8,3),(8,13),(4,10),(1,10)],ink,dark)
        line(d,[(10,6),(14,10)],C["pink"],2); line(d,[(14,6),(10,10)],C["pink"],2)
    elif "pause" in name:
        rect(d,(3,3,6,13),ink); rect(d,(10,3,13,13),hi)
        rect(d,(2,2,7,14),dark); rect(d,(9,2,14,14),dark)
        rect(d,(3,3,6,13),ink); rect(d,(10,3,13,13),hi)
    elif "share" in name:
        rect(d,(2,8,13,14),dark); rect(d,(3,9,12,13),hi); rect(d,(4,10,11,12),C["panel"])
        line(d,[(8,12),(8,2)],ink,2); poly(d,[(4,6),(8,2),(12,6)],C["lime"],dark)
    else:
        # Compact eight-tooth gear and center socket.
        for x,y in ((6,1),(10,1),(6,13),(10,13)): rect(d,(x,y,x+1,y+1),ink)
        for x,y in ((1,6),(13,6),(1,10),(13,10)): rect(d,(x,y,x+1,y+1),hi)
        rect(d,(3,3,12,12),dark); rect(d,(4,4,11,11),ink); rect(d,(6,6,9,9),C["panel"])
    return im

def launch(frame):
    im=new((64,64)); d=ImageDraw.Draw(im)
    cx=31 if frame==0 else 32; cy=31 if frame==0 else 33
    for r,color in ((29,C["shadow"]),(27,C["tealD"]),(24,C["teal"]),(21,C["shadow"]),(18,C["panel"])):
        d.ellipse((cx-r,cy-r,cx+r,cy+r),fill=rgba(color))
    d.arc((cx-24,cy-24,cx+24,cy+24),205,320,fill=rgba(C["lime"]),width=3)
    # Up arrow is a symbol, not a baked label; frame 01 is the pressed state.
    offset=2 if frame else 0
    poly(d,[(32,13+offset),(19,30+offset),(27,30+offset),(27,47+offset),(37,47+offset),(37,30+offset),(45,30+offset)],C["cream"],C["shadow"])
    rect(d,(29,19+offset,34,36+offset),C["lime"])
    if frame==1:
        rect(d,(7,30,10,33),C["pink"]); rect(d,(53,29,56,32),C["orange"])
    return im

def all_frames():
    frames={}
    def add(key, image, size, anchor, fps=None, loop=None):
        suffix="webp" if key=="bg_court_00" else "png"
        save(image,key,"WEBP" if suffix=="webp" else "PNG")
        meta={"file":f"sprites/{key}.{suffix}","size":list(size),"anchor":list(anchor)}
        if fps is not None: meta["fps"]=fps
        if loop is not None: meta["loop"]=loop
        frames[key]=meta
    add("bg_court_00",court(),(320,320),(0,0))
    add("blocker_idle_00",blocker(),(64,16),(32,8))
    for i in range(2): add(f"blocker_hit_0{i}",blocker("hit",i),(64,16),(32,8),12,False)
    add("blocker_ad_idle_00",ad_overlay(),(64,16),(32,8))
    for i in range(2): add(f"blocker_ad_hit_0{i}",ad_overlay("hit",i),(64,16),(32,8),12,False)
    for kind in ("necessary","partners","interest","reject"):
        add(f"brick_{kind}_idle_00",brick(kind),(34,18),(17,9))
        if kind in ("interest","reject"):
            add(f"brick_{kind}_crack_00",brick(kind,"crack"),(34,18),(17,9))
        for i in range(3): add(f"brick_{kind}_break_0{i}",brick(kind,"break",i),(34,18),(17,9),12,False)
    for i in range(4): add(f"packet_spin_0{i}",packet(i),(12,12),(6,6),8,True)
    for i in range(2): add(f"tracker_idle_0{i}",tracker(i),(32,24),(16,12),4,True)
    for i in range(4): add(f"fx_crumb_0{i}",crumb(i),(8,8),(4,4),12,False)
    add("logo_title_00",title_logo(),(320,96),(0,0))
    for key in ("ui_sound_on_00","ui_sound_off_00","ui_pause_00","ui_share_00","ui_settings_00"):
        add(key,icon(key),(16,16),(8,8))
    for i in range(2): add(f"ui_btn_launch_0{i}",launch(i),(64,64),(32,32),8,False)
    return frames

def font(size):
    for path in ("/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf","/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"):
        try: return ImageFont.truetype(path,size)
        except OSError: pass
    return ImageFont.load_default()

def review_sheet():
    W,H=1480,1280
    im=Image.new("RGB",(W,H),"#100d19"); d=ImageDraw.Draw(im)
    f18,f14,f12=font(18),font(14),font(12)
    d.rectangle((0,0,W,9),fill=C["lime"])
    d.text((36,27),"COOKIE WALL  /  FULL ART PASS",font=f18,fill=C["cream"])
    d.text((36,56),"GUIDE-SIZE SPRITES  ·  VECTOR-BUILT PIXEL ART  ·  SYMBOLS ONLY ON BANNERS",font=f12,fill=C["teal"])
    # Court preview with authored layout, packet and blocker.
    bg=court()
    for row,kinds in enumerate((
        ["necessary","partners","necessary","partners","necessary","partners","necessary","partners"],
        ["partners","necessary","interest","interest","partners","reject","necessary","partners"],
        ["necessary","interest","reject","partners","interest","reject","partners","necessary"],
    )):
        for col,kind in enumerate(kinds):
            tile=brick(kind,"crack" if kind in ("interest","reject") and row==2 and col%2 else "idle")
            bg.alpha_composite(tile,(10+col*38,36+row*22))
    bg.alpha_composite(packet(1),(151,205)); bg.alpha_composite(blocker(),(128,278))
    bg.alpha_composite(tracker(0),(144,294))
    bg2=bg.convert("RGB").resize((640,640),Image.Resampling.NEAREST)
    d.text((36,100),"COURT  320×320  ·  LANDSCAPE / PORTRAIT SHARE ONE FIELD",font=f14,fill=C["cream"])
    im.paste(bg2,(36,130))
    d.rectangle((34,128,677,773),outline=C["steel"],width=2)
    # Banner family study; captions live outside game sprites.
    d.text((720,100),"CONSENT BANNERS  34×18  ·  NO IN-BLOCK WORDS",font=f14,fill=C["cream"])
    labels=[("NEEDED / Strictly Necessary","necessary"),("347 / Ad Partners","partners"),("INTEREST / Legitimate Interest","interest"),("REJECT / Reject All","reject")]
    for i,(label,kind) in enumerate(labels):
        y=143+i*99
        d.text((720,y),label,font=f14,fill=C["cream"])
        idle=brick(kind).resize((102,54),Image.Resampling.NEAREST)
        state=brick(kind,"crack" if kind in ("interest","reject") else "break",0).resize((102,54),Image.Resampling.NEAREST)
        im.paste(idle,(840,y+23),idle); im.paste(state,(1015,y+23),state)
        d.text((840,y+77),"IDLE",font=f12,fill=C["muted"]); d.text((1015,y+77),"CRACK / BREAK 00",font=f12,fill=C["muted"])
    # Lower strip: controls and supporting sprites, all shown nearest-neighbour.
    d.text((720,555),"SUPPORTING SPRITES",font=f14,fill=C["cream"])
    x=720
    for label,spr,scale in (("BLOCKER",blocker(),2),("PACKET",packet(0),4),("TRACKER",tracker(0),3),("PATCH",ad_overlay(),2)):
        scaled=spr.resize((spr.width*scale,spr.height*scale),Image.Resampling.NEAREST)
        im.paste(scaled,(x,585),scaled); d.text((x,660),label,font=f12,fill=C["muted"])
        x+=165
    d.text((720,700),"BREAK 00 → 01 → 02  ·  34×18",font=f14,fill=C["cream"])
    for i,kind in enumerate(("necessary","partners","interest","reject")):
        for phase in range(3):
            spr=brick(kind,"break",phase).resize((68,36),Image.Resampling.NEAREST)
            im.paste(spr,(720+i*180+phase*72,730),spr)
    d.text((720,790),"TITLE PLATE / LIVE CODE-VECTOR TYPE  ·  320×96",font=f14,fill=C["cream"])
    logo=title_logo().resize((640,192),Image.Resampling.NEAREST)
    im.paste(logo,(720,815),logo)
    d.text((810,880),"COOKIE WALL",font=font(42),fill=C["cream"],stroke_width=1,stroke_fill=C["pink"])
    d.text((720,1015),"UI ICONS 16×16  ·  LAUNCH BUTTON 64×64",font=f14,fill=C["cream"])
    for i,key in enumerate(("ui_sound_on_00","ui_sound_off_00","ui_pause_00","ui_share_00","ui_settings_00")):
        spr=icon(key).resize((48,48),Image.Resampling.NEAREST)
        im.paste(spr,(720+i*88,1045),spr)
        d.text((720+i*88,1098),key.replace("ui_","").replace("_00","").upper(),font=f12,fill=C["muted"])
    for i in range(2):
        spr=launch(i).resize((64,64),Image.Resampling.NEAREST)
        im.paste(spr,(1205+i*76,1040),spr)
        d.text((1205+i*76,1107),"IDLE" if i==0 else "PRESS",font=f12,fill=C["muted"])
    return im

if __name__ == "__main__":
    manifest=all_frames()
    (BASE/"frames.json").write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8")
    if "--preview" in sys.argv:
        preview=review_sheet()
        deliver=ROOT/"deliverables"; deliver.mkdir(exist_ok=True)
        preview.save(deliver/"Cookie Wall Full Art Review.png")
    print(f"Wrote {len(manifest)} frames to {OUT}")
    if "--preview" in sys.argv: print(f"Review: {deliver/'Cookie Wall Full Art Review.png'}")
