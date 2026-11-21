#!/usr/bin/env python3
"""Start screen layers (puppeteer, option C, approved Nov 15 2026) -> assets/start_screen/ + data/start_screen.json.

Source: the final layer set (pz_start_16x9_1920x1080_*) from the approved start-screen build
(/workspace/hq-map/project-zero-start-screen/final/layers on the build box; Drive folder 1jAswZXi2jZIo3ArDyJb_S15SW242xkZK).
Transparent layers are cropped to their alpha bounds and the offsets go in data/start_screen.json, so the pack only
carries the pixels that show. The PRESS START prompt layer blinks on the title state; the menu takes its place after a press.
"""
import json, os, sys
from PIL import Image

src = sys.argv[1] if len(sys.argv) > 1 else '/workspace/hq-map/project-zero-start-screen/final/layers'
here = os.path.dirname(os.path.abspath(__file__))
world = os.path.dirname(here)
out = os.path.join(world, 'assets', 'start_screen')
os.makedirs(out, exist_ok=True)
tag = 'pz_start_16x9_1920x1080_'
layout = {"contract": "au.start_screen", "contract_version": 1, "size": [1920, 1080], "layers": {},
          "pivots": {"strings_left": [390, 248], "strings_right": [1545, 285]},
          "sway_deg": 0.9, "sway_s": 4.0, "eyes_pulse": [0.25, 1.0, 2.0],
          "source": "Project Zero start screen option C (puppeteer), approved Nov 15 2026; final layer set, 16:9 1920x1080"}
import shutil
shutil.copyfile(os.path.join(src, tag + 'plate_no_strings.jpg'), os.path.join(out, 'plate.jpg'))
layout['layers']['plate'] = {"file": "plate.jpg", "pos": [0, 0]}
for name in ['strings_left', 'strings_right', 'eyes_glow', 'title', 'prompt']:
    im = Image.open(os.path.join(src, tag + name + '.png')).convert('RGBA')
    box = im.getchannel('A').getbbox()
    crop = im.crop(box)
    crop.save(os.path.join(out, name + '.png'))
    layout['layers'][name] = {"file": name + '.png', "pos": [box[0], box[1]]}
with open(os.path.join(world, 'data', 'start_screen.json'), 'w') as f:
    json.dump(layout, f, indent=2)
print(json.dumps(layout['layers']))
