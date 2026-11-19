"""Re-pack the puppet-v1 web atlases from the approved 510x648 master frames.

Nov 15 2026: the user approved shipping the full-size masters (scale_from_master 1.0, ~480 px
standing) for a crisp Fony. Frames are only copied (or Lanczos-downscaled when AU_ATLAS_SCALE < 1),
never redrawn and never mirrored. Identical tiles share one atlas rect. Each view group
(sides / back / front) is split over sheets of at most AU_SHEET_MAX px square (4096 by default,
the safe WebGL2 limit on phones); the first sheet keeps the group's original file name and the
rest get _2, _3, ... Every frame's atlas_file names its sheet. pixel_size_m is recomputed so
Fony stays 1.720 m tall, and every per-frame gameplay field (lift/body/board in master px,
ground_depth_m, body_scale) is copied unchanged.

The web catalog drops the per-frame 'file' and 'source' strings (bake provenance only; the game
never reads them). The full catalog stays with the masters.

Usage: AU_FONY_MASTERS=/path/to/puppet-v1 python3 tools/rebake_fony_web_atlases.py
Env: AU_ATLAS_SCALE (default 1.0; the shipped pack uses 0.35), AU_IMPORT_MODE (1 lossy WebP, the default; 0 lossless), AU_SHEET_MAX (default 4096), AU_WEBP_Q (import lossy quality,
default 0.97, the shipped setting since M0), AU_FONY_DEST (default the repo pack).
"""
import glob, hashlib, json, os, re
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.environ.get('AU_FONY_MASTERS', '/workspace/hq-map/fony-2d-sprites/puppet-v1')
SRC_JSON = os.path.join(ROOT, 'bake/frames_puppet_v1.json')
DEST = os.environ.get('AU_FONY_DEST', os.path.join(HERE, '..', 'assets', 'library', 'fony2d'))
AS = float(os.environ.get('AU_ATLAS_SCALE', '1.0'))
SHEET = int(os.environ.get('AU_SHEET_MAX', '4096'))
QUALITY = float(os.environ.get('AU_WEBP_Q', '0.97'))
# M0 (Nov 18 2026): Fony's atlases import near-lossless: lossy WebP at q0.97 (was q0.75). The user chose this over full
# lossless to keep the main pack near 22 MiB under the 50 MiB budget. AU_IMPORT_MODE=0 gives lossless WebP.
MODE = int(os.environ.get('AU_IMPORT_MODE', '1'))
MASTER = (510, 648)
ANCHOR = (255, 632)
BASE_SCALE = 0.5          # game PIXEL 0.007167 m per atlas px at scale_from_master 0.5
BASE_PIXEL = 0.007167
PIXEL = BASE_PIXEL * BASE_SCALE / AS
ALPHA_T = 8
PAD = 2
DROP_FIELDS = ('file', 'source')

IMPORT_TMPL = """[remap]

importer="texture"
type="CompressedTexture2D"
metadata={{
"vram_texture": false
}}

[deps]

source_file="res://assets/library/fony2d/{name}"

[params]

compress/mode={mode}
compress/high_quality=false
compress/lossy_quality={q}
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
"""


def sheet_name(group: str, i: int) -> str:
    return group if i == 0 else group.replace('.png', f'_{i + 1}.png')


def write_import(name: str) -> None:
    path = os.path.join(DEST, name + '.import')
    if os.path.exists(path):
        txt = open(path).read()
        txt = re.sub(r'compress/lossy_quality=[0-9.]+', f'compress/lossy_quality={QUALITY}', txt)
        txt = re.sub(r'compress/mode=[0-9]+', f'compress/mode={MODE}', txt)
        open(path, 'w').write(txt)
    else:
        open(path, 'w').write(IMPORT_TMPL.format(name=name, q=QUALITY, mode=MODE))


def tile_of(path):
    im = Image.open(path).convert('RGBA')
    if im.size != MASTER:
        im = im.resize(MASTER, Image.LANCZOS)
    if AS != 1.0:
        im = im.resize((round(MASTER[0] * AS), round(MASTER[1] * AS)), Image.LANCZOS)
    bb = im.getchannel('A').point(lambda p: 255 if p > ALPHA_T else 0).getbbox() or (0, 0, 1, 1)
    tile = im.crop(bb)
    return tile, bb, hashlib.sha1(tile.tobytes() + repr(bb).encode()).hexdigest()


