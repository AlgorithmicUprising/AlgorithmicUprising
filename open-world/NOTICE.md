# Notice

The MIT license in `LICENSE` covers the code and the primitive greybox data in this directory.

It does not grant Algorithmic Uprising branding, logos, character artwork, or music. This slice has no final logo and no avatar. Labels are wayfinding text. Music is not included. See `BUILD_GUIDE.md`.

The Punk Arcade under `../arcade` is a separate project. This directory does not modify it.

## Arcade (Phase 1 exterior + Phase 2 interior, proposed carve-out)

- `assets/thirdparty/kenney/` holds unmodified CC0 1.0 models by Kenney (www.kenney.nl), each folder with its original `License.txt`. `assets/arcade/arcade_trim.png` is posterized from CC0 Poly Haven textures (polyhaven.com). Credit is voluntary.
- `assets/arcade/arcade_art.png`, `assets/arcade/arcade_screens.png` and `art-src/arcade/` contain Algorithmic Uprising art (covers, the AU lockup, the Zero glyph, the Punk Arcade cover art, and the band-approved AI-generated murals). They are not covered by the MIT license above; all rights reserved by Algorithmic Uprising. This carve-out is proposed and needs the band's OK before it merges.

## Zero X Game Engine (Godot Engine)

The Zero X Game Engine is our name for the Godot Engine 4.7.2 build this game runs on. Godot Engine is Copyright (c) 2014-present Godot Engine contributors and Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur, under the MIT license. The full license shows on the boot screen (`scenes/boot.tscn`) and the web loading screen (`web/zero_x_shell.html`). Godot's third-party notices are in `web/GODOT_COPYRIGHT.txt`, which ships next to the web build and is linked from the loading screen (Godot's official `COPYRIGHT.txt` for 4.7.2-stable).

`web/zero_x_zero.webp` is Algorithmic Uprising character art (Zero). It is not covered by the MIT license above; all rights reserved by Algorithmic Uprising.

## Start screen and front end (Nov 19 2026)

- `assets/start_screen/` (the puppeteer start screen, option C, approved Nov 15 2026) is Algorithmic Uprising art. It is not covered by the MIT license above; all rights reserved by Algorithmic Uprising. `tools/make_start_screen.py` regenerates it from the approved layer set.
- `assets/fonts/PressStart2P-Regular.ttf` is Press Start 2P by CodeMan38, from google/fonts, under the SIL Open Font License 1.1 (`assets/fonts/PressStart2P-OFL.txt`).
- The Act I intro video is not in this directory or in the pack. The web build plays it from `media/intro/` next to the pack. `tools/export-web.mjs` generates a labelled placeholder with ffmpeg, or copies the real cut from `AU_INTRO_MP4`. The real cut is Algorithmic Uprising work, all rights reserved.