def main():
    man = json.load(open(SRC_JSON))
    groups = man['atlases']
    ax, ay = ANCHOR[0] * AS, ANCHOR[1] * AS
    meta = {}
    n = 0
    for group in groups:
        for stale in glob.glob(os.path.join(DEST, group.replace('.png', '_[0-9]*.png*'))):
            os.remove(stale)
        recs = {}
        seen = {}
        for anim in man['animations'].values():
            for fr in anim['frames']:
                if fr['atlas_file'] != group:
                    continue
                path = os.path.join(ROOT, fr['file'])
                if path not in seen:
                    seen[path] = tile_of(path)
                tile, bb, h = seen[path]
                recs.setdefault(h, {'tile': tile, 'bb': bb, 'frames': []})['frames'].append(fr)
                n += 1
        seen.clear()
        tiles = sorted(recs.values(), key=lambda r: (-r['tile'].height, -r['tile'].width))
        sheet = 0
        x = y = PAD
        shelf = 0
        heights = {}
        for r in tiles:
            w, h = r['tile'].size
            if x + w + PAD > SHEET:
                x = PAD
                y += shelf + PAD
                shelf = 0
            if y + h + PAD > SHEET:
                heights[sheet] = SHEET
                sheet += 1
                x = y = PAD
                shelf = 0
            r['sheet'] = sheet
            r['pos'] = (x, y)
            x += w + PAD
            shelf = max(shelf, h)
            heights[sheet] = y + shelf + PAD
        for s in range(sheet + 1):
            name = sheet_name(group, s)
            atlas = Image.new('RGBA', (SHEET, heights[s]), (0, 0, 0, 0))
            for r in tiles:
                if r['sheet'] != s:
                    continue
                atlas.alpha_composite(r['tile'], r['pos'])
                rect = [r['pos'][0], r['pos'][1], r['tile'].width, r['tile'].height]
                off = [r['bb'][0] - ax, r['bb'][1] - ay]
                for fr in r['frames']:
                    fr['atlas_file'] = name
                    fr['atlas_rect'] = list(rect)
                    fr['anchor_offset'] = list(off)
            out_png = os.path.join(DEST, name)
            atlas.save(out_png, compress_level=6)
            write_import(name)
            meta[name] = dict(size=[SHEET, heights[s]], views=groups[group]['views'], group=group,
                              unique_tiles=sum(1 for r in tiles if r['sheet'] == s),
                              png_mb=round(os.path.getsize(out_png) / 1e6, 2))
            print(name, atlas.size, f"{os.path.getsize(out_png)/1e6:.2f} MB png", meta[name]['unique_tiles'], flush=True)
            del atlas
        del tiles, recs
    assert n == 2232, n
    for anim in man['animations'].values():
        for fr in anim['frames']:
            for k in DROP_FIELDS:
                fr.pop(k, None)
    man['atlas']['scale_from_master'] = AS
    man['atlas']['size'] = meta['fony2d_puppet_v1_atlas.png']['size']
    man['atlas']['pixel_size_m'] = PIXEL
    man['atlas']['note'] = (
        'same conventions as frames_v3.json. Never mirrored. Each frame names its atlas_file (sides / back / front groups, '
        f'split over sheets of at most {SHEET} px). Web pack at scale_from_master={AS} (~{round(480 * AS)} px standing; '
        'user-approved Nov 15 2026 sharpness pass, was 0.175); identical tiles share one rect; pixel_size_m keeps '
        '1.720 m world height. Per-frame file/source provenance lives in the master catalog (tools/rebake_fony_web_atlases.py).'
    )
    man['atlases'] = meta
    dest_json = os.path.join(DEST, 'frames_puppet_v1.json')
    with open(dest_json, 'w') as fh:
        json.dump(man, fh, separators=(',', ':'))
    print('frames', n, 'AS', AS, 'PIXEL', PIXEL, 'sheets', len(meta), 'json_kb', round(os.path.getsize(dest_json) / 1024))


if __name__ == '__main__':
    main()
